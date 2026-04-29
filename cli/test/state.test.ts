import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { loadState, saveState } from "../src/state.js";
import type { HandrailState } from "../src/types.js";

test("state stores pairing metadata without chat records", async () => {
  const previousHome = process.env.HOME;
  const tempDir = await mkdtemp(join(tmpdir(), "handrail-state-"));
  process.env.HOME = tempDir;

  const state: HandrailState = {
    protocolVersion: 1,
    port: 8788,
    machineName: "Test Mac",
    pairingToken: "token",
    defaultRepo: "/Users/me/project"
  };

  try {
    await saveState(state);
    const storedRaw = await readFile(join(tempDir, ".handrail", "state.json"), "utf8");
    const stored = JSON.parse(storedRaw) as HandrailState & { sessions?: unknown };
    const loaded = await loadState();

    assert.equal(stored.sessions, undefined);
    assert.deepEqual(loaded, state);
  } finally {
    if (previousHome === undefined) {
      delete process.env.HOME;
    } else {
      process.env.HOME = previousHome;
    }
    await rm(tempDir, { recursive: true, force: true });
  }
});
