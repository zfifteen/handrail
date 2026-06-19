import { spawn, type ChildProcess, type ChildProcessWithoutNullStreams } from "node:child_process";

import { readFile, writeFile } from "node:fs/promises";
import { createInterface, type Interface } from "node:readline";
import { readFile as readActiveFile } from "node:fs/promises";
import { grokActiveSessionsPath, grokBinary } from "./grokPaths.js";
import type { NewChatAccessPreset, NewChatReasoning } from "./types.js";

export interface GrokConversationInput {
  cwd: string;
  prompt: string;
  model: string;
  reasoningEffort: NewChatReasoning;
  accessPreset: NewChatAccessPreset;
}

export interface GrokTurnInput {
  sessionId: string;
  cwd: string;
  prompt: string;
  model?: string;
  reasoningEffort?: NewChatReasoning;
  accessPreset?: NewChatAccessPreset;
}

export type GrokApprovalDecision = "accept" | "decline";

export interface GrokApprovalRequest {
  sessionId: string;
  approvalId: string;
  title: string;
  summary: string;
  files: string[];
  diff: string;
  respond(decision: GrokApprovalDecision): Promise<void>;
}

export type GrokLiveEventKind = "turn_started" | "turn_completed" | "turn_failed" | "turn_interrupted" | "output";

export interface GrokLiveEvent {
  sessionId: string;
  kind: GrokLiveEventKind;
  text?: string;
}

const activeSessions = new Map<string, GrokAcpSession>();

interface ManagedTerminal {
  proc: ChildProcess;
  output: string;
  outputByteLimit: number;
  exited: boolean;
  exitCode: number | null;
  signal: NodeJS.Signals | null;
}

class GrokTerminalManager {
  private readonly terminals = new Map<string, ManagedTerminal>();
  private nextId = 1;

  create(params: Record<string, unknown>): { terminalId: string } {
    const command = String(params.command ?? "");
    const args = Array.isArray(params.args) ? params.args.map(String) : [];
    const cwd = String(params.cwd ?? process.cwd());
    const outputByteLimit = typeof params.outputByteLimit === "number" ? params.outputByteLimit : 1_048_576;
    const proc = spawn(command, args, {
      cwd,
      env: this.buildEnv(params.env),
      shell: false,
      stdio: ["ignore", "pipe", "pipe"]
    });
    const terminalId = `term_${this.nextId++}`;
    const managed: ManagedTerminal = {
      proc,
      output: "",
      outputByteLimit,
      exited: false,
      exitCode: null,
      signal: null
    };

    const append = (chunk: string) => {
      managed.output += chunk;
      while (Buffer.byteLength(managed.output, "utf8") > outputByteLimit && managed.output.length > 0) {
        managed.output = managed.output.slice(1);
      }
    };

    proc.stdout?.on("data", (buffer) => append(buffer.toString("utf8")));
    proc.stderr?.on("data", (buffer) => append(buffer.toString("utf8")));
    proc.on("close", (code, signal) => {
      managed.exited = true;
      managed.exitCode = code;
      managed.signal = signal;
    });

    this.terminals.set(terminalId, managed);
    return { terminalId };
  }

  output(terminalId: string): Record<string, unknown> {
    const terminal = this.require(terminalId);
    const result: Record<string, unknown> = {
      output: terminal.output,
      truncated: Buffer.byteLength(terminal.output, "utf8") >= terminal.outputByteLimit
    };
    if (terminal.exited) {
      result.exitStatus = { exitCode: terminal.exitCode, signal: terminal.signal };
    }
    return result;
  }

  async waitForExit(terminalId: string): Promise<Record<string, unknown>> {
    const terminal = this.require(terminalId);
    if (!terminal.exited) {
      await new Promise<void>((resolve) => {
        terminal.proc.once("close", () => resolve());
      });
    }
    return { exitCode: terminal.exitCode, signal: terminal.signal };
  }

  kill(terminalId: string): void {
    this.require(terminalId).proc.kill("SIGTERM");
  }

