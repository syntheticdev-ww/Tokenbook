import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Original 64-second C-major / A-minor ambient miniature, no sampled recordings.
// Every voice wraps into the beginning, so decay tails cross the loop boundary.
export function renderMusic(rate = 44100) {
  const seconds = 64;
  const samples = new Float64Array(rate * seconds);
  const hz = midi => 440 * 2 ** ((midi - 69) / 12);
  const tau = 2 * Math.PI;
  function voice(start, duration, midi, gain, pad) {
    const count = Math.floor(duration * rate);
    const frequency = hz(midi);
    for (let i = 0; i < count; i++) {
      const age = i / rate;
      const attack = 1 - Math.exp(-age / (pad ? 1.5 : 0.045));
      const release = pad ? Math.sin(Math.PI * age / duration) ** 2 : Math.exp(-age / 1.4) * Math.min(1, (duration - age) / 0.2);
      const phase = tau * frequency * age;
      const tone = Math.sin(phase) + (pad ? 0.10 : 0.20) * Math.sin(2 * phase) * Math.exp(-age / 2.1);
      const destination = (Math.floor(start * rate) + i) % samples.length;
      samples[destination] += tone * attack * release * gain;
    }
  }
  const chords = [[48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 59]];
  chords.forEach((chord, bar) => chord.forEach((note, index) => voice(bar * 16, 21, note, index === 0 ? 0.035 : 0.022, true)));
  const melody = [72, 76, 79, 76, 69, 72, 76, 72, 69, 72, 77, 76, 67, 71, 74, 79];
  melody.forEach((note, index) => voice(1 + index * 4, 5.8, note, 0.033, false));
  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const gain = 0.68 / Math.max(peak, 0.001);
  const buffer = Buffer.alloc(44 + samples.length * 2);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(buffer.length - 8, 4);
  buffer.write('WAVEfmt ', 8);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(rate, 24);
  buffer.writeUInt32LE(rate * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) buffer.writeInt16LE(Math.round(samples[i] * gain * 32767), 44 + i * 2);
  return buffer;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const destination = fileURLToPath(new URL('../game/assets/audio/morning.wav', import.meta.url));
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, renderMusic());
  console.log(`Original ambient loop generated: ${destination}`);
}
