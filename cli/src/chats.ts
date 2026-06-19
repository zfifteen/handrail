import { setTimeout as delay } from "node:timers/promises";
import { prepareChatWorkspace } from "./newChatOptions.js";
import type { ApprovalRequest, ChatRecord, ChatStatus, ServerMessage, StartChatOptions } from "./types.js";
import { formatGrokTranscriptEntry } from "./grokTranscript.js";
import { grokChatId, grokSessionId, listGrokChats, readGrokChatDetail } from "./grokSessions.js";
import {
  continueGrokTurn,
  interruptGrokTurn,
  startGrokConversation,
  type GrokApprovalDecision,
  type GrokApprovalRequest,
  type GrokLiveEvent
} from "./grokBuildAcp.js";

type Broadcast = (message: ServerMessage) => void;
const GROK_VISIBLE_WAIT_ATTEMPTS = 24;
const GROK_VISIBLE_WAIT_MS = 250;

interface ChatManagerDeps {
  listGrokChats: typeof listGrokChats;
  readGrokChatDetail: typeof readGrokChatDetail;
  prepareChatWorkspace: typeof prepareChatWorkspace;
  startGrokConversation: typeof startGrokConversation;
  continueGrokTurn: typeof continueGrokTurn;
  interruptGrokTurn: typeof interruptGrokTurn;
}

const defaultDeps: ChatManagerDeps = {
  listGrokChats,
  readGrokChatDetail,
  prepareChatWorkspace,
  startGrokConversation,
  continueGrokTurn,
  interruptGrokTurn
};

export class ChatManager {
  private pendingApprovals = new Map<string, { request: ApprovalRequest; respond(decision: GrokApprovalDecision): Promise<void> }>();
  private liveStatuses = new Map<string, { status: ChatStatus; updatedAt: string }>();

  constructor(
    private readonly broadcast: Broadcast,
    private readonly deps: ChatManagerDeps = defaultDeps
  ) {}

  async list(): Promise<ChatRecord[]> {
    return this.applyPendingApprovals(this.applyLiveStatuses(await this.deps.listGrokChats())).sort(
      (left, right) => this.sortTime(right) - this.sortTime(left)
    );
  }

