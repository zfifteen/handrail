import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir, hostname } from "node:os";
import { dirname, join } from "node:path";
import { randomBytes } from "node:crypto";
import type { HandrailState } from "./types.js";

const DEFAULT_PORT = 8787;

export function statePath(): string {
  return join(homedir(), ".handrail", "state.json");
}

export async function loadState(): Promise<HandrailState> {
  try {
    const raw = await readFile(statePath(), "utf8");
    const parsed = JSON.parse(raw) as HandrailState;
    const state: HandrailState = {
      protocolVersion: 1,
      port: parsed.port ?? DEFAULT_PORT,
      machineName: parsed.machineName || hostname(),
      defaultRepo: parsed.defaultRepo,
      pairingToken: parsed.pairingToken
    };
    if (parsed.pushDevice) {
      state.pushDevice = parsed.pushDevice;
    }
    if (parsed.sentNotificationEventIds) {
      state.sentNotificationEventIds = parsed.sentNotificationEventIds;
    }
    return state;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      throw error;
    }
    return {
      protocolVersion: 1,
      port: DEFAULT_PORT,
      machineName: hostname(),
      defaultRepo: process.cwd()
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
