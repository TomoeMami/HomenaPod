import { DesignTokens } from '../common/DesignTokens';

/** 筛选胶囊（HarmonyOS 分档按钮规范）：选中＝品牌色填充，未选中＝次级表面。 */
@Component
export struct TagChip {
  @Prop label: ResourceStr = '';
  @Prop selected: boolean = false;
  onTap: () => void = () => {
  };

  build() {
    Text(this.label)
      .fontSize(DesignTokens.FONT_FOOTNOTE)
      .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selected ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
      .backgroundColor(this.selected ? $r('app.color.primary') : $r('app.color.surface_secondary'))
      .padding({
        left: DesignTokens.SPACE_L,
        right: DesignTokens.SPACE_L,
        top: DesignTokens.SPACE_S,
        bottom: DesignTokens.SPACE_S
      })
      .borderRadius(DesignTokens.RADIUS_CHIP)
      .onClick(() => {
        this.onTap();
      })
  }
}
