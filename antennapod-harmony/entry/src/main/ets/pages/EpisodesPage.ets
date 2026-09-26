import router from '@ohos.router';
import { EpisodeRepository, EpisodeListFilter, EpisodeListCursor } from '../db/repositories/EpisodeRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { FeedItem } from '../model/FeedItem';
import { MediaType, SortOrder } from '../model/Enums';
import { Playable } from '../model/Playable';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { DownloadManager } from '../download/DownloadManager';
import { EventHub, EventType, FeedItemUpdateData, EpisodeDownloadData } from '../events/EventHub';
import { DurationUtils } from '../utils/DurationUtils';
import { DesignTokens } from '../common/DesignTokens';
import { menuIcon } from '../common/MenuIcons';
import { openEpisodeDetail } from '../common/EpisodeRoute';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { OverflowButton } from '../components/OverflowButton';
import { EpisodeRow } from '../components/EpisodeRow';
import { EmptyState } from '../components/EmptyState';
import { TagChip } from '../components/TagChip';
import { LazyDataSource } from '../components/LazyDataSource';

/**
 * Episodes 全库总表（对照上游 AllEpisodesFragment）：
 * 所有订阅的单集聚合视图，支持 全部 / 未播放 / 已下载 / 继续收听 过滤、6 种排序、
 * 行内播放/下载、长按多选批量操作（标已播/未播、入队、下载、删除）。
 */
@Entry
@Component
struct EpisodesPage {
  @State items: FeedItem[] = [];
  /**
   * 列表数据源（LazyForEach 按需创建行）。
   * 全库单集可以有上万条，用 ForEach 会**一次性创建全部行组件**：
   * 实测 1.5 万条时主线程在 ArkUI 组件构建里卡死 6 s（appfreeze，见第48轮）。
   * LazyForEach 只建可视区那几行，容器本身也不再随每次 reload 重建。
   */
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  @State loading: boolean = true;
  @State message: string = '';
  @State filterMode: number = 0;
  @State sortOrder: SortOrder = SortOrder.DATE_NEW_OLD;
  @State showSortSheet: boolean = false;
  @State showActionSheet: boolean = false;
  @State actionItem: FeedItem | undefined = undefined;
  @State actionTitle: string = '';
  // 多选
  @State selecting: boolean = false;
  @State selectedIds: number[] = [];
  private favoriteIds: number[] = [];
  private queueIds: number[] = [];
  private downloadToken: number = -1;
  private messageTimerId: number = -1;
  /** 下一页游标（undefined = 没有下一页；首屏 / 换过滤 / 换排序后复位） */
  private cursor: EpisodeListCursor | undefined = undefined;
  /** 后面还有没有页（上一页取满了就当作有） */
  private hasMore: boolean = false;
  /** 已加载单集 id：翻页去重（游标边界上可能重复取到同一条） */
  private loadedIds: Set<number> = new Set<number>();
  /** 翻页重入闸门（onReachEnd 会连续触发） */
  private loadingMore: boolean = false;

  /**
   * 每页条数。全库单集可以有上万条（实测本机 1.5 万），**必须分页**：
   * 一次性读全库 + 逐条映射会把 JS 线程占住数秒（打开页面卡 3 s、reload 时列表消失 9 s，
   * 并在 ArkUI 组件构建里触发 THREAD_BLOCK_6S appfreeze）。
   */
  private static readonly PAGE_SIZE: number = 100;

