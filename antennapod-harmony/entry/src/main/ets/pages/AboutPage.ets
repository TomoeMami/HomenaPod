// Port of: ui/preferences/src/main/res/xml/preferences_about.xml + screen/about/AboutFragment.java
import { Want } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import bundleManager from '@ohos.bundle.bundleManager';
import deviceInfo from '@ohos.deviceInfo';
import pasteboard from '@ohos.pasteboard';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { RowCard } from '../components/RowCard';

/** 上游项目与上游许可全文（事实性引用，不暗示上游背书；口径见仓库 NOTICE.md） */
const URL_UPSTREAM: string = 'https://github.com/AntennaPod/AntennaPod';
const URL_LICENSE: string = 'https://www.gnu.org/licenses/gpl-3.0.html';
/** 本项目自身的公开入口：源码、问题反馈、文档都指向同一个仓库 */
const URL_SOURCE: string = 'https://github.com/TomoeMami/HomenaPod';
const URL_ISSUES: string = 'https://github.com/TomoeMami/HomenaPod/issues';
const URL_DOCS: string = 'https://github.com/TomoeMami/HomenaPod#readme';

/**
 * 「关于」页（对齐上游 preferences_about.xml 的信息位次：版本 → 来源 → 隐私 → 许可 → 致谢）：
 * 顶部品牌卡（应用图标 + 名称 + 版本 + 一句话定位），随后依次为
 * 应用信息 / 来源与许可 / 隐私与数据 / 致谢 / 免责声明，底部提供「复制版本信息」。
 *
 * 与上游的差异（有意为之）：
 * - 上游的「贡献者 / 特别感谢 / 翻译者」三页依赖其社区名单与 Crowdin 数据，移植版不复制这类名单，
 *   改为陈述式的「致谢」，只列真正被依赖的项目与组件。
 * - 上游把版本号硬编码进 XML 再运行时覆盖；这里**只**从 bundleManager 读，避免版本号两处漂移。
 * - 上游的隐私政策链接指向 antennapod.org（上游服务条款）；移植版不收集任何数据，
 *   因此本地陈述「数据不出设备」比外链更准确。
 */
@Entry
@Component
struct AboutPage {
  /** 运行时读取的应用版本（不在代码里硬编码，与 AppScope/app.json5 始终一致） */
  @State versionName: string = '';
  @State versionCode: number = 0;
  @State bundleName: string = '';
  /**
   * 行内反馈（复制成功 / 链接退化复制）。
   *
   * 这里存 `ResourceStr` 而不是 `getStringSync()` 解析出来的 string：`getStringSync` 取的是
   * 系统区域（实测：应用切到 English 后，设置页「排序方式」右侧仍显示「最新优先」，因为那条
   * 路径就是 `getStringSync`），而 `$r()` 交给 `Text()` 渲染才跟随应用语言。
   */
  @State message: ResourceStr = '';
  @State showMessage: boolean = false;

