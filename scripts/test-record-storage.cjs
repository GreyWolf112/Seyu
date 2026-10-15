// Runs the production codec/repository against an in-memory Preferences adapter.
// DevEco bundles TypeScript, so no network install is needed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const ts = require(process.env.ZHIYU_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => {
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  });
  module._compile(output.outputText, filename);
};
const base = path.resolve(__dirname, '../entry/src/main/ets');
const { RecordRepository } = require(path.join(base, 'storage/RecordRepository.ets'));
const { migrateLegacy, parseDocument, DOCUMENT_KEY, RECOVERY_KEY } = require(path.join(base, 'storage/RecordCodec.ets'));
class Store {
  constructor(seed = {}) { this.values = new Map(Object.entries(seed)); this.disk = new Map(this.values); this.flushCount = 0; this.failFlushes = new Set(); }
  get(key) { return this.values.get(key); }
  async put(key, value) { this.values.set(key, value); }
  async remove(key) { this.values.delete(key); }
  async flush() {
    this.flushCount++;
    if (this.failFlushes.has(this.flushCount)) throw new Error('disk full');
    this.disk = new Map(this.values);
  }
  restart() { return new Store(Object.fromEntries(this.disk)); }
}
const seed = () => ({
  entries: JSON.stringify([{ id: '123', date: '2026-10-15', mood: '委屈', text: '原手记\n第二行' }]),
  bottles: JSON.stringify([{ id: '123', date: '2026-10-14', mood: '平静', text: '原瓶子' }]),
  joys: JSON.stringify([{ id: '123', date: '2026-10-13', title: '喝杯热饮' }])
});
test('migrates all legacy categories and preserves exact text, date and source ids', async () => {
  const original = seed(); const store = new Store(original); const repo = new RecordRepository(store);
  await repo.initialize(); const doc = repo.snapshot();
  assert.equal(doc.schemaVersion, 1); assert.equal(doc.records.length, 3);
  assert.deepEqual(repo.journals(), JSON.parse(original.entries));
  assert.deepEqual(repo.bottles(), JSON.parse(original.bottles));
  assert.deepEqual(repo.joys(), JSON.parse(original.joys));
  assert.equal(new Set(doc.records.map(r => r.id)).size, 3);
  assert.ok(doc.records.every(r => r.timePrecision === 'day'));
  for (const [k,v] of Object.entries(original)) assert.equal(store.get(k), v);
});
test('repeated launch does not duplicate records or resurrect deleted legacy entries', async () => {
  let store = new Store(seed()); let repo = new RecordRepository(store); await repo.initialize();
  await repo.remove('journal', '123');
  for (let i = 0; i < 3; i++) {
    store = store.restart(); repo = new RecordRepository(store); await repo.initialize();
    assert.equal(repo.snapshot().records.length, 2); assert.equal(repo.journals().length, 0);
  }
});
test('fresh install persists an empty versioned document', async () => {
  const store = new Store(); const repo = new RecordRepository(store); await repo.initialize();
  assert.deepEqual(parseDocument(store.get(DOCUMENT_KEY)), { schemaVersion: 1, records: [] });
});
test('multiple same-day entries, editing and deleting survive restart', async () => {
  const store = new Store(seed()); const repo = new RecordRepository(store); await repo.initialize();
  await repo.save('journal', 'a', '2026-10-15', '开心', 'first');
  await repo.save('journal', 'b', '2026-10-15', '平静', 'second');
  const created = repo.snapshot().records.find(r => r.id === 'journal:a').createdAt;
  await repo.save('journal', 'a', '2026-10-15', '疲惫', 'edited');
  await repo.remove('bottle', '123');
  const restarted = new RecordRepository(store.restart()); await restarted.initialize();
  assert.equal(restarted.journals().length, 3); assert.equal(restarted.bottles().length, 0);
  assert.equal(restarted.journals()[0].text, 'edited');
  assert.equal(restarted.snapshot().records.find(r => r.id === 'journal:a').createdAt, created);
  assert.equal(restarted.snapshot().records.find(r => r.id === 'journal:a').timePrecision, 'millisecond');
});
test('new metadata and photo associations survive editing through legacy UI', async () => {
  const doc = migrateLegacy(seed().entries, '[]', '[]');
  Object.assign(doc.records[0], { tags: ['工作'], intensity: 4, favorite: true,
    photos: [{ id: 'photo-1', relativePath: 'photos/photo-1.jpg' }],
    reflection: { sceneId: 'boundary', facts: '事实', needs: '休息', nextStep: '暂缓回复' } });
  const store = new Store({ [DOCUMENT_KEY]: JSON.stringify(doc) }); const repo = new RecordRepository(store);
  await repo.initialize(); await repo.save('journal', '123', '2026-10-15', '平静', 'edited');
  const result = repo.snapshot().records[0];
  for (const key of ['tags','intensity','favorite','photos','reflection','createdAt']) assert.deepEqual(result[key], doc.records[0][key]);
  assert.deepEqual(parseDocument(store.get(RECOVERY_KEY)), doc);
});
test('malformed legacy data fails closed and leaves original bytes untouched', async () => {
  for (const raw of ['{', 'null', '{}', '[null]', '[{"id":"x"}]', '[{"id":"x","date":"2026-2-30","mood":"开心","text":"x"}]']) {
    const original = { ...seed(), entries: raw }; const store = new Store(original); const repo = new RecordRepository(store);
    await assert.rejects(repo.initialize()); assert.equal(store.get(DOCUMENT_KEY), undefined);
    for (const [k,v] of Object.entries(original)) assert.equal(store.get(k), v);
    await assert.rejects(repo.save('journal','new','2026-10-15','开心','do not overwrite'));
  }
});
test('duplicate source ids block migration instead of discarding records', () => {
  const entries = JSON.parse(seed().entries); entries.push({ ...entries[0], text: 'different content' });
  assert.throws(() => migrateLegacy(JSON.stringify(entries), '[]', '[]'));
});
test('corrupt or future schema never falls back to stale legacy data', async () => {
  for (const raw of ['', '{', JSON.stringify({schemaVersion: 9, records: []})]) {
    const store = new Store({ ...seed(), [DOCUMENT_KEY]: raw }); const repo = new RecordRepository(store);
    await assert.rejects(repo.initialize()); assert.equal(store.get(DOCUMENT_KEY), raw);
    await assert.rejects(repo.remove('journal','123'));
  }
});
test('initial migration flush failure rolls back cached key and can safely retry', async () => {
  const store = new Store(seed()); store.failFlushes.add(1); const repo = new RecordRepository(store);
  await assert.rejects(repo.initialize()); assert.equal(store.get(DOCUMENT_KEY), undefined);
  await repo.initialize(); assert.equal(repo.snapshot().records.length, 3);
});
test('failed edit preserves memory and durable previous document', async () => {
  const store = new Store(seed()); const repo = new RecordRepository(store); await repo.initialize();
  const before = repo.snapshot(); store.failFlushes.add(store.flushCount + 2);
  await assert.rejects(repo.save('journal','123','2026-10-15','开心','failed edit'));
  assert.deepEqual(repo.snapshot(), before);
  const restarted = new RecordRepository(store.restart()); await restarted.initialize();
  assert.deepEqual(restarted.snapshot(), before);
});
test('concurrent writes reject busy request without dropping a successful write', async () => {
  const store = new Store(seed()); const repo = new RecordRepository(store); await repo.initialize();
  const first = repo.save('journal','a','2026-10-15','开心','a');
  await assert.rejects(repo.save('bottle','b','2026-10-15','平静','b')); await first;
  assert.equal(repo.journals().length, 2); assert.equal(repo.bottles().length, 1);
  await repo.save('bottle','b','2026-10-15','平静','b'); assert.equal(repo.bottles().length, 2);
});
test('snapshots cannot mutate repository state; unsafe photo paths are rejected', async () => {
  const repo = new RecordRepository(new Store(seed())); await repo.initialize();
  const copy = repo.snapshot(); copy.records[0].text = 'mutated';
  assert.notEqual(repo.journals()[0].text, 'mutated');
  copy.records[0].photos = [{id: 'p', relativePath: '../secret'}];
  assert.throws(() => parseDocument(JSON.stringify(copy)));
});
test('failure while saving recovery copy leaves the active document unchanged', async () => {
  const store = new Store(seed()); const repo = new RecordRepository(store); await repo.initialize();
  const before = repo.snapshot(); store.failFlushes.add(store.flushCount + 1);
  await assert.rejects(repo.remove('journal', '123'));
  assert.deepEqual(repo.snapshot(), before);
  assert.deepEqual(parseDocument(store.get(DOCUMENT_KEY)), before);
});
test('rollback persistence failure disables further writes until reinitialization', async () => {
  const store = new Store(seed()); const repo = new RecordRepository(store); await repo.initialize();
  const before = repo.snapshot();
  store.failFlushes.add(store.flushCount + 2); store.failFlushes.add(store.flushCount + 3);
  await assert.rejects(repo.save('journal', '123', '2026-10-15', '开心', 'failed'));
  await assert.rejects(repo.save('journal', 'new', '2026-10-15', '开心', 'must be blocked'));
  assert.deepEqual(repo.snapshot(), before);
  const restarted = new RecordRepository(store.restart()); await restarted.initialize();
  assert.deepEqual(restarted.snapshot(), before);
});
test('malformed current record metadata is not accepted as valid storage', () => {
  for (const change of [{ moods: [42] }, { tags: null }, { createdAt: null }, { intensity: 11 },
    { photos: [null] }, { reflection: {sceneId: 'x'} }, { timePrecision: 'invented' }]) {
    const doc = migrateLegacy(seed().entries, '[]', '[]'); Object.assign(doc.records[0], change);
    assert.throws(() => parseDocument(JSON.stringify(doc)));
  }
});

