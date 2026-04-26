export type SessionStatus = "running" | "waiting_for_approval" | "completed" | "failed" | "stopped" | "idle";

export interface SessionRecord {
  id: string;
  repo: string;
  title: string;
  status: SessionStatus;
  startedAt: string;
  updatedAt?: string;
  endedAt?: string;
  exitCode?: number | null;
  files?: string[];
  source?: "handrail" | "codex";
  transcript?: string[];
  acceptsInput?: boolean;
}

export interface HandrailState {
  protocolVersion: 1;
  port: number;
  machineName: string;
  defaultRepo?: string;
  pairingToken?: string;
  sessions: SessionRecord[];
}

export interface PairingPayload {
  protocolVersion: 1;
  host: string;
  port: number;
  token: string;
  machineName: string;
}

export type ClientMessage =
  | { type: "hello"; token: string }
  | { type: "start_session"; repo: string; title: string; prompt?: string }
  | { type: "continue_session"; sessionId: string; prompt: string }
  | { type: "send_input"; sessionId: string; text: string }
  | { type: "approve"; sessionId: string; approvalId: string }
  | { type: "deny"; sessionId: string; approvalId: string; reason?: string }
  | { type: "stop_session"; sessionId: string };

export interface ApprovalRequest {
  sessionId: string;
  approvalId: string;
  title: string;
  summary: string;
  files: string[];
  diff: string;
}

export type ServerMessage =
  | { type: "machine_status"; machineName: string; online: boolean; defaultRepo?: string }
  | { type: "session_list"; sessions: SessionRecord[] }
  | { type: "session_started"; session: SessionRecord }
  | { type: "session_event"; sessionId: string; event: { kind: string; text?: string; status?: SessionStatus; at?: string } }
  | ({ type: "approval_required" } & ApprovalRequest)
  | { type: "command_result"; ok: true; message: string }
  | { type: "error"; message: string };