  release(terminalId: string): void {
    const terminal = this.terminals.get(terminalId);
    if (!terminal) {
      return;
    }
    if (!terminal.exited) {
      terminal.proc.kill("SIGKILL");
    }
    this.terminals.delete(terminalId);
  }

  private require(terminalId: string): ManagedTerminal {
    const terminal = this.terminals.get(terminalId);
    if (!terminal) {
      throw new Error(`Unknown terminal: ${terminalId}`);
    }
    return terminal;
  }

  private buildEnv(envVars: unknown): NodeJS.ProcessEnv {
    const base = { ...process.env };
    if (!Array.isArray(envVars)) {
      return base;
    }
    for (const entry of envVars) {
      if (!entry || typeof entry !== "object") {
        continue;
      }
      const name = String((entry as Record<string, unknown>).name ?? "");
      const value = String((entry as Record<string, unknown>).value ?? "");
      if (name) {
        base[name] = value;
      }
    }
    return base;
  }
}

export function grokApprovalFromToolCall(toolCall: Record<string, unknown>): {
  title: string;
  summary: string;
  files: string[];
} {
  const kind = String(toolCall.kind ?? "");
  const title = String(toolCall.title ?? "Tool approval");
  const rawInput = toolCall.rawInput ?? toolCall.input ?? toolCall.arguments;
  let summary = title;
  const files: string[] = [];

  if (typeof rawInput === "string") {
    summary = rawInput.trim() || title;
  } else if (rawInput && typeof rawInput === "object") {
    const input = rawInput as Record<string, unknown>;
    if (typeof input.command === "string") {
      const args = Array.isArray(input.args) ? input.args.map(String).join(" ") : "";
      summary = args ? `${input.command} ${args}` : input.command;
    } else if (typeof input.path === "string") {
      summary = `Modify ${input.path}`;
      files.push(input.path);
    } else {
      summary = JSON.stringify(rawInput, null, 2);
    }
  }

  if (kind === "execute") {
    return { title: "Command approval required", summary, files };
  }
  if (kind === "edit" || kind === "write") {
    return { title: "File change approval required", summary, files };
  }
  return { title, summary, files };
}

export async function startGrokConversation(
  input: GrokConversationInput,
  onApprovalRequest?: (request: GrokApprovalRequest) => void,
  onLiveEvent?: (event: GrokLiveEvent) => void
): Promise<string> {
  const session = new GrokAcpSession(input.cwd, grokSpawnArgs(input), onApprovalRequest, onLiveEvent);
  await session.start();
  const sessionId = await session.createSession(input.cwd);
  activeSessions.set(sessionId, session);
  void session.runPrompt(sessionId, input.prompt).finally(() => {
    activeSessions.delete(sessionId);
    void session.close();
  });
  return sessionId;
}

export async function continueGrokTurn(
  input: GrokTurnInput,
  onApprovalRequest?: (request: GrokApprovalRequest) => void,
  onLiveEvent?: (event: GrokLiveEvent) => void
): Promise<void> {
  const useLeader = await sessionIsActiveOnLeader(input.sessionId);
  const session = new GrokAcpSession(
    input.cwd,
    grokSpawnArgs({
      cwd: input.cwd,
      prompt: input.prompt,
      model: input.model ?? "grok-build",
      reasoningEffort: input.reasoningEffort ?? "high",
      accessPreset: input.accessPreset ?? "on_request"
    }, useLeader),
    onApprovalRequest,
    onLiveEvent
  );
  await session.start();
  await session.loadSession(input.sessionId, input.cwd);
  activeSessions.set(input.sessionId, session);
  await session.runPrompt(input.sessionId, input.prompt);
  activeSessions.delete(input.sessionId);
  await session.close();
}

export async function interruptGrokTurn(sessionId: string): Promise<void> {
  const session = activeSessions.get(sessionId);
  if (!session) {
    return;
  }
  await session.cancel(sessionId);
  activeSessions.delete(sessionId);
  await session.close();
}

