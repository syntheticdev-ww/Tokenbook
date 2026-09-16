#!/usr/bin/env node

import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import { summarizeRollout } from "./codex-usage-probe.mjs";

function increment(counts, value) {
  const key = String(value ?? "unknown");
  counts[key] = (counts[key] ?? 0) + 1;
}

function originatorKind(originator) {
  if (typeof originator === "string") return originator;
  if (originator && typeof originator === "object") {
    if ("subagent" in originator) return "subagent";
    return `object:${Object.keys(originator).sort().join(",") || "empty"}`;
  }
  return "unknown";
}

function sourceKind(source) {
  if (typeof source === "string") return source;
  if (source && typeof source === "object") {
    if ("subagent" in source) return "subagent";
    return `object:${Object.keys(source).sort().join(",") || "empty"}`;
  }
  return "unknown";
}

async function listJsonl(directory, output = []) {
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
      if (entry.isDirectory()) await listJsonl(entryPath, output);
      else if (entry.isFile() && entry.name.endsWith(".jsonl")) output.push(entryPath);
    }),
  );
  return output;
}

const codexHome = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
const files = await listJsonl(path.join(codexHome, "sessions"));
const originators = {};
const sources = {};
const cliVersions = {};
const usageFilesByCliVersion = {};
const eventTypes = {};
let sessionsWithMetadata = 0;
let filesWithUsage = 0;
let usageFilesWithValidSemantics = 0;
let usageFilesMatchingCumulative = 0;
let starts = 0;
let completes = 0;
let aborts = 0;
let malformedLines = 0;

for (const file of files) {
  const text = await fs.readFile(file, "utf8");
  const summary = summarizeRollout(text, file);
  if (summary.counts.uniqueResponses > 0) {
    filesWithUsage += 1;
    if (summary.validation.perRecordSemanticsValid) {
      usageFilesWithValidSemantics += 1;
    }
    if (summary.validation.matchesThreadCumulative) {
      usageFilesMatchingCumulative += 1;
    }
  }
  malformedLines += summary.validation.malformedLines;

  let metadataSeen = false;
  let cliVersion = "unknown";
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    let record;
    try {
      record = JSON.parse(line);
    } catch {
      continue;
    }
    if (record.type === "session_meta" && record.payload && !metadataSeen) {
      metadataSeen = true;
      sessionsWithMetadata += 1;
      increment(originators, originatorKind(record.payload.originator));
      increment(sources, sourceKind(record.payload.source));
      cliVersion = record.payload.cli_version ?? "unknown";
      increment(cliVersions, cliVersion);
    }
    if (record.type !== "event_msg" || !record.payload) continue;
    const eventType = record.payload.type;
    increment(eventTypes, eventType);
    if (eventType === "task_started") starts += 1;
    else if (eventType === "task_complete") completes += 1;
    else if (eventType === "turn_aborted") aborts += 1;
  }
  if (summary.counts.uniqueResponses > 0) {
    increment(usageFilesByCliVersion, cliVersion);
  }
}

process.stdout.write(
  `${JSON.stringify(
    {
      schemaVersion: 1,
      source: "codex-local-rollout-structure",
      stability: "experimental-internal-format",
      privacy: "content-fields-ignored",
      files: {
        total: files.length,
        withSessionMetadata: sessionsWithMetadata,
        withUsageRecords: filesWithUsage,
      },
      sessionMetadata: { originators, sources, cliVersions, usageFilesByCliVersion },
      lifecycle: {
        starts,
        completes,
        aborts,
        unresolvedOrCurrentlyActive: Math.max(0, starts - completes - aborts),
        eventTypes,
      },
      usageValidation: {
        filesChecked: filesWithUsage,
        filesWithValidPerResponseSemantics: usageFilesWithValidSemantics,
        filesMatchingLatestThreadCumulative: usageFilesMatchingCumulative,
      },
      malformedLines,
    },
    null,
    2,
  )}\n`,
);
