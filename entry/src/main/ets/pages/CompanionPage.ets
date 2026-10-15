import { REFLECTION_SCENES, ReflectionScene } from '../models/ReflectionModel';
import { WRITING_TEMPLATES, WritingTemplate } from '../models/WritingTemplates';
import { INK, MUTED, ROSE } from '../theme/Theme';
import { titleBlock } from '../components/Common';

@Component
export struct CompanionPage {
  @Link reflectionPending: boolean;
  startReflection: (id: string) => void = () => {};
  resumeReflection: () => void = () => {};
  openEditor: (text?: string) => void = () => {};
  openTemplate: (id: string) => void = () => {};

  build() {
    Scroll() {
      Column({ space: 16 }) {
        titleBlock('LET IT REST HERE', '把心事，慢慢理清。', '从一件具体的事开始，每一步都可以跳过。')
        if (this.reflectionPending) {
          Button('继续上次的整理 →').width('100%').fontColor(ROSE).backgroundColor('#F0E4E2')
            .onClick(() => { this.resumeReflection(); })
        }
        ForEach(REFLECTION_SCENES, (scene: ReflectionScene) => {
          Column({ space: 8 }) {
            Text(scene.title + '  →').fontSize(17).fontColor(INK)
            Text(scene.description).fontSize(12).fontColor(MUTED).lineHeight(22)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor('#FFFFFF').borderRadius(20)
            .onClick(() => { this.startReflection(scene.id); })
        }, (scene: ReflectionScene) => scene.id)
        Text('给自己的书写仪式').fontSize(18).fontColor(INK).width('100%')
        Text('每份只有两个问题，不需要全部回答。').fontSize(12).fontColor(MUTED).width('100%')
        ForEach(WRITING_TEMPLATES, (template: WritingTemplate) => {
          Column({ space: 7 }) {
            Text(template.title + '  →').fontSize(16).fontColor(ROSE)
            Text(template.questions[0]).fontSize(12).fontColor(MUTED)
          }.width('100%').padding(16).alignItems(HorizontalAlign.Start).backgroundColor('#F1EAE4').borderRadius(18)
            .onClick(() => { this.openTemplate(template.id); })
        }, (template: WritingTemplate) => template.id)
        Image($r('app.media.bottle_sea')).width('100%').height(140).objectFit(ImageFit.Cover).borderRadius(22)
        Text('只想说出来，也可以').fontSize(18).fontColor(INK)
        Text('写下后，可以把这次记录装进私人瓶子。仍是同一份内容，仅自己可见。').fontSize(12).fontColor(MUTED).lineHeight(23)
        Button('自由写一点').width('100%').backgroundColor(ROSE).fontColor(Color.White).onClick(() => { this.openEditor(); })
      }.padding(24).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
