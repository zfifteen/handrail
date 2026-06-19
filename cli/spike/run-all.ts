#!/usr/bin/env node
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const spikeDir = dirname(fileURLToPath(import.meta.url));
const spikes = [
  "01-list-sessions.ts",
  "02-parse-transcript.ts",
  "03-acp-approval.ts",
  "04-resume-session.ts"
];

interface SpikeResult {
  name: string;
  ok: boolean;
  exitCode: number | null;
  output: string;
}

async function runSpike(name: string): Promise<SpikeResult> {
  const scriptPath = join(spikeDir, name);
  return await new Promise((resolve) => {
    const child = spawn("npx", ["tsx", scriptPath], {
      cwd: join(spikeDir, ".."),
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"]
    });

    let output = "";
    child.stdout.on("data", (chunk: Buffer) => {
      output += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk: Buffer) => {
      output += chunk.toString("utf8");
    });

    child.on("close", (exitCode) => {
      resolve({ name, ok: exitCode === 0, exitCode, output: output.trim() });
    });
  });
}

const results: SpikeResult[] = [];
for (const spike of spikes) {
  results.push(await runSpike(spike));
}

const summary = {
  ranAt: new Date().toISOString(),
  allPassed: results.every((result) => result.ok),
  results: results.map((result) => ({
    spike: result.name,
    ok: result.ok,
    exitCode: result.exitCode,
    output: result.output
  }))
};

console.log(JSON.stringify(summary, null, 2));
process.exit(summary.allPassed ? 0 : 1);