const { DraftRepository, DRAFT_KEY } = require(path.join(base, 'storage/DraftRepository.ets'));
const { newJournal, hasContent, validateEditorRecord } = require(path.join(base, 'models/EditorModel.ets'));
test('mood-only record can be saved, reopened, edited and deleted by its stable id', async () => {
  const store = new Store(); let repo = new RecordRepository(store); await repo.initialize();
  const record = newJournal('', '平静'); record.kind = 'mood';
  validateEditorRecord(record); await repo.upsert(record);
  repo = new RecordRepository(store.restart()); await repo.initialize();
  assert.equal(repo.timeline().length, 1); assert.equal(repo.timeline()[0].text, '');
  record.text = '后来写了一句话'; record.kind = 'journal'; record.updatedAt++;
  await repo.upsert(record); assert.equal(repo.timeline().length, 1);
  await repo.removeById(record.id); assert.equal(repo.timeline().length, 0);
});
test('three emotions, optional intensity, custom tags and three photos survive restart', async () => {
  const store = new Store(); const repo = new RecordRepository(store); await repo.initialize();
  const record = newJournal('今天很复杂');
  Object.assign(record, { moods: ['委屈','疲惫','期待'], intensity: 7, tags: ['工作/学习','经期不适'],
    photos: [1,2,3].map(n => ({id: `p${n}`, relativePath: `photos/p${n}.image`})) });
  validateEditorRecord(record); await repo.upsert(record);
  const restarted = new RecordRepository(store.restart()); await restarted.initialize();
  assert.deepEqual(restarted.timeline()[0], record);
});
test('editor accepts text-only and photo-only, rejects empty and over-limit records', () => {
  assert.equal(hasContent(newJournal()), false); assert.throws(() => validateEditorRecord(newJournal()));
  validateEditorRecord(newJournal('文字'));
  const image = newJournal(); image.photos = [{id:'p',relativePath:'photos/p.image'}]; validateEditorRecord(image);
  for (const changes of [{ moods: ['a','b','c','d'] }, { moods: ['a','a'] }, { text:'x'.repeat(5001) },
    { tags: ['x'.repeat(21)] }, { photos: Array.from({length:4},(_,n)=>({id:`p${n}`,relativePath:`photos/p${n}.image`})) }]) {
    assert.throws(() => validateEditorRecord(Object.assign(newJournal('文字'), changes)));
  }
});
test('rapid draft changes persist in order and recover after restart', async () => {
  const store = new Store(); const drafts = new DraftRepository(store); const record = newJournal('一');
  const first = drafts.save(record); record.text = '二'; const second = drafts.save(record);
  record.text = '未请求保存的改变'; await Promise.all([first,second]);
  const restored = new DraftRepository(store.restart()).load(); assert.equal(restored.text,'二');
  assert.equal(restored.id,record.id);
});
test('draft clear follows pending writes and does not delete formal records', async () => {
  const store = new Store(); const drafts = new DraftRepository(store);
  const pending = drafts.save(newJournal('草稿')); const clear = drafts.clear();
  await Promise.all([pending,clear]); assert.equal(new DraftRepository(store.restart()).load(),undefined);
});
test('draft write failure is reported, next explicit attempt can recover', async () => {
  const store = new Store(); store.failFlushes.add(1); const drafts = new DraftRepository(store);
  await assert.rejects(drafts.save(newJournal('保留在编辑器')));
  const record = newJournal('重试成功'); await drafts.save(record);
  assert.equal(new DraftRepository(store.restart()).load().text,'重试成功');
});
test('corrupt draft is preserved rather than silently overwritten on load', () => {
  for (const raw of ['{',JSON.stringify({schemaVersion:9,records:[]}),JSON.stringify({schemaVersion:1,records:[]})]) {
    const store = new Store({[DRAFT_KEY]:raw}); const drafts = new DraftRepository(store);
    assert.throws(()=>drafts.load()); assert.equal(store.get(DRAFT_KEY),raw);
  }
});
test('saving same recovered draft twice updates instead of duplicating', async () => {
  const store = new Store(); const repo = new RecordRepository(store); await repo.initialize();
  const record = newJournal('草稿'); await repo.upsert(record); await repo.upsert(record);
  assert.equal(repo.timeline().length,1);
});
test('photo cleanup reference list protects current and recovery documents', async () => {
  const store = new Store(); const repo = new RecordRepository(store); await repo.initialize();
  const record = newJournal('照片'); record.photos=[{id:'old',relativePath:'photos/old.image'}];
  await repo.upsert(record); record.photos=[{id:'new',relativePath:'photos/new.image'}]; await repo.upsert(record);
  assert.deepEqual(new Set(repo.photoReferences()),new Set(['photos/old.image','photos/new.image']));
});

