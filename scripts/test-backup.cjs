const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { test } = require('node:test');
const ts = require(process.env.ZHIYU_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, filename);
const base = path.resolve(__dirname, '../entry/src/main/ets');
const { DataMaintenance, MAINTENANCE_KEY } = require(path.join(base, 'storage/DataMaintenance.ets'));
const { parseBackup, draftRaw } = require(path.join(base, 'storage/BackupCodec.ets'));
const { DOCUMENT_KEY, RECOVERY_KEY, parseDocument } = require(path.join(base, 'storage/RecordCodec.ets'));
const { DRAFT_KEY } = require(path.join(base, 'storage/DraftRepository.ets'));
const { RecordRepository } = require(path.join(base, 'storage/RecordRepository.ets'));
const { newJournal } = require(path.join(base, 'models/EditorModel.ets'));
const { newReflection } = require(path.join(base, 'models/ReflectionModel.ets'));
class Store {
  constructor(seed = {}) { this.values = new Map(Object.entries(seed)); this.disk = new Map(this.values); this.flushCount = 0; this.failAt = -1; }
  get(k) { return this.values.get(k); }
  async put(k,v) { this.values.set(k,v); }
  async remove(k) { this.values.delete(k); }
  async flush() { if (++this.flushCount === this.failAt) throw Error('disk full'); this.disk = new Map(this.values); }
  restart() { return new Store(Object.fromEntries(this.disk)); }
}
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
class Media {
  constructor() { this.files = new Map(); this.staged = 0; this.failStage = false; this.failErase = false; }
  async readPhoto(p) { const bytes = this.files.get(p); if (!bytes) throw Error('missing'); return { relativePath: p, data: bytes.toString('base64'), sha256: hash(bytes) }; }
  async checkPhoto(p) { const bytes = Buffer.from(p.data,'base64'); if (bytes.toString('base64') !== p.data || hash(bytes) !== p.sha256) throw Error('checksum'); }
  async stagePhoto(p) { if (this.failStage) throw Error('full'); const name = `photos/staged-${++this.staged}.image`; this.files.set(name, Buffer.from(p.data,'base64')); return name; }
  async erasePhotos() { if (this.failErase) throw Error('unlink failed'); this.files.clear(); }
}
const documentRaw = records => JSON.stringify({ schemaVersion: 1, records });
function fixture(records = []) {
  const store = new Store({ [DOCUMENT_KEY]: documentRaw(records) }); const journal = new Store(); const reflection = new Store(); const media = new Media();
  return { store, journal, reflection, media, service: new DataMaintenance(store, journal, reflection, media) };
}
function backup() {
  const r = newJournal('含中文与换行\n保留原文'); r.id='imported'; r.favorite=true; r.bottled=true;
  r.photos=[{ id:'photo-1', relativePath:'photos/photo-1.image' }];
  const bytes=Buffer.from('original-photo-bytes');
  const journal = newJournal('未完成的草稿'); journal.id='draft'; journal.photos=r.photos.map(p=>({...p}));
  const reflection=newReflection('boundary'); reflection.id='reflection-draft'; reflection.reflection.step=2;
  return { format:'zhiyu-local-backup', version:1, createdAt:1234, document:{schemaVersion:1,records:[r]}, journalDraft:journal,
    reflectionDraft:reflection, photos:[{relativePath:r.photos[0].relativePath,data:bytes.toString('base64'),sha256:hash(bytes)}] };
}
test('backup round trip includes records, both drafts and shared photos exactly once', async () => {
  const b=backup(), f=fixture(b.document.records);
  await f.journal.put(DRAFT_KEY,draftRaw(b.journalDraft)); await f.reflection.put(DRAFT_KEY,draftRaw(b.reflectionDraft));
  f.media.files.set('photos/photo-1.image',Buffer.from(b.photos[0].data,'base64'));
  const exported=parseBackup(await f.service.createBackup());
  assert.deepEqual(exported.document,b.document); assert.deepEqual(exported.journalDraft,b.journalDraft);
  assert.deepEqual(exported.reflectionDraft,b.reflectionDraft); assert.equal(exported.photos.length,1);
  const target=fixture(); await target.service.restore(exported);
  const restored=parseDocument(target.store.get(DOCUMENT_KEY)).records[0];
  assert.equal(restored.text,b.document.records[0].text); assert.equal(restored.favorite,true); assert.equal(restored.bottled,true);
  assert.equal(restored.photos[0].relativePath,'photos/staged-1.image');
  assert.equal(JSON.parse(target.journal.get(DRAFT_KEY)).records[0].photos[0].relativePath,restored.photos[0].relativePath);
  assert.equal(target.media.files.size,1); assert.equal(target.service.isPending(),false);
});
test('merge preserves current same-id content and drafts; repeated imports add nothing', async () => {
  const b=backup(), local={...b.document.records[0],text:'本机新版本',photos:[]};
  const f=fixture([local]); await f.journal.put(DRAFT_KEY,draftRaw(newJournal('本机草稿'))); await f.journal.flush();
  assert.deepEqual(f.service.summarize(b),{added:0,kept:1,draftsAdded:1,draftsKept:1});
  await f.service.restore(b); await f.service.restore(b);
  assert.equal(parseDocument(f.store.get(DOCUMENT_KEY)).records.length,1);
  assert.equal(parseDocument(f.store.get(DOCUMENT_KEY)).records[0].text,'本机新版本');
  assert.equal(JSON.parse(f.journal.get(DRAFT_KEY)).records[0].text,'本机草稿');
  assert.equal(f.media.staged,0);
});
test('photo filename collisions never overwrite an existing photo', async () => {
  const local=newJournal('local'); local.id='local'; local.photos=[{id:'photo-1',relativePath:'photos/photo-1.image'}];
  const f=fixture([local]); f.media.files.set('photos/photo-1.image',Buffer.from('local bytes'));
  await f.service.restore(backup());
  assert.equal(f.media.files.get('photos/photo-1.image').toString(),'local bytes');
  assert.equal(parseDocument(f.store.get(DOCUMENT_KEY)).records.length,2);
});
test('invalid archives are rejected before any store or photo writes', async () => {
  for (const mutate of [b=>b.version=2,b=>b.document.records.push(b.document.records[0]),
    b=>b.photos=[],b=>b.photos.push(b.photos[0]),b=>b.photos[0].sha256='0'.repeat(64),
    b=>b.document.records[0].photos[0].relativePath='photos/../../escape',
    b=>b.document.records[0].photos[0].relativePath='photos/sub/other.image',
    b=>b.photos[0].data='!!!!',b=>b.reflectionDraft.reflection.sceneId='unknown',b=>delete b.journalDraft]) {
    const b=backup(); mutate(b); const f=fixture();
    await assert.rejects(f.service.inspect(JSON.stringify(b)));
    assert.equal(f.store.flushCount,0); assert.equal(f.media.staged,0);
  }
});
test('missing source photo aborts export instead of silently omitting it', async () => {
  const f=fixture(backup().document.records); await assert.rejects(f.service.createBackup());
  assert.equal(f.store.flushCount,0);
});
test('photo stage failure leaves active document and drafts untouched without pending intent', async () => {
  const local=newJournal('local'); const f=fixture([local]); f.media.failStage=true;
  await assert.rejects(f.service.restore(backup()));
  assert.deepEqual(parseDocument(f.store.get(DOCUMENT_KEY)).records,[local]);
  assert.equal(f.service.isPending(),false); assert.equal(f.journal.get(DRAFT_KEY),undefined);
});
test('import resumes after every record-store persistence interruption', async () => {
  for (let cut=1;cut<=4;cut++) {
    const local=newJournal('local'); const f=fixture([local]); f.store.failAt=cut;
    await assert.rejects(f.service.restore(backup()));
    const s=f.store.restart(),j=f.journal.restart(),r=f.reflection.restart();
    const resumed=new DataMaintenance(s,j,r,f.media); await resumed.recover();
    const records=parseDocument(s.get(DOCUMENT_KEY)).records;
    assert.equal(records.length,cut===1?1:2);
    if(cut!==1) { assert.ok(j.get(DRAFT_KEY)); assert.ok(r.get(DRAFT_KEY)); }
    assert.equal(resumed.isPending(),false);
  }
});
test('import resumes after either draft store fails, retaining staged photo files', async () => {
  for(const name of ['journal','reflection']) {
    const f=fixture(); f[name].failAt=1; await assert.rejects(f.service.restore(backup()));
    assert.equal(f.service.isPending(),true);
    const s=f.store.restart(),j=f.journal.restart(),r=f.reflection.restart();
    await new DataMaintenance(s,j,r,f.media).recover();
    assert.equal(parseDocument(s.get(DOCUMENT_KEY)).records.length,1);
    assert.ok(j.get(DRAFT_KEY)); assert.ok(r.get(DRAFT_KEY)); assert.equal(f.media.files.size,1);
  }
});
test('same-session retry re-persists intent after failed intent or journal removal flush', async () => {
  for(const cut of [1,4]) {
    const f=fixture(); f.store.failAt=cut; await assert.rejects(f.service.restore(backup()));
    assert.equal(f.service.isPending(),true); await f.service.recover();
    assert.equal(parseDocument(f.store.get(DOCUMENT_KEY)).records.length,1);
    assert.equal(f.service.isPending(),false);
  }
});
function seedErase() {
  const b=backup(),f=fixture(b.document.records);
  for(const key of [RECOVERY_KEY,'entries','bottles','joys']) { f.store.values.set(key,'private data'); f.store.disk.set(key,'private data'); }
  for(const s of [f.journal,f.reflection]) { s.values.set(DRAFT_KEY,'private draft'); s.disk.set(DRAFT_KEY,'private draft'); }
  f.media.files.set('photos/orphan.image',Buffer.from('orphan'));
  return f;
}
test('erase removes legacy keys, recovery, both drafts and all app photos; reboot does not migrate them back', async () => {
  const f=seedErase(); await f.service.erase();
  assert.deepEqual([...f.store.disk.keys()],[DOCUMENT_KEY]);
  assert.equal(f.journal.disk.size,0); assert.equal(f.reflection.disk.size,0); assert.equal(f.media.files.size,0);
  const repo=new RecordRepository(f.store.restart()); await repo.initialize(); assert.equal(repo.timeline().length,0);
});
test('erase resumes after each store interruption and media cleanup failure', async () => {
  for(const name of ['store','journal','reflection','media']) {
    const cuts=name==='store'?[2,3,4]:[1];
    for(const cut of cuts) {
      const f=seedErase(); if(name==='media') f.media.failErase=true; else f[name].failAt=cut;
      await assert.rejects(f.service.erase()); f.media.failErase=false;
      const s=f.store.restart(),j=f.journal.restart(),r=f.reflection.restart();
      const service=new DataMaintenance(s,j,r,f.media); await service.recover();
      assert.deepEqual([...s.disk.keys()],[DOCUMENT_KEY]); assert.equal(parseDocument(s.get(DOCUMENT_KEY)).records.length,0);
      assert.equal(j.disk.size,0); assert.equal(r.disk.size,0); assert.equal(f.media.files.size,0); assert.equal(service.isPending(),false);
    }
  }
});
test('pending work blocks exports/imports/another erase and invalid journals are not executed', async () => {
  const f=fixture(); f.store.failAt=2; await assert.rejects(f.service.restore(backup()));
  await assert.rejects(f.service.createBackup()); await assert.rejects(f.service.inspect(JSON.stringify(backup()))); await assert.rejects(f.service.erase());
  const g=fixture(); await g.store.put(MAINTENANCE_KEY,JSON.stringify({version:99,mode:'erase'}));
  await assert.rejects(g.service.recover()); assert.equal(g.media.staged,0); assert.equal(g.store.get(DOCUMENT_KEY),documentRaw([]));
});

