import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { picker } from '@kit.CoreFileKit';
import { Want } from '@kit.AbilityKit';
import { Feed } from '../model/Feed';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { OpmlService } from '../services/OpmlService';
import { DatabaseBackupService, DatabaseHeaderInfo } from '../services/DatabaseBackupService';
import { OpmlImportParams } from './OpmlPage';
import { Logger } from '../utils/Logger';
import { FileSizeUtils } from '../utils/FileSizeUtils';
import { MessageHelper } from '../utils/MessageHelper';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { RowCard } from '../components/RowCard';

const TAG: string = 'ImportExportPage';

/** 上游 preference 行最小高度（标题 + 摘要两行） */
const ROW_MIN_HEIGHT: number = 56;

/**
 * 「备份与恢复」页（对齐上游 `ImportExportPreferencesFragment` + `preferences_import_export.xml`）：
 *
 * - Database：数据库导出 / 数据库导入（整库 .db 备份与恢复，覆盖订阅、单集、播放进度、队列、收藏、历史）
 * - OPML：OPML 导出 / OPML 导入（只带订阅源，用于和别的播客应用互通）
 *
 * 上游把 HTML 导出与收藏导出也放在这一屏，本移植版不做（见 STATUS.md 的对齐取舍记录）。
 * 数据库导入会**整体替换**当前库，因此先弹上游那条警告确认框，成功后按上游流程重启应用。
 */
@Entry
@Component
struct ImportExportPage {
  @State loading: boolean = false;
  /** 数据库导入的警告确认框（上游 database_import_warning） */
  @State showImportWarning: boolean = false;
  /** 导入成功后的重启提示框（上游请按 OK 重启） */
  @State showImportSuccess: boolean = false;
  /** 错误对话框（导出/导入失败，上游 MaterialAlertDialog） */
  @State errorVisible: boolean = false;
  @State errorTitle: string = '';
  @State errorMessage: string = '';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppBar({ title: $r('app.string.import_export_pref'), showBack: true })

