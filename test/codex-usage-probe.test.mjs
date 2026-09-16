import assert from "node:assert/strict";
import test from "node:test";

import { summarizeRollout } from "../scripts/codex-usage-probe.mjs";

function line(value) {
  return JSON.stringify(value);
}

test("summarizes unique desktop usage records using the Tokenbook formula", () => {
  const fixture = [
    line({
      type: "session_meta",
      timestamp: "2026-09-09T00:00:00Z",
      payload: {
        id: "session-1",
        cwd: "/tmp/tokenbook",
        originator: "codex_work_desktop",
        source: "vscode",
      },
    }),
    line({
      type: "response_item",
      payload: { type: "message", content: "PRIVATE_PROMPT_SENTINEL" },
    }),
    line({
      type: "token_usage_record",
      timestamp: "2026-09-09T00:01:00Z",
      payload: {
        response_id: "response-1",
        turn_id: "turn-1",
        usage: {
          input_tokens: 100,
          cached_input_tokens: 60,
          output_tokens: 20,
          reasoning_output_tokens: 10,
          total_tokens: 120,
        },
        thread_token_usage: {
          input_tokens: 100,
          cached_input_tokens: 60,
          output_tokens: 20,
          reasoning_output_tokens: 10,
          total_tokens: 120,
        },
      },
    }),
    line({
      type: "token_usage_record",
      timestamp: "2026-09-09T00:01:01Z",
      payload: {
        response_id: "response-1",
        turn_id: "turn-1",
        usage: {
          input_tokens: 100,
          cached_input_tokens: 60,
          output_tokens: 20,
          reasoning_output_tokens: 10,
          total_tokens: 120,
        },
      },
    }),
    line({
      type: "token_usage_record",
      timestamp: "2026-09-09T00:02:00Z",
      payload: {
        response_id: "response-2",
        turn_id: "turn-2",
        usage: {
          input_tokens: 50,
          cached_input_tokens: 40,
          output_tokens: 5,
          reasoning_output_tokens: 2,
          total_tokens: 55,
        },
        thread_token_usage: {
          input_tokens: 150,
          cached_input_tokens: 100,
          output_tokens: 25,
          reasoning_output_tokens: 12,
          total_tokens: 175,
        },
      },
    }),
  ].join("\n");

  const summary = summarizeRollout(fixture);
  assert.equal(summary.counts.uniqueResponses, 2);
  assert.equal(summary.counts.duplicateResponses, 1);
  assert.equal(summary.counts.turns, 2);
  assert.deepEqual(summary.usage, {
    inputTokens: 150,
    cachedInputTokens: 100,
    cacheWriteInputTokens: 0,
    outputTokens: 25,
    reasoningOutputTokens: 12,
    totalTokens: 175,
    uncachedInputTokens: 50,
    inspirationTokens: 75,
  });
  assert.equal(summary.validation.matchesThreadCumulative, true);
  assert.equal(summary.validation.ok, true);
  assert.equal(JSON.stringify(summary).includes("PRIVATE_PROMPT_SENTINEL"), false);
});

test("rejects inconsistent usage semantics", () => {
  const fixture = [
    line({
      type: "session_meta",
      payload: { originator: "codex_work_desktop" },
    }),
    line({
      type: "token_usage_record",
      payload: {
        response_id: "response-1",
        turn_id: "turn-1",
        usage: {
          input_tokens: 10,
          cached_input_tokens: 11,
          output_tokens: 3,
          reasoning_output_tokens: 4,
          total_tokens: 99,
        },
      },
    }),
  ].join("\n");

  const summary = summarizeRollout(fixture);
  assert.equal(summary.validation.perRecordSemanticsValid, false);
  assert.equal(summary.validation.ok, false);
});

test("flags conflicting duplicate response ids", () => {
  const makeRecord = (outputTokens) =>
    line({
      type: "token_usage_record",
      payload: {
        response_id: "same-response",
        turn_id: "turn-1",
        usage: {
          input_tokens: 10,
          cached_input_tokens: 5,
          output_tokens: outputTokens,
          reasoning_output_tokens: 0,
          total_tokens: 10 + outputTokens,
        },
      },
    });

  const summary = summarizeRollout(
    [
      line({
        type: "session_meta",
        payload: { originator: "codex_work_desktop" },
      }),
      makeRecord(2),
      makeRecord(3),
    ].join("\n"),
  );

  assert.equal(summary.validation.conflictingResponses, 1);
  assert.equal(summary.validation.ok, false);
});
