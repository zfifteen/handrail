import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";

export interface AgentProcess {
  child: ChildProcessWithoutNullStreams;
  acceptsInput: boolean;
  send(text: string): void;
  stop(): void;
}

function parseAgentCommand(): { command: string; args: string[] } {
  const raw = process.env.HANDRAIL_AGENT_COMMAND || defaultAgentCommand();
  const parts = raw.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) {
    throw new Error("HANDRAIL_AGENT_COMMAND is empty.");
  }
  return { command: parts[0], args: parts.slice(1) };
}

function defaultAgentCommand(): string {
  const bundledCodex = "/Applications/Codex.app/Contents/Resources/codex";
  if (existsSync(bundledCodex)) {
    return `${bundledCodex} exec --json --color never`;
  }
  return "codex exec --json --color never";
}

export function formatAgentOutput(text: string): string {
  return text
    .replace(/<head>[\s\S]*?<\/html>/gi, "")
    .split(/\r?\n/)
    .map(formatAgentLine)
    .filter((line) => line.length > 0)
    .join("\n");
}

export function startAgent(repo: string, prompt?: string, resumeSessionId?: string): AgentProcess {
  const { command, args } = parseAgentCommand();
  const promptText = prompt?.trim();
  const childArgs = resumeSessionId ? resumeArgs(command, args, resumeSessionId, promptText) : promptText ? [...args, promptText] : args;
  const child = spawn(command, childArgs, {
    cwd: repo,
    env: {
      ...process.env,
      TERM: process.env.TERM && process.env.TERM !== "dumb" ? process.env.TERM : "xterm-256color"
    },
    stdio: "pipe"
  });
  const commandName = command.split("/").at(-1) ?? command;
  const closesStdinAfterPrompt = commandName === "codex" && childArgs[0] === "exec";
  if (closesStdinAfterPrompt) {
    child.stdin.end();
  }

  return {
    child,
    acceptsInput: !closesStdinAfterPrompt,
    send(text: string) {
      if (child.stdin.writableEnded || child.stdin.destroyed) {
        return;
      }
      child.stdin.write(text.endsWith("\n") ? text : `${text}\n`);
    },
    stop() {
      child.kill("SIGTERM");
    }
  };
}

function resumeArgs(command: string, args: string[], sessionId: string, prompt?: string): string[] {
  const commandName = command.split("/").at(-1) ?? command;
  if (commandName !== "codex" || args[0] !== "exec") {
    throw new Error("Continuing archived Codex chats requires HANDRAIL_AGENT_COMMAND to use `codex exec`.");
  }

  const options = args.slice(1).filter((arg, index, all) => {
    if (arg === "--color") {
      return false;
    }
    if (index > 0 && all[index - 1] === "--color") {
      return false;
    }
    return true;
  });
  return prompt ? ["exec", "resume", ...options, sessionId, prompt] : ["exec", "resume", ...options, sessionId];
}

function formatAgentLine(line: string): string {
  const trimmed = stripAnsi(line).trim();
  if (trimmed.length === 0) {
    return "";
  }
  if (trimmed === "Reading additional input from stdin...") {
    return "";
  }
  if (/^\d{4}-\d{2}-\d{2}T.*ERROR codex_core::session: failed to record rollout items/.test(trimmed)) {
    return "";
  }

  if (/^\d{4}-\d{2}-\d{2}T.*\s+WARN\s+/.test(trimmed)) {
    const marker = trimmed.indexOf("Codex error:");
    if (marker === -1) {
      return "";
    }
    return formatAgentLine(trimmed.slice(marker + "Codex error:".length).trim());
  }

  const jsonStart = trimmed.indexOf("{");
  if (jsonStart === -1) {
    return trimmed;
  }

  const prefix = trimmed.slice(0, jsonStart).trim();
  const jsonText = trimmed.slice(jsonStart);
  try {
    const event = JSON.parse(jsonText) as Record<string, unknown>;
    const formatted = formatCodexJsonEvent(event);
    if (!formatted) {
      return prefix;
    }
    if (prefix === "Codex error:") {
      return formatted;
    }
    return prefix ? `${prefix} ${formatted}` : formatted;
  } catch {
    return trimmed;
  }
}

function formatCodexJsonEvent(event: Record<string, unknown>): string {
  switch (event.type) {
    case "thread.started":
      return typeof event.thread_id === "string" ? `Codex thread started: ${event.thread_id}` : "Codex thread started.";
    case "turn.started":
      return "Codex started.";
    case "turn.completed":
      return "Codex completed.";
    case "item.completed":
      return formatCompletedItem(event.item);
    case "turn.failed":
      return `Codex failed: ${extractMessage(event.error)}`;
    case "error":
      return `Codex error: ${extractMessage(event)}`;
    default:
      return "";
  }
}

function formatCompletedItem(item: unknown): string {
  if (!item || typeof item !== "object") {
    return "";
  }
  const record = item as Record<string, unknown>;
  if (record.type === "agent_message" && typeof record.text === "string") {
    return record.text;
  }
  return "";
}

function extractMessage(value: unknown): string {
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.startsWith("{")) {
      try {
        return extractMessage(JSON.parse(trimmed));
      } catch {
        return value;
      }
    }
    return value;
  }
  if (value && typeof value === "object" && "message" in value) {
    const message = (value as { message?: unknown }).message;
    return extractMessage(message);
  }
  if (value && typeof value === "object" && "error" in value) {
    return extractMessage((value as { error?: unknown }).error);
  }
  return JSON.stringify(value);
}

function stripAnsi(text: string): string {
  return text
    .replace(/\x1B\][^\x07]*(?:\x07|\x1B\\)/g, "")
    .replace(/\x1B\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/\x1B[()][A-Za-z0-9]/g, "")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "");
}
