import { EmotionRecord } from '../models/Record';
import { ReflectionScene, reflectionScene, newReflection, updateReflection, reflectionHasContent } from '../models/ReflectionModel';
import { EDITOR_MOODS } from '../models/EditorModel';
import { DraftRepository } from '../storage/DraftRepository';
import { INK, MUTED, ROSE, PAPER } from '../theme/Theme';

@Component
export struct ReflectionFlow {
  seed: EmotionRecord = newReflection('words');
  drafts: DraftRepository | undefined = undefined;
  onSave: (record: EmotionRecord) => Promise<void> = async () => {};
  onClose: () => void = () => {};
  onRelax: () => void = () => {};
  @State step: number = 0;
  @State facts: string = '';
  @State moods: string[] = [];
  @State needs: string = '';
  @State nextStep: string = '';
  @State status: string = '';
  @State busy: boolean = false;
  private scene: ReflectionScene = reflectionScene('words');
  private revision: number = 0;

  aboutToAppear(): void {
    this.scene = reflectionScene(this.seed.reflection?.sceneId || 'words');
    this.step = this.seed.reflection?.step ?? 0;
    this.facts = this.seed.reflection?.facts || '';
    this.needs = this.seed.reflection?.needs || '';
    this.nextStep = this.seed.reflection?.nextStep || '';
    this.moods = this.seed.moods.slice();
    this.persist();
  }

  private record(): EmotionRecord {
    return updateReflection(this.seed, this.facts, this.moods, this.needs, this.nextStep, this.step);
  }

  private async persist(): Promise<void> {
    const revision = ++this.revision;
    this.status = '正在暂存…';
    try {
      if (!this.drafts) throw new Error('Missing draft store');
      await this.drafts.save(this.record());
      if (revision === this.revision) this.status = '进度已暂存到本机';
    } catch (_) { if (revision === this.revision) this.status = '暂存失败，请点此重试或保留页面'; }
  }

  private async leave(relax: boolean): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      if (!this.drafts) throw new Error('Missing draft store');
      await this.drafts.save(this.record());
      if (relax) this.onRelax(); else this.onClose();
    } catch (_) { this.status = '暂存失败，请重试后再离开'; }
    finally { this.busy = false; }
  }

  private async save(): Promise<void> {
    if (this.busy) return;
    const record = this.record();
    if (!reflectionHasContent(record)) { this.status = '可以不填写所有问题；留下一种感受或一句话再保存'; return; }
    this.busy = true;
    try { await this.onSave(record); }
    catch (_) { this.status = '保存未完成，内容仍在这里，请重试'; }
    finally { this.busy = false; }
  }

  private move(step: number): void {
    if (this.busy || step < 0 || step > 4) return;
    this.step = step;
    this.persist();
  }

  @Builder
  choices(values: string[], target: number) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(values, (value: string) => {
        Button(value).fontSize(13).fontColor(ROSE).backgroundColor('#F1EAE4').margin({ right: 6, bottom: 8 })
          .onClick(() => {
            if (target === 0) {
              if (this.moods.includes(value)) this.moods = this.moods.filter((mood: string) => mood !== value);
              else if (this.moods.length < 3) this.moods = [...this.moods, value];
              else { this.status = '最多选择3种感受'; return; }
            } else if (target === 1) this.needs = value;
            else this.nextStep = value;
            this.persist();
          })
          .backgroundColor(target === 0 && this.moods.includes(value) ? '#EBCED0' : '#F1EAE4')
          .accessibilityText(value + (target === 0 && this.moods.includes(value) ? '，已选择' : ''))
      })
    }.width('100%')
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.scene.title).fontSize(19).fontColor(INK).layoutWeight(1)
        Button('暂存离开').fontSize(12).fontColor(ROSE).backgroundColor(Color.Transparent)
          .enabled(!this.busy).onClick(() => { this.leave(false); })
      }.width('100%')
      Text(this.step < 4 ? `第 ${this.step + 1} / 4 步 · 可留空，直接点下一步` : '我的整理卡 · 内容都可以修改')
        .fontSize(12).fontColor(MUTED).width('100%')
      Scroll() {
        Column({ space: 16 }) {
          if (this.step === 0 || this.step === 4) {
            Text(this.step === 4 ? '发生的事' : this.scene.factQuestion).fontSize(18).fontColor(INK).width('100%')
            TextArea({ text: this.facts, placeholder: '只写你愿意留下的部分…' }).height(140).maxLength(1500)
              .onChange((value: string) => { this.facts = value; this.persist(); })
          }
          if (this.step === 1 || this.step === 4) {
            Text('这件事带来了哪些感受？').fontSize(18).fontColor(INK).width('100%')
            Text('最多选3种，也可以先留空。').fontSize(12).fontColor(MUTED).width('100%')
            this.choices(EDITOR_MOODS, 0)
          }
          if (this.step === 2 || this.step === 4) {
            Text(this.step === 4 ? '我的需要' : this.scene.needQuestion).fontSize(18).fontColor(INK).width('100%')
            if (this.step !== 4) this.choices(this.scene.needs, 1)
            TextArea({ text: this.needs, placeholder: '选择提示后也可以改成自己的话…' }).height(130).maxLength(1500)
              .onChange((value: string) => { this.needs = value; this.persist(); })
          }
          if (this.step === 3 || this.step === 4) {
            Text(this.step === 4 ? '我愿意尝试的下一步' : this.scene.actionQuestion).fontSize(18).fontColor(INK).width('100%')
            if (this.step !== 4) this.choices(this.scene.actions, 2)
            TextArea({ text: this.nextStep, placeholder: '也可以暂时不行动，先给自己一点时间。' }).height(130).maxLength(1500)
              .onChange((value: string) => { this.nextStep = value; this.persist(); })
          }
          Text('无需原谅、解释或马上做决定。选择由你来定。').fontSize(12).fontColor(MUTED).lineHeight(22)
          Button('先歇一会儿，保留进度').fontSize(13).fontColor(ROSE).backgroundColor(Color.Transparent)
            .onClick(() => { this.leave(true); })
        }.width('100%').enabled(!this.busy)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      Text(this.status).fontSize(11).fontColor(MUTED).onClick(() => { if (!this.busy) this.persist(); })
      Row({ space: 8 }) {
        if (this.step === 0) {
          Button() {
            Image($r('app.media.ic_back')).width(22).height(22).objectFit(ImageFit.Contain)
          }.width(44).height(44).backgroundColor('#F1EAE4')
            .accessibilityText('暂存并返回上一级').onClick(() => { this.leave(false); })
        } else {
          Button('上一步').fontColor(ROSE).backgroundColor('#F1EAE4').onClick(() => { this.move(this.step - 1); })
        }
        if (this.step < 4) {
          Button(this.step === 3 ? '看看整理卡' : '下一步').layoutWeight(1).backgroundColor(ROSE).fontColor(Color.White)
            .onClick(() => { this.move(this.step + 1); })
        } else {
          Button(this.busy ? '正在保存…' : '保存整理卡').layoutWeight(1).backgroundColor(ROSE).fontColor(Color.White)
            .onClick(() => { this.save(); })
        }
      }.width('100%').enabled(!this.busy)
    }.padding(22).width('100%').height('100%').backgroundColor(PAPER)
  }
}
