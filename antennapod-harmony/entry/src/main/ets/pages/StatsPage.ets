import { EpisodeRepository, MonthlyStat, FeedStat, FeedStorageUsage } from '../db/repositories/EpisodeRepository';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { Feed } from '../model/Feed';
import { UserPreferences } from '../prefs/UserPreferences';
import { DurationUtils } from '../utils/DurationUtils';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { TagChip } from '../components/TagChip';
import { SectionHeader } from '../components/SectionHeader';
import { RowCard } from '../components/RowCard';
import { FeedCover } from '../components/FeedCover';
import { EmptyState } from '../components/EmptyState';

/** 按年份聚合后的收听时长 */
interface YearStat {
  year: string;
  totalMs: number;
}

/**
 * 收听统计页（对齐上游 `ui/statistics` 的 `pager_fragment.xml` + `statistics_fragment.xml`）：
 * 56vp 标题栏 + 三标签行（Subscriptions / Years / Downloads），
 * 每个标签的内容用 `RowCard` 承载，并按数值绘制等宽比例条
 * （上游 `PieChartView` / `BarChartView` 是自绘 Canvas 图表，HarmonyOS 无对应原生控件，用比例条替代）。
 */
@Entry
@Component
struct StatsPage {
  @State months: MonthlyStat[] = [];
  @State feeds: FeedStat[] = [];
  @State years: YearStat[] = [];
  @State usages: FeedStorageUsage[] = [];
  @State loading: boolean = true;
  @State totalMs: number = 0;
  @State storageBytes: number = 0;
  @State activeTab: number = 0;
  /** 统计口径：是否计入「仅标记为已播」的单集时长（上游 StatisticsFilterDialog 的 includeMarkedCheckbox） */
  @State includeMarked: boolean = false;
  @State message: string = '';
  private feedImages: Map<number, string> = new Map<number, string>();

  build() {
    Column() {
      AppBar({ title: $r('app.string.stats_title'), showBack: true })

      // 标签行（上游 pager_fragment.xml 的 TabLayout：Subscriptions / Years / Downloads）
      Row({ space: DesignTokens.SPACE_S }) {
        TagChip({
          label: $r('app.string.tab_subscriptions'),
          selected: this.activeTab === 0,
          onTap: () => {
            this.activeTab = 0;
          }
        })
        TagChip({
          label: $r('app.string.stats_tab_years'),
          selected: this.activeTab === 1,
          onTap: () => {
            this.activeTab = 1;
          }
        })
        TagChip({
          label: $r('app.string.tab_downloads'),
          selected: this.activeTab === 2,
          onTap: () => {
            this.activeTab = 2;
          }
        })
      }
      .width('100%')
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })

      if (this.message !== '') {
        Text(this.message)
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.primary'))
          .width('100%')
          .padding({ left: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
      }

      if (this.loading) {
        Text($r('app.string.loading'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: DesignTokens.SPACE_S }) {
            if (this.activeTab === 0) {
              this.subscriptionsTab()
            } else if (this.activeTab === 1) {
              this.yearsTab()
            } else {
              this.downloadsTab()
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_M })
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  /** 标签 0「Subscriptions」：汇总（上游 total_time 28sp + 说明 14sp）+ 每个订阅 40vp 封面行 */
  @Builder
  subscriptionsTab() {
    // 统计口径开关（上游 StatisticsFilterDialog 的「包含仅标记为已播的单集时长」复选项）。
    // 首页「常听经典」按同一口径排序，所以这个开关也会影响首页。
    Row({ space: DesignTokens.SPACE_M }) {
      Text($r('app.string.stats_include_marked'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.includeMarked })
        .onChange((isOn: boolean) => {
          this.includeMarked = isOn;
          UserPreferences.setStatisticsIncludeMarked(isOn);
          this.load();
        })
    }
    .width('100%')
    .padding(DesignTokens.SPACE_M)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_ROW)
    .alignItems(VerticalAlign.Center)

    RowCard({ pad: DesignTokens.SPACE_L, radius: DesignTokens.RADIUS_CARD }) {
      Column({ space: DesignTokens.SPACE_XS }) {
        Row({ space: DesignTokens.SPACE_S }) {
          SymbolGlyph($r('sys.symbol.headphones'))
            .fontSize(DesignTokens.ICON_XL)
            .fontColor([$r('app.color.primary')])
          Text(this.durationText(this.totalMs))
            .fontSize(DesignTokens.FONT_DISPLAY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text($r('app.string.stats_total'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }

    if (this.feeds.length === 0) {
      this.emptyBlock($r('sys.symbol.histogram'), $r('app.string.stats_empty'))
    } else {
      SectionHeader({
        title: $r('app.string.stats_by_feed'),
        countPill: this.feeds.length
      })

      ForEach(this.feeds, (stat: FeedStat) => {
        this.feedRow(stat)
      }, (stat: FeedStat) => 'f-' + stat.feedId.toString())
    }
  }

  /** 订阅统计行（上游 statistics_listitem.xml：40dp 封面 + 16sp 标题 + 13sp ⬤ + 14sp 数值） */
  @Builder
  feedRow(stat: FeedStat) {
    RowCard({ pad: DesignTokens.SPACE_M, radius: DesignTokens.RADIUS_ROW }) {
      Column({ space: DesignTokens.SPACE_S }) {
        Row({ space: DesignTokens.SPACE_M }) {
          FeedCover({
            imageUrl: this.feedImage(stat.feedId),
            coverSize: 40,
            radius: 0,
            placeholderColor: $r('app.color.cover_placeholder')
          })
          Column({ space: DesignTokens.SPACE_XS }) {
            Text(stat.title)
              .fontSize(DesignTokens.FONT_BODY)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: DesignTokens.SPACE_XS }) {
              Text('⬤')
                .fontSize(13)
                .fontColor($r('app.color.primary'))
              Text(this.durationText(stat.totalMs))
                .fontSize(DesignTokens.FONT_PARAGRAPH)
                .fontColor($r('app.color.text_tertiary'))
                .maxLines(1)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Progress({ value: stat.totalMs, total: this.maxFeedMs(), type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color($r('app.color.primary'))
          .backgroundColor($r('app.color.scrubber_track'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  /** 标签 1「Years」：每月比例条（替代上游 BarChartView）+ 年份行（16sp 年份 + 14sp 时长） */
  @Builder
  yearsTab() {
    if (this.months.length === 0 && this.years.length === 0) {
      this.emptyBlock($r('sys.symbol.histogram'), $r('app.string.stats_empty'))
    } else {
      SectionHeader({
        title: $r('app.string.stats_by_month'),
        countPill: this.months.length
      })

      RowCard({ pad: DesignTokens.SPACE_L, radius: DesignTokens.RADIUS_CARD }) {
        Column({ space: DesignTokens.SPACE_S }) {
          Text($r('app.string.stats_time_per_month'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          ForEach(this.months, (stat: MonthlyStat) => {
            Row({ space: DesignTokens.SPACE_S }) {
              Text(stat.month)
                .fontSize(DesignTokens.FONT_FOOTNOTE)
                .fontColor($r('app.color.text_tertiary'))
                .width(56)
                .maxLines(1)
              Progress({ value: stat.totalMs, total: this.maxMonthMs(), type: ProgressType.Linear })
                .layoutWeight(1)
                .height(4)
                .color($r('app.color.primary'))
                .backgroundColor($r('app.color.scrubber_track'))
              Text(this.durationText(stat.totalMs))
                .fontSize(DesignTokens.FONT_CAPTION)
                .fontColor($r('app.color.text_tertiary'))
                .maxLines(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (stat: MonthlyStat) => 'm-' + stat.month)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.years.length > 0) {
        SectionHeader({
          title: $r('app.string.stats_tab_years'),
          countPill: this.years.length
        })

        ForEach(this.years, (stat: YearStat) => {
          this.yearRow(stat)
        }, (stat: YearStat) => 'y-' + stat.year)
      }
    }
  }

  /** 年份统计行（上游 statistics_year_listitem.xml） */
  @Builder
  yearRow(stat: YearStat) {
    RowCard({ pad: DesignTokens.SPACE_M, radius: DesignTokens.RADIUS_ROW }) {
      Column({ space: DesignTokens.SPACE_S }) {
        Row({ space: DesignTokens.SPACE_S }) {
          Text(stat.year)
            .fontSize(DesignTokens.FONT_BODY)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
          Text(this.durationText(stat.totalMs))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Progress({ value: stat.totalMs, total: this.maxYearMs(), type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color($r('app.color.primary'))
          .backgroundColor($r('app.color.scrubber_track'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  /** 标签 2「Downloads」：设备占用（上游 statistics_listitem.xml 的 size + episode 数） */
  @Builder
  downloadsTab() {
    RowCard({ pad: DesignTokens.SPACE_L, radius: DesignTokens.RADIUS_CARD }) {
      Column({ space: DesignTokens.SPACE_XS }) {
        Row({ space: DesignTokens.SPACE_S }) {
          SymbolGlyph($r('sys.symbol.sdcard_fill'))
            .fontSize(DesignTokens.ICON_XL)
            .fontColor([$r('app.color.primary')])
          Text(this.sizeText(this.storageBytes))
            .fontSize(DesignTokens.FONT_DISPLAY)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text($r('app.string.storage_total'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }

    if (this.usages.length === 0) {
      this.emptyBlock($r('sys.symbol.sdcard_fill'), $r('app.string.storage_empty'))
    } else {
      ForEach(this.usages, (usage: FeedStorageUsage) => {
        this.usageRow(usage)
      }, (usage: FeedStorageUsage) => 's-' + usage.feedId.toString())
    }
  }

  @Builder
  usageRow(usage: FeedStorageUsage) {
    RowCard({ pad: DesignTokens.SPACE_M, radius: DesignTokens.RADIUS_ROW }) {
      Column({ space: DesignTokens.SPACE_S }) {
        Row({ space: DesignTokens.SPACE_M }) {
          FeedCover({
            imageUrl: this.feedImage(usage.feedId),
            coverSize: 40,
            radius: 0,
            placeholderColor: $r('app.color.cover_placeholder')
          })
          Column({ space: DesignTokens.SPACE_XS }) {
            Text(usage.title)
              .fontSize(DesignTokens.FONT_BODY)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(usage.count.toString() + ' · ' + this.sizeText(usage.size))
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .fontColor($r('app.color.text_tertiary'))
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Progress({ value: usage.size, total: this.maxUsageSize(), type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color($r('app.color.primary'))
          .backgroundColor($r('app.color.scrubber_track'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  emptyBlock(icon: Resource, title: ResourceStr) {
    Column() {
      EmptyState({ icon: icon, title: title })
    }
    .width('100%')
    .padding({ top: DesignTokens.SPACE_XL, bottom: DesignTokens.SPACE_XL })
    .justifyContent(FlexAlign.Center)
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const feeds: Feed[] = await FeedRepository.listSubscribed();
      const images: Map<number, string> = new Map<number, string>();
      for (const feed of feeds) {
        images.set(feed.id, feed.imageUrl);
      }
      this.feedImages = images;

      this.months = await EpisodeRepository.listStatsByMonth();
      this.includeMarked = UserPreferences.getStatisticsIncludeMarked();
      this.feeds = await EpisodeRepository.listStatsByFeed(this.includeMarked);
      let total: number = 0;
      for (const stat of this.months) {
        total += stat.totalMs;
      }
      this.totalMs = total;
      this.years = this.buildYears(this.months);

      try {
        this.usages = await EpisodeRepository.listStorageByFeed();
        let bytes: number = 0;
        for (const usage of this.usages) {
          bytes += usage.size;
        }
        this.storageBytes = bytes;
      } catch (storageError) {
        this.usages = [];
        this.storageBytes = 0;
      }
    } catch (error) {
      this.months = [];
      this.feeds = [];
      this.years = [];
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  /** 月份（`YYYY-MM`）聚合为年份 */
  buildYears(months: MonthlyStat[]): YearStat[] {
    const totals: Map<string, number> = new Map<string, number>();
    for (const stat of months) {
      const year: string = stat.month.length >= 4 ? stat.month.substring(0, 4) : stat.month;
      const current: number | undefined = totals.get(year);
      totals.set(year, (current === undefined ? 0 : current) + stat.totalMs);
    }
    const rows: YearStat[] = [];
    totals.forEach((totalMs: number, year: string) => {
      rows.push({ year: year, totalMs: totalMs });
    });
    rows.sort((left: YearStat, right: YearStat) => right.year.localeCompare(left.year));
    return rows;
  }

  feedImage(feedId: number): string {
    const image: string | undefined = this.feedImages.get(feedId);
    return image === undefined ? '' : image;
  }

  maxFeedMs(): number {
    let max: number = 1;
    for (const stat of this.feeds) {
      if (stat.totalMs > max) {
        max = stat.totalMs;
      }
    }
    return max;
  }

  maxMonthMs(): number {
    let max: number = 1;
    for (const stat of this.months) {
      if (stat.totalMs > max) {
        max = stat.totalMs;
      }
    }
    return max;
  }

  maxYearMs(): number {
    let max: number = 1;
    for (const stat of this.years) {
      if (stat.totalMs > max) {
        max = stat.totalMs;
      }
    }
    return max;
  }

  maxUsageSize(): number {
    let max: number = 1;
    for (const usage of this.usages) {
      if (usage.size > max) {
        max = usage.size;
      }
    }
    return max;
  }

  /** 时长文本（0 时回退为 0:00，避免空字符串占位） */
  durationText(ms: number): string {
    const text: string = DurationUtils.format(ms);
    return text === '' ? '0:00' : text;
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
