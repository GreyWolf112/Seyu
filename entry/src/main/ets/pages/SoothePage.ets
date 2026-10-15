import { Joy } from '../models/LegacyModels';
import { INK, MUTED, ROSE } from '../theme/Theme';
import { icon, titleBlock, section } from '../components/Common';

@Component
export struct SoothePage {
  startSleep: () => void = () => {};
  openJoy: () => void = () => {};
  @Link sanctuary: boolean;
  @Link scene: number;
  @Link joys: Joy[];
  @Link filter: number;
  openEditor: (text?: string) => void = (text: string = '') => {};
  startExercise: (kind: number) => void = (kind: number) => {};
  recordJoy: (title: string) => void = (title: string) => {};

  private dateKey(date: Date): string {
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  @Builder
  scenePanel(title: string, subtitle: string, art: Resource, index: number) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(art).width('100%').height(230).objectFit(ImageFit.Cover)
      Column({ space: 6 }) {
        Text(title).fontSize(22).fontColor(INK)
        Text(subtitle + '  ↗').fontSize(12).fontColor(MUTED)
      }.padding(16).backgroundColor('#EDFFF9EF').borderRadius(18).margin({ left: 16, bottom: 28 })
    }.width('100%').borderRadius(26).clip(true).onClick(() => { this.scene = index; this.sanctuary = true; })
  }

  @Builder
  exerciseCard(title: string, subtitle: string, tag: string, color: string, artwork: Resource, action: () => void) {
    Row({ space: 15 }) {
      Stack() { Circle().width(49).height(49).fill(color); icon(artwork, 24) }
      Column({ space: 7 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK)
        Text(subtitle).fontSize(11).fontColor(MUTED)
        Text(tag).fontSize(10).fontColor(ROSE)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      icon($r('app.media.ic_arrow'), 18)
    }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(20).margin({ bottom: 12 }).onClick(action)
  }

  @Builder
  joyCard(title: string, art: Resource) {
    Column({ space: 9 }) {
      Image(art).width('100%').height(105).objectFit(ImageFit.Contain)
      Text(title).fontSize(11).fontColor(INK)
      Text(this.joys.some((item: Joy) => item.date === this.dateKey(new Date()) && item.title === title) ? '已留下 ✓' : '留下微光 +').fontSize(10).fontColor(ROSE)
    }.layoutWeight(1).padding(9).backgroundColor('#FFFFFF').borderRadius(20).onClick(() => { this.recordJoy(title); })
  }

  build() {
    Scroll() {
      Column() {
        titleBlock('A MOMENT FOR YOURSELF', '在片刻花园，歇一会儿。', '不用努力变好，先让此刻舒服一点。')
        Stack({ alignContent: Alignment.End }) {
          Image($r('app.media.botanical')).width(150).height(205).opacity(0.8)
          Column({ space: 13 }) {
            Text('今日留白  /  01').fontSize(10).fontColor('#61775F').letterSpacing(2)
            Text('跟着呼吸，\n慢慢回到此刻。').fontSize(25).fontColor(INK).lineHeight(37)
            Text('1 / 3 分钟 · 温和呼吸引导').fontSize(11).fontColor('#62715E')
            Button('开始放松   →').fontSize(12).height(38).backgroundColor('#71856A').fontColor(Color.White)
              .padding({ left: 18, right: 18 }).onClick(() => { this.startExercise(0); })
          }.alignItems(HorizontalAlign.Start).width('100%').padding(25)
        }.width('100%').backgroundColor('#E7ECDD').borderRadius(25).clip(true)
        this.exerciseCard('睡前，把今天轻轻放下', '放松身体，暂放心事，给自己一句晚安', '4 个小步骤 · 随时退出', '#EDE4D8', $r('app.media.ic_leaf'), () => { this.startSleep(); })
        section('什么都不做，也可以', '你的安静角落')
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.window_woman')).width('100%').height(210).objectFit(ImageFit.Cover)
          Column({ space: 8 }) {
            Text('窗边，给自己留个位置').fontSize(19).fontColor(INK)
            Text('雨声 · 海浪 · 林间风  →').fontSize(12).fontColor(ROSE)
          }.padding(16).backgroundColor('#EFFFFFF4').borderRadius(16).margin(16)
        }.borderRadius(25).clip(true).onClick(() => { this.sanctuary = true; })
        Swiper() {
          this.scenePanel('暮色花园', '今晚，允许自己慢下来', $r('app.media.moon_garden'), 1)
          this.scenePanel('晨光里的空白', '暂时不安排任何事', $r('app.media.morning_garden'), 2)
        }.height(230).autoPlay(false).margin({ top: 16 })
        section('今天的一点微光', '做过就留下，不必打卡')
        Button('记录自己的微光 · 文字 / 照片').width('100%').fontColor(ROSE).backgroundColor('#F0E4E2')
          .margin({ bottom: 14 }).onClick(() => { this.openJoy(); })
        Row({ space: 10 }) {
          this.joyCard('喝杯热饮', $r('app.media.life_tea'))
          this.joyCard('看看花草', $r('app.media.life_flower'))
          this.joyCard('写句话给自己', $r('app.media.life_letter'))
        }.width('100%')
        Row({ space: 10 }) {
          this.joyCard('听喜欢的歌', $r('app.media.woman_music'))
          this.joyCard('出去走走', $r('app.media.woman_walk'))
          this.joyCard('读几页书', $r('app.media.woman_read'))
        }.width('100%').margin({ top: 12 })
        Row({ space: 10 }) {
          this.joyCard('允许自己休息', $r('app.media.woman_rest'))
          this.joyCard('照顾一盆花', $r('app.media.woman_flowers'))
          this.joyCard('写一点心事', $r('app.media.woman_write'))
        }.width('100%').margin({ top: 12 })
        Text('点一下记下，再点一次取消。没有完成也没关系。').fontSize(11).fontColor(MUTED).margin({ top: 12 })
        section('找到适合此刻的方式', '由你选择')
        Row({ space: 9 }) {
          ForEach(['全部', '身体放松', '静心书写'], (label: string, index: number) => {
            Button(label).fontSize(12).fontWeight(FontWeight.Normal)
              .fontColor(this.filter === index ? '#FFFFFF' : MUTED)
              .backgroundColor(this.filter === index ? ROSE : '#F1EAE4')
              .height(36).padding({ left: 15, right: 15 }).borderRadius(18)
              .accessibilityText(label + (this.filter === index ? '，已选择' : ''))
              .onClick(() => { this.filter = index; })
          })
        }.width('100%').margin({ bottom: 20 })
        if (this.filter !== 2) {
          this.exerciseCard('给紧绷的自己松松绑', '把注意力，轻轻放回身体', '约 1 分钟 · 感官练习', '#E6EBDF', $r('app.media.ic_leaf'), () => { this.startExercise(1); })
          this.exerciseCard('跟随呼吸，歇一会儿', '用舒服的节奏，留一小段空白', '1 / 3 分钟 · 呼吸引导', '#EDE4D8', $r('app.media.ic_spark'), () => { this.startExercise(0); })
        }
        if (this.filter !== 1) {
          this.exerciseCard('写下暂时放不下的事', '把脑海中的声音，安放在纸上', '不限时 · 自由书写', '#F1DFDD', $r('app.media.ic_book'), () => { this.openEditor('此刻让我放不下的是：\n\n我希望自己得到的支持是：\n'); })
          this.exerciseCard('给自己的一封短信', '试着对自己，说一句温柔的话', '不限时 · 自我关怀', '#EDE5D6', $r('app.media.ic_chat'), () => { this.openEditor('亲爱的自己：\n\n'); })
        }
        Text('随时可以暂停。照顾自己，没有标准答案。').fontSize(11).fontColor(MUTED).textAlign(TextAlign.Center).margin({ top: 15, bottom: 25 })
      }.padding({ left: 24, right: 24 }).width('100%')
    }.scrollBar(BarState.Off).layoutWeight(1)
  }

}
