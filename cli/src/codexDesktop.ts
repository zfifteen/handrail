import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const DESKTOP_SOURCE = "vscode";

export interface DesktopThreadPromotion {
  databasePath: string;
  sql: string;
  args: string[];
}

export async function promoteCodexThreadToDesktop(threadId: string, title: string, firstUserMessage: string): Promise<void> {
  const promotion = desktopThreadPromotion(threadId, title, firstUserMessage, Date.now());
  await execFileAsync("sqlite3", [
    promotion.databasePath,
    promotion.sql,
    ...promotion.args
  ]);
}

export function desktopThreadPromotion(threadId: string, title: string, firstUserMessage: string, nowMs: number): DesktopThreadPromotion {
  const nowSeconds = Math.floor(nowMs / 1000);
  return {
    databasePath: join(homedir(), ".codex", "state_5.sqlite"),
    sql: [
      "UPDATE threads",
      "SET source = ?,",
      "title = CASE WHEN title = '' OR source = 'exec' THEN ? ELSE title END,",
      "first_user_message = CASE WHEN first_user_message = '' THEN ? ELSE first_user_message END,",
      "has_user_event = 1,",
      "updated_at = CASE WHEN updated_at < ? THEN ? ELSE updated_at END,",
      "updated_at_ms = CASE WHEN updated_at_ms < ? THEN ? ELSE updated_at_ms END",
      "WHERE id = ?;"
    ].join(" "),
    args: [
      DESKTOP_SOURCE,
      title,
      firstUserMessage,
      String(nowSeconds),
      String(nowSeconds),
      String(nowMs),
      String(nowMs),
      threadId
    ]
  };
}

