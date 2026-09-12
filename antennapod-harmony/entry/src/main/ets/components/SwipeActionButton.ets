import { DesignTokens } from '../common/DesignTokens';
import { SwipeActionSpec, swipeActionWidth } from '../common/SwipeActions';

/**
 * 划出项按钮（`ListItem.swipeAction` 的动作区内容）：
 * 图标 + 文字竖排的整块彩色动作区，宽度固定（决定「完全划出」的距离）。
 * 破坏性动作（移出队列 / 移出收件箱 / 删除文件）用 error 配色，其余用品牌色。
 */
@Component
export struct SwipeActionButton {
  @Prop spec: SwipeActionSpec = { id: 'NONE', label: '', icon: $r('sys.symbol.circle') };
  @Prop destructive: boolean = false;
  onTap: () => void = () => {
  };

  build() {
    Column({ space: 2 }) {
      SymbolGlyph(this.spec.icon)
        .fontSize(DesignTokens.ICON_M)
        .fontColor([this.destructive ? $r('app.color.error') : $r('app.color.on_primary')])
      Text(this.spec.label)
        .fontSize(DesignTokens.FONT_CAPTION)
        .fontColor(this.destructive ? $r('app.color.error') : $r('app.color.on_primary'))
        .maxLines(1)
    }
    .width(swipeActionWidth())
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.destructive ? $r('app.color.error_container') : $r('app.color.primary'))
    .borderRadius(DesignTokens.RADIUS_ROW)
    .onClick(() => {
      this.onTap();
    })
  }
}
