import { DataManager } from '../components/DataManager';
import { DataMaintenance } from '../storage/DataMaintenance';
import { BackupFiles } from '../storage/BackupFiles';
import { LocalBackup } from '../storage/BackupCodec';
import { AmbientPanel } from '../components/AmbientPanel';
import { SleepFlow } from '../components/SleepFlow';
import { BreathingClock } from '../models/Relaxation';
import { newJoy, templateRecord } from '../models/WritingTemplates';
import { newReflection, reflectionScene } from '../models/ReflectionModel';
import { ReflectionFlow } from '../components/ReflectionFlow';
import { EmotionRecord } from '../models/Record';
import { newJournal } from '../models/EditorModel';
import { DraftRepository } from '../storage/DraftRepository';
import { PhotoStore } from '../storage/PhotoStore';
import { RecordEditor } from '../components/RecordEditor';
import { RecordRepository } from '../storage/RecordRepository';
import { PreferencesRecordStore } from '../storage/PreferencesRecordStore';
import { preferences } from '@kit.ArkData';
import { Joy } from '../models/LegacyModels';
import { INK, MUTED, ROSE, PAPER } from '../theme/Theme';
import { icon, mainButton } from '../components/Common';
import { HomePage } from './HomePage';
import { CompanionPage } from './CompanionPage';
import { SoothePage } from './SoothePage';
import { JournalPage } from './JournalPage';

@Entry
@Component
struct Index {
  @State storageInitializing: boolean = false;
  @State dataOpen: boolean = false;
  @State dataBusy: boolean = false;
  @State maintenanceBlocked: boolean = false;
  @State dataMessage: string = '';
  @State backupPreview: string = '';
  private pendingBackup: LocalBackup | undefined = undefined;
  private dataMaintenance: DataMaintenance | undefined = undefined;
  private backupFiles: BackupFiles | undefined = undefined;
  @StorageLink('zhiyuForeground') @Watch('foregroundChanged') foreground: boolean = true;
  @State sleepOpen: boolean = false;
  @State breathingDuration: number = 60;
  private breathingClock: BreathingClock = new BreathingClock();
  private foregroundChanged(): void { if (!this.foreground) this.stopTimer(); }
  @State savedRecordId: string = '';
  @State bottlePlaced: boolean = false;
  @State markingBottle: boolean = false;
  @State favoriteBusy: boolean = false;
  @State reflectionOpen: boolean = false;
  @State reflectionPending: boolean = false;
  @State reflectionSeed: EmotionRecord = newReflection('words');
  private reflectionDrafts: DraftRepository | undefined = undefined;
  @State tab: number = 0;
  @State sanctuary: boolean = false;
  @State night: boolean = false;
  @State scene: number = 0;
  @State journalView: number = 0;
  @State search: string = '';
  @State monthOffset: number = 0;
  @State mood: string = '';
  @State joys: Joy[] = [];
  @State presetJoys: Joy[] = [];
  @State savingJoy: boolean = false;
  @State filter: number = 0;
  @State entries: EmotionRecord[] = [];
  @State selectedDate: string = '';
  @State editor: boolean = false;
  @State exercise: number = -1;
  @State seconds: number = 60;
  @State running: boolean = false;
  @State step: number = 0;
  @State notice: string = '';
  private timer: number = -1;
  private noticeTimer: number = -1;
  private repository: RecordRepository | undefined = undefined;
  @State storageReady: boolean = false;
  @State quickSaving: boolean = false;
  @State editorSeed: EmotionRecord = newJournal();
  @State filesDir: string = '';
  private drafts: DraftRepository | undefined = undefined;
  private media: PhotoStore | undefined = undefined;
  private tabs: string[] = ['此刻', '心事', '放松', '我的记录'];
  private icons: Resource[] = [$r('app.media.ic_home'), $r('app.media.ic_chat'), $r('app.media.ic_leaf'), $r('app.media.ic_book')];

