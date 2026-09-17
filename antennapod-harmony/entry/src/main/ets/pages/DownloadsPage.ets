import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { Playable } from '../model/Playable';
import { DownloadLogEntry } from '../model/DownloadLogEntry';
import { MediaType, SortOrder } from '../model/Enums';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { DownloadLogRepository } from '../db/repositories/DownloadLogRepository';
import { DownloadManager } from '../download/DownloadManager';
import { DownloadErrorLabel } from '../common/DownloadErrorLabel';
import { RefreshService } from '../services/RefreshService';
import { AutoDownloadService } from '../services/AutoDownloadService';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { UserPreferences } from '../prefs/UserPreferences';
import {
  EventHub,
  EventType,
  EpisodeDownloadData,
  FeedItemUpdateData,
  FeedUpdateData,
  PlaybackPositionData,
  RefreshStateData
} from '../events/EventHub';
import { openEpisodeDetail } from '../common/EpisodeRoute';
import { DurationUtils } from '../utils/DurationUtils';
import { FileSizeUtils } from '../utils/FileSizeUtils';
import { DesignTokens } from '../common/DesignTokens';
import { menuIcon } from '../common/MenuIcons';
import {
  SwipeActionId,
  SwipeActionSpec,
  SwipeActions,
  SwipeScreen,
  isDestructiveSwipeAction,
  swipeActionSpec
} from '../common/SwipeActions';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { OverflowButton } from '../components/OverflowButton';
import { EpisodeRow } from '../components/EpisodeRow';
import { EmptyState } from '../components/EmptyState';
import { TagChip } from '../components/TagChip';
import { SwipeActionButton } from '../components/SwipeActionButton';
import { LazyDataSource } from '../components/LazyDataSource';

/** 下载页排序面板的一格（对照上游 DownloadsSortDialog.onAddItem 的四类） */
interface DownloadSortChip {
  label: Resource;
  ascending: SortOrder;
  descending: SortOrder;
  ascendingIsDefault: boolean;
}

/** 多选动作栏的一项（对照上游 episodes_apply_action_speeddial.xml + FeedItemMenuHandler） */
interface DownloadMenuItem {
  id: string;
  label: ResourceStr;
  icon: Resource;
  destructive: boolean;
}

/**
 * 下载页（对齐上游 `simple_list_fragment.xml` + `CompletedDownloadsFragment`）：
 * 56vp 标题栏（返回 / 搜索 / 下载记录 / 溢出菜单）+ 已下载单集列表（含进行中的下载）。
 * 行 = 共享 `EpisodeRow`（上游 `feeditemlist_item.xml` 几何）：单击进详情页、右侧 48vp 次级操作
 * （默认「删除文件」，偏好打开后改「播放」）、长按弹操作层、左右滑动按「已下载」屏的动作配置。
 * 下载记录（上游 `DownloadLogFragment` 底部弹层）与排序面板、确认框、移动网络确认均为页内弹层。
 */
@Entry
@Component
export struct DownloadsPage {
  /** 划出动作的完全展开距离（与首页一致） */
  private static readonly SWIPE_ACTION_DISTANCE: number = 88;
  /** 弹层最大高度（超过后内部滚动） */
  private static readonly SHEET_MAX_HEIGHT: number = 520;
  /** 移动网络确认的免打扰窗口：300 秒内不再弹（上游 DownloadActionButton.TIMEOUT_NETWORK_WARN_SECONDS） */
  private static readonly MOBILE_BYPASS_MS: number = 300 * 1000;
  /** DownloadLog.feedfiletype：订阅（对照上游 FeedFileType.FEED） */
  private static readonly FEED_FILE_TYPE_FEED: number = 1;
  /** 移动网络确认的免打扰截止时间（上游 static bypassCellularNetworkWarningTimer） */
  private static mobileBypassUntil: number = 0;

  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  @State items: FeedItem[] = [];
  @State loading: boolean = false;
  /** 是否已完成首次加载（骨架屏只在首次显示） */
  private loaded: boolean = false;
  @State message: string = '';
  @State refreshing: boolean = false;
  private refreshingNow: boolean = false;

  /** 行内状态：收藏 / 队列 / 当前播放项 */
  @State favoriteIds: number[] = [];
  @State queueIds: number[] = [];
  @State playingMediaId: number = 0;
  @State playingPosition: number = 0;
  @State playingDuration: number = 0;
  @State showRemainingTime: boolean = false;
  /** 行内按钮动作：false = 删除文件（上游默认），true = 播放（prefDownloadsButtonAction） */
  @State downloadsButtonPlay: boolean = false;
  @State downloadsSortOrder: SortOrder = SortOrder.DATE_NEW_OLD;
  private feedImages: Map<number, string> = new Map<number, string>();
  private feedTitles: Map<number, string> = new Map<number, string>();
  /** 行内取值回查表：列表不重建时行持有的是首帧对象 */
  private rowItems: Map<number, FeedItem> = new Map<number, FeedItem>();

  /** 多选（上游 ActionMode + FloatingSelectMenu） */
  @State selectMode: boolean = false;
  @State selectedIds: number[] = [];

  /** 滑动动作（屏幕 = CompletedDownloadsFragment） */
  @State swipeRightId: string = SwipeActionId.ADD_TO_QUEUE;
  @State swipeLeftId: string = SwipeActionId.DELETE;

  /** 下载记录弹层（上游 DownloadLogFragment） */
  @State showLogSheet: boolean = false;
  @State logEntries: DownloadLogEntry[] = [];
  @State logLoading: boolean = false;
  /** 日志详情对话框（上游 DownloadLogDetailsDialog） */
  @State showLogDetails: boolean = false;
  @State detailSuccessful: boolean = false;
  @State detailReason: string = '';
  @State detailTechnical: string = '';
  @State detailPodcast: string = '';
  @State detailEpisode: string = '';
  @State detailUrl: string = '';
  @State detailFeedId: number = 0;
  private detailEntry: DownloadLogEntry | undefined = undefined;

  /** 排序面板 / 操作弹层 / 确认框 */
  @State showSortSheet: boolean = false;
  @State showActionSheet: boolean = false;
  @State actionItem: FeedItem | undefined = undefined;
  @State actionTitle: string = '';
  @State showDeletePlayedDialog: boolean = false;
  /** 重试前的移动网络确认 */
  @State showMobileConfirm: boolean = false;
  private pendingLogRetry: DownloadLogEntry | undefined = undefined;

  @State infoTick: number = 0;

