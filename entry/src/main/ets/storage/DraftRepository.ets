import { EmotionRecord } from '../models/Record';
import { RecordStore } from './RecordRepository';
import { parseDocument, SCHEMA_VERSION } from './RecordCodec';

export const DRAFT_KEY: string = 'editor_draft_v1';

// Uses a separate Preferences file so draft flushes cannot commit half-finished record writes.
export class DraftRepository {
  private store: RecordStore;
  private queue: Promise<void> = Promise.resolve();

  constructor(store: RecordStore) { this.store = store; }

  load(): EmotionRecord | undefined {
    const raw: string | undefined = this.store.get(DRAFT_KEY);
    if (raw === undefined) return undefined;
    const document = parseDocument(raw);
    if (document.records.length !== 1) throw new Error('Invalid draft');
    return document.records[0];
  }

  save(record: EmotionRecord): Promise<void> {
    // Snapshot before queueing: later input must not change an earlier write.
    const raw: string = JSON.stringify({ schemaVersion: SCHEMA_VERSION, records: [record] });
    parseDocument(raw);
    const task: Promise<void> = this.queue.then(async () => {
      await this.store.put(DRAFT_KEY, raw);
      await this.store.flush();
    });
    this.queue = task.catch(() => {});
    return task;
  }

  clear(): Promise<void> {
    const task: Promise<void> = this.queue.then(async () => {
      await this.store.remove(DRAFT_KEY);
      await this.store.flush();
    });
    this.queue = task.catch(() => {});
    return task;
  }
}
