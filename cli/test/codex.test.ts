import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { join } from "node:path";
import { formatAgentOutput, startAgent } from "../src/codex.js";

test("starts configured agent with initial prompt as an argument", async () => {
  const previousCommand = process.env.HANDRAIL_AGENT_COMMAND;
  process.env.HANDRAIL_AGENT_COMMAND = `${process.execPath} ${join(process.cwd(), "test/fixtures/fake-agent.mjs")}`;

  try {
    const agent = startAgent(process.cwd(), "Hello from Handrail");
    let output = "";
    agent.child.stdout.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    const [code] = await once(agent.child, "exit");

    assert.equal(code, 0);
    assert.match(output, /prompt:Hello from Handrail/);
  } finally {
    if (previousCommand === undefined) {
      delete process.env.HANDRAIL_AGENT_COMMAND;
    } else {
      process.env.HANDRAIL_AGENT_COMMAND = previousCommand;
    }
  }
});

test("formats Codex JSON events into readable transcript lines", () => {
  const output = formatAgentOutput([
    "{\"type\":\"thread.started\",\"thread_id\":\"abc\"}",
    "{\"type\":\"turn.started\"}",
    "2026-04-25T09:43:20.843471Z  WARN codex_core::plugins::manifest: noisy startup warning",
    "<head><meta name=\"viewport\" /></head><body>challenge</body></html>",
    "{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"text\":\"done\"}}",
    "{\"type\":\"error\",\"message\":\"{\\\"error\\\":{\\\"message\\\":\\\"boom\\\"}}\"}"
  ].join("\n"));

  assert.equal(output, [
    "Codex thread started: abc",
    "Codex started.",
    "done",
    "Codex error: boom"
  ].join("\n"));
});
