#!/usr/bin/env node
import { Command } from "commander";
import qrcode from "qrcode-terminal";
import WebSocket from "ws";
import { clearPairingToken, ensurePairingToken, loadState } from "./state.js";
import { isPortOpen, localNetworkHost, pairingPayload, startServer } from "./server.js";
import type { ServerMessage } from "./types.js";

const program = new Command();

program
  .name("handrail")
  .description("Local-first iOS remote control for Codex CLI sessions.")
  .version("0.1.0");

program.command("pair")
  .description("Print a pairing QR code and start the local Handrail server if needed.")
  .action(async () => {
    const state = await ensurePairingToken();
    const host = localNetworkHost();
    const payload = pairingPayload(host, state.port, state.pairingToken!, state.machineName);
    const encoded = JSON.stringify(payload);

    console.log("Scan this QR code with Handrail on iOS:");
    qrcode.generate(encoded, { small: true });
    console.log(encoded);

    if (await isPortOpen(state.port)) {
      console.log(`Handrail server already appears to be listening on port ${state.port}.`);
      return;
    }

    await startServer();
  });

program.command("serve")
  .description("Start the local Handrail WebSocket server.")
  .action(async () => {
    await startServer();
  });

program.command("start")
  .requiredOption("--repo <path>", "Repository path")
  .requiredOption("--title <title>", "Session title")
  .option("--prompt <prompt>", "Initial prompt to send to Codex")
  .description("Start a new Codex CLI session through the running Handrail server.")
  .action(async (options: { repo: string; title: string; prompt?: string }) => {
    const state = await loadState();
    if (!state.pairingToken) {
      throw new Error("No pairing token. Run `handrail pair` first.");
    }
    await sendLocalServerMessage({
      type: "start_session",
      repo: options.repo,
      title: options.title,
      prompt: options.prompt
    }, "session_started");
  });

program.command("sessions")
  .description("List known Codex Desktop chats.")
  .action(async () => {
    const sessions = await fetchLocalSessions();
    for (const session of sessions) {
      console.log(`${session.id}\t${session.status}\t${session.title}\t${session.repo}`);
    }
  });

program.command("stop")
  .argument("<session-id>", "Session id")
  .description("Stop a running session.")
  .action(async (sessionId: string) => {
    await sendLocalServerMessage({ type: "stop_session", sessionId }, "command_result");
  });

program.command("unpair")
  .description("Clear Handrail pairing tokens.")
  .action(async () => {
    await clearPairingToken();
    console.log("Handrail pairing token cleared.");
  });

program.parseAsync().catch((error) => {
  console.error(error.message);
  process.exit(1);
});

async function sendLocalServerMessage(message: object, expectedType: ServerMessage["type"]): Promise<void> {
  const state = await loadState();
  if (!state.pairingToken) {
    throw new Error("No pairing token. Run `handrail pair` first.");
  }

  await new Promise<void>((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${state.port}`);
    let resolved = false;
    let authed = false;

    ws.once("error", (error) => reject(error));
    ws.once("open", () => {
      ws.send(JSON.stringify({ type: "hello", token: state.pairingToken }));
    });
    ws.on("message", (data) => {
      const serverMessage = JSON.parse(data.toString()) as ServerMessage;
      if (!authed && serverMessage.type === "machine_status") {
        authed = true;
        ws.send(JSON.stringify(message));
        return;
      }
      if (serverMessage.type === expectedType) {
        if (serverMessage.type === "session_started") {
          console.log(`Started ${serverMessage.session.id}`);
        }
        resolved = true;
        ws.close();
        resolve();
      }
      if (serverMessage.type === "error") {
        reject(new Error(serverMessage.message));
      }
    });
    ws.once("close", () => {
      if (!resolved) {
        reject(new Error("Handrail server closed before confirming the command."));
      }
    });
  });
}

async function fetchLocalSessions(): Promise<Extract<ServerMessage, { type: "session_list" }>["sessions"]> {
  const state = await loadState();
  if (!state.pairingToken) {
    throw new Error("No pairing token. Run `handrail pair` first.");
  }

  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${state.port}`);
    let resolved = false;

    ws.once("error", (error) => reject(error));
    ws.once("open", () => {
      ws.send(JSON.stringify({ type: "hello", token: state.pairingToken }));
    });
    ws.on("message", (data) => {
      const serverMessage = JSON.parse(data.toString()) as ServerMessage;
      if (serverMessage.type === "session_list") {
        resolved = true;
        ws.close();
        resolve(serverMessage.sessions);
      }
      if (serverMessage.type === "error") {
        reject(new Error(serverMessage.message));
      }
    });
    ws.once("close", () => {
      if (!resolved) {
        reject(new Error("Handrail server closed before sending sessions."));
      }
    });
  });
}
