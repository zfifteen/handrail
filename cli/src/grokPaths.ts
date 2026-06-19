import { homedir } from "node:os";
import { join } from "node:path";

export function grokHome(): string {
  return process.env.GROK_HOME?.trim() || join(homedir(), ".grok");
}

export function grokSessionsRoot(): string {
  return join(grokHome(), "sessions");
}

export function grokActiveSessionsPath(): string {
  return join(grokHome(), "active_sessions.json");
}

export function grokBinary(): string {
  return process.env.GROK_BIN?.trim() || join(grokHome(), "bin", "grok");
}