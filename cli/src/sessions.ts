import { randomUUID } from "node:crypto";
import type { ApprovalRequest, ServerMessage, SessionRecord, SessionStatus, StartChatOptions } from "./types.js";
import { looksLikeApprovalRequest } from "./approvals.js";
import { formatAgentOutput, startAgent, type AgentOptions, type AgentProcess } from "./codex.js";
import { formatCodexTranscriptEntry } from "./codexSessions.js";
import { listCodexSessions } from "./codexSessions.js";
import { readGitDiff } from "./git.js";
import { upsertSession } from "./state.js";
import { stat } from "node:fs/promises";
import { promoteCodexThreadToDesktop } from "./codexDesktop.js";
import { interruptCodexDesktopTurn, startCodexDesktopTurn } from "./codexDesktopIpc.js";

type Broadcast = (message: ServerMessage) => void;

interface LiveSession {
  record: SessionRecord;
  agent: AgentProcess;
  approvalPending: boolean;
  stopping: boolean;
  codexThreadId?: string;
}

export class SessionManager {
  private sessions = new Map<string, LiveSession>();

  constructor(private readonly broadcast: Broadcast) {}

  async list(): Promise<SessionRecord[]> {
    const codexSessions = await listCodexSessions();
    return codexSessions.map((session) => this.liveDesktopSession(session)).sort(
      (left, right) => this.sortTime(right) - this.sortTime(left)
    );
  }

  async start(repo: string, title: string, prompt?: string): Promise<SessionRecord> {
    await this.validateRepo(repo);
    return this.startLiveSession(repo, title, prompt);
  }

  async startChat(options: StartChatOptions): Promise<SessionRecord> {
    void options;
    throw new Error("Starting a new Desktop chat from Handrail is disabled until it can be routed through Codex Desktop directly. Use New chat in Codex Desktop for now.");
  }

  async continue(sessionId: string, prompt: string): Promise<SessionRecord> {
    const codexSession = (await listCodexSessions()).find((session) => session.id === sessionId);
    if (!codexSession) {
      throw new Error(`No Codex chat with id ${sessionId}. Refresh sessions and try again.`);
    }
    const codexThreadId = sessionId.replace(/^codex:/, "");
    await startCodexDesktopTurn({ threadId: codexThreadId, cwd: codexSession.repo, prompt });
    const now = new Date().toISOString();
    const session: SessionRecord = {
      ...codexSession,
      status: "running",
      updatedAt: now,
      transcript: [...(codexSession.transcript ?? []), formatCodexTranscriptEntry("user", prompt)]
    };
    this.broadcast({ type: "session_started", session });
    this.broadcast({ type: "session_event", sessionId, event: { kind: "input_sent", text: prompt, status: "running", at: now } });
    this.broadcast({ type: "session_list", sessions: await this.list() });
    return session;
  }

  private async startLiveSession(repo: string, title: string, prompt?: string, resumeSessionId?: string, agentOptions: AgentOptions = {}): Promise<SessionRecord> {
    await this.validateRepo(repo);
    const id = randomUUID();
    const record: SessionRecord = {
      id,
      repo,
      title,
      status: "running",
      startedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      source: "handrail",
      acceptsInput: false,
      transcript: prompt?.trim() ? [formatCodexTranscriptEntry("user", prompt)] : []
    };

    const agent = startAgent(repo, prompt, resumeSessionId, agentOptions);
    record.acceptsInput = agent.acceptsInput;
    const liveSession: LiveSession = { record, agent, approvalPending: false, stopping: false, codexThreadId: resumeSessionId };
    this.sessions.set(id, liveSession);
    await upsertSession(record);

    if (resumeSessionId) {
      this.broadcast({ type: "session_started", session: this.toDesktopLiveRecord(liveSession) });
      this.broadcast({ type: "session_event", sessionId: this.publicSessionId(liveSession), event: { kind: "session_started", status: "running", at: record.startedAt } });
    }
    this.broadcast({ type: "session_list", sessions: await this.list() });

    agent.child.stdout.on("data", (chunk: Buffer) => {
      void this.handleOutput(id, chunk.toString());
    });
    agent.child.stderr.on("data", (chunk: Buffer) => {
      void this.handleOutput(id, chunk.toString());
    });
    agent.child.on("error", (error) => {
      void this.finish(id, "failed", null, error.message);
    });
    agent.child.on("exit", (code, signal) => {
      const live = this.sessions.get(id);
      const status: SessionStatus = live?.stopping ? "stopped" : code === 0 ? "completed" : "failed";
      const text = live?.stopping ? "Stopped by Handrail." : signal ? `Exited by signal ${signal}.` : `Exited with code ${code ?? "unknown"}.`;
      void this.finish(id, status, code, text);
    });

    return record;
  }

