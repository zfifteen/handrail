import { createHash } from "node:crypto";
import { basename } from "node:path";
import { apnsConfigFromEnv, sendApnsNotification, type ApnsConfig } from "./apns.js";
import type { ChatRecord, HandrailState, NotificationEvent, NotificationEventKind, PushDeviceRegistration } from "./types.js";

export type PersistState = (state: HandrailState) => Promise<void>;
export type PushSender = (device: PushDeviceRegistration, event: NotificationEvent) => Promise<void>;

export class NotificationDispatcher {
  private readonly reportedFailures = new Set<string>();

  constructor(
    private readonly state: HandrailState,
    private readonly persistState: PersistState,
    private readonly sendPush: PushSender = defaultPushSender
  ) {}

  async registerPushToken(input: {
    deviceToken: string;
    environment: "sandbox" | "production";
    deviceName?: string;
  }): Promise<void> {
    if (typeof input.deviceToken !== "string" || !input.deviceToken.trim()) {
      throw new Error("APNs device token is required.");
    }
    if (input.environment !== "sandbox" && input.environment !== "production") {
      throw new Error("APNs environment must be sandbox or production.");
    }
    this.state.pushDevice = {
      deviceToken: input.deviceToken,
      environment: input.environment,
      deviceName: input.deviceName,
      registeredAt: new Date().toISOString()
    };
    await this.persistState(this.state);
  }

  async notifyVisibleChats(chats: ChatRecord[], reportError: (message: string) => void): Promise<void> {
    for (const chat of chats) {
      const event = notificationEventForChat(chat);
      if (!event) {
        continue;
      }
      try {
        await this.send(event);
      } catch (error) {
        if (!this.reportedFailures.has(event.eventId)) {
          this.reportedFailures.add(event.eventId);
          reportError((error as Error).message);
        }
      }
    }
  }

  async notifyChat(chat: ChatRecord): Promise<void> {
    const event = notificationEventForChat(chat);
    if (event) {
      await this.send(event);
    }
  }

  private async send(event: NotificationEvent): Promise<void> {
    if (this.hasSent(event.eventId)) {
      return;
    }
    if (!this.state.pushDevice) {
      return;
    }
    await this.sendPush(this.state.pushDevice, event);
    this.state.sentNotificationEventIds = [...(this.state.sentNotificationEventIds ?? []), event.eventId];
    await this.persistState(this.state);
  }

  private hasSent(eventId: string): boolean {
    return (this.state.sentNotificationEventIds ?? []).includes(eventId);
  }
}

export function notificationEventForChat(chat: ChatRecord): NotificationEvent | null {
  if (chat.status === "completed") {
    return eventForChat(chat, "completed", "Codex task completed", notificationChatLabel(chat));
  }
  if (chat.status === "failed") {
    return eventForChat(chat, "failed", "Codex task failed", notificationChatLabel(chat));
  }
  if (chat.status === "waiting_for_approval") {
    return eventForChat(chat, "approval_required", "Codex approval required", notificationChatLabel(chat));
  }
  const inputMarker = latestInputRequiredMarker(chat.transcript);
  if (inputMarker) {
    return eventForChat(chat, "input_required", "Codex input required", notificationChatLabel(chat), inputMarker);
  }
  return null;
}

export function defaultPushSender(device: PushDeviceRegistration, event: NotificationEvent): Promise<void> {
  const config = apnsConfigFromEnv();
  if (device.environment !== config.environment) {
    throw new Error(`APNs device token is ${device.environment}, but HANDRAIL_APNS_ENVIRONMENT is ${config.environment}.`);
  }
  return sendApnsNotification(config, device, event);
}

export function configuredPushSender(config: ApnsConfig): PushSender {
  return (device, event) => {
    if (device.environment !== config.environment) {
      throw new Error(`APNs device token is ${device.environment}, but APNs config is ${config.environment}.`);
    }
    return sendApnsNotification(config, device, event);
  };
}

function eventForChat(
  chat: ChatRecord,
  kind: NotificationEventKind,
  title: string,
  body: string,
  marker?: string
): NotificationEvent {
  const at = chat.updatedAt ?? chat.endedAt ?? chat.startedAt;
  const markerPart = marker ? `:${hash(marker)}` : "";
  return {
    eventId: `${chat.id}:${kind}:${at}${markerPart}`,
    chatId: chat.id,
    kind,
    title,
    body,
    at
  };
}

function notificationChatLabel(chat: ChatRecord): string {
  for (const value of [chat.title, chat.projectName, basename(chat.repo)]) {
    const label = value?.trim();
    if (label && !isRawCodexIdentifier(label)) {
      return label;
    }
  }
  return "Codex chat";
}

function isRawCodexIdentifier(value: string): boolean {
  const candidate = value.replace(/^codex:/i, "");
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(candidate);
}

function latestInputRequiredMarker(transcript: string[] | undefined): string | null {
  if (!transcript) {
    return null;
  }
  for (let index = transcript.length - 1; index >= 0; index -= 1) {
    if (transcript[index].toLowerCase().includes("input required")) {
      return transcript[index];
    }
  }
  return null;
}

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}
