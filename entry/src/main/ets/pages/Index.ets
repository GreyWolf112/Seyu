import { preferences } from '@kit.ArkData';

interface JournalEntry {
  id: string;
  date: string;
  mood: string;
  text: string;
}
interface Bottle { id: string; date: string; mood: string; text: string; }
interface Joy { id: string; date: string; title: string; }
interface DayItem {
  key: string;
  day: number;
  label: string;
}

const INK: string = '#493E3D';
const MUTED: string = '#776B65';
const ROSE: string = '#986067';
const PAPER: string = '#FCF9F5';
const MOODS: string[] = ['平静', '开心', '疲惫', '委屈', '烦躁'];
const FACES: string[] = ['◡', '⌣', '－', '︵', '﹏'];

@Entry
@Component
struct Index {
  @State tab: number = 0;
  @State sanctuary: boolean = false;
  @State night: boolean = false;
  @State scene: number = 0;
  @State journalView: number = 0;
  @State search: string = '';
  @State monthOffset: number = 0;
  @State mood: string = '';
  @State mode: number = 0;
  @State draft: string = '';
  @State bottles: Bottle[] = [];
  @State joys: Joy[] = [];
  @State bottleMood: string = '平静';
  @State floating: boolean = false;
  @State savingBottle: boolean = false;
  @State savingJoy: boolean = false;
  @State showBottles: boolean = false;
  @State warmth: number = -1;
  private floatTimer: number = -1;
  private warmCards: string[] = ['你可以在照顾别人之前，先问问自己累不累。', '拒绝一件让你为难的事，也是在认真照顾自己的生活。', '今天没有特别的收获，也不妨碍你值得休息。', '你的感受不需要获得所有人的同意，才可以存在。'];
  @State filter: number = 0;
  @State entries: JournalEntry[] = [];
  @State selectedDate: string = '';
  @State editor: boolean = false;
  @State note: string = '';
  @State noteMood: string = '平静';
  @State editingId: string = '';
  @State exercise: number = -1;
  @State seconds: number = 60;
  @State running: boolean = false;
  @State step: number = 0;
  @State notice: string = '';
  private timer: number = -1;
  private noticeTimer: number = -1;
  private storage: preferences.Preferences | undefined = undefined;
  private modes: string[] = ['先听我说', '陪我梳理', '想个小办法'];
  private tabs: string[] = ['首页', '陪伴', '舒缓', '心情手记'];
  private icons: Resource[] = [$r('app.media.ic_home'), $r('app.media.ic_chat'), $r('app.media.ic_leaf'), $r('app.media.ic_book')];

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

  private visibleEntries(): JournalEntry[] {
    return this.entries.filter((item: JournalEntry) => (this.selectedDate === '' || item.date === this.selectedDate) && (!this.search.trim() || item.text.includes(this.search.trim()) || item.mood.includes(this.search.trim())));
  }

  aboutToAppear(): void {
    this.selectedDate = this.dateKey(new Date());
    try {
      const context = this.getUIContext().getHostContext();
      if (context) {
        this.storage = preferences.getPreferencesSync(context, { name: 'zhiyu_journal' });
        const saved: string = this.storage.getSync('entries', '[]') as string;
        this.entries = JSON.parse(saved) as JournalEntry[];
        this.bottles = JSON.parse(this.storage.getSync('bottles', '[]') as string) as Bottle[];
        this.joys = JSON.parse(this.storage.getSync('joys', '[]') as string) as Joy[];
      }
    } catch (_) {
      this.flash('暂时无法读取本地手记，请稍后重试');
    }
  }

  aboutToDisappear(): void {
    if (this.floatTimer !== -1) clearTimeout(this.floatTimer);
    this.stopTimer();
    if (this.noticeTimer !== -1) clearTimeout(this.noticeTimer);
  }

  private flash(text: string): void {
    if (this.noticeTimer !== -1) clearTimeout(this.noticeTimer);
    this.notice = text;
    this.noticeTimer = setTimeout(() => { this.notice = ''; }, 2800);
  }

  private openEditor(text: string = ''): void {
    this.editingId = '';
    this.note = text;
    this.noteMood = this.mood || '平静';
    this.editor = true;
  }

  private async saveNote(): Promise<void> {
    if (!this.note.trim()) { this.flash('写下一点此刻的感受吧'); return; }
    const record: JournalEntry = {
      id: this.editingId || Date.now().toString(),
      date: this.editingId ? (this.entries.find((item: JournalEntry) => item.id === this.editingId)?.date || this.dateKey(new Date())) : this.dateKey(new Date()),
      mood: this.noteMood,
      text: this.note.trim()
    };
    const next: JournalEntry[] = [record, ...this.entries.filter((item: JournalEntry) => item.id !== record.id)];
    try {
      if (!this.storage) { this.flash('本地存储暂不可用，文字仍保留在这里'); return; }
      await this.storage.put('entries', JSON.stringify(next));
      await this.storage.flush();
      this.entries = next;
      this.selectedDate = record.date;
      this.editor = false;
      this.tab = 3;
      this.flash('已保存在这台设备上');
    } catch (_) { this.flash('保存未完成，文字仍保留在这里'); }
  }

