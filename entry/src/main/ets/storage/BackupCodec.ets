import { reflectionScene } from '../models/ReflectionModel';
import { EmotionRecord, RecordDocument } from '../models/Record';
import { parseDocument, SCHEMA_VERSION } from './RecordCodec';

export const MAX_BACKUP_BYTES: number = 64 * 1024 * 1024;
export const MAX_PHOTO_BYTES: number = 30 * 1024 * 1024;
export interface BackupPhoto { relativePath: string; data: string; sha256: string; }
export interface LocalBackup {
  format: string;
  version: number;
  createdAt: number;
  document: RecordDocument;
  journalDraft: EmotionRecord | null;
  reflectionDraft: EmotionRecord | null;
  photos: BackupPhoto[];
}
export interface RestoreSummary { added: number; kept: number; draftsAdded: number; draftsKept: number; }

export function validPhotoPath(path: string): boolean { return /^photos\/[a-zA-Z0-9-]+\.image$/.test(path); }
export function draftRaw(record: EmotionRecord | null): string | null {
  return record === null ? null : JSON.stringify({ schemaVersion: SCHEMA_VERSION, records: [record] });
}
export function parseDraft(raw: string | undefined): EmotionRecord | null {
  if (raw === undefined) return null;
  const doc: RecordDocument = parseDocument(raw);
  if (doc.records.length !== 1) throw new Error('Invalid draft');
  return doc.records[0];
}
export function backupReferences(backup: LocalBackup): string[] {
  const records: EmotionRecord[] = backup.document.records.slice();
  if (backup.journalDraft) records.push(backup.journalDraft);
  if (backup.reflectionDraft) records.push(backup.reflectionDraft);
  const paths: Set<string> = new Set();
  records.forEach((record: EmotionRecord) => record.photos.forEach((photo) => {
    if (!validPhotoPath(photo.relativePath)) throw new Error('Unsafe photo path');
    paths.add(photo.relativePath);
  }));
  return Array.from(paths);
}
export function parseBackup(raw: string): LocalBackup {
  if (raw.length > MAX_BACKUP_BYTES) throw new Error('Backup too large');
  const backup: LocalBackup = JSON.parse(raw) as LocalBackup;
  if (!backup || backup.format !== 'zhiyu-local-backup' || backup.version !== 1 ||
    !Number.isFinite(backup.createdAt) || !Number.isFinite(new Date(backup.createdAt).getTime()) || backup.createdAt < 0 || !Array.isArray(backup.photos)) throw new Error('Invalid backup format');
  backup.document = parseDocument(JSON.stringify(backup.document));
  if (backup.journalDraft !== null) parseDraft(draftRaw(backup.journalDraft) ?? undefined);
  if (backup.reflectionDraft !== null) {
    const reflection = parseDraft(draftRaw(backup.reflectionDraft) ?? undefined);
    if (!reflection || reflection.kind !== 'reflection' || !reflection.reflection) throw new Error('Invalid reflection draft');
  }
  const records: EmotionRecord[] = backup.document.records.slice();
  if (backup.journalDraft) {
    if (backup.journalDraft.kind === 'reflection') throw new Error('Wrong draft category');
    records.push(backup.journalDraft);
  }
  if (backup.reflectionDraft) records.push(backup.reflectionDraft);
  records.forEach((record: EmotionRecord) => {
    if (record.kind === 'reflection') {
      if (!record.reflection) throw new Error('Missing reflection');
      reflectionScene(record.reflection.sceneId);
    }
  });
  const references: string[] = backupReferences(backup);
  const found: Set<string> = new Set();
  backup.photos.forEach((photo: BackupPhoto) => {
    if (!photo || typeof photo.relativePath !== 'string' || !validPhotoPath(photo.relativePath) ||
      found.has(photo.relativePath) || !references.includes(photo.relativePath) ||
      typeof photo.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(photo.sha256) ||
      typeof photo.data !== 'string' || photo.data.length === 0 || photo.data.length > Math.ceil(MAX_PHOTO_BYTES / 3) * 4 ||
      photo.data.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(photo.data)) throw new Error('Invalid backup photo');
    found.add(photo.relativePath);
  });
  if (found.size !== references.length) throw new Error('Missing backup photos');
  return backup;
}
