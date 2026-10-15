const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const ts = require(process.env.ZHIYU_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, filename);
};
const base = path.resolve(__dirname, '../entry/src/main/ets');
const { buildMoodReview } = require(path.join(base, 'models/MoodReview.ets'));
const { filterRecords } = require(path.join(base, 'models/RecordFilters.ets'));
const { normalizedRecordDate } = require(path.join(base, 'models/RecordDate.ets'));
let id = 0;
function record(date, values = {}) {
  return { id: `review-${++id}`, kind: 'journal', date, createdAt: 0, updatedAt: 0,
    timePrecision: 'day', moods: [], intensity: null, tags: [], title: '', text: '', photos: [],
    reflection: null, favorite: false, legacyId: '', ...values };
}
const now = new Date(2026, 9, 15, 23, 59);
test('seven local calendar days include today and exclude older and future records', () => {
  const data = [record('2026-10-8'), record('2026-10-9'), record('2026-10-15'), record('2026-10-16')];
  const review = buildMoodReview(data, 7, now);
  assert.equal(review.start, '2026-10-9'); assert.equal(review.end, '2026-10-15');
  assert.equal(review.totalRecords, 2); assert.equal(review.recordedDays, 2);
  assert.equal(review.weeks.flat().length, 7);
});
test('counts each emotion and tag once per calendar day across all record kinds', () => {
  const data = [record('2026-10-15', { moods: ['疲惫', '疲惫', '平静'], tags: ['工作', '工作'] }),
    record('2026-10-15', { kind: 'mood', moods: ['疲惫'], tags: ['工作'] }),
    record('2026-10-14', { kind: 'reflection', moods: ['疲惫'], tags: ['工作', '关系'] }),
    record('2026-10-14', { kind: 'joy', moods: ['开心'] }), record('2026-10-13', { kind: 'bottle' })];
  const review = buildMoodReview(data, 7, now);
  assert.equal(review.totalRecords, 5); assert.equal(review.recordedDays, 3); assert.equal(review.moodDays, 2);
  assert.deepEqual(review.moods.find(x => x.label === '疲惫'), { label: '疲惫', days: 2 });
  assert.deepEqual(review.tags.find(x => x.label === '工作'), { label: '工作', days: 2 });
  assert.equal(review.joyCount, 1);
});
test('empty days and records without mood remain unknown, not neutral or negative', () => {
  const review = buildMoodReview([record('2026-10-15', { text: '今天很难过', kind: 'joy' })], 7, now);
  assert.equal(review.moodDays, 0); assert.deepEqual(review.moods, []); assert.deepEqual(review.tags, []);
  assert.equal(review.weeks.flat().filter(d => d.count === 0).length, 6);
  assert.equal(review.joyCount, 1); assert.equal(review.recordedDays, 1);
});
test('thirty day range crosses year boundary and leap days without fixed 24h arithmetic', () => {
  const winter = buildMoodReview([], 30, new Date(2026, 0, 10));
  assert.equal(winter.start, '2025-12-12'); assert.equal(winter.weeks.flat().length, 30);
  const leap = buildMoodReview([record('2024-02-29')], 7, new Date(2024, 2, 1));
  assert.equal(leap.totalRecords, 1); assert.equal(leap.weeks.flat()[5].key, '2024-2-29');
});
test('padded legacy dates are combined and drill down returns exactly the counted records', () => {
  const data = [record('2026-10-09', { moods: ['平静'] }), record('2026-10-9', { moods: ['平静'] })];
  const review = buildMoodReview(data, 7, now);
  assert.equal(review.recordedDays, 1); assert.equal(review.moods[0].days, 1);
  assert.equal(filterRecords(data, '全部', review.start, '').length, 2);
  assert.equal(filterRecords(data, '全部', '2026-10-09', '').length, 2);
});
test('invalid dates never roll over into a real day and unsupported ranges fail', () => {
  assert.equal(normalizedRecordDate('2026-02-30'), '');
  assert.equal(normalizedRecordDate('2026-13-1'), '');
  assert.equal(normalizedRecordDate('2026-10-15T00:00:00Z'), '');
  assert.throws(() => buildMoodReview([], 14, now));
  assert.throws(() => buildMoodReview([], 7, new Date('invalid')));
  assert.equal(filterRecords([record('invalid')], '全部', 'invalid', '').length, 0);
});
test('review does not mutate source or retain deleted and edited values', () => {
  const data = [record('2026-10-15', { moods: ['疲惫'], tags: ['工作'] })];
  const before = JSON.stringify(data);
  const first = buildMoodReview(data, 7, now);
  first.weeks[0][6].moods.push('开心');
  assert.equal(JSON.stringify(data), before);
  data[0].moods = ['平静'];
  assert.deepEqual(buildMoodReview(data, 7, now).moods, [{ label: '平静', days: 1 }]);
  assert.equal(buildMoodReview([], 7, now).totalRecords, 0);
});
test('record date, not edit timestamp, determines review range', () => {
  const old = record('2026-9-1', { updatedAt: now.getTime(), moods: ['平静'] });
  const legacy = record('2026-10-15', { createdAt: 0, updatedAt: 0 });
  assert.equal(buildMoodReview([old, legacy], 7, now).totalRecords, 1);
});
test('local date range keeps seven distinct days across DST transition', () => {
  const previous = process.env.TZ;
  process.env.TZ = 'America/New_York';
  try {
    const review = buildMoodReview([], 7, new Date(2026, 2, 10, 0, 10));
    assert.deepEqual(review.weeks.flat().map(d => d.key), [
      '2026-3-4', '2026-3-5', '2026-3-6', '2026-3-7', '2026-3-8', '2026-3-9', '2026-3-10'
    ]);
  } finally { if (previous === undefined) delete process.env.TZ; else process.env.TZ = previous; }
});