  async detail(chatId: string): Promise<ChatRecord> {
    const chat = await this.deps.readGrokChatDetail(chatId);
    if (!chat) {
      throw new Error(`No Grok chat with id ${chatId}. Refresh chats and try again.`);
    }
    return chat;
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
    const sessionId = await this.deps.startGrokConversation(
      {
        cwd: repo,
        prompt,
        model: options.model,
        reasoningEffort: options.reasoningEffort,
        accessPreset: options.accessPreset
      },
      (approval) => void this.handleGrokApprovalRequest(approval).catch((error) => this.broadcastError(error)),
      (event) => void this.handleGrokLiveEvent(event).catch((error) => this.broadcastError(error))
    );
    const now = new Date().toISOString();
    const visibleChat = await this.waitForVisibleChat(grokChatId(sessionId));
    const chat: ChatRecord = {
      ...visibleChat,
      status: "running",
      updatedAt: now,
      transcript: visibleChat.transcript?.length ? visibleChat.transcript : [formatGrokTranscriptEntry("user", prompt)],
      acceptsInput: false
    };

    this.broadcast({ type: "chat_started", chat });
    this.broadcast({ type: "chat_event", chatId: chat.id, event: { kind: "chat_started", text: "Grok Build chat started.", status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.withVisibleOverlayChat(chat) });
    return chat;
  }

  async continue(chatId: string, prompt: string): Promise<ChatRecord> {
    const trimmedPrompt = prompt.trim();
    if (!trimmedPrompt) {
      throw new Error("Follow-up prompt is required.");
    }
    const grokChats = await this.deps.listGrokChats();
    const grokChat = grokChats.find((chat) => chat.id === chatId);
    if (!grokChat) {
      throw new Error(`No Grok chat with id ${chatId}. Refresh chats and try again.`);
    }

    const sessionId = grokSessionId(chatId);
    await this.deps.continueGrokTurn({
      sessionId,
      cwd: grokChat.repo,
      prompt: trimmedPrompt
    });
    const now = new Date().toISOString();
    const chat: ChatRecord = {
      ...grokChat,
      status: "running",
      updatedAt: now,
      transcript: [...(grokChat.transcript ?? []), formatGrokTranscriptEntry("user", trimmedPrompt)],
      acceptsInput: false
    };

    this.broadcast({ type: "chat_started", chat });
    this.broadcast({ type: "chat_event", chatId, event: { kind: "input_sent", text: trimmedPrompt, status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: this.overlayVisibleChat(grokChats, chat) });
    return chat;
  }

  sendInput(chatId: string, _text: string): void {
    throw new Error(`Grok chat ${chatId} does not accept direct terminal input from Handrail.`);
  }

  async approve(chatId: string, approvalId: string): Promise<ApprovalRequest> {
    const pending = this.pendingApproval(chatId, approvalId);
    await pending.respond("accept");
    this.pendingApprovals.delete(approvalKey(chatId, approvalId));
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "approval_approved", text: pending.request.summary, status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
    return pending.request;
  }

  async deny(chatId: string, approvalId: string, _reason?: string): Promise<ApprovalRequest> {
    const pending = this.pendingApproval(chatId, approvalId);
    await pending.respond("decline");
    this.pendingApprovals.delete(approvalKey(chatId, approvalId));
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "approval_denied", text: pending.request.summary, status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
    return pending.request;
  }

  async stop(chatId: string): Promise<void> {
    const sessionId = grokSessionId(chatId);
    await this.deps.interruptGrokTurn(sessionId);
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "chat_stopped", text: "Stop requested in Grok Build.", status: "stopped", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
  }

  private sortTime(chat: ChatRecord): number {
    return new Date(chat.updatedAt ?? chat.endedAt ?? chat.startedAt).getTime();
  }

  private async waitForVisibleChat(chatId: string): Promise<ChatRecord> {
    for (let attempt = 0; attempt < GROK_VISIBLE_WAIT_ATTEMPTS; attempt += 1) {
      const chat = (await this.deps.listGrokChats()).find((item) => item.id === chatId);
      if (chat) {
        return chat;
      }
      await delay(GROK_VISIBLE_WAIT_MS);
    }
    throw new Error(`Grok Build did not expose chat ${chatId}. Refresh Handrail and try again.`);
  }

  private async withVisibleOverlayChat(startedChat: ChatRecord): Promise<ChatRecord[]> {
    const chats = await this.list();
    return this.overlayVisibleChat(chats, startedChat);
  }

  private overlayVisibleChat(chats: ChatRecord[], overlay: ChatRecord): ChatRecord[] {
    if (!chats.some((chat) => chat.id === overlay.id)) {
      throw new Error(`Grok Build did not expose chat ${overlay.id}. Refresh Handrail and try again.`);
    }
    return chats.map((chat) => chat.id === overlay.id ? { ...chat, ...overlay } : chat);
  }

  private async handleGrokApprovalRequest(approval: GrokApprovalRequest): Promise<void> {
    const request: ApprovalRequest = {
      chatId: grokChatId(approval.sessionId),
      approvalId: approval.approvalId,
      title: approval.title,
      summary: approval.summary,
      files: approval.files,
      diff: approval.diff
    };
    await this.waitForVisibleChat(request.chatId);
    this.pendingApprovals.set(approvalKey(request.chatId, request.approvalId), { request, respond: approval.respond });
    this.broadcast({ type: "approval_required", ...request });
    this.broadcast({
      type: "chat_event",
      chatId: request.chatId,
      event: { kind: "approval_required", text: request.summary, status: "waiting_for_approval", at: new Date().toISOString() }
    });
    this.broadcast({ type: "chat_list", chats: await this.list() });
  }

  private async handleGrokLiveEvent(event: GrokLiveEvent): Promise<void> {
    const chatId = grokChatId(event.sessionId);
    const now = new Date().toISOString();
    const mapped = chatEventFromGrokLiveEvent(event);
    if (!mapped) {
      return;
    }
    await this.waitForVisibleChat(chatId);
    if (mapped.status) {
      this.liveStatuses.set(chatId, { status: mapped.status, updatedAt: now });
    }
    this.broadcast({
      type: "chat_event",
      chatId,
      event: { kind: mapped.kind, text: event.text, status: mapped.status, at: now }
    });
    if (mapped.status) {
      this.broadcast({ type: "chat_list", chats: await this.list() });
    }
  }

  private pendingApproval(chatId: string, approvalId: string): { request: ApprovalRequest; respond(decision: GrokApprovalDecision): Promise<void> } {
    const pending = this.pendingApprovals.get(approvalKey(chatId, approvalId));
    if (!pending || pending.request.chatId !== chatId) {
      throw new Error(`No pending approval ${approvalId} for Grok chat ${chatId}.`);
    }
    return pending;
  }

  private applyPendingApprovals(chats: ChatRecord[]): ChatRecord[] {
    if (this.pendingApprovals.size === 0) {
      return chats;
    }
    return chats.map((chat) => {
      const pending = [...this.pendingApprovals.values()].find((item) => item.request.chatId === chat.id);
      if (!pending) {
        return chat;
      }
      return { ...chat, status: "waiting_for_approval", files: pending.request.files };
    });
  }

  private applyLiveStatuses(chats: ChatRecord[]): ChatRecord[] {
    if (this.liveStatuses.size === 0) {
      return chats;
    }
    return chats.map((chat) => {
      const liveStatus = this.liveStatuses.get(chat.id);
      return liveStatus ? { ...chat, status: liveStatus.status, updatedAt: liveStatus.updatedAt } : chat;
    });
  }

  private broadcastError(error: unknown): void {
    this.broadcast({ type: "error", message: error instanceof Error ? error.message : String(error) });
  }
}

function chatEventFromGrokLiveEvent(event: GrokLiveEvent): { kind: string; status?: ChatStatus } | null {
  switch (event.kind) {
    case "turn_started":
      return { kind: "turn_started", status: "running" };
    case "turn_completed":
      return { kind: "chat_completed", status: "completed" };
    case "turn_failed":
      return { kind: "chat_failed", status: "failed" };
    case "turn_interrupted":
      return { kind: "chat_stopped", status: "stopped" };
    case "output":
      return { kind: "output" };
  }
}

function approvalKey(chatId: string, approvalId: string): string {
  return `${chatId}\n${approvalId}`;
}