import { setTimeout as delay } from "node:timers/promises";
import { prepareChatWorkspace } from "./newChatOptions.js";
import type { ApprovalRequest, ChatRecord, ChatStatus, ServerMessage, StartChatOptions } from "./types.js";
import { formatCodexTranscriptEntry, listCodexChats, readCodexChatDetail } from "./codexSessions.js";
import { interruptCodexDesktopTurn, startCodexDesktopConversation, startCodexDesktopTurn, type DesktopApprovalDecision, type DesktopApprovalRequest, type DesktopLiveEvent } from "./codexDesktopIpc.js";

type Broadcast = (message: ServerMessage) => void;
const DESKTOP_VISIBLE_WAIT_ATTEMPTS = 24;
const DESKTOP_VISIBLE_WAIT_MS = 250;

interface ChatManagerDeps {
  listCodexChats: typeof listCodexChats;
  readCodexChatDetail: typeof readCodexChatDetail;
  prepareChatWorkspace: typeof prepareChatWorkspace;
  startCodexDesktopConversation: typeof startCodexDesktopConversation;
  startCodexDesktopTurn: typeof startCodexDesktopTurn;
  interruptCodexDesktopTurn: typeof interruptCodexDesktopTurn;
}

const defaultDeps: ChatManagerDeps = {
  listCodexChats,
  readCodexChatDetail,
  prepareChatWorkspace,
  startCodexDesktopConversation,
  startCodexDesktopTurn,
  interruptCodexDesktopTurn
};

export class ChatManager {
  private pendingApprovals = new Map<string, { request: ApprovalRequest; respond(decision: DesktopApprovalDecision): Promise<void> }>();
  private liveStatuses = new Map<string, { status: ChatStatus; updatedAt: string }>();

  constructor(
    private readonly broadcast: Broadcast,
    private readonly deps: ChatManagerDeps = defaultDeps
  ) {}

  async list(): Promise<ChatRecord[]> {
    return this.applyPendingApprovals(this.applyLiveStatuses(await this.deps.listCodexChats())).sort(
      (left, right) => this.sortTime(right) - this.sortTime(left)
    );
  }

  async detail(chatId: string): Promise<ChatRecord> {
    const chat = await this.deps.readCodexChatDetail(chatId);
    if (!chat) {
      throw new Error(`No Codex chat with id ${chatId}. Refresh chats and try again.`);
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
    const threadId = await this.deps.startCodexDesktopConversation(
      {
        cwd: repo,
        prompt,
        model: options.model,
        reasoningEffort: options.reasoningEffort,
        accessPreset: options.accessPreset
      },
      (approval) => void this.handleDesktopApprovalRequest(approval),
      (event) => void this.handleDesktopLiveEvent(event)
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
    await this.deps.startCodexDesktopTurn({
      threadId,
      cwd: desktopChat.repo,
      prompt: trimmedPrompt
    });
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

  async approve(chatId: string, approvalId: string): Promise<ApprovalRequest> {
    const pending = this.pendingApproval(chatId, approvalId);
    await pending.respond("accept");
    this.pendingApprovals.delete(approvalId);
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "approval_approved", text: pending.request.summary, status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
    return pending.request;
  }

  async deny(chatId: string, approvalId: string, _reason?: string): Promise<ApprovalRequest> {
    const pending = this.pendingApproval(chatId, approvalId);
    await pending.respond("decline");
    this.pendingApprovals.delete(approvalId);
    const now = new Date().toISOString();
    this.broadcast({ type: "chat_event", chatId, event: { kind: "approval_denied", text: pending.request.summary, status: "running", at: now } });
    this.broadcast({ type: "chat_list", chats: await this.list() });
    return pending.request;
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

  private async handleDesktopApprovalRequest(approval: DesktopApprovalRequest): Promise<void> {
    const request: ApprovalRequest = {
      chatId: `codex:${approval.threadId}`,
      approvalId: approval.approvalId,
      title: approval.title,
      summary: approval.summary,
      files: approval.files,
      diff: approval.diff
    };
    this.pendingApprovals.set(request.approvalId, { request, respond: approval.respond });
    this.broadcast({ type: "approval_required", ...request });
    this.broadcast({
      type: "chat_event",
      chatId: request.chatId,
      event: { kind: "approval_required", text: request.summary, status: "waiting_for_approval", at: new Date().toISOString() }
    });
    this.broadcast({ type: "chat_list", chats: await this.list() });
  }

  private async handleDesktopLiveEvent(event: DesktopLiveEvent): Promise<void> {
    const chatId = `codex:${event.threadId}`;
    const now = new Date().toISOString();
    const mapped = chatEventFromDesktopLiveEvent(event);
    if (!mapped) {
      return;
    }
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

  private pendingApproval(chatId: string, approvalId: string): { request: ApprovalRequest; respond(decision: DesktopApprovalDecision): Promise<void> } {
    const pending = this.pendingApprovals.get(approvalId);
    if (!pending || pending.request.chatId !== chatId) {
      throw new Error(`No pending approval ${approvalId} for Codex chat ${chatId}.`);
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
}

function chatEventFromDesktopLiveEvent(event: DesktopLiveEvent): { kind: string; status?: ChatStatus } | null {
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

function desktopThreadId(chatId: string): string {
  if (!chatId.startsWith("codex:")) {
    throw new Error(`No Codex chat with id ${chatId}.`);
  }
  return chatId.replace(/^codex:/, "");
}
