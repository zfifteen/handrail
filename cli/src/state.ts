import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir, hostname } from "node:os";
import { dirname, join } from "node:path";
import { randomBytes } from "node:crypto";
import type { HandrailState, SessionRecord } from "./types.js";

const DEFAULT_PORT = 8787;

export function statePath(): string {
  return join(homedir(), ".handrail", "state.json");
}

export async function loadState(): Promise<HandrailState> {
  try {
    const raw = await readFile(statePath(), "utf8");
    const parsed = JSON.parse(raw) as HandrailState;
    return {
      protocolVersion: 1,
      port: parsed.port ?? DEFAULT_PORT,
      machineName: parsed.machineName || hostname(),
      defaultRepo: parsed.defaultRepo,
      pairingToken: parsed.pairingToken,
      sessions: Array.isArray(parsed.sessions) ? parsed.sessions : []
    };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      throw error;
    }
    return {
      protocolVersion: 1,
      port: DEFAULT_PORT,
      machineName: hostname(),
      defaultRepo: process.cwd(),
      sessions: []
    };
  }
}

export async function saveState(state: HandrailState): Promise<void> {
  await mkdir(dirname(statePath()), { recursive: true });
  await writeFile(statePath(), `${JSON.stringify(state, null, 2)}\n`, "utf8");
}

export async function ensurePairingToken(): Promise<HandrailState> {
  const state = await loadState();
  let changed = false;
  if (!state.pairingToken) {
    state.pairingToken = randomBytes(24).toString("base64url");
    changed = true;
  }
  if (!state.defaultRepo) {
    state.defaultRepo = process.cwd();
    changed = true;
  }
  if (changed) {
    await saveState(state);
  }
  return state;
}

export async function clearPairingToken(): Promise<void> {
  const state = await loadState();
  delete state.pairingToken;
  await saveState(state);
}

export async function upsertSession(record: SessionRecord): Promise<void> {
  const state = await loadState();
  const index = state.sessions.findIndex((session) => session.id === record.id);
  if (index === -1) {
    state.sessions.unshift(record);
  } else {
    state.sessions[index] = record;
  }
  await saveState(state);
}
