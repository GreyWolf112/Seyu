import { LocalPhoto } from './LocalPhoto';
import { EmotionRecord, PhotoReference } from '../models/Record';
import { EDITOR_MOODS, LIFE_TAGS, newJournal, hasContent, validateEditorRecord } from '../models/EditorModel';
import { DraftRepository } from '../storage/DraftRepository';
import { PhotoStore } from '../storage/PhotoStore';
import { INK, MUTED, ROSE, PAPER } from '../theme/Theme';

@Component
export struct RecordEditor {
  seed: EmotionRecord = newJournal();
  drafts: DraftRepository | undefined = undefined;
  media: PhotoStore | undefined = undefined;
  @Prop filesDir: string = '';
  onSave: (record: EmotionRecord) => Promise<void> = async () => {};
  onClose: () => void = () => {};
  @State moods: string[] = [];
  @State tags: string[] = [];
  @State text: string = '';
  @State title: string = '';
  @State photos: PhotoReference[] = [];
  @State intensity: number = -1;
  @State customTag: string = '';
  @State status: string = '';
  @State busy: boolean = false;
  @State importing: boolean = false;
  private revision: number = 0;

  aboutToAppear(): void {
    this.moods = this.seed.moods.slice();
    this.tags = this.seed.tags.slice();
    this.text = this.seed.text;
    this.title = this.seed.title;
    this.photos = this.seed.photos.slice();
    this.intensity = this.seed.intensity ?? -1;
    this.changed();
  }

  private record(): EmotionRecord {
    return {
      id: this.seed.id, kind: this.seed.kind === 'joy' || this.seed.kind === 'bottle' ? this.seed.kind : 'journal', date: this.seed.date,
      createdAt: this.seed.createdAt, updatedAt: Date.now(), timePrecision: this.seed.timePrecision,
      moods: this.moods.slice(), intensity: this.intensity < 0 ? null : this.intensity,
      tags: this.tags.slice(), title: this.title.trim(), text: this.text, photos: this.photos.slice(),
      reflection: this.seed.reflection, favorite: this.seed.favorite, bottled: this.seed.bottled ?? false, legacyId: this.seed.legacyId
    };
  }

  private async changed(): Promise<void> {
    const revision: number = ++this.revision;
    this.status = '正在保存草稿…';
    try {
      if (!this.drafts) throw new Error('Draft storage unavailable');
      await this.drafts.save(this.record());
      if (revision === this.revision) this.status = '草稿已保存在本机';
    } catch (_) {
      if (revision === this.revision) this.status = '草稿未保存成功，请保留页面并重试';
    }
  }

  private toggleMood(mood: string): void {
    if (this.moods.includes(mood)) this.moods = this.moods.filter((value: string) => value !== mood);
    else if (this.moods.length < 3) this.moods = [...this.moods, mood];
    else { this.status = '最多选择3种感受，可以先取消一种'; return; }
    this.changed();
  }

  private toggleTag(tag: string): void {
    if (this.tags.includes(tag)) this.tags = this.tags.filter((value: string) => value !== tag);
    else if (this.tags.length < 12) this.tags = [...this.tags, tag];
    else { this.status = '最多选择12个标签'; return; }
    this.changed();
  }

  private addTag(): void {
    const tag: string = this.customTag.trim();
    if (!tag || this.tags.includes(tag)) return;
    if (this.tags.length >= 12) { this.status = '最多选择12个标签'; return; }
    this.tags = [...this.tags, tag];
    this.customTag = '';
    this.changed();
  }

  private async pickPhotos(): Promise<void> {
    if (this.importing || this.busy || this.photos.length >= 3) return;
    this.importing = true;
    try {
      if (!this.media) throw new Error('No media store');
      const selected: PhotoReference[] = await this.media.select(3 - this.photos.length);
      if (selected.length) {
        this.photos = [...this.photos, ...selected];
        await this.changed();
      }
    } catch (_) { this.status = '照片未添加成功，请重试（每张不超过30MB）'; }
    finally { this.importing = false; }
  }

  private async close(): Promise<void> {
    if (this.busy || this.importing) return;
    this.busy = true;
    try {
      if (!this.drafts) throw new Error('No draft store');
      await this.drafts.save(this.record());
      this.onClose();
    } catch (_) { this.status = '草稿未保存成功，请重试后再离开'; }
    finally { this.busy = false; }
  }

  private discard(): void {
    this.getUIContext().showAlertDialog({
      title: '舍弃这次草稿？', message: '已保存的正式记录不会改变。',
      primaryButton: { value: '继续写', action: () => {} },
      secondaryButton: { value: '舍弃草稿', action: () => { this.clearAndClose(); } }
    });
  }

  private async clearAndClose(): Promise<void> {
    this.busy = true;
    try {
      if (!this.drafts) throw new Error('No draft store');
      await this.drafts.clear();
      this.onClose();
    } catch (_) { this.status = '草稿未清除成功，请重试'; }
    finally { this.busy = false; }
  }

  private async save(): Promise<void> {
    if (this.busy || this.importing) return;
    const record: EmotionRecord = this.record();
    if (!hasContent(record)) { this.status = '选一个心情、写一句话或添加照片，就可以保存'; return; }
    this.busy = true;
    try {
      validateEditorRecord(record);
      await this.onSave(record);
    } catch (_) { this.status = '记录未保存成功，内容仍在这里，请重试'; }
    finally { this.busy = false; }
  }

