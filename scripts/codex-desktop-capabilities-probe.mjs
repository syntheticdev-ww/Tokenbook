#!/usr/bin/env node

import { spawn } from "node:child_process";
import readline from "node:readline";

const cliPath = process.env.CODEX_CLI_PATH || "codex";
const cwd = process.cwd();
const child = spawn(cliPath, ["app-server", "--stdio"], {
  stdio: ["pipe", "pipe", "pipe"],
  env: process.env,
});

const requests = new Map([
  [2, { key: "accountUsage", method: "account/usage/read" }],
  [3, { key: "threads", method: "thread/list", params: { cwd, limit: 100 } }],
  [4, { key: "hooks", method: "hooks/list", params: { cwds: [cwd] } }],
  [5, { key: "plugins", method: "plugin/list", params: { cwds: [cwd] } }],
  [6, { key: "apps", method: "app/list", params: { limit: 100 } }],
]);
const results = {};
let stderr = "";
let settled = false;

function countBy(values) {
  return values.reduce((counts, value) => {
    const key = String(value ?? "unknown");
    counts[key] = (counts[key] ?? 0) + 1;
    return counts;
  }, {});
}

function send(message) {
  child.stdin.write(`${JSON.stringify(message)}\n`);
}

function sanitize(key, result) {
  if (key === "accountUsage") {
    return {
      available: result.summary?.lifetimeTokens != null,
      hasDailyBuckets: Array.isArray(result.dailyUsageBuckets),
      dailyBucketCount: result.dailyUsageBuckets?.length ?? 0,
    };
  }
  if (key === "threads") {
    const threads = Array.isArray(result.data) ? result.data : [];
    return {
      count: threads.length,
      statusCounts: countBy(threads.map((thread) => thread.status?.type)),
      sourceCounts: countBy(
        threads.map((thread) =>
          typeof thread.source === "string"
            ? thread.source
            : Object.keys(thread.source ?? {})[0],
        ),
      ),
      hasMore: result.nextCursor != null,
    };
  }
  if (key === "hooks") {
    const entries = Array.isArray(result.data) ? result.data : [];
    const hooks = entries.flatMap((entry) => entry.hooks ?? []);
    return {
      cwdCount: entries.length,
      hookCount: hooks.length,
      enabledCount: hooks.filter((hook) => hook.enabled).length,
      eventCounts: countBy(hooks.map((hook) => hook.eventName)),
      trustCounts: countBy(hooks.map((hook) => hook.trustStatus)),
      sourceCounts: countBy(hooks.map((hook) => hook.source)),
      hooks: hooks.map((hook) => ({
        eventName: hook.eventName ?? null,
        handlerType: hook.handlerType ?? null,
        enabled: Boolean(hook.enabled),
        source: hook.source ?? null,
        trustStatus: hook.trustStatus ?? null,
        isManaged: Boolean(hook.isManaged),
        async: hook.async ?? null,
      })),
      errorCount: entries.reduce(
        (total, entry) => total + (entry.errors?.length ?? 0),
        0,
      ),
      warningCount: entries.reduce(
        (total, entry) => total + (entry.warnings?.length ?? 0),
        0,
      ),
    };
  }
  if (key === "plugins") {
    const marketplaces = Array.isArray(result.marketplaces)
      ? result.marketplaces
      : [];
    const plugins = marketplaces.flatMap((marketplace) => marketplace.plugins ?? []);
    return {
      marketplaceCount: marketplaces.length,
      pluginCount: plugins.length,
      installedCount: plugins.filter((plugin) => plugin.installed).length,
      enabledCount: plugins.filter((plugin) => plugin.enabled).length,
      installed: plugins
        .filter((plugin) => plugin.installed)
        .map((plugin) => ({
          id: plugin.id,
          name: plugin.name,
          enabled: Boolean(plugin.enabled),
          sourceType: plugin.source?.type ?? "unknown",
          capabilities: plugin.interface?.capabilities ?? [],
        })),
      loadErrorCount: result.marketplaceLoadErrors?.length ?? 0,
    };
  }
  if (key === "apps") {
    const apps = Array.isArray(result.data) ? result.data : [];
    return {
      count: apps.length,
      accessibleCount: apps.filter((app) => app.isAccessible).length,
      enabledCount: apps.filter((app) => app.isEnabled !== false).length,
      hasMore: result.nextCursor != null,
    };
  }
  return { available: true };
}

function finish(exitCode) {
  if (settled) return;
  settled = true;
  clearTimeout(timer);
  process.stdout.write(
    `${JSON.stringify(
      {
        schemaVersion: 1,
        source: "codex-app-server",
        stability: {
          accountUsage: "stable-v2-protocol",
          threads: "stable-v2-protocol",
          hooks: "stable-v2-protocol",
          plugins: "stable-v2-protocol",
          apps: "experimental-protocol",
        },
        results,
      },
      null,
      2,
    )}\n`,
  );
  child.kill("SIGTERM");
  process.exitCode = exitCode;
}

const timer = setTimeout(() => {
  for (const request of requests.values()) {
    if (!results[request.key]) results[request.key] = { error: "timeout" };
  }
  finish(1);
}, 55_000);

child.stderr.on("data", (chunk) => {
  stderr += chunk.toString("utf8");
  if (stderr.length > 4_096) stderr = stderr.slice(-4_096);
});
child.on("error", (error) => {
  results.appServer = { error: error.message };
  finish(1);
});
child.on("exit", (code) => {
  if (!settled) {
    results.appServer = {
      error: `App Server exited before all responses (code ${code})`,
      hasDiagnostic: Boolean(stderr.trim()),
    };
    finish(1);
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
      results.appServer = { error: message.error.message ?? "initialize failed" };
      finish(1);
      return;
    }
    send({ method: "initialized", params: {} });
    for (const [id, request] of requests) {
      send({ method: request.method, id, ...(request.params ? { params: request.params } : {}) });
    }
    return;
  }

  const request = requests.get(message.id);
  if (!request) return;
  results[request.key] = message.error
    ? { error: message.error.message ?? "request failed" }
    : sanitize(request.key, message.result ?? {});
  requests.delete(message.id);
  if (requests.size === 0) {
    const hasErrors = Object.values(results).some((result) => result.error);
    finish(hasErrors ? 2 : 0);
  }
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
    capabilities: { experimentalApi: true },
  },
});