export function grokAccessArgs(preset: NewChatAccessPreset): string[] {
  switch (preset) {
    case "full_access":
      return ["--always-approve"];
    case "read_only":
      return ["--sandbox", "read-only"];
    case "on_request":
      return ["--sandbox", "workspace"];
  }
}

function grokSpawnArgs(input: GrokConversationInput, useLeader = false): string[] {
  const args = [
    ...grokAccessArgs(input.accessPreset),
    "-m",
    input.model,
    "--effort",
    input.reasoningEffort,
    "--tools",
    "read_file,grep,list_dir,write,run_terminal_cmd",
    "agent",
    useLeader ? "--leader" : "--no-leader",
    "stdio"
  ];
  return args;
}

async function sessionIsActiveOnLeader(sessionId: string): Promise<boolean> {
  try {
    const rows = JSON.parse(await readActiveFile(grokActiveSessionsPath(), "utf8")) as Array<{ session_id: string }>;
    return rows.some((row) => row.session_id === sessionId);
  } catch {
    return false;
  }
}

class GrokAcpSession {
  private proc: ChildProcessWithoutNullStreams | null = null;
  private reader: Interface | null = null;
  private nextId = 1;
  private readonly pending = new Map<number, { resolve(value: unknown): void; reject(error: Error): void }>();
  private readonly terminals = new GrokTerminalManager();
  constructor(
    private readonly cwd: string,
    private readonly spawnArgs: string[],
    private readonly onApprovalRequest?: (request: GrokApprovalRequest) => void,
    private readonly onLiveEvent?: (event: GrokLiveEvent) => void
  ) {}

