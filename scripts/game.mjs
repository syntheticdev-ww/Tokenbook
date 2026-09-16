import { spawn } from 'node:child_process';
import { createReadStream, createWriteStream, existsSync } from 'node:fs';
import { mkdir, mkdtemp } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const godot = join(root, '.tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot');
process.umask(0o077);

async function run(binary, args, env = process.env, timeout = 0) {
  const child = spawn(binary, args, { cwd: root, env, stdio: ['inherit', 'pipe', 'pipe'] });
  let engineError = false;
  let tail = '';
  for (const [stream, output] of [[child.stdout, process.stdout], [child.stderr, process.stderr]]) {
    stream.on('data', chunk => {
      output.write(chunk);
      tail = (tail + chunk.toString()).slice(-8192);
      if (/(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed loading resource|ERROR: Failed to load script|ObjectDB instances were leaked|resources still in use at exit)/.test(tail)) engineError = true;
    });
  }
  const timer = timeout ? setTimeout(() => child.kill('SIGKILL'), timeout) : null;
  const code = await new Promise((ok, fail) => {
    child.on('error', fail);
    child.on('exit', (code, signal) => ok(code ?? (signal ? 1 : 0)));
  });
  if (timer) clearTimeout(timer);
  if (code !== 0) throw new Error(`${binary.split('/').at(-1)} exited ${code}`);
  if (engineError) throw new Error('Godot reported a script or resource error; see output above.');
}

async function archive(url, destination, expected) {
  await mkdir(dirname(destination), { recursive: true });
  if (!existsSync(destination)) {
    console.log(`Downloading ${url}`);
    const response = await fetch(url, { signal: AbortSignal.timeout(240_000) });
    if (!response.ok) throw new Error(`Download failed: ${response.status}`);
    await pipeline(Readable.fromWeb(response.body), createWriteStream(destination, { flags: 'wx', mode: 0o600 }));
  }
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(destination)) hash.update(chunk);
  if (hash.digest('hex') !== expected) throw new Error(`Checksum mismatch; remove only this incomplete archive and retry: ${destination}`);
}

async function setup() {
  if (process.platform !== 'darwin') throw new Error('This M0 runtime currently targets macOS only.');
  const engineZip = join(root, '.tools/godot-4.7.2/macos.zip');
  await archive('https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip', engineZip, 'c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e');
  if (!existsSync(godot)) await run('ditto', ['-x', '-k', engineZip, dirname(engineZip)]);
  const sqliteZip = join(root, '.tools/godot-sqlite-4.9/addons.zip');
  await archive('https://github.com/2shady4u/godot-sqlite/releases/download/v4.9/addons.zip', sqliteZip, '95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0');
  if (!existsSync(join(root, 'game/addons/godot-sqlite/gdsqlite.gdextension'))) {
    await run('unzip', ['-q', sqliteZip, 'addons/godot-sqlite/*.gdextension', 'addons/godot-sqlite/bin/*macos*/*', 'addons/godot-sqlite/LICENSE*', '-d', 'game']);
  }
  const header = join(root, '.tools/gdextension_interface.h');
  await archive('https://raw.githubusercontent.com/godotengine/godot-cpp/godot-4.5-stable/gdextension/gdextension_interface.h', header, 'a40ac4fca0f526910bd0e6afc6da6c169f50801c84d4e29c4ce2891cadc7b550');
  await run('clang', ['-fobjc-arc', '-dynamiclib', '-arch', 'arm64', '-arch', 'x86_64', '-mmacosx-version-min=13.0', '-I', '.tools', '-framework', 'AppKit', 'native/macos/window_bridge.m', '-o', 'game/native/libtokenbook_window.dylib']);
  await run(godot, ['--headless', '--editor', '--path', 'game', '--import'], process.env, 60000);
  console.log('Project-local Godot and SQLite are ready. No system installation or Codex configuration changed.');
}

const command = process.argv[2] ?? 'run';
try {
  if (command === 'setup') await setup();
  else {
    if (!existsSync(godot)) throw new Error('Run npm run game:setup first.');
    if (command === 'test' || command === 'smoke') {
      const data = await mkdtemp(join(tmpdir(), 'tokenbook-m0-'));
      const captures = join(root, 'artifacts/m0');
      await mkdir(captures, { recursive: true });
      console.log(`Isolated test data: ${data}`);
      const env = { ...process.env, TOKENBOOK_TEST_DIR: data, TOKENBOOK_DATA_DIR: data, TOKENBOOK_CAPTURE_DIR: captures };
      await run(godot, [...(command === 'test' ? ['--headless'] : []), '--path', 'game', '--script', command === 'test' ? 'res://tests/run.gd' : 'res://tests/window_smoke.gd'], env, 45000);
    } else if (command === 'run') {
      const data = join(root, '.runtime/m0');
      await mkdir(data, { recursive: true });
      await run(godot, ['--path', 'game'], { ...process.env, TOKENBOOK_DATA_DIR: data });
    } else throw new Error('Usage: node scripts/game.mjs setup|test|smoke|run');
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
