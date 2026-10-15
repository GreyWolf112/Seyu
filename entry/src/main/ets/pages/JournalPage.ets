import { LocalPhoto } from '../components/LocalPhoto';
import { MoodReviewCard } from '../components/MoodReviewCard';
import { normalizedRecordDate } from '../models/RecordDate';
import { filterRecords } from '../models/RecordFilters';
import { EmotionRecord, PhotoReference } from '../models/Record';
import { Joy, DayItem } from '../models/LegacyModels';
import { INK, MUTED, ROSE } from '../theme/Theme';
import { icon, titleBlock, pill } from '../components/Common';

@Component
export struct JournalPage {
  openDataManager: () => void = () => {};
  private pendingReviewScroll: boolean = false;
  private listScroller: Scroller = new Scroller();
  @State recordFilter: string = '全部';
  @Link favoriteBusy: boolean;
  toggleFavorite: (id: string) => void = () => {};
  openJoy: () => void = () => {};
  putInBottle: (id: string) => void = () => {};
  @Link journalView: number;
  @Link search: string;
  @Link monthOffset: number;
  @Link joys: Joy[];
  @Link entries: EmotionRecord[];
  @Link selectedDate: string;
  openEditor: (text?: string) => void = (text: string = '') => {};
  @Prop filesDir: string = '';
  editRecord: (id: string) => void = () => {};
  deleteNote: (id: string) => void = (id: string) => {};