  build() {
    Column() {
      AppBar({ title: $r('app.string.about_title'), showBack: true })

      if (this.showMessage) {
        Row({ space: DesignTokens.SPACE_XS }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(DesignTokens.ICON_S)
            .fontColor([$r('app.color.primary')])
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
      }

      Scroll() {
        Column({ space: DesignTokens.SPACE_L }) {
          // ── 品牌卡：图标 + 名称 + 版本 + 定位 ──
          RowCard({ pad: DesignTokens.SPACE_L, radius: DesignTokens.RADIUS_CARD }) {
            Row({ space: DesignTokens.SPACE_L }) {
              Image($r('app.media.app_icon'))
                .width(64)
                .height(64)
                .borderRadius(DesignTokens.RADIUS_CARD)
                .objectFit(ImageFit.Contain)

              Column({ space: DesignTokens.SPACE_XS }) {
                Text($r('app.string.app_name'))
                  .fontSize(DesignTokens.FONT_TITLE1)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
                Text(this.versionLabel())
                  .fontSize(DesignTokens.FONT_PARAGRAPH)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                Text($r('app.string.about_tagline'))
                  .fontSize(DesignTokens.FONT_FOOTNOTE)
                  .fontColor($r('app.color.text_tertiary'))
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }

          // ── 应用信息（上游 about_version 的等价物 + 移植版补充的运行环境）──
          this.sectionTitle($r('app.string.about_section_app'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.infoRow($r('app.string.about_row_version'), this.versionLabel())
              this.rowDivider()
              this.infoRow($r('app.string.about_row_bundle'), this.bundleName)
              this.rowDivider()
              this.infoRow($r('app.string.about_row_runtime'), this.runtimeLabel())
              this.rowDivider()
              this.infoRow($r('app.string.about_row_device'), this.deviceLabel())
              this.rowDivider()
              this.infoRow($r('app.string.about_row_upstream'), $r('app.string.about_value_upstream'))
            }
            .width('100%')
          }

          // ── 来源与许可（上游 about_licenses 的外链等价物）──
          this.sectionTitle($r('app.string.about_section_legal'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.linkRow($r('app.string.about_row_upstream_repo'), URL_UPSTREAM)
              this.rowDivider()
              this.linkRow($r('app.string.about_row_source'), URL_SOURCE)
              this.rowDivider()
              this.linkRow($r('app.string.about_row_license'), URL_LICENSE)
              this.rowDivider()
              this.linkRow($r('app.string.about_row_issues'), URL_ISSUES)
              this.rowDivider()
              this.linkRow($r('app.string.about_row_docs'), URL_DOCS)
            }
            .width('100%')
          }
          this.paragraph($r('app.string.about_text_source'))

          // ── 隐私与数据（上游 about_privacy_policy 的等价物：本应用无服务端，故为本地陈述）──
          this.sectionTitle($r('app.string.about_section_privacy'))
          this.paragraph($r('app.string.about_text_privacy_local'))
          this.paragraph($r('app.string.about_text_privacy_network'))
          this.paragraph($r('app.string.about_text_privacy_permissions'))

          // ── 致谢 ──
          this.sectionTitle($r('app.string.about_section_credits'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.infoRow($r('app.string.about_credit_upstream_label'),
                $r('app.string.about_credit_upstream_value'))
              this.rowDivider()
              this.infoRow($r('app.string.about_credit_sdk_label'),
                $r('app.string.about_credit_sdk_value'))
              this.rowDivider()
              this.infoRow($r('app.string.about_credit_symbol_label'),
                $r('app.string.about_credit_symbol_value'))
              this.rowDivider()
              this.infoRow($r('app.string.about_credit_test_label'),
                $r('app.string.about_credit_test_value'))
            }
            .width('100%')
          }
          this.paragraph($r('app.string.about_text_credits'))

          // ── 免责声明 ──
          this.sectionTitle($r('app.string.about_section_disclaimer'))
          this.paragraph($r('app.string.about_text_disclaimer'))

          // ── 底部动作：复制版本信息（反馈问题时要粘贴的就是这几行）──
          Row({ space: DesignTokens.SPACE_S }) {
            SymbolGlyph($r('sys.symbol.doc_plaintext'))
              .fontSize(DesignTokens.ICON_M)
              .fontColor([$r('app.color.primary')])
            Text($r('app.string.about_copy_version'))
              .fontSize(DesignTokens.FONT_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.primary'))
          }
          .width('100%')
          .height(DesignTokens.HEIGHT_BUTTON)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('app.color.primary_container'))
          .borderRadius(DesignTokens.RADIUS_ROW)
          .onClick(() => {
            this.copyVersionInfo();
          })

          Text($r('app.string.about_copyright'))
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ bottom: DesignTokens.SPACE_S })
        }
        .width('100%')
        .padding({
          left: DesignTokens.PAGE_MARGIN,
          right: DesignTokens.PAGE_MARGIN,
          bottom: DesignTokens.SPACE_XXL
        })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor($r('app.color.page_bg'))
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：与其它二级页一致，背景延伸到状态栏下
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 分类标题（与设置页同款：14sp 品牌色，上 16vp / 下 8vp） */
  @Builder
  sectionTitle(label: ResourceStr) {
    Text(label)
      .fontSize(DesignTokens.FONT_PARAGRAPH)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.primary'))
      .width('100%')
      .padding({ top: DesignTokens.SPACE_L, bottom: DesignTokens.SPACE_S })
  }

  /** 行间分隔线 */
  @Builder
  rowDivider() {
    Divider()
      .color($r('app.color.divider'))
      .strokeWidth(1)
      .width('100%')
  }

  /**
   * 信息行：上行小字标签 + 下行取值。
   *
   * 不用「左标签 / 右取值」两列：取值里有 URL、上游快照号这类长字符串，
   * 两列布局在窄屏上必然省略号截断，而「关于」页的价值恰恰在把完整信息给到用户。
   */
  @Builder
  infoRow(label: ResourceStr, value: ResourceStr) {
    Column({ space: DesignTokens.SPACE_XS }) {
      Text(label)
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Text(value)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .maxLines(3)
    }
    .width('100%')
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(HorizontalAlign.Start)
  }

  /** 外链行：信息行 + 尾部「打开外部」箭头，点击拉起浏览器（失败退化为复制链接） */
  @Builder
  linkRow(label: ResourceStr, url: string) {
    Row({ space: DesignTokens.SPACE_M }) {
      Column({ space: DesignTokens.SPACE_XS }) {
        Text(label)
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Text(url)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.primary'))
          .width('100%')
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.arrow_up_right'))
        .fontSize(DesignTokens.ICON_M)
        .fontColor([$r('app.color.text_disabled')])
    }
    .width('100%')
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openLink(url);
    })
  }

  /** 说明段落：整段正文单独成卡，行高放宽以便长段落阅读 */
  @Builder
  paragraph(text: ResourceStr) {
    RowCard({ pad: DesignTokens.SPACE_L, radius: DesignTokens.RADIUS_ROW }) {
      Text(text)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
    }
  }

  aboutToAppear(): void {
    this.loadBundleInfo();
  }

  /** 版本号只从包信息读一次（读失败时留空，页面其余内容照常显示） */
  loadBundleInfo(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.versionName = info.versionName;
      this.versionCode = info.versionCode;
      this.bundleName = info.name;
    } catch (error) {
      this.versionName = '';
      this.versionCode = 0;
      this.bundleName = '';
    }
  }

  /** 品牌卡与「版本」行的取值：v1.0.14 (1000014) */
  versionLabel(): string {
    if (this.versionName === '') {
      return '—';
    }
    return 'v' + this.versionName + ' (' + this.versionCode.toString() + ')';
  }

  /** 运行环境：系统版本 + 设备上的 SDK API 版本（未申请任何权限即可读取） */
  runtimeLabel(): string {
    return deviceInfo.osFullName + ' · API ' + deviceInfo.sdkApiVersion.toString();
  }

  /** 设备：机型 + 设备类型（phone / tablet / 2in1） */
  deviceLabel(): string {
    return deviceInfo.productModel + ' · ' + deviceInfo.deviceType;
  }

  /**
   * 拉起外部链接：`ohos.want.action.viewData` + browsable 是鸿蒙打开 http(s) 链接的标准隐式 Want。
   * 设备上没有可处理的浏览器（或启动被拒）时退化为复制链接，至少让用户拿得到地址。
   */
  async openLink(url: string): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      };
      await context.startAbility(want);
    } catch (error) {
      await this.copyText(url);
      this.message = $r('app.string.about_link_copied');
      this.showMessage = true;
    }
  }

  /** 写入系统剪贴板（无需权限）；失败时静默，不阻断页面其它动作 */
  async copyText(text: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
    } catch (error) {
      // 剪贴板不可用：保持静默
    }
  }

  /** 复制版本信息：反馈问题时需要粘贴的版本 / 包名 / 运行环境 / 机型 */
  async copyVersionInfo(): Promise<void> {
    await this.copyText(this.versionBlock());
    this.message = $r('app.string.about_copied');
    this.showMessage = true;
  }

  /** 复制用的纯文本块（无本地化，便于维护者直接比对） */
  versionBlock(): string {
    const lines: string[] = [];
    lines.push('HomenaPod ' + this.versionName + ' (' + this.versionCode.toString() + ')');
    lines.push('bundle: ' + this.bundleName);
    lines.push(deviceInfo.osFullName + ' / API ' + deviceInfo.sdkApiVersion.toString());
    lines.push('device: ' + this.deviceLabel());
    return lines.join('\n');
  }
}
