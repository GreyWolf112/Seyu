import { INK, MUTED, ROSE } from '../theme/Theme';

@Builder
export function icon(source: Resource, size: number = 22) {
  Image(source).width(size).height(size).objectFit(ImageFit.Contain)
}

@Builder
export function titleBlock(eyebrow: string, title: string, subtitle: string) {
  Column({ space: 9 }) {
    Text(eyebrow).fontSize(11).fontColor(ROSE).letterSpacing(2)
    Text(title).fontSize(30).fontWeight(FontWeight.Medium).fontColor(INK)
    Text(subtitle).fontSize(13).fontColor(MUTED).lineHeight(22)
  }.alignItems(HorizontalAlign.Start).width('100%').margin({ top: 17, bottom: 26 })
}

@Builder
export function section(title: string, caption: string) {
  Row() {
    Text(title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(INK)
    Blank()
    Text(caption).fontSize(11).fontColor(MUTED)
  }.width('100%').margin({ top: 26, bottom: 16 })
}

@Builder
export function pill(text: string, selected: boolean, action: () => void) {
  Button(text).fontSize(12).fontWeight(FontWeight.Normal).fontColor(selected ? '#FFFFFF' : MUTED)
    .backgroundColor(selected ? ROSE : '#F1EAE4').height(36).padding({ left: 15, right: 15 })
    .borderRadius(18).onClick(action)
}

@Builder
export function mainButton(label: string, action: () => void) {
  Button(label).width('100%').height(48).fontSize(14).fontWeight(FontWeight.Medium)
    .fontColor(Color.White).backgroundColor(ROSE).borderRadius(16).onClick(action)
}

