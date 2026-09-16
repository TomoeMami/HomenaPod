import router from '@ohos.router';
import { EpisodeRepository, EpisodeHistoryRow } from '../db/repositories/EpisodeRepository';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { Feed } from '../model/Feed';
import { DbManager } from '../db/DbManager';
import { TABLE_FEED_MEDIA } from '../db/Tables';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { FeedItem } from '../model/FeedItem';
import { Playable } from '../model/Playable';
import { DurationUtils } from '../utils/DurationUtils';
import { DesignTokens } from '../common/DesignTokens';
import { openEpisodeDetail } from '../common/EpisodeRoute';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { SectionHeader } from '../components/SectionHeader';
import { EpisodeRow } from '../components/EpisodeRow';
import { EmptyState } from '../components/EmptyState';

/**
 * 播放历史页（对齐上游 `episodes_list_fragment.xml` + `PlaybackHistoryFragment`）：
 * 56vp 标题栏（返回箭头 + 「清除历史」trash 动作，列表非空时显示），
 * 下方为「继续收听」与「全部记录」两个区块，行均使用共享 `EpisodeRow`
 * （上游 `feeditemlist_item.xml`：56vp 封面 + 状态行 + 两行标题 + 位置/时长进度行）。
 */
@Entry
@Component
struct HistoryPage {
  @State rows: EpisodeHistoryRow[] = [];
  @State inProgress: EpisodeHistoryRow[] = [];
  @State loading: boolean = true;
  @State message: string = '';
  private feedImages: Map<number, string> = new Map<number, string>();

  build() {
    Column() {
      AppBar({ title: $r('app.string.setting_history'), showBack: true }) {
        if (this.rows.length > 0) {
          AppIconButton({
            symbol: $r('sys.symbol.trash'),
            onTap: () => {
              this.clearHistory();
            }
          })
        }
      }

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
      } else if (this.rows.length === 0) {
        Column() {
          EmptyState({
            icon: $r('sys.symbol.clock'),
            title: $r('app.string.history_empty'),
            sub: $r('app.string.history_empty_hint')
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: DesignTokens.SPACE_XS }) {
          if (this.inProgress.length > 0) {
            ListItem() {
              SectionHeader({
                title: $r('app.string.history_continue'),
                countPill: this.inProgress.length
              })
            }
            ForEach(this.inProgress, (row: EpisodeHistoryRow) => {
              ListItem() {
                this.historyRow(row)
              }
            }, (row: EpisodeHistoryRow) => 'progress-' + row.mediaId.toString())
          }

          ListItem() {
            SectionHeader({
              title: $r('app.string.history_all'),
              countPill: this.rows.length
            })
          }
          ForEach(this.rows, (row: EpisodeHistoryRow) => {
            ListItem() {
              this.historyRow(row)
            }
          }, (row: EpisodeHistoryRow) => 'row-' + row.mediaId.toString())
        }
        .layoutWeight(1)
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_M })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 历史行：上游 feeditemlist_item.xml —— 状态行（订阅名 · 最近播放）+ 标题 + 位置/时长进度行 */
  @Builder
  historyRow(row: EpisodeHistoryRow) {
    EpisodeRow({
      title: row.title,
      imageUrl: this.feedImage(row.feedId),
      metaText: this.metaText(row),
      positionText: this.positionText(row),
      durationText: this.durationText(row),
      progress: this.progress(row),
      isPlayed: row.played,
      actionIcon: $r('sys.symbol.play_fill'),
      actionTint: $r('app.color.primary'),
      onTap: () => {
        // 单击 = 打开单集详情页（与收件箱一致）；继续收听仍走右侧播放钮
        openEpisodeDetail(row.feedItemId);
      },
      onAction: () => {
        this.play(row);
      }
    })
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

      const rows: EpisodeHistoryRow[] = await EpisodeRepository.listHistory(200);
      this.rows = rows;
      this.inProgress = rows.filter((row: EpisodeHistoryRow) => row.position > 0
        && (row.duration <= 0 || row.position < row.duration - 1000));
    } catch (error) {
      this.rows = [];
      this.inProgress = [];
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  /** 清除播放历史（上游 PlaybackHistoryFragment 的 clear_history_item：重置播放位置与历史时间） */
  async clearHistory(): Promise<void> {
    try {
      await DbManager.executeSql(
        `UPDATE ${TABLE_FEED_MEDIA} SET position = 0, last_played_time_history = 0`
      );
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  async play(row: EpisodeHistoryRow): Promise<void> {
    try {
      const item: FeedItem | undefined = await EpisodeRepository.getById(row.feedItemId);
      if (item === undefined) {
        return;
      }
      const playable: Playable | undefined = await QueueEngine.toPlayable(item);
      if (playable === undefined) {
        return;
      }
      await QueueEngine.ensureQueued(item);
      await PlayerManager.load(playable, row.position, true);
      router.pushUrl({ url: 'pages/PlayerPage' });
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  feedImage(feedId: number): string {
    const image: string | undefined = this.feedImages.get(feedId);
    return image === undefined ? '' : image;
  }

  /** 状态行：订阅名 · 最近播放日期 */
  metaText(row: EpisodeHistoryRow): string {
    const parts: string[] = [];
    if (row.feedTitle !== '') {
      parts.push(row.feedTitle);
    }
    if (row.lastPlayedTime > 0) {
      parts.push(new Date(row.lastPlayedTime).toLocaleDateString());
    }
    return parts.join(' · ');
  }

  positionText(row: EpisodeHistoryRow): string {
    return row.position > 0 ? DurationUtils.format(row.position) : '';
  }

  durationText(row: EpisodeHistoryRow): string {
    return row.duration > 0 ? DurationUtils.format(row.duration) : '';
  }

  progress(row: EpisodeHistoryRow): number {
    if (row.duration <= 0 || row.position <= 0) {
      return 0;
    }
    const percent: number = Math.floor(row.position * 100 / row.duration);
    return percent > 100 ? 100 : (percent < 5 ? 5 : percent);
  }
}
