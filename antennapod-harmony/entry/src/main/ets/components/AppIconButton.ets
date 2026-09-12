import { DesignTokens } from '../common/DesignTokens';

/**
 * 圆形图标按钮（HarmonyOS 图标按钮规范）：
 * 44vp 触控热区、图标 22vp、可选右上角数字角标。
 */
@Component
export struct AppIconButton {
  @Prop symbol: Resource = $r('sys.symbol.checkmark');
  @Prop tint: ResourceColor = $r('app.color.text_secondary');
  @Prop bg: ResourceColor = Color.Transparent;
  @Prop badge: number = -1;
  @Prop badgeShow: boolean = false;
  onTap: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.End }) {
      Stack() {
        SymbolGlyph(this.symbol)
          .fontSize(DesignTokens.ICON_L)
          .fontColor([this.tint])
      }
      .width(DesignTokens.HIT_MIN)
      .height(DesignTokens.HIT_MIN)
      .borderRadius(DesignTokens.HIT_MIN / 2)
      .backgroundColor(this.bg)
      .alignContent(Alignment.Center)
      .onClick(() => {
        this.onTap();
      })

      if (this.badgeShow && this.badge > 0) {
        Text(this.badge > 99 ? '99+' : this.badge.toString())
          .fontSize(DesignTokens.FONT_OVERLINE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.badge_bg'))
          .borderRadius(8)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .margin({ top: 2, right: 2 })
      }
    }
    .width(DesignTokens.HIT_MIN + 6)
    .height(DesignTokens.HIT_MIN + 6)
  }
}
