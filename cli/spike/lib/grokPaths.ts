import { homedir } from "node:os";
import { join } from "node:path";

/** Resolve the Grok home directory (override with GROK_HOME). */
export function grokHome(): string {
  return process.env.GROK_HOME?.trim() || join(homedir(), ".grok");
}

/** Path to on-disk Grok session storage. */
export function grokSessionsRoot(): string {
  return join(grokHome(), "sessions");
}

/** Path to the file that tracks live Grok session PIDs. */
export function grokActiveSessionsPath(): string {
  return join(grokHome(), "active_sessions.json");
}

/** Resolve the Grok CLI binary (override with GROK_BIN). */
export function grokBinary(): string {
  return process.env.GROK_BIN?.trim() || join(grokHome(), "bin", "grok");
}