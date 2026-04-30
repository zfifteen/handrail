import { createSign } from "node:crypto";
import { readFile } from "node:fs/promises";
import { connect } from "node:http2";
import type { NotificationEvent, PushDeviceRegistration, PushEnvironment } from "./types.js";

export interface ApnsConfig {
  teamId: string;
  keyId: string;
  topic: string;
  keyPath: string;
  environment: PushEnvironment;
}

export interface ApnsRequest {
  authority: string;
  path: string;
  headers: Record<string, string>;
  payload: ApnsPayload;
}

interface ApnsPayload {
  aps: {
    alert: {
      title: string;
      body: string;
    };
    category: string;
    sound: "default";
  };
  chatId: string;
  eventId: string;
}

export function apnsConfigFromEnv(env: NodeJS.ProcessEnv = process.env): ApnsConfig {
  const teamId = requiredEnv(env, "HANDRAIL_APNS_TEAM_ID");
  const keyId = requiredEnv(env, "HANDRAIL_APNS_KEY_ID");
  const topic = requiredEnv(env, "HANDRAIL_APNS_TOPIC");
  const keyPath = requiredEnv(env, "HANDRAIL_APNS_KEY_PATH");
  const environment = requiredEnv(env, "HANDRAIL_APNS_ENVIRONMENT");
  if (environment !== "sandbox" && environment !== "production") {
    throw new Error("HANDRAIL_APNS_ENVIRONMENT must be sandbox or production.");
  }
  return { teamId, keyId, topic, keyPath, environment };
}

export async function sendApnsNotification(
  config: ApnsConfig,
  device: PushDeviceRegistration,
  event: NotificationEvent,
  now: Date = new Date()
): Promise<void> {
  const privateKey = await readFile(config.keyPath, "utf8");
  const token = providerToken(config, privateKey, now);
  const request = buildApnsRequest(config, device.deviceToken, event, token);

  await new Promise<void>((resolve, reject) => {
    const client = connect(`https://${request.authority}`);
    let responseBody = "";
    let statusCode = 0;
    client.once("error", reject);
    const stream = client.request({
      ":method": "POST",
      ":path": request.path,
      ...request.headers
    });
    stream.setEncoding("utf8");
    stream.on("response", (headers) => {
      statusCode = Number(headers[":status"] ?? 0);
    });
    stream.on("data", (chunk: string) => {
      responseBody += chunk;
    });
    stream.once("error", reject);
    stream.once("end", () => {
      client.close();
      if (statusCode >= 200 && statusCode < 300) {
        resolve();
        return;
      }
      reject(new Error(`APNs rejected ${event.eventId} with ${statusCode}: ${responseBody}`));
    });
    stream.end(JSON.stringify(request.payload));
  });
}

export function buildApnsRequest(
  config: ApnsConfig,
  deviceToken: string,
  event: NotificationEvent,
  providerJwt: string
): ApnsRequest {
  return {
    authority: config.environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com",
    path: `/3/device/${deviceToken}`,
    headers: {
      authorization: `bearer ${providerJwt}`,
      "apns-topic": config.topic,
      "apns-push-type": "alert",
      "apns-priority": "10"
    },
    payload: {
      aps: {
        alert: {
          title: trimForPayload(event.title),
          body: trimForPayload(event.body)
        },
        category: "HANDRAIL_CHAT",
        sound: "default"
      },
      chatId: event.chatId,
      eventId: event.eventId
    }
  };
}

export function providerToken(config: ApnsConfig, privateKey: string, now: Date = new Date()): string {
  const header = base64urlJson({ alg: "ES256", kid: config.keyId });
  const payload = base64urlJson({ iss: config.teamId, iat: Math.floor(now.getTime() / 1000) });
  const signingInput = `${header}.${payload}`;
  const signer = createSign("SHA256");
  signer.update(signingInput);
  signer.end();
  const signature = signer.sign({ key: privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url");
  return `${signingInput}.${signature}`;
}

function requiredEnv(env: NodeJS.ProcessEnv, key: string): string {
  const value = env[key];
  if (!value) {
    throw new Error(`Missing ${key}.`);
  }
  return value;
}

function base64urlJson(value: unknown): string {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function trimForPayload(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length <= 160) {
    return trimmed;
  }
  return `${trimmed.slice(0, 157)}...`;
}
