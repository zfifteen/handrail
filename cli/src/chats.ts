import { setTimeout as delay } from "node:timers/promises";
import { prepareChatWorkspace } from "./newChatOptions.js";
import type { ApprovalRequest, ChatRecord, ServerMessage, StartChatOptions } from "./types.js";
import { formatCodexTranscriptEntry, listCodexChats } from "./codexSessions.js";
import { interruptCodexDesktopTurn, startCodexDesktopConversation, startCodexDesktopTurn } from "./codexDesktopIpc.js";

type Broadcast = (message: ServerMessage) => void;
const DESKTOP_VISIBLE_WAIT_ATTEMPTS = 24;
const DESKTOP_VISIBLE_WAIT_MS = 250;

interface ChatManagerDeps {
  listCodexChats: typeof listCodexChats;
  prepareChatWorkspace: typeof prepareChatWorkspace;
  startCodexDesktopConversation: typeof startCodexDesktopConversation;
  startCodexDesktopTurn: typeof startCodexDesktopTurn;
  interruptCodexDesktopTurn: typeof interruptCodexDesktopTurn;
}

const defaultDeps: ChatManagerDeps = {
  listCodexChats,
  prepareChatWorkspace,
  startCodexDesktopConversation,
  startCodexDesktopTurn,
  interruptCodexDesktopTurn
};

export class ChatManager {
  constructor(private readonly broadcast: Broadcast, private readonly deps: ChatManagerDeps = defaultDeps) {}

  async list(): Promise<ChatRecord[]> {
    return (await this.deps.listCodexChats()).sort(
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
    const threadId = await this.deps.startCodexDesktopConversation(
      {
        cwd: repo,
        prompt,
        model: options.model,
        reasoningEffort: options.reasoningEffort,
        accessPreset: options.accessPreset
      },
      (completedThreadId) => void this.broadcastCompleted(completedThreadId)
    );
    const now = new Date().toISOString();
    const visibleChat = await this.waitForDesktopVisibleChat(`codex:${threadId}`);
    const chat: ChatRecord = {
      ...visibleChat,
      status: "running",
      updatedAt: now,
      transcript: visibleChat.transcript?.length ? visibleChat.transcript : [formatCodexTranscriptEntry("user", prompt)],
      acceptsInput: false
    };

    this.broadcast({ type: "chat_started", chat });
    this.broadcast({ type: "chat_event", chatId: chat.id, event: { kind: "chat_started", text: "Codex Desktop chat started.", status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.withVisibleOverlayChat(chat) });
    return chat;
  }

  async continue(chatId: string, prompt: string): Promise<ChatRecord> {
    const trimmedPrompt = prompt.trim();
    if (!trimmedPrompt) {
      throw new Error("Follow-up prompt is required.");
    }
    const desktopChats = await this.deps.listCodexChats();
    const desktopChat = desktopChats.find((chat) => chat.id === chatId);
    if (!desktopChat) {
      throw new Error(`No Codex chat with id ${chatId}. Refresh chats and try again.`);
    }

    const threadId = desktopThreadId(chatId);
    await this.deps.startCodexDesktopTurn(
      {
        threadId,
        cwd: desktopChat.repo,
        prompt: trimmedPrompt
      },
      (completedThreadId) => void this.broadcastCompleted(completedThreadId)
    );
    const now = new Date().toISOString();
    const chat: ChatRecord = {
      ...desktopChat,
      status: "running",
      updatedAt: now,
      transcript: [...(desktopChat.transcript ?? []), formatCodexTranscriptEntry("user", trimmedPrompt)],
      acceptsInput: false
    };

    this.broadcast({ type: "chat_started", chat });
    this.broadcast({ type: "chat_event", chatId, event: { kind: "input_sent", text: trimmedPrompt, status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: this.overlayVisibleChat(desktopChats, chat) });
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
    const threadId = desktopThreadId(chatId);
    await this.deps.interruptCodexDesktopTurn(threadId);
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "chat_stopped", text: "Stop requested in Codex Desktop.", status: "stopped", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
  }

  private sortTime(chat: ChatRecord): number {
    return new Date(chat.updatedAt ?? chat.endedAt ?? chat.startedAt).getTime();
  }

  private async waitForDesktopVisibleChat(chatId: string): Promise<ChatRecord> {
    for (let attempt = 0; attempt < DESKTOP_VISIBLE_WAIT_ATTEMPTS; attempt += 1) {
      const chat = (await this.deps.listCodexChats()).find((item) => item.id === chatId);
      if (chat) {
        return chat;
      }
      await delay(DESKTOP_VISIBLE_WAIT_MS);
    }
    throw new Error(`Codex Desktop did not expose chat ${chatId}. Open Codex Desktop and refresh Handrail.`);
  }

  private async withVisibleOverlayChat(startedChat: ChatRecord): Promise<ChatRecord[]> {
    const chats = await this.list();
    return this.overlayVisibleChat(chats, startedChat);
  }

  private overlayVisibleChat(chats: ChatRecord[], overlay: ChatRecord): ChatRecord[] {
    if (!chats.some((chat) => chat.id === overlay.id)) {
      throw new Error(`Codex Desktop did not expose chat ${overlay.id}. Open Codex Desktop and refresh Handrail.`);
    }
    return chats.map((chat) => chat.id === overlay.id ? { ...chat, ...overlay } : chat);
  }

  private async broadcastCompleted(threadId: string): Promise<void> {
    const chatId = `codex:${threadId}`;
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "chat_completed", status: "completed", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
  }
}

export function chatCompletedEvent(status: ChatRecord["status"]): "chat_completed" | "chat_stopped" | "chat_failed" {
  if (status === "completed") {
    return "chat_completed";
  }
  if (status === "stopped") {
    return "chat_stopped";
  }
  return "chat_failed";
}

function desktopThreadId(chatId: string): string {
  if (!chatId.startsWith("codex:")) {
    throw new Error(`No Codex chat with id ${chatId}.`);
  }
  return chatId.replace(/^codex:/, "");
}
