#!/usr/bin/env node
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { AcpStdioClient, type AcpPermissionRequest } from "./lib/acpClient.js";

async function main(): Promise<void> {
  const spikeDir = await mkdtemp(join(tmpdir(), "handrail-spike-acp-"));
  const targetFile = join(spikeDir, "spike-test.txt");
  let permissionSeen = false;
  let permissionTool = "";

  const client = new AcpStdioClient({ cwd: spikeDir });
  client.onPermission(async (request: AcpPermissionRequest) => {
    permissionSeen = true;
    const toolCall = request.params.toolCall as Record<string, unknown> | undefined;
    permissionTool = String(toolCall?.title ?? toolCall?.kind ?? "unknown");

    const options = Array.isArray(request.params.options)
      ? request.params.options as Array<Record<string, unknown>>
      : [];
    const allowOption = options.find((option) => String(option.name ?? "").toLowerCase().includes("allow"))
      ?? options[0];
    const optionId = String(allowOption?.optionId ?? allowOption?.id ?? "allow");

    return { outcome: { outcome: "selected", optionId } };
  });

  try {
    await client.start();
    await client.initialize();
    const sessionId = await client.newSession(spikeDir);

    const promptResult = await client.prompt(
      sessionId,
      "Use the write tool to create spike-test.txt containing exactly: handrail-spike-ok"
    );

    const fileText = await readFile(targetFile, "utf8").catch(() => "");
    const fileOk = fileText.trim() === "handrail-spike-ok";
    const payload = {
      spike: "03-acp-approval",
      ok: fileOk && (permissionSeen || (promptResult as { stopReason?: string }).stopReason === "end_turn"),
      sessionId,
      spikeDir,
      permissionSeen,
      permissionTool,
      fileText: fileText.trim(),
      promptStopReason: (promptResult as { stopReason?: string }).stopReason ?? null
    };

    await writeFile(join(spikeDir, "result.json"), JSON.stringify(payload, null, 2));
    console.log(JSON.stringify(payload, null, 2));
    process.exit(payload.ok ? 0 : 1);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(JSON.stringify({ spike: "03-acp-approval", ok: false, error: message, spikeDir }, null, 2));
    process.exit(1);
  } finally {
    await client.close();
  }
}

void main();