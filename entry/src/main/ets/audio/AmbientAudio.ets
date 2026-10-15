import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { resourceManager } from '@kit.LocalizationKit';

export class AmbientAudio {
  private manager: resourceManager.ResourceManager;
  private player: media.AVPlayer | undefined = undefined;
  private path: string = '';
  private generation: number = 0;
  private queue: Promise<void> = Promise.resolve();
  private volume: number = 0.35;
  private report: (message: string, playing: boolean) => void;

  constructor(manager: resourceManager.ResourceManager, report: (message: string, playing: boolean) => void) {
    this.manager = manager; this.report = report;
  }

  play(name: string): Promise<void> {
    if (!['rain', 'ocean', 'forest'].includes(name)) return Promise.reject(new Error('Unknown sound'));
    const generation = ++this.generation;
    const task = this.queue.then(async () => {
      await this.release();
      if (generation !== this.generation) return;
      try {
        const player = await media.createAVPlayer();
        this.player = player;
        const path = `ambient/${name}.wav`;
        const descriptor = await this.manager.getRawFd(path);
        this.path = path;
        if (generation !== this.generation) { await this.release(); return; }
        await new Promise<void>((resolve, reject) => {
          const timer = setTimeout(() => { reject(new Error('Audio prepare timeout')); }, 8000);
          player.on('stateChange', (state: string) => {
            try {
            if (state === 'initialized') {
              player.audioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_MUSIC, rendererFlags: 0 };
              player.prepare().catch(() => { clearTimeout(timer); reject(new Error('Audio prepare failed')); });
            } else if (state === 'prepared') { clearTimeout(timer); resolve(); }
            } catch (_) { clearTimeout(timer); reject(new Error('Audio prepare failed')); }
          });
          player.on('error', () => {
            clearTimeout(timer); reject(new Error('Audio playback failed'));
            if (generation === this.generation) this.stop('声音暂不可用，请重试');
          });
          try { player.fdSrc = { fd: descriptor.fd, offset: descriptor.offset, length: descriptor.length }; }
          catch (_) { clearTimeout(timer); reject(new Error('Audio source failed')); }
        });
        if (generation !== this.generation) { await this.release(); return; }
        player.on('audioInterrupt', (event: audio.InterruptEvent) => {
          if (event.eventType === audio.InterruptType.INTERRUPT_TYPE_BEGIN && generation === this.generation) {
            this.stop('声音已因系统中断停止，点播放可重新开始');
          }
        });
        player.loop = true;
        player.setVolume(this.volume);
        await player.play();
        if (generation !== this.generation) { await this.release(); return; }
        this.report('正在播放', true);
      } catch (_) {
        await this.release();
        if (generation === this.generation) this.report('声音暂不可用，请重试', false);
      }
    });
    this.queue = task.catch(() => {});
    return task;
  }

  setVolume(value: number): void {
    this.volume = Math.max(0, Math.min(1, value));
    try { if (this.player?.state === 'playing') this.player.setVolume(this.volume); }
    catch (_) { this.stop('音量调整失败，请重新播放'); }
  }

  stop(message: string = '声音已停止'): Promise<void> {
    ++this.generation;
    this.report(message, false);
    const task = this.queue.then(async () => { await this.release(); });
    this.queue = task.catch(() => {});
    return task;
  }

  private async release(): Promise<void> {
    const player = this.player; this.player = undefined;
    const path = this.path; this.path = '';
    try { if (player) await player.release(); }
    catch (_) {}
    finally {
      if (path) { try { await this.manager.closeRawFd(path); } catch (_) {} }
    }
  }
}
