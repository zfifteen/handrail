import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { createInterface, type Interface } from "node:readline";
import { grokBinary } from "./grokPaths.js";

export interface AcpSpawnOptions {
  cwd: string;
  extraArgs?: string[];
  requestTimeoutMs?: number;
}

export interface AcpPermissionRequest {
  requestId: number;
  params: Record<string, unknown>;
}

type PendingRequest = {
  resolve(value: unknown): void;
  reject(error: Error): void;
};

/**
 * Minimal ACP stdio client for Phase 0 spikes.
 * Handrail Phase 1 will replace this with a fuller adapter (grokBuildAcp.ts).
 */
export class AcpStdioClient {
  private proc: ChildProcessWithoutNullStreams | null = null;
  private reader: Interface | null = null;
  private nextId = 1;
  private pending = new Map<number, PendingRequest>();
  private permissionHandler: ((request: AcpPermissionRequest) => Promise<Record<string, unknown>>) | null = null;
  private notificationHandler: ((method: string, params: Record<string, unknown>) => void) | null = null;

  constructor(private readonly spawnOptions: AcpSpawnOptions) {}

  async start(): Promise<void> {
    const args = [
      "--sandbox",
      "workspace",
      "--tools",
      "read_file,grep,list_dir,write,run_terminal_cmd",
      ...(this.spawnOptions.extraArgs ?? []),
      "agent",
      "--no-leader",
      "stdio"
    ];

    this.proc = spawn(grokBinary(), args, {
      cwd: this.spawnOptions.cwd,
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env }
    });

    this.reader = createInterface({ input: this.proc.stdout });
    this.reader.on("line", (line) => void this.handleLine(line));

    this.proc.stderr.on("data", (chunk: Buffer) => {
      const text = chunk.toString("utf8").trim();
      if (text.length > 0) {
        process.stderr.write(`[grok stderr] ${text}\n`);
      }
    });
  }

  onPermission(handler: (request: AcpPermissionRequest) => Promise<Record<string, unknown>>): void {
    this.permissionHandler = handler;
  }

  onNotification(handler: (method: string, params: Record<string, unknown>) => void): void {
    this.notificationHandler = handler;
  }

  async initialize(): Promise<Record<string, unknown>> {
    const result = await this.request("initialize", {
      protocolVersion: 1,
      clientCapabilities: {
        fs: { readTextFile: true, writeTextFile: true },
        terminal: true
      },
      clientInfo: { name: "handrail-spike", version: "0.1.0" }
    });
    return result as Record<string, unknown>;
  }

  async newSession(cwd: string): Promise<string> {
    const result = await this.request("session/new", { cwd, mcpServers: [] }) as { sessionId?: string };
    if (!result.sessionId) {
      throw new Error("session/new did not return sessionId.");
    }
    return result.sessionId;
  }

  async loadSession(sessionId: string, cwd: string): Promise<Record<string, unknown>> {
    return await this.request("session/load", { sessionId, cwd, mcpServers: [] }) as Record<string, unknown>;
  }

  async prompt(sessionId: string, text: string): Promise<Record<string, unknown>> {
    return await this.request("session/prompt", {
      sessionId,
      prompt: [{ type: "text", text }]
    }) as Record<string, unknown>;
  }

  async request(method: string, params: Record<string, unknown>): Promise<unknown> {
    const id = this.nextId++;
    const payload = JSON.stringify({ jsonrpc: "2.0", id, method, params });
    this.proc?.stdin.write(`${payload}\n`);

    const timeoutMs = this.spawnOptions.requestTimeoutMs ?? 120_000;
    return await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (!this.pending.has(id)) {
          return;
        }
        this.pending.delete(id);
        reject(new Error(`ACP request timed out after ${timeoutMs}ms: ${method}`));
      }, timeoutMs);

      this.pending.set(id, {
        resolve: (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        }
      });
    });
  }

  async close(): Promise<void> {
    this.reader?.close();
    this.proc?.stdin.end();
    this.proc?.kill("SIGTERM");
    this.proc = null;
  }

  private async handleLine(line: string): Promise<void> {
    let message: Record<string, unknown>;
    try {
      message = JSON.parse(line) as Record<string, unknown>;
    } catch {
      return;
    }

    const method = typeof message.method === "string" ? message.method : null;
    const id = typeof message.id === "number" ? message.id : null;
    const params = (message.params ?? {}) as Record<string, unknown>;

    if (id !== null && method) {
      await this.handleIncomingRequest(id, method, params);
      return;
    }

    if (method && this.notificationHandler) {
      this.notificationHandler(method, params);
    }

    if (id !== null && ("result" in message || "error" in message)) {
      const pending = this.pending.get(id);
      if (!pending) {
        return;
      }
      this.pending.delete(id);
      if ("error" in message) {
        pending.reject(new Error(JSON.stringify(message.error)));
        return;
      }
      pending.resolve(message.result);
    }
  }

  private async handleIncomingRequest(id: number, method: string, params: Record<string, unknown>): Promise<void> {
    if (method === "session/request_permission") {
      await this.respond(id, await this.buildPermissionResult(id, params));
      return;
    }

    if (method === "fs/read_text_file") {
      const path = String(params.path ?? "");
      try {
        const content = await readFile(path, "utf8");
        await this.respond(id, { content });
      } catch {
        await this.respond(id, { content: "" });
      }
      return;
    }

    if (method === "fs/write_text_file") {
      const path = String(params.path ?? "");
      const content = String(params.content ?? "");
      await writeFile(path, content, "utf8");
      await this.respond(id, {});
      return;
    }

    await this.respond(id, {});
  }

  private async buildPermissionResult(id: number, params: Record<string, unknown>): Promise<Record<string, unknown>> {
    if (this.permissionHandler) {
      return await this.permissionHandler({ requestId: id, params });
    }

    const options = Array.isArray(params.options) ? params.options as Array<Record<string, unknown>> : [];
    const allowOption = options.find((option) => String(option.name ?? "").toLowerCase().includes("allow"))
      ?? options[0];
    const optionId = String(allowOption?.optionId ?? allowOption?.id ?? "allow");
    return { outcome: { outcome: "selected", optionId } };
  }

  private async respond(id: number, result: Record<string, unknown>): Promise<void> {
    const response = JSON.stringify({ jsonrpc: "2.0", id, result });
    this.proc?.stdin.write(`${response}\n`);
  }
}