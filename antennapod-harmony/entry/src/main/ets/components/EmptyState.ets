import { DesignTokens } from '../common/DesignTokens';

/** 空状态占位（HarmonyOS 空状态规范）：图标 + 说明文字（+ 可选动作按钮），居中。 */
@Component
export struct EmptyState {
  @Prop icon: Resource = $r('sys.symbol.music');
  @Prop title: ResourceStr = '';
  @Prop sub: ResourceStr = '';
  /** 可选动作按钮文案（上游 EmptyViewHandler.setButtonText，如队列页的「Go to inbox」） */
  @Prop buttonLabel: ResourceStr = '';
  onButtonTap: () => void = () => {
  };

  build() {
    Column({ space: DesignTokens.SPACE_M }) {
      Stack() {
        SymbolGlyph(this.icon)
          .fontSize(DesignTokens.ICON_XXL + 20)
          .fontColor([$r('app.color.text_disabled')])
      }
      .width(96)
      .height(96)
      .borderRadius(48)
      .backgroundColor($r('app.color.surface_secondary'))
      .alignContent(Alignment.Center)

      Text(this.title)
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)

      if (this.sub !== '') {
        Text(this.sub)
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
          .maxLines(3)
      }

      // 上游是 Material3 OutlinedButton：描边 + 主色文字
      if (this.buttonLabel !== '') {
        Button(this.buttonLabel)
          .height(DesignTokens.HEIGHT_BUTTON)
          .padding({ left: DesignTokens.SPACE_XL, right: DesignTokens.SPACE_XL })
          .backgroundColor($r('app.color.surface'))
          .borderWidth(1)
          .borderColor($r('app.color.primary'))
          .fontColor($r('app.color.primary'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .margin({ top: DesignTokens.SPACE_S })
          .onClick(() => {
            this.onButtonTap();
          })
      }
    }
    .width('100%')
    .padding(DesignTokens.SPACE_XL)
  }
}
