import { preferences } from '@kit.ArkData';
import { RecordStore } from './RecordRepository';

export class PreferencesRecordStore implements RecordStore {
  private storage: preferences.Preferences;

  constructor(storage: preferences.Preferences) { this.storage = storage; }

  get(key: string): string | undefined {
    try {
      if (!this.storage.hasSync(key)) return undefined;
      const value = this.storage.getSync(key, '');
      if (typeof value !== 'string') throw new Error('Invalid stored value');
      return value;
    } catch (_) { throw new Error('Cannot read local records'); }
  }

  async put(key: string, value: string): Promise<void> {
    try { await this.storage.put(key, value); }
    catch (_) { throw new Error('Cannot write local records'); }
  }

  async remove(key: string): Promise<void> {
    try { await this.storage.delete(key); }
    catch (_) { throw new Error('Cannot remove local record key'); }
  }

  async flush(): Promise<void> {
    try { await this.storage.flush(); }
    catch (_) { throw new Error('Cannot persist local records'); }
  }
}