  sendInput(sessionId: string, text: string): void {
    const session = this.requireLive(sessionId);
    const publicSessionId = this.publicSessionId(session);
    session.agent.send(text);
    session.record.updatedAt = new Date().toISOString();
    void upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId: publicSessionId, event: { kind: "input_sent", text, at: session.record.updatedAt } });
  }

  approve(sessionId: string, approvalId: string): void {
    const session = this.requireLive(sessionId);
    const publicSessionId = this.publicSessionId(session);
    session.approvalPending = false;
    session.record.status = "running";
    session.record.updatedAt = new Date().toISOString();
    session.agent.send("y");
    void upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId: publicSessionId, event: { kind: "approval_approved", text: approvalId, status: "running", at: session.record.updatedAt } });
  }

  deny(sessionId: string, approvalId: string, reason?: string): void {
    const session = this.requireLive(sessionId);
    const publicSessionId = this.publicSessionId(session);
    session.approvalPending = false;
    session.record.status = "running";
    session.record.updatedAt = new Date().toISOString();
    session.agent.send("n");
    void upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId: publicSessionId, event: { kind: "approval_denied", text: reason || approvalId, status: "running", at: session.record.updatedAt } });
  }

  async stop(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId) ?? [...this.sessions.values()].find((live) => this.publicSessionId(live) === sessionId);
    if (!session && sessionId.startsWith("codex:")) {
      const threadId = sessionId.replace(/^codex:/, "");
      await interruptCodexDesktopTurn(threadId);
      const now = new Date().toISOString();
      this.broadcast({ type: "session_event", sessionId, event: { kind: "session_stopped", text: "Stop requested in Codex Desktop.", status: "stopped", at: now } });
      this.broadcast({ type: "session_list", sessions: await this.list() });
      return;
    }
    if (!session) {
      throw new Error(`No running session with id ${sessionId}.`);
    }
    session.stopping = true;
    session.record.status = "stopped";
    session.record.endedAt = new Date().toISOString();
    session.record.updatedAt = session.record.endedAt;
    session.record.transcript = [...(session.record.transcript ?? []), formatCodexTranscriptEntry("assistant", "Stopped by Handrail.")];
    await upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId: this.publicSessionId(session), event: { kind: "session_stopped", text: "Stopped by Handrail.", status: "stopped", at: session.record.endedAt } });
    this.broadcast({ type: "session_list", sessions: await this.list() });
    session.agent.stop();
  }

  private async handleOutput(sessionId: string, text: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return;
    }

    const output = formatAgentOutput(text);
    if (output.length === 0) {
      return;
    }

    const codexThreadId = extractCodexThreadId(output);
    if (codexThreadId && session.codexThreadId !== codexThreadId) {
      session.codexThreadId = codexThreadId;
      await this.promoteDesktopThread(codexThreadId, session.record.title, firstUserMessage(session.record));
      this.broadcast({ type: "session_started", session: this.toDesktopLiveRecord(session) });
      this.broadcast({ type: "session_event", sessionId: this.publicSessionId(session), event: { kind: "session_started", status: "running", at: session.record.startedAt } });
      this.broadcast({ type: "session_list", sessions: await this.list() });
    }

    session.record.updatedAt = new Date().toISOString();
    const transcriptText = formatCodexTranscriptEntry("assistant", output);
    session.record.transcript = [...(session.record.transcript ?? []), transcriptText];
    await upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId: this.publicSessionId(session), event: { kind: "output", text: transcriptText, at: session.record.updatedAt } });

    if (!session.approvalPending && looksLikeApprovalRequest(output)) {
      session.approvalPending = true;
      session.record.status = "waiting_for_approval";
      let snapshot;
      try {
        snapshot = await readGitDiff(session.record.repo);
      } catch (error) {
        this.broadcast({ type: "error", message: `Could not read git diff for ${session.record.repo}: ${(error as Error).message}` });
        return;
      }
      session.record.files = snapshot.files;
      await upsertSession(session.record);

      const approval: ApprovalRequest = {
        sessionId: this.publicSessionId(session),
        approvalId: randomUUID(),
        title: "Approval Required",
        summary: snapshot.stat || "Codex appears to be requesting approval.",
        files: snapshot.files,
        diff: snapshot.diff
      };
      this.broadcast({ type: "approval_required", ...approval });
      this.broadcast({ type: "session_list", sessions: await this.list() });
    }
  }

  private async finish(sessionId: string, status: SessionStatus, exitCode: number | null, text: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return;
    }
    if (session.record.status === "stopped") {
      this.sessions.delete(sessionId);
      return;
    }

    session.record.status = status;
    session.record.endedAt = new Date().toISOString();
    session.record.updatedAt = session.record.endedAt;
    session.record.exitCode = exitCode;
    session.record.transcript = [...(session.record.transcript ?? []), formatCodexTranscriptEntry("assistant", text)];
    await upsertSession(session.record);
    this.sessions.delete(sessionId);
    const kind = status === "completed" ? "session_completed" : status === "stopped" ? "session_stopped" : "session_failed";
    this.broadcast({ type: "session_event", sessionId: this.publicSessionId(session), event: { kind, text, status, at: session.record.endedAt } });
    this.broadcast({ type: "session_list", sessions: await this.list() });
  }

  private requireLive(sessionId: string): LiveSession {
    const session = this.sessions.get(sessionId) ?? [...this.sessions.values()].find((live) => this.publicSessionId(live) === sessionId);
    if (!session) {
      throw new Error(`No running session with id ${sessionId}.`);
    }
    return session;
  }

  private liveDesktopSession(session: SessionRecord): SessionRecord {
    const live = [...this.sessions.values()].find((candidate) => this.publicSessionId(candidate) === session.id);
    if (!live) {
      return session;
    }
    return {
      ...session,
      status: live.record.status,
      updatedAt: live.record.updatedAt ?? session.updatedAt,
      endedAt: live.record.endedAt,
      exitCode: live.record.exitCode,
      files: live.record.files,
      transcript: live.record.transcript,
      acceptsInput: live.record.acceptsInput
    };
  }

  private toDesktopLiveRecord(session: LiveSession): SessionRecord {
    return {
      ...session.record,
      id: this.publicSessionId(session),
      source: "codex"
    };
  }

  private publicSessionId(session: LiveSession): string {
    return session.codexThreadId ? `codex:${session.codexThreadId}` : session.record.id;
  }

  private async validateRepo(repo: string): Promise<void> {
    let info;
    try {
      info = await stat(repo);
    } catch {
      throw new Error(`Repository path does not exist on this Mac: ${repo}`);
    }
    if (!info.isDirectory()) {
      throw new Error(`Repository path is not a directory on this Mac: ${repo}`);
    }
  }

  private sortTime(session: SessionRecord): number {
    return new Date(session.updatedAt ?? session.endedAt ?? session.startedAt).getTime();
  }

  private async promoteDesktopThread(threadId: string, title: string, prompt?: string): Promise<void> {
    try {
      await promoteCodexThreadToDesktop(threadId, title, prompt ?? "");
    } catch (error) {
      this.broadcast({ type: "error", message: `Could not mark Codex chat ${threadId} visible in Codex Desktop: ${(error as Error).message}` });
    }
  }
}

export function extractCodexThreadId(text: string): string | null {
  return text.match(/Codex thread started: ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/)?.[1] ?? null;
}

function firstUserMessage(session: SessionRecord): string {
  const entry = session.transcript?.find((line) => line.startsWith("User:\n"));
  return entry?.replace(/^User:\n/, "").trim() ?? "";
}