  private tokens: number[] = [];

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.selectMode) {
          this.selectHeader()
        } else {
          this.normalHeader()
        }

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
        }

        if (this.loading) {
          // 加载态：居中转圈 + 骨架行（上游 ProgressBar + adapter.setDummyViews）
          this.skeletonList()
        } else if (this.items.length === 0) {
          Column() {
            EmptyState({
              icon: $r('sys.symbol.download_1'),
              title: $r('app.string.no_comp_downloads_head_label'),
              sub: $r('app.string.downloads_empty_hint')
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          // 下拉刷新（上游 SwipeRefreshLayout：下拉 = 更新订阅）
          Refresh({ refreshing: this.refreshing }) {
            List({ space: DesignTokens.SPACE_XS }) {
              LazyForEach(this.dataSource, (item: FeedItem) => {
                ListItem() {
                  this.downloadRow(item)
                }
                .swipeAction(this.swipeOptions(item))
              }, (item: FeedItem) => this.rowKey(item))
            }
            .width('100%')
            .height('100%')
            .padding({
              left: DesignTokens.PAGE_MARGIN,
              right: DesignTokens.PAGE_MARGIN,
              bottom: this.selectMode ? 128 : DesignTokens.SPACE_M
            })
            .scrollBar(BarState.Off)
          }
          .layoutWeight(1)
          .onRefreshing(() => {
            this.refreshFeeds();
          })
        }
      }
      .width('100%')
      .height('100%')

      if (this.selectMode) {
        this.floatingSelectMenu()
      }

      if (this.showLogSheet) {
        this.sheetBackdrop(() => {
          this.showLogSheet = false;
        })
        this.logSheet()
      }
      if (this.showLogDetails) {
        this.logDetailsDialog()
      }
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
      if (this.showDeletePlayedDialog) {
        this.deletePlayedDialog()
      }
      if (this.showMobileConfirm) {
        this.sheetBackdrop(() => {
          this.showMobileConfirm = false;
          this.pendingLogRetry = undefined;
        })
        this.mobileConfirmSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  // ---------------------------------------------------------------- 标题栏

  /** 标题栏：返回 + 搜索 + 下载记录 + 溢出菜单（对照上游 downloads_completed.xml） */
  @Builder
  normalHeader() {
    AppBar({ title: $r('app.string.tab_downloads'), showBack: true }) {
      Row({ space: DesignTokens.SPACE_XS }) {
        AppIconButton({
          symbol: $r('sys.symbol.magnifyingglass'),
          onTap: () => {
            this.openSearch();
          }
        })
        AppIconButton({
          symbol: $r('sys.symbol.clock'),
          onTap: () => {
            this.openLogSheet();
          }
        })
        OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
          this.overflowMenu()
        }
      }
    }
  }

  /** 多选态标题栏（上游 ActionMode：N/M selected + 溢出 + 关闭） */
  @Builder
  selectHeader() {
    Row({ space: DesignTokens.SPACE_XS }) {
      Text($r('app.string.queue_selected_count', this.selectedIds.length.toString(), this.items.length.toString()))
        .fontSize(DesignTokens.FONT_SECTION)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
        this.selectMenu()
      }
      AppIconButton({
        symbol: $r('sys.symbol.xmark'),
        onTap: () => {
          this.exitSelectMode();
        }
      })
    }
    .width('100%')
    .height(DesignTokens.HEIGHT_APP_BAR)
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.SPACE_S })
  }

  /** 溢出菜单（上游 downloads_completed.xml 的溢出三项） */
  @Builder
  overflowMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.checkmark_circle')), content: $r('app.string.delete_downloads_played') })
        .onClick(() => {
          this.showDeletePlayedDialog = true;
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.arrow_clockwise')), content: $r('app.string.refresh_label') })
        .onClick(() => {
          this.refreshFeeds();
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.sort')), content: $r('app.string.sort_label') })
        .onClick(() => {
          this.openSortSheet();
        })
    }
  }

  /** 多选态溢出菜单（上游 multi_select_options.xml） */
  @Builder
  selectMenu() {
    Menu() {
      MenuItem({
        symbolStartIcon: menuIcon($r('sys.symbol.checkmark_circle')),
        content: this.allSelected() ? $r('app.string.deselect_all_label') : $r('app.string.select_all_label')
      })
        .onClick(() => {
          this.toggleSelectAll();
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.arrow_up')), content: $r('app.string.queue_select_all_above') })
        .onClick(() => {
          this.selectAllAbove();
        })
      MenuItem({
        symbolStartIcon: menuIcon($r('sys.symbol.arrow_down')),
        content: $r('app.string.queue_select_all_below')
      })
        .onClick(() => {
          this.selectAllBelow();
        })
    }
  }

  // ---------------------------------------------------------------- 行

  /** 行：已下载单集（含进行中的下载，上游按 URL 合并进同一列表） */
  @Builder
  downloadRow(item: FeedItem) {
    EpisodeRow({
      title: this.rowItem(item).title,
      imageUrl: this.rowImage(item),
      coverFallbackTitle: this.feedTitle(item.feedId),
      metaText: this.metaText(item),
      positionText: this.positionText(item),
      durationText: this.durationText(item),
      progress: this.progress(item),
      playing: this.isPlaying(item),
      isPlayed: this.rowItem(item).isPlayed,
      isNew: this.rowItem(item).isNew(),
      isFavorite: this.favoriteIds.includes(item.id),
      inQueue: this.queueIds.includes(item.id),
      isVideo: this.isVideo(item),
      selected: this.selectedIds.includes(item.id),
      showAction: true,
      actionIcon: this.rowActionIcon(item),
      actionTint: this.rowActionTint(item),
      downloadProgress: -1,
      onTap: () => {
        this.onRowTap(item);
      },
      onAction: () => {
        this.onRowAction(item);
      },
      onLongPress: () => {
        this.openActionSheet(item);
      }
    })
  }

  /** 骨架行（上游 adapter.setDummyViews：灰色占位块 + 居中转圈） */
  @Builder
  skeletonList() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: DesignTokens.SPACE_XS }) {
        ForEach([1, 2, 3, 4, 5], (index: number) => {
          Row({ space: DesignTokens.SPACE_L }) {
            Column()
              .width(DesignTokens.COVER_LIST)
              .height(DesignTokens.COVER_LIST)
              .borderRadius(8)
              .backgroundColor($r('app.color.surface_secondary'))
            Column({ space: DesignTokens.SPACE_S }) {
              Column()
                .width('70%')
                .height(12)
                .borderRadius(6)
                .backgroundColor($r('app.color.surface_secondary'))
              Column()
                .width('45%')
                .height(12)
                .borderRadius(6)
                .backgroundColor($r('app.color.surface_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: DesignTokens.SPACE_M, top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
        }, (index: number) => 'skeleton' + index.toString())
      }
      .width('100%')
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })

      LoadingProgress()
        .width(48)
        .height(48)
        .color($r('app.color.primary'))
    }
    .width('100%')
    .layoutWeight(1)
  }

  /** 划出动作配置（屏幕 = 已完成下载；关闭该屏滑动动作或某侧为「无」时不挂） */
  private swipeOptions(item: FeedItem): SwipeActionOptions {
    const options: SwipeActionOptions = {};
    if (!SwipeActions.isEnabled(SwipeScreen.DOWNLOADS)) {
      return options;
    }
    if (this.swipeRightId !== SwipeActionId.NONE) {
      const rightSpec: SwipeActionSpec = swipeActionSpec(this.swipeRightId);
      const rightItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(rightSpec, item);
        },
        actionAreaDistance: DownloadsPage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(this.swipeRightId, item);
        }
      };
      options.start = rightItem;
    }
    if (this.swipeLeftId !== SwipeActionId.NONE) {
      const leftSpec: SwipeActionSpec = swipeActionSpec(this.swipeLeftId);
      const leftItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(leftSpec, item);
        },
        actionAreaDistance: DownloadsPage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(this.swipeLeftId, item);
        }
      };
      options.end = leftItem;
    }
    return options;
  }

  @Builder
  swipeButton(spec: SwipeActionSpec, item: FeedItem) {
    SwipeActionButton({
      spec: spec,
      destructive: isDestructiveSwipeAction(spec.id),
      onTap: () => {
        this.runSwipeAction(spec.id, item);
      }
    })
  }

  /** 划出项动作分发（只调用本页已有方法） */
  private runSwipeAction(id: string, item: FeedItem): void {
    if (id === SwipeActionId.ADD_TO_QUEUE) {
      this.batchQueue([item], true);
      return;
    }
    if (id === SwipeActionId.REMOVE_FROM_QUEUE) {
      this.batchQueue([item], false);
      return;
    }
    if (id === SwipeActionId.START_DOWNLOAD) {
      this.downloadAction(item);
      return;
    }
    if (id === SwipeActionId.MARK_PLAYED) {
      this.batchMarkPlayed([item], true);
      return;
    }
    if (id === SwipeActionId.DELETE) {
      this.deleteDownload(item);
      return;
    }
    if (id === SwipeActionId.MARK_FAV) {
      this.batchFavorite([item], true);
      return;
    }
    if (id === SwipeActionId.REMOVE_FROM_FAVORITES) {
      this.batchFavorite([item], false);
      return;
    }
    if (id === SwipeActionId.SHARE) {
      this.share(item);
    }
    // 其余动作（MOVE_* / NONE）本页没有对应实现
  }

  // ---------------------------------------------------------------- 多选动作栏

  @Builder
  floatingSelectMenu() {
    Column() {
      Scroll() {
        Row({ space: DesignTokens.SPACE_XS }) {
          ForEach(this.menuItems(), (entry: DownloadMenuItem) => {
            this.selectAction(entry);
          }, (entry: DownloadMenuItem) => entry.id)
        }
        .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .height(112)
    }
    .width('100%')
    .height(112)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(8)
    .shadow({ radius: 16, color: '#26000000', offsetY: 4 })
    .margin({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.PAGE_MARGIN })
  }

  @Builder
  selectAction(entry: DownloadMenuItem) {
    Column({ space: DesignTokens.SPACE_S }) {
      SymbolGlyph(entry.icon)
        .fontSize(DesignTokens.ICON_XXL)
        .fontColor([entry.destructive ? $r('app.color.error') : $r('app.color.text_primary')])
      Text(entry.label)
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .width(80)
    }
    .justifyContent(FlexAlign.Center)
    .padding({ left: DesignTokens.SPACE_XS, right: DesignTokens.SPACE_XS, top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_S })
    .onClick(() => {
      this.runMenuAction(entry.id);
    })
  }

  /** 多选动作栏可见项（对照上游 onSelectedItemsUpdated：按选中集合状态逐项显隐） */
  private menuItems(): DownloadMenuItem[] {
    const selected: FeedItem[] = this.selectedItems();
    const entries: DownloadMenuItem[] = [];
    if (selected.length === 0) {
      return entries;
    }
    if (this.anySelected((item: FeedItem): boolean => this.canDeleteFile(item))) {
      entries.push({
        id: 'DELETE',
        label: $r('app.string.episode_delete_download'),
        icon: $r('sys.symbol.trash'),
        destructive: true
      });
    }
    if (this.anySelected((item: FeedItem): boolean => item.isPlayed)) {
      entries.push({
        id: 'MARK_UNPLAYED',
        label: $r('app.string.episode_mark_unplayed'),
        icon: $r('sys.symbol.circle'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem): boolean => !item.isPlayed)) {
      entries.push({
        id: 'MARK_PLAYED',
        label: $r('app.string.episode_mark_played'),
        icon: $r('sys.symbol.checkmark_circle'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem): boolean => !this.queueIds.includes(item.id))) {
      entries.push({
        id: 'ADD_QUEUE',
        label: $r('app.string.episode_add_queue'),
        icon: $r('sys.symbol.music_note_list'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem): boolean => this.queueIds.includes(item.id))) {
      entries.push({
        id: 'REMOVE_QUEUE',
        label: $r('app.string.swipe_action_remove_from_queue'),
        icon: $r('sys.symbol.xmark_circle'),
        destructive: true
      });
    }
    if (selected.length === 1) {
      entries.push({
        id: 'SHARE',
        label: $r('app.string.episode_share'),
        icon: $r('sys.symbol.share'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem): boolean => !this.favoriteIds.includes(item.id))) {
      entries.push({
        id: 'MARK_FAV',
        label: $r('app.string.add_to_favorites_label'),
        icon: $r('sys.symbol.star_fill'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem): boolean => this.favoriteIds.includes(item.id))) {
      entries.push({
        id: 'REMOVE_FAV',
        label: $r('app.string.remove_from_favorites_label'),
        icon: $r('sys.symbol.star'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem): boolean => this.hasPosition(item))) {
      entries.push({
        id: 'RESET_POSITION',
        label: $r('app.string.reset_playback_position_label'),
        icon: $r('sys.symbol.arrow_counterclockwise'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem): boolean => item.isNew())) {
      entries.push({
        id: 'REMOVE_INBOX',
        label: $r('app.string.remove_inbox_label'),
        icon: $r('sys.symbol.inbox'),
        destructive: false
      });
    }
    return entries;
  }

  private runMenuAction(id: string): void {
    const selected: FeedItem[] = this.selectedItems();
    if (id === 'DELETE') {
      this.batchDeleteDownload(selected);
    } else if (id === 'MARK_UNPLAYED') {
      this.batchMarkPlayed(selected, false);
    } else if (id === 'MARK_PLAYED') {
      this.batchMarkPlayed(selected, true);
    } else if (id === 'ADD_QUEUE') {
      this.batchQueue(selected, true);
    } else if (id === 'REMOVE_QUEUE') {
      this.batchQueue(selected, false);
    } else if (id === 'SHARE') {
      if (selected.length > 0) {
        this.share(selected[0]);
      }
    } else if (id === 'MARK_FAV') {
      this.batchFavorite(selected, true);
    } else if (id === 'REMOVE_FAV') {
      this.batchFavorite(selected, false);
    } else if (id === 'RESET_POSITION') {
      this.batchResetPosition(selected);
    } else if (id === 'REMOVE_INBOX') {
      this.batchRemoveFromInbox(selected);
    }
  }

  // ---------------------------------------------------------------- 下载记录弹层

  /** 底部弹层背板（点击关闭） */
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

  /**
   * 下载记录弹层（上游 `DownloadLogFragment` + `download_log_fragment.xml`）：
   * 自带标题栏（标题 + 清空历史）、空态、行内 16dp 状态图标 / 状态行 / 红色原因行 /
   * 「点按查看详情」提示 / 48dp 重试钮；行单击打开日志详情对话框。
   */
  @Builder
  logSheet() {
    Column() {
      Row({ space: DesignTokens.SPACE_XS }) {
        Text($r('app.string.downloads_log_label'))
          .fontSize(DesignTokens.FONT_SECTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        if (this.logEntries.length > 0) {
          AppIconButton({
            symbol: $r('sys.symbol.trash'),
            onTap: () => {
              this.clearHistory();
            }
          })
        }
        AppIconButton({
          symbol: $r('sys.symbol.xmark'),
          onTap: () => {
            this.showLogSheet = false;
          }
        })
      }
      .width('100%')
      .height(DesignTokens.HEIGHT_APP_BAR)
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.SPACE_S })

      if (this.logLoading) {
        Stack({ alignContent: Alignment.Center }) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('app.color.primary'))
        }
        .width('100%')
        .layoutWeight(1)
      } else if (this.logEntries.length === 0) {
        Column() {
          EmptyState({
            icon: $r('sys.symbol.download_1'),
            title: $r('app.string.no_log_downloads_head_label'),
            sub: $r('app.string.no_log_downloads_label')
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: DesignTokens.SPACE_XS }) {
          ForEach(this.logEntries, (entry: DownloadLogEntry, index: number) => {
            ListItem() {
              this.logRow(entry, index)
            }
          }, (entry: DownloadLogEntry) => 'log-' + entry.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_M })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .constraintSize({ maxHeight: DownloadsPage.SHEET_MAX_HEIGHT })
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  /** 日志行（上游 `downloadlog_item.xml`：无封面 + 前置图标 + 状态行 + 原因行 + 详情提示 + 重试钮） */
  @Builder
  logRow(entry: DownloadLogEntry, index: number) {
    Row() {
      Column({ space: 2 }) {
        Row({ space: DesignTokens.SPACE_XS }) {
          SymbolGlyph(this.logIcon(entry))
            .fontSize(DesignTokens.ICON_XS)
            .fontColor([this.logIconTint(entry)])
          Text(this.logTitle(entry))
            .fontSize(DesignTokens.FONT_BODY)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')

        Text(this.logStatusText(entry))
          .fontSize(DesignTokens.FONT_CAPTION)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)

        if (!entry.successful) {
          Text(this.logReasonText(entry))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.error'))
            .width('100%')
          Text($r('app.string.download_error_tap_for_details'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })

      if (this.showLogRetry(entry, index)) {
        Stack() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(DesignTokens.ICON_XL)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width(48)
        .height(48)
        .alignContent(Alignment.Center)
        .onClick(() => {
          this.retryLogEntry(entry);
        })
      }
    }
    .width('100%')
    .padding({ left: DesignTokens.SPACE_L, right: DesignTokens.SPACE_S })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_ROW)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openLogDetails(entry);
    })
  }

  /** 日志行状态图标（上游：成功 ic_check / 失败 ic_error / 重复 ic_info） */
  private logIcon(entry: DownloadLogEntry): Resource {
    if (entry.successful) {
      return $r('sys.symbol.checkmark');
    }
    // 「文件已存在」对应上游的「重复」这一类，用 info 图标
    return DownloadErrorLabel.isFileAlreadyExists(DownloadErrorLabel.parseCode(entry.reasonDetailed))
      ? $r('sys.symbol.info_circle') : $r('sys.symbol.exclamationmark_circle');
  }

  private logIconTint(entry: DownloadLogEntry): ResourceColor {
    if (entry.successful) {
      return $r('app.color.success');
    }
    return DownloadErrorLabel.isFileAlreadyExists(DownloadErrorLabel.parseCode(entry.reasonDetailed))
      ? $r('app.color.text_secondary') : $r('app.color.error');
  }

  private logTitle(entry: DownloadLogEntry): string {
    return entry.downloadStatusTitle === ''
      ? this.text($r('app.string.download_log_title_unknown')) : entry.downloadStatusTitle;
  }

  /** 状态行：类型 · 相对时间（上游 DownloadLogAdapter 的 "Media file · 5 minutes ago"） */
  private logStatusText(entry: DownloadLogEntry): string {
    const type: string = entry.feedFileType === DownloadsPage.FEED_FILE_TYPE_FEED
      ? this.text($r('app.string.download_type_feed')) : this.text($r('app.string.download_type_media'));
    const time: string = this.relativeTime(entry.completionDate);
    return time === '' ? type : type + ' · ' + time;
  }

  /** 相对时间（上游 DateUtils.getRelativeTimeSpanString 的等价实现，走资源串） */
  private relativeTime(epochMillis: number): string {
    if (epochMillis <= 0) {
      return '';
    }
    const diffSeconds: number = Math.floor((Date.now() - epochMillis) / 1000);
    if (diffSeconds < 60) {
      return this.text($r('app.string.time_just_now'));
    }
    if (diffSeconds < 3600) {
      return this.textArg($r('app.string.time_minutes_ago'), Math.floor(diffSeconds / 60));
    }
    if (diffSeconds < 86400) {
      return this.textArg($r('app.string.time_hours_ago'), Math.floor(diffSeconds / 3600));
    }
    if (diffSeconds < 86400 * 7) {
      return this.textArg($r('app.string.time_days_ago'), Math.floor(diffSeconds / 86400));
    }
    return new Date(epochMillis).toLocaleDateString();
  }

  /**
   * 失败原因文案：`code=N` 走 11 种 request 错误码映射，其余（订阅更新失败等）原样展示。
   * 按**资源名**取字符串：`$r('app.string.' + name)` 这种运行期拼接在真机上拿到的是 id 0。
   */
  private logReasonText(entry: DownloadLogEntry): string {
    const code: number = DownloadErrorLabel.parseCode(entry.reasonDetailed);
    if (code < 0) {
      return entry.reasonDetailed;
    }
    return getContext(this).resourceManager.getStringByNameSync(DownloadErrorLabel.resourceName(code));
  }

  /** 重试钮显隐（上游 newerWasSuccessful：更新的记录里已有成功记录时不再显示） */
  private showLogRetry(entry: DownloadLogEntry, index: number): boolean {
    if (entry.successful) {
      return false;
    }
    for (let i: number = 0; i < index; i++) {
      const other: DownloadLogEntry = this.logEntries[i];
      if (other.feedFileType === entry.feedFileType && other.feedFileId === entry.feedFileId
        && other.successful) {
        return false;
      }
    }
    return true;
  }

  /** 日志详情对话框（上游 DownloadLogDetailsDialog：播客 / 单集 / 状态 / 技术细节 / 文件 URL） */
  @Builder
  logDetailsDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showLogDetails = false;
        })
      Column({ space: DesignTokens.SPACE_M }) {
        Text($r('app.string.download_error_details'))
          .fontSize(DesignTokens.FONT_SECTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        if (this.detailPodcast !== '') {
          Row({ space: DesignTokens.SPACE_S }) {
            Column({ space: 2 }) {
              Text($r('app.string.feed_label'))
                .fontSize(DesignTokens.FONT_PARAGRAPH)
                .fontColor($r('app.color.text_secondary'))
              Text(this.detailPodcast)
                .fontSize(DesignTokens.FONT_PARAGRAPH)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (this.detailFeedId > 0) {
              Text($r('app.string.download_log_open_feed'))
                .fontSize(DesignTokens.FONT_PARAGRAPH)
                .fontColor($r('app.color.primary'))
                .padding({
                  left: DesignTokens.SPACE_M,
                  right: DesignTokens.SPACE_M,
                  top: DesignTokens.SPACE_S,
                  bottom: DesignTokens.SPACE_S
                })
                .onClick(() => {
                  this.openDetailFeed();
                })
            }
          }
          .width('100%')
        }

        if (this.detailEpisode !== '') {
          Column({ space: 2 }) {
            Text($r('app.string.episode_label'))
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .fontColor($r('app.color.text_secondary'))
            Text(this.detailEpisode)
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Column({ space: 2 }) {
          Text($r('app.string.download_log_details_human_readable_reason_title'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_secondary'))
          Text(this.detailReason)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor(this.detailSuccessful ? $r('app.color.text_primary') : $r('app.color.error'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Text($r('app.string.download_log_details_technical_reason_title'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_secondary'))
          Text(this.detailTechnical)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.copyText(this.detailTechnical);
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.detailUrl !== '') {
          Column({ space: 2 }) {
            Text($r('app.string.download_log_details_file_url_title'))
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .fontColor($r('app.color.text_secondary'))
            Text(this.detailUrl)
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .fontColor($r('app.color.text_primary'))
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.copyText(this.detailUrl);
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Row({ space: DesignTokens.SPACE_M }) {
          Button($r('app.string.copy_to_clipboard'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.copyDetails();
            })
          Button($r('app.string.dialog_ok'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .backgroundColor($r('app.color.primary'))
            .fontColor($r('app.color.on_primary'))
            .onClick(() => {
              this.showLogDetails = false;
            })
        }
        .width('100%')
        .margin({ top: DesignTokens.SPACE_S })
      }
      .width('86%')
      .constraintSize({ maxHeight: DownloadsPage.SHEET_MAX_HEIGHT })
      .backgroundColor($r('app.color.surface'))
      .borderRadius(DesignTokens.RADIUS_CARD)
      .padding(DesignTokens.SPACE_XL)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  // ---------------------------------------------------------------- 排序面板

  /** 排序面板（上游 DownloadsSortDialog：日期 / 单集标题 / 时长 / 大小，激活项带 ▲▼） */
  @Builder
  sortSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      Column({ space: DesignTokens.SPACE_S }) {
        ForEach(this.sortChipRows(), (row: DownloadSortChip[], rowIndex: number) => {
          Row({ space: DesignTokens.SPACE_S }) {
            ForEach(row, (chip: DownloadSortChip) => {
              Row() {
                TagChip({
                  label: this.sortChipLabel(chip),
                  selected: this.isSortChipActive(chip),
                  onTap: () => {
                    this.pickSortChip(chip);
                  }
                })
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            }, (chip: DownloadSortChip) => chip.ascending.toString() + '-' + chip.descending.toString())
          }
          .width('100%')
        }, (row: DownloadSortChip[], rowIndex: number) => 'downloadSortRow' + rowIndex.toString())
      }
      .width('100%')

      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .margin({ bottom: DesignTokens.SPACE_S })
        .onClick(() => {
          this.showSortSheet = false;
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, top: DesignTokens.SPACE_XL })
  }

  private sortChips(): DownloadSortChip[] {
    const chips: DownloadSortChip[] = [];
    chips.push({
      label: $r('app.string.sort_date_label'),
      ascending: SortOrder.DATE_OLD_NEW,
      descending: SortOrder.DATE_NEW_OLD,
      // 上游 DownloadsSortDialog：日期默认降序（新→旧）
      ascendingIsDefault: false
    });
    chips.push({
      label: $r('app.string.sort_episode_title'),
      ascending: SortOrder.TITLE_A_Z,
      descending: SortOrder.TITLE_Z_A,
      ascendingIsDefault: true
    });
    chips.push({
      label: $r('app.string.sort_duration_label'),
      ascending: SortOrder.DURATION_SHORT_LONG,
      descending: SortOrder.DURATION_LONG_SHORT,
      ascendingIsDefault: true
    });
    chips.push({
      label: $r('app.string.size'),
      ascending: SortOrder.SIZE_SMALL_LARGE,
      descending: SortOrder.SIZE_LARGE_SMALL,
      // 上游：大小默认降序（大→小）
      ascendingIsDefault: false
    });
    return chips;
  }

  private sortChipRows(): DownloadSortChip[][] {
    const chips: DownloadSortChip[] = this.sortChips();
    const rows: DownloadSortChip[][] = [];
    for (let i: number = 0; i < chips.length; i += 2) {
      const row: DownloadSortChip[] = [chips[i]];
      if (i + 1 < chips.length) {
        row.push(chips[i + 1]);
      }
      rows.push(row);
    }
    return rows;
  }

  private isSortChipActive(chip: DownloadSortChip): boolean {
    return this.downloadsSortOrder === chip.ascending || this.downloadsSortOrder === chip.descending;
  }

  private sortChipLabel(chip: DownloadSortChip): ResourceStr {
    if (!this.isSortChipActive(chip)) {
      return chip.label;
    }
    const arrow: string = this.downloadsSortOrder === chip.ascending ? ' ▲' : ' ▼';
    return this.text(chip.label) + arrow;
  }

  private async pickSortChip(chip: DownloadSortChip): Promise<void> {
    let order: SortOrder = chip.ascendingIsDefault ? chip.ascending : chip.descending;
    if (this.isSortChipActive(chip)) {
      order = this.downloadsSortOrder === chip.ascending ? chip.descending : chip.ascending;
    }
    this.downloadsSortOrder = order;
    UserPreferences.setDownloadsSortedOrder(order);
    // 首页「管理下载」区块也按这个偏好排序，广播让它重排
    const data: FeedUpdateData = { feedId: 0 };
    EventHub.publish(EventType.FEED_LIST_UPDATE, data);
    await this.load();
  }

  // ---------------------------------------------------------------- 操作弹层

  /** 长按操作弹层（上游 feeditemlist_context.xml + FeedItemMenuHandler） */
  @Builder
  actionSheet() {
    Scroll() {
      Column({ space: 2 }) {
        Text(this.actionTitle)
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding(DesignTokens.SPACE_L)

        if (this.actionIsPlaying()) {
          this.actionRow($r('sys.symbol.forward_end_fill'), $r('app.string.skip_episode_label'), () => {
            this.skipEpisode();
          })
        }
        if (this.actionItemIsNew()) {
          this.actionRow($r('sys.symbol.inbox'), $r('app.string.remove_inbox_label'), () => {
            this.removeFromInboxItem();
          })
        }
        if (this.actionItemPlayed()) {
          this.actionRow($r('sys.symbol.circle'), $r('app.string.episode_mark_unplayed'), () => {
            this.markPlayedItem(false);
          })
        } else {
          this.actionRow($r('sys.symbol.checkmark_circle'), $r('app.string.episode_mark_played'), () => {
            this.markPlayedItem(true);
          })
        }
        if (this.actionItemInQueue()) {
          this.actionRow($r('sys.symbol.xmark_circle'), $r('app.string.swipe_action_remove_from_queue'), () => {
            this.queueItem(false);
          })
        } else {
          this.actionRow($r('sys.symbol.music_note_list'), $r('app.string.episode_add_queue'), () => {
            this.queueItem(true);
          })
        }
        if (this.actionItemDeletable()) {
          this.actionRow($r('sys.symbol.trash'), $r('app.string.episode_delete_download'), () => {
            this.deleteItem();
          })
        }
        if (this.actionItemDownloading()) {
          // 进行中的下载：取消下载（行内按钮是暂停/继续，取消在这里，对照上游 CancelDownloadActionButton）
          this.actionRow($r('sys.symbol.xmark_circle'), $r('app.string.episode_download_cancel'), () => {
            this.cancelItem();
          })
        }
        if (this.actionItemFavorite()) {
          this.actionRow($r('sys.symbol.star'), $r('app.string.remove_from_favorites_label'), () => {
            this.favoriteItem(false);
          })
        } else {
          this.actionRow($r('sys.symbol.star_fill'), $r('app.string.add_to_favorites_label'), () => {
            this.favoriteItem(true);
          })
        }
        if (this.actionItemHasPosition()) {
          this.actionRow($r('sys.symbol.arrow_counterclockwise'), $r('app.string.reset_playback_position_label'), () => {
            this.resetPositionItem();
          })
        }
        this.actionRow($r('sys.symbol.share'), $r('app.string.episode_share'), () => {
          this.shareItem();
        })
        this.actionRow($r('sys.symbol.checkmark_circle'), $r('app.string.multi_select'), () => {
          this.startSelectFromSheet();
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
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
    }
    .constraintSize({ maxHeight: DownloadsPage.SHEET_MAX_HEIGHT })
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
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
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .padding({ left: DesignTokens.SPACE_S, top: DesignTokens.SPACE_XS, bottom: DesignTokens.SPACE_XS })
    .onClick(() => {
      this.showActionSheet = false;
      onTap();
    })
  }

  /** 「删除已播放的下载」确认框（上游 ConfirmationDialog） */
  @Builder
  deletePlayedDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showDeletePlayedDialog = false;
        })
      Column({ space: DesignTokens.SPACE_M }) {
        Text($r('app.string.delete_downloads_played'))
          .fontSize(DesignTokens.FONT_SECTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text($r('app.string.delete_downloads_played_confirmation'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Row({ space: DesignTokens.SPACE_M }) {
          Button($r('app.string.dialog_cancel'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.showDeletePlayedDialog = false;
            })
          Button($r('app.string.delete_downloads_played'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .backgroundColor($r('app.color.error'))
            .fontColor($r('app.color.on_primary'))
            .onClick(() => {
              this.deletePlayedDownloads();
            })
        }
        .width('100%')
        .margin({ top: DesignTokens.SPACE_S })
      }
      .width('86%')
      .backgroundColor($r('app.color.surface'))
      .borderRadius(DesignTokens.RADIUS_CARD)
      .padding(DesignTokens.SPACE_XL)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  /** 移动网络确认（上游 confirm_mobile_download_dialog_*：允许本次 / 取消，300 秒内免打扰） */
  @Builder
  mobileConfirmSheet() {
    Column({ space: DesignTokens.SPACE_L }) {
      Text($r('app.string.confirm_mobile_download_dialog_title'))
        .fontSize(DesignTokens.FONT_SECTION)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .padding({ top: DesignTokens.SPACE_XL, left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
      Text($r('app.string.confirm_mobile_download_dialog_message'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showMobileConfirm = false;
            this.pendingLogRetry = undefined;
          })
        Button($r('app.string.confirm_mobile_download_dialog_allow_this_time'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            this.confirmMobileDownload();
          })
      }
      .width('90%')
      .margin({ bottom: DesignTokens.SPACE_L })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  // ---------------------------------------------------------------- 生命周期

  aboutToAppear(): void {
    this.downloadsButtonPlay = UserPreferences.getDownloadsButtonPlay();
    this.downloadsSortOrder = UserPreferences.getDownloadsSortedOrder() as SortOrder;
    this.showRemainingTime = UserPreferences.getShowRemainingTime();
    this.loadSwipeActions();
    this.refreshing = RefreshService.isRunning();
    this.load();

    this.tokens.push(EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.onDownloadEvent(data);
    }));
    this.tokens.push(EventHub.subscribe(EventType.FEED_ITEM_UPDATE, () => {
      this.load();
    }));
    // 整库刷新状态（上游 sticky FeedUpdateRunningEvent）驱动下拉刷新指示
    this.tokens.push(EventHub.subscribe(EventType.REFRESH_STATE, (data: object) => {
      const state: RefreshStateData = data as RefreshStateData;
      this.refreshing = state.running;
    }));
    // 播放状态 / 播放位置：行内播放高亮与进度条
    this.tokens.push(EventHub.subscribe(EventType.PLAYER_STATUS, () => {
      this.refreshPlaying();
    }));
    this.tokens.push(EventHub.subscribe(EventType.PLAYBACK_POSITION, (data: object) => {
      this.updatePlayingPosition(data);
    }));
    this.tokens.push(EventHub.subscribe(EventType.DOWNLOADS_CHANGED, () => {
      this.load();
    }));
    this.tokens.push(EventHub.subscribe(EventType.SWIPE_ACTIONS_CHANGED, () => {
      this.loadSwipeActions();
    }));
    this.tokens.push(EventHub.subscribe(EventType.PREFS_CHANGED, () => {
      this.downloadsButtonPlay = UserPreferences.getDownloadsButtonPlay();
      this.showRemainingTime = UserPreferences.getShowRemainingTime();
      this.infoTick = this.infoTick + 1;
    }));
    // 下载记录变化：弹层开着时同步刷新
    this.tokens.push(EventHub.subscribe(EventType.DOWNLOAD_LOG, () => {
      if (this.showLogSheet) {
        this.loadLog();
      }
    }));
  }

  aboutToDisappear(): void {
    for (const token of this.tokens) {
      EventHub.unsubscribeToken(token);
    }
    this.tokens = [];
  }

  onDownloadEvent(data: object): void {
    const payload: EpisodeDownloadData = data as EpisodeDownloadData;
    if (payload.state === 'PROGRESS') {
      // 进度：只重绘这一行（键里编了进度，行才会重建）
      const index: number = this.items.findIndex((entry: FeedItem) =>
      entry.media !== undefined && entry.media.id === payload.mediaId);
      if (index >= 0) {
        this.dataSource.notifyDataChange(index);
      }
      return;
    }
    if (payload.state === 'DONE' || payload.state === 'REMOVED' || payload.state === 'FAILED') {
      this.load();
      if (this.showLogSheet) {
        this.loadLog();
      }
    }
  }

  // ---------------------------------------------------------------- 数据

  /** 已下载单集 + 进行中的下载（上游 CompletedDownloadsFragment.loadItems 的合并顺序：进行中在前） */
  async load(): Promise<void> {
    // 骨架屏只在首次加载出现：下载事件（开始/暂停/完成）会频繁触发重载，
    // 每次都闪一次骨架会让人以为列表在重置
    if (!this.loaded) {
      this.loading = true;
    }
    try {
      const downloaded: FeedItem[] = await EpisodeRepository.listDownloadedItems(0, this.downloadsSortOrder);
      const seen: Set<number> = new Set<number>();
      for (const item of downloaded) {
        seen.add(item.id);
      }
      const active: FeedItem[] = [];
      const tasks: Map<number, string> = DownloadManager.getActiveTasks();
      const activeIds: number[] = [];
      tasks.forEach((state: string, mediaId: number) => {
        const current: string = DownloadManager.getStatus(mediaId);
        if (current === 'RUNNING' || current === 'PAUSED') {
          activeIds.push(mediaId);
        }
      });
      // 进行中的下载按排序偏好排在前部（上游把 runningDownloads 的结果 addAll 在已下载之前）
      for (const mediaId of activeIds) {
        const item: FeedItem | undefined = await EpisodeRepository.getByMediaId(mediaId);
        if (item !== undefined && !seen.has(item.id)) {
          // `getByMediaId` 只查单集行：行内的下载状态 / 进度 / 时长都依赖媒体记录，必须补查
          item.media = await this.mediaOf(item);
          seen.add(item.id);
          active.push(item);
        }
      }
      const all: FeedItem[] = active.concat(downloaded);
      const rowItems: Map<number, FeedItem> = new Map<number, FeedItem>();
      for (const item of all) {
        rowItems.set(item.id, item);
      }
      this.rowItems = rowItems;
      // 顺序（键值）没变时静默换数据：不重建列表，滚动位置与行内动画都保住
      const sameOrder: boolean = all.length === this.items.length
        && all.every((entry: FeedItem, index: number) => entry.id === this.items[index].id);
      if (sameOrder) {
        this.dataSource.replaceData(all);
      } else {
        this.dataSource.setData(all);
      }
      this.items = all;
      await this.loadFeeds(all);
      this.favoriteIds = await FavoritesRepository.listIds();
      this.queueIds = QueueEngine.getItems().map((item: FeedItem) => item.id);
      this.refreshPlaying();
    } catch (error) {
      this.items = [];
      this.dataSource.setData([]);
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
      this.loaded = true;
    }
  }

  /** 列表涉及订阅的标题 / 封面（行封面回落与占位文字用） */
  private async loadFeeds(items: FeedItem[]): Promise<void> {
    const ids: number[] = [];
    for (const item of items) {
      ids.push(item.feedId);
    }
    const feeds: Feed[] = await FeedRepository.listByIds(ids);
    const titles: Map<number, string> = new Map<number, string>();
    const images: Map<number, string> = new Map<number, string>();
    for (const feed of feeds) {
      titles.set(feed.id, feed.getTitle());
      images.set(feed.id, feed.imageUrl);
    }
    this.feedTitles = titles;
    this.feedImages = images;
  }

  private async loadLog(): Promise<void> {
    this.logLoading = true;
    try {
      this.logEntries = await DownloadLogRepository.list();
    } catch (error) {
      this.logEntries = [];
      this.message = (error as Error).message;
    } finally {
      this.logLoading = false;
    }
  }

  private loadSwipeActions(): void {
    const actions: string[] = SwipeActions.resolve(SwipeScreen.DOWNLOADS);
    this.swipeRightId = actions[0];
    this.swipeLeftId = actions[1];
  }

  /** 当前播放项（上游 PlaybackStatus.isPlaying：只认 PlayerManager 里装载的那一集） */
  private refreshPlaying(): void {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    const mediaId: number = playable === undefined ? 0 : playable.id;
    if (mediaId === this.playingMediaId) {
      return;
    }
    this.playingMediaId = mediaId;
    this.playingPosition = playable === undefined ? 0 : playable.position;
    this.playingDuration = playable === undefined ? 0 : playable.duration;
  }

  private updatePlayingPosition(data: object): void {
    const payload: PlaybackPositionData = data as PlaybackPositionData;
    if (payload.time !== undefined) {
      this.playingPosition = payload.time;
    }
    if (payload.duration !== undefined && payload.duration > 0) {
      this.playingDuration = payload.duration;
    }
  }

  /** 打开下载记录弹层 */
  private async openLogSheet(): Promise<void> {
    this.showLogSheet = true;
    await this.loadLog();
  }

  private openSearch(): void {
    router.pushUrl({ url: 'pages/SearchPage', params: { term: '' } });
  }

  private async openLogDetails(entry: DownloadLogEntry): Promise<void> {
    this.detailEntry = entry;
    this.detailSuccessful = entry.successful;
    this.detailReason = entry.successful
      ? this.text($r('app.string.download_successful')) : this.logReasonText(entry);
    this.detailTechnical = entry.successful
      ? this.text($r('app.string.download_successful')) : entry.reasonDetailed;
    this.detailPodcast = '';
    this.detailEpisode = '';
    this.detailUrl = '';
    this.detailFeedId = 0;
    try {
      if (entry.feedFileType === DownloadsPage.FEED_FILE_TYPE_FEED) {
        const feed: Feed | undefined = await FeedRepository.getById(entry.feedFileId);
        if (feed !== undefined) {
          this.detailPodcast = feed.getTitle();
          this.detailUrl = feed.downloadUrl;
          this.detailFeedId = feed.isSubscribed() ? feed.id : 0;
        } else {
          this.detailPodcast = this.logTitle(entry);
        }
      } else {
        const item: FeedItem | undefined = await EpisodeRepository.getByMediaId(entry.feedFileId);
        if (item !== undefined) {
          this.detailEpisode = item.title;
          // getByMediaId 只查单集行（不含媒体），下载 URL 要单独回查媒体表
          const media: FeedMedia | undefined = await this.mediaOf(item);
          this.detailUrl = media === undefined ? '' : media.downloadUrl;
          const feed: Feed | undefined = await FeedRepository.getById(item.feedId);
          if (feed !== undefined) {
            this.detailPodcast = feed.getTitle();
            this.detailFeedId = feed.isSubscribed() ? feed.id : 0;
          }
        } else {
          this.detailEpisode = this.logTitle(entry);
        }
      }
    } catch (error) {
      this.message = (error as Error).message;
    }
    this.showLogDetails = true;
  }

  private openDetailFeed(): void {
    this.showLogDetails = false;
    this.showLogSheet = false;
    if (this.detailFeedId > 0) {
      router.pushUrl({ url: 'pages/FeedDetailPage', params: { feedId: this.detailFeedId } });
    }
  }

  private copyText(text: string): void {
    if (text === '') {
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data);
      this.message = this.text($r('app.string.copy_to_clipboard'));
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private copyDetails(): void {
    const reasonTitle: string = this.text($r('app.string.download_log_details_human_readable_reason_title'));
    const technicalTitle: string = this.text($r('app.string.download_log_details_technical_reason_title'));
    const urlTitle: string = this.text($r('app.string.download_log_details_file_url_title'));
    this.copyText(reasonTitle + ': \n' + this.detailReason + ' \n\n' + technicalTitle + ': \n'
      + this.detailTechnical + ' \n\n' + urlTitle + ': \n' + this.detailUrl);
  }

  /** 清除下载记录（上游 menu/download_log.xml 的 clear_logs_item） */
  async clearHistory(): Promise<void> {
    try {
      await DownloadLogRepository.clear();
      await this.loadLog();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  // ---------------------------------------------------------------- 重试

  /**
   * 日志行重试（上游 DownloadLogAdapter：feed 类型 → 刷新订阅；media 类型 → 走下载动作，
   * 移动网络下先弹确认，确认后 300 秒内免打扰）。
   */
  private retryLogEntry(entry: DownloadLogEntry): void {
    if (entry.feedFileType === DownloadsPage.FEED_FILE_TYPE_FEED) {
      this.retryFeedRefresh(entry);
      return;
    }
    if (AutoDownloadService.isMetered() && Date.now() >= DownloadsPage.mobileBypassUntil) {
      this.pendingLogRetry = entry;
      this.showMobileConfirm = true;
      return;
    }
    this.retryMediaDownload(entry);
  }

  private async retryFeedRefresh(entry: DownloadLogEntry): Promise<void> {
    try {
      const added: number = await RefreshService.refreshFeed(entry.feedFileId);
      this.message = this.text($r('app.string.feed_refresh_done')) + added;
      await this.loadLog();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private async retryMediaDownload(entry: DownloadLogEntry): Promise<void> {
    try {
      const item: FeedItem | undefined = await EpisodeRepository.getByMediaId(entry.feedFileId);
      if (item === undefined) {
        this.message = this.text($r('app.string.download_fail'));
        return;
      }
      const media: FeedMedia | undefined = await this.mediaOf(item);
      if (media === undefined || media.downloadUrl === '') {
        this.message = this.text($r('app.string.download_fail'));
        return;
      }
      await DownloadManager.startDownload(media, item.title);
      this.message = this.text($r('app.string.download_started'));
      await this.loadLog();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 单集的媒体记录：`getByMediaId` 只查单集行，媒体要按 feedItemId 回查 */
  private async mediaOf(item: FeedItem): Promise<FeedMedia | undefined> {
    if (item.media !== undefined) {
      return item.media;
    }
    return await EpisodeRepository.getMediaByFeedItem(item.id);
  }

  private confirmMobileDownload(): void {
    DownloadsPage.mobileBypassUntil = Date.now() + DownloadsPage.MOBILE_BYPASS_MS;
    const entry: DownloadLogEntry | undefined = this.pendingLogRetry;
    this.showMobileConfirm = false;
    this.pendingLogRetry = undefined;
    if (entry !== undefined) {
      this.retryMediaDownload(entry);
    }
  }

  // ---------------------------------------------------------------- 行内动作

  private onRowTap(item: FeedItem): void {
    if (this.selectMode) {
      this.toggleSelected(item.id);
      return;
    }
    openEpisodeDetail(item.id);
  }

  private onRowAction(item: FeedItem): void {
    if (this.selectMode) {
      this.toggleSelected(item.id);
      return;
    }
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      this.togglePause(item);
      return;
    }
    if (this.downloadsButtonPlay) {
      this.playItem(item);
      return;
    }
    this.deleteDownload(item);
  }

  /** 行内按钮图标（上游：进行中 = 取消/暂停；已下载 = 删除文件或播放） */
  private rowActionIcon(item: FeedItem): Resource {
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return state === 'PAUSED' ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill');
    }
    return this.downloadsButtonPlay ? $r('sys.symbol.play_fill') : $r('sys.symbol.trash');
  }

  private rowActionTint(item: FeedItem): ResourceColor {
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return $r('app.color.primary');
    }
    return this.downloadsButtonPlay ? $r('app.color.primary') : $r('app.color.text_secondary');
  }

  async togglePause(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return;
    }
    if (DownloadManager.getStatus(media.id) === 'PAUSED') {
      await DownloadManager.resume(media.id);
    } else {
      await DownloadManager.pause(media.id);
    }
    this.infoTick = this.infoTick + 1;
  }

  async playItem(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return;
    }
    const playable: Playable | undefined = await QueueEngine.toPlayable(this.rowItem(item));
    if (playable === undefined) {
      return;
    }
    await QueueEngine.ensureQueued(this.rowItem(item));
    await PlayerManager.load(playable, media.position, true);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  async deleteDownload(item: FeedItem): Promise<void> {
    try {
      const media: FeedMedia | undefined = this.rowItem(item).media;
      if (media !== undefined) {
        await DownloadManager.deleteFile(media);
      }
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 菜单里的下载动作（未下载 → 下载；下载中 → 取消；已下载 → 删除文件） */
  async downloadAction(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined || media.downloadUrl === '') {
      return;
    }
    try {
      const state: string = this.downloadState(item);
      if (state === 'DONE') {
        await DownloadManager.deleteFile(media);
      } else if (state === 'RUNNING' || state === 'PAUSED') {
        await DownloadManager.remove(media.id);
      } else {
        await DownloadManager.startDownload(media, this.rowItem(item).title);
      }
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private openActionSheet(item: FeedItem): void {
    if (this.selectMode) {
      return;
    }
    this.actionItem = item;
    this.actionTitle = item.title;
    this.showActionSheet = true;
  }

  private async share(item: FeedItem): Promise<void> {
    const row: FeedItem = this.rowItem(item);
    let link: string = row.link;
    if (link === '' && row.media !== undefined) {
      link = row.media.downloadUrl;
    }
    if (link === '') {
      this.message = this.text($r('app.string.share_no_link'));
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link);
      await pasteboard.getSystemPasteboard().setData(data);
      this.message = this.text($r('app.string.share_copied'));
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  // ---------------------------------------------------------------- 批量动作

  private async batchDeleteDownload(items: FeedItem[]): Promise<void> {
    this.exitSelectMode();
    try {
      for (const item of items) {
        const media: FeedMedia | undefined = this.rowItem(item).media;
        if (media !== undefined && media.fileUrl !== '') {
          await DownloadManager.deleteFile(media);
        }
      }
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private async batchMarkPlayed(items: FeedItem[], played: boolean): Promise<void> {
    try {
      for (const item of items) {
        await EpisodeRepository.markPlayed(item.id, played);
      }
      this.exitSelectMode();
      const data: FeedItemUpdateData = { feedId: 0, itemId: 0 };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private async batchQueue(items: FeedItem[], add: boolean): Promise<void> {
    try {
      for (const item of items) {
        if (add) {
          await QueueEngine.add(item);
          if (item.isNew()) {
            await EpisodeRepository.setNewFlag(item.id, false);
          }
        } else {
          await QueueEngine.remove(item.id);
        }
      }
      this.exitSelectMode();
      const data: FeedItemUpdateData = { feedId: 0, itemId: 0 };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private async batchFavorite(items: FeedItem[], add: boolean): Promise<void> {
    try {
      for (const item of items) {
        if (add) {
          await FavoritesRepository.add(item.id, item.feedId);
        } else {
          await FavoritesRepository.remove(item.id);
        }
      }
      this.exitSelectMode();
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private async batchResetPosition(items: FeedItem[]): Promise<void> {
    try {
      for (const item of items) {
        const media: FeedMedia | undefined = this.rowItem(item).media;
        if (media !== undefined) {
          await EpisodeRepository.updatePosition(media.id, 0);
        }
      }
      this.exitSelectMode();
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  private async batchRemoveFromInbox(items: FeedItem[]): Promise<void> {
    try {
      for (const item of items) {
        await EpisodeRepository.setNewFlag(item.id, false);
      }
      this.exitSelectMode();
      const data: FeedItemUpdateData = { feedId: 0, itemId: 0 };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 删除已播放的下载（上游溢出菜单 action_delete_downloads_played） */
  async deletePlayedDownloads(): Promise<void> {
    this.showDeletePlayedDialog = false;
    try {
      const played: FeedItem[] = this.items.filter((item: FeedItem) =>
      item.isPlayed && item.media !== undefined && item.media.fileUrl !== '');
      for (const item of played) {
        const media: FeedMedia | undefined = item.media;
        if (media !== undefined) {
          await DownloadManager.deleteFile(media);
        }
      }
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  // ---------------------------------------------------------------- 操作弹层内的动作

  private actionRowItem(): FeedItem | undefined {
    return this.actionItem;
  }

  private actionItemPlayed(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    return item !== undefined && item.isPlayed;
  }

  private actionItemIsNew(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    return item !== undefined && item.isNew();
  }

  private actionItemInQueue(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    return item !== undefined && this.queueIds.includes(item.id);
  }

  private actionItemFavorite(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    return item !== undefined && this.favoriteIds.includes(item.id);
  }

  private actionItemHasPosition(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    return item !== undefined && this.hasPosition(item);
  }

  private actionItemDeletable(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    return item !== undefined && this.canDeleteFile(item);
  }

  /** 是否正在进行下载（会话内有 RUNNING/PAUSED 任务） */
  private actionItemDownloading(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item === undefined) {
      return false;
    }
    const state: string = this.downloadState(item);
    return state === 'RUNNING' || state === 'PAUSED';
  }

  private actionIsPlaying(): boolean {
    const item: FeedItem | undefined = this.actionRowItem();
    return item !== undefined && this.isPlaying(item);
  }

  private skipEpisode(): void {
    QueueEngine.autoAdvance(false).catch((error: Error) => {
      this.message = error.message;
    });
  }

  private markPlayedItem(played: boolean): void {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item !== undefined) {
      this.batchMarkPlayed([item], played);
    }
  }

  private queueItem(add: boolean): void {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item !== undefined) {
      this.batchQueue([item], add);
    }
  }

  private favoriteItem(add: boolean): void {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item !== undefined) {
      this.batchFavorite([item], add);
    }
  }

  private deleteItem(): void {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item !== undefined) {
      this.deleteDownload(item);
    }
  }

  /** 取消下载（上游 CancelDownloadActionButton：取消任务 + 关掉该单集的自动下载标记） */
  private cancelItem(): void {
    const item: FeedItem | undefined = this.actionRowItem();
    const media: FeedMedia | undefined = item === undefined ? undefined : this.rowItem(item).media;
    if (media === undefined) {
      return;
    }
    DownloadManager.remove(media.id).then(() => {
      this.load();
    }).catch((error: Error) => {
      this.message = error.message;
    });
  }

  private resetPositionItem(): void {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item !== undefined) {
      this.batchResetPosition([item]);
    }
  }

  private removeFromInboxItem(): void {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item !== undefined) {
      this.batchRemoveFromInbox([item]);
    }
  }

  private shareItem(): void {
    const item: FeedItem | undefined = this.actionRowItem();
    if (item !== undefined) {
      this.share(item);
    }
  }

  private startSelectFromSheet(): void {
    const item: FeedItem | undefined = this.actionRowItem();
    this.showActionSheet = false;
    if (item !== undefined) {
      this.enterSelectMode(item.id);
    }
  }

  // ---------------------------------------------------------------- 多选

  private enterSelectMode(itemId: number): void {
    this.selectMode = true;
    this.selectedIds = [itemId];
  }

  private exitSelectMode(): void {
    this.selectMode = false;
    this.selectedIds = [];
  }

  private toggleSelected(itemId: number): void {
    if (this.selectedIds.includes(itemId)) {
      this.selectedIds = this.selectedIds.filter((id: number) => id !== itemId);
      if (this.selectedIds.length === 0) {
        this.selectMode = false;
      }
      return;
    }
    const next: number[] = this.selectedIds.slice();
    next.push(itemId);
    this.selectedIds = next;
  }

  private allSelected(): boolean {
    return this.items.length > 0 && this.selectedIds.length === this.items.length;
  }

  private toggleSelectAll(): void {
    if (this.allSelected()) {
      this.selectedIds = [];
      return;
    }
    this.selectedIds = this.items.map((item: FeedItem) => item.id);
  }

  private selectAllAbove(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    let firstSelected: number = -1;
    for (let i: number = 0; i < this.items.length; i++) {
      if (this.selectedIds.includes(this.items[i].id)) {
        firstSelected = i;
        break;
      }
    }
    if (firstSelected <= 0) {
      return;
    }
    const next: number[] = this.selectedIds.slice();
    for (let i: number = 0; i < firstSelected; i++) {
      if (!next.includes(this.items[i].id)) {
        next.push(this.items[i].id);
      }
    }
    this.selectedIds = next;
  }

  private selectAllBelow(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    let lastSelected: number = -1;
    for (let i: number = this.items.length - 1; i >= 0; i--) {
      if (this.selectedIds.includes(this.items[i].id)) {
        lastSelected = i;
        break;
      }
    }
    if (lastSelected < 0 || lastSelected === this.items.length - 1) {
      return;
    }
    const next: number[] = this.selectedIds.slice();
    for (let i: number = lastSelected + 1; i < this.items.length; i++) {
      if (!next.includes(this.items[i].id)) {
        next.push(this.items[i].id);
      }
    }
    this.selectedIds = next;
  }

  private selectedItems(): FeedItem[] {
    return this.items.filter((item: FeedItem) => this.selectedIds.includes(item.id));
  }

  private anySelected(predicate: (item: FeedItem) => boolean): boolean {
    return this.selectedItems().some(predicate);
  }

  // ---------------------------------------------------------------- 刷新

  /** 下拉 / 溢出菜单刷新（与订阅页、收件箱同一套语义） */
  async refreshFeeds(): Promise<void> {
    if (this.refreshingNow) {
      return;
    }
    this.refreshingNow = true;
    this.refreshing = true;
    this.message = this.text($r('app.string.refresh_running'));
    try {
      const added: number = await RefreshService.refreshAll();
      this.message = this.text($r('app.string.feed_refresh_done')) + added;
    } catch (error) {
      this.message = (error as Error).message;
    } finally {
      this.refreshingNow = false;
    }
    await this.load();
    if (this.showLogSheet) {
      await this.loadLog();
    }
  }

  private openSortSheet(): void {
    this.downloadsSortOrder = UserPreferences.getDownloadsSortedOrder() as SortOrder;
    this.showSortSheet = true;
  }

  // ---------------------------------------------------------------- 取值

  /** 行内取值统一入口（列表不重建时行持有的是首帧对象） */
  private rowItem(item: FeedItem): FeedItem {
    const current: FeedItem | undefined = this.rowItems.get(item.id);
    return current === undefined ? item : current;
  }

  private rowImage(item: FeedItem): string {
    const row: FeedItem = this.rowItem(item);
    return row.imageUrl !== '' ? row.imageUrl : this.feedImage(row.feedId);
  }

  private feedImage(feedId: number): string {
    return this.feedImages.get(feedId) ?? '';
  }

  private feedTitle(feedId: number): string {
    return this.feedTitles.get(feedId) ?? '';
  }

  /** 下载按钮状态：优先看数据库 file_url，再看会话内任务状态 */
  private downloadState(item: FeedItem): string {
    const row: FeedItem = this.rowItem(item);
    if (row.media === undefined) {
      return 'IDLE';
    }
    if (row.media.fileUrl !== '') {
      return 'DONE';
    }
    return DownloadManager.getStatus(row.media.id);
  }

  private isPlaying(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && media.id === this.playingMediaId;
  }

  private isVideo(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && media.getMediaType() === MediaType.VIDEO;
  }

  private hasPosition(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && media.position > 0;
  }

  private canDeleteFile(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && media.fileUrl !== '';
  }

  /** LazyForEach 行键：必须把下载状态与进度编进去，进度变化时行才会重建 */
  private rowKey(item: FeedItem): string {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return item.id.toString();
    }
    const state: string = this.downloadState(item);
    if (state !== 'RUNNING' && state !== 'PAUSED') {
      return item.id.toString() + '-' + state;
    }
    return item.id.toString() + '-' + state + '-'
      + DownloadManager.getProgressPercent(media.id).toString();
  }

  /** 进行中任务的已下载 / 总大小 */
  private sizeText(item: FeedItem): string {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return '';
    }
    const received: number = DownloadManager.getReceivedBytes(media.id);
    const total: number = DownloadManager.getTotalBytes(media.id);
    if (total <= 0) {
      return '';
    }
    return FileSizeUtils.format(received) + ' / ' + FileSizeUtils.format(total);
  }

  private progressPercent(item: FeedItem): number {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return 0;
    }
    const percent: number = DownloadManager.getProgressPercent(media.id);
    return percent < 0 ? 0 : percent;
  }

  /** 状态行：进行中显示状态与大小，已下载显示「发布日期 · 大小」 */
  metaText(item: FeedItem): string {
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return state === 'PAUSED'
        ? this.text($r('app.string.episode_download_paused')) : this.text($r('app.string.episode_downloading'));
    }
    const row: FeedItem = this.rowItem(item);
    const parts: string[] = [];
    if (row.pubDate > 0) {
      parts.push(new Date(row.pubDate).toLocaleDateString());
    }
    if (row.media !== undefined && row.media.size > 0) {
      parts.push(FileSizeUtils.format(row.media.size));
    }
    return parts.join(' · ');
  }

  positionText(item: FeedItem): string {
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return this.sizeText(item);
    }
    const playing: boolean = this.isPlaying(item);
    const media: FeedMedia | undefined = this.rowItem(item).media;
    const position: number = playing
      ? this.playingPosition
      : (media === undefined ? 0 : media.position);
    if (position > 0) {
      return DurationUtils.format(position);
    }
    return playing ? '0:00' : '';
  }

  durationText(item: FeedItem): string {
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return this.progressPercent(item).toString() + '%';
    }
    const duration: number = this.rowDuration(item);
    if (duration <= 0) {
      return '';
    }
    if (this.showRemainingTime) {
      const position: number = this.isPlaying(item)
        ? this.playingPosition
        : (this.rowItem(item).media === undefined ? 0 : this.rowItem(item).media!.position);
      if (position > 0) {
        const remaining: number = duration - position;
        return remaining > 0 ? '-' + DurationUtils.format(remaining) : '0:00';
      }
    }
    return DurationUtils.format(duration);
  }

  progress(item: FeedItem): number {
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return this.progressPercent(item);
    }
    const media: FeedMedia | undefined = this.rowItem(item).media;
    const duration: number = this.rowDuration(item);
    const position: number = this.isPlaying(item)
      ? this.playingPosition
      : (media === undefined ? 0 : media.position);
    if (duration <= 0 || position <= 0) {
      return 0;
    }
    const percent: number = Math.floor(position * 100 / duration);
    return percent > 100 ? 100 : (percent < 5 ? 5 : percent);
  }

  private rowDuration(item: FeedItem): number {
    if (this.isPlaying(item) && this.playingDuration > 0) {
      return this.playingDuration;
    }
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media === undefined ? 0 : media.duration;
  }

  private text(res: Resource): string {
    return getContext(this).resourceManager.getStringSync(res);
  }

  private textArg(res: Resource, arg: number): string {
    return getContext(this).resourceManager.getStringSync(res, arg.toString());
  }
}