  @Builder
  chip(label: string, selected: boolean, action: () => void) {
    Button(label).fontSize(13).fontWeight(FontWeight.Normal).height(36)
      .fontColor(selected ? Color.White : INK).backgroundColor(selected ? ROSE : '#F1EAE4')
      .padding({ left: 13, right: 13 }).margin({ right: 8, bottom: 8 })
      .accessibilityText(label + (selected ? '，已选择' : '，未选择')).onClick(action)
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(this.seed.kind === 'joy' ? '留下一点生活微光' : '留住此刻的自己').fontSize(22).fontColor(INK).layoutWeight(1)
        Button('稍后继续').fontSize(13).fontColor(ROSE).backgroundColor(Color.Transparent)
          .enabled(!this.busy && !this.importing).onClick(() => { this.close(); })
      }.width('100%')
      Scroll() {
        Column({ space: 16 }) {
          TextInput({ text: this.title, placeholder: '给这次记录起个名字 · 可不填' }).maxLength(60).fontSize(14)
            .onChange((value: string) => { this.title = value; this.changed(); })
          Text('可以只记心情，不必写得完整。').fontSize(13).fontColor(MUTED).width('100%')
          Column({ space: 6 }) {
            Text('此刻的感受 · 最多3种').fontSize(15).fontColor(INK).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(EDITOR_MOODS, (mood: string) => { this.chip(mood, this.moods.includes(mood), () => { this.toggleMood(mood); }) })
            }.width('100%')
          }.width('100%')
          Column({ space: 5 }) {
            Row() {
              Text(this.intensity < 0 ? '感受强度 · 可跳过' : `感受强度 · ${this.intensity}/10`).fontSize(14).fontColor(INK).layoutWeight(1)
              Button(this.intensity < 0 ? '选择强度' : '清除').fontSize(12).fontColor(ROSE).backgroundColor(Color.Transparent)
                .onClick(() => { this.intensity = this.intensity < 0 ? 5 : -1; this.changed(); })
            }.width('100%')
            if (this.intensity >= 0) {
              Slider({ value: this.intensity, min: 0, max: 10, step: 1 }).selectedColor(ROSE)
                .onChange((value: number) => { this.intensity = value; this.changed(); })
              Text('0 很轻微                                  10 很强烈').fontSize(11).fontColor(MUTED).width('100%')
            }
          }.width('100%')
          Column({ space: 6 }) {
            Text('和什么有关？· 可跳过').fontSize(15).fontColor(INK).width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(LIFE_TAGS, (tag: string) => { this.chip(tag, this.tags.includes(tag), () => { this.toggleTag(tag); }) })
              ForEach(this.tags.filter((tag: string) => !LIFE_TAGS.includes(tag)), (tag: string) => {
                this.chip(tag + ' ×', true, () => { this.toggleTag(tag); })
              })
            }.width('100%')
            Row({ space: 8 }) {
              TextInput({ text: this.customTag, placeholder: '自定义标签，如睡眠不足' }).maxLength(20).layoutWeight(1).fontSize(13)
                .onChange((value: string) => { this.customTag = value; })
              Button('添加').fontSize(12).fontColor(ROSE).backgroundColor('#F1EAE4').onClick(() => { this.addTag(); })
            }.width('100%')
          }.width('100%')
          TextArea({ text: this.text, placeholder: '今天发生了什么？也可以什么都不写。' })
            .height(190).fontSize(16).fontColor(INK).backgroundColor(Color.White).maxLength(5000)
            .onChange((value: string) => { this.text = value; this.changed(); })
          Text(`${this.text.length}/5000`).fontSize(11).fontColor(MUTED).width('100%').textAlign(TextAlign.End)
          Row({ space: 8 }) {
            ForEach(this.photos, (photo: PhotoReference) => {
              Column({ space: 4 }) {
                LocalPhoto({ filesDir: this.filesDir, relativePath: photo.relativePath, photoSize: 86 })
                Button('移除').fontSize(11).height(30).fontColor(MUTED).backgroundColor(Color.Transparent)
                  .onClick(() => { this.photos = this.photos.filter((item: PhotoReference) => item.id !== photo.id); this.changed(); })
              }
            }, (photo: PhotoReference) => photo.id)
          }.width('100%')
          Button(this.importing ? '正在导入照片…' : `添加照片 · ${this.photos.length}/3`).fontColor(ROSE).backgroundColor('#F1EAE4')
            .enabled(!this.importing && this.photos.length < 3).onClick(() => { this.pickPhotos(); })
          Button('舍弃草稿').fontSize(12).fontColor(MUTED).backgroundColor(Color.Transparent)
            .enabled(!this.importing).onClick(() => { this.discard(); })
        }.width('100%').enabled(!this.busy)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      Text(this.status).fontSize(11).fontColor(MUTED).width('100%').onClick(() => { if (!this.busy) this.changed(); })
      Button(this.busy ? '正在保存…' : '保存这次记录').width('100%').height(48).backgroundColor(ROSE).fontColor(Color.White)
        .enabled(!this.busy && !this.importing).onClick(() => { this.save(); })
    }.padding(20).width('100%').height('100%').backgroundColor(PAPER)
  }
}