  private dateKey(date: Date): string {
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  aboutToAppear(): void {
    this.selectedDate = this.dateKey(new Date());
    this.initializeStorage();
  }

  private async initializeStorage(): Promise<void> {
    this.storageInitializing = true;
    this.storageReady = false;
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) throw new Error('Missing context');
      const store = new PreferencesRecordStore(preferences.getPreferencesSync(context, { name: 'zhiyu_journal' }));
      const journalStore = new PreferencesRecordStore(preferences.getPreferencesSync(context, { name: 'zhiyu_editor_drafts' }));
      const reflectionStore = new PreferencesRecordStore(preferences.getPreferencesSync(context, { name: 'zhiyu_reflection_drafts' }));
      this.backupFiles = new BackupFiles(context);
      this.dataMaintenance = new DataMaintenance(store, journalStore, reflectionStore, this.backupFiles);
      // Finish a durable import/delete before loading records or deleting unused photos.
      await this.dataMaintenance.recover();
      this.maintenanceBlocked = false;
      const repository = new RecordRepository(store);
      this.repository = repository;
      await repository.initialize();
      this.filesDir = context.filesDir;
      this.media = new PhotoStore(context.filesDir);
      this.drafts = new DraftRepository(journalStore);
      this.reflectionDrafts = new DraftRepository(reflectionStore);
      this.refreshReflectionPending();
      this.refreshRecords();
      // A corrupt draft or recovery copy disables cleanup, never destroys its potential photos.
      try {
        const references = repository.photoReferences();
        const reflectionDraft = this.reflectionDrafts.load();
        reflectionDraft?.photos.forEach((photo) => { references.push(photo.relativePath); });
        const draft = this.drafts.load();
        draft?.photos.forEach((photo) => { references.push(photo.relativePath); });
        await this.media.collectUnused(references);
      } catch (_) {}
      this.storageReady = true;
    } catch (_) {
      this.maintenanceBlocked = this.hasPendingMaintenance();
      if (this.maintenanceBlocked) {
        this.dataOpen = true;
        this.dataMessage = '上次数据操作尚未完成，请重试；完成前暂不开放记录编辑。';
      } else this.flash('记录暂不可用，请重新打开应用重试。');
    } finally { this.storageInitializing = false; }
  }

  private hasPendingMaintenance(): boolean {
    try { return this.dataMaintenance?.isPending() || false; }
    catch (_) { return true; }
  }

  private openDataManager(): void {
    if (this.storageInitializing || this.quickSaving || this.savingJoy || this.favoriteBusy || this.markingBottle) {
      this.flash('请等当前保存完成后再打开数据管理'); return;
    }
    this.dataMessage = ''; this.clearBackupPreview(); this.dataOpen = true;
  }

  private clearBackupPreview(): void { this.pendingBackup = undefined; this.backupPreview = ''; }

  private async exportBackup(): Promise<void> {
    if (this.dataBusy || !this.storageReady || !this.dataMaintenance || !this.backupFiles) return;
    this.dataBusy = true; this.dataMessage = '正在整理记录、草稿和照片…';
    try {
      const raw = await this.dataMaintenance.createBackup();
      this.dataMessage = await this.backupFiles.save(raw) ? '备份已导出到你选择的位置，请妥善保管。' : '已取消导出，没有生成备份。';
    } catch (_) { this.dataMessage = '备份未完成。请检查照片是否可读、存储空间及64MB大小限制；若目标位置留下不完整文件，请删除后重试。'; }
    finally { this.dataBusy = false; }
  }

  private async chooseBackup(): Promise<void> {
    if (this.dataBusy || !this.storageReady || !this.dataMaintenance || !this.backupFiles) return;
    this.dataBusy = true; this.clearBackupPreview(); this.dataMessage = '请选择备份，随后会校验内容和照片…';
    try {
      const raw = await this.backupFiles.select();
      if (raw === null) { this.dataMessage = '已取消选择，本机数据没有改变。'; return; }
      const backup = await this.dataMaintenance.inspect(raw);
      const summary = this.dataMaintenance.summarize(backup);
      this.pendingBackup = backup;
      this.backupPreview = `备份时间：${new Date(backup.createdAt).toLocaleString()}\n包含 ${backup.document.records.length} 条记录、${backup.photos.length} 张照片\n将新增 ${summary.added} 条记录；${summary.kept} 条同编号记录保留本机版本\n将恢复 ${summary.draftsAdded} 份草稿；${summary.draftsKept} 份已有草稿保留本机版本`;
      this.dataMessage = '校验通过，确认后才会写入本机。';
    } catch (_) { this.dataMessage = '文件未通过校验，或无法读取。请选择64MB以内的知屿备份；本机数据没有改变。'; }
    finally { this.dataBusy = false; }
  }

  private confirmRestore(): void {
    if (this.dataBusy || !this.pendingBackup) return;
    this.getUIContext().showAlertDialog({ title: '合并这份备份？',
      message: '新增备份里的记录；同编号记录和已有草稿保留本机版本。合并期间请等待完成。',
      primaryButton: { value: '先不恢复', action: () => {} },
      secondaryButton: { value: '确认合并', action: () => { this.restoreBackup(); } } });
  }

  private async restoreBackup(): Promise<void> {
    if (this.dataBusy || !this.storageReady || !this.pendingBackup || !this.dataMaintenance) return;
    this.dataBusy = true; this.storageReady = false; this.dataMessage = '正在导入照片并合并记录…';
    try {
      await this.dataMaintenance.restore(this.pendingBackup);
      await this.reloadAfterMaintenance();
      this.clearBackupPreview(); this.dataMessage = '备份已合并，记录和可恢复的草稿已保存到本机。';
    } catch (_) { await this.maintenanceFailed(); }
    finally { this.dataBusy = false; }
  }

  private confirmErase(): void {
    if (this.dataBusy || this.maintenanceBlocked) return;
    this.getUIContext().showAlertDialog({ title: '确定删除本机全部数据？',
      message: '记录、草稿、应用内照片及旧版和内部恢复副本都会删除，无法撤销。已导出的备份和相册原图不会删除。',
      primaryButton: { value: '保留数据', action: () => {} },
      secondaryButton: { value: '确认全部删除', action: () => { this.eraseData(); } } });
  }

  private async eraseData(): Promise<void> {
    if (this.dataBusy || !this.dataMaintenance) return;
    this.clearBackupPreview();
    this.dataBusy = true; this.storageReady = false; this.dataMessage = '正在删除本机数据与应用内照片…';
    try {
      await this.dataMaintenance.erase();
      this.clearRecordViews();
      await this.reloadAfterMaintenance();
      this.clearBackupPreview(); this.editorSeed = newJournal(); this.reflectionSeed = newReflection('words');
      this.mood = ''; this.savedRecordId = ''; this.search = ''; this.selectedDate = '';
      this.dataMessage = '本机记录、草稿、应用内照片及内部副本已删除。你导出的备份仍由你自行保管。';
    } catch (_) { await this.maintenanceFailed(); }
    finally { this.dataBusy = false; }
  }

  private clearRecordViews(): void {
    this.entries = []; this.joys = []; this.presetJoys = []; this.reflectionPending = false;
    this.editorSeed = newJournal(); this.reflectionSeed = newReflection('words');
    this.mood = ''; this.savedRecordId = ''; this.search = ''; this.selectedDate = '';
  }

  private async reloadAfterMaintenance(): Promise<void> {
    // Recreate adapters as well, including when startup previously stopped during recovery.
    await this.initializeStorage();
    if (!this.storageReady) throw new Error('Reload failed');
    this.maintenanceBlocked = false;
  }

  private async maintenanceFailed(): Promise<void> {
    this.maintenanceBlocked = this.hasPendingMaintenance();
    if (this.maintenanceBlocked) {
      this.storageReady = false;
      this.dataMessage = '操作尚未完成，暂不开放编辑。请点“重试完成上次操作”；重新打开应用也会继续完成。';
    } else {
      await this.initializeStorage();
      this.dataMessage = this.storageReady ? '操作未能确认完成，已重新载入本机现有记录。请核对后重试。' : '操作未完成，请重新打开应用检查后重试。';
    }
  }

  private async retryMaintenance(): Promise<void> {
    if (this.dataBusy || !this.dataMaintenance) return;
    this.dataBusy = true; this.dataMessage = '正在继续完成上次数据操作…';
    try {
      await this.dataMaintenance.recover();
      this.clearRecordViews();
      await this.reloadAfterMaintenance(); this.clearBackupPreview();
      this.editorSeed = newJournal(); this.reflectionSeed = newReflection('words');
      this.dataMessage = '上次数据操作已完成，可以继续使用。';
    } catch (_) { await this.maintenanceFailed(); }
    finally { this.dataBusy = false; }
  }

  private refreshRecords(): void {
    if (!this.repository) return;
    this.entries = this.repository.timeline();
    this.joys = this.repository.joys();
    this.presetJoys = this.repository.presetJoys();
  }

  aboutToDisappear(): void {
    this.stopTimer();
    if (this.noticeTimer !== -1) clearTimeout(this.noticeTimer);
  }

  private flash(text: string): void {
    if (this.noticeTimer !== -1) clearTimeout(this.noticeTimer);
    this.notice = text;
    this.noticeTimer = setTimeout(() => { this.notice = ''; }, 2800);
  }

  private refreshReflectionPending(): void {
    try { this.reflectionPending = this.reflectionDrafts?.load() !== undefined; }
    catch (_) { this.reflectionPending = true; }
  }

  private startReflection(id: string): void { this.requestReflection(newReflection(id)); }

  private resumeReflection(): void {
    if (!this.storageReady) { this.flash('记录尚未准备好'); return; }
    try {
      const draft = this.reflectionDrafts?.load();
      if (!draft?.reflection) { this.refreshReflectionPending(); return; }
      reflectionScene(draft.reflection.sceneId);
      this.reflectionSeed = draft;
      this.reflectionOpen = true;
    } catch (_) { this.flash('整理草稿暂不可用，原内容已保留'); }
  }

  private requestReflection(seed: EmotionRecord): void {
    if (!this.storageReady || !this.reflectionDrafts) { this.flash('记录尚未准备好'); return; }
    try {
      reflectionScene(seed.reflection?.sceneId || '');
      const draft = this.reflectionDrafts.load();
      if (draft) {
        this.getUIContext().showAlertDialog({ title: '还有一份心事整理未完成', message: '继续原进度，或明确舍弃后打开本次整理。',
          primaryButton: { value: '继续原进度', action: () => { this.resumeReflection(); } },
          secondaryButton: { value: '舍弃并打开', action: () => { this.replaceReflection(seed); } } });
      } else { this.reflectionSeed = seed; this.reflectionOpen = true; }
    } catch (_) { this.flash('整理内容暂不可用，原数据已保留'); }
  }

  private async replaceReflection(seed: EmotionRecord): Promise<void> {
    try {
      if (!this.reflectionDrafts) throw new Error('No draft store');
      await this.reflectionDrafts.clear();
      this.reflectionSeed = seed; this.reflectionOpen = true;
      this.refreshReflectionPending();
    } catch (_) { this.flash('草稿未清除，请重试'); }
  }

  private async saveReflection(record: EmotionRecord): Promise<void> {
    if (!this.repository || !this.storageReady) throw new Error('No record store');
    await this.repository.upsert(record);
    this.refreshRecords(); this.selectedDate = record.date; this.tab = 3;
    let message: string = '整理卡已保存，随时可以回来修改';
    try { await this.reflectionDrafts?.clear(); }
    catch (_) { message = '整理卡已保存，草稿清理未完成；重存不会重复新增'; }
    this.reflectionOpen = false; this.refreshReflectionPending(); this.flash(message);
    this.showBottleRitual(record.id);
  }

  private showBottleRitual(id: string): void {
    const record = this.entries.find((item: EmotionRecord) => item.id === id);
    if (!record) return;
    this.savedRecordId = id;
    this.bottlePlaced = record.bottled === true || record.kind === 'bottle';
  }

  private async markBottle(): Promise<void> {
    if (this.markingBottle || this.bottlePlaced) return;
    this.markingBottle = true;
    try {
      if (!this.repository) throw new Error('No record store');
      await this.repository.putInBottle(this.savedRecordId);
      this.refreshRecords(); this.bottlePlaced = true;
    } catch (_) { this.flash('暂未装进瓶子，原记录仍然保留'); }
    finally { this.markingBottle = false; }
  }

  private async toggleFavorite(id: string): Promise<void> {
    if (this.favoriteBusy || !this.repository) return;
    const record = this.entries.find((item: EmotionRecord) => item.id === id);
    if (!record) return;
    this.favoriteBusy = true;
    try {
      await this.repository.setFavorite(id, !record.favorite);
      this.refreshRecords();
      this.flash(record.favorite ? '已取消收藏' : '已收藏，可在“收藏”中找回');
    } catch (_) { this.flash('收藏未更新，请重试'); }
    finally { this.favoriteBusy = false; }
  }

  private openEditor(text: string = ''): void {
    this.requestEditor(newJournal(text, this.mood));
  }

  private editRecord(id: string): void {
    const record = this.entries.find((item: EmotionRecord) => item.id === id);
    if (record?.kind === 'reflection') this.requestReflection(record);
    else if (record) this.requestEditor(record);
  }

  private requestEditor(seed: EmotionRecord): void {
    if (!this.storageReady || !this.drafts) { this.flash('记录尚未准备好，请稍后重试'); return; }
    try {
      const draft = this.drafts.load();
      if (draft) {
        this.getUIContext().showAlertDialog({
          title: '还有一份未完成的草稿', message: '可以继续上次的内容，或舍弃草稿后打开这次记录。',
          primaryButton: { value: '继续草稿', action: () => { this.editorSeed = draft; this.editor = true; } },
          secondaryButton: { value: '舍弃并打开', action: () => { this.replaceDraft(seed); } }
        });
      } else { this.editorSeed = seed; this.editor = true; }
    } catch (_) { this.flash('草稿暂时无法读取，已保留原数据，请稍后重试'); }
  }

  private async replaceDraft(seed: EmotionRecord): Promise<void> {
    try {
      if (!this.drafts) throw new Error('No draft store');
      await this.drafts.clear();
      this.editorSeed = seed;
      this.editor = true;
    } catch (_) { this.flash('草稿未清除成功，请重试'); }
  }

  private async saveRecord(record: EmotionRecord): Promise<void> {
    if (!this.repository || !this.storageReady) throw new Error('No record store');
    await this.repository.upsert(record);
    this.refreshRecords();
    this.selectedDate = record.date;
    this.tab = 3;
    try { await this.drafts?.clear(); }
    catch (_) {
      this.editor = false;
      this.flash('记录已保存；草稿未清理，重复保存不会新增记录');
      return;
    }
    this.editor = false;
    this.flash('已保存在这台设备上');
    this.showBottleRitual(record.id);
  }

  private async saveQuickMood(): Promise<void> {
    if (this.quickSaving || !this.mood) return;
    this.quickSaving = true;
    try {
      if (!this.repository || !this.storageReady) throw new Error('No record store');
      const record = newJournal('', this.mood);
      record.kind = 'mood';
      await this.repository.upsert(record);
      this.refreshRecords();
      this.flash('此刻的心情已留下，可在我的记录中查看');
      this.mood = '';
    } catch (_) { this.flash('心情未保存成功，请重试'); }
    finally { this.quickSaving = false; }
  }

  onBackPress(): boolean {
    if (this.dataOpen) {
      if (!this.dataBusy && !this.storageInitializing && !this.maintenanceBlocked) this.dataOpen = false;
      else this.flash('请等待数据操作完成；未完成时可重试');
      return true;
    }
    if (this.sleepOpen) { this.sleepOpen = false; return true; }
    if (this.savedRecordId) { if (!this.markingBottle) this.savedRecordId = ''; return true; }
    if (this.reflectionOpen) { this.flash('请点“暂存离开”保留进度后返回'); return true; }
    if (this.editor) { this.flash('请点“稍后继续”保存草稿后离开'); return true; }
    if (this.exercise >= 0) { this.stopTimer(); this.exercise = -1; return true; }
    if (this.sanctuary) { this.sanctuary = false; return true; }
    return false;
  }

  private deleteNote(id: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除这篇手记？', message: '删除后无法恢复。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.removeNote(id); } }
    });
  }

  private async removeNote(id: string): Promise<void> {
    try {
      if (!this.storageReady || !this.repository) throw new Error('storage');
      await this.repository.removeById(id);
      this.refreshRecords();
      this.flash('手记已删除');
    } catch (_) { this.flash('删除未完成，请重试'); }
  }

  private async recordJoy(title: string): Promise<void> {
    if (this.savingJoy) return;
    const today: string = this.dateKey(new Date());
    const existing: Joy | undefined = this.presetJoys.find((item: Joy) => item.date === today && item.title === title);
    const exists: boolean = existing !== undefined;
    this.savingJoy = true;
    try {
      if (!this.storageReady || !this.repository) throw new Error('storage');
      if (existing) await this.repository.remove('joy', existing.id);
      else await this.repository.save('joy', Date.now().toString(), today, '', '', title);
      this.refreshRecords();
      this.flash(exists ? '已取消这次记录' : '今天的这一点微光，留下了');
    } catch (_) { this.flash('保存未完成，请重试'); }
    finally { this.savingJoy = false; }
  }

  private stopTimer(): void {
    if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1; }
    this.breathingClock.pause(Date.now());
    this.seconds = this.breathingClock.seconds(Date.now());
    this.running = false;
  }

  private selectDuration(value: number): void {
    this.stopTimer();
    this.breathingDuration = value;
    this.breathingClock.select(value);
    this.seconds = value;
  }

  private startExercise(kind: number): void {
    this.stopTimer();
    this.selectDuration(this.breathingDuration);
    this.step = 0;
    this.exercise = kind;
  }

  private toggleBreathing(): void {
    if (this.running) { this.stopTimer(); return; }
    if (!this.foreground) return;
    this.breathingClock.start(Date.now());
    this.seconds = this.breathingClock.seconds(Date.now());
    this.running = true;
    this.timer = setInterval(() => {
      this.seconds = this.breathingClock.seconds(Date.now());
      if (this.seconds === 0) this.stopTimer();
    }, 250);
  }

  @Builder
  navigation() {
    Row() {
      ForEach(this.tabs, (label: string, index: number) => {
        Column({ space: 5 }) {
          Stack() {
            if (this.tab === index) { Rect().width(45).height(29).fill('#EEDDD8').radius(13) }
            icon(this.icons[index], 21)
          }.height(30)
          Text(label).fontSize(10).fontColor(this.tab === index ? ROSE : MUTED).fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Normal)
        }.layoutWeight(1).padding({ top: 9, bottom: 10 }).onClick(() => { this.tab = index; })
          .id(`tab-${index}`).accessibilityText(label + (this.tab === index ? '，当前页面' : ''))
      })
    }.width('100%').backgroundColor('#FCF9F5').border({ width: { top: 1 }, color: '#EDE5DD' })
  }

  @Builder
  exerciseSheet() {
    Scroll() {
    Column() {
      Row() {
        Text('给自己一点时间').fontSize(13).fontColor(MUTED)
        Blank()
        Button('结束').fontSize(13).fontColor(INK).backgroundColor(Color.Transparent).onClick(() => { this.stopTimer(); this.exercise = -1; })
      }.width('100%')
      Blank()
      Text(this.exercise === 0 ? '跟着呼吸，回到此刻' : '轻轻地，回到身体').fontSize(25).fontColor(INK)
      Text(this.exercise === 0 ? '保持舒服的节奏，不必勉强跟随。' : '用一点点感官，感受当下的自己。').fontSize(12).fontColor(MUTED).margin({ top: 15 })
      if (this.exercise === 0) {
        Row({ space: 12 }) {
          ForEach([60, 180], (value: number) => {
            Button(`${value / 60}分钟`).fontColor(this.breathingDuration === value ? Color.White : ROSE)
              .backgroundColor(this.breathingDuration === value ? ROSE : '#EEE5DC').enabled(!this.running)
              .onClick(() => { this.selectDuration(value); })
          })
        }.margin({ top: 18 })
        Text('暂停后可切换时长，切换会重新开始').fontSize(10).fontColor(MUTED).margin({ top: 8 })
      }
      Stack() {
        Circle().width(242).height(242).fill('#E4EADC')
        Circle().width(205).height(205).fill('#D7E1CD')
          .scale({ x: this.running && (this.breathingDuration - this.seconds) % 10 < 4 ? 1.1 : 0.88, y: this.running && (this.breathingDuration - this.seconds) % 10 < 4 ? 1.1 : 0.88 })
          .animation({ duration: 1400, curve: Curve.EaseInOut })
        Column({ space: 12 }) {
          icon($r('app.media.ic_leaf'), 30)
          Text(this.exercise === 0 ? (this.seconds === 0 ? '谢谢你照顾自己' : !this.running ? '准备好，再开始' : (this.breathingDuration - this.seconds) % 10 < 4 ? '慢慢吸气' : '缓缓呼气') : ['看看周围', '感受支撑', '自然呼吸'][this.step])
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
        mainButton(this.running ? '暂停一下' : this.seconds === 0 ? '再练习一次' : this.seconds < this.breathingDuration ? '继续' : `开始${this.breathingDuration / 60}分钟`, () => { this.toggleBreathing(); })
      } else {
        mainButton(this.step < 2 ? '慢慢来，下一步' : '完成，回到放松', () => { if (this.step < 2) this.step++; else this.exercise = -1; })
      }
      Text('感到不适时，请停止练习并自然呼吸。').fontSize(11).fontColor(MUTED).margin({ top: 19, bottom: 14 })
    }.width('100%').constraintSize({ minHeight: '100%' }).padding(27).backgroundColor('#F4F5EB')
    }.width('100%').height('100%').backgroundColor('#F4F5EB').scrollBar(BarState.Off)
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
        Scroll() {
        Column({ space: 14 }) {
          Text('这里，不用回复任何人。').fontSize(24).fontColor(INK)
          Text('放松肩膀，找一个舒服的姿势。\n可以安静待着，也可以选一段声音。').fontSize(14).fontColor(MUTED).lineHeight(26).textAlign(TextAlign.Center)
          Button('想跟着呼吸一会儿').fontColor(ROSE).backgroundColor('#F1E3E4').onClick(() => { this.sanctuary = false; this.startExercise(0); })
          AmbientPanel()
        }.width('100%').padding(18).backgroundColor('#F2FCF9F5').borderRadius(28)
        }.layoutWeight(1).width('100%').margin({ top: 20 })
      }.width('100%').height('100%').padding(24)
    }.width('100%').height('100%').brightness(this.night ? 0.75 : 1)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (!this.storageReady) {
          Text('记录正在准备；若长时间未显示，请重新打开应用。原数据会保留。')
            .fontSize(12).fontColor(MUTED).padding(12).width('100%')
        }
        if (this.tab === 0) { HomePage({
          quickSaving: this.quickSaving,
          saveQuickMood: () => { this.saveQuickMood(); },
          tab: this.tab,
          mood: this.mood,
          entries: this.entries,
          reflectionPending: this.reflectionPending,
          resumeReflection: () => { this.resumeReflection(); },
          editRecord: (id: string) => { this.editRecord(id); },
          openEditor: (text: string = '') => { this.openEditor(text); }
        }).layoutWeight(1) }
        else if (this.tab === 1) { CompanionPage({
          reflectionPending: this.reflectionPending,
          startReflection: (id: string) => { this.startReflection(id); },
          resumeReflection: () => { this.resumeReflection(); },
          openEditor: (text: string = '') => { this.openEditor(text); },
          openTemplate: (id: string) => { this.requestEditor(templateRecord(id)); }
        }).layoutWeight(1) }
        else if (this.tab === 2) { SoothePage({
          startSleep: () => { this.sleepOpen = true; },
          sanctuary: this.sanctuary,
          scene: this.scene,
          joys: this.presetJoys,
          filter: this.filter,
          openEditor: (text: string = '') => { this.openEditor(text); },
          startExercise: (kind: number) => { this.startExercise(kind); },
          openJoy: () => { this.requestEditor(newJoy()); },
          recordJoy: (title: string) => { this.recordJoy(title); }
        }).layoutWeight(1) }
        else { JournalPage({
          openDataManager: () => { this.openDataManager(); },
          journalView: this.journalView,
          search: this.search,
          monthOffset: this.monthOffset,
          joys: this.joys,
          entries: this.entries,
          selectedDate: this.selectedDate,
          filesDir: this.filesDir,
          favoriteBusy: this.favoriteBusy,
          toggleFavorite: (id: string) => { this.toggleFavorite(id); },
          openJoy: () => { this.requestEditor(newJoy()); },
          putInBottle: (id: string) => { this.showBottleRitual(id); },
          editRecord: (id: string) => { this.editRecord(id); },
          openEditor: (text: string = '') => { this.openEditor(text); },
          deleteNote: (id: string) => { this.deleteNote(id); }
        }).layoutWeight(1) }
        this.navigation()
      }.width('100%').height('100%').backgroundColor(PAPER)
      if (this.sanctuary) { this.sanctuarySheet() }
      if (this.editor) {
        RecordEditor({ seed: this.editorSeed, drafts: this.drafts, media: this.media, filesDir: this.filesDir,
          onSave: async (record: EmotionRecord) => { await this.saveRecord(record); },
          onClose: () => { this.editor = false; } })
      }
      if (this.reflectionOpen) {
        ReflectionFlow({ seed: this.reflectionSeed, drafts: this.reflectionDrafts,
          onSave: async (record: EmotionRecord) => { await this.saveReflection(record); },
          onClose: () => { this.reflectionOpen = false; this.refreshReflectionPending(); },
          onRelax: () => { this.reflectionOpen = false; this.refreshReflectionPending(); this.tab = 2; } })
      }
      if (this.exercise >= 0) { this.exerciseSheet() }
      if (this.sleepOpen) {
        SleepFlow({ onClose: () => { this.sleepOpen = false; },
          onAmbient: () => { this.sleepOpen = false; this.scene = 1; this.sanctuary = true; } })
      }
      if (this.savedRecordId) {
        Column({ space: 14 }) {
          Text(this.bottlePlaced ? '这份心事，已经靠岸。' : '记录已保存，想给它一个小仪式吗？').fontSize(20).fontColor(INK)
          Image($r('app.media.bottle_sea')).width('100%').height(150).objectFit(ImageFit.Cover).borderRadius(20)
            .translate({ x: this.bottlePlaced ? 15 : 0 }).opacity(this.bottlePlaced ? 0.65 : 1)
            .animation({ duration: 900, curve: Curve.EaseInOut })
          Text('私人瓶子关联原记录，不会复制内容，也不会发送给其他人。').fontSize(12).fontColor(MUTED).lineHeight(22)
          if (!this.bottlePlaced) {
            Button(this.markingBottle ? '正在收好…' : '装进瓶子，轻轻放漂').width('100%').backgroundColor(ROSE).fontColor(Color.White)
              .enabled(!this.markingBottle).onClick(() => { this.markBottle(); })
          }
          Button(this.bottlePlaced ? '收好，回到记录' : '留在这里就好').fontColor(ROSE).backgroundColor(Color.Transparent)
            .enabled(!this.markingBottle).onClick(() => { this.savedRecordId = ''; })
        }.padding(26).width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor(PAPER)
      }
      if (this.dataOpen) {
        DataManager({ busy: this.dataBusy || this.storageInitializing, blocked: this.maintenanceBlocked, ready: this.storageReady,
          message: this.dataMessage, preview: this.backupPreview,
          onClose: () => { this.clearBackupPreview(); this.dataOpen = false; },
          onExport: () => { this.exportBackup(); }, onImport: () => { this.chooseBackup(); },
          onRestore: () => { this.confirmRestore(); }, onCancelPreview: () => { this.clearBackupPreview(); },
          onErase: () => { this.confirmErase(); }, onRetry: () => { this.retryMaintenance(); } })
      }
      if (this.notice) {
        Text(this.notice).fontSize(12).fontColor(Color.White).padding(15).backgroundColor('#493E3D').borderRadius(15)
          .margin({ left: 20, right: 20, bottom: 90 }).textAlign(TextAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
