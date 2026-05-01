#!/usr/bin/env node

import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { createConnection } from "node:net";
import { tmpdir, userInfo } from "node:os";
import { join } from "node:path";

const REQUEST_TIMEOUT_MS = 15000;
const INITIALIZING_CLIENT_ID = "initializing-client";

const args = process.argv.slice(2);

if (args.length !== 1) {
  console.error("Usage: node scripts/run-codex-automation-now.mjs <automation-id>");
  process.exit(2);
}

const [automationId] = args;

class CodexDesktopIpcClient {
  constructor(socketPath) {
    this.socketPath = socketPath;
    this.buffer = Buffer.alloc(0);
    this.clientId = INITIALIZING_CLIENT_ID;
    this.inflight = new Map();
    this.socket = null;
  }

  connect() {
    return new Promise((resolve, reject) => {
      const socket = createConnection(this.socketPath);
      this.socket = socket;

      socket.once("connect", resolve);
      socket.once("error", reject);
      socket.on("data", (chunk) => this.handleData(chunk));
      socket.on("close", () => {
        for (const { method, reject: rejectRequest } of this.inflight.values()) {
          rejectRequest(new Error(`Codex Desktop IPC socket closed while waiting for ${method}.`));
        }
        this.inflight.clear();
      });
    });
  }

  close() {
    this.socket?.end();
  }

  async initialize() {
    const result = await this.request("initialize", { clientType: "handrail" });
    if (result && typeof result === "object" && typeof result.clientId === "string") {
      this.clientId = result.clientId;
    }
  }

  request(method, params) {
    const requestId = randomUUID();
    const message = {
      type: "request",
      requestId,
      sourceClientId: this.clientId,
      version: method.startsWith("thread-follower-") ? 1 : 0,
      method,
      params
    };

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.inflight.delete(requestId);
        reject(new Error(`Codex Desktop IPC request timed out: ${method}`));
      }, REQUEST_TIMEOUT_MS);

      this.inflight.set(requestId, {
        method,
        resolve: (result) => {
          clearTimeout(timeout);
          resolve(result);
        },
        reject: (error) => {
          clearTimeout(timeout);
          reject(error);
        }
      });

      this.socket.write(encodeCodexDesktopIpcFrame(message));
    });
  }

  handleData(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);

    while (this.buffer.length >= 4) {
      const length = this.buffer.readUInt32LE(0);
      if (this.buffer.length < 4 + length) {
        return;
      }

      const frame = this.buffer.subarray(4, 4 + length).toString("utf8");
      this.buffer = this.buffer.subarray(4 + length);
      this.handleFrame(frame);
    }
  }

  handleFrame(frame) {
    let message;
    try {
      message = JSON.parse(frame);
    } catch (error) {
      throw new Error(`Codex Desktop IPC returned invalid JSON: ${error.message}`);
    }

    if (message.type !== "response" || typeof message.requestId !== "string") {
      return;
    }

    const request = this.inflight.get(message.requestId);
    if (!request) {
      return;
    }

    this.inflight.delete(message.requestId);
    if (message.resultType === "error") {
      request.reject(new Error(`Codex Desktop rejected ${request.method}: ${message.error}`));
      return;
    }

    request.resolve(message.result);
  }
}

function encodeCodexDesktopIpcFrame(message) {
  const json = JSON.stringify(message);
  const length = Buffer.byteLength(json);
  const frame = Buffer.alloc(4 + length);
  frame.writeUInt32LE(length, 0);
  frame.write(json, 4);
  return frame;
}

function codexDesktopIpcSocketPath() {
  const uid = userInfo().uid;
  const socketName = uid == null ? "ipc.sock" : `ipc-${uid}.sock`;
  return join(tmpdir(), "codex-ipc", socketName);
}

async function main() {
  const socketPath = codexDesktopIpcSocketPath();
  if (!existsSync(socketPath)) {
    throw new Error(`Codex Desktop IPC socket does not exist: ${socketPath}`);
  }

  const client = new CodexDesktopIpcClient(socketPath);
  await client.connect();
  try {
    await client.initialize();
    await client.request("automation-run-now", {
      id: automationId,
      collaborationMode: null,
      permissions: null
    });
  } finally {
    client.close();
  }

  console.log(`Run now requested for ${automationId}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
