import { fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { PhotoReference } from '../models/Record';

export class PhotoStore {
  private root: string;
  constructor(filesDir: string) { this.root = filesDir; }

  async select(remaining: number): Promise<PhotoReference[]> {
    if (remaining < 1) return [];
    const copied: PhotoReference[] = [];
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const selected = await picker.select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: remaining });
      if (selected.photoUris.length === 0) return [];
      const directory: string = `${this.root}/photos`;
      if (!await fs.access(directory)) await fs.mkdir(directory);
      for (const uri of selected.photoUris.slice(0, remaining)) {
        const id: string = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
        const relativePath: string = `photos/${id}.image`;
        const source = await fs.open(uri, fs.OpenMode.READ_ONLY);
        try {
          const info = await fs.stat(source.fd);
          if (info.size > 30 * 1024 * 1024) throw new Error('Photo exceeds 30 MB');
          // Track destination before copying so partially copied files are removed on failure.
          copied.push({ id, relativePath });
          await fs.copyFile(source.fd, `${this.root}/${relativePath}`);
        } finally { await fs.close(source); }
      }
      return copied;
    } catch (_) {
      for (const photo of copied) {
        try { await fs.unlink(`${this.root}/${photo.relativePath}`); } catch (_) {}
      }
      throw new Error('Photo import failed');
    }
  }

  // Run before enabling the editor on launch. Keep current, recovery and draft references.
  async collectUnused(references: string[]): Promise<void> {
    try {
      const directory: string = `${this.root}/photos`;
      if (!await fs.access(directory)) return;
      const files: string[] = await fs.listFile(directory);
      for (const name of files) {
        if (!/^[a-zA-Z0-9-]+\.image$/.test(name)) continue;
        if (!references.includes(`photos/${name}`)) await fs.unlink(`${directory}/${name}`);
      }
    } catch (_) { /* Cleanup must never block access to saved records. Retry on next launch. */ }
  }
}
