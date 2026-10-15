import { AmbientAudio } from '../audio/AmbientAudio';
import { volumeLevel } from '../models/Relaxation';
import { INK, MUTED, ROSE } from '../theme/Theme';

@Component
export struct AmbientPanel {
  @StorageLink('zhiyuForeground') @Watch('foregroundChanged') foreground: boolean = true;
  @State sound: number = 0;
  @State volume: number = 35;
  @State muted: boolean = false;
  @State playing: boolean = false;
  @State busy: boolean = false;
  @State minutes: number = 15;
  @State remaining: number = 0;
  @State status: string = '声音默认关闭，由你选择播放';
  private engine: AmbientAudio | undefined = undefined;
  private timer: number = -1;
  private deadline: number = 0;
  private alive: boolean = false;
  private names: string[] = ['雨声', '海浪', '林间风'];
  private descriptions: string[] = ['雨滴与雨幕 · 自然降雨录音', '海浪拍岸 · 岩石海岸实录', '林间鸟鸣 · 风吹树叶'];
  private files: string[] = ['rain', 'ocean', 'forest'];

  aboutToAppear(): void {
    this.alive = true;
    const context = this.getUIContext().getHostContext();
    if (context) this.engine = new AmbientAudio(context.resourceManager, (message: string, playing: boolean) => {
      if (!this.alive) return;
      this.status = message; this.playing = playing;
      if (!playing) this.clearTimer();
    });
  }

  aboutToDisappear(): void { this.alive = false; this.clearTimer(); this.engine?.stop(); }
  private foregroundChanged(): void { if (!this.foreground) { this.clearTimer(); this.engine?.stop('切到后台，声音已停止'); } }
  private clearTimer(): void {
    if (this.timer !== -1) clearInterval(this.timer);
    this.timer = -1; this.remaining = 0;
  }
  private resetTimer(): void {
    this.clearTimer();
    if (!this.playing) return;
    this.deadline = Date.now() + this.minutes * 60000;
    this.remaining = this.minutes * 60;
    this.timer = setInterval(() => {
      this.remaining = Math.max(0, Math.ceil((this.deadline - Date.now()) / 1000));
      if (this.remaining === 0) { this.clearTimer(); this.engine?.stop('设定时间到了，声音已关闭'); }
    }, 500);
  }
  private async play(): Promise<void> {
    if (this.busy || !this.foreground) return;
    this.clearTimer(); this.playing = false;
    this.busy = true; this.status = '正在准备声音…';
    try {
      if (!this.engine) throw new Error('No audio engine');
      this.engine.setVolume(volumeLevel(this.volume, this.muted));
      await this.engine.play(this.files[this.sound]);
      if (this.alive && this.playing) this.resetTimer();
    } catch (_) { this.status = '声音暂不可用，请重试'; }
    finally { this.busy = false; }
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        ForEach(this.names, (name: string, index: number) => {
          Button(name).fontSize(12).layoutWeight(1).fontColor(this.sound === index ? Color.White : ROSE)
            .backgroundColor(this.sound === index ? ROSE : '#F1EAE4').enabled(!this.busy)
            .onClick(() => { if (this.sound !== index) { this.sound = index; if (this.playing) this.play(); } })
        })
      }.width('100%')
      Text(this.descriptions[this.sound]).fontSize(12).fontColor(MUTED)
      Row({ space: 8 }) {
        Button(this.muted ? '取消静音' : '静音').fontSize(12).fontColor(ROSE).backgroundColor(Color.Transparent)
          .onClick(() => { this.muted = !this.muted; this.engine?.setVolume(volumeLevel(this.volume, this.muted)); })
        Slider({ value: this.volume, min: 0, max: 100, step: 1 }).layoutWeight(1).selectedColor(ROSE)
          .onChange((value: number) => { this.volume = value; this.engine?.setVolume(volumeLevel(value, this.muted)); })
        Text(`${this.volume}%`).fontSize(11).fontColor(MUTED)
      }.width('100%')
      Row({ space: 6 }) {
        Text('定时关闭').fontSize(11).fontColor(MUTED)
        ForEach([5, 15, 30], (value: number) => {
          Button(`${value}分钟`).fontSize(11).fontColor(this.minutes === value ? Color.White : ROSE)
            .backgroundColor(this.minutes === value ? ROSE : '#F1EAE4')
            .onClick(() => { this.minutes = value; this.resetTimer(); })
        })
      }.width('100%')
      Button(this.busy ? '正在准备…' : this.playing ? '停止声音' : '播放声音').width('100%')
        .fontColor(Color.White).backgroundColor(ROSE).enabled(!this.busy)
        .onClick(() => { if (this.playing) this.engine?.stop(); else this.play(); })
      Text(this.status + (this.playing ? ` · 还剩${Math.ceil(this.remaining / 60)}分钟` : '')).fontSize(11).fontColor(INK)
      Text('自然录音 · 离开空间或切到后台会停止').fontSize(10).fontColor(MUTED)
    }.padding(14).width('100%').backgroundColor('#F7F2EB').borderRadius(20)
  }
}
