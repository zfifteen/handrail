export type ChatStatus = "running" | "waiting_for_approval" | "completed" | "failed" | "stopped" | "idle";

export interface ChatRecord {
  id: string;
  repo: string;
  title: string;
  projectName?: string;
  status: ChatStatus;
  startedAt: string;
  updatedAt?: string;
  endedAt?: string;
  exitCode?: number | null;
  files?: string[];
  transcript?: string[];
  thinking?: ThinkingEntry[];
  acceptsInput?: boolean;
  isPinned?: boolean;
  pinnedOrder?: number;
}

export interface ThinkingEntry {
  id: string;
  round: number;
  text: string;
  at?: string;
}

export type NewChatWorkMode = "local" | "worktree";
export type NewChatAccessPreset = "full_access" | "on_request" | "read_only";
export type NewChatReasoning = "low" | "medium" | "high" | "xhigh";

export interface NewChatProject {
  id: string;
  name: string;
  path: string | null;
}

export interface NewChatBranch {
  name: string;
  isCurrent: boolean;
}

export interface NewChatOptions {
  projects: NewChatProject[];
  defaultProjectId: string;
  branches: NewChatBranch[];
  defaultBranch: string;
  workModes: NewChatWorkMode[];
  accessPresets: NewChatAccessPreset[];
  defaultAccessPreset: NewChatAccessPreset;
  models: string[];
  defaultModel: string;
  reasoningEfforts: NewChatReasoning[];
  defaultReasoningEffort: NewChatReasoning;
}

export interface StartChatOptions {
  prompt: string;
  projectId: string;
  projectPath?: string | null;
  workMode: NewChatWorkMode;
  branch: string;
  newBranch?: string;
  accessPreset: NewChatAccessPreset;
  model: string;
  reasoningEffort: NewChatReasoning;
}

export interface HandrailState {
  protocolVersion: 1;
  port: number;
  machineName: string;
  defaultRepo?: string;
  pairingToken?: string;
  pushDevice?: PushDeviceRegistration;
  sentNotificationEventIds?: string[];
}

export type PushEnvironment = "sandbox" | "production";

export interface PushDeviceRegistration {
  deviceToken: string;
  environment: PushEnvironment;
  deviceName?: string;
  registeredAt: string;
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
  | { type: "register_push_token"; deviceToken: string; environment: PushEnvironment; deviceName?: string }
  | ({ type: "start_chat" } & StartChatOptions)
  | { type: "continue_chat"; chatId: string; prompt: string }
  | { type: "send_chat_input"; chatId: string; text: string }
  | { type: "approve"; chatId: string; approvalId: string }
  | { type: "deny"; chatId: string; approvalId: string; reason?: string }
  | { type: "stop_chat"; chatId: string };

export interface ApprovalRequest {
  chatId: string;
  approvalId: string;
  title: string;
  summary: string;
  files: string[];
  diff: string;
}

export type NotificationEventKind = "completed" | "failed" | "approval_required" | "input_required";

export interface NotificationEvent {
  eventId: string;
  chatId: string;
  kind: NotificationEventKind;
  title: string;
  body: string;
  at: string;
}

export type ServerMessage =
  | { type: "machine_status"; machineName: string; online: boolean; defaultRepo?: string }
  | { type: "new_chat_options"; options: NewChatOptions }
  | { type: "chat_list"; chats: ChatRecord[] }
  | { type: "chat_started"; chat: ChatRecord }
  | { type: "chat_event"; chatId: string; event: { kind: string; text?: string; status?: ChatStatus; at?: string } }
  | ({ type: "approval_required" } & ApprovalRequest)
  | { type: "command_result"; ok: true; message: string }
  | { type: "error"; message: string };