  async start(): Promise<void> {
    this.proc = spawn(grokBinary(), this.spawnArgs, {
      cwd: this.cwd,
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env }
    });
    this.reader = createInterface({ input: this.proc.stdout });
    this.reader.on("line", (line) => void this.handleLine(line));
    await this.request("initialize", {
      protocolVersion: 1,
      clientCapabilities: {
        fs: { readTextFile: true, writeTextFile: true },
        terminal: true
      },
      clientInfo: { name: "handrail", version: "0.2.0" }
    });
  }

  async createSession(cwd: string): Promise<string> {
    const result = await this.request("session/new", { cwd, mcpServers: [] }) as { sessionId?: string };
    if (!result.sessionId) {
      throw new Error("Grok did not return a session id.");
    }
    return result.sessionId;
  }

  async loadSession(sessionId: string, cwd: string): Promise<void> {
    await this.request("session/load", { sessionId, cwd, mcpServers: [] });
  }

  async runPrompt(sessionId: string, prompt: string): Promise<void> {
    this.onLiveEvent?.({ sessionId, kind: "turn_started" });
    try {
      const result = await this.request("session/prompt", {
        sessionId,
        prompt: [{ type: "text", text: prompt }]
      }) as { stopReason?: string };
      const kind = result.stopReason === "cancelled" ? "turn_interrupted" : "turn_completed";
      this.onLiveEvent?.({ sessionId, kind });
    } catch (error) {
      this.onLiveEvent?.({
        sessionId,
        kind: "turn_failed",
        text: error instanceof Error ? error.message : String(error)
      });
      throw error;
    }
  }

  async cancel(sessionId: string): Promise<void> {
    this.proc?.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "session/cancel", params: { sessionId } })}\n`);
  }

  async close(): Promise<void> {
    this.reader?.close();
    this.proc?.stdin.end();
    this.proc?.kill("SIGTERM");
    this.proc = null;
  }

  private async request(method: string, params: Record<string, unknown>): Promise<unknown> {
    const id = this.nextId++;
    this.proc?.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    return await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (!this.pending.has(id)) {
          return;
        }
        this.pending.delete(id);
        reject(new Error(`Grok ACP request timed out: ${method}`));
      }, 300_000);
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

    if (method === "session/update") {
      this.handleSessionUpdate(params);
      return;
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

  private handleSessionUpdate(params: Record<string, unknown>): void {
    const sessionId = String(params.sessionId ?? "");
    const update = (params.update ?? {}) as Record<string, unknown>;
    const kind = String(update.sessionUpdate ?? "");
    if (kind === "agent_message_chunk") {
      const content = (update.content ?? {}) as { text?: string };
      if (content.text) {
        this.onLiveEvent?.({ sessionId, kind: "output", text: content.text });
      }
    }
  }

  private async handleIncomingRequest(id: number, method: string, params: Record<string, unknown>): Promise<void> {
    if (method === "session/request_permission") {
      if (this.onApprovalRequest) {
        await this.deferPermissionResponse(id, params);
      } else {
        await this.respond(id, this.autoApprovePermission(params));
      }
      return;
    }

    if (method === "fs/read_text_file") {
      const path = String(params.path ?? "");
      try {
        await this.respond(id, { content: await readFile(path, "utf8") });
      } catch {
        await this.respond(id, { content: "" });
      }
      return;
    }

    if (method === "fs/write_text_file") {
      await writeFile(String(params.path ?? ""), String(params.content ?? ""), "utf8");
      await this.respond(id, {});
      return;
    }

    if (method === "terminal/create") {
      await this.respond(id, this.terminals.create(params));
      return;
    }

    if (method === "terminal/output") {
      const terminalId = String(params.terminalId ?? "");
      await this.respond(id, this.terminals.output(terminalId));
      return;
    }

    if (method === "terminal/wait_for_exit") {
      const terminalId = String(params.terminalId ?? "");
      await this.respond(id, await this.terminals.waitForExit(terminalId));
      return;
    }

    if (method === "terminal/kill") {
      const terminalId = String(params.terminalId ?? "");
      this.terminals.kill(terminalId);
      await this.respond(id, {});
      return;
    }

    if (method === "terminal/release") {
      const terminalId = String(params.terminalId ?? "");
      this.terminals.release(terminalId);
      await this.respond(id, {});
      return;
    }

    await this.respond(id, {});
  }

  private async deferPermissionResponse(requestId: number, params: Record<string, unknown>): Promise<void> {
    const sessionId = String(params.sessionId ?? "");
    const toolCall = (params.toolCall ?? {}) as Record<string, unknown>;
    const approvalId = String(toolCall.toolCallId ?? params.requestId ?? requestId);
    const options = Array.isArray(params.options) ? params.options as Array<Record<string, unknown>> : [];
    const allowOption = options.find((option) => String(option.name ?? "").toLowerCase().includes("allow")) ?? options[0];
    const denyOption = options.find((option) => String(option.name ?? "").toLowerCase().includes("deny")) ?? options[1];
    const allowOptionId = String(allowOption?.optionId ?? allowOption?.id ?? "allow");
    const denyOptionId = String(denyOption?.optionId ?? denyOption?.id ?? "deny");

    const approval = grokApprovalFromToolCall(toolCall);
    const request: GrokApprovalRequest = {
      sessionId,
      approvalId,
      title: approval.title,
      summary: approval.summary,
      files: approval.files,
      diff: "",
      respond: async (decision) => {
        const optionId = decision === "accept" ? allowOptionId : denyOptionId;
        await this.respond(requestId, { outcome: { outcome: "selected", optionId } });
      }
    };
    this.onApprovalRequest?.(request);
  }

  private autoApprovePermission(params: Record<string, unknown>): Record<string, unknown> {
    const options = Array.isArray(params.options) ? params.options as Array<Record<string, unknown>> : [];
    const allowOption = options.find((option) => String(option.name ?? "").toLowerCase().includes("allow")) ?? options[0];
    const optionId = String(allowOption?.optionId ?? allowOption?.id ?? "allow");
    return { outcome: { outcome: "selected", optionId } };
  }

  private async respond(id: number, result: Record<string, unknown>): Promise<void> {
    this.proc?.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, result })}\n`);
  }
}