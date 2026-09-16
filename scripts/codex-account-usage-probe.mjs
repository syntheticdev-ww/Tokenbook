#!/usr/bin/env node

import { spawn } from "node:child_process";
import readline from "node:readline";

function parseArguments(argv) {
  const options = { threadId: null };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--thread-id") {
      options.threadId = argv[++index] ?? null;
      if (!options.threadId) throw new Error("--thread-id requires a value");
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

const options = parseArguments(process.argv.slice(2));
const cliPath = process.env.CODEX_CLI_PATH || "codex";
const timeoutMs = 15_000;
const child = spawn(cliPath, ["app-server", "--stdio"], {
  stdio: ["pipe", "pipe", "pipe"],
  env: process.env,
});

let stderr = "";
let settled = false;

function send(message) {
  child.stdin.write(`${JSON.stringify(message)}\n`);
}

function finish(exitCode, output) {
  if (settled) return;
  settled = true;
  clearTimeout(timer);
  if (output) process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
  child.kill("SIGTERM");
  process.exitCode = exitCode;
}

const timer = setTimeout(() => {
  finish(1, {
    schemaVersion: 1,
    source: "codex-app-server-account-usage",
    available: false,
    error: "Timed out waiting for account/usage/read",
  });
}, timeoutMs);

child.stderr.on("data", (chunk) => {
  stderr += chunk.toString("utf8");
  if (stderr.length > 4_096) stderr = stderr.slice(-4_096);
});

child.on("error", (error) => {
  finish(1, {
    schemaVersion: 1,
    source: "codex-app-server-account-usage",
    available: false,
    error: error.message,
  });
});

child.on("exit", (code) => {
  if (!settled) {
    finish(1, {
      schemaVersion: 1,
      source: "codex-app-server-account-usage",
      available: false,
      error: `App Server exited before responding (code ${code})`,
      detail: stderr.trim() || undefined,
    });
  }
});

const lines = readline.createInterface({ input: child.stdout });
lines.on("line", (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }

  if (message.id === 1) {
    if (message.error) {
      finish(1, {
        schemaVersion: 1,
        source: "codex-app-server-account-usage",
        available: false,
        error: message.error.message ?? "Initialization failed",
      });
      return;
    }

    send({ method: "initialized", params: {} });
    send({
      method: "account/usage/read",
      id: 2,
      ...(options.threadId ? { params: { threadId: options.threadId } } : {}),
    });
    return;
  }

  if (message.id !== 2) return;
  if (message.error) {
    finish(2, {
      schemaVersion: 1,
      source: "codex-app-server-account-usage",
      available: false,
      error: message.error.message ?? "account/usage/read failed",
    });
    return;
  }

  const result = message.result ?? {};
  const buckets = Array.isArray(result.dailyUsageBuckets)
    ? result.dailyUsageBuckets
    : null;
  const threadUsage = result.threadUsage ?? null;
  finish(0, {
    schemaVersion: 1,
    source: "codex-app-server-account-usage",
    stability: "stable-v2-protocol",
    available: true,
    summary: {
      lifetimeTokens: result.summary?.lifetimeTokens ?? null,
      peakDailyTokens: result.summary?.peakDailyTokens ?? null,
      currentStreakDays: result.summary?.currentStreakDays ?? null,
      longestStreakDays: result.summary?.longestStreakDays ?? null,
      longestRunningTurnSec: result.summary?.longestRunningTurnSec ?? null,
    },
    dailyUsage: buckets,
    threadUsage: threadUsage
      ? {
          threadId: threadUsage.threadId ?? null,
          groups: Array.isArray(threadUsage.groups)
            ? threadUsage.groups.map((group) => ({
                model: group.model ?? null,
                reasoningEffort: group.reasoningEffort ?? null,
                speed: group.speed ?? null,
                inputTokens: group.inputTokens ?? null,
                cachedInputTokens: group.cachedInputTokens ?? null,
                netNewInputTokens: group.netNewInputTokens ?? null,
                outputTokens: group.outputTokens ?? null,
                totalTokens: group.totalTokens ?? null,
              }))
            : [],
        }
      : null,
    coverage: {
      hasLifetimeTokens: result.summary?.lifetimeTokens != null,
      hasDailyBuckets: buckets != null,
      dailyBucketCount: buckets?.length ?? 0,
      firstDate: buckets?.[0]?.startDate ?? null,
      lastDate: buckets?.at(-1)?.startDate ?? null,
      hasThreadUsage: threadUsage != null,
      threadUsageGroupCount: threadUsage?.groups?.length ?? 0,
    },
  });
});

send({
  method: "initialize",
  id: 1,
  params: {
    clientInfo: {
      name: "tokenbook-probe",
      title: "Tokenbook compatibility probe",
      version: "0.0.0",
    },
    capabilities: {
      experimentalApi: false,
    },
  },
});
