import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BackupPhoto, MAX_BACKUP_BYTES, MAX_PHOTO_BYTES, validPhotoPath } from './BackupCodec';
import { BackupMedia } from './DataMaintenance';

export class BackupFiles implements BackupMedia {
  private context: common.Context;
  private root: string;
  private base64: util.Base64Helper = new util.Base64Helper();
  constructor(context: common.Context) { this.context = context; this.root = context.filesDir; }

  private async digest(data: Uint8Array): Promise<string> {
    const hash = cryptoFramework.createMd('SHA256');
    await hash.update({ data });
    const result = await hash.digest();
    return Array.from(result.data).map((byte: number) => byte.toString(16).padStart(2, '0')).join('');
  }
  private async readFile(path: string, limit: number): Promise<Uint8Array> {
    const file = await fs.open(path, fs.OpenMode.READ_ONLY);
    try {
      const info = await fs.stat(file.fd);
      if (info.size <= 0 || info.size > limit) throw new Error('文件为空或超过大小限制');
      const result: Uint8Array = new Uint8Array(info.size);
      let position: number = 0;
      while (position < info.size) {
        const buffer: ArrayBuffer = new ArrayBuffer(Math.min(256 * 1024, info.size - position));
        const count: number = await fs.read(file.fd, buffer);
        if (count <= 0) throw new Error('文件读取不完整');
        result.set(new Uint8Array(buffer, 0, count), position); position += count;
      }
      return result;
    } finally { await fs.close(file); }
  }
  private async writeFile(path: string, bytes: Uint8Array): Promise<void> {
    const file = await fs.open(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      let position: number = 0;
      while (position < bytes.length) {
        const chunk = bytes.slice(position, Math.min(position + 256 * 1024, bytes.length));
        const count = await fs.write(file.fd, chunk.buffer);
        if (count <= 0) throw new Error('文件写入不完整');
        position += count;
      }
      await fs.fsync(file.fd);
    } finally { await fs.close(file); }
  }
  async save(raw: string): Promise<boolean> {
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(raw);
    if (bytes.length > MAX_BACKUP_BYTES) throw new Error('备份超过64MB，未导出');
    const selected: string[] = await new picker.DocumentViewPicker(this.context).save({
      newFileNames: [`绪屿备份-${new Date().toISOString().slice(0, 10)}-${Date.now()}.zhiyu.json`] });
    if (selected.length === 0) return false;
    await this.writeFile(selected[0], bytes);
    return true;
  }
  async select(): Promise<string | null> {
    const selected: string[] = await new picker.DocumentViewPicker(this.context).select({ maxSelectNumber: 1 });
    if (selected.length === 0) return null;
    const bytes = await this.readFile(selected[0], MAX_BACKUP_BYTES);
    return new util.TextDecoder('utf-8', { fatal: true }).decodeToString(bytes);
  }
  async readPhoto(path: string): Promise<BackupPhoto> {
    if (!validPhotoPath(path)) throw new Error('不支持的照片路径');
    const bytes = await this.readFile(`${this.root}/${path}`, MAX_PHOTO_BYTES);
    return { relativePath: path, data: this.base64.encodeToStringSync(bytes), sha256: await this.digest(bytes) };
  }
  private decode(photo: BackupPhoto): Uint8Array {
    const bytes = this.base64.decodeSync(photo.data);
    if (bytes.length === 0 || bytes.length > MAX_PHOTO_BYTES || this.base64.encodeToStringSync(bytes) !== photo.data) throw new Error('照片编码无效');
    return bytes;
  }
  async checkPhoto(photo: BackupPhoto): Promise<void> {
    if (await this.digest(this.decode(photo)) !== photo.sha256) throw new Error('照片校验失败');
  }
  async stagePhoto(photo: BackupPhoto): Promise<string> {
    const bytes = this.decode(photo);
    if (await this.digest(bytes) !== photo.sha256) throw new Error('照片校验失败');
    const directory = `${this.root}/photos`;
    if (!await fs.access(directory)) await fs.mkdir(directory);
    let path: string = '';
    do { path = `photos/restore-${Date.now()}-${Math.random().toString(36).slice(2, 12)}.image`; }
    while (await fs.access(`${this.root}/${path}`));
    try { await this.writeFile(`${this.root}/${path}`, bytes); }
    catch (error) { try { await fs.unlink(`${this.root}/${path}`); } catch (_) {} throw new Error('照片导入未完成'); }
    return path;
  }
  async erasePhotos(): Promise<void> {
    const directory = `${this.root}/photos`;
    if (!await fs.access(directory)) return;
    // Only application-owned photos; never touch original album or exported backups.
    for (const name of await fs.listFile(directory)) {
      if (name.includes('/') || name === '..' || name === '.') throw new Error('Unexpected photo entry');
      await fs.unlink(`${directory}/${name}`);
    }
    await fs.rmdir(directory);
  }
}
