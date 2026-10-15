import { SLEEP_TITLES, SLEEP_TEXTS } from '../models/Relaxation';
import { INK, MUTED, ROSE, PAPER } from '../theme/Theme';

@Component
export struct SleepFlow {
  @State step: number = 0;
  onClose: () => void = () => {};
  onAmbient: () => void = () => {};
  build() {
    Column({ space: 20 }) {
      Row() {
        Text('睡前，把自己轻轻放下').fontSize(15).fontColor(MUTED)
        Blank()
        Button('退出').fontColor(ROSE).backgroundColor(Color.Transparent).onClick(this.onClose)
      }.width('100%')
      Scroll() {
        Column({ space: 24 }) {
          Text(`${this.step + 1} / 4`).fontSize(14).fontColor(ROSE)
          Image($r('app.media.moon_garden')).width('100%').height(190).objectFit(ImageFit.Cover).borderRadius(26)
          Text(SLEEP_TITLES[this.step]).fontSize(26).fontColor(INK)
          Text(SLEEP_TEXTS[this.step]).fontSize(17).fontColor(INK).lineHeight(30)
          Text('按自己的节奏停留，不必完成所有步骤。').fontSize(12).fontColor(MUTED)
        }.width('100%').padding({ top: 20, bottom: 20 })
      }.layoutWeight(1).width('100%')
      if (this.step > 0) {
        Button('回到上一步').fontColor(ROSE).backgroundColor(Color.Transparent).onClick(() => { this.step--; })
      }
      Button(this.step < 3 ? '准备好了，下一步' : '结束引导，晚安').width('100%').fontColor(Color.White).backgroundColor(ROSE)
        .onClick(() => { if (this.step < 3) this.step++; else this.onClose(); })
      Button(this.step < 3 ? '跳过，直接休息' : '再听一会儿环境音').fontColor(ROSE).backgroundColor(Color.Transparent)
        .onClick(() => { if (this.step < 3) this.step = 3; else this.onAmbient(); })
    }.padding(24).width('100%').height('100%').backgroundColor(PAPER)
  }
}
