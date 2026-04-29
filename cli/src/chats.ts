import { basename } from "node:path";
import type { AgentProcess, AgentOptions } from "./codex.js";
import { formatAgentOutput, startAgent } from "./codex.js";
import { promoteCodexThreadToDesktop, waitForCodexDesktopThreadSettled } from "./codexDesktop.js";
import { prepareChatWorkspace } from "./newChatOptions.js";
import type { ApprovalRequest, ChatRecord, ChatStatus, ServerMessage, StartChatOptions } from "./types.js";
import { formatCodexTranscriptEntry, listCodexChats } from "./codexSessions.js";
import { interruptCodexDesktopTurn, openCodexDesktopThread, startCodexDesktopTurn } from "./codexDesktopIpc.js";

type Broadcast = (message: ServerMessage) => void;

interface LiveChat {
  agent: AgentProcess;
  record: ChatRecord;
}

interface ChatManagerDeps {
  listCodexChats: typeof listCodexChats;
  prepareChatWorkspace: typeof prepareChatWorkspace;
  startAgent: typeof startAgent;
  promoteCodexThreadToDesktop: typeof promoteCodexThreadToDesktop;
  waitForCodexDesktopThreadSettled: typeof waitForCodexDesktopThreadSettled;
  openCodexDesktopThread: typeof openCodexDesktopThread;
  startCodexDesktopTurn: typeof startCodexDesktopTurn;
  interruptCodexDesktopTurn: typeof interruptCodexDesktopTurn;
}

const defaultDeps: ChatManagerDeps = {
  listCodexChats,
  prepareChatWorkspace,
  startAgent,
  promoteCodexThreadToDesktop,
  waitForCodexDesktopThreadSettled,
  openCodexDesktopThread,
  startCodexDesktopTurn,
  interruptCodexDesktopTurn
};

export class ChatManager {
  private readonly liveChats = new Map<string, LiveChat>();

  constructor(private readonly broadcast: Broadcast, private readonly deps: ChatManagerDeps = defaultDeps) {}

  async list(): Promise<ChatRecord[]> {
    return (await this.deps.listCodexChats()).map((chat) => {
      const live = this.liveChats.get(chat.id);
      return live ? { ...chat, ...live.record } : chat;
    }).sort(
      (left, right) => this.sortTime(right) - this.sortTime(left)
    );
  }

  async startChat(options: StartChatOptions): Promise<ChatRecord> {
    const prompt = options.prompt.trim();
    if (!prompt) {
      throw new Error("New chat prompt is required.");
    }

    const repo = await this.deps.prepareChatWorkspace({
      projectPath: options.projectPath,
      branch: options.branch,
      newBranch: options.newBranch,
      workMode: options.workMode
    });
    const agentOptions: AgentOptions = {
      model: options.model,
      reasoningEffort: options.reasoningEffort,
      accessPreset: options.accessPreset,
      skipGitRepoCheck: !options.projectPath
    };
    const agent = this.deps.startAgent(repo, prompt, undefined, agentOptions);
    return await this.promoteStartedChat({ agent, options, prompt, repo });
  }

