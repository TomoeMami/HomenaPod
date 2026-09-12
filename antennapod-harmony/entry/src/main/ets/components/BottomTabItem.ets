import { DesignTokens } from '../common/DesignTokens';

/**
 * 底部导航项（对齐上游 BottomNavigationView：栏高 64vp、图标 24vp、文字 11fp）：
 * 选中态使用品牌色 + 填充图标 + 图标底胶囊（对应 Material3 的 active indicator）。
 */
@Component
export struct BottomTabItem {
  @Prop label: ResourceStr = '';
  @Prop icon: Resource = $r('sys.symbol.circle');
  @Prop iconActive: Resource = $r('sys.symbol.circle');
  @Prop selected: boolean = false;
  @Prop badge: number = -1;
  onTap: () => void = () => {
  };

  build() {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Stack() {
          SymbolGlyph(this.selected ? this.iconActive : this.icon)
            .fontSize(DesignTokens.ICON_XL)
            .fontColor([this.selected ? $r('app.color.primary') : $r('app.color.text_tertiary')])
        }
        .width(56)
        .height(30)
        .borderRadius(15)
        .backgroundColor(this.selected ? $r('app.color.primary_container') : Color.Transparent)
        .alignContent(Alignment.Center)

        if (this.badge > 0) {
          Text(this.badge > 99 ? '99+' : this.badge.toString())
            .fontSize(DesignTokens.FONT_OVERLINE)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.badge_bg'))
            .borderRadius(8)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .margin({ top: -2, right: -4 })
        }
      }
      .width(56)
      .height(30)

      Text(this.label)
        .fontSize(DesignTokens.FONT_NAV)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selected ? $r('app.color.primary') : $r('app.color.text_tertiary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(DesignTokens.HEIGHT_TAB_BAR)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onTap();
    })
  }
}
