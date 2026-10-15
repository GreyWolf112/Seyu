import { EmotionRecord } from '../models/Record';
import { buildMoodReview, MoodReview, ReviewCount, ReviewDay } from '../models/MoodReview';
import { INK, MUTED, ROSE } from '../theme/Theme';

@Component
export struct MoodReviewCard {
  @Prop @Watch('refresh') entries: EmotionRecord[] = [];
  @StorageLink('zhiyuForeground') @Watch('foregroundChanged') foreground: boolean = true;
  @State period: number = 7;
  @State expanded: boolean = false;
  @State review: MoodReview = buildMoodReview([], 7);
  onDay: (date: string) => void = () => {};

  aboutToAppear(): void { this.refresh(); }
  private foregroundChanged(): void { if (this.foreground) this.refresh(); }
  private refresh(): void { this.review = buildMoodReview(this.entries, this.period); }

  @Builder
  counts(title: string, counts: ReviewCount[], empty: string) {
    Column({ space: 9 }) {
      Text(title).fontSize(15).fontColor(INK).fontWeight(FontWeight.Medium)
      if (counts.length === 0) { Text(empty).fontSize(12).fontColor(MUTED).lineHeight(21) }
      ForEach(counts.slice(0, 4), (item: ReviewCount) => {
        Row({ space: 12 }) {
          Text(item.label).fontSize(13).fontColor(INK).layoutWeight(1)
          Text(`${item.days} 天`).fontSize(12).fontColor(ROSE)
        }.width('100%')
      }, (item: ReviewCount) => item.label)
      if (counts.length > 4) { Text('显示出现天数最多的前4项').fontSize(10).fontColor(MUTED) }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('慢慢回看自己').fontSize(19).fontColor(INK)
        Blank()
        Text('只属于你的回顾').fontSize(11).fontColor(MUTED)
      }.width('100%')
      Row({ space: 8 }) {
        ForEach([7, 30], (days: number) => {
          Button(`近${days}天`).fontSize(12).fontColor(this.period === days ? Color.White : ROSE)
            .backgroundColor(this.period === days ? ROSE : '#F8F3F4')
            .accessibilityText(`近${days}天` + (this.period === days ? '，已选择' : ''))
            .onClick(() => { this.period = days; this.refresh(); })
        })
      }.width('100%')
      Text(`${this.review.start.replace(/-/g, '.')} — ${this.review.end.replace(/-/g, '.')} · 含今天`)
        .fontSize(11).fontColor(MUTED)
      if (this.review.totalRecords === 0) {
        Text('这段时间还没有记录。想写的时候，再回来就好。').fontSize(14).fontColor(INK).lineHeight(24)
      } else {
        Text(`在 ${this.review.recordedDays} 天里，留下了 ${this.review.totalRecords} 次记录。`)
          .fontSize(16).fontColor(INK).lineHeight(26)
        Text(this.review.moodDays < 3 ? '有情绪记录的天数还不多，先看看留下了什么，不急着找规律。' : '这里只呈现你写下的感受，不代表没有记录时的状态。')
          .fontSize(12).fontColor(MUTED).lineHeight(22)
        if (this.review.joyCount > 0) {
          Text(`其中有 ${this.review.joyCount} 条生活微光，也值得再看一眼。`).fontSize(12).fontColor(ROSE).lineHeight(22)
        }
        Button(this.expanded ? '收起回顾' : '展开这段时间的回顾').fontSize(12).fontColor(ROSE)
          .backgroundColor('#F8F3F4').width('100%').onClick(() => { this.expanded = !this.expanded; })
        if (this.expanded) {
          this.counts('记下过的情绪', this.review.moods, '还没有填写情绪。文字和照片同样是记录。')
          this.counts('记录里的生活场景', this.review.tags, '还没有填写场景标签，不会根据正文猜测。')
          Text('按出现天数统计；同一天同一项只计一次，多种情绪可以并存。场景标签不代表情绪的原因。')
            .fontSize(11).fontColor(MUTED).lineHeight(20)
          Text('点一个有记录的日子，回去看看').fontSize(13).fontColor(INK)
          ForEach(this.review.weeks, (week: ReviewDay[]) => {
            Row({ space: 3 }) {
              ForEach(week, (day: ReviewDay) => {
                Button() {
                  Column({ space: 5 }) {
                    Text(day.label).fontSize(10).fontColor(day.count > 0 ? ROSE : MUTED)
                    Text(day.count > 0 ? `${day.count}条` : '—').fontSize(10).fontColor(day.count > 0 ? ROSE : MUTED)
                  }.padding({ top: 10, bottom: 10 })
                }.layoutWeight(1).padding({ left: 0, right: 0 }).borderRadius(10).backgroundColor(day.count > 0 ? '#F8F3F4' : Color.Transparent)
                  .enabled(day.count > 0).accessibilityText(`${day.key}，${day.count}条记录`)
                  .onClick(() => { this.expanded = false; this.onDay(day.key); })
              }, (day: ReviewDay) => day.key)
              if (week.length < 7) { Blank().layoutWeight(7 - week.length) }
            }.width('100%')
          }, (week: ReviewDay[]) => week[0].key)
          Text('“—”表示没有记录，不表示心情不好。回顾基于全部已保存记录，不受下方筛选影响。')
            .fontSize(11).fontColor(MUTED).lineHeight(20)
        }
      }
    }.alignItems(HorizontalAlign.Start).width('100%').padding(20).backgroundColor('#EEE8EE').borderRadius(23)
  }
}
