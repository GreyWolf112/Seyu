export class BreathingClock {
  private duration: number = 60000;
  private remaining: number = 60000;
  private startedAt: number = -1;

  select(seconds: number): void {
    if (seconds !== 60 && seconds !== 180) throw new Error('Unsupported duration');
    this.duration = seconds * 1000; this.remaining = this.duration; this.startedAt = -1;
  }
  start(now: number): void {
    if (this.startedAt >= 0) return;
    if (this.remaining <= 0) this.remaining = this.duration;
    this.startedAt = now;
  }
  left(now: number): number {
    return Math.max(0, this.remaining - (this.startedAt < 0 ? 0 : Math.max(0, now - this.startedAt)));
  }
  pause(now: number): void { this.remaining = this.left(now); this.startedAt = -1; }
  seconds(now: number): number { return Math.ceil(this.left(now) / 1000); }
}

export const SLEEP_TITLES: string[] = ['找个舒服的位置', '把今天暂时放下', '给明天留一个小位置', '今晚，到这里就好'];
export const SLEEP_TEXTS: string[] = [
  '把屏幕调到舒服的亮度，放松肩膀。保持自然呼吸，不需要跟随固定节奏。',
  '注意到一件还挂在心里的事。可以只在心里说：我已经看见它了，今晚先不解决。',
  '如果有需要处理的事，只选明天的一小步。想不出来也没关系，现在可以休息。',
  '放下手机，选择一个舒服的姿势。睡意暂时没来，也不需要责备自己。'
];

export function volumeLevel(percent: number, muted: boolean): number {
  return muted ? 0 : Math.min(1, Math.max(0, percent / 100));
}