        Scroll() {
          Column() {
            // ── Database（上游 preferences_import_export.xml 的 database 分类）──
            this.categoryTitle($r('app.string.settings_category_database'))
            RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
              Column() {
                this.exportRow($r('sys.symbol.doc_plaintext'), $r('app.string.database_export_label'),
                  $r('app.string.database_export_summary'), () => {
                    this.exportDatabase();
                  })
                this.rowDivider()
                this.exportRow($r('sys.symbol.arrow_down_to_line'), $r('app.string.database_import_label'),
                  $r('app.string.database_import_summary'), () => {
                    this.showImportWarning = true;
                  })
              }
              .width('100%')
            }

            // ── OPML（上游 preferences_import_export.xml 的 opml 分类）──
            this.categoryTitle($r('app.string.settings_category_opml'))
            RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
              Column() {
                this.exportRow($r('sys.symbol.doc_text'), $r('app.string.opml_export_label'),
                  $r('app.string.opml_export_summary'), () => {
                    this.exportOpml();
                  })
                this.rowDivider()
                this.exportRow($r('sys.symbol.square_and_arrow_down'), $r('app.string.opml_import_label'),
                  $r('app.string.opml_import_summary'), () => {
                    this.pickOpml();
                  })
              }
              .width('100%')
            }
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
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('app.color.primary'))
          Text($r('app.string.please_wait'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: DesignTokens.SPACE_S })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#66000000')
      }

      if (this.showImportWarning) {
        this.scrim(() => {
          this.showImportWarning = false;
        })
        this.messageDialog($r('app.string.database_import_label'), $r('app.string.database_import_warning'),
          $r('app.string.confirm_label'), true, () => {
            this.showImportWarning = false;
            this.importDatabase();
          }, () => {
            this.showImportWarning = false;
          })
      }

      if (this.showImportSuccess) {
        this.messageDialog($r('app.string.successful_import_label'), $r('app.string.import_ok'),
          $r('app.string.ok_label'), false, () => {
            this.restartApp();
          }, () => {
            this.restartApp();
          })
      }

      if (this.errorVisible) {
        this.scrim(() => {
          this.errorVisible = false;
        })
        this.errorDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 分类标题（对齐上游 PreferenceCategory） */
  @Builder
  categoryTitle(label: ResourceStr) {
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

  /** 动作行：图标 + 标题 + 摘要（上游 Preference 的 title/summary 两行形态） */
  @Builder
  exportRow(icon: Resource, title: ResourceStr, summary: ResourceStr, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Column({ space: DesignTokens.SPACE_XS }) {
        Text(title)
          .fontSize(DesignTokens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text(summary)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      onTap();
    })
  }

  /** 半透明遮罩（点外部关闭，对应上游 AlertDialog 的取消） */
  @Builder
  scrim(onTap: () => void) {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .onClick(() => {
        onTap();
      })
  }

  /**
   * 居中对话框（上游 MaterialAlertDialogBuilder）：
   * cancellable = true 时左侧还有「否」（数据库导入的警告框，上游是 No / Confirm）；
   * 导入成功的重启提示则只有一个「确定」（上游 setCancelable(false)）。
   */
  @Builder
  messageDialog(title: ResourceStr, body: ResourceStr, confirmLabel: ResourceStr, cancellable: boolean,
                onConfirm: () => void, onCancel: () => void) {
    Column({ space: DesignTokens.SPACE_L }) {
      Text(title)
        .fontSize(DesignTokens.FONT_TITLE3)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(body)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Row({ space: DesignTokens.SPACE_M }) {
        if (cancellable) {
          Text($r('app.string.no_label'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
            .padding(DesignTokens.SPACE_M)
            .onClick(() => {
              onCancel();
            })
        }
        Text(confirmLabel)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            onConfirm();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('82%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_CARD)
    .padding(DesignTokens.SPACE_XL)
  }

  /** 错误对话框（上游 showExportErrorDialog / showImportErrorDialog：标题 + 详细信息） */
  @Builder
  errorDialog() {
    Column({ space: DesignTokens.SPACE_L }) {
      Text(this.errorTitle)
        .fontSize(DesignTokens.FONT_TITLE3)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(this.errorMessage)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Row() {
        Text($r('app.string.ok_label'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            this.errorVisible = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('82%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_CARD)
    .padding(DesignTokens.SPACE_XL)
  }

  // ───────────────────────────── 数据库备份 / 恢复 ─────────────────────────────

  /** 数据库导出：选保存位置 → relationalStore.backup() 快照 → 拷到目标 uri（上游 Database export） */
  async exportDatabase(): Promise<void> {
    this.loading = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const uri: string = await this.pickSavePath(DatabaseBackupService.defaultFileName(new Date()));
      if (uri === '') {
        return;
      }
      const bytes: number = await DatabaseBackupService.exportTo(uri, context);
      MessageHelper.show(context.resourceManager.getStringSync($r('app.string.export_success_title'))
        + ' · ' + FileSizeUtils.format(bytes));
    } catch (error) {
      this.showError($r('app.string.export_error_label'), (error as Error).message);
    } finally {
      this.loading = false;
    }
  }

  /**
   * 数据库导入：确认警告 → 选文件 → 校验（SQLite 头 + 拒绝降级）→ restore() → 提示重启。
   * 上游 `ImportExportPreferencesFragment.restoreDatabaseResult` + `forceRestart()`。
   */
  async importDatabase(): Promise<void> {
    this.loading = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const uri: string = await this.pickOpenPath();
      if (uri === '') {
        return;
      }
      const info: DatabaseHeaderInfo = await DatabaseBackupService.describeFile(uri);
      if (!info.isSqlite) {
        this.showError($r('app.string.import_error_label'), context.resourceManager
          .getStringSync($r('app.string.import_not_a_database')));
        return;
      }
      if (info.tooNew) {
        // 上游 import_no_downgrade：更新的库版本不认，直接拒绝（不能覆盖成读不出来的库）
        this.showError($r('app.string.import_error_label'), context.resourceManager
          .getStringSync($r('app.string.import_no_downgrade')));
        return;
      }
      await DatabaseBackupService.importFrom(uri, context);
      this.showImportSuccess = true;
    } catch (error) {
      Logger.warn(TAG, 'database import failed: ' + (error as Error).message);
      this.showError($r('app.string.import_error_label'), (error as Error).message);
    } finally {
      this.loading = false;
    }
  }

  /** 重启应用：让所有页面重新读恢复后的库（上游导入成功后 `forceRestart()`） */
  private restartApp(): void {
    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: context.abilityInfo.name
    };
    try {
      context.getApplicationContext().restartApp(want);
    } catch (error) {
      Logger.warn(TAG, 'restartApp failed: ' + (error as Error).message);
      context.terminateSelf();
    }
  }

  // ───────────────────────────── OPML 导出 / 导入 ─────────────────────────────

  /** OPML 导出：只导出订阅源（上游 prefOpmlExport → OpmlWriter） */
  async exportOpml(): Promise<void> {
    this.loading = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const uri: string = await this.pickSavePath(OpmlService.defaultExportFileName(new Date()));
      if (uri === '') {
        return;
      }
      const feeds: Feed[] = await FeedRepository.listSubscribed();
      await OpmlService.writeToUri(uri, OpmlService.exportOpml(feeds, new Date()));
      MessageHelper.show(context.resourceManager.getStringSync($r('app.string.opml_exported'))
        + feeds.length);
    } catch (error) {
      this.showError($r('app.string.export_error_label'), (error as Error).message);
    } finally {
      this.loading = false;
    }
  }

  /**
   * OPML 导入：选文件后交给 OpmlPage 的勾选列表（上游 prefOpmlImport → GetContent →
   * `OpmlImportActivity`）。文件由本页选好，页面只负责解析与勾选，避免让用户选两次。
   */
  async pickOpml(): Promise<void> {
    this.loading = true;
    try {
      const uri: string = await this.pickOpenPath();
      if (uri === '') {
        return;
      }
      const params: OpmlImportParams = { opmlUri: uri };
      router.pushUrl({ url: 'pages/OpmlPage', params: params });
    } catch (error) {
      this.showError($r('app.string.import_error_label'), (error as Error).message);
    } finally {
      this.loading = false;
    }
  }

  // ───────────────────────────── 文件选择器 ─────────────────────────────

  /** 选保存位置；用户取消时返回空串（上游 result.getResultCode() != RESULT_OK） */
  private async pickSavePath(fileName: string): Promise<string> {
    const context = getContext(this) as common.UIAbilityContext;
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const result: string[] = await new picker.DocumentViewPicker(context).save(options);
    return result.length > 0 ? result[0] : '';
  }

  /**
   * 选单个文件；用户取消时返回空串。
   * 不设后缀过滤，等价于上游传的「所有文件」通配（API 14 的手机端还不支持该过滤项）。
   */
  private async pickOpenPath(): Promise<string> {
    const context = getContext(this) as common.UIAbilityContext;
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    const result: string[] = await new picker.DocumentViewPicker(context).select(options);
    return result.length > 0 ? result[0] : '';
  }

  private showError(title: Resource, message: string): void {
    this.errorTitle = getContext(this).resourceManager.getStringSync(title);
    this.errorMessage = message;
    this.errorVisible = true;
  }
}
