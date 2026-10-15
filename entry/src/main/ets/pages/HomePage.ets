import { INK, MUTED, ROSE, MOODS, FACES } from '../theme/Theme';
import { EmotionRecord } from '../models/Record';
import { icon } from '../components/Common';

@Component
export struct HomePage {
  @Link quickSaving: boolean;
  @Link tab: number;
  @Link mood: string;
  @Link entries: EmotionRecord[];
  @Link reflectionPending: boolean;
  saveQuickMood: () => void = () => {};
  openEditor: (text?: string) => void = () => {};
  resumeReflection: () => void = () => {};
  editRecord: (id: string) => void = () => {};

  @Builder
  entrance(title: string, detail: string, art: Resource, action: () => void) {
    Column({ space: 8 }) {
      Image(art).height(58).width(58).objectFit(ImageFit.Contain)
      Text(title).fontSize(16).fontColor(INK)
      Text(detail).fontSize(11).fontColor(MUTED)
    }.layoutWeight(1).padding({ top: 14, bottom: 14 }).backgroundColor('#FFFFFF').borderRadius(20)
      .accessibilityText(title + '，' + detail).onClick(action)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          icon($r('app.media.ic_spark'), 22)
          Text('知屿').fontSize(21).fontColor(INK).letterSpacing(3).margin({ left: 8 })
          Blank()
          Text(`${new Date().getMonth() + 1}月${new Date().getDate()}日`).fontSize(12).fontColor(MUTED)
        }.width('100%')
        Column({ space: 8 }) {
          Text('先照顾，此刻的自己。').fontSize(25).fontColor(INK)
          Text('写一点、理一理，或只是歇一会儿。').fontSize(13).fontColor(MUTED)
        }.alignItems(HorizontalAlign.Start).width('100%')
        Row() {
          ForEach(MOODS, (item: string, index: number) => {
            Column({ space: 7 }) {
              Text(FACES[index]).fontSize(25).fontColor(ROSE).width(42).height(42).textAlign(TextAlign.Center)
                .backgroundColor(this.mood === item ? '#EBCED0' : '#F6EBE5').borderRadius(22)
              Text(item).fontSize(12).fontColor(this.mood === item ? ROSE : MUTED)
            }.layoutWeight(1).accessibilityText(item + (this.mood === item ? '，已选择' : ''))
              .onClick(() => { this.mood = this.mood === item ? '' : item; })
          })
        }.width('100%')
        Button(this.quickSaving ? '正在保存…' : '只记下此刻心情').width('100%').height(42)
          .fontColor(Color.White).backgroundColor(ROSE).enabled(this.mood !== '' && !this.quickSaving)
          .onClick(() => { this.saveQuickMood(); })
        Row({ space: 10 }) {
          this.entrance('写下来', '心情与生活', $r('app.media.woman_write'), () => { this.openEditor(); })
          this.entrance('理一理', '安放心事', $r('app.media.woman_read'), () => { this.tab = 1; })
          this.entrance('歇一会儿', '让自己放松', $r('app.media.woman_rest'), () => { this.tab = 2; })
        }.width('100%')
        if (this.reflectionPending) {
          Button('继续上次的心事整理 →').width('100%').height(46).fontColor(ROSE).backgroundColor('#F0E4E2')
            .onClick(() => { this.resumeReflection(); })
        }
        if (this.entries.some((item: EmotionRecord) => item.kind === 'reflection')) {
          Column({ space: 10 }) {
            Text('最近留给自己的提醒').fontSize(17).fontColor(INK)
            ForEach(this.entries.filter((item: EmotionRecord) => item.kind === 'reflection').slice(0, 1), (item: EmotionRecord) => {
              Text(item.reflection?.nextStep || item.reflection?.needs || item.title).fontSize(14).fontColor(MUTED).lineHeight(24)
              Button('回看这次整理').fontSize(12).fontColor(ROSE).backgroundColor(Color.Transparent)
                .onClick(() => { this.editRecord(item.id); })
            }, (item: EmotionRecord) => item.id)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor('#F3EDE3').borderRadius(20)
        }
        Image($r('app.media.window_woman')).width('100%').height(150).objectFit(ImageFit.Cover).borderRadius(22)
        Text('不用完成所有事情，也可以好好休息。').fontSize(12).fontColor(MUTED)
      }.padding(22).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
  }
}
