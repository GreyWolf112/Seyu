import { INK, MUTED, ROSE, PAPER } from '../theme/Theme';

@Component
export struct DataManager {
  @Prop busy: boolean = false;
  @Prop blocked: boolean = false;
  @Prop ready: boolean = false;
  @Prop message: string = '';
  @Prop preview: string = '';
  @State eraseText: string = '';
  onClose: () => void = () => {};
  onExport: () => void = () => {};
  onImport: () => void = () => {};
  onRestore: () => void = () => {};
  onCancelPreview: () => void = () => {};
  onErase: () => void = () => {};
  onRetry: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('数据与备份').fontSize(23).fontColor(INK)
        Blank()
        Button('返回').fontColor(ROSE).backgroundColor(Color.Transparent).enabled(!this.busy && !this.blocked).onClick(this.onClose)
      }.width('100%')
      Scroll() {
        Column({ space: 20 }) {
          Text('你的记录，由你保管').fontSize(19).fontColor(INK)
          Text('记录保存在这台设备上。换手机或卸载前，可先导出一份备份。').fontSize(14).fontColor(MUTED).lineHeight(24)
          Column({ space: 12 }) {
            Text('保存一份本地备份').fontSize(17).fontColor(INK)
            Text('包含已保存记录、照片、书写草稿和心事整理草稿。备份文件未加密，请存放在你信任的位置；单个文件最多64MB，超限会提示，不会省略照片。')
              .fontSize(13).fontColor(MUTED).lineHeight(23)
            Button('选择位置并导出备份').width('100%').fontColor(Color.White).backgroundColor(ROSE)
              .enabled(this.ready && !this.busy && !this.blocked).onClick(this.onExport)
          }.padding(18).backgroundColor(Color.White).borderRadius(20).width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 12 }) {
            Text('从备份恢复').fontSize(17).fontColor(INK)
            Text('先校验并预览，再确认合并。同编号记录和已有草稿保留本机版本；重复导入不会重复新增记录。')
              .fontSize(13).fontColor(MUTED).lineHeight(23)
            Button('选择备份文件').width('100%').fontColor(ROSE).backgroundColor('#F0E4E2')
              .enabled(this.ready && !this.busy && !this.blocked).onClick(this.onImport)
            if (this.preview) {
              Text(this.preview).fontSize(14).fontColor(INK).lineHeight(25)
              Button('确认合并这份备份').width('100%').fontColor(Color.White).backgroundColor(ROSE)
                .enabled(!this.busy && !this.blocked).onClick(this.onRestore)
              Button('取消本次恢复').fontColor(ROSE).backgroundColor(Color.Transparent)
                .enabled(!this.busy && !this.blocked).onClick(this.onCancelPreview)
            }
          }.padding(18).backgroundColor(Color.White).borderRadius(20).width('100%').alignItems(HorizontalAlign.Start)
          if (this.message) { Text(this.message).fontSize(14).fontColor(INK).lineHeight(25).width('100%') }
          if (this.blocked) {
            Button('重试完成上次操作').width('100%').fontColor(Color.White).backgroundColor(ROSE)
              .enabled(!this.busy).onClick(this.onRetry)
          }
          Column({ space: 12 }) {
            Text('删除本机全部数据').fontSize(17).fontColor('#9A4444')
            Text('删除记录、收藏、瓶子、微光、两类草稿、应用内照片，以及旧版和内部恢复副本。无法撤销。相册原图和你导出的备份不会被删除。')
              .fontSize(13).fontColor(MUTED).lineHeight(23)
            TextInput({ text: this.eraseText, placeholder: '输入“删除全部”后继续' }).fontSize(14).maxLength(4)
              .enabled(!this.busy && !this.blocked).onChange((value: string) => { this.eraseText = value; })
            Button('删除本机全部数据').width('100%').fontColor('#9A4444').backgroundColor('#F7E7E4')
              .enabled(this.eraseText === '删除全部' && !this.busy && !this.blocked)
              .onClick(() => { this.eraseText = ''; this.onErase(); })
          }.padding(18).backgroundColor(Color.White).borderRadius(20).width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 28 })
      }.width('100%').layoutWeight(1)
    }.padding(24).width('100%').height('100%').backgroundColor(PAPER)
  }
}
