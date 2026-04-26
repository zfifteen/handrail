import { createServer } from "node:http";
import { networkInterfaces } from "node:os";
import { Socket } from "node:net";
import { WebSocketServer, WebSocket } from "ws";
import type { ClientMessage, PairingPayload, ServerMessage } from "./types.js";
import { ensurePairingToken, loadState } from "./state.js";
import { SessionManager } from "./sessions.js";

interface AuthedSocket extends WebSocket {
  isAuthed?: boolean;
}

export function localNetworkHost(): string {
  const interfaces = networkInterfaces();
  const names = Object.keys(interfaces).sort();
  for (const name of names) {
    for (const address of interfaces[name] ?? []) {
      if (address.family === "IPv4" && !address.internal) {
        return address.address;
      }
    }
  }
  throw new Error("No non-internal IPv4 address found. Handrail pairing requires local network access.");
}

export function pairingPayload(host: string, port: number, token: string, machineName: string): PairingPayload {
  return {
    protocolVersion: 1,
    host,
    port,
    token,
    machineName
  };
}

export async function isPortOpen(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = new Socket();
    socket.once("connect", () => {
      socket.destroy();
      resolve(true);
    });
    socket.once("error", () => resolve(false));
    socket.connect(port, "127.0.0.1");
  });
}

export async function startServer(): Promise<void> {
  const state = await ensurePairingToken();
  const httpServer = createServer();
  const wss = new WebSocketServer({ server: httpServer });

  const broadcast = (message: ServerMessage) => {
    const encoded = JSON.stringify(message);
    for (const client of wss.clients) {
      const socket = client as AuthedSocket;
      if (socket.isAuthed && socket.readyState === WebSocket.OPEN) {
        socket.send(encoded);
      }
    }
  };

  const sessions = new SessionManager(broadcast);

  wss.on("connection", (socket: AuthedSocket) => {
    socket.on("message", (data) => {
      void handleMessage(socket, data.toString(), state.pairingToken!, sessions, broadcast);
    });
  });

  await new Promise<void>((resolve, reject) => {
    httpServer.once("error", reject);
    httpServer.listen(state.port, () => resolve());
  });

  console.log(`Handrail server listening on ws://0.0.0.0:${state.port}`);
}

async function handleMessage(
  socket: AuthedSocket,
  raw: string,
  token: string,
  sessions: SessionManager,
  broadcast: (message: ServerMessage) => void
): Promise<void> {
  let message: ClientMessage;
  try {
    message = JSON.parse(raw) as ClientMessage;
  } catch {
    socket.send(JSON.stringify({ type: "error", message: "Invalid JSON." } satisfies ServerMessage));
    return;
  }

  if (!socket.isAuthed) {
    if (message.type !== "hello" || message.token !== token) {
      socket.close(1008, "Invalid Handrail pairing token.");
      return;
    }
    socket.isAuthed = true;
    const state = await loadState();
    socket.send(JSON.stringify({
      type: "machine_status",
      machineName: state.machineName,
      online: true,
      defaultRepo: state.defaultRepo
    } satisfies ServerMessage));
    socket.send(JSON.stringify({ type: "session_list", sessions: await sessions.list() } satisfies ServerMessage));
    return;
  }

  try {
    switch (message.type) {
      case "hello":
        socket.send(JSON.stringify({ type: "session_list", sessions: await sessions.list() } satisfies ServerMessage));
        break;
      case "start_session":
        await sessions.start(message.repo, message.title, message.prompt);
        break;
      case "continue_session":
        await sessions.continue(message.sessionId, message.prompt);
        break;
      case "send_input":
        sessions.sendInput(message.sessionId, message.text);
        break;
      case "approve":
        sessions.approve(message.sessionId, message.approvalId);
        broadcast({ type: "session_list", sessions: await sessions.list() });
        break;
      case "deny":
        sessions.deny(message.sessionId, message.approvalId, message.reason);
        broadcast({ type: "session_list", sessions: await sessions.list() });
        break;
      case "stop_session":
        sessions.stop(message.sessionId);
        socket.send(JSON.stringify({ type: "command_result", ok: true, message: "Session stop requested." } satisfies ServerMessage));
        break;
    }
  } catch (error) {
    socket.send(JSON.stringify({ type: "error", message: (error as Error).message } satisfies ServerMessage));
  }
}
