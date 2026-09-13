import { EpisodeRepository, FeedStorageUsage } from '../db/repositories/EpisodeRepository';
import { FeedMedia } from '../model/FeedMedia';
import { DownloadManager } from '../download/DownloadManager';
import { EventHub, EventType, DownloadsChangedData } from '../events/EventHub';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { EmptyState } from '../components/EmptyState';
import { FeedCover } from '../components/FeedCover';
import { RowCard } from '../components/RowCard';
import { SectionHeader } from '../components/SectionHeader';

/**
 * 存储管理页（对齐上游 Downloads 屏的「Choose data folder」条目 + remove_feed_dialog 的破坏性样式）：
 * 顶部为总占用摘要卡（48vp 图标 + 20sp 总量），随后是「按订阅」分组标题与逐订阅列表
 * （56vp 封面 + 标题 16sp + 集数/占用 14sp + 尾部删除按钮），底部为
 * error_container 底 + error 文字的「删除全部下载」动作。
 */
@Entry
@Component
struct StoragePage {
  @State usages: FeedStorageUsage[] = [];
  @State loading: boolean = true;
  @State totalBytes: number = 0;
  @State message: string = '';
  @State showClearAll: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        AppBar({ title: $r('app.string.storage_title'), showBack: true })

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
        }

        if (this.loading) {
          Text($r('app.string.loading'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
        } else if (this.usages.length === 0) {
          Column() {
            EmptyState({ icon: $r('sys.symbol.sdcard_fill'), title: $r('app.string.storage_empty') })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          // ── 总占用摘要卡 ──
          Row() {
            RowCard({ pad: DesignTokens.SPACE_L, radius: DesignTokens.RADIUS_ROW }) {
              Row({ space: DesignTokens.SPACE_M }) {
                Stack() {
                  SymbolGlyph($r('sys.symbol.sdcard_fill'))
                    .fontSize(DesignTokens.ICON_XL)
                    .fontColor([$r('app.color.primary')])
                }
                .width(48)
                .height(48)
                .borderRadius(DesignTokens.RADIUS_ROW)
                .backgroundColor($r('app.color.primary_container'))
                .alignContent(Alignment.Center)

                Column({ space: DesignTokens.SPACE_XS }) {
                  Text($r('app.string.storage_total'))
                    .fontSize(DesignTokens.FONT_FOOTNOTE)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                  Text(this.sizeText(this.totalBytes))
                    .fontSize(DesignTokens.FONT_TITLE3)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
          }
          .width('100%')
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })

          // ── 按订阅分组标题 ──
          Row() {
            SectionHeader({ title: $r('app.string.stats_by_feed'), countPill: this.usages.length })
          }
          .width('100%')
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })

          // ── 逐订阅占用列表 ──
          List({ space: DesignTokens.SPACE_S }) {
            ForEach(this.usages, (usage: FeedStorageUsage) => {
              ListItem() {
                Row({ space: DesignTokens.SPACE_M }) {
                  FeedCover({
                    imageUrl: '',
                    coverSize: DesignTokens.COVER_LIST,
                    fallbackTitle: usage.title
                  })

                  Column({ space: DesignTokens.SPACE_XS }) {
                    Text(usage.title)
                      .fontSize(DesignTokens.FONT_BODY)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(usage.count + ' · ' + this.sizeText(usage.size))
                      .fontSize(DesignTokens.FONT_PARAGRAPH)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Stack() {
                    SymbolGlyph($r('sys.symbol.trash'))
                      .fontSize(DesignTokens.ICON_M)
                      .fontColor([$r('app.color.error')])
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(20)
                  .alignContent(Alignment.Center)
                  .onClick(() => {
                    this.deleteFeed(usage);
                  })
                }
                .width('100%')
                .padding(DesignTokens.SPACE_M)
                .backgroundColor($r('app.color.surface'))
                .borderRadius(DesignTokens.RADIUS_ROW)
                .alignItems(VerticalAlign.Center)
              }
            }, (usage: FeedStorageUsage) => usage.feedId.toString())
          }
          .layoutWeight(1)
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
          .scrollBar(BarState.Off)

          // ── 破坏性动作：删除全部下载 ──
          Row() {
            Row({ space: DesignTokens.SPACE_S }) {
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(DesignTokens.ICON_M)
                .fontColor([$r('app.color.error')])
              Text($r('app.string.setting_storage_clear_all'))
                .fontSize(DesignTokens.FONT_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.error'))
            }
            .width('100%')
            .height(DesignTokens.HEIGHT_BUTTON)
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.error_container'))
            .borderRadius(DesignTokens.RADIUS_ROW)
            .onClick(() => {
              this.showClearAll = true;
            })
          }
          .width('100%')
          .padding({
            left: DesignTokens.PAGE_MARGIN,
            right: DesignTokens.PAGE_MARGIN,
            top: DesignTokens.SPACE_M,
            bottom: DesignTokens.SPACE_M
          })
        }
      }
      .width('100%')
      .height('100%')

      if (this.showClearAll) {
        Column({ space: DesignTokens.SPACE_L }) {
          Text($r('app.string.setting_storage_clear_all'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_primary'))
            .padding({ top: DesignTokens.SPACE_XL, left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
          Row({ space: DesignTokens.SPACE_M }) {
            Button($r('app.string.dialog_cancel'))
              .layoutWeight(1)
              .height(DesignTokens.HEIGHT_BUTTON)
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .backgroundColor($r('app.color.surface_secondary'))
              .fontColor($r('app.color.text_primary'))
              .onClick(() => {
                this.showClearAll = false;
              })
            Button($r('app.string.setting_storage_clear_all'))
              .layoutWeight(1)
              .height(DesignTokens.HEIGHT_BUTTON)
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .backgroundColor($r('app.color.error'))
              .fontColor(Color.White)
              .onClick(() => {
                this.clearAll();
              })
          }
          .width('90%')
          .margin({ bottom: DesignTokens.SPACE_L })
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const usages: FeedStorageUsage[] = await EpisodeRepository.listStorageByFeed();
      this.usages = usages;
      let total: number = 0;
      for (const usage of usages) {
        total += usage.size;
      }
      this.totalBytes = total;
    } catch (error) {
      this.usages = [];
      this.totalBytes = 0;
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  async deleteFeed(usage: FeedStorageUsage): Promise<void> {
    try {
      const media: FeedMedia[] = await EpisodeRepository.listDownloadedMediaByFeed(usage.feedId);
      for (const item of media) {
        await DownloadManager.deleteFile(item);
      }
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.storage_deleted'));
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  async clearAll(): Promise<void> {
    this.showClearAll = false;
    try {
      const media: FeedMedia[] = await EpisodeRepository.listAllDownloadedMedia();
      for (const item of media) {
        await DownloadManager.deleteFile(item);
      }
      const changed: DownloadsChangedData = { active: 0 };
      EventHub.publish(EventType.DOWNLOADS_CHANGED, changed);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.storage_deleted'));
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  sizeText(bytes: number): string {
    if (bytes <= 0) {
      return '0 MB';
    }
    const mb: number = bytes / (1024 * 1024);
    if (mb < 1) {
      return (bytes / 1024).toFixed(0) + ' KB';
    }
    return mb.toFixed(1) + ' MB';
  }
}
