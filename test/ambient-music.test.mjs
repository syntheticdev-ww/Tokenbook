import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';

test('ambient loop is deterministic PCM with headroom and a continuous loop seam', async () => {
  const moduleURL = new URL('../scripts/ambient-music.mjs', import.meta.url);
  assert.ok(existsSync(moduleURL), 'the original ambient music generator is not implemented');
  const { renderMusic } = await import(moduleURL.href);
  const rate = 44100;
  const wave = renderMusic(rate);
  assert.equal(wave.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wave.readUInt32LE(24), rate);
  assert.equal(wave.readUInt16LE(22), 1);
  assert.equal(wave.readUInt16LE(34), 16);
  assert.equal(wave.length, 44 + rate * 64 * 2);
  let peak = 0;
  let sum = 0;
  for (let offset = 44; offset < wave.length; offset += 2) {
    const sample = wave.readInt16LE(offset) / 32768;
    peak = Math.max(peak, Math.abs(sample));
    sum += sample * sample;
  }
  assert.ok(peak > 0.4 && peak < 0.8, `headroom: ${peak}`);
  assert.ok(Math.sqrt(sum / (rate * 64)) > 0.03, 'loop is audible, not silence');
  // Consecutive samples need not be equal. At the shipped sample rate, compare
  // the seam slope with its neighbors as well as bounding its absolute step.
  const seam = wave.readInt16LE(44) - wave.readInt16LE(wave.length - 2);
  const before = wave.readInt16LE(wave.length - 2) - wave.readInt16LE(wave.length - 4);
  const after = wave.readInt16LE(46) - wave.readInt16LE(44);
  assert.ok(Math.abs(seam) < 650, 'loop has no hard boundary click');
  assert.ok(Math.abs(seam - (before + after) / 2) < 50, 'waveform slope is continuous across the loop');
  assert.deepEqual(renderMusic(rate), wave);
});
