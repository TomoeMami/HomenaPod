import { DesignTokens } from '../common/DesignTokens';

/**
 * 区块标题（对齐上游 `home_section.xml`）：
 * 标题 16fp Medium 占主位，右侧依次是可选「乱序」图标、可选数字胶囊（品牌色浅底填充 24vp）、
 * 可选「更多」链接（文案 + 尾随箭头）。
 */
@Component
export struct SectionHeader {
  @Prop title: ResourceStr = '';
  @Prop actionText: ResourceStr = '';
  @Prop countPill: number = -1;
  @Prop shuffle: boolean = false;
  onAction: () => void = () => {
  };
  onShuffle: () => void = () => {
  };

  build() {
    Row({ space: DesignTokens.SPACE_S }) {
      Text(this.title)
        .fontSize(DesignTokens.FONT_SECTION)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      if (this.shuffle) {
        SymbolGlyph($r('sys.symbol.shuffle'))
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([$r('app.color.text_primary')])
          .onClick(() => {
            this.onShuffle();
          })
      }

      if (this.countPill > 0) {
        // 计数胶囊：定高 24vp + 半径 12vp（恰为半高）。描边式胶囊在「圆角 > 高度一半」时
        // 描边路径会退化成鼓出的弧形（收件箱计数胶囊同款改法）。
        Text(this.countPill > 99 ? '99+' : this.countPill.toString())
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .height(24)
          .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S })
          .backgroundColor($r('app.color.primary_container'))
          .borderRadius(12)
      }

      if (this.actionText !== '') {
        Row({ space: DesignTokens.SPACE_XS }) {
          Text(this.actionText)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.primary'))
            .maxLines(1)
          SymbolGlyph($r('sys.symbol.chevron_forward'))
            .fontSize(DesignTokens.ICON_XL)
            .fontColor([$r('app.color.primary')])
        }
        // 几何对齐上游 home_section.xml 的 moreButton：
        // marginStart 16dp / marginEnd 8dp（由调用方的标题行右内边距承担）/ padding 12dp×8dp / 图标 24dp
        .padding({
          left: DesignTokens.SPACE_M,
          right: DesignTokens.SPACE_M,
          top: DesignTokens.SPACE_S,
          bottom: DesignTokens.SPACE_S
        })
        .margin({ left: DesignTokens.SPACE_L })
        .onClick(() => {
          this.onAction();
        })
      }
    }
    .width('100%')
    .padding({ top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_XS })
    .alignItems(VerticalAlign.Center)
  }
}
