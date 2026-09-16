#!/usr/bin/env node

import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const EMPTY_USAGE = Object.freeze({
  inputTokens: 0,
  cachedInputTokens: 0,
  cacheWriteInputTokens: 0,
  outputTokens: 0,
  reasoningOutputTokens: 0,
  totalTokens: 0,
});

function toNonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function normalizeUsage(raw) {
  if (!raw || typeof raw !== "object") return null;

  const usage = {
    inputTokens: toNonNegativeInteger(raw.input_tokens),
    cachedInputTokens: toNonNegativeInteger(raw.cached_input_tokens ?? 0),
    cacheWriteInputTokens: toNonNegativeInteger(
      raw.cache_write_input_tokens ?? 0,
    ),
    outputTokens: toNonNegativeInteger(raw.output_tokens),
    reasoningOutputTokens: toNonNegativeInteger(
      raw.reasoning_output_tokens ?? 0,
    ),
    totalTokens: toNonNegativeInteger(raw.total_tokens),
  };

  return Object.values(usage).some((value) => value === null) ? null : usage;
}

function sameUsage(left, right) {
  return Object.keys(EMPTY_USAGE).every((key) => left[key] === right[key]);
}

function addUsage(total, usage) {
  for (const key of Object.keys(EMPTY_USAGE)) total[key] += usage[key];
}

export function summarizeRollout(text, sourceName = "rollout.jsonl") {
  let session = null;
  let malformedLines = 0;
  let invalidUsageRecords = 0;
  let duplicateResponses = 0;
  let conflictingResponses = 0;
  let latestThreadUsage = null;
  let latestTimestamp = null;
  const turns = new Set();
  const responses = new Map();

  for (const line of text.split("\n")) {
    if (!line.trim()) continue;

    let record;
    try {
      record = JSON.parse(line);
    } catch {
      malformedLines += 1;
      continue;
    }

    if (record.type === "session_meta" && record.payload) {
      session = {
        id: record.payload.id ?? null,
        cwd: record.payload.cwd ?? null,
        originator: record.payload.originator ?? null,
        source: record.payload.source ?? null,
        startedAt: record.payload.timestamp ?? record.timestamp ?? null,
      };
      continue;
    }

    if (record.type !== "token_usage_record" || !record.payload) continue;

    const responseId = record.payload.response_id;
    const usage = normalizeUsage(record.payload.usage);
    if (typeof responseId !== "string" || !usage) {
      invalidUsageRecords += 1;
      continue;
    }

    if (typeof record.payload.turn_id === "string") {
      turns.add(record.payload.turn_id);
    }

    const existing = responses.get(responseId);
    if (existing) {
      duplicateResponses += 1;
      if (!sameUsage(existing, usage)) conflictingResponses += 1;
      continue;
    }

    responses.set(responseId, usage);
    latestTimestamp = record.timestamp ?? latestTimestamp;
    latestThreadUsage =
      normalizeUsage(record.payload.thread_token_usage) ?? latestThreadUsage;
  }

  const usage = { ...EMPTY_USAGE };
  for (const responseUsage of responses.values()) addUsage(usage, responseUsage);

  const uncachedInputTokens = Math.max(
    0,
    usage.inputTokens - usage.cachedInputTokens,
  );
  const perRecordSemanticsValid = [...responses.values()].every(
    (item) =>
      item.cachedInputTokens <= item.inputTokens &&
      item.reasoningOutputTokens <= item.outputTokens &&
      item.totalTokens === item.inputTokens + item.outputTokens,
  );
  const matchesThreadCumulative = latestThreadUsage
    ? sameUsage(usage, latestThreadUsage)
    : null;

  const validation = {
    hasDesktopSession: session?.originator === "codex_work_desktop",
    hasUsageRecords: responses.size > 0,
    perRecordSemanticsValid,
    matchesThreadCumulative,
    conflictingResponses,
    invalidUsageRecords,
    malformedLines,
  };

  return {
    schemaVersion: 1,
    source: "codex-desktop-local-rollout",
    stability: "experimental-internal-format",
    sourceFile: path.basename(sourceName),
    session,
    latestUsageAt: latestTimestamp,
    counts: {
      turns: turns.size,
      uniqueResponses: responses.size,
      duplicateResponses,
    },
    usage: {
      ...usage,
      uncachedInputTokens,
      inspirationTokens: uncachedInputTokens + usage.outputTokens,
    },
    validation: {
      ...validation,
      ok:
        validation.hasDesktopSession &&
        validation.hasUsageRecords &&
        validation.perRecordSemanticsValid &&
        validation.matchesThreadCumulative !== false &&
        validation.conflictingResponses === 0 &&
        validation.invalidUsageRecords === 0,
    },
  };
}

async function listRollouts(directory, output = []) {
  let entries;
  try {
    entries = await fs.readdir(directory, { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return output;
    throw error;
  }

  await Promise.all(
    entries.map(async (entry) => {
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await listRollouts(entryPath, output);
      } else if (entry.isFile() && entry.name.endsWith(".jsonl")) {
        const stats = await fs.stat(entryPath);
        output.push({ path: entryPath, modifiedAt: stats.mtimeMs });
      }
    }),
  );
  return output;
}

async function readSessionMeta(filePath) {
  const handle = await fs.open(filePath, "r");
  try {
    const buffer = Buffer.alloc(64 * 1024);
    const { bytesRead } = await handle.read(buffer, 0, buffer.length, 0);
    for (const line of buffer.subarray(0, bytesRead).toString("utf8").split("\n")) {
      try {
        const record = JSON.parse(line);
        if (record.type === "session_meta") return record.payload ?? null;
      } catch {
        // Ignore a partial trailing line in the initial read window.
      }
    }
    return null;
  } finally {
    await handle.close();
  }
}

export async function findLatestDesktopRollout({
  codexHome = process.env.CODEX_HOME || path.join(os.homedir(), ".codex"),
  cwd = process.cwd(),
} = {}) {
  const rollouts = await listRollouts(path.join(codexHome, "sessions"));
  rollouts.sort((left, right) => right.modifiedAt - left.modifiedAt);

  for (const rollout of rollouts) {
    const meta = await readSessionMeta(rollout.path);
    if (
      meta?.originator === "codex_work_desktop" &&
      (!cwd || path.resolve(meta.cwd) === path.resolve(cwd))
    ) {
      return rollout.path;
    }
  }
  return null;
}

function parseArguments(argv) {
  const options = { once: false, cwd: process.cwd(), file: null };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--once") options.once = true;
    else if (argument === "--cwd") options.cwd = argv[++index];
    else if (argument === "--file") options.file = argv[++index];
    else throw new Error(`Unknown argument: ${argument}`);
  }
  return options;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (!options.once) {
    throw new Error("Only --once is implemented in the M0 probe.");
  }

  const rolloutPath =
    options.file ?? (await findLatestDesktopRollout({ cwd: options.cwd }));
  if (!rolloutPath) {
    throw new Error(`No Codex Desktop rollout found for ${options.cwd}`);
  }

  const text = await fs.readFile(rolloutPath, "utf8");
  const summary = summarizeRollout(text, rolloutPath);
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  if (!summary.validation.ok) process.exitCode = 2;
}

const isMain =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
