import test from "node:test";
import assert from "node:assert/strict";
import { looksLikeApprovalRequest } from "../src/approvals.js";

test("detects approval-like Codex output", () => {
  assert.equal(looksLikeApprovalRequest("Do you want to proceed with these edits? y/n"), true);
  assert.equal(looksLikeApprovalRequest("Permission required before running tests."), true);
  assert.equal(looksLikeApprovalRequest("Wrote src/server.ts"), false);
});