  private deleteNote(id: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除这篇手记？', message: '删除后无法恢复。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.removeNote(id); } }
    });
  }

  private async removeNote(id: string): Promise<void> {
    const next: JournalEntry[] = this.entries.filter((item: JournalEntry) => item.id !== id);
    try {
      if (!this.storage) return;
      await this.storage.put('entries', JSON.stringify(next));
      await this.storage.flush();
      this.entries = next;
      this.flash('手记已删除');
    } catch (_) { this.flash('删除未完成，请重试'); }
  }

  private async floatBottle(): Promise<void> {
    if (!this.draft.trim() || this.savingBottle || this.floating) return;
    this.savingBottle = true;
    const next: Bottle[] = [{ id: Date.now().toString(), date: this.dateKey(new Date()), mood: this.bottleMood, text: this.draft.trim() }, ...this.bottles];
    try {
      if (!this.storage) throw new Error('storage');
      await this.storage.put('bottles', JSON.stringify(next));
      await this.storage.flush();
      this.bottles = next;
      this.draft = '';
      this.floating = true;
      this.floatTimer = setTimeout(() => { this.floating = false; this.flash('已收进你的私人瓶子收藏'); }, 1800);
    } catch (_) { this.flash('没有保存成功，心事仍留在输入框里'); }
    finally { this.savingBottle = false; }
  }

  private deleteBottle(id: string): void {
    this.getUIContext().showAlertDialog({ title: '删除这只瓶子？', message: '里面的文字也会删除，无法恢复。',
      primaryButton: { value: '留下', action: () => {} }, secondaryButton: { value: '删除', action: () => { this.removeBottle(id); } } });
  }

  private async removeBottle(id: string): Promise<void> {
    const next: Bottle[] = this.bottles.filter((item: Bottle) => item.id !== id);
    try {
      if (!this.storage) throw new Error('storage');
      await this.storage.put('bottles', JSON.stringify(next)); await this.storage.flush(); this.bottles = next;
    } catch (_) { this.flash('删除未完成，请重试'); }
  }

  private async recordJoy(title: string): Promise<void> {
    if (this.savingJoy) return;
    const today: string = this.dateKey(new Date());
    const exists: boolean = this.joys.some((item: Joy) => item.date === today && item.title === title);
    const next: Joy[] = exists ? this.joys.filter((item: Joy) => !(item.date === today && item.title === title)) : [{ id: Date.now().toString(), date: today, title }, ...this.joys];
    this.savingJoy = true;
    try {
      if (!this.storage) throw new Error('storage');
      await this.storage.put('joys', JSON.stringify(next)); await this.storage.flush(); this.joys = next;
      this.flash(exists ? '已取消这次记录' : '今天的这一点微光，留下了');
    } catch (_) { this.flash('保存未完成，请重试'); }
    finally { this.savingJoy = false; }
  }

  private stopTimer(): void {
    if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1; }
    this.running = false;
  }

  private startExercise(kind: number): void {
    this.stopTimer();
    this.seconds = 60;
    this.step = 0;
    this.exercise = kind;
  }

  private toggleBreathing(): void {
    if (this.running) { this.stopTimer(); return; }
    if (this.seconds === 0) this.seconds = 60;
    this.running = true;
    this.timer = setInterval(() => {
      if (this.seconds > 0) this.seconds--;
      if (this.seconds === 0) this.stopTimer();
    }, 1000);
  }

  @Builder
  icon(source: Resource, size: number = 22) {
    Image(source).width(size).height(size).objectFit(ImageFit.Contain)
  }

  @Builder
  titleBlock(eyebrow: string, title: string, subtitle: string) {
    Column({ space: 9 }) {
      Text(eyebrow).fontSize(11).fontColor(ROSE).letterSpacing(2)
      Text(title).fontSize(30).fontWeight(FontWeight.Medium).fontColor(INK)
      Text(subtitle).fontSize(13).fontColor(MUTED).lineHeight(22)
    }.alignItems(HorizontalAlign.Start).width('100%').margin({ top: 17, bottom: 26 })
  }

  @Builder
  section(title: string, caption: string) {
    Row() {
      Text(title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK)
      Blank()
      Text(caption).fontSize(11).fontColor(MUTED)
    }.width('100%').margin({ top: 26, bottom: 16 })
  }

  @Builder
  moodPicker(forNote: boolean = false) {
    Row() {
      ForEach(MOODS, (item: string, index: number) => {
        Column({ space: 9 }) {
          Text(FACES[index]).fontSize(25).fontColor(ROSE).textAlign(TextAlign.Center)
            .width(43).height(43).backgroundColor((forNote ? this.noteMood : this.mood) === item ? '#EBCED0' : '#F6EBE5')
            .borderRadius(22).border({ width: (forNote ? this.noteMood : this.mood) === item ? 1.5 : 0, color: ROSE })
          Text(item).fontSize(12).fontColor((forNote ? this.noteMood : this.mood) === item ? ROSE : MUTED)
        }.layoutWeight(1).padding({ top: 3, bottom: 5 })
        .accessibilityText(item + ((forNote ? this.noteMood : this.mood) === item ? '，已选择' : ''))
        .onClick(() => { if (forNote) this.noteMood = item; else this.mood = item; })
      }, (item: string) => item)
    }.width('100%')
  }

  @Builder
  pill(text: string, selected: boolean, action: () => void) {
    Button(text).fontSize(12).fontWeight(FontWeight.Normal).fontColor(selected ? '#FFFFFF' : MUTED)
      .backgroundColor(selected ? ROSE : '#F1EAE4').height(36).padding({ left: 15, right: 15 })
      .borderRadius(18).onClick(action)
  }

  @Builder
  mainButton(label: string, action: () => void) {
    Button(label).width('100%').height(48).fontSize(14).fontWeight(FontWeight.Medium)
      .fontColor(Color.White).backgroundColor(ROSE).borderRadius(16).onClick(action)
  }

  @Builder
  needTile(title: string, subtitle: string, art: Resource, action: () => void) {
    Column({ space: 7 }) {
      Image(art).width('100%').height(136).objectFit(ImageFit.Contain)
      Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(INK)
      Text(subtitle).fontSize(11).fontColor(MUTED)
    }.layoutWeight(1).padding({ bottom: 16 }).onClick(action)
  }

  @Builder
  needsGarden() {
    this.section('今天，想怎样照顾自己？', '跟着此刻的需要')
    Row({ space: 16 }) {
      this.needTile('我很累，不想说话', '安静待着，也很好', $r('app.media.woman_rest'), () => { this.sanctuary = true; })
      this.needTile('心里有一点委屈', '让没说出口的话靠岸', $r('app.media.woman_write'), () => { this.tab = 1; this.mode = 0; })
    }.width('100%')
    Row({ space: 16 }) {
      this.needTile('脑子停不下来', '把事情一件件放下', $r('app.media.woman_read'), () => { this.tab = 1; this.mode = 1; })
      this.needTile('又勉强自己了吗', '练习把自己放在前面', $r('app.media.woman_walk'), () => { this.openEditor('我其实不太愿意的是：\n\n我的需要是：\n\n我可以这样表达拒绝：\n'); })
    }.width('100%')
    Row({ space: 16 }) {
      this.needTile('想舒服一点', '选一件小小的喜欢', $r('app.media.woman_flowers'), () => { this.tab = 2; })
      this.needTile('今天也辛苦了', '不用给自己打分', $r('app.media.woman_music'), () => { this.openEditor('今天让我辛苦的是：\n\n稍微没那么难受的一刻：\n\n今晚我想先放下：\n'); })
    }.width('100%')
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
  ritual(title: string, subtitle: string, art: Resource, color: string) {
    Column({ space: 7 }) {
      Image(art).width(95).height(90).objectFit(ImageFit.Contain)
      Text(title).fontSize(16).fontColor(INK)
      Text(subtitle).fontSize(11).fontColor(MUTED)
    }.padding(15).layoutWeight(1).backgroundColor(color).borderRadius({ topLeft: 35, topRight: 15, bottomLeft: 15, bottomRight: 35 })
      .onClick(() => { this.openEditor(`${title}\n\n${subtitle}\n\n`); })
  }

  @Builder
  homePage() {
    Scroll() {
      Column() {
        Row() {
          Row({ space: 8 }) {
            this.icon($r('app.media.ic_spark'), 22)
            Text('知屿').fontSize(21).fontWeight(FontWeight.Medium).fontColor(INK).letterSpacing(3)
          }
          Blank()
          Text(`${new Date().getMonth() + 1}月${new Date().getDate()}日 · 给自己一点时间`).fontSize(11).fontColor(MUTED)
        }.width('100%').margin({ top: 10, bottom: 26 })
        Column({ space: 9 }) {
          Text('留一盏灯，给自己。').fontSize(27).fontWeight(FontWeight.Medium).fontColor(INK)
          Text('放下「应该」，先照顾此刻的感受。').fontSize(13).fontColor(MUTED)
        }.alignItems(HorizontalAlign.Start).width('100%').margin({ bottom: 20 })
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.window_woman')).width('100%').height(211).objectFit(ImageFit.Cover)
          Row({ space: 5 }) {
            Text('✧').fontColor(INK).fontSize(12)
            Text('今日小屿 · 不必时刻都很坚强').fontColor(INK).fontSize(11)
          }.padding({ left: 12, right: 12, top: 8, bottom: 8 }).backgroundColor('#EFFFFFF8').borderRadius(12).margin(14)
        }.width('100%').borderRadius(24).clip(true)
        this.section('此刻，心里是什么天气？', '选一个最贴近的感受')
        this.moodPicker()
        if (this.mood) {
          Text(`今天的${this.mood}，也可以被好好安放。`).fontSize(12).fontColor(ROSE).margin({ top: 12 })
        }
        this.section('属于你的生活角落', '左右滑动，选一处停留')
        Swiper() {
          this.scenePanel('暮色花园', '让一天慢慢落幕', $r('app.media.moon_garden'), 1)
          this.scenePanel('清晨的窗', '把时间留给自己', $r('app.media.morning_garden'), 2)
          this.scenePanel('窗边独处', '不必回应所有期待', $r('app.media.window_woman'), 0)
        }.height(230).autoPlay(false).indicator(true).margin({ bottom: 8 })
        this.needsGarden()
        this.section('给自己的书写仪式', '不需要每天完成')
        Row({ space: 12 }) {
          this.ritual('晨间一页', '今天，我想先照顾…', $r('app.media.woman_flowers'), '#E7EDDF')
          this.ritual('没寄出的信', '有些话，只写给自己', $r('app.media.woman_write'), '#F0E0E3')
        }.width('100%')
        Row({ space: 12 }) {
          this.ritual('我的小小勇敢', '哪怕只是一句拒绝', $r('app.media.woman_walk'), '#ECE5D8')
          this.ritual('睡前放一放', '今晚不用想出答案', $r('app.media.woman_rest'), '#E8E2ED')
        }.width('100%').margin({ top: 12 })

        this.section('给今天的一句温柔', 'A LITTLE REMINDER')
        Column({ space: 13 }) {
          Text('“').fontSize(37).fontColor('#BD9381').height(26)
          Text('你不需要一直表现得很好，\n才值得被认真对待。').fontSize(18).fontColor(INK).lineHeight(31)
          Row() {
            Text('允许自己，暂时休息一下。').fontSize(11).fontColor(MUTED)
            Blank()
            Button('记下此刻  ↗').fontSize(11).fontColor(ROSE).backgroundColor(Color.Transparent).height(36)
              .onClick(() => { this.openEditor(); })
          }.width('100%')
        }.alignItems(HorizontalAlign.Start).width('100%').padding(21).backgroundColor('#F3EDE3').borderRadius(22)
        Text('每一种感受，都有被听见的位置。').fontSize(11).fontColor(MUTED).margin({ top: 26, bottom: 16 })
      }.padding({ left: 24, right: 24, bottom: 16 }).width('100%')
    }.scrollBar(BarState.Off).layoutWeight(1).width('100%')
  }

  @Builder
  companionPage() {
    Scroll() {
      Column({ space: 16 }) {
        this.titleBlock('LET IT REST HERE', '心事，有处安放。', '写给自己，留在这里。今天不用急着释怀。')
        Row({ space: 16 }) {
          Image($r('app.media.woman_write')).width(120).height(125).objectFit(ImageFit.Contain)
          Column({ space: 8 }) {
            Text('一封信，一只瓶子，\n都装得下此刻的你。').fontSize(19).fontColor(INK).lineHeight(29)
            Text('你的私人海岸 · 不公开投递').fontSize(11).fontColor(MUTED)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.bottle_sea')).width('100%').height(195).objectFit(ImageFit.Cover)
            .translate({ x: this.floating ? 55 : 0, y: this.floating ? -24 : 0 }).opacity(this.floating ? 0.25 : 1)
            .animation({ duration: 1600, curve: Curve.EaseInOut })
          Text(this.floating ? '让心事，轻轻靠岸。' : '私人漂流瓶 · 仅自己可见').fontSize(12).fontColor('#49675E')
            .padding(12).backgroundColor('#EFFFFFF8').borderRadius(12).margin(16)
        }.width('100%').backgroundColor('#E8E7ED').borderRadius(25).clip(true)
        Row({ space: 7 }) {
          ForEach(this.modes, (label: string, index: number) => {
            Button(label).fontSize(12).fontWeight(FontWeight.Normal)
              .fontColor(this.mode === index ? '#FFFFFF' : MUTED)
              .backgroundColor(this.mode === index ? ROSE : '#F1EAE4')
              .height(36).padding({ left: 15, right: 15 }).borderRadius(18)
              .accessibilityText(label + (this.mode === index ? '，已选择' : ''))
              .onClick(() => { this.mode = index; })
          })
        }.width('100%')
        Column({ space: 15 }) {
          Text(this.mode === 0 ? '此刻，你最想说的是什么？' : this.mode === 1 ? '先照顾自己的感受，再慢慢梳理。' : '今天，可以为自己做哪一件小事？').fontSize(17).fontColor(INK).lineHeight(26)
          Text(this.mode === 0 ? '委屈、疲惫、说不清楚，都可以写在这里。' : this.mode === 1 ? '发生了什么？我感到什么？我需要什么？' : '也许是拒绝一次勉强，或允许自己早点休息。').fontSize(12).fontColor(MUTED).lineHeight(22)
          TextArea({ text: this.draft, placeholder: '把暂时放不下的心事，轻轻写下来…' }).height(160).fontSize(15).fontColor(INK)
            .backgroundColor('#FFFCF7').maxLength(2000).onChange((value: string) => { this.draft = value; })
          Row({ space: 5 }) {
            ForEach(MOODS, (label: string) => {
              Text(label).fontSize(12).fontColor(this.bottleMood === label ? ROSE : MUTED).padding(8)
                .backgroundColor(this.bottleMood === label ? '#F0DDDF' : '#F5F1EB').borderRadius(12)
                .onClick(() => { this.bottleMood = label; })
            })
          }.width('100%')
          Button(this.savingBottle ? '正在收好…' : this.floating ? '心事正在靠岸…' : '装进瓶子，轻轻放漂').width('100%').height(48).fontSize(14)
            .backgroundColor(ROSE).fontColor(Color.White).enabled(this.draft.trim().length > 0 && !this.savingBottle && !this.floating)
            .onClick(() => { this.floatBottle(); })
          Text('放漂后保存在本机收藏，不会发送给其他人。').fontSize(11).fontColor(MUTED).lineHeight(20)
        }.alignItems(HorizontalAlign.Start).padding(20).backgroundColor('#FFFFFF').borderRadius(24).width('100%')
        Row({ space: 12 }) {
          Image($r('app.media.woman_write')).width(92).height(100).objectFit(ImageFit.Contain)
          Column({ space: 6 }) {
            Text('给自己的一封信').fontSize(16).fontColor(INK)
            Text('写给那个总在努力的自己').fontSize(11).fontColor(MUTED)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          this.icon($r('app.media.ic_arrow'), 18)
        }.padding(15).width('100%').backgroundColor('#F0E4E2').borderRadius(22)
          .onClick(() => { this.openEditor('亲爱的自己：\n\n最近辛苦你的地方是：\n\n我想允许自己：\n'); })
        Button('拾一份温柔  ✧').fontSize(14).fontColor(ROSE).backgroundColor('#EFE8EF').width('100%').height(46)
          .onClick(() => { this.warmth = (this.warmth + 1) % this.warmCards.length; })
        if (this.warmth >= 0) {
          Column({ space: 10 }) {
            Text(this.warmCards[this.warmth]).fontSize(17).lineHeight(29).fontColor(INK)
            Text('知屿文字卡 · 预设内容，并非他人回信').fontSize(10).fontColor(MUTED)
          }.width('100%').padding(22).backgroundColor('#FFF7E9').borderRadius(22)
        }
        Image($r('app.media.bottle_sea')).width('100%').height(95).objectFit(ImageFit.Cover).borderRadius(18)
        Button(`我的瓶子收藏 · ${this.bottles.length}  ${this.showBottles ? '收起' : '展开'}`).fontSize(14).fontColor(ROSE)
          .backgroundColor(Color.Transparent).onClick(() => { this.showBottles = !this.showBottles; })
        if (this.showBottles) {
          if (this.bottles.length === 0) { Text('海岸很安静，第一只瓶子会在这里等你。').fontSize(12).fontColor(MUTED) }
          ForEach(this.bottles, (item: Bottle) => {
            Column({ space: 12 }) {
              Text(`${item.date}  ·  ${item.mood}`).fontSize(12).fontColor(ROSE)
              Text(item.text).fontSize(15).fontColor(INK).lineHeight(26).width('100%')
              Button('删除这只瓶子').fontSize(11).fontColor(MUTED).backgroundColor(Color.Transparent).onClick(() => { this.deleteBottle(item.id); })
            }.alignItems(HorizontalAlign.Start).width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(20)
          }, (item: Bottle) => item.id)
        }
      }.width('100%').padding({ left: 24, right: 24, bottom: 28 })
    }.scrollBar(BarState.Off).layoutWeight(1)
  }

  @Builder
  exerciseCard(title: string, subtitle: string, tag: string, color: string, icon: Resource, action: () => void) {
    Row({ space: 15 }) {
      Stack() { Circle().width(49).height(49).fill(color); this.icon(icon, 24) }
      Column({ space: 7 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(INK)
        Text(subtitle).fontSize(11).fontColor(MUTED)
        Text(tag).fontSize(10).fontColor(ROSE)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      this.icon($r('app.media.ic_arrow'), 18)
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

  @Builder
  soothePage() {
    Scroll() {
      Column() {
        this.titleBlock('A MOMENT FOR YOURSELF', '在片刻花园，歇一会儿。', '不用努力变好，先让此刻舒服一点。')
        Stack({ alignContent: Alignment.End }) {
          Image($r('app.media.botanical')).width(150).height(205).opacity(0.8)
          Column({ space: 13 }) {
            Text('今日留白  /  01').fontSize(10).fontColor('#61775F').letterSpacing(2)
            Text('跟着呼吸，\n慢慢回到此刻。').fontSize(25).fontColor(INK).lineHeight(37)
            Text('一分钟 · 温和呼吸引导').fontSize(11).fontColor('#62715E')
            Button('开始放松   →').fontSize(12).height(38).backgroundColor('#71856A').fontColor(Color.White)
              .padding({ left: 18, right: 18 }).onClick(() => { this.startExercise(0); })
          }.alignItems(HorizontalAlign.Start).width('100%').padding(25)
        }.width('100%').backgroundColor('#E7ECDD').borderRadius(25).clip(true)
        this.section('什么都不做，也可以', '你的安静角落')
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.window_woman')).width('100%').height(210).objectFit(ImageFit.Cover)
          Column({ space: 8 }) {
            Text('窗边，给自己留个位置').fontSize(19).fontColor(INK)
            Text('进入安静空间  →').fontSize(12).fontColor(ROSE)
          }.padding(16).backgroundColor('#EFFFFFF4').borderRadius(16).margin(16)
        }.borderRadius(25).clip(true).onClick(() => { this.sanctuary = true; })
        Swiper() {
          this.scenePanel('暮色花园', '今晚，允许自己慢下来', $r('app.media.moon_garden'), 1)
          this.scenePanel('晨光里的空白', '暂时不安排任何事', $r('app.media.morning_garden'), 2)
        }.height(230).autoPlay(false).margin({ top: 16 })
        this.section('今天的一点微光', '做过就留下，不必打卡')
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
        this.section('找到适合此刻的方式', '由你选择')
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
          this.exerciseCard('跟随呼吸，歇一会儿', '用舒服的节奏，留一小段空白', '1 分钟 · 呼吸引导', '#EDE4D8', $r('app.media.ic_spark'), () => { this.startExercise(0); })
        }
        if (this.filter !== 1) {
          this.exerciseCard('写下暂时放不下的事', '把脑海中的声音，安放在纸上', '不限时 · 自由书写', '#F1DFDD', $r('app.media.ic_book'), () => { this.openEditor('此刻让我放不下的是：\n\n我希望自己得到的支持是：\n'); })
          this.exerciseCard('给自己的一封短信', '试着对自己，说一句温柔的话', '不限时 · 自我关怀', '#EDE5D6', $r('app.media.ic_chat'), () => { this.openEditor('亲爱的自己：\n\n'); })
        }
        Text('随时可以暂停。照顾自己，没有标准答案。').fontSize(11).fontColor(MUTED).textAlign(TextAlign.Center).margin({ top: 15, bottom: 25 })
      }.padding({ left: 24, right: 24 }).width('100%')
    }.scrollBar(BarState.Off).layoutWeight(1)
  }

  @Builder
  journalPage() {
    Scroll() {
      Column() {
        this.titleBlock('LITTLE PIECES OF YOU', '你的感受，值得留下。', '收藏生活的微光，也安放偶尔的阴天。')
        Row({ space: 14 }) {
          Image($r('app.media.woman_read')).width(130).height(145).objectFit(ImageFit.Contain)
          Column({ space: 10 }) {
            Text('一页一页，\n都是你走过的日子。').fontSize(21).fontColor(INK).lineHeight(32)
            Text('不用完整，也不必每天都写。').fontSize(11).fontColor(MUTED)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').margin({ bottom: 22 })

        Column({ space: 10 }) {
          Text('慢慢回看自己').fontSize(18).fontColor(INK)
          Text(this.entries.length < 3 ? '记录还不多，先留住此刻，不急着总结规律。' : `你留下了 ${this.entries.length} 篇手记。每一种感受，都是生活的一部分。`).fontSize(13).fontColor(MUTED).lineHeight(23)
          Text(`珍藏 ${this.bottles.length} 只心事瓶 · 留下 ${this.joys.length} 点生活微光`).fontSize(12).fontColor(ROSE)
        }.alignItems(HorizontalAlign.Start).width('100%').padding(20).backgroundColor('#EEE8EE').borderRadius(23).margin({ bottom: 20 })
        Row({ space: 8 }) {
          this.icon($r('app.media.ic_lock'), 14)
          Text('手记仅保存在本机 · 你可以随时删除').fontSize(11).fontColor(MUTED)
        }.width('100%').margin({ bottom: 23 })
        Row({ space: 9 }) {
          this.pill('心情日历', this.journalView === 0, () => { this.journalView = 0; })
          this.pill('全部手记', this.journalView === 1, () => { this.journalView = 1; this.selectedDate = ''; })
        }.width('100%').margin({ bottom: 14 })
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
                    Circle().width(5).height(5).fill(day.key !== '' && this.entries.some((item: JournalEntry) => item.date === day.key) ? '#B38594' : Color.Transparent)
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
          Button() { this.icon($r('app.media.ic_plus'), 23) }.width(46).height(46).backgroundColor('#FFFFFF').borderRadius(23)
            .accessibilityText('写一篇新的心情手记').onClick(() => { this.openEditor(); })
        }.padding(22).backgroundColor('#F0E0DC').borderRadius(23).width('100%').margin({ top: 24 })
        Row() {
          Text('心情足迹').fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK)
          Blank()
          Button(this.selectedDate === '' ? '查看今天' : '全部手记').fontSize(11).fontColor(ROSE).height(38).backgroundColor(Color.Transparent)
            .onClick(() => { this.selectedDate = this.selectedDate === '' ? this.dateKey(new Date()) : ''; })
        }.width('100%').margin({ top: 20, bottom: 9 })
        if (this.visibleEntries().length === 0) {
          Column({ space: 13 }) {
            Image($r('app.media.woman_write')).width(145).height(145)
            Text(this.search.trim() ? '暂时没有找到匹配的手记' : '这一页，还在等你的故事').fontSize(17).fontColor(INK)
            Text('这里不用只记录开心。\n普通的一天，也值得被记住。').fontSize(12).fontColor(MUTED).lineHeight(22).textAlign(TextAlign.Center)
            Button('写下第一句话  ↗').fontSize(12).fontColor(ROSE).backgroundColor(Color.Transparent).onClick(() => { this.openEditor(); })
          }.width('100%').padding(24).backgroundColor('#FFFFFF').borderRadius(23)
        }
        ForEach(this.visibleEntries(), (item: JournalEntry) => {
          Column({ space: 14 }) {
            Row() {
              Text(item.date.replace(/-/g, '.')).fontSize(11).fontColor(MUTED)
              Blank()
              Text(item.mood).fontSize(11).fontColor(ROSE).padding({ left: 10, right: 10, top: 5, bottom: 5 }).backgroundColor('#F6E8E5').borderRadius(10)
            }.width('100%')
            Text(item.text).fontSize(15).fontColor(INK).lineHeight(27).width('100%')
            Row() {
              Button('编辑').fontSize(11).fontColor(ROSE).backgroundColor(Color.Transparent).height(34)
                .onClick(() => { this.note = item.text; this.noteMood = item.mood; this.editingId = item.id; this.editor = true; })
              Blank()
              Button('删除').fontSize(11).fontColor(MUTED).backgroundColor(Color.Transparent).height(34).onClick(() => { this.deleteNote(item.id); })
            }.width('100%')
          }.padding(20).backgroundColor('#FFFFFF').borderRadius(21).width('100%').margin({ bottom: 13 })
        }, (item: JournalEntry) => item.id)
        this.section('生活里的小小收藏', '最近留下的微光')
        if (this.joys.length === 0) {
          Text('散过的步、听过的歌，都可以在舒缓页留下印记。').fontSize(12).fontColor(MUTED).lineHeight(22)
        }
        ForEach(this.joys.slice(0, 6), (item: Joy) => {
          Row({ space: 12 }) {
            Image($r('app.media.life_flower')).width(44).height(44)
            Text(item.title).fontSize(14).fontColor(INK).layoutWeight(1)
            Text(item.date).fontSize(11).fontColor(MUTED)
          }.width('100%').padding(10).border({ width: { bottom: 1 }, color: '#E8DED6' })
        }, (item: Joy) => item.id)
        Text('这是你的故事，不需要与任何人比较。').fontSize(11).fontColor(MUTED).margin({ top: 22, bottom: 30 })
      }.padding({ left: 24, right: 24 }).width('100%')
    }.scrollBar(BarState.Off).layoutWeight(1)
  }

  @Builder
  navigation() {
    Row() {
      ForEach(this.tabs, (label: string, index: number) => {
        Column({ space: 5 }) {
          Stack() {
            if (this.tab === index) { Rect().width(45).height(29).fill('#EEDDD8').radius(13) }
            this.icon(this.icons[index], 21)
          }.height(30)
          Text(label).fontSize(10).fontColor(this.tab === index ? ROSE : MUTED).fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Normal)
        }.layoutWeight(1).padding({ top: 9, bottom: 10 }).onClick(() => { this.tab = index; })
          .id(`tab-${index}`).accessibilityText(label + (this.tab === index ? '，当前页面' : ''))
      })
    }.width('100%').backgroundColor('#FCF9F5').border({ width: { top: 1 }, color: '#EDE5DD' })
  }

  @Builder
  editorSheet() {
    Column({ space: 18 }) {
      Row() {
        Text(this.editingId ? '编辑这页心情' : '写给此刻的自己').fontSize(22).fontColor(INK).fontWeight(FontWeight.Medium)
        Blank()
        Button('收起').fontSize(12).fontColor(MUTED).backgroundColor(Color.Transparent).onClick(() => {
          if (this.note.trim()) {
            this.getUIContext().showAlertDialog({ title: '暂时离开书写？', message: '尚未保存的文字会被舍弃。',
              primaryButton: { value: '继续写', action: () => {} }, secondaryButton: { value: '舍弃', action: () => { this.editor = false; } } });
          } else this.editor = false;
        })
      }.width('100%')
      Text('不需要完整，不需要正确，真实就很好。').fontSize(12).fontColor(MUTED).width('100%')
      this.moodPicker(true)
      TextArea({ placeholder: '今天发生了什么？\n此刻，最想对自己说的一句话是…', text: this.note })
        .width('100%').layoutWeight(1).fontSize(16).fontColor(INK).placeholderColor(MUTED).backgroundColor('#FFFFFF').borderRadius(18)
        .padding(18).maxLength(5000).onChange((value: string) => { this.note = value; })
      Text(`${this.note.length} / 5000 · 仅保存到本机`).fontSize(11).fontColor(MUTED).width('100%').textAlign(TextAlign.End)
      this.mainButton('保存这页心情', () => { this.saveNote(); })
    }.width('100%').height('100%').padding(24).backgroundColor(PAPER)
  }

  @Builder
  exerciseSheet() {
    Column() {
      Row() {
        Text('给自己一点时间').fontSize(13).fontColor(MUTED)
        Blank()
        Button('结束').fontSize(13).fontColor(INK).backgroundColor(Color.Transparent).onClick(() => { this.stopTimer(); this.exercise = -1; })
      }.width('100%')
      Blank()
      Text(this.exercise === 0 ? '跟着呼吸，回到此刻' : '轻轻地，回到身体').fontSize(25).fontColor(INK)
      Text(this.exercise === 0 ? '保持舒服的节奏，不必勉强跟随。' : '用一点点感官，感受当下的自己。').fontSize(12).fontColor(MUTED).margin({ top: 15 })
      Stack() {
        Circle().width(242).height(242).fill('#E4EADC')
        Circle().width(205).height(205).fill('#D7E1CD')
          .scale({ x: this.running && (60 - this.seconds) % 10 < 4 ? 1.1 : 0.88, y: this.running && (60 - this.seconds) % 10 < 4 ? 1.1 : 0.88 })
          .animation({ duration: 1400, curve: Curve.EaseInOut })
        Column({ space: 12 }) {
          this.icon($r('app.media.ic_leaf'), 30)
          Text(this.exercise === 0 ? (this.seconds === 0 ? '谢谢你照顾自己' : !this.running ? '准备好，再开始' : (60 - this.seconds) % 10 < 4 ? '慢慢吸气' : '缓缓呼气') : ['看看周围', '感受支撑', '自然呼吸'][this.step])
            .fontSize(18).fontColor('#50664E')
          Text(this.exercise === 0 ? `${this.seconds} 秒` : `${this.step + 1} / 3`).fontSize(12).fontColor('#62765F')
        }
      }.margin({ top: 42, bottom: 35 })
      if (this.exercise === 1) {
        Text(['找一件让你觉得舒服的物品，\n留意它的颜色、形状和细节。', '把双脚轻轻放稳，\n感受地面与椅子给予的支撑。', '让呼吸回到自己的节奏。\n你可以停在这里，休息一会儿。'][this.step])
          .fontSize(15).fontColor(INK).lineHeight(28).textAlign(TextAlign.Center)
      }
      Blank()
      if (this.exercise === 0) {
        this.mainButton(this.running ? '暂停一下' : this.seconds === 0 ? '再给自己一分钟' : this.seconds < 60 ? '继续' : '开始一分钟', () => { this.toggleBreathing(); })
      } else {
        this.mainButton(this.step < 2 ? '慢慢来，下一步' : '完成，回到舒缓', () => { if (this.step < 2) this.step++; else this.exercise = -1; })
      }
      Text('感到不适时，请停止练习并自然呼吸。').fontSize(11).fontColor(MUTED).margin({ top: 19, bottom: 14 })
    }.width('100%').height('100%').padding(27).backgroundColor('#F4F5EB')
  }

  @Builder
  sanctuarySheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Image(this.scene === 1 ? $r('app.media.moon_garden') : this.scene === 2 ? $r('app.media.morning_garden') : $r('app.media.window_woman')).width('100%').height('100%').objectFit(ImageFit.Cover)
      Column() {
        Row() {
          Button() {
            Image($r('app.media.ic_back')).width(24).height(24).objectFit(ImageFit.Contain)
          }.width(44).height(44).borderRadius(22).backgroundColor('#EEFCF9F5')
            .accessibilityText('返回').onClick(() => { this.sanctuary = false; })
          Blank()
          Button(this.night ? '调亮一些' : '柔和一点').fontColor(INK).backgroundColor('#EEFCF9F5').onClick(() => { this.night = !this.night; })
        }.width('100%')
        Blank()
        Column({ space: 14 }) {
          Text('这里，不用回复任何人。').fontSize(24).fontColor(INK)
          Text('放松肩膀，找一个舒服的姿势。\n没有任务，也没有倒计时。').fontSize(14).fontColor(MUTED).lineHeight(26).textAlign(TextAlign.Center)
          Button('想跟着呼吸一会儿').fontColor(ROSE).backgroundColor('#F1E3E4').onClick(() => { this.sanctuary = false; this.startExercise(0); })
          Text('静谧插画空间 · 无音频播放').fontSize(10).fontColor(MUTED)
        }.width('100%').padding(24).backgroundColor('#F2FCF9F5').borderRadius(28)
      }.width('100%').height('100%').padding(24)
    }.width('100%').height('100%').brightness(this.night ? 0.75 : 1)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.tab === 0) { this.homePage() }
        else if (this.tab === 1) { this.companionPage() }
        else if (this.tab === 2) { this.soothePage() }
        else { this.journalPage() }
        this.navigation()
      }.width('100%').height('100%').backgroundColor(PAPER)
      if (this.sanctuary) { this.sanctuarySheet() }
      if (this.editor) { this.editorSheet() }
      if (this.exercise >= 0) { this.exerciseSheet() }
      if (this.notice) {
        Text(this.notice).fontSize(12).fontColor(Color.White).padding(15).backgroundColor('#493E3D').borderRadius(15)
          .margin({ left: 20, right: 20, bottom: 90 }).textAlign(TextAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
