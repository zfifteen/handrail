import { createServer } from "node:http";
import { networkInterfaces } from "node:os";
import { Socket } from "node:net";
import { WebSocketServer, WebSocket } from "ws";
import type { ApprovalRequest, ChatRecord, ClientMessage, HandrailState, NewChatOptions, PairingPayload, ServerMessage, StartChatOptions } from "./types.js";
import { ensurePairingToken, saveState } from "./state.js";
import { ChatManager } from "./chats.js";
import { getNewChatOptions } from "./newChatOptions.js";
import { NotificationDispatcher, type PersistState } from "./notifications.js";

interface AuthedSocket extends WebSocket {
  isAuthed?: boolean;
}

interface ChatController {
  list(): Promise<ChatRecord[]>;
  startChat(options: StartChatOptions): Promise<ChatRecord>;
  continue(chatId: string, prompt: string): Promise<ChatRecord>;
  sendInput(chatId: string, text: string): void;
  approve(chatId: string, approvalId: string): ApprovalRequest;
  deny(chatId: string, approvalId: string, reason?: string): ApprovalRequest;
  stop(chatId: string): Promise<void>;
}

export interface HandrailServerHandle {
  port: number;
  close(): Promise<void>;
}

export function localNetworkHost(): string {
  const interfaces = networkInterfaces();
  const names = Object.keys(interfaces).sort();
  for (const name of names) {
    for (const address of interfaces[name] ?? []) {
      if (address.family === "IPv4" && !address.internal) {
        return address.address;
      }
    }
  }
  throw new Error("No non-internal IPv4 address found. Handrail pairing requires local network access.");
}

export function pairingPayload(host: string, port: number, token: string, machineName: string): PairingPayload {
  return {
    protocolVersion: 1,
    host,
    port,
    token,
    machineName
  };
}

export async function isPortOpen(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = new Socket();
    socket.once("connect", () => {
      socket.destroy();
      resolve(true);
    });
    socket.once("error", () => resolve(false));
    socket.connect(port, "127.0.0.1");
  });
}

export async function startServer(): Promise<void> {
  const state = await ensurePairingToken();
  const handle = await createHandrailServer({ state });

  console.log(`Handrail server listening on ws://0.0.0.0:${handle.port}`);
  await new Promise<void>(() => {
    setInterval(() => {}, 60_000);
  });
}

export async function createHandrailServer(options: {
  state: HandrailState;
  chats?: ChatController;
  getOptions?: (projectPath?: string) => Promise<NewChatOptions>;
  persistState?: PersistState;
  notificationDispatcher?: NotificationDispatcher;
  notificationPollIntervalMs?: number;
  port?: number;
}): Promise<HandrailServerHandle> {
  const httpServer = createServer();
  const wss = new WebSocketServer({ server: httpServer });
  const getOptions = options.getOptions ?? getNewChatOptions;

  const broadcast = (message: ServerMessage) => {
    const encoded = JSON.stringify(message);
    for (const client of wss.clients) {
      const socket = client as AuthedSocket;
      if (socket.isAuthed && socket.readyState === WebSocket.OPEN) {
        socket.send(encoded);
      }
    }
  };

  const persistState = options.persistState ?? saveState;
  const notificationDispatcher = options.notificationDispatcher ?? new NotificationDispatcher(options.state, persistState);
  let lastVisibleChatSignature = "";
  let chats: ChatController;
  chats = options.chats ?? new ChatManager(broadcast);
  const observeNotifications = async () => {
    const visibleChats = await chats.list();
    await notificationDispatcher.notifyVisibleChats(
      visibleChats,
      (message) => broadcast({ type: "error", message })
    );
    const signature = visibleChatSignature(visibleChats);
    if (signature !== lastVisibleChatSignature) {
      lastVisibleChatSignature = signature;
      broadcast({ type: "chat_list", chats: visibleChats });
    }
  };
  const observer = setInterval(() => {
    void observeNotifications().catch((error) => {
      broadcast({ type: "error", message: (error as Error).message });
    });
  }, options.notificationPollIntervalMs ?? 5_000);

  wss.on("connection", (socket: AuthedSocket) => {
    socket.on("message", (data) => {
      void handleMessage(socket, data.toString(), options.state, chats, broadcast, getOptions, notificationDispatcher);
    });
  });

  await new Promise<void>((resolve, reject) => {
    httpServer.once("error", reject);
    httpServer.listen(options.port ?? options.state.port, () => resolve());
  });

  const address = httpServer.address();
  const port = typeof address === "object" && address ? address.port : options.state.port;
  return {
    port,
    async close() {
      clearInterval(observer);
      await new Promise<void>((resolve, reject) => {
        wss.close((webSocketError) => {
          if (webSocketError) {
            reject(webSocketError);
            return;
          }
          httpServer.close((httpError) => httpError ? reject(httpError) : resolve());
        });
      });
    }
  };
}

