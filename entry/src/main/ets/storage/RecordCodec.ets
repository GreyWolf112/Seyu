import { JournalEntry, Bottle, Joy } from '../models/LegacyModels';
import { EmotionRecord, RecordDocument, RecordKind } from '../models/Record';

export const SCHEMA_VERSION: number = 1;
export const DOCUMENT_KEY: string = 'record_document_v1';
export const RECOVERY_KEY: string = 'record_document_previous_v1';

export function dayTimestamp(date: string): number {
  if (typeof date !== 'string' || !/^\d{4}-\d{1,2}-\d{1,2}$/.test(date)) throw new Error('Invalid date');
  const parts: number[] = date.split('-').map((part: string) => Number(part));
  const value: Date = new Date(parts[0], parts[1] - 1, parts[2]);
  if (value.getFullYear() !== parts[0] || value.getMonth() !== parts[1] - 1 || value.getDate() !== parts[2]) throw new Error('Invalid date');
  return value.getTime();
}

export function legacyRecord(kind: RecordKind, id: string, date: string, mood: string, text: string, title: string): EmotionRecord {
  if (typeof id !== 'string' || !id || typeof mood !== 'string' || typeof text !== 'string' || typeof title !== 'string') throw new Error('Invalid legacy record');
  const timestamp: number = dayTimestamp(date);
  return {
    id: `${kind}:${id}`, kind, date, createdAt: timestamp, updatedAt: timestamp, timePrecision: 'day',
    moods: mood ? [mood] : [], intensity: null, tags: [], title, text, photos: [], reflection: null,
    favorite: false, legacyId: id
  };
}

export function migrateLegacy(entriesRaw: string, bottlesRaw: string, joysRaw: string): RecordDocument {
  const entries: JournalEntry[] = JSON.parse(entriesRaw) as JournalEntry[];
  const bottles: Bottle[] = JSON.parse(bottlesRaw) as Bottle[];
  const joys: Joy[] = JSON.parse(joysRaw) as Joy[];
  if (!Array.isArray(entries) || !Array.isArray(bottles) || !Array.isArray(joys)) throw new Error('Invalid legacy arrays');
  const records: EmotionRecord[] = [];
  entries.forEach((item: JournalEntry) => { records.push(legacyRecord('journal', item.id, item.date, item.mood, item.text, '')); });
  bottles.forEach((item: Bottle) => { records.push(legacyRecord('bottle', item.id, item.date, item.mood, item.text, '')); });
  joys.forEach((item: Joy) => { records.push(legacyRecord('joy', item.id, item.date, '', '', item.title)); });
  // Same timestamps across categories are valid. Duplicates inside one category are not silently discarded.
  const ids: Set<string> = new Set<string>();
  records.forEach((record: EmotionRecord) => {
    if (ids.has(record.id)) throw new Error('Duplicate legacy id');
    if (record.reflection && record.reflection.step !== undefined &&
      (!Number.isInteger(record.reflection.step) || record.reflection.step < 0 || record.reflection.step > 4)) throw new Error('Invalid reflection progress');
    ids.add(record.id);
  });
  return { schemaVersion: SCHEMA_VERSION, records };
}

function stringsValid(values: string[]): boolean {
  return Array.isArray(values) && values.every((value: string) => typeof value === 'string');
}

export function parseDocument(raw: string): RecordDocument {
  const doc: RecordDocument = JSON.parse(raw) as RecordDocument;
  if (!doc || doc.schemaVersion !== SCHEMA_VERSION || !Array.isArray(doc.records)) throw new Error('Unsupported or corrupt document');
  const ids: Set<string> = new Set<string>();
  doc.records.forEach((record: EmotionRecord) => {
    if (!record || typeof record.id !== 'string' || !record.id || ids.has(record.id) ||
      !['mood', 'journal', 'bottle', 'joy', 'reflection'].includes(record.kind) ||
      !Number.isFinite(record.createdAt) || !Number.isFinite(record.updatedAt) ||
      !['day', 'millisecond'].includes(record.timePrecision) ||
      !stringsValid(record.moods) || !stringsValid(record.tags) ||
      typeof record.title !== 'string' || typeof record.text !== 'string' ||
      typeof record.favorite !== 'boolean' || typeof record.legacyId !== 'string' ||
      (record.intensity !== null && (!Number.isFinite(record.intensity) || record.intensity < 0 || record.intensity > 10)) ||
      !Array.isArray(record.photos)) throw new Error('Invalid record');
    if (record.bottled !== undefined && typeof record.bottled !== 'boolean') throw new Error('Invalid bottle marker');
    dayTimestamp(record.date);
    record.photos.forEach((photo) => {
      if (!photo || typeof photo.id !== 'string' || !photo.id || typeof photo.relativePath !== 'string' ||
        !photo.relativePath || photo.relativePath.startsWith('/') || photo.relativePath.includes('..') || photo.relativePath.includes(':')) throw new Error('Invalid photo');
    });
    if (record.reflection !== null && (!record.reflection || typeof record.reflection.sceneId !== 'string' ||
      typeof record.reflection.facts !== 'string' || typeof record.reflection.needs !== 'string' || typeof record.reflection.nextStep !== 'string')) throw new Error('Invalid reflection');
    if (record.reflection && record.reflection.step !== undefined &&
      (!Number.isInteger(record.reflection.step) || record.reflection.step < 0 || record.reflection.step > 4)) throw new Error('Invalid reflection progress');
    ids.add(record.id);
  });
  return doc;
}
