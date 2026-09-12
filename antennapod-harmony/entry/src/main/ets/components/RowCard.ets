import { DesignTokens } from '../common/DesignTokens';

/**
 * 通用卡片容器（HarmonyOS 卡片规范）：圆角 12vp、白/深色表面、
 * 默认 12vp 内边距；内容通过 @BuilderParam 注入，可配点击。
 */
@Component
export struct RowCard {
  @Prop bg: ResourceColor = $r('app.color.surface');
  @Prop pad: number = DesignTokens.SPACE_M;
  @Prop radius: number = DesignTokens.RADIUS_ROW;
  @Prop chevron: boolean = false;
  onTap: (() => void) | undefined = undefined;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
  }

  build() {
    Row() {
      Column() {
        this.content()
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.chevron) {
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(DesignTokens.ICON_M)
          .fontColor([$r('app.color.text_disabled')])
          .margin({ left: DesignTokens.SPACE_S })
      }
    }
    .width('100%')
    .padding(this.pad)
    .backgroundColor(this.bg)
    .borderRadius(this.radius)
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      if (this.onTap !== undefined) {
        this.onTap();
      }
    })
  }
}
