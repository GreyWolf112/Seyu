import { JournalEntry, Bottle, Joy } from '../models/LegacyModels';
import { EmotionRecord, RecordDocument, RecordKind } from '../models/Record';
import { DOCUMENT_KEY, RECOVERY_KEY, SCHEMA_VERSION, legacyRecord, migrateLegacy, parseDocument } from './RecordCodec';

// Narrow interface permits fault-injection tests without device Preferences.
export interface RecordStore {
  get(key: string): string | undefined;
  put(key: string, value: string): Promise<void>;
  remove(key: string): Promise<void>;
  flush(): Promise<void>;
}

export class RecordRepository {
  private document: RecordDocument = { schemaVersion: SCHEMA_VERSION, records: [] };
  private ready: boolean = false;
  private busy: boolean = false;

  private store: RecordStore;

  constructor(store: RecordStore) { this.store = store; }

  async initialize(): Promise<void> {
    this.ready = false;
    const raw: string | undefined = this.store.get(DOCUMENT_KEY);
    if (raw !== undefined) {
      // Never reinterpret corrupt/newer documents as a fresh install or resurrect deleted legacy records.
      this.document = parseDocument(raw);
      this.ready = true;
      return;
    }
    const migrated: RecordDocument = migrateLegacy(this.store.get('entries') ?? '[]', this.store.get('bottles') ?? '[]', this.store.get('joys') ?? '[]');
    await this.commit(migrated);
    this.ready = true;
  }

  snapshot(): RecordDocument {
    return parseDocument(JSON.stringify(this.document));
  }

  journals(): JournalEntry[] {
    return this.document.records.filter((r: EmotionRecord) => r.kind === 'journal').map((r: EmotionRecord): JournalEntry => {
      return { id: r.legacyId || r.id, date: r.date, mood: r.moods[0] || '平静', text: r.text };
    });
  }

  bottles(): Bottle[] {
    return this.document.records.filter((r: EmotionRecord) => r.kind === 'bottle').map((r: EmotionRecord): Bottle => {
      return { id: r.legacyId || r.id, date: r.date, mood: r.moods[0] || '平静', text: r.text };
    });
  }

  presetJoys(): Joy[] {
    const ids: string[] = this.document.records.filter((r: EmotionRecord) => r.kind === 'joy' && !!r.legacyId).map((r: EmotionRecord) => r.legacyId);
    return this.joys().filter((joy: Joy) => ids.includes(joy.id));
  }

  joys(): Joy[] {
    return this.document.records.filter((r: EmotionRecord) => r.kind === 'joy').map((r: EmotionRecord): Joy => {
      return { id: r.legacyId || r.id, date: r.date, title: r.title };
    });
  }

  async save(kind: RecordKind, id: string, date: string, mood: string, text: string, title: string = ''): Promise<void> {
    const key: string = `${kind}:${id}`;
    const next: RecordDocument = this.snapshot();
    const previous: EmotionRecord | undefined = next.records.find((r: EmotionRecord) => r.id === key);
    const record: EmotionRecord = previous || legacyRecord(kind, id, date, mood, text, title);
    const now: number = Date.now();
    if (!previous) { record.createdAt = now; record.timePrecision = 'millisecond'; }
    record.updatedAt = now;
    record.moods = mood ? [mood] : [];
    record.text = text;
    record.title = title;
    next.records = [record, ...next.records.filter((r: EmotionRecord) => r.id !== key)];
    await this.write(next);
  }

  async remove(kind: RecordKind, id: string): Promise<void> {
    const next: RecordDocument = this.snapshot();
    next.records = next.records.filter((r: EmotionRecord) => r.id !== `${kind}:${id}`);
    await this.write(next);
  }

  photoReferences(): string[] {
    const references: string[] = [];
    this.document.records.forEach((record: EmotionRecord) => {
      record.photos.forEach((photo) => { references.push(photo.relativePath); });
    });
    const previous: string | undefined = this.store.get(RECOVERY_KEY);
    if (previous !== undefined) {
      parseDocument(previous).records.forEach((record: EmotionRecord) => {
        record.photos.forEach((photo) => { references.push(photo.relativePath); });
      });
    }
    return references;
  }

  timeline(): EmotionRecord[] {
    return this.snapshot().records;
  }

  async upsert(record: EmotionRecord): Promise<void> {
    const next: RecordDocument = this.snapshot();
    const copy: EmotionRecord = parseDocument(JSON.stringify({ schemaVersion: SCHEMA_VERSION, records: [record] })).records[0];
    const existing = next.records.find((r: EmotionRecord) => r.id === copy.id);
    if (existing) { copy.favorite = existing.favorite; copy.bottled = existing.bottled; }
    next.records = [copy, ...next.records.filter((r: EmotionRecord) => r.id !== copy.id)];
    await this.write(next);
  }

  async setFavorite(id: string, value: boolean): Promise<void> {
    const next = this.snapshot();
    const record = next.records.find((r: EmotionRecord) => r.id === id);
    if (!record) throw new Error('Record not found');
    record.favorite = value;
    await this.write(next);
  }

  async putInBottle(id: string): Promise<void> {
    const next = this.snapshot();
    const record = next.records.find((r: EmotionRecord) => r.id === id);
    if (!record) throw new Error('Record not found');
    if (record.bottled || record.kind === 'bottle') return;
    record.bottled = true;
    await this.write(next);
  }

  async removeById(id: string): Promise<void> {
    const next: RecordDocument = this.snapshot();
    next.records = next.records.filter((r: EmotionRecord) => r.id !== id);
    await this.write(next);
  }

  private async write(next: RecordDocument): Promise<void> {
    if (!this.ready || this.busy) throw new Error('Storage unavailable or busy');
    this.busy = true;
    try { await this.commit(next); } finally { this.busy = false; }
  }

  private async commit(next: RecordDocument): Promise<void> {
    const serialized: string = JSON.stringify(next);
    parseDocument(serialized);
    const old: string | undefined = this.store.get(DOCUMENT_KEY);
    // Retain the previous valid document before overwriting. Legacy keys are never modified.
    if (old !== undefined) {
      await this.store.put(RECOVERY_KEY, old);
      await this.store.flush();
    }
    try {
      await this.store.put(DOCUMENT_KEY, serialized);
      await this.store.flush();
    } catch (error) {
      try {
        if (old === undefined) await this.store.remove(DOCUMENT_KEY);
        else await this.store.put(DOCUMENT_KEY, old);
        await this.store.flush();
      } catch (_) { this.ready = false; }
      throw new Error('Record write failed');
    }
    this.document = next;
  }
}
