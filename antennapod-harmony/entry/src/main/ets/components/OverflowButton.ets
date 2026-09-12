import { DesignTokens } from '../common/DesignTokens';

/**
 * 溢出菜单按钮：44vp 热区 + 图标，点击弹出 @BuilderParam 注入的菜单。
 * 注意：`bindMenu` 必须挂在**没有 onClick** 的容器上，否则内部 onClick 会吞掉点击
 * （挂在 AppIconButton 上实测弹不出菜单），故单独封装。
 */
@Component
export struct OverflowButton {
  @Prop symbol: Resource = $r('sys.symbol.ellipsis_circle');
  @Prop tint: ResourceColor = $r('app.color.text_secondary');
  @BuilderParam menu: () => void = this.emptyMenu;

  @Builder
  emptyMenu() {
  }

  build() {
    Stack() {
      SymbolGlyph(this.symbol)
        .fontSize(DesignTokens.ICON_L)
        .fontColor([this.tint])
    }
    .width(DesignTokens.HIT_MIN)
    .height(DesignTokens.HIT_MIN)
    .borderRadius(DesignTokens.HIT_MIN / 2)
    .alignContent(Alignment.Center)
    .bindMenu(this.menu)
  }
}