test('erase intent failure does not delete anything on disk; same-session retry can finish', async () => {
  const f=seedErase(); f.store.failAt=1; await assert.rejects(f.service.erase());
  assert.equal(f.store.disk.has('entries'),true); assert.equal(f.media.files.size,1);
  await new DataMaintenance(f.store.restart(),f.journal.restart(),f.reflection.restart(),f.media).recover();
  assert.equal(f.media.files.size,1);
  await f.service.recover(); assert.equal(f.media.files.size,0); assert.equal(f.store.disk.has('entries'),false);
});

const vm = require('node:vm');
function nativeFixture() {
  const files=new Map(), dirs=new Set(['/app/photos']), opened=new Map(); let next=1;
  const options={save:[],select:[],readSize:5,writeSize:3,failWrite:false,reportedSize:null,earlyEOF:false};
  const stats={closed:0,synced:0,picker:0};
  const api={ OpenMode:{READ_ONLY:1,WRITE_ONLY:2,CREATE:4,TRUNC:8},
    async open(p,mode) { if(mode&2) files.set(p,Buffer.alloc(0)); else if(!files.has(p)) throw Error('missing'); const fd=next++;opened.set(fd,{p,pos:0});return {fd}; },
    async close(f){opened.delete(f.fd);stats.closed++;},
    async stat(fd){return {size:options.reportedSize??files.get(opened.get(fd).p).length};},
    async read(fd,buffer){if(options.earlyEOF)return 0;const f=opened.get(fd),source=files.get(f.p);const n=Math.min(options.readSize,buffer.byteLength,source.length-f.pos);new Uint8Array(buffer).set(source.subarray(f.pos,f.pos+n));f.pos+=n;return n;},
    async write(fd,buffer){if(options.failWrite)throw Error('disk full');const f=opened.get(fd),n=Math.min(options.writeSize,buffer.byteLength);files.set(f.p,Buffer.concat([files.get(f.p),Buffer.from(buffer).subarray(0,n)]));f.pos+=n;return n;},
    async fsync(){stats.synced++;}, async access(p){return files.has(p)||dirs.has(p);}, async mkdir(p){dirs.add(p);},
    async unlink(p){files.delete(p);},async listFile(p){return [...files.keys()].filter(x=>x.startsWith(p+'/')).map(x=>x.slice(p.length+1));},
    async rmdir(p){dirs.delete(p);}
  };
  const kit={fileIo:api,picker:{DocumentViewPicker:class { async save(){stats.picker++;return options.save;} async select(){stats.picker++;return options.select;} }}};
  const utility={util:{Base64Helper:class { encodeToStringSync(b){return Buffer.from(b).toString('base64');} decodeSync(s){return new Uint8Array(Buffer.from(s,'base64'));} },
    TextEncoder:class{encodeInto(s){return new TextEncoder().encode(s);}},
    TextDecoder:class{constructor(enc,opts){this.decoder=new TextDecoder(enc,opts);}decodeToString(bytes){return this.decoder.decode(bytes);}}}};
  const crypt={cryptoFramework:{createMd(){const hash=crypto.createHash('sha256');return {async update({data}){hash.update(data);},async digest(){return {data:new Uint8Array(hash.digest())};}};}}};
  const mod={exports:{}};
  const js=ts.transpileModule(fs.readFileSync(path.join(base,'storage/BackupFiles.ets'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText;
  vm.runInNewContext(`(function(require,module,exports){${js}\n})`,{Uint8Array,ArrayBuffer,Date,Math})(name=>{
    if(name==='@kit.CoreFileKit')return kit;if(name==='@kit.ArkTS')return utility;if(name==='@kit.CryptoArchitectureKit')return crypt;
    if(name==='@kit.AbilityKit')return {};return require(path.join(base,'storage',name+'.ets'));
  },mod,mod.exports);
  return {files,dirs,opened,options,stats,service:new mod.exports.BackupFiles({filesDir:'/app'})};
}
test('native backup I/O handles short reads/writes, unicode and descriptor closure', async () => {
  const f=nativeFixture(),raw=JSON.stringify({text:'知屿\n🙂'});f.options.save=['document://backup'];
  assert.equal(await f.service.save(raw),true);assert.equal(f.files.get('document://backup').toString(),raw);
  f.options.select=['document://backup'];assert.equal(await f.service.select(),raw);
  assert.equal(f.opened.size,0);assert.equal(f.stats.closed,2);assert.equal(f.stats.synced,1);
});
test('cancelled file pickers do not create or read any files', async () => {
  const f=nativeFixture();assert.equal(await f.service.save('{}'),false);assert.equal(await f.service.select(),null);
  assert.equal(f.files.size,0);assert.equal(f.stats.closed,0);
});
test('native import rejects oversized, truncated and malformed UTF8 files and closes handles', async () => {
  for(const issue of ['oversized','truncated','utf8']) {
    const f=nativeFixture();f.files.set('document://backup',Buffer.from([0xff]));f.options.select=['document://backup'];
    if(issue==='oversized')f.options.reportedSize=64*1024*1024+1;
    if(issue==='truncated')f.options.earlyEOF=true;
    await assert.rejects(f.service.select());assert.equal(f.opened.size,0);assert.equal(f.stats.closed,1);
  }
});
test('native photo hashing, remapped stage and erase never touch exported backup or album source', async () => {
  const f=nativeFixture();f.files.set('/app/photos/old.image',Buffer.from('original bytes'));f.files.set('document://backup',Buffer.from('backup'));f.files.set('photo://album',Buffer.from('original'));
  const photo=await f.service.readPhoto('photos/old.image');await f.service.checkPhoto(photo);
  const dest=await f.service.stagePhoto(photo);assert.notEqual(dest,'photos/old.image');
  assert.equal(f.files.get('/app/'+dest).toString(),'original bytes');
  await assert.rejects(f.service.checkPhoto({...photo,sha256:'0'.repeat(64)}));
  await assert.rejects(f.service.readPhoto('../private'));
  await f.service.erasePhotos();assert.deepEqual([...f.files.keys()],['document://backup','photo://album']);assert.equal(f.opened.size,0);
});
test('failed native photo writes close descriptor and remove the partial staged photo', async () => {
  const f=nativeFixture();f.options.failWrite=true;
  await assert.rejects(f.service.stagePhoto(backup().photos[0]));assert.equal(f.files.size,0);assert.equal(f.opened.size,0);
});

test('corrupt existing drafts stop export and restore without changing originals', async () => {
  const f=fixture();await f.journal.put(DRAFT_KEY,'corrupt');await f.journal.flush();
  await assert.rejects(f.service.createBackup());await assert.rejects(f.service.restore(backup()));
  assert.equal(f.journal.get(DRAFT_KEY),'corrupt');assert.equal(f.media.staged,0);assert.equal(f.store.flushCount,0);
});
test('empty backup is valid and never clears existing records', async () => {
  const empty=fixture();const b=parseBackup(await empty.service.createBackup());assert.equal(b.photos.length,0);
  const record=newJournal('keep');const target=fixture([record]);await target.service.restore(b);
  assert.deepEqual(parseDocument(target.store.get(DOCUMENT_KEY)).records,[record]);
});