  /** 过滤模式：0=全部 1=未播放 2=已下载 3=继续收听 */
  private static readonly FILTER_ALL: number = 0;
  private static readonly FILTER_UNPLAYED: number = 1;
  private static readonly FILTER_DOWNLOADED: number = 2;
  private static readonly FILTER_IN_PROGRESS: number = 3;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        AppBar({ title: $r('app.string.episodes_label'), showBack: true }) {
          Row({ space: DesignTokens.SPACE_XS }) {
            AppIconButton({
              symbol: $r('sys.symbol.magnifyingglass'),
              onTap: () => {
                router.pushUrl({ url: 'pages/SearchPage', params: { term: '' } });
              }
            })
            OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
              this.overflowMenu()
            }
          }
        }

        if (this.selecting) {
          this.selectionBar()
        }

        // 过滤胶囊行（上游 episodes 页的 filter 入口）
        Scroll() {
          Row({ space: DesignTokens.SPACE_XS }) {
            this.filterChip($r('app.string.filter_all'), EpisodesPage.FILTER_ALL)
            this.filterChip($r('app.string.filter_unplayed'), EpisodesPage.FILTER_UNPLAYED)
            this.filterChip($r('app.string.filter_downloaded'), EpisodesPage.FILTER_DOWNLOADED)
            this.filterChip($r('app.string.history_continue'), EpisodesPage.FILTER_IN_PROGRESS)
          }
          .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ bottom: DesignTokens.SPACE_S })

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_XS })
        }

        if (this.loading) {
          Text($r('app.string.loading'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
        } else if (this.items.length === 0) {
          Column() {
            EmptyState({ icon: $r('sys.symbol.music'), title: $r('app.string.placeholder_episodes') })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: DesignTokens.SPACE_XS }) {
            // 键值只取 id（LazyForEach 的键必须稳定）：下载进度等行内变化
            // 由 onDownloadEvent 里的 notifyDataChange(index) 驱动，不再靠键里编进度
            LazyForEach(this.dataSource, (item: FeedItem) => {
              ListItem() {
                this.episodeRow(item)
              }
            }, (item: FeedItem) => item.id.toString())
          }
          .layoutWeight(1)
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_XXL })
          .scrollBar(BarState.Off)
          .onReachEnd(() => {
            // 滚到底：按游标续读下一页（增量追加，不重建列表）
            this.loadMore();
          })
        }
      }
      .width('100%')
      .height('100%')

      if (this.showSortSheet) {
        this.sheetBackdrop(() => {
          this.showSortSheet = false;
        })
        this.sortSheet()
      }

      if (this.showActionSheet) {
        this.sheetBackdrop(() => {
          this.showActionSheet = false;
        })
        this.actionSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  sheetBackdrop(onClose: () => void) {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .onClick(() => {
        onClose();
      })
  }

  /** 多选操作条（对照上游 FloatingSelectMenu：选中计数 + 批量动作） */
  @Builder
  selectionBar() {
    Column({ space: DesignTokens.SPACE_S }) {
      Row({ space: DesignTokens.SPACE_S }) {
        Text(getContext(this).resourceManager.getStringSync($r('app.string.queue_selected')) + ' ' + this.selectedIds.length)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button($r('app.string.queue_cancel_select'))
          .fontSize(DesignTokens.FONT_CAPTION)
          .height(32)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.exitSelection();
          })
      }
      .width('100%')

      Scroll() {
        Row({ space: DesignTokens.SPACE_XS }) {
          this.selectionAction($r('sys.symbol.checkmark_circle'), $r('app.string.episode_mark_played'), () => {
            this.batchMarkPlayed(true);
          })
          this.selectionAction($r('sys.symbol.circle'), $r('app.string.episode_mark_unplayed'), () => {
            this.batchMarkPlayed(false);
          })
          this.selectionAction($r('sys.symbol.music_note_list'), $r('app.string.episode_add_queue'), () => {
            this.batchAddToQueue();
          })
          this.selectionAction($r('sys.symbol.arrow_down_circle'), $r('app.string.episode_download'), () => {
            this.batchDownload();
          })
          this.selectionAction($r('sys.symbol.trash'), $r('app.string.episode_delete_download'), () => {
            this.batchDeleteDownload();
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .padding({
      left: DesignTokens.PAGE_MARGIN,
      right: DesignTokens.PAGE_MARGIN,
      top: DesignTokens.SPACE_S,
      bottom: DesignTokens.SPACE_S
    })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_ROW)
    .margin({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
  }

  @Builder
  selectionAction(icon: Resource, label: ResourceStr, onTap: () => void) {
    Column({ space: DesignTokens.SPACE_XS }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_L)
        .fontColor([$r('app.color.text_secondary')])
      Text(label)
        .fontSize(DesignTokens.FONT_CAPTION)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
    }
    .padding(DesignTokens.SPACE_S)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  filterChip(label: ResourceStr, mode: number) {
    TagChip({
      label: label,
      selected: this.filterMode === mode,
      onTap: () => {
        this.filterMode = mode;
        this.load();
      }
    })
  }

  @Builder
  overflowMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.sort')), content: $r('app.string.feed_sort') })
        .onClick(() => {
          this.showSortSheet = true;
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.arrow_clockwise')), content: $r('app.string.refresh_label') })
        .onClick(() => {
          this.load();
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.checkmark_circle')), content: $r('app.string.multi_select') })
        .onClick(() => {
          this.selecting = true;
          this.selectedIds = [];
        })
    }
  }

  @Builder
  sortSheet() {
    Column({ space: 2 }) {
      Text($r('app.string.feed_sort'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .padding(DesignTokens.SPACE_L)
      this.sortOption($r('app.string.sort_date_new_old'), SortOrder.DATE_NEW_OLD)
      this.sortOption($r('app.string.sort_date_old_new'), SortOrder.DATE_OLD_NEW)
      this.sortOption($r('app.string.sort_title_a_z'), SortOrder.TITLE_A_Z)
      this.sortOption($r('app.string.sort_title_z_a'), SortOrder.TITLE_Z_A)
      this.sortOption($r('app.string.sort_duration_short_long'), SortOrder.DURATION_SHORT_LONG)
      this.sortOption($r('app.string.sort_duration_long_short'), SortOrder.DURATION_LONG_SHORT)
      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.PAGE_MARGIN })
        .onClick(() => {
          this.showSortSheet = false;
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
  }

  @Builder
  sortOption(label: ResourceStr, order: SortOrder) {
    Row({ space: DesignTokens.SPACE_S }) {
      SymbolGlyph(this.sortOrder === order ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
        .fontSize(DesignTokens.ICON_L)
        .fontColor([this.sortOrder === order ? $r('app.color.primary') : $r('app.color.text_tertiary')])
      Text(label)
        .fontSize(DesignTokens.FONT_SUBTITLE)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .onClick(() => {
      this.sortOrder = order;
      this.showSortSheet = false;
      this.load();
    })
  }

  @Builder
  actionSheet() {
    Column({ space: 2 }) {
      Text(this.actionTitle)
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_tertiary'))
        .maxLines(1)
        .padding(DesignTokens.SPACE_L)
      this.actionRow($r('sys.symbol.checkmark_circle'),
        this.actionItem !== undefined && this.actionItem!.isPlayed
          ? $r('app.string.episode_mark_unplayed') : $r('app.string.episode_mark_played'), () => {
          if (this.actionItem !== undefined) {
            this.togglePlayed(this.actionItem!);
          }
        })
      this.actionRow($r('sys.symbol.music_note_list'), $r('app.string.episode_add_queue'), () => {
        if (this.actionItem !== undefined) {
          this.addToQueue(this.actionItem!);
        }
      })
      this.actionRow($r('sys.symbol.star'), $r('app.string.favorites_button'), () => {
        if (this.actionItem !== undefined) {
          this.toggleFavorite(this.actionItem!);
        }
      })
      this.actionRow($r('sys.symbol.share'), $r('app.string.episode_share'), () => {
        if (this.actionItem !== undefined) {
          this.openEpisode(this.actionItem!);
        }
      })
      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.PAGE_MARGIN })
        .onClick(() => {
          this.showActionSheet = false;
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
  }

  @Builder
  actionRow(icon: Resource, label: ResourceStr, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_M }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_L)
        .fontColor([$r('app.color.text_secondary')])
      Text(label)
        .fontSize(DesignTokens.FONT_SUBTITLE)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left: DesignTokens.SPACE_S, top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
    .onClick(() => {
      this.showActionSheet = false;
      onTap();
    })
  }

  @Builder
  episodeRow(item: FeedItem) {
    EpisodeRow({
      title: item.title,
      subtitle: item.feedTitle,
      imageUrl: item.imageUrl !== '' ? item.imageUrl : item.feedImage,
      metaText: this.metaText(item),
      positionText: this.positionText(item),
      durationText: this.durationText(item),
      progress: this.progress(item),
      isPlayed: item.isPlayed,
      isNew: item.isNew(),
      isFavorite: this.favoriteIds.includes(item.id),
      inQueue: this.queueIds.includes(item.id),
      isVideo: item.media !== undefined && item.media.getMediaType() === MediaType.VIDEO,
      selected: this.selectedIds.includes(item.id),
      actionIcon: this.actionIcon(item),
      downloadProgress: this.downloadProgress(item),
      downloadIndeterminate: this.downloadIndeterminate(item),
      onTap: () => {
        if (this.selecting) {
          this.toggleSelected(item.id);
        } else {
          this.openEpisode(item);
        }
      },
      onAction: () => {
        if (this.selecting) {
          this.toggleSelected(item.id);
          return;
        }
        if (item.media === undefined) {
          return;
        }
        const state: string = this.downloadState(item);
        if (state === 'DONE') {
          this.play(item);
        } else if (state === 'RUNNING') {
          DownloadManager.pause(item.media.id);
        } else if (state === 'PAUSED') {
          // 暂停后必须能再点回继续（对照上游 ItemActionButton 的播放/暂停互toggle）
          DownloadManager.resume(item.media.id);
        } else {
          this.startDownload(item);
        }
      },
      onLongPress: () => {
        this.enterSelection(item.id);
      }
    })
  }

  aboutToAppear(): void {
    this.load();
    this.downloadToken = EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.onDownloadEvent(data);
    });
  }

  /**
   * 下载事件只刷新**受影响的那一行**（对照 QueuePage.onDownloadEvent）。
   * 以前这里是「key 里编进进度 + 换数组引用」逼 ForEach 重算键，LazyForEach 下改成
   * 精确定位后 `notifyDataChange(index)`：不会因为一次进度回调把整页 1.5 万条重新拉一遍。
   */
  private async onDownloadEvent(data: object): Promise<void> {
    const payload: EpisodeDownloadData = data as EpisodeDownloadData;
    const index: number = this.items.findIndex((entry: FeedItem) =>
    entry.media !== undefined && entry.media.id === payload.mediaId);
    if (index < 0) {
      return;
    }
    if (payload.state === 'DONE') {
      // file_url 变了，要重新查库才能把行切到「已下载」
      const fresh: FeedItem | undefined = await EpisodeRepository.getById(this.items[index].id);
      if (fresh === undefined) {
        return;
      }
      this.items[index] = fresh;
    }
    // RUNNING / PAUSED / PROGRESS / FAILED / REMOVED 只影响行内进度环，读 DownloadManager 即可
    this.dataSource.notifyDataChange(index);
  }

  aboutToDisappear(): void {
    if (this.downloadToken >= 0) {
      EventHub.unsubscribeToken(this.downloadToken);
      this.downloadToken = -1;
    }
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
      this.messageTimerId = -1;
    }
  }

  /** 顶部提示自动消失（上游是 Toast/Snackbar 语义），避免提示条永久占位 */
  private showMessage(text: string): void {
    this.message = text;
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
    }
    this.messageTimerId = setTimeout(() => {
      this.message = '';
      this.messageTimerId = -1;
    }, 3000);
  }

  /** 行内下载进度环的百分比；-1 = 不显示（对照上游 secondaryActionProgress） */
  private downloadProgress(item: FeedItem): number {
    if (item.media === undefined) {
      return -1;
    }
    return DownloadManager.getProgressPercent(item.media.id);
  }

  /** 总大小未知（进度不可确定）时环走等待动画 */
  private downloadIndeterminate(item: FeedItem): boolean {
    return item.media !== undefined && DownloadManager.isProgressIndeterminate(item.media.id);
  }

  async load(): Promise<void> {
    // 只有首屏（列表还是空的时候）才整页显示「加载中」：`loading` 是 build 里的**结构分支**，
    // 每次重载都置 true 会把整个 List 拆掉、加载完再重建 —— 全库 400 条时这条路径
    // 实测要 6 s+（主线程在 ArkUI 组件构建里，触发 appfreeze），批量操作后 reload 尤其明显。
    this.loading = this.items.length === 0;
    try {
      const items: FeedItem[] = await EpisodeRepository.listPage(
        this.currentFilter(), this.sortOrder, EpisodesPage.PAGE_SIZE);
      const favorites: FeedItem[] = await FavoritesRepository.list();
      const favoriteIds: number[] = favorites.map((entry: FeedItem) => entry.id);
      await QueueEngine.load();
      const queueIds: number[] = QueueEngine.getItems().map((entry: FeedItem) => entry.id);
      for (const item of items) {
        item.isFavorite = favoriteIds.includes(item.id);
        item.inQueue = queueIds.includes(item.id);
      }
      this.favoriteIds = favoriteIds;
      this.queueIds = queueIds;
      // 首屏：复位游标与去重集合，从第一页重新开始
      this.cursor = undefined;
      this.loadedIds = new Set<number>();
      this.items = items;
      this.dataSource.setData(items);
      this.remember(items);
      this.hasMore = items.length === EpisodesPage.PAGE_SIZE;
    } catch (error) {
      this.cursor = undefined;
      this.loadedIds = new Set<number>();
      this.hasMore = false;
      this.items = [];
      this.dataSource.setData([]);
      this.showMessage((error as Error).message);
    } finally {
      this.loading = false;
    }
  }

  /** 当前过滤胶囊对应的查询条件（首屏与翻页共用，两边必须完全一致） */
  private currentFilter(): EpisodeListFilter {
    const filter: EpisodeListFilter = new EpisodeListFilter();
    if (this.filterMode === EpisodesPage.FILTER_UNPLAYED) {
      filter.unplayedOnly = true;
    } else if (this.filterMode === EpisodesPage.FILTER_DOWNLOADED) {
      filter.downloadedOnly = true;
    } else if (this.filterMode === EpisodesPage.FILTER_IN_PROGRESS) {
      filter.inProgressOnly = true;
    }
    return filter;
  }

  /** 滚到底部：按游标续读下一页并增量追加（不重建列表，滚动位置不变） */
  async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore || this.cursor === undefined) {
      return;
    }
    this.loadingMore = true;
    try {
      const page: FeedItem[] = await EpisodeRepository.listPage(
        this.currentFilter(), this.sortOrder, EpisodesPage.PAGE_SIZE, this.cursor);
      // 游标边界上可能重复取到同一条：按 id 去重后再追加
      const fresh: FeedItem[] = page.filter((item: FeedItem) => !this.loadedIds.has(item.id));
      for (const item of fresh) {
        item.isFavorite = this.favoriteIds.includes(item.id);
        item.inQueue = this.queueIds.includes(item.id);
      }
      this.dataSource.appendData(fresh);
      this.items = this.dataSource.getDataArray();
      this.remember(page);
      this.hasMore = page.length === EpisodesPage.PAGE_SIZE;
    } catch (error) {
      this.hasMore = false;
      this.showMessage((error as Error).message);
    } finally {
      this.loadingMore = false;
    }
  }

  /** 记录本页已加载 id 与下一页游标（排序键 + id 双键，与 SQL 的 ORDER BY 一一对应） */
  private remember(items: FeedItem[]): void {
    for (const item of items) {
      this.loadedIds.add(item.id);
    }
    if (items.length === 0) {
      return;
    }
    const last: FeedItem = items[items.length - 1];
    this.cursor = {
      pubDate: last.pubDate,
      duration: last.media === undefined ? 0 : last.media.duration,
      title: last.title,
      id: last.id
    };
  }

  /** 下载按钮状态：优先看数据库 file_url，再看会话内任务状态（对照 FeedDetailPage.downloadState） */
  private downloadState(item: FeedItem): string {
    if (item.media === undefined) {
      return 'IDLE';
    }
    if (item.media.fileUrl !== '') {
      return 'DONE';
    }
    return DownloadManager.getStatus(item.media.id);
  }

  private actionIcon(item: FeedItem): Resource {
    const state: string = this.downloadState(item);
    if (state === 'DONE') {
      return $r('sys.symbol.play_fill');
    }
    if (state === 'RUNNING') {
      return $r('sys.symbol.pause_fill');
    }
    if (state === 'PAUSED') {
      return $r('sys.symbol.play_fill');
    }
    return $r('sys.symbol.arrow_down_circle');
  }

  private metaText(item: FeedItem): string {
    const parts: string[] = [];
    if (item.pubDate > 0) {
      parts.push(new Date(item.pubDate).toLocaleDateString());
    }
    if (item.media !== undefined && item.media.size > 0) {
      const mb: number = item.media.size / (1024 * 1024);
      parts.push(mb < 1 ? (item.media.size / 1024).toFixed(0) + ' KB' : mb.toFixed(1) + ' MB');
    }
    return parts.join(' · ');
  }

  private positionText(item: FeedItem): string {
    if (item.media === undefined || item.media.position <= 0) {
      return '';
    }
    return DurationUtils.format(item.media.position);
  }

  private durationText(item: FeedItem): string {
    if (item.media === undefined || item.media.duration <= 0) {
      return '';
    }
    return DurationUtils.format(item.media.duration);
  }

  private progress(item: FeedItem): number {
    if (item.media === undefined || item.media.duration <= 0 || item.media.position <= 0) {
      return 0;
    }
    const percent: number = Math.floor(item.media.position * 100 / item.media.duration);
    return percent > 100 ? 100 : (percent < 5 ? 5 : percent);
  }

  /**
   * 单击行 = 打开单集详情页（与收件箱一致）；播放由详情页主操作或行内播放钮触发。
   * 长按仍走本页的操作弹层（`openActionSheet`）。
   */
  private openEpisode(item: FeedItem): void {
    openEpisodeDetail(item.id);
  }

  async play(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    // 与其它入口统一走 QueueEngine.toPlayable：它会读每订阅设置（倍速 / 跳片头 / 跳片尾 / 音量适配）。
    // 旧实现把 speed 写死 1.0、其余写死 0，于是「列表行内按钮播放已下载单集」会丢掉订阅级倍速、
    // 落到全局默认倍速 —— 用户侧的表现是「同一集，下载的比在线的慢」（列表里未下载的单集按钮是
    // 下载而不是播放，想在线听只能进详情页，那条路读得到订阅级倍速，所以只有下载的会慢）。
    const playable: Playable | undefined = await QueueEngine.toPlayable(item);
    if (playable === undefined) {
      return;
    }
    await QueueEngine.ensureQueued(item);
    await PlayerManager.load(playable, item.media.position, true);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  async startDownload(item: FeedItem): Promise<void> {
    if (item.media === undefined || item.media.downloadUrl === '') {
      return;
    }
    try {
      await DownloadManager.startDownload(item.media, item.title);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.episode_downloading')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async togglePlayed(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.markPlayed(item.id, !item.isPlayed);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async addToQueue(item: FeedItem): Promise<void> {
    try {
      await QueueEngine.add(item);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.queue_added')));
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async toggleFavorite(item: FeedItem): Promise<void> {
    try {
      if (this.favoriteIds.includes(item.id)) {
        await FavoritesRepository.remove(item.id);
      } else {
        await FavoritesRepository.add(item.id, item.feedId);
      }
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  enterSelection(itemId: number): void {
    this.selecting = true;
    this.toggleSelected(itemId);
  }

  toggleSelected(itemId: number): void {
    if (this.selectedIds.includes(itemId)) {
      this.selectedIds = this.selectedIds.filter((id: number) => id !== itemId);
    } else {
      this.selectedIds = this.selectedIds.concat([itemId]);
    }
  }

  exitSelection(): void {
    this.selecting = false;
    this.selectedIds = [];
  }

  selectedItems(): FeedItem[] {
    return this.items.filter((item: FeedItem) => this.selectedIds.includes(item.id));
  }

  async batchMarkPlayed(played: boolean): Promise<void> {
    try {
      for (const item of this.selectedItems()) {
        await EpisodeRepository.markPlayed(item.id, played);
        const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
        EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      }
      this.exitSelection();
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchAddToQueue(): Promise<void> {
    try {
      for (const item of this.selectedItems()) {
        await QueueEngine.add(item);
      }
      this.exitSelection();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.queue_added')));
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchDownload(): Promise<void> {
    try {
      for (const item of this.selectedItems()) {
        if (item.media !== undefined && item.media.downloadUrl !== '' && item.media.fileUrl === '') {
          await DownloadManager.startDownload(item.media, item.title);
        }
      }
      this.exitSelection();
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchDeleteDownload(): Promise<void> {
    try {
      for (const item of this.selectedItems()) {
        if (item.media !== undefined && item.media.fileUrl !== '') {
          await DownloadManager.deleteFile(item.media);
        }
      }
      this.exitSelection();
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }
}
