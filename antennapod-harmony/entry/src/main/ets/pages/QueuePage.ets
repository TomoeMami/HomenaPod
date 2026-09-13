import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { Feed } from '../model/Feed';
import { SortOrder, MediaType } from '../model/Enums';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { DownloadManager } from '../download/DownloadManager';
import { RefreshService } from '../services/RefreshService';
import { UserPreferences } from '../prefs/UserPreferences';
import { LazyDataSource } from '../components/LazyDataSource';
import { EventHub, EventType, FeedItemUpdateData, EpisodeDownloadData } from '../events/EventHub';
import { DurationUtils } from '../utils/DurationUtils';
import { DesignTokens } from '../common/DesignTokens';
import { menuIcon } from '../common/MenuIcons';
import { SwipeActions, SwipeScreen, SwipeActionId, SwipeActionSpec, swipeActionSpec,
  isDestructiveSwipeAction } from '../common/SwipeActions';
import { AppIconButton } from '../components/AppIconButton';
import { OverflowButton } from '../components/OverflowButton';
import { EpisodeRow } from '../components/EpisodeRow';
import { EmptyState } from '../components/EmptyState';
import { SwipeActionButton } from '../components/SwipeActionButton';
import { TagChip } from '../components/TagChip';

/** 排序对话框里的一格（对照上游 ItemSortDialog.onAddItem 的参数） */
interface QueueSortChip {
  label: ResourceStr;
  ascending: SortOrder;
  descending: SortOrder;
  /** 首次点击该格时用升序还是降序（上游 ascendingIsDefault） */
  ascendingIsDefault: boolean;
}

/** 队列多选动作栏的一项 */
interface QueueMenuItem {
  id: string;
  label: ResourceStr;
  icon: Resource;
  destructive: boolean;
}

/**
 * 队列页（对齐上游 queue_fragment.xml + QueueFragment / QueueRecyclerAdapter / FloatingSelectMenu）：
 *
 * 相对布局：标题栏（多选时换成「N/M 已选 + 全选溢出 + 关闭」）+ 信息条（多选时隐藏）+
 * 剧集行（拖拽手柄 + 封面 + 状态行 + 进度 + 右侧 48vp 次级操作）+ 底部浮动多选菜单。
 *
 * 手势与上游一致：
 * - 长按 = 上下文操作弹层（移到顶部/底部、跳过、移出收件箱、标记已播/未播、移出队列、下载、
 *   删除文件、收藏、重置播放位置、分享、多选），不再是「直接进多选」；
 * - 拖拽排序可从左侧三横线或封面左半区起拖（锁定 / 多选 / 保持排序时禁用）；
 * - 左右滑动作由设置页「滑动动作」决定，队列默认左右都是「移出队列」。
 */
