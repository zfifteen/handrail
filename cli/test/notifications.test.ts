import test from "node:test";
import assert from "node:assert/strict";
import { buildApnsRequest } from "../src/apns.js";
import { NotificationDispatcher, notificationEventForChat } from "../src/notifications.js";
import type { ChatRecord, HandrailState, NotificationEvent } from "../src/types.js";

const completedChat: ChatRecord = {
  id: "codex:thread-1",
  repo: "/Users/me/project",
  title: "Long task",
  projectName: "project",
  status: "completed",
  startedAt: "2026-04-29T14:00:00.000Z",
  updatedAt: "2026-04-29T14:05:00.000Z"
};

test("builds APNs alert request deterministically", () => {
  const event = notificationEventForChat(completedChat);
  assert.ok(event);

  const request = buildApnsRequest(
    {
      teamId: "TEAMID1234",
      keyId: "KEYID1234",
      topic: "com.velocityworks.Handrail",
      keyPath: "/tmp/AuthKey_KEYID1234.p8",
      environment: "sandbox"
    },
    "abcdef",
    event,
    "provider.jwt"
  );

  assert.deepEqual(request, {
    authority: "api.sandbox.push.apple.com",
    path: "/3/device/abcdef",
    headers: {
      authorization: "bearer provider.jwt",
      "apns-topic": "com.velocityworks.Handrail",
      "apns-push-type": "alert",
      "apns-priority": "10"
    },
    payload: {
      aps: {
        alert: {
          title: "Codex task completed",
          body: "Long task"
        },
        category: "HANDRAIL_CHAT",
        sound: "default"
      },
      chatId: "codex:thread-1",
      eventId: "codex:thread-1:completed:2026-04-29T14:05:00.000Z"
    }
  });
});

test("notification dispatcher sends completed and failed events once", async () => {
  const state = stateWithPushDevice();
  let savedState: HandrailState | undefined;
  const sent: NotificationEvent[] = [];
  const dispatcher = new NotificationDispatcher(
    state,
    async (nextState) => {
      savedState = JSON.parse(JSON.stringify(nextState)) as HandrailState;
    },
    async (_device, event) => {
      sent.push(event);
    }
  );

  const failedChat: ChatRecord = {
    ...completedChat,
    id: "codex:thread-2",
    title: "Broken task",
    status: "failed",
    updatedAt: "2026-04-29T14:07:00.000Z"
  };

  await dispatcher.notifyVisibleChats([completedChat, failedChat], () => {});
  await dispatcher.notifyVisibleChats([completedChat, failedChat], () => {});

  assert.deepEqual(sent.map((event) => event.kind), ["completed", "failed"]);
  assert.deepEqual(savedState?.sentNotificationEventIds, [
    "codex:thread-1:completed:2026-04-29T14:05:00.000Z",
    "codex:thread-2:failed:2026-04-29T14:07:00.000Z"
  ]);

  const reloadedDispatcher = new NotificationDispatcher(
    savedState!,
    async (nextState) => {
      savedState = JSON.parse(JSON.stringify(nextState)) as HandrailState;
    },
    async (_device, event) => {
      sent.push(event);
    }
  );
  await reloadedDispatcher.notifyVisibleChats([completedChat, failedChat], () => {});
  assert.equal(sent.length, 2);
});

test("notification dispatcher reports missing APNs config when push is required", async () => {
  const previousEnv = process.env;
  process.env = { ...previousEnv };
  delete process.env.HANDRAIL_APNS_TEAM_ID;
  delete process.env.HANDRAIL_APNS_KEY_ID;
  delete process.env.HANDRAIL_APNS_TOPIC;
  delete process.env.HANDRAIL_APNS_KEY_PATH;
  delete process.env.HANDRAIL_APNS_ENVIRONMENT;

  const errors: string[] = [];
  const dispatcher = new NotificationDispatcher(stateWithPushDevice(), async () => {});

  try {
    await dispatcher.notifyVisibleChats([completedChat], (message) => errors.push(message));
    assert.deepEqual(errors, ["Missing HANDRAIL_APNS_TEAM_ID."]);
  } finally {
    process.env = previousEnv;
  }
});

test("notification event detects input-required transcript marker", () => {
  const event = notificationEventForChat({
    ...completedChat,
    status: "running",
    transcript: ["Codex:\nInput required before continuing.\n"],
    updatedAt: "2026-04-29T14:08:00.000Z"
  });

  assert.equal(event?.kind, "input_required");
  assert.equal(event?.title, "Codex input required");
  assert.match(event?.eventId ?? "", /^codex:thread-1:input_required:2026-04-29T14:08:00\.000Z:[a-f0-9]{16}$/);
});

test("notification event body falls back from raw Codex ids to a human chat label", () => {
  const rawId = "019dd5d6-86b5-7081-8d93-318872cfb02a";

  assert.equal(
    notificationEventForChat({
      ...completedChat,
      title: `codex:${rawId}`,
      projectName: "Build Handrail MVP"
    })?.body,
    "Build Handrail MVP"
  );

  assert.equal(
    notificationEventForChat({
      ...completedChat,
      title: rawId,
      projectName: undefined,
      repo: "/Users/me/IdeaProjects/handrail"
    })?.body,
    "handrail"
  );

  assert.equal(
    notificationEventForChat({
      ...completedChat,
      status: "running",
      title: `codex:${rawId}`,
      projectName: "Build Handrail MVP",
      transcript: ["Codex:\nInput required before continuing.\n"]
    })?.body,
    "Build Handrail MVP"
  );
});

function stateWithPushDevice(): HandrailState {
  return {
    protocolVersion: 1,
    port: 8787,
    machineName: "Test Mac",
    defaultRepo: "/Users/me/project",
    pairingToken: "token",
    pushDevice: {
      deviceToken: "abcdef",
      environment: "sandbox",
      deviceName: "Test iPhone",
      registeredAt: "2026-04-29T13:00:00.000Z"
    },
    sentNotificationEventIds: []
  };
}
