import { randomUUID } from "node:crypto";
import type { ApprovalRequest, ServerMessage, SessionRecord, SessionStatus } from "./types.js";
import { looksLikeApprovalRequest } from "./approvals.js";
import { formatAgentOutput, startAgent, type AgentProcess } from "./codex.js";
import { listCodexSessions } from "./codexSessions.js";
import { readGitDiff } from "./git.js";
import { loadState, upsertSession } from "./state.js";
import { stat } from "node:fs/promises";

type Broadcast = (message: ServerMessage) => void;

interface LiveSession {
  record: SessionRecord;
  agent: AgentProcess;
  approvalPending: boolean;
  stopping: boolean;
}

export class SessionManager {
  private sessions = new Map<string, LiveSession>();

  constructor(private readonly broadcast: Broadcast) {}

  async list(): Promise<SessionRecord[]> {
    const state = await loadState();
    const live = new Set(this.sessions.keys());
    const handrailSessions = state.sessions.map((session) => {
      if (live.has(session.id)) {
        return this.sessions.get(session.id)!.record;
      }
      if (session.status === "running" || session.status === "waiting_for_approval") {
        return { ...session, status: "idle" as SessionStatus };
      }
      return session;
    });
    return [...handrailSessions, ...await listCodexSessions()].sort(
      (left, right) => this.sortTime(right) - this.sortTime(left)
    );
  }

  async start(repo: string, title: string, prompt?: string): Promise<SessionRecord> {
    await this.validateRepo(repo);
    return this.startLiveSession(repo, title, prompt);
  }

  async continue(sessionId: string, prompt: string): Promise<SessionRecord> {
    const codexSession = (await listCodexSessions()).find((session) => session.id === sessionId);
    if (!codexSession) {
      throw new Error(`No Codex chat with id ${sessionId}. Refresh sessions and try again.`);
    }
    return this.startLiveSession(codexSession.repo, codexSession.title, prompt, sessionId.replace(/^codex:/, ""));
  }

  private async startLiveSession(repo: string, title: string, prompt?: string, resumeSessionId?: string): Promise<SessionRecord> {
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
      acceptsInput: false
    };

    const agent = startAgent(repo, prompt, resumeSessionId);
    record.acceptsInput = agent.acceptsInput;
    this.sessions.set(id, { record, agent, approvalPending: false, stopping: false });
    await upsertSession(record);

    this.broadcast({ type: "session_started", session: record });
    this.broadcast({ type: "session_event", sessionId: id, event: { kind: "session_started", status: "running", at: record.startedAt } });
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
    session.agent.send(text);
    session.record.updatedAt = new Date().toISOString();
    void upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId, event: { kind: "input_sent", text, at: session.record.updatedAt } });
  }

  approve(sessionId: string, approvalId: string): void {
    const session = this.requireLive(sessionId);
    session.approvalPending = false;
    session.record.status = "running";
    session.record.updatedAt = new Date().toISOString();
    session.agent.send("y");
    void upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId, event: { kind: "approval_approved", text: approvalId, status: "running", at: session.record.updatedAt } });
  }

  deny(sessionId: string, approvalId: string, reason?: string): void {
    const session = this.requireLive(sessionId);
    session.approvalPending = false;
    session.record.status = "running";
    session.record.updatedAt = new Date().toISOString();
    session.agent.send("n");
    void upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId, event: { kind: "approval_denied", text: reason || approvalId, status: "running", at: session.record.updatedAt } });
  }

  stop(sessionId: string): void {
    const session = this.requireLive(sessionId);
    session.stopping = true;
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

    session.record.updatedAt = new Date().toISOString();
    const transcriptText = `${output}\n`;
    session.record.transcript = [...(session.record.transcript ?? []), transcriptText];
    await upsertSession(session.record);
    this.broadcast({ type: "session_event", sessionId, event: { kind: "output", text: transcriptText, at: session.record.updatedAt } });

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
        sessionId,
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

    session.record.status = status;
    session.record.endedAt = new Date().toISOString();
    session.record.updatedAt = session.record.endedAt;
    session.record.exitCode = exitCode;
    session.record.transcript = [...(session.record.transcript ?? []), text.endsWith("\n") ? text : `${text}\n`];
    await upsertSession(session.record);
    this.sessions.delete(sessionId);
    const kind = status === "completed" ? "session_completed" : status === "stopped" ? "session_stopped" : "session_failed";
    this.broadcast({ type: "session_event", sessionId, event: { kind, text, status, at: session.record.endedAt } });
    this.broadcast({ type: "session_list", sessions: await this.list() });
  }

  private requireLive(sessionId: string): LiveSession {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`No running session with id ${sessionId}.`);
    }
    return session;
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
}