function visibleChatSignature(chats: ChatRecord[]): string {
  return JSON.stringify(chats.map((chat) => ({
    id: chat.id,
    repo: chat.repo,
    title: chat.title,
    projectName: chat.projectName ?? null,
    status: chat.status,
    startedAt: chat.startedAt,
    updatedAt: chat.updatedAt ?? null,
    endedAt: chat.endedAt ?? null,
    exitCode: chat.exitCode ?? null,
    files: chat.files ?? [],
    transcript: chat.transcript ?? [],
    thinking: (chat.thinking ?? []).map((entry) => ({
      id: entry.id,
      round: entry.round,
      text: entry.text,
      at: entry.at ?? null
    })),
    acceptsInput: chat.acceptsInput ?? null,
    isPinned: chat.isPinned ?? null,
    pinnedOrder: chat.pinnedOrder ?? null
  })));
}

async function handleMessage(
  socket: AuthedSocket,
  raw: string,
  state: HandrailState,
  chats: ChatController,
  broadcast: (message: ServerMessage) => void,
  getOptions: (projectPath?: string) => Promise<NewChatOptions> = getNewChatOptions,
  notificationDispatcher?: NotificationDispatcher
): Promise<void> {
  let message: ClientMessage;
  try {
    message = JSON.parse(raw) as ClientMessage;
  } catch {
    socket.send(JSON.stringify({ type: "error", message: "Invalid JSON." } satisfies ServerMessage));
    return;
  }

  if (!socket.isAuthed) {
    if (message.type !== "hello" || message.token !== state.pairingToken) {
      socket.close(1008, "Invalid Handrail pairing token.");
      return;
    }
    socket.isAuthed = true;
    socket.send(JSON.stringify({
      type: "machine_status",
      machineName: state.machineName,
      online: true,
      defaultRepo: state.defaultRepo
    } satisfies ServerMessage));
    socket.send(JSON.stringify({ type: "new_chat_options", options: await getOptions(state.defaultRepo) } satisfies ServerMessage));
    socket.send(JSON.stringify({ type: "chat_list", chats: await chats.list() } satisfies ServerMessage));
    return;
  }

  try {
    switch (message.type) {
      case "hello":
        socket.send(JSON.stringify({ type: "new_chat_options", options: await getOptions(state.defaultRepo) } satisfies ServerMessage));
        socket.send(JSON.stringify({ type: "chat_list", chats: await chats.list() } satisfies ServerMessage));
        break;
      case "register_push_token":
        await notificationDispatcher?.registerPushToken(message);
        break;
      case "start_chat":
        await chats.startChat(message);
        break;
      case "continue_chat":
        await chats.continue(message.chatId, message.prompt);
        break;
      case "send_chat_input":
        chats.sendInput(message.chatId, message.text);
        break;
      case "approve":
        chats.approve(message.chatId, message.approvalId);
        broadcast({ type: "chat_list", chats: await chats.list() });
        break;
      case "deny":
        chats.deny(message.chatId, message.approvalId, message.reason);
        broadcast({ type: "chat_list", chats: await chats.list() });
        break;
      case "stop_chat":
        await chats.stop(message.chatId);
        socket.send(JSON.stringify({ type: "command_result", ok: true, message: "Chat stop requested." } satisfies ServerMessage));
        break;
    }
  } catch (error) {
    socket.send(JSON.stringify({ type: "error", message: (error as Error).message } satisfies ServerMessage));
  }
}