@Component
export struct QueuePage {
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  private listScroller: ListScroller = new ListScroller();
  @State items: FeedItem[] = [];
  @State loading: boolean = false;
  @State locked: boolean = false;
  @State keepSorted: boolean = false;
  @State showSortSheet: boolean = false;
  /** 当前生效的排序方式（未开启「保持排序」时 -1 = 无激活格，与上游一致） */
  @State activeSortOrder: number = -1;
  @State selectMode: boolean = false;
  @State selectedIds: number[] = [];
  @State favoriteIds: number[] = [];
  @State message: string = '';
  @State hasUndo: boolean = false;
  @State refreshing: boolean = false;
  @State showActionSheet: boolean = false;
  @State actionItem: FeedItem | undefined = undefined;
  @State actionTitle: string = '';
  @State showLockDialog: boolean = false;
  @State lockDoNotShowAgain: boolean = false;
  @State showClearDialog: boolean = false;
  /** 「保持排序」复选框（随机排序时被强制关闭并禁用，上游同） */
  @State keepSortedChecked: boolean = false;
  @State showRemainingTime: boolean = false;
  /** 信息条里的剩余时长需要随倍速偏好变化重算 */
  @State infoTick: number = 0;
  /** 当前队列里是否有未播单集（空态「前往收件箱」按钮的显示条件） */
  @State inboxHasItems: boolean = false;
  /** 正在拖拽的单集 id（-1 = 未拖拽） */
  @State dragId: number = -1;
  /** 浮层里显示的被拖行（列表内的原行已隐藏） */
  @State dragItem: FeedItem | undefined = undefined;
  /** 浮层纵坐标（vp，相对列表顶部） */
  @State dragOverlayY: number = 0;
  /**
   * 当前播放项的 FeedMedia.id（上游 PlaybackStatus.isPlaying 的「当前播放 media」）。
   * 队列行按「正在播放 ∪ 有播放进度」显示进度行，所以这一项变了整页都要重绘。
   */
  @State playingMediaId: number = 0;
  /** 当前播放项的实时位置（上游 PlaybackPositionEvent → notifyPlaybackPositionUpdated） */
  @State playingPosition: number = 0;
  /** 当前播放项的实时时长（流媒体在播放中才拿到准确时长） */
  @State playingDuration: number = 0;
  /**
   * 本次 load() 从库里读到的单集，按 id 索引。
   * LazyForEach 的行持有的是首次渲染时的对象，顺序不变时不会重建（重建会把列表滚回顶部），
   * 行内取值一律经 `rowItem()` 回查这里，进度等字段才不会停在旧值。
   */
  @State rowItems: Map<number, FeedItem> = new Map<number, FeedItem>();
  /** 本次拖拽是否发生过换位（决定松手后是否需要落库） */
  private dragReordered: boolean = false;
  /**
   * 被拖行「离开原槽位」的累计位移（vp）= 各次换位挪动的槽位节距之和。
   * PanGesture 的 offsetY 是手势开始以来的累计值，所以这里必须累计：
   * 换位判断用 `offsetY - dragConsumed`，只减当前帧的换位量会让被拖行越漂越远。
   */
  private dragConsumed: number = 0;
  /** 拖拽开始时被拖行槽位顶部相对列表内容的偏移（vp）与列表滚动偏移（vp） */
  private dragStartTop: number = 0;
  private dragScrollY: number = 0;
  /** 每行实测高度（vp，由 EpisodeRow 的 onAreaChange 上报）：换位阈值按真实行高计算 */
  private rowHeights: Map<number, number> = new Map<number, number>();
  /** 订阅标题 / 封面 / 倍速，按 feedId 索引（信息条与行内展示共用） */
  private feedTitles: Map<number, string> = new Map<number, string>();
  private feedImages: Map<number, string> = new Map<number, string>();
  private feedSpeeds: Map<number, number> = new Map<number, number>();
  private queueToken: number = -1;
  /** 播放状态 / 换集 / 播放位置订阅（当前播放项的进度显示跟着播放走） */
  private playerStatusToken: number = -1;
  private trackChangedToken: number = -1;
  private positionToken: number = -1;
  /** 单集状态（已播 / 收藏）、下载、倍速、滑动动作配置订阅 */
  private feedItemToken: number = -1;
  private downloadToken: number = -1;
  private speedToken: number = -1;
  private swipeToken: number = -1;
  /** 显示类偏好（显示剩余时间 / 倍速折算）变化订阅 */
  private prefsToken: number = -1;
  /** 标题栏刷新与滑动刷新共用一个「刷新中」状态，需要防重入（上游 runOnceOrAsk） */
  private refreshingNow: boolean = false;
  /** 顶部提示自动消失（上游是 Snackbar 语义） */
  private messageTimerId: number = -1;
  private undoAction: () => void = () => {
  };
  /** 长按打开操作弹层的时刻：`parallelGesture` 下同一次长按的 onClick 也会命中，需忽略紧随的点击 */
  private longPressAt: number = 0;
  /** 随机排序前的「保持排序」勾选状态（切走随机后恢复，上游 turnedOffKeepSortedForRandom） */
  private keepSortedBeforeRandom: boolean = false;
  /** 冷启动后首次加载成功时才恢复上次的滚动位置 */
  private restoreScrollPending: boolean = true;
  /** 滑动动作（设置页可改；队列默认左右都是「移出队列」） */
  @State swipeRightId: string = SwipeActionId.REMOVE_FROM_QUEUE;
  @State swipeLeftId: string = SwipeActionId.REMOVE_FROM_QUEUE;
  /** 划出后继续拖动的距离阈值（vp）：进入动作区松手立即执行 */
  private static readonly SWIPE_ACTION_DISTANCE: number = 40;
  /** 行排列节距（vp）：封面 56 + 上下外边距各 12 + List 行间距 4，仅作兜底参考 */
  private static readonly FALLBACK_ROW_HEIGHT: number = 80;
  /** 相邻行让位动画时长（ms） */
  private static readonly SLOT_MOVE_DURATION: number = 180;
  /** 操作弹层最大高度（vp），超出可滚 */
  private static readonly SHEET_MAX_HEIGHT: number = 460;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.selectMode) {
          this.selectHeader()
        } else {
          this.normalHeader()
        }

        // 信息条（上游 info_bar：12fp、紧贴标题栏；多选时整条隐藏，上游 setVisibility(INVISIBLE)）
        if (!this.selectMode && this.items.length > 0) {
          Text($r('app.string.queue_info', this.items.length.toString(), this.remainingText()))
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
            .margin({ top: -DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_S })
        }

        if (this.message !== '') {
          Row({ space: DesignTokens.SPACE_XS }) {
            Text(this.message)
              .fontSize(DesignTokens.FONT_FOOTNOTE)
              .fontColor($r('app.color.primary'))
              .maxLines(2)
              .layoutWeight(1)
            if (this.hasUndo) {
              Text($r('app.string.undo_label'))
                .fontSize(DesignTokens.FONT_FOOTNOTE)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.primary'))
                .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S })
                .onClick(() => {
                  this.runUndo();
                })
            }
          }
          .width('100%')
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
        }

        if (this.loading) {
          Text($r('app.string.loading'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
        } else if (this.items.length === 0) {
          Column() {
            EmptyState({
              icon: $r('sys.symbol.music_note_list'),
              title: $r('app.string.queue_empty_title'),
              sub: $r('app.string.queue_empty_hint'),
              buttonLabel: this.inboxHasItems ? $r('app.string.queue_go_to_inbox') : '',
              onButtonTap: () => {
                router.pushUrl({ url: 'pages/InboxPage' });
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          // 下拉刷新（上游 SwipeRefreshLayout：下拉 = 更新订阅）
          Refresh({ refreshing: this.refreshing }) {
            // Stack 让拖拽浮层能叠在列表之上；浮层坐标相对列表顶部，无需知道列表的绝对位置
            Stack({ alignContent: Alignment.TopStart }) {
              List({ space: DesignTokens.SPACE_XS, scroller: this.listScroller }) {
                LazyForEach(this.dataSource, (item: FeedItem) => {
                  ListItem() {
                    this.queueRow(item)
                  }
                  .swipeAction(this.swipeOptions(item))
                }, (item: FeedItem) => item.id.toString())
              }
              .width('100%')
              .height('100%')
              .padding({
                left: DesignTokens.PAGE_MARGIN,
                right: DesignTokens.PAGE_MARGIN,
                bottom: this.selectMode ? 128 : DesignTokens.SPACE_S
              })
              .scrollBar(BarState.Off)

              if (this.dragItem !== undefined) {
                this.dragOverlay(this.dragItem)
              }
            }
            .width('100%')
            .height('100%')
            .clip(true)
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
      if (this.showLockDialog) {
        this.lockDialog()
      }
      if (this.showClearDialog) {
        this.clearDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 弹层背板（点击关闭） */
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

  /** 标题栏：大标题 + 搜索 + 溢出菜单 */
  @Builder
  normalHeader() {
    Row({ space: DesignTokens.SPACE_XS }) {
      Text($r('app.string.tab_queue'))
        .fontSize(DesignTokens.FONT_TITLE1)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      AppIconButton({
        symbol: $r('sys.symbol.magnifyingglass'),
        onTap: () => {
          // 上游：在队列内检索（FeedItemFilter(QUEUED)），不是全局搜索
          router.pushUrl({ url: 'pages/SearchPage', params: { term: '', queuedOnly: true } });
        }
      })
      OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
        this.overflowMenu()
      }
    }
    .width('100%')
    .height(DesignTokens.HEIGHT_APP_BAR)
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.SPACE_S })
  }

  /**
   * 多选态标题栏（对照上游 ActionMode：标题 "N/M selected" + 溢出菜单 + 关闭按钮）。
   * 上游在多选时把信息条置为不可见，计数改由标题栏承担。
   */
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

  /** 溢出菜单（上游 queue.xml：搜索 / 刷新 / 锁定 / 排序 / 清空队列） */
  @Builder
  overflowMenu() {
    Menu() {
      MenuItem({
        symbolStartIcon: menuIcon($r('sys.symbol.magnifyingglass')),
        content: $r('app.string.discover_search')
      })
        .onClick(() => {
          router.pushUrl({ url: 'pages/SearchPage', params: { term: '', queuedOnly: true } });
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.arrow_clockwise')), content: $r('app.string.refresh_label') })
        .onClick(() => {
          this.refreshFeeds();
        })
      // 上游「锁定队列」是勾选项，且在开启「保持排序」时隐藏
      if (!this.keepSorted) {
        MenuItem({
          symbolStartIcon: menuIcon(this.locked ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open')),
          content: this.locked ? $r('app.string.queue_unlocked') : $r('app.string.queue_locked')
        })
          .onClick(() => {
            this.toggleLock();
          })
      }
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.sort')), content: $r('app.string.queue_sort') })
        .onClick(() => {
          if (!this.locked) {
            this.openSortSheet();
          }
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.trash')), content: $r('app.string.queue_clear') })
        .onClick(() => {
          this.showClearDialog = true;
        })
    }
  }

  /** 多选态溢出菜单（上游 multi_select_options.xml：全选·取消全选 / 向上全选 / 向下全选） */
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

  @Builder
  queueRow(item: FeedItem) {
    EpisodeRow({
      title: this.rowItem(item).title,
      imageUrl: this.rowImage(item),
      metaText: this.metaText(item),
      positionText: this.positionText(item),
      durationText: this.durationText(item),
      progress: this.progress(item),
      playing: this.isPlaying(item),
      isPlayed: this.rowItem(item).isPlayed,
      isNew: this.rowItem(item).isNew(),
      isFavorite: this.favoriteIds.includes(item.id),
      inQueue: false,
      isVideo: this.isVideo(item),
      // 左侧三横线：上下拖拽排序的入口（锁定 / 多选 / 保持排序时禁用）
      showDragHandle: this.dragEnabled(),
      selected: this.selectedIds.includes(item.id),
      // 右侧 48vp 次级操作（上游 secondary_action.xml）：播放 / 暂停 / 下载 / 取消
      showAction: true,
      actionIcon: this.actionIcon(item),
      downloadProgress: this.downloadProgress(item),
      downloadIndeterminate: this.downloadIndeterminate(item),
      onTap: () => {
        this.onRowTap(item);
      },
      onAction: () => {
        this.onRowAction(item);
      },
      onLongPress: () => {
        this.openActionSheet(item);
      },
      // 拖拽以单集 id 为准（实时换位会改变下标，闭包里存 index 会失效）
      onHandleDragStart: (): boolean => {
        return this.startHandleDrag(item.id);
      },
      onHandleDragMove: (offsetY: number) => {
        this.moveHandleDrag(item.id, offsetY);
      },
      onHandleDragEnd: (offsetY: number) => {
        this.endHandleDrag(item.id, offsetY);
      },
      // 实测行高：换位阈值 / 槽位位移都按真实高度算
      onHeightChange: (height: number) => {
        this.rowHeights.set(item.id, height);
      }
    })
  }

  /** 行高（vp）：优先用实测值，未测得（尚未进入可视区）时回落到默认行高 */
  private rowHeightOf(item: FeedItem): number {
    const measured: number | undefined = this.rowHeights.get(item.id);
    return measured !== undefined && measured > 0 ? measured : QueuePage.FALLBACK_ROW_HEIGHT;
  }

  /** 槽位 index 的顶部偏移（vp）：前面各行高度 + 行间距之和 */
  private slotOffset(index: number): number {
    const space: number = DesignTokens.SPACE_XS;
    let offset: number = 0;
    for (let i: number = 0; i < index; i++) {
      offset += this.rowHeightOf(this.items[i]) + space;
    }
    return offset;
  }

  /**
   * 拖拽浮层：被拖行的真实视觉，跟随手指。
   * 列表内的原行此时已隐藏（`EpisodeRow.handleDragging`），但仍留在列表里占住
   * 「将要落位」的槽位并接收手势；相邻行的让位由 List 的 onDataMove 动画完成。
   */
  @Builder
  dragOverlay(item: FeedItem) {
    Column() {
      this.queueRow(item)
    }
    .width('100%')
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
    .position({ x: 0, y: this.dragOverlayY })
    .zIndex(10)
    // 浮层不能抢手势：手柄的 PanGesture 仍由列表里那行接收
    .hitTestBehavior(HitTestMode.None)
  }

  /**
   * 按住三横线开始拖拽（锁定 / 多选 / 保持排序时不可用）：返回 false 表示不接管。
   * 注意：外层 dragEnabled() 已挡住禁用场景，这里再判一次是因为手势闭包可能滞后一帧。
   */
  private startHandleDrag(itemId: number): boolean {
    if (!this.dragEnabled()) {
      return false;
    }
    const index: number = this.items.findIndex((entry: FeedItem) => entry.id === itemId);
    if (index < 0) {
      return false;
    }
    this.dragId = itemId;
    this.dragReordered = false;
    this.dragConsumed = 0;
    this.dragStartTop = this.slotOffset(index);
    this.dragScrollY = this.listScroller.currentOffset().yOffset;
    this.dragItem = this.items[index];
    this.dragOverlayY = this.dragStartTop - this.dragScrollY;
    return true;
  }

  /**
   * 拖拽中实时换位：被拖行的中心越过相邻槽位中心时与该槽位互换
   * （`onDataMove` + `animateTo` 让相邻行滑动让位）。
   *
   * 阈值取「两行中心间距」而非固定半行节距：行高随标题行数变化（1 行 / 2 行），
   * 固定节距会在行高不一致时算错槽位；且中心间距大于单行位移，换位后残差落在
   * 区间内部，不会在阈值附近来回抖动。
   */
  private moveHandleDrag(itemId: number, offsetY: number): void {
    if (this.dragId !== itemId) {
      return;
    }
    let index: number = this.items.findIndex((entry: FeedItem) => entry.id === itemId);
    if (index < 0) {
      return;
    }
    const space: number = DesignTokens.SPACE_XS;
    // 被拖行自身高度全程不变
    const dragged: number = this.rowHeightOf(this.items[index]);
    while (true) {
      if (index < this.items.length - 1) {
        const next: number = this.rowHeightOf(this.items[index + 1]);
        if (offsetY - this.dragConsumed >= (dragged + next) / 2 + space) {
          this.moveSlot(index, index + 1);
          // 槽位下移「被拖行高度 + 行间距」
          this.dragConsumed += dragged + space;
          index++;
          continue;
        }
      }
      if (index > 0) {
        const prev: number = this.rowHeightOf(this.items[index - 1]);
        if (offsetY - this.dragConsumed <= -((dragged + prev) / 2 + space)) {
          this.moveSlot(index, index - 1);
          this.dragConsumed -= prev + space;
          index--;
          continue;
        }
      }
      break;
    }
    // 浮层严格跟手：原槽位 + 手势累计位移（与换位无关，换位只影响列表里的槽位）
    this.dragOverlayY = this.dragStartTop - this.dragScrollY + offsetY;
  }

  /** 交换两个槽位（dataSource 与 this.items 引用同一数组，两边会同步改动） */
  private moveSlot(from: number, to: number): void {
    animateTo({ duration: QueuePage.SLOT_MOVE_DURATION, curve: Curve.EaseOut }, () => {
      this.dataSource.move(from, to);
    });
    this.dragReordered = true;
  }

  /** 松手：落位（换位过程中数据源已改好，这里只需落库） */
  async endHandleDrag(itemId: number, offsetY: number): Promise<void> {
    if (this.dragId !== itemId) {
      return;
    }
    this.dragId = -1;
    this.dragItem = undefined;
    this.dragConsumed = 0;
    if (!this.dragReordered) {
      return;
    }
    this.dragReordered = false;
    await QueueEngine.replaceOrder(this.items.slice());
  }

  /** 划出项配置（左右动作由设置页「滑动动作」决定，队列默认两侧都是「移出队列」） */
  private swipeOptions(item: FeedItem): SwipeActionOptions {
    const options: SwipeActionOptions = {};
    if (!SwipeActions.isEnabled(SwipeScreen.QUEUE) || this.locked || this.selectMode) {
      return options;
    }
    if (this.swipeRightId !== SwipeActionId.NONE) {
      const rightSpec: SwipeActionSpec = swipeActionSpec(this.swipeRightId);
      options.start = {
        builder: () => {
          this.swipeButton(rightSpec, item);
        },
        actionAreaDistance: QueuePage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(this.swipeRightId, item);
        }
      };
    }
    if (this.swipeLeftId !== SwipeActionId.NONE) {
      const leftSpec: SwipeActionSpec = swipeActionSpec(this.swipeLeftId);
      options.end = {
        builder: () => {
          this.swipeButton(leftSpec, item);
        },
        actionAreaDistance: QueuePage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(this.swipeLeftId, item);
        }
      };
    }
    return options;
  }

  /**
   * 划出项内容。builder 在渲染期就会执行，绝不能在这里直接调用副作用方法——
   * 副作用只在 `onAction`（拖过阈值松手）和按钮 `onClick`（近距划出后点按）里发生。
   */
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

  /** 执行左/右滑动作（对照上游 SwipeActions.onSwiped → 各 SwipeAction.performAction） */
  private runSwipeAction(id: string, item: FeedItem): void {
    if (id === SwipeActionId.REMOVE_FROM_QUEUE) {
      this.removeFromQueue(item.id);
    } else if (id === SwipeActionId.START_DOWNLOAD) {
      this.startDownload(item);
    } else if (id === SwipeActionId.MARK_PLAYED) {
      this.markPlayed(item, true);
    } else if (id === SwipeActionId.MARK_FAV) {
      this.setFavorite(item, true);
    } else if (id === SwipeActionId.REMOVE_FROM_FAVORITES) {
      this.setFavorite(item, false);
    } else if (id === SwipeActionId.DELETE) {
      this.deleteDownload(item);
    } else if (id === SwipeActionId.SHARE) {
      this.share(item);
    } else if (id === SwipeActionId.MOVE_TO_TOP) {
      this.moveToTop(item);
    } else if (id === SwipeActionId.MOVE_TO_BOTTOM) {
      this.moveToBottom(item);
    }
  }

  /** 底部浮动多选菜单（上游 FloatingSelectMenu：112vp 卡片 + 横向滚动动作，按状态显隐） */
  @Builder
  floatingSelectMenu() {
    Row() {
      Scroll() {
        Row({ space: DesignTokens.SPACE_XS }) {
          ForEach(this.menuItems(), (entry: QueueMenuItem) => {
            this.selectAction(entry);
          }, (entry: QueueMenuItem) => entry.id)
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
  selectAction(entry: QueueMenuItem) {
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

  /**
   * 多选动作栏的可见项（对照上游 onSelectedItemsUpdated：
   * FeedItemMenuHandler.onPrepareMenu + canMove，逐项按选中集合的状态决定是否显示）。
   * 顺序与上游 episodes_apply_action_speeddial.xml 一致；队列页排除「加入队列 / 移出收件箱」。
   */
  private menuItems(): QueueMenuItem[] {
    const selected: FeedItem[] = this.selectedItems();
    const entries: QueueMenuItem[] = [];
    if (selected.length === 0) {
      return entries;
    }
    if (this.anySelected((item: FeedItem): boolean => this.canDelete(item))) {
      entries.push({
        id: 'DELETE',
        label: $r('app.string.episode_delete_download'),
        icon: $r('sys.symbol.trash'),
        destructive: true
      });
    }
    if (this.anySelected((item: FeedItem): boolean => this.canDownload(item))) {
      entries.push({
        id: 'DOWNLOAD',
        label: $r('app.string.episode_download'),
        icon: $r('sys.symbol.arrow_down_circle'),
        destructive: false
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
    entries.push({
      id: 'REMOVE_QUEUE',
      label: $r('app.string.swipe_action_remove_from_queue'),
      icon: $r('sys.symbol.xmark_circle'),
      destructive: true
    });
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
    if (this.canMoveTop()) {
      entries.push({
        id: 'MOVE_TOP',
        label: $r('app.string.queue_move_top'),
        icon: $r('sys.symbol.arrow_up'),
        destructive: false
      });
    }
    if (this.canMoveBottom()) {
      entries.push({
        id: 'MOVE_BOTTOM',
        label: $r('app.string.queue_move_bottom'),
        icon: $r('sys.symbol.arrow_down'),
        destructive: false
      });
    }
    return entries;
  }

  private runMenuAction(id: string): void {
    if (id === 'DELETE') {
      this.batchDeleteDownload();
    } else if (id === 'DOWNLOAD') {
      this.batchDownload();
    } else if (id === 'MARK_UNPLAYED') {
      this.batchMarkPlayed(false);
    } else if (id === 'MARK_PLAYED') {
      this.batchMarkPlayed(true);
    } else if (id === 'REMOVE_QUEUE') {
      this.batchRemove();
    } else if (id === 'SHARE') {
      const selected: FeedItem[] = this.selectedItems();
      if (selected.length > 0) {
        this.share(selected[0]);
      }
    } else if (id === 'MARK_FAV') {
      this.batchFavorite(true);
    } else if (id === 'REMOVE_FAV') {
      this.batchFavorite(false);
    } else if (id === 'RESET_POSITION') {
      this.batchResetPosition();
    } else if (id === 'MOVE_TOP') {
      this.batchMoveTop();
    } else if (id === 'MOVE_BOTTOM') {
      this.batchMoveBottom();
    }
  }

  /** 长按操作弹层（上游 queue_context.xml + feeditemlist_context.xml + FeedItemMenuHandler） */
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

        if (this.canMoveActionItemTop()) {
          this.actionRow($r('sys.symbol.arrow_up'), $r('app.string.queue_move_top'), () => {
            this.moveToTopItem();
          })
        }
        if (this.canMoveActionItemBottom()) {
          this.actionRow($r('sys.symbol.arrow_down'), $r('app.string.queue_move_bottom'), () => {
            this.moveToBottomItem();
          })
        }
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
        this.actionRow($r('sys.symbol.xmark_circle'), $r('app.string.swipe_action_remove_from_queue'), () => {
          this.removeFromQueueItem();
        })
        if (this.actionItemDownloadable()) {
          this.actionRow($r('sys.symbol.arrow_down_circle'), $r('app.string.episode_download'), () => {
            this.downloadItem();
          })
        }
        if (this.actionItemDeletable()) {
          this.actionRow($r('sys.symbol.trash'), $r('app.string.episode_delete_download'), () => {
            this.deleteItem();
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
    .constraintSize({ maxHeight: QueuePage.SHEET_MAX_HEIGHT })
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

  /**
   * 排序面板（对照上游 sort_dialog.xml + QueueSortDialog）：
   * 双列 chip 网格（每类一项，激活项带 ▲/▼，再次点击翻转方向）+「保持排序」复选框 + 取消。
   */
  @Builder
  sortSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      // 双列 chip：用「每行两个」的显式行承载（Grid 在无高度约束时会撑满整屏，
      // 把下面的「保持排序」与取消按钮挤出屏幕）
      Column({ space: DesignTokens.SPACE_S }) {
        ForEach(this.sortChipRows(), (row: QueueSortChip[], rowIndex: number) => {
          Row({ space: DesignTokens.SPACE_S }) {
            ForEach(row, (chip: QueueSortChip) => {
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
            }, (chip: QueueSortChip) => chip.ascending.toString() + '-' + chip.descending.toString())
          }
          .width('100%')
        }, (row: QueueSortChip[], rowIndex: number) => 'sortRow' + rowIndex.toString())
      }
      .width('100%')

      Row({ space: DesignTokens.SPACE_S }) {
        Checkbox({ name: 'queueKeepSorted', group: 'queueSort' })
          .select(this.keepSortedChecked)
          .enabled(this.activeSortOrder !== SortOrder.RANDOM)
          .onChange((value: boolean) => {
            this.onKeepSortedChange(value);
          })
        Text($r('app.string.keep_sorted_label'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor(this.activeSortOrder === SortOrder.RANDOM
            ? $r('app.color.text_disabled') : $r('app.color.text_primary'))
          .layoutWeight(1)
          .onClick(() => {
            if (this.activeSortOrder !== SortOrder.RANDOM) {
              this.onKeepSortedChange(!this.keepSortedChecked);
            }
          })
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

  /** 锁定队列确认框（上游 toggleQueueLock：标题 + 说明 + 「不再提示」+ 锁定/取消） */
  @Builder
  lockDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showLockDialog = false;
        })
      Column({ space: DesignTokens.SPACE_M }) {
        Text($r('app.string.lock_queue_label'))
          .fontSize(DesignTokens.FONT_SECTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text($r('app.string.queue_lock_warning'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Row({ space: DesignTokens.SPACE_S }) {
          Checkbox({ name: 'queueLockWarning', group: 'queueLock' })
            .select(this.lockDoNotShowAgain)
            .onChange((value: boolean) => {
              this.lockDoNotShowAgain = value;
            })
          Text($r('app.string.checkbox_do_not_show_again'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .onClick(() => {
              this.lockDoNotShowAgain = !this.lockDoNotShowAgain;
            })
        }
        .width('100%')
        Row({ space: DesignTokens.SPACE_M }) {
          Button($r('app.string.cancel_label'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .onClick(() => {
              this.showLockDialog = false;
            })
          Button($r('app.string.lock_queue_label'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .backgroundColor($r('app.color.primary'))
            .fontColor($r('app.color.on_primary'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .onClick(() => {
              this.confirmLock();
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

  /** 清空队列确认框（上游 ConfirmationDialog clear_queue_label / clear_queue_confirmation_msg） */
  @Builder
  clearDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showClearDialog = false;
        })
      Column({ space: DesignTokens.SPACE_M }) {
        Text($r('app.string.queue_clear'))
          .fontSize(DesignTokens.FONT_SECTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text($r('app.string.clear_queue_confirmation_msg'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Row({ space: DesignTokens.SPACE_M }) {
          Button($r('app.string.cancel_label'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .onClick(() => {
              this.showClearDialog = false;
            })
          Button($r('app.string.queue_clear'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .backgroundColor($r('app.color.error'))
            .fontColor($r('app.color.on_primary'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .onClick(() => {
              this.showClearDialog = false;
              this.clearQueue();
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

  aboutToAppear(): void {
    this.locked = UserPreferences.getQueueLocked();
    this.keepSorted = UserPreferences.getQueueKeepSorted();
    this.keepSortedChecked = this.keepSorted;
    this.activeSortOrder = this.keepSorted ? UserPreferences.getQueueKeepSortedOrder() : -1;
    this.showRemainingTime = UserPreferences.getShowRemainingTime();
    this.loadSwipeActions();
    this.refreshPlaying();
    this.load();
    this.queueToken = EventHub.subscribe(EventType.QUEUE, () => {
      this.load();
    });
    // 换集（PlaybackService 开始装载新的单集）：队列里「当前播放项」的进度行要立刻挪到新的一集，
    // 并从库里重新读一遍各集进度（对照上游 QueueFragment.onPlayerStatusChanged → loadItems）
    this.trackChangedToken = EventHub.subscribe(EventType.PLAYER_TRACK_CHANGED, () => {
      this.refreshPlaying();
      this.load();
    });
    // 播放状态变化：上游 onPlayerStatusChanged 会整页 loadItems（已播状态 / 进度都可能变）
    this.playerStatusToken = EventHub.subscribe(EventType.PLAYER_STATUS, () => {
      this.refreshPlaying();
      this.load();
    });
    // 播放位置：只更新当前播放项那一行的位置与进度（上游 onEventMainThread(PlaybackPositionEvent)）
    this.positionToken = EventHub.subscribe(EventType.PLAYBACK_POSITION, (data: object) => {
      this.updatePlayingPosition(data);
    });
    // 单集状态变化（已播 / 收藏）：只刷新受影响的行（上游 FeedItemEvent → notifyItemChangedCompat）
    this.feedItemToken = EventHub.subscribe(EventType.FEED_ITEM_UPDATE, (data: object) => {
      const record: Record<string, number> = data as Record<string, number>;
      const itemId: number | undefined = record['itemId'];
      if (itemId !== undefined) {
        this.refreshRow(itemId);
      }
      this.refreshCounts();
    });
    // 下载进度 / 完成：只刷新对应行（上游 EpisodeDownloadEvent → notifyItemChangedCompat）
    this.downloadToken = EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.onDownloadEvent(data);
    });
    // 倍速变化：信息条的「剩余时长」按新倍速重算（上游 SpeedChangedEvent → refreshInfoBar）
    this.speedToken = EventHub.subscribe(EventType.SPEED_CHANGED, () => {
      this.infoTick = this.infoTick + 1;
    });
    // 设置页改了滑动动作：重新读取左右动作
    this.swipeToken = EventHub.subscribe(EventType.SWIPE_ACTIONS_CHANGED, () => {
      this.loadSwipeActions();
    });
    // 设置页改了「显示剩余时间 / 时长按倍速折算」：页签常驻不会重走 aboutToAppear，这里重新读取
    this.prefsToken = EventHub.subscribe(EventType.PREFS_CHANGED, () => {
      this.showRemainingTime = UserPreferences.getShowRemainingTime();
      this.infoTick = this.infoTick + 1;
    });
  }

  aboutToDisappear(): void {
    if (this.queueToken >= 0) {
      EventHub.unsubscribeToken(this.queueToken);
      this.queueToken = -1;
    }
    if (this.trackChangedToken >= 0) {
      EventHub.unsubscribeToken(this.trackChangedToken);
      this.trackChangedToken = -1;
    }
    if (this.playerStatusToken >= 0) {
      EventHub.unsubscribeToken(this.playerStatusToken);
      this.playerStatusToken = -1;
    }
    if (this.positionToken >= 0) {
      EventHub.unsubscribeToken(this.positionToken);
      this.positionToken = -1;
    }
    if (this.feedItemToken >= 0) {
      EventHub.unsubscribeToken(this.feedItemToken);
      this.feedItemToken = -1;
    }
    if (this.downloadToken >= 0) {
      EventHub.unsubscribeToken(this.downloadToken);
      this.downloadToken = -1;
    }
    if (this.speedToken >= 0) {
      EventHub.unsubscribeToken(this.speedToken);
      this.speedToken = -1;
    }
    if (this.swipeToken >= 0) {
      EventHub.unsubscribeToken(this.swipeToken);
      this.swipeToken = -1;
    }
    if (this.prefsToken >= 0) {
      EventHub.unsubscribeToken(this.prefsToken);
      this.prefsToken = -1;
    }
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
      this.messageTimerId = -1;
    }
    // 记住滚动位置（上游 onPause 存 SCROLL_POSITION_KEY / SCROLL_OFFSET_KEY）
    try {
      const offset: OffsetResult = this.listScroller.currentOffset();
      UserPreferences.setQueueScrollPosition(0, offset.yOffset);
    } catch (error) {
      // 列表尚未绑定时忽略
    }
  }

  /** 滑动动作配置（设置页「滑动动作」） */
  private loadSwipeActions(): void {
    const actions: string[] = SwipeActions.resolve(SwipeScreen.QUEUE);
    this.swipeRightId = actions[0];
    this.swipeLeftId = actions[1];
  }

  /** 当前播放项（上游 PlaybackStatus.isPlaying：只认 PlayerManager 里装载的那一集，Playable.id = FeedMedia.id） */
  private refreshPlaying(): void {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    const mediaId: number = playable === undefined ? 0 : playable.id;
    if (mediaId === this.playingMediaId) {
      return;
    }
    this.playingMediaId = mediaId;
    // 换集时位置/时长先取装载时的值（恢复播放位置），随后由 PlaybackPositionEvent 接管
    this.playingPosition = playable === undefined ? 0 : playable.position;
    this.playingDuration = playable === undefined ? 0 : playable.duration;
  }

  /** 正在播放的这一集位置推进：只改这一行的进度，不重载列表（上游 notifyPlaybackPositionUpdated） */
  private updatePlayingPosition(data: object): void {
    const record: Record<string, number> = data as Record<string, number>;
    const time: number | undefined = record['time'];
    const duration: number | undefined = record['duration'];
    if (time !== undefined) {
      this.playingPosition = time;
    }
    if (duration !== undefined && duration > 0) {
      this.playingDuration = duration;
    }
  }

  /** 下载事件：只刷新受影响的行；完成时该行的 file_url 变了，需要重新查库 */
  private async onDownloadEvent(data: object): Promise<void> {
    const payload: EpisodeDownloadData = data as EpisodeDownloadData;
    const index: number = this.items.findIndex((entry: FeedItem) =>
    entry.media !== undefined && entry.media.id === payload.mediaId);
    if (index < 0) {
      return;
    }
    if (payload.state === 'DONE' || payload.state === 'REMOVED') {
      await this.refreshRow(this.items[index].id);
      return;
    }
    this.dataSource.notifyDataChange(index);
  }

  /** 只刷新一行（下载进度 / 已播状态 / 收藏），不重建整个列表 */
  private async refreshRow(itemId: number): Promise<void> {
    const index: number = this.items.findIndex((entry: FeedItem) => entry.id === itemId);
    if (index < 0) {
      return;
    }
    const fresh: FeedItem | undefined = await EpisodeRepository.getById(itemId);
    if (fresh === undefined) {
      return;
    }
    // dataSource 与 this.items 是同一个数组对象，就地替换即可两边同步
    this.items[index] = fresh;
    this.rowItems.set(itemId, fresh);
    this.dataSource.notifyDataChange(index);
    this.infoTick = this.infoTick + 1;
  }

  /** 顶部提示（上游 MessageEvent / Snackbar），可带一个「撤销」动作 */
  private showMessage(text: string, undo?: () => void): void {
    this.message = text;
    if (undo === undefined) {
      this.hasUndo = false;
      this.undoAction = () => {
      };
    } else {
      this.hasUndo = true;
      this.undoAction = undo;
    }
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
    }
    this.messageTimerId = setTimeout(() => {
      this.message = '';
      this.hasUndo = false;
      this.messageTimerId = -1;
    }, 4000);
  }

  private runUndo(): void {
    const action: () => void = this.undoAction;
    this.message = '';
    this.hasUndo = false;
    action();
  }

  async load(): Promise<void> {
    if (this.dragId >= 0) {
      // 拖拽中不重载：重载会把内存顺序换成库里的旧顺序，拖拽的下标全部失效，
      // 松手时还会把「被换回旧顺序」的结果当成拖拽结果落库
      return;
    }
    // 只有首屏（还没有内容）才显示「加载中」：拖拽落库后也会走 load()，
    // 若无条件置 true，整页会在松手瞬间闪成「加载中…」
    this.loading = this.items.length === 0;
    try {
      await QueueEngine.load();
      const items: FeedItem[] = QueueEngine.getItems();
      // 顺序没变时不动数据源：setData 会触发 onDataReloaded 重建列表并让滚动位置回到顶部
      // （拖拽落位后 QueueEngine 会 publish(QUEUE)，本页订阅后会再 load 一次）
      const sameOrder: boolean = items.length === this.items.length
        && items.every((entry: FeedItem, index: number) => entry.id === this.items[index].id);
      const wasEmpty: boolean = this.items.length === 0;
      this.items = items;
      if (!sameOrder) {
        this.dataSource.setData(items);
      }
      // 行内取值走 rowItem() 回查：顺序不变时列表里的行不会重建，拿不到新对象
      const rowItems: Map<number, FeedItem> = new Map<number, FeedItem>();
      for (const entry of items) {
        rowItems.set(entry.id, entry);
      }
      this.rowItems = rowItems;

      await this.loadFeeds(items);

      const favorites: FeedItem[] = await FavoritesRepository.list();
      this.favoriteIds = favorites.map((item: FeedItem) => item.id);
      await this.refreshCounts();

      if (this.restoreScrollPending && wasEmpty) {
        this.restoreScrollPending = false;
        this.restoreScrollPosition();
      }
    } catch (error) {
      this.items = [];
      this.dataSource.setData([]);
    } finally {
      this.loading = false;
    }
  }

  /** 队列涉及的全部订阅（标题 / 封面 / 倍速），未订阅的单集也要拿到封面与倍速 */
  private async loadFeeds(items: FeedItem[]): Promise<void> {
    const ids: number[] = [];
    for (const item of items) {
      ids.push(item.feedId);
    }
    const feeds: Feed[] = await FeedRepository.listByIds(ids);
    const titles: Map<number, string> = new Map<number, string>();
    const images: Map<number, string> = new Map<number, string>();
    const speeds: Map<number, number> = new Map<number, number>();
    for (const feed of feeds) {
      titles.set(feed.id, feed.getTitle());
      images.set(feed.id, feed.imageUrl);
      speeds.set(feed.id, feed.feedPlaybackSpeed);
    }
    this.feedTitles = titles;
    this.feedImages = images;
    this.feedSpeeds = speeds;
  }

  /** 空态「前往收件箱」按钮的显示条件（上游 getTotalEpisodeCount(NEW) > 0） */
  private async refreshCounts(): Promise<void> {
    try {
      this.inboxHasItems = await EpisodeRepository.countNew() > 0;
    } catch (error) {
      this.inboxHasItems = false;
    }
  }

  /** 恢复上次离开队列页时的滚动位置（上游 restoreScrollPosition） */
  private restoreScrollPosition(): void {
    const offset: number = UserPreferences.getQueueScrollOffset();
    if (offset <= 0) {
      return;
    }
    try {
      this.listScroller.scrollTo({ xOffset: 0, yOffset: offset });
    } catch (error) {
      // 列表尚未完成布局时忽略：位置不是关键功能
    }
  }

  feedImage(feedId: number): string {
    return this.feedImages.get(feedId) ?? '';
  }

  /** 该行的播放倍速（上游 PlaybackSpeedUtils.getCurrentPlaybackSpeed） */
  private speedOf(item: FeedItem): number {
    const feedSpeed: number | undefined = this.feedSpeeds.get(item.feedId);
    if (feedSpeed !== undefined && feedSpeed > 0) {
      return feedSpeed;
    }
    const global: number = UserPreferences.getDefaultPlaybackSpeed();
    return global > 0 ? global : 1;
  }

  /**
   * 信息条右侧：队列剩余时长（上游 "… left"）。
   * 开启「时长按倍速折算」时按每集倍速折算（上游 timeRespectsSpeed）。
   */
  remainingText(): string {
    const respectSpeed: boolean = UserPreferences.getTimeRespectsSpeed();
    let remaining: number = 0;
    for (const item of this.items) {
      if (item.media === undefined) {
        continue;
      }
      const left: number = item.media.duration - item.media.position;
      if (left <= 0) {
        continue;
      }
      const speed: number = respectSpeed ? this.speedOf(item) : 1;
      remaining += left / speed;
    }
    // infoTick 只是为了让倍速偏好变化时本方法重新求值
    const tick: number = this.infoTick;
    const minutes: number = Math.floor(remaining / 60000);
    const hours: number = Math.floor(minutes / 60);
    const restMinutes: number = minutes % 60;
    const hourUnit: string = getContext(this).resourceManager.getStringSync($r('app.string.time_hour_unit'));
    const minuteUnit: string = getContext(this).resourceManager.getStringSync($r('app.string.time_minute_unit'));
    if (hours > 0) {
      return hours.toString() + ' ' + hourUnit + ' ' + restMinutes.toString() + ' ' + minuteUnit;
    }
    return minutes.toString() + ' ' + minuteUnit;
  }

  /** 锁定 / 解锁（上游 toggleQueueLock：首次锁定先弹确认框） */
  toggleLock(): void {
    if (this.locked) {
      this.setLocked(false);
      return;
    }
    if (UserPreferences.getShowQueueLockWarning()) {
      this.lockDoNotShowAgain = false;
      this.showLockDialog = true;
      return;
    }
    this.setLocked(true);
  }

  private confirmLock(): void {
    UserPreferences.setShowQueueLockWarning(!this.lockDoNotShowAgain);
    this.showLockDialog = false;
    this.setLocked(true);
  }

  private setLocked(locked: boolean): void {
    this.locked = locked;
    UserPreferences.setQueueLocked(locked);
    if (locked) {
      this.exitSelectMode();
    }
    // 队列为空时上游也会提示已锁定 / 已解锁（MessageEvent）
    if (this.items.length === 0) {
      this.showMessage(getContext(this).resourceManager.getStringSync(
        locked ? $r('app.string.queue_locked') : $r('app.string.queue_unlocked')));
    }
  }

  private toggleSelectMode(): void {
    if (this.selectMode) {
      this.exitSelectMode();
      return;
    }
    this.selectMode = true;
    this.selectedIds = [];
  }

  private exitSelectMode(): void {
    this.selectMode = false;
    this.selectedIds = [];
  }

  /**
   * 行点击：多选态切换选中；否则播放。
   * 长按刚弹出操作弹层时忽略紧随其后的点击（`parallelGesture` 下同一次长按也会触发 onClick）。
   */
  private onRowTap(item: FeedItem): void {
    if (this.showActionSheet) {
      return;
    }
    if (Date.now() - this.longPressAt < 800) {
      return;
    }
    if (this.selectMode) {
      this.toggleSelected(item.id);
      return;
    }
    this.play(this.rowItem(item));
  }

  /** 行内次级操作按钮（上游 ItemActionButton.forItem） */
  private onRowAction(item: FeedItem): void {
    if (this.selectMode) {
      this.toggleSelected(item.id);
      return;
    }
    const row: FeedItem = this.rowItem(item);
    if (row.media === undefined) {
      return;
    }
    if (this.isPlaying(item) && PlayerManager.getStatus() === 'PLAYING') {
      PlayerManager.pause();
      return;
    }
    const state: string = this.downloadState(row);
    if (state === 'DONE') {
      this.play(row);
    } else if (state === 'RUNNING') {
      DownloadManager.pause(row.media.id);
    } else if (state === 'PAUSED') {
      DownloadManager.resume(row.media.id);
    } else {
      this.startDownload(row);
    }
  }

  /** 长按：打开操作弹层（上游 registerForContextMenu） */
  private openActionSheet(item: FeedItem): void {
    this.longPressAt = Date.now();
    if (this.selectMode) {
      return;
    }
    this.actionItem = this.rowItem(item);
    this.actionTitle = this.rowItem(item).title;
    this.showActionSheet = true;
  }

  /** 操作弹层里的「多选」：进入多选并选中长按项 */
  private startSelectFromSheet(): void {
    if (this.actionItem === undefined) {
      return;
    }
    this.selectMode = true;
    this.selectedIds = [this.actionItem.id];
  }

  private toggleSelected(itemId: number): void {
    if (this.selectedIds.includes(itemId)) {
      this.selectedIds = this.selectedIds.filter((id: number) => id !== itemId);
    } else {
      this.selectedIds = this.selectedIds.concat([itemId]);
    }
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

  /** 向上全选：选中第一项到「第一个已选项」之前（上游 select_all_above） */
  private selectAllAbove(): void {
    let first: number = -1;
    for (let i: number = 0; i < this.items.length; i++) {
      if (this.selectedIds.includes(this.items[i].id)) {
        first = i;
        break;
      }
    }
    if (first <= 0) {
      return;
    }
    const ids: number[] = this.selectedIds.slice();
    for (let i: number = 0; i < first; i++) {
      if (!ids.includes(this.items[i].id)) {
        ids.push(this.items[i].id);
      }
    }
    this.selectedIds = ids;
  }

  /** 向下全选：选中「最后一个已选项」之后到队尾（上游 select_all_below） */
  private selectAllBelow(): void {
    let last: number = -1;
    for (let i: number = this.items.length - 1; i >= 0; i--) {
      if (this.selectedIds.includes(this.items[i].id)) {
        last = i;
        break;
      }
    }
    if (last < 0 || last >= this.items.length - 1) {
      return;
    }
    const ids: number[] = this.selectedIds.slice();
    for (let i: number = last + 1; i < this.items.length; i++) {
      if (!ids.includes(this.items[i].id)) {
        ids.push(this.items[i].id);
      }
    }
    this.selectedIds = ids;
  }

  private selectedItems(): FeedItem[] {
    return this.items.filter((item: FeedItem) => this.selectedIds.includes(item.id));
  }

  /** 选中集合里是否存在满足条件的项（上游 onPrepareMenu 的 |= 语义） */
  private anySelected(predicate: (item: FeedItem) => boolean): boolean {
    for (const item of this.selectedItems()) {
      if (predicate(item)) {
        return true;
      }
    }
    return false;
  }

  /** 上游 QueueFragment.canMove：手动重排是否可用 + 是否已经是队首 / 队尾（连续块也算） */
  private canMoveTop(): boolean {
    const selected: FeedItem[] = this.selectedItems();
    if (!this.canReorder(selected)) {
      return false;
    }
    let firstSelected: number = -1;
    for (let i: number = 0; i < this.items.length; i++) {
      if (this.selectedIds.includes(this.items[i].id)) {
        firstSelected = i;
        break;
      }
    }
    if (firstSelected !== 0) {
      return true;
    }
    // 从队首开始的连续块：往上没有可挪的空间
    for (let i: number = 0; i < selected.length; i++) {
      if (this.items[i].id !== selected[i].id) {
        return true;
      }
    }
    return false;
  }

  private canMoveBottom(): boolean {
    const selected: FeedItem[] = this.selectedItems();
    if (!this.canReorder(selected)) {
      return false;
    }
    let lastSelected: number = -1;
    for (let i: number = this.items.length - 1; i >= 0; i--) {
      if (this.selectedIds.includes(this.items[i].id)) {
        lastSelected = i;
        break;
      }
    }
    if (lastSelected !== this.items.length - 1) {
      return true;
    }
    const offset: number = this.items.length - selected.length;
    for (let i: number = 0; i < selected.length; i++) {
      if (this.items[offset + i].id !== selected[i].id) {
        return true;
      }
    }
    return false;
  }

  private canReorder(selected: FeedItem[]): boolean {
    if (selected.length === 0 || this.items.length === 0) {
      return false;
    }
    if (this.locked || this.keepSorted || selected.length === this.items.length) {
      return false;
    }
    return true;
  }

  private play(item: FeedItem): void {
    if (item.media === undefined) {
      return;
    }
    QueueEngine.toPlayable(item).then((playable: Playable | undefined) => {
      if (playable === undefined) {
        return;
      }
      PlayerManager.load(playable, item.media === undefined ? 0 : item.media.position, true).then(() => {
        router.pushUrl({ url: 'pages/PlayerPage' });
      }).catch((error: Error) => {
        this.showMessage(error.message);
      });
    }).catch((error: Error) => {
      this.showMessage(error.message);
    });
  }

  /** 拖拽排序（对齐上游 ItemTouchHelper 的上下拖拽；锁定 / 多选 / 保持排序时禁用） */
  dragEnabled(): boolean {
    return !this.locked && !this.selectMode && !this.keepSorted;
  }

  /**
   * 移出队列（上游 RemoveFromQueueSwipeAction：Snackbar + 撤销，撤销时插回原位置）。
   * 行随之消失，无需额外提示；批量移出由 batchRemove 负责。
   */
  async removeFromQueue(feedItemId: number): Promise<void> {
    this.closeSwipes();
    const index: number = this.items.findIndex((entry: FeedItem) => entry.id === feedItemId);
    const removed: FeedItem | undefined = index >= 0 ? this.items[index] : undefined;
    try {
      await QueueEngine.remove(feedItemId);
      await this.load();
      if (removed !== undefined) {
        this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.removed_from_queue_message')),
          () => {
            QueueEngine.addAt(removed, index);
          });
      }
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /**
   * 收起已划出的行。
   * `onAction` 触发后行不会自动回弹——只删除行时才看不出来，像「添加下载」这种
   * 不删行的动作必须手动收起，否则该行会一直停在「滑出屏幕」的状态。
   */
  private closeSwipes(): void {
    try {
      this.listScroller.closeAllSwipeActions();
    } catch (error) {
      // 列表未绑定时（首屏加载中）忽略：此时不可能有展开的划出项
    }
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

  /** 行内次级操作图标（上游 ItemActionButton：播放中 = 暂停，已下载 = 播放，下载中 = 暂停，其余 = 下载） */
  private actionIcon(item: FeedItem): Resource {
    const row: FeedItem = this.rowItem(item);
    if (this.isPlaying(item) && PlayerManager.getStatus() === 'PLAYING') {
      return $r('sys.symbol.pause_fill');
    }
    const state: string = this.downloadState(row);
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

  /** 行内下载进度环的百分比；-1 = 不显示（对照上游 secondaryActionProgress） */
  private downloadProgress(item: FeedItem): number {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return -1;
    }
    return DownloadManager.getProgressPercent(media.id);
  }

  private downloadIndeterminate(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && DownloadManager.isProgressIndeterminate(media.id);
  }

  /** 右滑 / 弹层：开始下载（已下载 / 正在下载时不重复触发，只给提示） */
  async startDownload(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return;
    }
    const status: string = DownloadManager.getStatus(media.id);
    if (media.fileUrl !== '' || status === 'DONE') {
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.episode_downloaded')));
      this.closeSwipes();
      return;
    }
    if (status === 'RUNNING' || status === 'PAUSED') {
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.episode_downloading')));
      this.closeSwipes();
      return;
    }
    try {
      await DownloadManager.startDownload(media, item.title);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.download_started')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
    this.closeSwipes();
  }

  /** 删除本地文件（上游 DeleteSwipeAction / AddToQueue 之外的单集删除） */
  async deleteDownload(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return;
    }
    try {
      await DownloadManager.deleteFile(media);
      await this.refreshRow(item.id);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.deleted_episode_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 标记已播 / 未播 */
  async markPlayed(item: FeedItem, played: boolean): Promise<void> {
    try {
      await EpisodeRepository.markPlayed(item.id, played);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.refreshRow(item.id);
      this.showMessage(getContext(this).resourceManager.getStringSync(
        played ? $r('app.string.marked_played_message') : $r('app.string.marked_unplayed_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 收藏 / 取消收藏 */
  async setFavorite(item: FeedItem, favorite: boolean): Promise<void> {
    const isFavorite: boolean = this.favoriteIds.includes(item.id);
    if (isFavorite === favorite) {
      return;
    }
    try {
      if (favorite) {
        await FavoritesRepository.add(item.id, item.feedId);
      } else {
        await FavoritesRepository.remove(item.id);
      }
      const favorites: FeedItem[] = await FavoritesRepository.list();
      this.favoriteIds = favorites.map((entry: FeedItem) => entry.id);
      await this.refreshRow(item.id);
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 重置播放位置（上游 reset_position：位置归零并标记未播） */
  async resetPosition(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return;
    }
    try {
      await EpisodeRepository.updatePosition(media.id, 0);
      await EpisodeRepository.markPlayed(item.id, false);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.refreshRow(item.id);
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 分享：复制单集链接到剪贴板（本 SDK 无系统分享面板 API，与订阅详情/播放页一致） */
  async share(item: FeedItem): Promise<void> {
    let link: string = this.rowItem(item).link;
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (link === '' && media !== undefined) {
      link = media.downloadUrl;
    }
    if (link === '') {
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.share_no_link')));
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.share_copied')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 移到队首 / 队尾 */
  async moveToTop(item: FeedItem): Promise<void> {
    try {
      await QueueEngine.moveToTop(item.id);
      await this.load();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.moved_to_top_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async moveToBottom(item: FeedItem): Promise<void> {
    try {
      await QueueEngine.moveToBottom(item.id);
      await this.load();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.moved_to_bottom_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 下拉 / 标题栏刷新：拉取订阅更新（上游 FeedUpdateManager.runOnceOrAsk） */
  async refreshFeeds(): Promise<void> {
    // 防重入：`Refresh` 组件在 refreshing 被置真时会再回调一次 onRefreshing
    if (this.refreshingNow) {
      return;
    }
    this.refreshingNow = true;
    this.refreshing = true;
    try {
      await RefreshService.refreshAll();
    } catch (error) {
      this.showMessage((error as Error).message);
    } finally {
      this.refreshingNow = false;
      this.refreshing = false;
      await this.load();
    }
  }

  /** 打开排序面板（上游若已开启保持排序，则带上已保存的排序方式） */
  private openSortSheet(): void {
    if (this.keepSorted) {
      this.activeSortOrder = UserPreferences.getQueueKeepSortedOrder();
    }
    this.keepSortedChecked = this.keepSorted;
    this.showSortSheet = true;
  }

  /** 队列排序项（上游 QueueSortDialog.onAddItem；文件名字/大小两种排序被排除，标签不带方向） */
  private sortChips(): QueueSortChip[] {
    const chips: QueueSortChip[] = [];
    chips.push({
      label: $r('app.string.sort_episode_title'),
      ascending: SortOrder.TITLE_A_Z,
      descending: SortOrder.TITLE_Z_A,
      ascendingIsDefault: true
    });
    chips.push({
      label: $r('app.string.sort_podcast_title'),
      ascending: SortOrder.FEED_TITLE_A_Z,
      descending: SortOrder.FEED_TITLE_Z_A,
      ascendingIsDefault: true
    });
    chips.push({
      label: $r('app.string.sort_duration_label'),
      ascending: SortOrder.DURATION_SHORT_LONG,
      descending: SortOrder.DURATION_LONG_SHORT,
      ascendingIsDefault: true
    });
    chips.push({
      label: $r('app.string.sort_date_label'),
      ascending: SortOrder.DATE_OLD_NEW,
      descending: SortOrder.DATE_NEW_OLD,
      ascendingIsDefault: true
    });
    chips.push({
      label: $r('app.string.sort_random_label'),
      ascending: SortOrder.RANDOM,
      descending: SortOrder.RANDOM,
      ascendingIsDefault: true
    });
    chips.push({
      label: $r('app.string.queue_smart_shuffle'),
      ascending: SortOrder.SMART_SHUFFLE_OLD_NEW,
      descending: SortOrder.SMART_SHUFFLE_NEW_OLD,
      ascendingIsDefault: true
    });
    return chips;
  }

  /** 排序格按「每行两个」切分（面板用显式行承载，避免 Grid 撑满整屏） */
  private sortChipRows(): QueueSortChip[][] {
    const chips: QueueSortChip[] = this.sortChips();
    const rows: QueueSortChip[][] = [];
    for (let i: number = 0; i < chips.length; i += 2) {
      const row: QueueSortChip[] = [chips[i]];
      if (i + 1 < chips.length) {
        row.push(chips[i + 1]);
      }
      rows.push(row);
    }
    return rows;
  }

  /** 激活的排序格：标签带 ▲（升序）/ ▼（降序）；无方向的项不带箭头（上游 sort_dialog_item_active.xml） */
  private sortChipLabel(chip: QueueSortChip): ResourceStr {
    if (!this.isSortChipActive(chip)) {
      return chip.label;
    }
    if (chip.ascending === chip.descending) {
      return chip.label;
    }
    const arrow: string = this.activeSortOrder === chip.ascending ? ' ▲' : ' ▼';
    return getContext(this).resourceManager.getStringSync(chip.label as Resource) + arrow;
  }

  private isSortChipActive(chip: QueueSortChip): boolean {
    return this.activeSortOrder === chip.ascending || this.activeSortOrder === chip.descending;
  }

  /**
   * 点排序格：未激活时用默认方向，已激活时翻转方向（上游 ItemSortDialog.onAddItem 的点击分支）；
   * 每次选择都会写入「保持排序」的排序方式并立即重排队列。
   */
  private async pickSortChip(chip: QueueSortChip): Promise<void> {
    let order: SortOrder = chip.ascendingIsDefault ? chip.ascending : chip.descending;
    if (this.isSortChipActive(chip)) {
      order = this.activeSortOrder === chip.ascending ? chip.descending : chip.ascending;
    }
    this.activeSortOrder = order;
    if (order === SortOrder.RANDOM) {
      // 上游：随机排序时强制取消并禁用「保持排序」，切走后恢复
      if (this.keepSortedChecked) {
        this.keepSortedBeforeRandom = true;
      }
      this.keepSortedChecked = false;
      this.keepSorted = false;
      UserPreferences.setQueueKeepSorted(false);
    } else if (this.keepSortedBeforeRandom) {
      this.keepSortedBeforeRandom = false;
      this.keepSortedChecked = true;
      this.keepSorted = true;
      UserPreferences.setQueueKeepSorted(true);
    }
    UserPreferences.setQueueKeepSortedOrder(order);
    await QueueEngine.applySort(order);
    await this.load();
  }

  /** 「保持排序」开关（上游 QueueSortDialog.onSelectionChanged） */
  private async onKeepSortedChange(value: boolean): Promise<void> {
    this.keepSortedChecked = value;
    this.keepSorted = value;
    UserPreferences.setQueueKeepSorted(value);
    const order: number = this.activeSortOrder >= 0 ? this.activeSortOrder : UserPreferences.getQueueKeepSortedOrder();
    UserPreferences.setQueueKeepSortedOrder(order);
    if (value) {
      await QueueEngine.applySort(order);
      await this.load();
    }
  }

  async removeFromQueueItems(ids: number[]): Promise<void> {
    for (const id of ids) {
      await QueueEngine.remove(id);
    }
    await this.load();
  }

  async batchRemove(): Promise<void> {
    const count: number = this.selectedIds.length;
    if (count === 0) {
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.no_items_selected_message')));
      return;
    }
    const ids: number[] = this.selectedIds.slice();
    this.exitSelectMode();
    try {
      await this.removeFromQueueItems(ids);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.removed_from_queue_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchMarkPlayed(played: boolean): Promise<void> {
    const selected: FeedItem[] = this.selectedItems();
    if (selected.length === 0) {
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.no_items_selected_message')));
      return;
    }
    this.exitSelectMode();
    try {
      for (const item of selected) {
        await EpisodeRepository.markPlayed(item.id, played);
        const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
        EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      }
      await this.load();
      this.showMessage(getContext(this).resourceManager.getStringSync(
        played ? $r('app.string.marked_played_message') : $r('app.string.marked_unplayed_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchDownload(): Promise<void> {
    const selected: FeedItem[] = this.selectedItems();
    this.exitSelectMode();
    try {
      for (const item of selected) {
        const media: FeedMedia | undefined = this.rowItem(item).media;
        if (media !== undefined && media.downloadUrl !== '' && media.fileUrl === '') {
          await DownloadManager.startDownload(media, item.title);
        }
      }
      await this.load();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.download_started')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchDeleteDownload(): Promise<void> {
    const selected: FeedItem[] = this.selectedItems();
    this.exitSelectMode();
    try {
      for (const item of selected) {
        const media: FeedMedia | undefined = this.rowItem(item).media;
        if (media === undefined) {
          continue;
        }
        if (media.fileUrl !== '') {
          await DownloadManager.deleteFile(media);
        } else if (DownloadManager.getStatus(media.id) === 'RUNNING') {
          await DownloadManager.pause(media.id);
        }
      }
      await this.load();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.deleted_episode_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchFavorite(favorite: boolean): Promise<void> {
    const selected: FeedItem[] = this.selectedItems();
    this.exitSelectMode();
    try {
      for (const item of selected) {
        await this.setFavorite(item, favorite);
      }
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchResetPosition(): Promise<void> {
    const selected: FeedItem[] = this.selectedItems();
    this.exitSelectMode();
    try {
      for (const item of selected) {
        await this.resetPosition(item);
      }
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchMoveTop(): Promise<void> {
    const selected: FeedItem[] = this.selectedItems();
    const rest: FeedItem[] = this.items.filter((item: FeedItem) => !this.selectedIds.includes(item.id));
    this.exitSelectMode();
    try {
      await QueueEngine.replaceOrder(selected.concat(rest));
      await this.load();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.moved_to_top_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchMoveBottom(): Promise<void> {
    const selected: FeedItem[] = this.selectedItems();
    const rest: FeedItem[] = this.items.filter((item: FeedItem) => !this.selectedIds.includes(item.id));
    this.exitSelectMode();
    try {
      await QueueEngine.replaceOrder(rest.concat(selected));
      await this.load();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.moved_to_bottom_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async clearQueue(): Promise<void> {
    try {
      this.exitSelectMode();
      await QueueEngine.clear();
      await this.load();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  isVideo(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && media.getMediaType() === MediaType.VIDEO;
  }

  /**
   * 行内取值统一入口：LazyForEach 的行持有的是首次渲染时的单集对象，
   * 队列顺序不变时列表不会重建（重建会把滚动位置带回顶部），
   * 所以按 id 回查本次 load() 从库里读到的对象，进度 / 已播等字段才是最新的。
   */
  private rowItem(item: FeedItem): FeedItem {
    const current: FeedItem | undefined = this.rowItems.get(item.id);
    return current === undefined ? item : current;
  }

  /** 行封面：单集封面优先，回落订阅封面 */
  private rowImage(item: FeedItem): string {
    const row: FeedItem = this.rowItem(item);
    return row.imageUrl !== '' ? row.imageUrl : this.feedImage(row.feedId);
  }

  /** 这一集是不是播放器当前装载的那一集（上游 PlaybackStatus.isPlaying(media)） */
  isPlaying(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && media.id === this.playingMediaId;
  }

  /** 进度行左侧位置文本：当前播放项即使位置为 0 也显示（上游 position 与 progressBar 同时可见） */
  positionText(item: FeedItem): string {
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

  /**
   * 进度行右侧时长文本：播放中优先用播放器上报的时长（流媒体装载后才准确）。
   * 开启「显示剩余时间」时显示 `-剩余`（上游 shouldShowRemainingTime）。
   */
  durationText(item: FeedItem): string {
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
        // 剩余为 0 时上游仍显示 "00:00"（DurationUtils.format(0) 返回空串，这里显式给出）
        return remaining > 0 ? '-' + DurationUtils.format(remaining) : '0:00';
      }
    }
    return DurationUtils.format(duration);
  }

  progress(item: FeedItem): number {
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

  /** 本行用于算进度的时长：播放中优先用播放器上报值，否则用库里存的时长 */
  private rowDuration(item: FeedItem): number {
    if (this.isPlaying(item) && this.playingDuration > 0) {
      return this.playingDuration;
    }
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media === undefined ? 0 : media.duration;
  }

  metaText(item: FeedItem): string {
    const row: FeedItem = this.rowItem(item);
    const parts: string[] = [];
    if (row.pubDate > 0) {
      parts.push(new Date(row.pubDate).toLocaleDateString());
    }
    if (row.media !== undefined && row.media.size > 0) {
      const mb: number = row.media.size / (1024 * 1024);
      parts.push(mb < 1 ? (row.media.size / 1024).toFixed(0) + ' KB' : mb.toFixed(1) + ' MB');
    }
    return parts.join(' · ');
  }

  // ---------------------------------------------------------------- 操作弹层内的动作
  private actionItemPlayed(): boolean {
    return this.actionItem !== undefined && this.actionItem!.isPlayed;
  }

  private actionItemIsNew(): boolean {
    return this.actionItem !== undefined && this.actionItem!.isNew();
  }

  private actionItemFavorite(): boolean {
    return this.actionItem !== undefined && this.favoriteIds.includes(this.actionItem!.id);
  }

  private actionItemHasPosition(): boolean {
    return this.actionItem !== undefined && this.hasPosition(this.actionItem!);
  }

  private actionItemDownloadable(): boolean {
    return this.actionItem !== undefined && this.canDownload(this.actionItem!);
  }

  private actionItemDeletable(): boolean {
    return this.actionItem !== undefined && this.canDelete(this.actionItem!);
  }

  /** 上游 skip_episode_item 只在「当前正在播放的那一集」上显示 */
  private actionIsPlaying(): boolean {
    return this.actionItem !== undefined && this.isPlaying(this.actionItem!);
  }

  /**
   * 长按弹层里的「移到顶部 / 移到底部」：判据是**长按的那一集**在队列里的位置
   * （上游 QueueRecyclerAdapter.onCreateContextMenu 用 getLongPressedItem 比较队首/队尾），
   * 与多选动作栏的 canMoveTop/canMoveBottom（按选中集合判断）不是一回事。
   */
  private canMoveActionItemTop(): boolean {
    if (!this.canReorderSingle()) {
      return false;
    }
    return this.items[0].id !== this.actionItem!.id;
  }

  private canMoveActionItemBottom(): boolean {
    if (!this.canReorderSingle()) {
      return false;
    }
    return this.items[this.items.length - 1].id !== this.actionItem!.id;
  }

  private canReorderSingle(): boolean {
    return this.actionItem !== undefined && !this.locked && !this.keepSorted && this.items.length > 1;
  }

  private hasPosition(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    return media !== undefined && media.position > 0;
  }

  /** 上游 canDelete = 已下载 或 正在下载 */
  private canDelete(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return false;
    }
    return media.fileUrl !== '' || DownloadManager.getStatus(media.id) === 'RUNNING';
  }

  /** 上游 canDownload = 有媒体 且 未下载 且 不在下载中 */
  private canDownload(item: FeedItem): boolean {
    const media: FeedMedia | undefined = this.rowItem(item).media;
    if (media === undefined) {
      return false;
    }
    const status: string = DownloadManager.getStatus(media.id);
    return media.fileUrl === '' && status !== 'RUNNING' && status !== 'PAUSED';
  }

  private moveToTopItem(): void {
    if (this.actionItem !== undefined) {
      this.moveToTop(this.actionItem!);
    }
  }

  private moveToBottomItem(): void {
    if (this.actionItem !== undefined) {
      this.moveToBottom(this.actionItem!);
    }
  }

  /** 跳过这一集：结束当前播放并接着播队列里的下一集（上游 KEYCODE_MEDIA_NEXT → 播放服务跳过） */
  private skipEpisode(): void {
    QueueEngine.autoAdvance(false).catch((error: Error) => {
      this.showMessage(error.message);
    });
  }

  private async removeFromInboxItem(): Promise<void> {
    if (this.actionItem === undefined) {
      return;
    }
    const item: FeedItem = this.actionItem!;
    try {
      await EpisodeRepository.setNewFlag(item.id, false);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.refreshRow(item.id);
      await this.refreshCounts();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  private markPlayedItem(played: boolean): void {
    if (this.actionItem !== undefined) {
      this.markPlayed(this.actionItem!, played);
    }
  }

  private removeFromQueueItem(): void {
    if (this.actionItem !== undefined) {
      this.removeFromQueue(this.actionItem!.id);
    }
  }

  private downloadItem(): void {
    if (this.actionItem !== undefined) {
      this.startDownload(this.actionItem!);
    }
  }

  private deleteItem(): void {
    if (this.actionItem !== undefined) {
      this.deleteDownload(this.actionItem!);
    }
  }

  private favoriteItem(favorite: boolean): void {
    if (this.actionItem !== undefined) {
      this.setFavorite(this.actionItem!, favorite);
    }
  }

  private resetPositionItem(): void {
    if (this.actionItem !== undefined) {
      this.resetPosition(this.actionItem!);
    }
  }

  private shareItem(): void {
    if (this.actionItem !== undefined) {
      this.share(this.actionItem!);
    }
  }
}
