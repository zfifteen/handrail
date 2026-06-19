import test from "node:test";
import assert from "node:assert/strict";
import { grokApprovalFromToolCall } from "../src/grokBuildAcp.js";

test("grokApprovalFromToolCall maps execute tool calls to command approvals", () => {
  const approval = grokApprovalFromToolCall({
    kind: "execute",
    title: "Run npm test",
    rawInput: { command: "npm", args: ["test", "--coverage"] }
  });

  assert.deepEqual(approval, {
    title: "Command approval required",
    summary: "npm test --coverage",
    files: []
  });
});

test("grokApprovalFromToolCall maps write tool calls to file approvals", () => {
  const approval = grokApprovalFromToolCall({
    kind: "write",
    title: "Write file",
    rawInput: { path: "/tmp/example.txt" }
  });

  assert.deepEqual(approval, {
    title: "File change approval required",
    summary: "Modify /tmp/example.txt",
    files: ["/tmp/example.txt"]
  });
});