import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Socket, createConnection } from "node:net";

const INITIALIZING_CLIENT_ID = "initializing-client";
const REQUEST_TIMEOUT_MS = 15_000;

type IpcResponse =
  | { type: "response"; requestId: string; resultType: "success"; method?: string; result?: unknown }
  | { type: "response"; requestId: string; resultType: "error"; error: string };

interface PendingResponse {
  resolve(response: IpcResponse): void;
  reject(error: Error): void;
  timer: NodeJS.Timeout;
}

interface IpcRequest {
  type: "request";
  requestId: string;
  sourceClientId: string;
  version: number;
  method: string;
  params: unknown;
}

export interface DesktopTurnInput {
  threadId: string;
  cwd: string;
  prompt: string;
}

export async function startCodexDesktopTurn(input: DesktopTurnInput): Promise<void> {
  await withCodexDesktopIpc(async (client) => {
    await client.request("thread-follower-start-turn", {
      conversationId: input.threadId,
      turnStartParams: {
        input: [{ type: "text", text: input.prompt, text_elements: [] }],
        cwd: input.cwd
      }
    });
  });
}

export async function interruptCodexDesktopTurn(threadId: string): Promise<void> {
  await withCodexDesktopIpc(async (client) => {
    await client.request("thread-follower-interrupt-turn", { conversationId: threadId });
  });
}

export function codexDesktopIpcSocketPath(): string {
  const uid = typeof process.getuid === "function" ? process.getuid() : null;
  return join(tmpdir(), "codex-ipc", uid == null ? "ipc.sock" : `ipc-${uid}.sock`);
}

export function codexDesktopIpcRequest(method: string, params: unknown, sourceClientId: string, requestId: string = randomUUID()): IpcRequest {
  return {
    type: "request",
    requestId,
    sourceClientId,
    version: codexDesktopIpcRequestVersion(method),
    method,
    params
  };
}

export function codexDesktopIpcRequestVersion(method: string): number {
  return method.startsWith("thread-follower-") ? 1 : 0;
}

export function encodeCodexDesktopIpcFrame(message: unknown): Buffer {
  const json = JSON.stringify(message);
  const length = Buffer.byteLength(json);
  const frame = Buffer.alloc(4 + length);
  frame.writeUInt32LE(length, 0);
  frame.write(json, 4);
  return frame;
}

async function withCodexDesktopIpc<T>(work: (client: CodexDesktopIpcClient) => Promise<T>): Promise<T> {
  const client = new CodexDesktopIpcClient(codexDesktopIpcSocketPath());
  await client.connect();
  try {
    return await work(client);
  } finally {
    client.close();
  }
}

class CodexDesktopIpcClient {
  private socket: Socket | null = null;
  private clientId = INITIALIZING_CLIENT_ID;
  private buffer = Buffer.alloc(0);
  private pending = new Map<string, PendingResponse>();

  constructor(private readonly socketPath: string) {}

  async connect(): Promise<void> {
    if (!existsSync(this.socketPath)) {
      throw new Error(`Codex Desktop IPC socket was not found at ${this.socketPath}. Open Codex Desktop and try again.`);
    }

    await new Promise<void>((resolve, reject) => {
      const socket = createConnection(this.socketPath);
      this.socket = socket;
      socket.once("connect", resolve);
      socket.once("error", reject);
      socket.on("data", (chunk) => this.read(chunk));
      socket.on("close", () => this.rejectAll("Codex Desktop IPC connection closed."));
    });

    const response = await this.request("initialize", { clientType: "handrail" });
    if (response && typeof response === "object" && "clientId" in response && typeof response.clientId === "string") {
      this.clientId = response.clientId;
    }
  }

  async request(method: string, params: unknown): Promise<unknown> {
    const socket = this.socket;
    if (!socket?.writable) {
      throw new Error("Codex Desktop IPC is not connected.");
    }

    const request = codexDesktopIpcRequest(method, params, this.clientId);
    const frame = encodeCodexDesktopIpcFrame(request);
    socket.write(frame);

    const response = await new Promise<IpcResponse>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(request.requestId);
        reject(new Error(`Timed out waiting for Codex Desktop to handle ${method}.`));
      }, REQUEST_TIMEOUT_MS);
      this.pending.set(request.requestId, { resolve, reject, timer });
    });

    if (response.resultType === "error") {
      throw new Error(formatDesktopIpcError(method, response.error));
    }
    return response.result;
  }

  close(): void {
    this.socket?.end();
    this.socket = null;
  }

  private read(chunk: Buffer): void {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length >= 4) {
      const length = this.buffer.readUInt32LE(0);
      if (this.buffer.length < 4 + length) {
        return;
      }
      const message = JSON.parse(this.buffer.subarray(4, 4 + length).toString("utf8")) as { type?: string; requestId?: string };
      this.buffer = this.buffer.subarray(4 + length);
      if (message.type !== "response" || typeof message.requestId !== "string") {
        continue;
      }
      const pending = this.pending.get(message.requestId);
      if (!pending) {
        continue;
      }
      this.pending.delete(message.requestId);
      clearTimeout(pending.timer);
      pending.resolve(message as IpcResponse);
    }
  }

  private rejectAll(message: string): void {
    for (const [requestId, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(new Error(message));
      this.pending.delete(requestId);
    }
  }
}

function formatDesktopIpcError(method: string, error: string): string {
  if (error === "no-client-found") {
    return `Codex Desktop does not have an open owner for this chat, so ${method} could not be routed. Open that chat in Codex Desktop and try again.`;
  }
  return `Codex Desktop rejected ${method}: ${error}`;
}