  private dateKey(date: Date): string {
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  private calendarTitle(): string {
    const date: Date = new Date(new Date().getFullYear(), new Date().getMonth() + this.monthOffset, 1);
    return `${date.getFullYear()} 年 ${date.getMonth() + 1} 月`;
  }

  private monthRows(): DayItem[][] {
    const first: Date = new Date(new Date().getFullYear(), new Date().getMonth() + this.monthOffset, 1);
    const count: number = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
    const rows: DayItem[][] = [];
    for (let week: number = 0; week < Math.ceil((first.getDay() + count) / 7); week++) {
      const row: DayItem[] = [];
      for (let day: number = 0; day < 7; day++) {
        const number: number = week * 7 + day - first.getDay() + 1;
        row.push({ key: number > 0 && number <= count ? this.dateKey(new Date(first.getFullYear(), first.getMonth(), number)) : '', day: number > 0 && number <= count ? number : 0, label: '' });
      }
      rows.push(row);
    }
    return rows;
  }

  private visibleEntries(): EmotionRecord[] {
    return filterRecords(this.entries, this.recordFilter, this.selectedDate, this.search);
  }

  build() {
    Scroll(this.listScroller) {
      Column() {
        titleBlock('LITTLE PIECES OF YOU', '你的感受，值得留下。', '收藏生活的微光，也安放偶尔的阴天。')
        Row({ space: 14 }) {
          Image($r('app.media.woman_read')).width(130).height(145).objectFit(ImageFit.Contain)
          Column({ space: 10 }) {
            Text('一页一页，\n都是你走过的日子。').fontSize(21).fontColor(INK).lineHeight(32)
            Text('不用完整，也不必每天都写。').fontSize(11).fontColor(MUTED)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').margin({ bottom: 22 })

        MoodReviewCard({ entries: this.entries, onDay: (date: string) => {
          this.recordFilter = '全部'; this.search = ''; this.selectedDate = date; this.journalView = 1;
          this.pendingReviewScroll = true;
        } }).margin({ bottom: 20 })
        Row({ space: 8 }) {
          icon($r('app.media.ic_lock'), 14)
          Text('手记仅保存在本机 · 你可以随时删除').fontSize(11).fontColor(MUTED)
        }.width('100%').margin({ bottom: 23 })
        Button('数据与备份 · 导出 / 恢复 / 删除').width('100%').fontSize(12).fontColor(ROSE)
          .backgroundColor('#F1EAE4').margin({ bottom: 18 }).onClick(this.openDataManager)
        Row({ space: 9 }) {
          pill('心情日历', this.journalView === 0, () => { this.journalView = 0; })
          pill('全部手记', this.journalView === 1, () => { this.journalView = 1; this.selectedDate = ''; })
        }.width('100%').margin({ bottom: 14 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['全部', '收藏', '整理卡', '微光', '瓶子'], (label: string) => {
            Button(label).fontSize(12).fontColor(this.recordFilter === label ? Color.White : ROSE)
              .backgroundColor(this.recordFilter === label ? ROSE : '#F1EAE4').margin({ right: 6, bottom: 8 })
              .onClick(() => { this.recordFilter = label; this.selectedDate = ''; this.search = ''; this.journalView = 1; })
          })
        }.width('100%')
        Button('留下一点自己的微光 +').fontColor(ROSE).backgroundColor(Color.Transparent).onClick(() => { this.openJoy(); })
        TextInput({ text: this.search, placeholder: '找找某个心情，或一句写过的话' }).height(46).backgroundColor('#F1EBE3').fontSize(13)
          .onChange((value: string) => { this.search = value; this.selectedDate = ''; }).margin({ bottom: 16 })
        if (this.journalView === 0) {
          Column({ space: 10 }) {
            Row() {
              Button('‹').fontColor(ROSE).backgroundColor(Color.Transparent).onClick(() => { this.monthOffset--; })
              Blank()
              Text(this.calendarTitle()).fontSize(17).fontColor(INK)
              Blank()
              Button('›').fontColor(ROSE).backgroundColor(Color.Transparent).onClick(() => { this.monthOffset++; })
            }.width('100%')
            Row() {
              ForEach(['日', '一', '二', '三', '四', '五', '六'], (label: string) => { Text(label).fontSize(11).fontColor(MUTED).layoutWeight(1).textAlign(TextAlign.Center) })
            }.width('100%')
            ForEach(this.monthRows(), (row: DayItem[]) => {
              Row({ space: 3 }) {
                ForEach(row, (day: DayItem) => {
                  Column({ space: 5 }) {
                    Text(day.day === 0 ? '' : day.day.toString()).fontSize(14).fontColor(this.selectedDate === day.key && day.day !== 0 ? '#FFFFFF' : INK)
                    Circle().width(5).height(5).fill(day.key !== '' && this.entries.some((item: EmotionRecord) => normalizedRecordDate(item.date) === day.key) ? '#B38594' : Color.Transparent)
                  }.height(43).layoutWeight(1).justifyContent(FlexAlign.Center).borderRadius(15)
                    .backgroundColor(day.key !== '' && this.selectedDate === day.key ? ROSE : Color.Transparent)
                    .onClick(() => { if (day.key !== '') this.selectedDate = day.key; })
                })
              }.width('100%')
            })
          }.padding(14).width('100%').backgroundColor('#FFFFFF').borderRadius(24)
        }
        Row() {
          Column({ space: 8 }) {
            Text('给今天，留下一页。').fontSize(19).fontColor(INK).fontWeight(FontWeight.Medium)
            Text('一句话也好，不需要写得漂亮。').fontSize(12).fontColor(MUTED)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button() { icon($r('app.media.ic_plus'), 23) }.width(46).height(46).backgroundColor('#FFFFFF').borderRadius(23)
            .accessibilityText('写一篇新的心情手记').onClick(() => { this.openEditor(); })
        }.padding(22).backgroundColor('#F0E0DC').borderRadius(23).width('100%').margin({ top: 24 })
        Row() {
          Text(this.selectedDate ? `${this.selectedDate.replace(/-/g, '.')} 的记录` : '心情足迹').fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK).layoutWeight(1)
          Blank()
          Button(this.selectedDate === '' ? '查看今天' : '全部手记').fontSize(11).fontColor(ROSE).height(38).backgroundColor(Color.Transparent)
            .onClick(() => { this.selectedDate = this.selectedDate === '' ? this.dateKey(new Date()) : ''; })
        }.width('100%').margin({ top: 20, bottom: 9 })
          .onAreaChange((_oldArea: Area, area: Area) => {
            if (this.pendingReviewScroll) {
              this.pendingReviewScroll = false;
              this.listScroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, Number(area.position.y) - 12) });
            }
          })
        if (this.visibleEntries().length === 0) {
          Column({ space: 13 }) {
            Image($r('app.media.woman_write')).width(145).height(145)
            Text(this.search.trim() ? '暂时没有找到匹配的记录' : this.recordFilter === '全部' ? '这一页，还在等你的故事' : `这里还没有${this.recordFilter}记录`).fontSize(17).fontColor(INK)
            Text('这里不用只记录开心。\n普通的一天，也值得被记住。').fontSize(12).fontColor(MUTED).lineHeight(22).textAlign(TextAlign.Center)
            Button('写下第一句话  ↗').fontSize(12).fontColor(ROSE).backgroundColor(Color.Transparent).onClick(() => { this.openEditor(); })
          }.width('100%').padding(24).backgroundColor('#FFFFFF').borderRadius(23)
        }
        ForEach(this.visibleEntries(), (item: EmotionRecord) => {
          Column({ space: 14 }) {
            Row() {
              Text(item.date.replace(/-/g, '.')).fontSize(11).fontColor(MUTED)
              Blank()
              Text(item.moods.join(' · ') || '随手记').fontSize(11).fontColor(ROSE).padding({ left: 10, right: 10, top: 5, bottom: 5 }).backgroundColor('#F6E8E5').borderRadius(10)
            }.width('100%')
            if (item.photos.length > 0) {
              Row({ space: 8 }) {
                ForEach(item.photos, (photo: PhotoReference) => {
                  LocalPhoto({ filesDir: this.filesDir, relativePath: photo.relativePath, photoSize: 82 })
                }, (photo: PhotoReference) => photo.id)
              }.width('100%')
            }
            if (item.tags.length > 0 || item.intensity !== null) {
              Text(item.tags.join(' · ') + (item.intensity !== null ? `  强度 ${item.intensity}/10` : ''))
                .fontSize(12).fontColor(MUTED).width('100%')
            }
            if (item.kind === 'reflection') { Text('心事整理 · ' + item.title).fontSize(16).fontColor(ROSE).width('100%') }
            if (item.kind !== 'reflection' && item.title) { Text((item.kind === 'joy' ? '生活微光 · ' : '') + item.title).fontSize(16).fontColor(INK).width('100%') }
            Text(item.text || (item.kind === 'joy' ? '这一点微光，已经留下。' : '此刻的感受，已经留下。')).fontSize(15).fontColor(INK).lineHeight(27).width('100%')
            Row() {
              Button('编辑').fontSize(11).fontColor(ROSE).backgroundColor(Color.Transparent).height(34)
                .onClick(() => { this.editRecord(item.id); })
              Button(item.favorite ? '取消收藏' : '收藏').fontSize(11).fontColor(ROSE).backgroundColor(Color.Transparent).height(34)
                .enabled(!this.favoriteBusy).onClick(() => { this.toggleFavorite(item.id); })
              Blank()
              Button('删除').fontSize(11).fontColor(MUTED).backgroundColor(Color.Transparent).height(34).onClick(() => { this.deleteNote(item.id); })
            }.width('100%')
            Button(item.bottled || item.kind === 'bottle' ? '已在私人瓶子里 · 查看' : '装进私人瓶子').fontSize(11).fontColor(ROSE)
              .backgroundColor(Color.Transparent).onClick(() => { this.putInBottle(item.id); })
          }.padding(20).backgroundColor('#FFFFFF').borderRadius(21).width('100%').margin({ bottom: 13 })
        }, (item: EmotionRecord) => item.id)
        Text('这是你的故事，不需要与任何人比较。').fontSize(11).fontColor(MUTED).margin({ top: 22, bottom: 30 })
      }.padding({ left: 24, right: 24 }).width('100%')
    }.scrollBar(BarState.Off).layoutWeight(1)
  }

}
