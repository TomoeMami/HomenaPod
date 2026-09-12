/**
 * HomenaPod 设计令牌（HarmonyOS 官方设计规范落地）：
 * 间距 8vp 网格、字阶（fp）、圆角、组件尺寸集中在此；颜色走资源（base/dark 自适应）。
 * 参考：HarmonyOS 设计指南《视觉风格》《应用布局》《字阶》规范。
 */
export class DesignTokens {
  /** 页面左右安全边距（手机 16vp） */
  static readonly PAGE_MARGIN: number = 16;
  /** 卡片圆角：列表行 12，大卡 16，弹层顶角 24 */
  static readonly RADIUS_ROW: number = 12;
  static readonly RADIUS_CARD: number = 16;
  static readonly RADIUS_SHEET: number = 24;
  static readonly RADIUS_BUTTON: number = 22;
  static readonly RADIUS_CHIP: number = 16;
  /** 高度（上游 AntennaPod：标题栏 56dp、底部导航 64dp、按钮 40dp） */
  static readonly HEIGHT_APP_BAR: number = 56;
  static readonly HEIGHT_TAB_BAR: number = 64;
  static readonly HEIGHT_TAB_BAR_SAFE: number = 68;
  static readonly HEIGHT_BUTTON: number = 40;
  static readonly HEIGHT_BUTTON_SM: number = 32;
  static readonly HEIGHT_ROW: number = 72;
  /** 封面尺寸（对齐上游：首页横滑卡片 128dp、订阅瓦片 96dp、列表行 56dp、详情头图 124dp） */
  static readonly COVER_HOME_CARD: number = 128;
  static readonly COVER_FEED_TILE: number = 96;
  static readonly COVER_LIST: number = 56;
  static readonly COVER_DETAIL: number = 124;
  /** 首页横滑卡片的宽度（128 封面 + 左右各 4 内边距） */
  static readonly WIDTH_HOME_CARD: number = 136;
  /** 间距 */
  static readonly SPACE_XS: number = 4;
  static readonly SPACE_S: number = 8;
  static readonly SPACE_M: number = 12;
  static readonly SPACE_L: number = 16;
  static readonly SPACE_XL: number = 20;
  static readonly SPACE_XXL: number = 24;
  /** 图标尺寸 */
  static readonly ICON_XXL: number = 28;
  static readonly ICON_XL: number = 24;
  static readonly ICON_L: number = 22;
  static readonly ICON_M: number = 20;
  static readonly ICON_S: number = 18;
  static readonly ICON_XS: number = 16;
  /** 触控热区 */
  static readonly HIT_MIN: number = 44;
  /** 字阶（fp，HarmonyOS 系统字体 HarmonyOS Sans） */
  static readonly FONT_DISPLAY: number = 28;
  static readonly FONT_TITLE1: number = 24;
  static readonly FONT_TITLE2: number = 22;
  static readonly FONT_TITLE3: number = 20;
  static readonly FONT_HEADLINE: number = 17;
  static readonly FONT_SECTION: number = 16;
  static readonly FONT_BODY: number = 16;
  static readonly FONT_SUBTITLE: number = 15;
  static readonly FONT_PARAGRAPH: number = 14;
  static readonly FONT_FOOTNOTE: number = 12;
  static readonly FONT_CAPTION: number = 11;
  static readonly FONT_OVERLINE: number = 10;
  /** 底部导航文字（上游 TextBottomNav = 11sp） */
  static readonly FONT_NAV: number = 11;
}