// Execute the actual PhotoStore with simulated platform APIs; no user album access.
const vm = require('node:vm');
function loadPhotoStore(api, picker) {
  const file = path.join(base, 'storage/PhotoStore.ets'); const mod = {exports:{}};
  const js = ts.transpileModule(fs.readFileSync(file,'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText;
  vm.runInNewContext(`(function(require,module,exports){${js}\n})`,{})(name=>{
    if(name==='@kit.CoreFileKit')return {fileIo:api};
    if(name==='@kit.MediaLibraryKit')return {photoAccessHelper:{PhotoViewPicker:class {select(options){return picker(options);}},PhotoViewMIMETypes:{IMAGE_TYPE:'image'}}};
    throw new Error(name);
  },mod,mod.exports);
  return mod.exports.PhotoStore;
}
function photoApi() {
  return {OpenMode:{READ_ONLY:0},copied:[],closed:[],deleted:[],
    async access(){return true;},async mkdir(){},async open(uri){return {fd:uri};},async stat(){return {size:100};},
    async copyFile(src,dest){this.copied.push(dest);},async close(file){this.closed.push(file.fd);},
    async unlink(file){this.deleted.push(file);},async listFile(){return ['keep.image','unused.image','unknown.jpg'];}};
}
test('picker honors remaining slots and copies temporary URIs into owned storage', async () => {
  const api=photoApi(); let requested;
  const Media=loadPhotoStore(api,async options=>{requested=options.maxSelectNumber;return {photoUris:['photo://1','photo://2']};});
  const result=await new Media('/owned').select(2);
  assert.equal(requested,2); assert.equal(result.length,2); assert.equal(api.closed.length,2);
  assert.ok(api.copied.every(p=>p.startsWith('/owned/photos/')));
  assert.ok(result.every(p=>p.relativePath.startsWith('photos/')));
});
test('picker cancellation creates no files', async () => {
  const api=photoApi();const Media=loadPhotoStore(api,async()=>({photoUris:[]}));
  assert.equal((await new Media('/owned').select(3)).length,0);assert.equal(api.copied.length,0);
});
test('partial photo copy failure closes files and removes incomplete imports', async () => {
  const api=photoApi();api.copyFile=async function(src,dest){this.copied.push(dest);throw new Error('disk full');};
  const Media=loadPhotoStore(api,async()=>({photoUris:['photo://1']}));
  await assert.rejects(new Media('/owned').select(1));assert.equal(api.closed.length,1);assert.equal(api.deleted.length,1);
});
test('large photo is rejected and its source handle is closed', async () => {
  const api=photoApi();api.stat=async()=>({size:31*1024*1024});
  const Media=loadPhotoStore(api,async()=>({photoUris:['photo://1']}));
  await assert.rejects(new Media('/owned').select(1));assert.equal(api.closed.length,1);assert.equal(api.copied.length,0);
});
test('startup cleanup deletes only unreferenced files owned by this importer', async () => {
  const api=photoApi();const Media=loadPhotoStore(api,async()=>({photoUris:[]}));
  await new Media('/owned').collectUnused(['photos/keep.image']);
  assert.deepEqual(api.deleted,['/owned/photos/unused.image']);
});

const { REFLECTION_SCENES, reflectionScene, newReflection, updateReflection, reflectionHasContent } = require(path.join(base, 'models/ReflectionModel.ets'));
test('all five reflection scenes create independent stable records with four-step progress', () => {
  assert.equal(REFLECTION_SCENES.length,5); assert.equal(new Set(REFLECTION_SCENES.map(s=>s.id)).size,5);
  for (const scene of REFLECTION_SCENES) {
    const seed = newReflection(scene.id); assert.equal(seed.reflection.step,0);
    const final = updateReflection(seed,'发生了一件事',['委屈'],'被尊重','先休息',4);
    assert.equal(final.id,seed.id); assert.equal(final.createdAt,seed.createdAt);
    assert.equal(final.kind,'reflection'); assert.equal(final.title,scene.title);
    assert.equal(final.reflection.sceneId,scene.id); assert.equal(final.reflection.step,4);
    assert.ok(reflectionHasContent(final)); parseDocument(JSON.stringify({schemaVersion:1,records:[final]}));
  }
});
test('reflection draft resumes exact progress without interfering with ordinary journal draft', async () => {
  const ordinaryStore = new Store(); const reflectionStore = new Store();
  const ordinary = new DraftRepository(ordinaryStore); const reflections = new DraftRepository(reflectionStore);
  await ordinary.save(newJournal('日记草稿'));
  const record = updateReflection(newReflection('boundary'),'临时接到任务',['疲惫'],'休息','',2);
  await reflections.save(record);
  const restored = new DraftRepository(reflectionStore.restart()).load();
  assert.deepEqual(restored,record); assert.equal(restored.reflection.step,2);
  await reflections.clear(); assert.equal(ordinary.load().text,'日记草稿');
});
test('skipping all questions does not manufacture user answers or a meaningful card', () => {
  const skipped = updateReflection(newReflection('words'),'',[],'','',4);
  assert.equal(reflectionHasContent(skipped),false);
  assert.equal(skipped.reflection.facts,''); assert.equal(skipped.reflection.nextStep,'');
  const moodsOnly = updateReflection(skipped,'',['说不清'],'','',4);
  assert.equal(reflectionHasContent(moodsOnly),true);
});
test('saved reflection card is visible in timeline and editable without duplicate records', async () => {
  const store = new Store(); const repo = new RecordRepository(store); await repo.initialize();
  const card = updateReflection(newReflection('relationship'),'有点误会',['委屈'],'空间','先暂停交流',4);
  await repo.upsert(card);
  const reopened = new RecordRepository(store.restart()); await reopened.initialize();
  const previous = reopened.timeline()[0]; assert.equal(previous.title,reflectionScene('relationship').title);
  const edited = updateReflection(previous,'有点误会',['平静'],'空间','明天再决定',4);
  await reopened.upsert(edited); assert.equal(reopened.timeline().length,1);
  assert.equal(reopened.timeline()[0].reflection.nextStep,'明天再决定');
  await reopened.removeById(edited.id); assert.equal(reopened.timeline().length,0);
});
test('invalid scene, out-of-range progress and oversized reflection input are rejected', () => {
  assert.throws(()=>newReflection('unknown'));
  for(const step of [-1,5,1.5]) assert.throws(()=>updateReflection(newReflection('words'),'a',[],'','',step));
  assert.throws(()=>updateReflection(newReflection('words'),'x'.repeat(1501),[],'','',0));
  const card = newReflection('words'); card.reflection.step = 5;
  assert.throws(()=>parseDocument(JSON.stringify({schemaVersion:1,records:[card]})));
});
test('older reflection records without progress remain compatible', () => {
  const card = newReflection('selfkindness'); delete card.reflection.step;
  assert.equal(parseDocument(JSON.stringify({schemaVersion:1,records:[card]})).records.length,1);
});

const { WRITING_TEMPLATES, templateRecord, newJoy } = require(path.join(base,'models/WritingTemplates.ets'));
const { filterRecords } = require(path.join(base,'models/RecordFilters.ets'));
test('five short templates create independent records; joy template uses joy type', () => {
  assert.equal(WRITING_TEMPLATES.length,5);
  for(const t of WRITING_TEMPLATES) {
    assert.equal(t.questions.length,2); const a=templateRecord(t.id),b=templateRecord(t.id);
    assert.notEqual(a.id,b.id);assert.equal(a.title,t.title);assert.ok(a.text.includes(t.questions[1]));
    assert.equal(a.kind,t.id==='joy'?'joy':'journal');
  }
  assert.throws(()=>templateRecord('missing'));
});
test('custom title-only or photo joy remains editable and survives restart', async () => {
  const store=new Store();const repo=new RecordRepository(store);await repo.initialize();
  const joy=newJoy();joy.title='窗边的一束光';joy.photos=[{id:'p',relativePath:'photos/p.image'}];
  validateEditorRecord(joy);await repo.upsert(joy);
  const restarted=new RecordRepository(store.restart());await restarted.initialize();
  assert.deepEqual(restarted.timeline()[0],joy);
  joy.text='后来加了一句话';await restarted.upsert(joy);assert.equal(restarted.timeline().length,1);
  assert.equal(restarted.timeline()[0].kind,'joy');
});
test('bottle ritual is idempotent, points at original and follows edits and deletion',async()=>{
  const store=new Store();const repo=new RecordRepository(store);await repo.initialize();
  const record=newJournal('心事');await repo.upsert(record);
  await repo.putInBottle(record.id);await repo.putInBottle(record.id);
  assert.equal(repo.timeline().length,1);assert.equal(filterRecords(repo.timeline(),'瓶子','','').length,1);
  record.text='改过的心事';await repo.upsert(record);
  assert.equal(filterRecords(repo.timeline(),'瓶子','','')[0].text,'改过的心事');
  await repo.removeById(record.id);assert.equal(filterRecords(repo.timeline(),'瓶子','','').length,0);
});
test('favorite survives restart and stale draft save, can be explicitly removed',async()=>{
  const store=new Store();const repo=new RecordRepository(store);await repo.initialize();
  const record=updateReflection(newReflection('boundary'),'任务',['疲惫'],'休息','晚点回复',4);
  await repo.upsert(record);await repo.setFavorite(record.id,true);
  await repo.upsert(record);assert.equal(repo.timeline()[0].favorite,true);
  const restarted=new RecordRepository(store.restart());await restarted.initialize();
  assert.equal(filterRecords(restarted.timeline(),'收藏','','').length,1);
  await restarted.setFavorite(record.id,false);assert.equal(filterRecords(restarted.timeline(),'收藏','','').length,0);
});
test('legacy bottles and preset joys appear in unified timeline without duplication',async()=>{
  const store=new Store(seed());const repo=new RecordRepository(store);await repo.initialize();
  assert.equal(repo.timeline().length,3);const bottles=filterRecords(repo.timeline(),'瓶子','','');
  assert.equal(bottles.length,1);await repo.putInBottle(bottles[0].id);assert.equal(repo.timeline().length,3);
});
test('custom joy with preset title never becomes the preset toggle target',async()=>{
  const store=new Store(seed());const repo=new RecordRepository(store);await repo.initialize();
  const joy=newJoy();joy.title='喝杯热饮';joy.text='自己的照片记录';await repo.upsert(joy);
  assert.equal(repo.joys().length,2);assert.equal(repo.presetJoys().length,1);
  await repo.remove('joy',repo.presetJoys()[0].id);
  assert.equal(repo.joys().length,1);assert.equal(repo.timeline().find(r=>r.id===joy.id).text,'自己的照片记录');
});
test('record filters combine category, date and title/tag search',()=>{
  const a=newJoy();a.title='热饮';a.tags=['散步'];a.favorite=true;
  const b=newJournal('心事');b.date='2026-1-1';b.bottled=true;
  assert.equal(filterRecords([a,b],'收藏','','热饮').length,1);
  assert.equal(filterRecords([a,b],'微光','','散步').length,1);
  assert.equal(filterRecords([a,b],'瓶子','2026-1-1','心事').length,1);
  assert.equal(filterRecords([a,b],'整理卡','','').length,0);
});
test('failed favorite or bottle write leaves original metadata unchanged',async()=>{
  const store=new Store();const repo=new RecordRepository(store);await repo.initialize();
  const r=newJournal('记录');await repo.upsert(r);store.failFlushes.add(store.flushCount+2);
  await assert.rejects(repo.setFavorite(r.id,true));assert.equal(repo.timeline()[0].favorite,false);
  store.failFlushes.add(store.flushCount+2);await assert.rejects(repo.putInBottle(r.id));
  assert.notEqual(repo.timeline()[0].bottled,true);
});
