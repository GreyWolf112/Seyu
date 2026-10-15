import { fileUri } from '@kit.CoreFileKit';
import { MUTED } from '../theme/Theme';

// Image expects a file URI for sandbox files; persistence keeps relative paths.
@Component
export struct LocalPhoto {
  @Prop @Watch('refreshSource') filesDir: string = '';
  @Prop @Watch('refreshSource') relativePath: string = '';
  @Prop photoSize: number = 86;
  @State source: string = '';
  @State failed: boolean = false;
  @State loaded: boolean = false;
  @State revision: number = 0;

  aboutToAppear(): void { this.refreshSource(); }

  private refreshSource(): void {
    this.revision++;
    this.loaded = false;
    this.failed = false;
    try {
      if (!this.filesDir.startsWith('/') || !/^photos\/[a-zA-Z0-9-]+\.image$/.test(this.relativePath)) {
        throw new Error('Invalid photo location');
      }
      this.source = fileUri.getUriFromPath(`${this.filesDir}/${this.relativePath}`);
    } catch (_) { this.source = ''; this.failed = true; }
  }

  build() {
    Stack() {
      if (this.source) {
        ForEach([this.revision], (version: number) => {
          Image(this.source).width(this.photoSize).height(this.photoSize).objectFit(ImageFit.Cover)
            .accessibilityText('记录中的照片')
            .onComplete(() => { if (version === this.revision) { this.loaded = true; this.failed = false; } })
            .onError(() => { if (version === this.revision) { this.failed = true; this.loaded = false; } })
        }, (version: number) => version.toString())
      }
      if (this.failed) {
        Button() {
          Text('照片暂不可用\n点此重试').fontSize(11).fontColor(MUTED).lineHeight(19).textAlign(TextAlign.Center)
        }.width(this.photoSize).height(this.photoSize).padding(4).borderRadius(12).backgroundColor('#F1EAE4')
          .accessibilityText('照片加载失败，点击重试').onClick(() => { this.refreshSource(); })
      } else if (!this.loaded) {
        Text('正在加载…').fontSize(11).fontColor(MUTED)
      }
    }.width(this.photoSize).height(this.photoSize).backgroundColor('#F1EAE4').borderRadius(12).clip(true)
  }
}
