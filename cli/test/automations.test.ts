import test from "node:test";
import assert from "node:assert/strict";
import { parseAutomationToml } from "../src/automations.js";

test("parses active cron automations for mobile display", () => {
  assert.deepEqual(parseAutomationToml([
    "version = 1",
    "id = \"finish-handrail-ipad-app\"",
    "kind = \"cron\"",
    "name = \"Finish Handrail iPad App\"",
    "prompt = \"Continue the iPad app.\"",
    "status = \"ACTIVE\"",
    "rrule = \"FREQ=HOURLY;INTERVAL=1\"",
    "model = \"gpt-5.2\"",
    "reasoning_effort = \"high\"",
    "execution_environment = \"local\"",
    "cwds = [\"/Users/me/IdeaProjects/handrail\"]"
  ].join("\n")), {
    id: "finish-handrail-ipad-app",
    name: "Finish Handrail iPad App",
    kind: "cron",
    status: "ACTIVE",
    prompt: "Continue the iPad app.",
    rrule: "FREQ=HOURLY;INTERVAL=1",
    scheduleText: "Hourly",
    contextText: "handrail",
    projectName: "handrail",
    targetThreadId: undefined,
    model: "gpt-5.2",
    reasoningEffort: "high",
    executionEnvironment: "local",
    cwds: ["/Users/me/IdeaProjects/handrail"]
  });
});

test("parses heartbeat target threads for mobile display", () => {
  const targetThreads = new Map([
    ["019dddba-dd9c-7140-b913-09bb7d645043", {
      cwd: "/Users/me/IdeaProjects/handrail",
      title: "Handrail Bug Fixes"
    }]
  ]);

  assert.deepEqual(parseAutomationToml([
    "version = 1",
    "id = \"handrail-bug-fix\"",
    "kind = \"heartbeat\"",
    "name = \"Handrail Bug Fix\"",
    "prompt = \"Fix the top bug.\"",
    "status = \"ACTIVE\"",
    "rrule = \"RRULE:FREQ=MINUTELY;INTERVAL=240\"",
    "target_thread_id = \"019dddba-dd9c-7140-b913-09bb7d645043\""
  ].join("\n"), targetThreads), {
    id: "handrail-bug-fix",
    name: "Handrail Bug Fix",
    kind: "heartbeat",
    status: "ACTIVE",
    prompt: "Fix the top bug.",
    rrule: "RRULE:FREQ=MINUTELY;INTERVAL=240",
    scheduleText: "Every 240m",
    contextText: "Heartbeat • Handrail Bug Fixes",
    projectName: "handrail",
    targetThreadId: "019dddba-dd9c-7140-b913-09bb7d645043",
    model: undefined,
    reasoningEffort: undefined,
    executionEnvironment: undefined,
    cwds: []
  });
});
