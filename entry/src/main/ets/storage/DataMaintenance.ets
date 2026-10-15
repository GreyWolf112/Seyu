import { EmotionRecord, RecordDocument } from '../models/Record';
import { RecordStore } from './RecordRepository';
import { DOCUMENT_KEY, RECOVERY_KEY, SCHEMA_VERSION, parseDocument } from './RecordCodec';
import { DRAFT_KEY } from './DraftRepository';
import { BackupPhoto, LocalBackup, RestoreSummary, backupReferences, draftRaw, parseBackup, parseDraft, MAX_BACKUP_BYTES } from './BackupCodec';

export const MAINTENANCE_KEY: string = 'maintenance_job_v1';
export interface BackupMedia {
  readPhoto(path: string): Promise<BackupPhoto>;
  checkPhoto(photo: BackupPhoto): Promise<void>;
  stagePhoto(photo: BackupPhoto): Promise<string>;
  erasePhotos(): Promise<void>;
}
interface MaintenanceJob {
  version: number;
  mode: string;
  documentRaw: string;
  journalRaw: string | null;
  reflectionRaw: string | null;
  previousRaw: string | null;
}

// Durable roll-forward journal: on any failure after intent is saved, block edits
// and finish the same operation before loading records or collecting photos.
export class DataMaintenance {
  private store: RecordStore;
  private journal: RecordStore;
  private reflection: RecordStore;
  private media: BackupMedia;
  private pending: MaintenanceJob | undefined = undefined;
  constructor(store: RecordStore, journal: RecordStore, reflection: RecordStore, media: BackupMedia) {
    this.store = store; this.journal = journal; this.reflection = reflection; this.media = media;
  }
  isPending(): boolean { return this.pending !== undefined || this.store.get(MAINTENANCE_KEY) !== undefined; }
  private current(): RecordDocument {
    const raw = this.store.get(DOCUMENT_KEY);
    if (raw === undefined) throw new Error('Records unavailable');
    return parseDocument(raw);
  }
  async createBackup(): Promise<string> {
    if (this.isPending()) throw new Error('Maintenance pending');
    const backup: LocalBackup = { format: 'zhiyu-local-backup', version: 1, createdAt: Date.now(),
      document: this.current(), journalDraft: parseDraft(this.journal.get(DRAFT_KEY)),
      reflectionDraft: parseDraft(this.reflection.get(DRAFT_KEY)), photos: [] };
    let length: number = JSON.stringify(backup).length;
    for (const path of backupReferences(backup)) {
      const photo = await this.media.readPhoto(path);
      length += photo.data.length + 256;
      if (length > MAX_BACKUP_BYTES) throw new Error('Backup too large');
      backup.photos.push(photo);
    }
    const raw: string = JSON.stringify(backup);
    parseBackup(raw);
    return raw;
  }
  async inspect(raw: string): Promise<LocalBackup> {
    if (this.isPending()) throw new Error('Maintenance pending');
    const backup: LocalBackup = parseBackup(raw);
    for (const photo of backup.photos) await this.media.checkPhoto(photo);
    return backup;
  }
  summarize(backup: LocalBackup): RestoreSummary {
    const current = this.current();
    const added = backup.document.records.filter((record: EmotionRecord) => !current.records.some((item: EmotionRecord) => item.id === record.id)).length;
    let draftsAdded: number = 0;
    let draftsKept: number = 0;
    if (backup.journalDraft) { if (this.journal.get(DRAFT_KEY) === undefined) draftsAdded++; else draftsKept++; }
    if (backup.reflectionDraft) { if (this.reflection.get(DRAFT_KEY) === undefined) draftsAdded++; else draftsKept++; }
    return { added, kept: backup.document.records.length - added, draftsAdded, draftsKept };
  }
  async restore(source: LocalBackup): Promise<void> {
    const backup = await this.inspect(JSON.stringify(source));
    const current = this.current();
    const incoming: EmotionRecord[] = backup.document.records.filter((record: EmotionRecord) => !current.records.some((item: EmotionRecord) => item.id === record.id));
    const journalRaw: string | undefined = this.journal.get(DRAFT_KEY);
    const reflectionRaw: string | undefined = this.reflection.get(DRAFT_KEY);
    // Validate existing drafts before creating any operation; don't silently discard corrupt ones.
    parseDraft(journalRaw); parseDraft(reflectionRaw);
    const journal = journalRaw === undefined ? backup.journalDraft : null;
    const reflection = reflectionRaw === undefined ? backup.reflectionDraft : null;
    const selected: EmotionRecord[] = incoming.slice();
    if (journal) selected.push(journal);
    if (reflection) selected.push(reflection);
    const staged: Map<string, string> = new Map();
    for (const record of selected) {
      for (const photo of record.photos) {
        const original = photo.relativePath;
        let destination: string | undefined = staged.get(original);
        if (!destination) {
          const payload = backup.photos.find((item: BackupPhoto) => item.relativePath === original);
          if (!payload) throw new Error('Missing photo');
          destination = await this.media.stagePhoto(payload);
          staged.set(original, destination);
        }
        photo.relativePath = destination;
      }
    }
    const document: RecordDocument = { schemaVersion: SCHEMA_VERSION, records: [...incoming, ...current.records] };
    const job: MaintenanceJob = { version: 1, mode: 'restore', documentRaw: JSON.stringify(document),
      journalRaw: journalRaw ?? draftRaw(journal), reflectionRaw: reflectionRaw ?? draftRaw(reflection),
      previousRaw: JSON.stringify(current) };
    await this.begin(job);
  }
  async erase(): Promise<void> {
    if (this.isPending()) throw new Error('Maintenance pending');
    await this.begin({ version: 1, mode: 'erase', documentRaw: JSON.stringify({ schemaVersion: SCHEMA_VERSION, records: [] }),
      journalRaw: null, reflectionRaw: null, previousRaw: null });
  }
  private async begin(job: MaintenanceJob): Promise<void> {
    this.pending = job;
    await this.store.put(MAINTENANCE_KEY, JSON.stringify(job));
    await this.store.flush();
    await this.recover();
  }
  async recover(): Promise<void> {
    const raw: string | undefined = this.store.get(MAINTENANCE_KEY);
    if (!this.pending && raw === undefined) return;
    const job: MaintenanceJob = this.pending || JSON.parse(raw || '') as MaintenanceJob;
    if (job.version !== 1 || !['restore', 'erase'].includes(job.mode) || typeof job.documentRaw !== 'string' ||
      (job.journalRaw !== null && typeof job.journalRaw !== 'string') ||
      (job.reflectionRaw !== null && typeof job.reflectionRaw !== 'string') ||
      (job.previousRaw !== null && typeof job.previousRaw !== 'string')) throw new Error('Invalid maintenance journal');
    const document = parseDocument(job.documentRaw);
    parseDraft(job.journalRaw ?? undefined); parseDraft(job.reflectionRaw ?? undefined);
    if (job.previousRaw !== null) parseDocument(job.previousRaw);
    if (job.mode === 'erase' && (document.records.length !== 0 || job.journalRaw !== null || job.reflectionRaw !== null || job.previousRaw !== null)) throw new Error('Invalid erase journal');
    this.pending = job;
    // Re-persist intent as well: the previous flush or journal removal may have failed.
    await this.store.put(MAINTENANCE_KEY, JSON.stringify(job));
    await this.store.flush();
    await this.store.put(DOCUMENT_KEY, job.documentRaw);
    if (job.previousRaw !== null) await this.store.put(RECOVERY_KEY, job.previousRaw);
    else await this.store.remove(RECOVERY_KEY);
    if (job.mode === 'erase') {
      for (const key of ['entries', 'bottles', 'joys']) await this.store.remove(key);
    }
    await this.store.flush();
    await this.applyDraft(this.journal, job.journalRaw);
    await this.applyDraft(this.reflection, job.reflectionRaw);
    if (job.mode === 'erase') await this.media.erasePhotos();
    await this.store.remove(MAINTENANCE_KEY);
    await this.store.flush();
    this.pending = undefined;
  }
  private async applyDraft(store: RecordStore, raw: string | null): Promise<void> {
    if (raw === null) await store.remove(DRAFT_KEY); else await store.put(DRAFT_KEY, raw);
    await store.flush();
  }
}