  async continue(chatId: string, prompt: string): Promise<ChatRecord> {
    const trimmedPrompt = prompt.trim();
    if (!trimmedPrompt) {
      throw new Error("Follow-up prompt is required.");
    }
    const codexChat = (await this.deps.listCodexChats()).find((chat) => chat.id === chatId);
    if (!codexChat) {
      throw new Error(`No Codex chat with id ${chatId}. Refresh chats and try again.`);
    }

    const codexThreadId = chatId.replace(/^codex:/, "");
    const agent = this.deps.startAgent(codexChat.repo, trimmedPrompt, codexThreadId);
    const now = new Date().toISOString();
    const chat: ChatRecord = {
      ...codexChat,
      status: "running",
      updatedAt: now,
      transcript: [...(codexChat.transcript ?? []), formatCodexTranscriptEntry("user", trimmedPrompt)],
      acceptsInput: false
    };

    this.liveChats.set(chat.id, { agent, record: chat });
    this.attachContinuedChat(agent, chat, codexThreadId, trimmedPrompt);
    this.broadcast({ type: "chat_started", chat });
    this.broadcast({ type: "chat_event", chatId, event: { kind: "input_sent", text: trimmedPrompt, status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
    return chat;
  }

  sendInput(chatId: string, _text: string): void {
    throw new Error(`Codex chat ${chatId} does not accept direct terminal input from Handrail.`);
  }

  approve(chatId: string, _approvalId: string): ApprovalRequest {
    throw new Error(`Approval routing for Codex chat ${chatId} is not enabled yet.`);
  }

  deny(chatId: string, _approvalId: string, _reason?: string): ApprovalRequest {
    throw new Error(`Approval routing for Codex chat ${chatId} is not enabled yet.`);
  }

  async stop(chatId: string): Promise<void> {
    if (!chatId.startsWith("codex:")) {
      throw new Error(`No Codex chat with id ${chatId}.`);
    }

    const threadId = chatId.replace(/^codex:/, "");
    await this.deps.interruptCodexDesktopTurn(threadId);
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "chat_stopped", text: "Stop requested in Codex Desktop.", status: "stopped", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
  }

  private sortTime(chat: ChatRecord): number {
    return new Date(chat.updatedAt ?? chat.endedAt ?? chat.startedAt).getTime();
  }

  private attachContinuedChat(agent: AgentProcess, record: ChatRecord, threadId: string, prompt: string): void {
    const appendOutput = (chunk: Buffer) => {
      const output = visibleAssistantOutput(formatAgentOutput(chunk.toString()));
      if (!output) {
        return;
      }
      const now = new Date().toISOString();
      record.updatedAt = now;
      record.transcript = [...(record.transcript ?? []), formatCodexTranscriptEntry("assistant", output)];
      this.broadcast({ type: "chat_event", chatId: record.id, event: { kind: "output", text: formatCodexTranscriptEntry("assistant", output), status: record.status, at: now } });
    };

    const fail = (error: Error) => {
      const now = new Date().toISOString();
      record.status = "failed";
      record.endedAt = now;
      record.updatedAt = now;
      this.broadcast({ type: "chat_event", chatId: record.id, event: { kind: "chat_failed", text: error.message, status: "failed", at: now } });
      this.liveChats.delete(record.id);
      void this.list().then((chats) => this.broadcast({ type: "chat_list", chats }));
    };

    agent.child.stdout.on("data", appendOutput);
    agent.child.stderr.on("data", appendOutput);
    agent.child.once("error", fail);
    agent.child.once("exit", (code) => {
      void (async () => {
        const now = new Date().toISOString();
        const status: ChatStatus = code === 0 ? "completed" : "failed";
        record.status = status;
        record.exitCode = code;
        record.endedAt = now;
        record.updatedAt = now;
        if (status === "completed") {
          await this.deps.promoteCodexThreadToDesktop(threadId, record.title, firstUserPrompt(record, prompt), { cwd: record.repo });
        }
        this.broadcast({ type: "chat_event", chatId: record.id, event: { kind: chatCompletedEvent(status), status, at: now } });
        this.liveChats.delete(record.id);
        this.broadcast({ type: "chat_list", chats: await this.list() });
      })().catch(fail);
    });
  }

  private async promoteStartedChat(input: { agent: AgentProcess; options: StartChatOptions; prompt: string; repo: string }): Promise<ChatRecord> {
    const startedAt = new Date().toISOString();
    const pendingOutput: string[] = [];
    let resolved = false;
    let promoted = false;
    let exited = false;
    let exitCode: number | null = null;
    let codexThreadId: string | null = null;
    let promotedTitle: string | null = null;
    let record: ChatRecord | null = null;

    return await new Promise<ChatRecord>((resolve, reject) => {
      const finishRecord = async (code: number | null) => {
        if (!record) {
          return;
        }
        if (codexThreadId && promotedTitle) {
          try {
            await this.deps.waitForCodexDesktopThreadSettled(codexThreadId);
            await this.deps.promoteCodexThreadToDesktop(codexThreadId, promotedTitle, input.prompt, promotionMetadata(input));
          } catch (error) {
            const now = new Date().toISOString();
            record.status = "failed";
            record.exitCode = code;
            record.endedAt = now;
            record.updatedAt = now;
            this.broadcast({ type: "chat_event", chatId: record.id, event: { kind: "chat_failed", text: (error as Error).message, status: "failed", at: now } });
            this.broadcast({ type: "chat_list", chats: await this.list() });
            this.liveChats.delete(record.id);
            return;
          }
        }
        const now = new Date().toISOString();
        const status: ChatStatus = code === 0 ? "completed" : "failed";
        record.status = status;
        record.exitCode = code;
        record.endedAt = now;
        record.updatedAt = now;
        this.broadcast({ type: "chat_event", chatId: record.id, event: { kind: chatCompletedEvent(status), status, at: now } });
        this.broadcast({ type: "chat_list", chats: await this.list() });
        this.liveChats.delete(record.id);
      };

      const rejectStart = (error: Error) => {
        if (!resolved) {
          resolved = true;
          reject(error);
          return;
        }
        this.broadcast({ type: "chat_event", chatId: record?.id ?? "codex:pending", event: { kind: "chat_failed", text: error.message, status: "failed", at: new Date().toISOString() } });
      };

      const appendOutput = (text: string) => {
        const visible = visibleAssistantOutput(text);
        if (!visible) {
          return;
        }
        if (!record) {
          pendingOutput.push(visible);
          return;
        }
        const now = new Date().toISOString();
        record.updatedAt = now;
        record.transcript = [...(record.transcript ?? []), formatCodexTranscriptEntry("assistant", visible)];
        this.broadcast({ type: "chat_event", chatId: record.id, event: { kind: "output", text: formatCodexTranscriptEntry("assistant", visible), status: record.status, at: now } });
      };

      const promote = (threadId: string) => {
        if (promoted) {
          return;
        }
        promoted = true;
        void (async () => {
          const title = chatTitle(input.prompt);
          await this.deps.promoteCodexThreadToDesktop(threadId, title, input.prompt, promotionMetadata(input));
          await this.deps.openCodexDesktopThread(threadId);
          codexThreadId = threadId;
          promotedTitle = title;
          const now = new Date().toISOString();
          record = {
            id: `codex:${threadId}`,
            repo: input.repo,
            title,
            projectName: projectName(input.options, input.repo),
            status: "running",
            startedAt,
            updatedAt: now,
            transcript: [formatCodexTranscriptEntry("user", input.prompt)],
            acceptsInput: false
          };
          for (const output of pendingOutput.splice(0)) {
            record.transcript = [...(record.transcript ?? []), formatCodexTranscriptEntry("assistant", output)];
          }
          this.liveChats.set(record.id, { agent: input.agent, record });
          this.broadcast({ type: "chat_started", chat: record });
          this.broadcast({ type: "chat_event", chatId: record.id, event: { kind: "chat_started", text: "Codex chat created in Desktop.", status: "running", at: now } });
          this.broadcast({ type: "chat_list", chats: await this.list() });
          resolved = true;
          resolve(record);
          if (exited) {
            await finishRecord(exitCode);
          }
        })().catch(rejectStart);
      };

      const onOutput = (chunk: Buffer) => {
        const output = formatAgentOutput(chunk.toString());
        if (!output) {
          return;
        }
        const threadId = extractCodexThreadId(output);
        if (threadId) {
          promote(threadId);
        }
        appendOutput(output);
      };

      input.agent.child.stdout.on("data", onOutput);
      input.agent.child.stderr.on("data", onOutput);
      input.agent.child.once("error", rejectStart);
      input.agent.child.once("exit", (code) => {
        exited = true;
        exitCode = code;
        if (!record) {
          if (promoted) {
            return;
          }
          rejectStart(new Error(`Codex exited before reporting a Desktop-visible thread id. Exit code: ${code ?? "unknown"}.`));
          return;
        }
        void finishRecord(code);
      });
    });
  }
}

export function extractCodexThreadId(text: string): string | null {
  return text.match(/Codex thread started: ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/)?.[1] ?? null;
}

export function chatCompletedEvent(status: ChatStatus): "chat_completed" | "chat_stopped" | "chat_failed" {
  if (status === "completed") {
    return "chat_completed";
  }
  if (status === "stopped") {
    return "chat_stopped";
  }
  return "chat_failed";
}

function visibleAssistantOutput(text: string): string {
  return text
    .split("\n")
    .filter((line) => !line.startsWith("Codex thread started:") && line !== "Codex started." && line !== "Codex completed.")
    .join("\n")
    .trim();
}

function chatTitle(prompt: string): string {
  const line = prompt.split(/\r?\n/).find((item) => item.trim().length > 0)?.trim() ?? "New chat";
  return line.length <= 80 ? line : `${line.slice(0, 77)}...`;
}

function projectName(options: StartChatOptions, repo: string): string {
  if (options.projectId !== "no-project" && options.projectPath) {
    return basename(options.projectPath);
  }
  return basename(repo);
}

function firstUserPrompt(record: ChatRecord, fallback: string): string {
  const firstUserEntry = record.transcript?.find((entry) => entry.startsWith("User:\n"));
  if (!firstUserEntry) {
    return fallback;
  }
  return firstUserEntry
    .replace(/^User:\n/, "")
    .replace(/\n\n$/, "")
    .replace(/  \n/g, "\n")
    .trim() || fallback;
}

function promotionMetadata(input: { options: StartChatOptions; repo: string }) {
  return {
    cwd: input.repo,
    model: input.options.model,
    reasoningEffort: input.options.reasoningEffort,
    ...desktopAccessMetadata(input.options.accessPreset)
  };
}

function desktopAccessMetadata(accessPreset: StartChatOptions["accessPreset"]): { sandboxPolicy: string; approvalMode: string } {
  switch (accessPreset) {
    case "full_access":
      return { sandboxPolicy: "danger-full-access", approvalMode: "never" };
    case "read_only":
      return { sandboxPolicy: "read-only", approvalMode: "on-request" };
    case "on_request":
      return { sandboxPolicy: "workspace-write", approvalMode: "on-request" };
  }
}
