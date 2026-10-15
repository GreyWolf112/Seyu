const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
function load(name, modules = {}) {
  const exports = {};
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', name), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText,
    { exports, require: id => modules[id], setTimeout, clearTimeout });
  return exports;
}
const { BreathingClock, volumeLevel } = load('models/Relaxation.ets');
test('both breathing durations use elapsed time, including delayed ticks', () => {
  for (const duration of [60, 180]) {
    const clock = new BreathingClock(); clock.select(duration); clock.start(1000);
    assert.equal(clock.seconds(12500), duration - 11);
    assert.equal(clock.seconds(1000 + duration * 1000 + 700), 0);
  }
});
test('pause preserves fractional remainder and background time does not count', () => {
  const clock = new BreathingClock(); clock.start(1000); clock.pause(12400);
  assert.equal(clock.left(900000), 48600);
  clock.start(900000); assert.equal(clock.left(900600), 48000);
});
test('completed practice restarts and switching duration resets it', () => {
  const clock = new BreathingClock(); clock.start(0); clock.pause(60000);
  clock.start(70000); assert.equal(clock.seconds(70000), 60);
  clock.select(180); assert.equal(clock.seconds(900000), 180);
  assert.throws(() => clock.select(90));
});
test('mute and volume boundaries', () => {
  assert.equal(volumeLevel(35, false), .35); assert.equal(volumeLevel(90, true), 0);
  assert.equal(volumeLevel(-10, false), 0); assert.equal(volumeLevel(120, false), 1);
});
function fixture(options = {}) {
  const players = [], closed = [], reports = [];
  class Player {
    state = 'idle'; handlers = {}; released = 0; volumes = [];
    on(name, fn) { this.handlers[name] = fn; }
    set fdSrc(value) { if (options.sourceError) throw Error('source'); this.state = 'initialized'; this.handlers.stateChange('initialized'); }
    async prepare() { this.state = 'prepared'; this.handlers.stateChange('prepared'); }
    setVolume(value) { this.volumes.push(value); }
    async play() { this.state = 'playing'; }
    async release() { this.released++; this.state = 'released'; }
  }
  const { AmbientAudio } = load('audio/AmbientAudio.ets', {
    '@kit.MediaKit': { media: { createAVPlayer: async () => { const p = new Player(); players.push(p); return p; } } },
    '@kit.AudioKit': { audio: { StreamUsage: { STREAM_USAGE_MUSIC: 1 }, InterruptType: { INTERRUPT_TYPE_BEGIN: 1 } } }
  });
  const engine = new AmbientAudio({ getRawFd: options.getRawFd || (async () => ({ fd: 1, offset: 0, length: 10 })),
    closeRawFd: async name => closed.push(name) }, (message, playing) => reports.push({ message, playing }));
  return { engine, players, closed, reports };
}
test('switching releases old audio and stop closes the active resource', async () => {
  const f = fixture(); f.engine.setVolume(.2); await f.engine.play('rain');
  assert.equal(f.players[0].loop, true); assert.equal(f.players[0].volumes[0], .2);
  await f.engine.play('ocean'); assert.equal(f.players[0].released, 1);
  f.engine.setVolume(0); assert.equal(f.players[1].volumes.at(-1), 0);
  await f.engine.stop(); assert.deepEqual(f.closed, ['ambient/rain.wav', 'ambient/ocean.wav']);
  assert.equal(f.reports.at(-1).playing, false);
});
test('stop while loading prevents later playback and closes descriptor', async () => {
  let ready, entered;
  const loading = new Promise(resolve => entered = resolve);
  const f = fixture({ getRawFd: () => { entered(); return new Promise(resolve => ready = resolve); } });
  const play = f.engine.play('forest'); await loading;
  const stop = f.engine.stop(); ready({ fd: 1, offset: 0, length: 10 }); await Promise.all([play, stop]);
  assert.equal(f.players[0].released, 1); assert.equal(f.reports.some(r => r.playing), false);
  assert.deepEqual(f.closed, ['ambient/forest.wav']);
});
test('system interruption stops audio without automatic resume', async () => {
  const f = fixture(); await f.engine.play('rain');
  f.players[0].handlers.audioInterrupt({ eventType: 1 });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(f.players[0].released, 1); assert.equal(f.reports.at(-1).playing, false);
});
test('invalid source and runtime error release resources', async () => {
  const f = fixture({ sourceError: true }); await f.engine.play('rain');
  assert.equal(f.players[0].released, 1); assert.equal(f.closed.length, 1);
  assert.equal(f.reports.at(-1).playing, false);
  const g = fixture(); await g.engine.play('ocean'); g.players[0].handlers.error();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(g.players[0].released, 1); assert.equal(g.closed.length, 1);
  await assert.rejects(g.engine.play('../unexpected'));
});
test('bundled WAV files are 60 second field-recording PCM audio without clipping', () => {
  for (const name of ['rain', 'ocean', 'forest']) {
    const data = fs.readFileSync(path.join(__dirname, '../entry/src/main/resources/rawfile/ambient', name + '.wav'));
    assert.equal(data.toString('ascii', 0, 4), 'RIFF'); assert.equal(data.readUInt16LE(22), 1);
    assert.equal(data.readUInt32LE(24), 44100); assert.equal(data.readUInt16LE(34), 16);
    assert.equal(data.readUInt32LE(40), 60 * 44100 * 2);
    let peak = 0; for (let i = 44; i < data.length; i += 2) peak = Math.max(peak, Math.abs(data.readInt16LE(i)));
    assert.ok(peak > 1000 && peak < 32767);
  }
});

test('three scene assets match the reviewed source manifest and are distinct', () => {
  const crypto = require('node:crypto');
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '../docs/ambient-audio-build.json')));
  const hashes = ['rain', 'ocean', 'forest'].map(name => {
    const data = fs.readFileSync(path.join(__dirname, '../entry/src/main/resources/rawfile/ambient', name + '.wav'));
    const hash = crypto.createHash('sha256').update(data).digest('hex');
    assert.equal(hash, manifest[name].outputSha256);
    return hash;
  });
  assert.equal(new Set(hashes).size, 3);
});
