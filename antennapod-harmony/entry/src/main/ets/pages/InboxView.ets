import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';
import { EpisodeRepository, InboxCursor } from '../db/repositories/EpisodeRepository';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { MediaType, SortOrder } from '../model/Enums';
import { Playable } from '../model/Playable';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { DownloadManager } from '../download/DownloadManager';
import { RefreshService } from '../services/RefreshService';
import { UserPreferences } from '../prefs/UserPreferences';
import { EventHub, EventType, FeedItemUpdateData, EpisodeDownloadData } from '../events/EventHub';
import { DurationUtils } from '../utils/DurationUtils';
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
import { LazyDataSource } from '../components/LazyDataSource';
import { SwipeActionButton } from '../components/SwipeActionButton';
import { TagChip } from '../components/TagChip';

/** 收件箱排序面板的一格（对照上游 InboxSortDialog.onAddItem；只提供「日期 / 时长」两类） */
interface InboxSortChip {
  label: ResourceStr;
  ascending: SortOrder;
  descending: SortOrder;
  /** 首次点击该格时用升序还是降序（上游 ascendingIsDefault） */
  ascendingIsDefault: boolean;
}

/** 收件箱多选动作栏的一项 */
interface InboxMenuItem {
  id: string;
  label: ResourceStr;
  icon: Resource;
  destructive: boolean;
}

/**
 * Inbox：新单集收件箱（read = -1，对照上游 InboxFragment 的 FeedItemFilter(NEW)）。
 *
 * 相对布局（对齐上游 `episodes_list_fragment.xml` + `menu/inbox.xml` + `feeditemlist_item.xml`）：
 * 标题栏 = 大标题「收件箱」+ 搜索图标 + ⋮ 溢出菜单（刷新 / 排序 / 全部移出收件箱）；
 * 多选时标题栏换成「N/M 已选 + 全选溢出 + 关闭」；列表行的左右留白用 4vp（上游行 inset 4dp）。
 *
 * 手势（对照上游 SwipeActions：位移到位松手即执行，不是先弹回再点按钮）：
 * 右滑（`start` 划出项）/ 左滑（`end` 划出项）的动作取自设置页的「滑动动作」偏好，
 * 默认右滑 = 加入队列、左滑 = 移出收件箱；长按 = 上下文操作弹层（含多选）；
 * 单击 = 播放（上游是单集详情页，本移植版没有该页，见 docs/07-ui-layout-parity.md 第 35 条）。
 *
 * 分页（对齐上游 EpisodesListFragment 的无限滚动）：首屏只取一页，
 * 列表用 LazyForEach 惰性渲染，滚到底部再取下一页——OPML 导入上千条新单集时
 * 既不会一次性拉全库 + 逐条查媒体，也不会一次性构建上千个列表行。
 */
@Component
export struct InboxView {
  @Prop asTab: boolean = false;
  /** 已加载到列表中的条数（空状态判断 + 多选计数用；LazyDataSource 本身不是状态变量） */
  @State loadedCount: number = 0;
  /** 数据库中全部「新」单集数（多选「全选」的显示依据） */
  @State totalCount: number = 0;
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = false;
  @State message: string = '';
  @State showRemoveAll: boolean = false;
  /** 「全部移出」弹层里的「不再显示」勾选态 */
  @State removeAllChecked: boolean = false;
  @State showSortSheet: boolean = false;
  /** 收件箱排序（上游 prefInboxSortedOrder，默认最新在前） */
  @State sortOrder: SortOrder = SortOrder.DATE_NEW_OLD;
  @State showActionSheet: boolean = false;
  @State actionItem: FeedItem | undefined = undefined;
  @State actionTitle: string = '';
  /** 多选态（上游 ActionMode） */
  @State selectMode: boolean = false;
  @State selectedIds: number[] = [];
  /**
   * 「全选 / 向下全选」是否连带**尚未加载的页**（上游 `SelectableAdapter.shouldSelectLazyLoadedItems`）。
   * 为真时标题栏计数把未加载的条数也算作已选，批量动作会继续按游标读后面的页并逐条施加。
   */
  @State selectAllLazy: boolean = false;
  /** 「标记已播放 / 未播放」的二次确认弹层（上游 ConfirmationDialog） */
  @State showMarkConfirm: boolean = false;
  /** 左右滑动作 id（对照上游 SwipeActions.getSwipeActions；设置页保存后重新解析） */
  @State swipeRightId: string = SwipeActionId.NONE;
  @State swipeLeftId: string = SwipeActionId.NONE;
  /** 刷新中（下拉刷新转圈） */
  @State refreshing: boolean = false;
  /** 行内状态：LazyForEach 的行不会因外部变化重建，靠这些状态 + notifyDataChange 驱动 */
  @State favoriteIds: number[] = [];
  @State queueIds: number[] = [];
  @State playingMediaId: number = -1;
  @State playingPosition: number = 0;
  @State playingDuration: number = 0;
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  private cursor: InboxCursor | undefined = undefined;
  private loadedIds: Set<number> = new Set<number>();
  private feedTitles: Map<number, string> = new Map<number, string>();
  private feedImages: Map<number, string> = new Map<number, string>();
  private feedListToken: number = -1;
  private swipeToken: number = -1;
  private itemToken: number = -1;
  private playerToken: number = -1;
  private downloadToken: number = -1;
  private positionToken: number = -1;
  private messageTimerId: number = -1;
  private listScroller: ListScroller = new ListScroller();
  /** 首屏加载完成后是否还要恢复滚动位置（上游 onItemsFirstLoaded → restoreScrollPosition） */
  private restoreScrollPending: boolean = true;
  private refreshingNow: boolean = false;
  /** 每页条数（上游 EPISODES_PER_PAGE=150；这里取 50，首屏更快、滚动中补页更平滑） */
  private static readonly PAGE_SIZE: number = 50;
  /**
   * 划出后继续拖动的距离阈值（vp）：进入该区域后松手立即执行动作（`onAction`）。
   * 默认 56vp 对收件箱行偏长，这里取 40vp——总位移约 128vp，与上游 85% 位移阈值手感相当。
   */
  private static readonly SWIPE_ACTION_DISTANCE: number = 40;
  /** 操作弹层最大高度（vp），超出可滚 */
  private static readonly SHEET_MAX_HEIGHT: number = 460;
  /** 多选动作栏占位高度（列表底部内边距，避免最后一行被动作栏盖住） */
  private static readonly SELECT_BAR_SPACE: number = 128;
  /** 选中达到该条数就要求二次确认（上游 EpisodesListFragment：>= 25） */
  private static readonly MARK_CONFIRM_THRESHOLD: number = 25;
  /** 连带未加载页时的最大续读页数（纯保险，避免异常数据导致死循环；上游无此上限） */
  private static readonly MAX_LAZY_PAGES: number = 1000;
  /** 「标记已播放 / 未播放」待确认的意图（上游 ConfirmationDialog 确认后才执行） */
  private pendingMarkPlayed: boolean = false;

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
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
        }

        if (this.loading) {
          Text($r('app.string.loading'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
        } else if (this.loadedCount === 0) {
          Column() {
            EmptyState({
              icon: $r('sys.symbol.inbox'),
              title: $r('app.string.inbox_empty'),
              sub: $r('app.string.inbox_empty_message')
            })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          this.listContent()
        }
      }
      .width('100%')
      .height('100%')

      // 多选动作栏（上游 FloatingSelectMenu，贴底）
      if (this.selectMode && this.selectedIds.length > 0) {
        this.selectionBar()
      }

      if (this.showRemoveAll) {
        this.sheetBackdrop(() => {
          this.showRemoveAll = false;
        })
        this.removeAllSheet()
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
          this.actionItem = undefined;
        })
        this.actionSheet()
      }

      // 标记已播 / 未播的二次确认（居中对话框，盖住底部弹层）
      if (this.showMarkConfirm) {
        this.markConfirmDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
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

  /**
   * 标记已播 / 未播的二次确认（上游 `ConfirmationDialog(activity, R.string.multi_select, ...)`）：
   * 选中 >= 25 条、或「全选」连带未加载页时先问一次（可能要改动上千条）。
   */
  @Builder
  markConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showMarkConfirm = false;
        })
      Column({ space: DesignTokens.SPACE_M }) {
        Text($r('app.string.multi_select'))
          .fontSize(DesignTokens.FONT_SECTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text(this.pendingMarkPlayed
          ? $r('app.string.multi_select_mark_played_confirmation')
          : $r('app.string.multi_select_mark_unplayed_confirmation'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Row({ space: DesignTokens.SPACE_M }) {
          Button($r('app.string.dialog_cancel'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .onClick(() => {
              this.showMarkConfirm = false;
            })
          Button($r('app.string.confirm_label'))
            .layoutWeight(1)
            .height(DesignTokens.HEIGHT_BUTTON)
            .backgroundColor($r('app.color.primary'))
            .fontColor($r('app.color.on_primary'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .onClick(() => {
              this.confirmMarkPlayed();
            })
        }
        .width('100%')
      }
      .width('86%')
      .padding(DesignTokens.PAGE_MARGIN)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(DesignTokens.RADIUS_CARD)
    }
    .width('100%')
    .height('100%')
  }

  // ---------------------------------------------------------------- 标题栏

  /**
   * 常态标题栏（上游 `menu/inbox.xml`）：只有「搜索」是常显图标动作，
   * 「刷新 / 排序 / 全部移出收件箱」都收在右侧溢出菜单里。上游不显示未读数胶囊。
   */
  @Builder
  normalHeader() {
    if (this.asTab) {
      Row({ space: DesignTokens.SPACE_XS }) {
        Text($r('app.string.inbox_title'))
          .fontSize(DesignTokens.FONT_TITLE1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        AppIconButton({
          symbol: $r('sys.symbol.magnifyingglass'),
          onTap: () => {
            this.openSearch();
          }
        })
        OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
          this.overflowMenu()
        }
      }
      .width('100%')
      .height(DesignTokens.HEIGHT_APP_BAR)
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.SPACE_S })
    } else {
      AppBar({ title: $r('app.string.inbox_title'), showBack: true }) {
        Row({ space: DesignTokens.SPACE_XS }) {
          AppIconButton({
            symbol: $r('sys.symbol.magnifyingglass'),
            onTap: () => {
              this.openSearch();
            }
          })
          OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
            this.overflowMenu()
          }
        }
      }
    }
  }

  /**
   * 多选态标题栏（上游 ActionMode：标题 "N/M selected" + 全选溢出 + 关闭）。
   * 分母是数据库里的「新」单集总数（上游 `setTotalNumberOfItems(getTotalEpisodeCount(NEW))`），
   * 分子在「全选连带未加载页」时把未加载的条数一并算入（上游 `onSelectedItemsUpdated`）。
   */
  @Builder
  selectHeader() {
    Row({ space: DesignTokens.SPACE_XS }) {
      Text($r('app.string.queue_selected_count', this.selectedForLabel().toString(), this.totalCount.toString()))
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

  /** 收件箱溢出菜单（上游 inbox.xml：refresh_item / inbox_sort / remove_all_inbox_item） */
  @Builder
  overflowMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.arrow_clockwise')), content: $r('app.string.refresh_label') })
        .onClick(() => {
          this.refreshFeeds();
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.sort')), content: $r('app.string.feed_sort') })
        .onClick(() => {
          this.openSortSheet();
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.trash')), content: $r('app.string.remove_all_inbox_label') })
        .onClick(() => {
          this.onRemoveAllTap();
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

  // ---------------------------------------------------------------- 列表

  @Builder
  listContent() {
    Refresh({ refreshing: this.refreshing }) {
      List({ space: DesignTokens.SPACE_XS, scroller: this.listScroller }) {
        LazyForEach(this.dataSource, (item: FeedItem) => {
          ListItem() {
            this.episodeRow(item)
          }
          // 双向滑动都是「拖到动作区松手即执行」：
          // 左右两个动作来自设置页配置（`start` = 右滑，`end` = 左滑），未配置的一侧不挂划出项。
          .swipeAction(this.swipeOptions(item))
        }, (item: FeedItem) => this.rowKey(item))

        // 无限滚动页脚：还有下一页时显示加载指示（滚到底部自动续读）
        if (this.hasMore) {
          ListItem() {
            Row({ space: DesignTokens.SPACE_S }) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color($r('app.color.primary'))
              Text($r('app.string.loading'))
                .fontSize(DesignTokens.FONT_CAPTION)
                .fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            .height(48)
            .justifyContent(FlexAlign.Center)
          }
        }
      }
      .width('100%')
      .height('100%')
      // 左右只留 4vp：上游列表的页面内边距 additional_horizontal_spacing = 0dp，
      // 行底自身有 4dp inset（bg_episode_list_item），合计封面离屏 16dp
      .padding({
        left: DesignTokens.SPACE_XS,
        right: DesignTokens.SPACE_XS,
        top: DesignTokens.SPACE_XS,
        bottom: this.selectMode ? InboxView.SELECT_BAR_SPACE : DesignTokens.SPACE_M
      })
      .scrollBar(BarState.Off)
      .onReachEnd(() => {
        this.loadMore();
      })
    }
    .layoutWeight(1)
    .onRefreshing(() => {
      this.refreshFeeds();
    })
  }

  @Builder
  episodeRow(item: FeedItem) {
    EpisodeRow({
      title: item.title,
      imageUrl: item.imageUrl !== '' ? item.imageUrl : this.feedImage(item.feedId),
      coverFallbackTitle: this.feedTitle(item.feedId),
      metaText: this.metaText(item),
      positionText: this.positionText(item),
      durationText: this.durationText(item),
      progress: this.progress(item),
      playing: this.isCurrentlyPlaying(item.id),
      isPlayed: item.isPlayed,
      isNew: item.isNew(),
      isFavorite: this.favoriteIds.includes(item.id),
      inQueue: this.queueIds.includes(item.id),
      isVideo: this.isVideo(item),
      selected: this.selectedIds.includes(item.id),
      actionIcon: this.secondaryIcon(item),
      downloadProgress: this.downloadProgress(item),
      downloadIndeterminate: this.downloadIndeterminate(item),
      onTap: () => {
        if (this.selectMode) {
          this.toggleSelected(item.id);
        } else {
          this.play(item);
        }
      },
      onAction: () => {
        if (this.selectMode) {
          this.toggleSelected(item.id);
          return;
        }
        this.secondaryAction(item);
      },
      onLongPress: () => {
        this.openRowMenu(item);
      }
    })
  }

  /** 多选动作栏（上游 FloatingSelectMenu + episodes_apply_action_speeddial） */
  @Builder
  selectionBar() {
    Scroll() {
      Row({ space: DesignTokens.SPACE_XS }) {
        ForEach(this.batchActions(), (entry: InboxMenuItem) => {
          Column({ space: DesignTokens.SPACE_XS }) {
            SymbolGlyph(entry.icon)
              .fontSize(DesignTokens.ICON_L)
              .fontColor([entry.destructive ? $r('app.color.error') : $r('app.color.text_secondary')])
            Text(entry.label)
              .fontSize(DesignTokens.FONT_CAPTION)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
          }
          .padding(DesignTokens.SPACE_S)
          .onClick(() => {
            this.runBatchAction(entry.id);
          })
        }, (entry: InboxMenuItem) => entry.id)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_S })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_ROW)
    .margin({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
  }

  // ---------------------------------------------------------------- 弹层

  /** 「移除全部」确认弹层（对照上游 showRemoveAllDialog：标题 + 说明 + 不再显示 + 取消/确认） */
  @Builder
  removeAllSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      Text($r('app.string.remove_all_inbox_label'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: DesignTokens.SPACE_L })
      Text($r('app.string.remove_all_inbox_confirmation_msg'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Row({ space: DesignTokens.SPACE_S }) {
        Checkbox({ name: 'inboxRemoveAllPrompt', group: 'inboxRemoveAll' })
          .select(this.removeAllChecked)
          .onChange((value: boolean) => {
            this.removeAllChecked = value;
          })
        Text($r('app.string.checkbox_do_not_show_again'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .onClick(() => {
            this.removeAllChecked = !this.removeAllChecked;
          })
      }
      .width('100%')
      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .onClick(() => {
            this.showRemoveAll = false;
          })
        Button($r('app.string.confirm_label'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .onClick(() => {
            this.removeAllFromInbox();
          })
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.PAGE_MARGIN })
  }

  /**
   * 排序面板（对照上游 InboxSortDialog）：只列「日期 / 时长」两个 chip，
   * 激活项标签带 ▲（升序）/ ▼（降序），再次点击翻转方向；选中即持久化并重载列表。
   */
  @Builder
  sortSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      Text($r('app.string.feed_sort'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: DesignTokens.SPACE_L })
      Row({ space: DesignTokens.SPACE_S }) {
        ForEach(this.sortChips(), (chip: InboxSortChip) => {
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
        }, (chip: InboxSortChip) => chip.ascending.toString() + '-' + chip.descending.toString())
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
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
  }

  /** 长按操作弹层（上游 feeditemlist_context.xml + FeedItemMenuHandler.onPrepareMenu） */
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

        if (this.canSkipActionItem()) {
          this.actionRow($r('sys.symbol.forward_end_fill'), $r('app.string.skip_episode_label'), () => {
            this.skipEpisode();
          })
        }
        this.actionRow($r('sys.symbol.inbox'), $r('app.string.remove_inbox_label'), () => {
          this.removeFromInboxItem();
        })
        if (this.actionItemPlayed()) {
          this.actionRow($r('sys.symbol.circle'), $r('app.string.episode_mark_unplayed'), () => {
            this.markPlayedItem(false);
          })
        } else {
          this.actionRow($r('sys.symbol.checkmark_circle'), $r('app.string.episode_mark_played'), () => {
            this.markPlayedItem(true);
          })
        }
        if (this.actionItemQueued()) {
          this.actionRow($r('sys.symbol.xmark_circle'), $r('app.string.swipe_action_remove_from_queue'), () => {
            this.removeFromQueueItem();
          })
        } else {
          this.actionRow($r('sys.symbol.music_note_list'), $r('app.string.episode_add_queue'), () => {
            this.addToQueueItem();
          })
        }
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
            this.actionItem = undefined;
          })
      }
      .width('100%')
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
    }
    .constraintSize({ maxHeight: InboxView.SHEET_MAX_HEIGHT })
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
   * 划出项配置：左右两个动作都取自偏好（`SwipeActions.resolve`），
   * 该屏幕关闭滑动动作、或某一侧配置为「无」时，对应侧不挂划出项。
   */
  private swipeOptions(item: FeedItem): SwipeActionOptions {
    const options: SwipeActionOptions = {};
    if (!SwipeActions.isEnabled(SwipeScreen.INBOX) || this.selectMode) {
      return options;
    }
    if (this.swipeRightId !== SwipeActionId.NONE) {
      const rightSpec: SwipeActionSpec = swipeActionSpec(this.swipeRightId);
      const rightItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(rightSpec, item);
        },
        actionAreaDistance: InboxView.SWIPE_ACTION_DISTANCE,
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
        actionAreaDistance: InboxView.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(this.swipeLeftId, item);
        }
      };
      options.end = leftItem;
    }
    return options;
  }

  /**
   * 划出项按钮（图标 + 名称，破坏性动作用 error 配色）。
   * 拖到动作区松手由 `onAction` 触发，近距划出后点按钮同样执行动作。
   * 注意：builder 在渲染期就会执行，绝不能在这里直接调用副作用方法。
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

  /** 划出项动作分发（动作集合见 SwipeActions.availableIds：收件箱不含标记已播 / 删除文件） */
  private runSwipeAction(id: string, item: FeedItem): void {
    if (id === SwipeActionId.ADD_TO_QUEUE) {
      this.addToQueue(item);
      return;
    }
    if (id === SwipeActionId.REMOVE_FROM_INBOX) {
      this.removeFromInbox(item);
      return;
    }
    if (id === SwipeActionId.START_DOWNLOAD) {
      this.startDownload(item);
      return;
    }
    if (id === SwipeActionId.MARK_FAV) {
      this.setFavorite(item, true);
      return;
    }
    if (id === SwipeActionId.SHARE) {
      this.share(item);
    }
  }

  /**
   * 解析本屏的 [右滑, 左滑] 动作 id（aboutToAppear 与 SWIPE_ACTIONS_CHANGED 时调用）。
   * 存量偏好里可能还留着本端已不再提供、但历史上可用的动作，这里只放行当前动作集合里的 id。
   */
  private loadSwipeActions(): void {
    const ids: string[] = SwipeActions.resolve(SwipeScreen.INBOX);
    this.swipeRightId = this.filterSwipeId(ids[0]);
    this.swipeLeftId = this.filterSwipeId(ids[1]);
  }

  private filterSwipeId(id: string): string {
    const available: SwipeActionSpec[] = SwipeActions.available(SwipeScreen.INBOX);
    for (const spec of available) {
      if (spec.id === id) {
        return id;
      }
    }
    return SwipeActionId.NONE;
  }

  // ---------------------------------------------------------------- 生命周期

  aboutToAppear(): void {
    this.sortOrder = UserPreferences.getInboxSortedOrder() as SortOrder;
    this.removeAllChecked = UserPreferences.getRemoveAllInboxDoNotPrompt();
    this.loadSwipeActions();
    this.load();
    // 订阅/刷新/OPML 导入后自动刷新首屏（刷新与导入各只发一次 FEED_LIST_UPDATE，不会抖动）
    this.feedListToken = EventHub.subscribe(EventType.FEED_LIST_UPDATE, (data: object) => {
      this.onFeedListUpdate();
    });
    // 设置页保存「滑动动作」后重新解析左右滑动作
    this.swipeToken = EventHub.subscribe(EventType.SWIPE_ACTIONS_CHANGED, (data: object) => {
      this.loadSwipeActions();
    });
    // 别处改单集状态（播放页听完自动标已播、订阅详情移出收件箱、批量标记）→ 本页行同步
    this.itemToken = EventHub.subscribe(EventType.FEED_ITEM_UPDATE, (data: object) => {
      this.onFeedItemUpdate(data);
    });
    // 播放状态变化：行内次级按钮要在「播放中 → 暂停」之间切换
    this.playerToken = EventHub.subscribe(EventType.PLAYER_STATUS, (data: object) => {
      this.syncPlayingRow();
    });
    // 下载进度：只刷受影响的行
    this.downloadToken = EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.onDownloadEvent(data);
    });
    // 播放进度：只改正在播放这一行的位置与进度条（上游 notifyPlaybackPositionUpdated）
    this.positionToken = EventHub.subscribe(EventType.PLAYBACK_POSITION, (data: object) => {
      this.onPlaybackPosition(data);
    });
  }

  aboutToDisappear(): void {
    const tokens: number[] = [this.feedListToken, this.swipeToken, this.itemToken,
      this.playerToken, this.downloadToken, this.positionToken];
    for (const token of tokens) {
      if (token >= 0) {
        EventHub.unsubscribeToken(token);
      }
    }
    this.feedListToken = -1;
    this.swipeToken = -1;
    this.itemToken = -1;
    this.playerToken = -1;
    this.downloadToken = -1;
    this.positionToken = -1;
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
      this.messageTimerId = -1;
    }
    // 记住滚动位置（上游 InboxFragment.onPause 存 scrollPosition）
    try {
      const offset: OffsetResult = this.listScroller.currentOffset();
      UserPreferences.setInboxScrollOffset(offset.yOffset);
    } catch (error) {
      // 列表尚未绑定时忽略：位置不是关键功能
    }
  }

  // ---------------------------------------------------------------- 数据

  /** 首屏 / 手动刷新：重新从第一页开始取，并复位游标 */
  async load(): Promise<void> {
    this.loading = true;
    try {
      const wasEmpty: boolean = this.dataSource.totalCount() === 0;
      await this.loadFeedLookup();
      await this.loadRowState();
      this.totalCount = await EpisodeRepository.countNew();
      const items: FeedItem[] = await EpisodeRepository.listInboxPage(InboxView.PAGE_SIZE, this.sortOrder);
      this.cursor = undefined;
      this.loadedIds = new Set<number>();
      this.dataSource.setData(items);
      this.loadedCount = items.length;
      this.remember(items);
      this.hasMore = items.length === InboxView.PAGE_SIZE;
      if (this.restoreScrollPending && wasEmpty) {
        this.restoreScrollPending = false;
        this.restoreScrollPosition();
      }
    } catch (error) {
      this.cursor = undefined;
      this.loadedIds = new Set<number>();
      this.dataSource.setData([]);
      this.loadedCount = 0;
      this.totalCount = 0;
      this.hasMore = false;
      this.showMessage((error as Error).message);
    } finally {
      this.loading = false;
    }
  }

  /** 滚到底部：按游标续读下一页并增量追加（不重建列表，滚动位置不变） */
  async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore || this.cursor === undefined) {
      return;
    }
    this.loadingMore = true;
    try {
      const items: FeedItem[] = await EpisodeRepository.listInboxPage(
        InboxView.PAGE_SIZE, this.sortOrder, this.cursor);
      const fresh: FeedItem[] = items.filter((item: FeedItem) => !this.loadedIds.has(item.id));
      this.dataSource.appendData(fresh);
      this.loadedCount = this.dataSource.totalCount();
      this.remember(items);
      this.hasMore = items.length === InboxView.PAGE_SIZE;
    } catch (error) {
      this.hasMore = false;
      this.showMessage((error as Error).message);
    } finally {
      this.loadingMore = false;
    }
  }

  /** 记录本页游标与已加载 id（去重 + 翻页续读） */
  private remember(items: FeedItem[]): void {
    for (const item of items) {
      this.loadedIds.add(item.id);
    }
    const next: InboxCursor | undefined = InboxView.cursorOf(items);
    if (next !== undefined) {
      this.cursor = next;
    }
  }

  /** 一页数据 → 续读游标（排序键 + id）；空页返回 undefined */
  private static cursorOf(items: FeedItem[]): InboxCursor | undefined {
    if (items.length === 0) {
      return undefined;
    }
    const last: FeedItem = items[items.length - 1];
    const media: FeedMedia | undefined = last.media;
    return {
      pubDate: last.pubDate,
      duration: media === undefined ? 0 : media.duration,
      id: last.id
    };
  }

  /**
   * 上游 `EpisodesListFragment.performMultiSelectAction` 的「连带未加载页」部分：
   * 从当前游标继续读后面的页（与上游直接调 `loadMoreData(page)` 一样，不把这些页塞进列表），
   * 对每一条施加同一动作。只有 `shouldSelectLazyLoadedItems`（= 全选 / 向下全选）为真时才做。
   *
   * @returns 施加动作的未加载条目数
   */
  private async forEachUnloadedItem(action: (item: FeedItem) => Promise<void>): Promise<number> {
    if (!this.selectAllLazy || !this.hasMore || this.cursor === undefined) {
      return 0;
    }
    let cursor: InboxCursor | undefined = this.cursor;
    let applied: number = 0;
    let pages: number = 0;
    while (cursor !== undefined && pages < InboxView.MAX_LAZY_PAGES) {
      pages++;
      const page: FeedItem[] = await EpisodeRepository.listInboxPage(
        InboxView.PAGE_SIZE, this.sortOrder, cursor);
      if (page.length === 0) {
        break;
      }
      for (const item of page) {
        if (this.loadedIds.has(item.id)) {
          continue;
        }
        await action(item);
        applied++;
      }
      if (page.length < InboxView.PAGE_SIZE) {
        break;
      }
      cursor = InboxView.cursorOf(page);
    }
    return applied;
  }

  /** 逐条广播单集更新：已加载的行就地重绘，首页 / 底栏角标同步刷新 */
  private publishItemUpdates(items: FeedItem[]): void {
    for (const item of items) {
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
    }
  }

  /** 整体变更广播（feedId/itemId 都为 0）：本页与首页 / 底栏角标统一重载 */
  private publishBulkUpdate(): void {
    const data: FeedItemUpdateData = { feedId: 0, itemId: 0 };
    EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
  }

  /** 标已播/移出收件箱会减少已加载行数，不足一页时补一页，避免列表短到无法触发 onReachEnd */
  private fillIfShort(): void {
    if (this.hasMore && !this.loadingMore && this.dataSource.totalCount() < InboxView.PAGE_SIZE) {
      this.loadMore();
    }
  }

  private dropItem(itemId: number): void {
    const index: number = this.dataSource.getDataArray()
      .findIndex((entry: FeedItem) => entry.id === itemId);
    if (index < 0) {
      return;
    }
    this.dataSource.removeAt(index);
    this.loadedIds.delete(itemId);
    this.loadedCount = this.dataSource.totalCount();
    // 行被移出列表后，它的选中态也必须同步清掉（否则标题栏计数与实际行对不上）
    this.removeFromSelection(itemId);
  }

  /** 恢复上次离开收件箱时的滚动位置（上游 restoreScrollPosition） */
  private restoreScrollPosition(): void {
    const offset: number = UserPreferences.getInboxScrollOffset();
    if (offset <= 0) {
      return;
    }
    try {
      this.listScroller.scrollTo({ xOffset: 0, yOffset: offset });
    } catch (error) {
      // 列表尚未完成布局时忽略：位置不是关键功能
    }
  }

  /** FEED_LIST_UPDATE：已深度翻页时只更新计数，避免把滚动位置重置回顶部 */
  private onFeedListUpdate(): void {
    if (this.loading) {
      return;
    }
    if (this.loadedCount > InboxView.PAGE_SIZE) {
      this.refreshTotal();
      return;
    }
    this.load();
  }

  private async refreshTotal(): Promise<void> {
    try {
      this.totalCount = await EpisodeRepository.countNew();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /**
   * 单集状态变化（上游 `onEventMainThread(FeedItemEvent)`）：读一次该条目的最新状态，
   * 不再「新」的行移出列表，仍「新」的行就地重绘。
   */
  private async onFeedItemUpdate(data: object): Promise<void> {
    const payload: FeedItemUpdateData = data as FeedItemUpdateData;
    if (payload.itemId <= 0) {
      // feedId/itemId 都为 0 的广播（如「全部移出」）：整体重载
      this.load();
      return;
    }
    if (!this.loadedIds.has(payload.itemId)) {
      await this.refreshTotal();
      return;
    }
    const fresh: FeedItem | undefined = await EpisodeRepository.getById(payload.itemId);
    if (fresh === undefined || !fresh.isNew()) {
      this.dropItem(payload.itemId);
      await this.refreshTotal();
      this.fillIfShort();
      return;
    }
    this.replaceRow(fresh);
  }

  /** 下载事件：只刷新受影响的行；完成时该行的 file_url 变了，需要重新查库 */
  private async onDownloadEvent(data: object): Promise<void> {
    const payload: EpisodeDownloadData = data as EpisodeDownloadData;
    const index: number = this.indexOfMedia(payload.mediaId);
    if (index < 0) {
      return;
    }
    if (payload.state === 'DONE' || payload.state === 'REMOVED') {
      const fresh: FeedItem | undefined = await EpisodeRepository.getById(
        this.dataSource.getDataArray()[index].id);
      if (fresh !== undefined) {
        this.replaceRow(fresh);
      }
      return;
    }
    this.dataSource.notifyDataChange(index);
  }

  /** 播放状态变化：当前播放项变了，行内次级按钮要跟着切（播放 / 暂停） */
  private syncPlayingRow(): void {
    const current: Playable | undefined = PlayerManager.getCurrent();
    const mediaId: number = current === undefined ? -1 : current.id;
    const changed: number = this.indexOfMedia(mediaId);
    const previous: number = this.indexOfMedia(this.playingMediaId);
    this.playingMediaId = mediaId;
    if (previous >= 0) {
      this.dataSource.notifyDataChange(previous);
    }
    if (changed >= 0) {
      this.dataSource.notifyDataChange(changed);
    }
  }

  /** 播放进度推进：只改正在播放这一行的位置与进度条 */
  private onPlaybackPosition(data: object): void {
    const record: Record<string, number> = data as Record<string, number>;
    const time: number | undefined = record['time'];
    const duration: number | undefined = record['duration'];
    if (time !== undefined) {
      this.playingPosition = time;
    }
    if (duration !== undefined && duration > 0) {
      this.playingDuration = duration;
    }
    const index: number = this.indexOfMedia(this.playingMediaId);
    if (index >= 0) {
      this.dataSource.notifyDataChange(index);
    }
  }

  private indexOfMedia(mediaId: number): number {
    if (mediaId < 0) {
      return -1;
    }
    return this.dataSource.getDataArray().findIndex((entry: FeedItem) =>
    entry.media !== undefined && entry.media.id === mediaId);
  }

  /** 就地替换一行并只重绘该行 */
  private replaceRow(fresh: FeedItem): void {
    const data: FeedItem[] = this.dataSource.getDataArray();
    const index: number = data.findIndex((entry: FeedItem) => entry.id === fresh.id);
    if (index < 0) {
      return;
    }
    data[index] = fresh;
    this.dataSource.notifyDataChange(index);
  }

  /** 订阅标题与封面（行内封面回退 / 无封面占位文字用），只查一次 */
  private async loadFeedLookup(): Promise<void> {
    const feeds: Feed[] = await FeedRepository.listSubscribed();
    const titles: Map<number, string> = new Map<number, string>();
    const images: Map<number, string> = new Map<number, string>();
    for (const feed of feeds) {
      titles.set(feed.id, feed.getTitle());
      images.set(feed.id, feed.imageUrl);
    }
    this.feedTitles = titles;
    this.feedImages = images;
  }

  /** 收藏 / 已在队列的行内状态（FeedItem 里没有这两个标记，上游是 TAG_FAVORITE / TAG_QUEUE） */
  private async loadRowState(): Promise<void> {
    const favorites: FeedItem[] = await FavoritesRepository.list();
    this.favoriteIds = favorites.map((entry: FeedItem) => entry.id);
    await QueueEngine.load();
    this.queueIds = QueueEngine.getItems().map((entry: FeedItem) => entry.id);
  }

  private async refreshRowState(): Promise<void> {
    await this.loadRowState();
    const data: FeedItem[] = this.dataSource.getDataArray();
    for (let i: number = 0; i < data.length; i++) {
      this.dataSource.notifyDataChange(i);
    }
  }

  feedImage(feedId: number): string {
    return this.feedImages.get(feedId) ?? '';
  }

  feedTitle(feedId: number): string {
    return this.feedTitles.get(feedId) ?? '';
  }

  // ---------------------------------------------------------------- 行内动作

  /** 单击 = 播放（上游是单集详情页，本移植版没有该页） */
  async play(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    try {
      const playable: Playable | undefined = await QueueEngine.toPlayable(item);
      if (playable === undefined) {
        return;
      }
      await QueueEngine.ensureQueued(item);
      await PlayerManager.load(playable, item.media.position, true);
      router.pushUrl({ url: 'pages/PlayerPage' });
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /**
   * 行内次级操作钮，逐条对照上游 `ItemActionButton.forItem`：
   * 无媒体 → 标记已播；正在播放 → 暂停；已下载 → 播放；
   * 下载中 → 取消下载；开了「流播优先」→ 流播；其余 → 下载。
   */
  async secondaryAction(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      this.togglePlayed(item);
      return;
    }
    if (this.isPlaying(item.id)) {
      PlayerManager.pause();
      return;
    }
    if (media.fileUrl !== '') {
      await this.play(item);
      return;
    }
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      await this.cancelDownload(item);
      return;
    }
    if (UserPreferences.getStreamOverDownload()) {
      await this.play(item);
      return;
    }
    await this.startDownload(item);
  }

  /** 副操作钮图标（与 `secondaryAction` 一一对应） */
  secondaryIcon(item: FeedItem): Resource {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      return $r('sys.symbol.checkmark_circle');
    }
    if (this.isPlaying(item.id)) {
      return $r('sys.symbol.pause_fill');
    }
    if (media.fileUrl !== '') {
      return $r('sys.symbol.play_fill');
    }
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return $r('sys.symbol.xmark_circle');
    }
    if (UserPreferences.getStreamOverDownload()) {
      return $r('sys.symbol.play_fill');
    }
    return $r('sys.symbol.arrow_down_circle');
  }

  /** 下载按钮状态：优先看数据库 file_url，再看会话内任务状态 */
  private downloadState(item: FeedItem): string {
    if (item.media === undefined) {
      return 'IDLE';
    }
    if (item.media.fileUrl !== '') {
      return 'DONE';
    }
    return DownloadManager.getStatus(item.media.id);
  }

  /** 行内下载进度环的百分比；-1 = 不显示（对照上游 secondaryActionProgress） */
  private downloadProgress(item: FeedItem): number {
    if (item.media === undefined) {
      return -1;
    }
    const state: string = this.downloadState(item);
    if (state !== 'RUNNING' && state !== 'PAUSED') {
      return -1;
    }
    return DownloadManager.getProgressPercent(item.media.id);
  }

  private downloadIndeterminate(item: FeedItem): boolean {
    return item.media !== undefined && DownloadManager.isProgressIndeterminate(item.media.id);
  }

  /** 正在播放（上游 PlaybackStatus.isCurrentlyPlaying：当前媒体） */
  isCurrentlyPlaying(feedItemId: number): boolean {
    const current: Playable | undefined = PlayerManager.getCurrent();
    return current !== undefined && current.feedItemId === feedItemId;
  }

  /** 当前播放中的项且状态为播放中（上游 PlaybackStatus.isPlaying） */
  isPlaying(feedItemId: number): boolean {
    return this.isCurrentlyPlaying(feedItemId) && PlayerManager.getStatus() === 'PLAYING';
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

  async cancelDownload(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    try {
      await DownloadManager.remove(item.media.id);
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 标记已播 / 未播（收件箱里标已播 = 移出列表） */
  async togglePlayed(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.markPlayed(item.id, !item.isPlayed);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      this.showMessage(getContext(this).resourceManager.getStringSync(
        item.isPlayed ? $r('app.string.marked_unplayed_message') : $r('app.string.marked_played_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /**
   * 移出收件箱（对照上游 RemoveFromInboxSwipeAction / removeNewFlagWithUndo）：
   * 把「新」标记降级为未播放。行会因此移出列表，计数与分页补齐与 `markPlayed` 保持一致。
   */
  async removeFromInbox(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.setNewFlag(item.id, false);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      this.removeFromSelection(item.id);
      this.dropItem(item.id);
      if (this.totalCount > 0) {
        this.totalCount--;
      }
      this.fillIfShort();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.removed_from_inbox_msg')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /**
   * 加入队列（对照上游 AddToQueueSwipeAction）。入队时清除「新」标记（read = -1 → 0），
   * 与上游 DBWriter.addQueueItem 一致——因此该行会移出收件箱，而不是留在列表里。
   */
  async addToQueue(item: FeedItem): Promise<void> {
    try {
      await QueueEngine.add(item);
      await EpisodeRepository.setNewFlag(item.id, false);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      this.queueIds = QueueEngine.getItems().map((entry: FeedItem) => entry.id);
      this.removeFromSelection(item.id);
      this.dropItem(item.id);
      if (this.totalCount > 0) {
        this.totalCount--;
      }
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.queue_added')));
      this.fillIfShort();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async toggleFavorite(item: FeedItem): Promise<void> {
    await this.setFavorite(item, !this.favoriteIds.includes(item.id));
  }

  async setFavorite(item: FeedItem, favorite: boolean): Promise<void> {
    try {
      if (favorite) {
        await FavoritesRepository.add(item.id, item.feedId);
      } else {
        await FavoritesRepository.remove(item.id);
      }
      const favorites: FeedItem[] = await FavoritesRepository.list();
      this.favoriteIds = favorites.map((entry: FeedItem) => entry.id);
      this.replaceRow(item);
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 重置播放位置（上游 reset_position：位置归零并按未播处理） */
  async resetPosition(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      return;
    }
    try {
      await EpisodeRepository.updatePosition(media.id, 0);
      await EpisodeRepository.markPlayed(item.id, false);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      media.position = 0;
      this.replaceRow(item);
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 分享：复制单集链接到剪贴板（本 SDK 无系统分享面板 API，与订阅详情 / 播放页一致） */
  async share(item: FeedItem): Promise<void> {
    let link: string = item.link;
    const media: FeedMedia | undefined = item.media;
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

  /** 移除全部：把所有新标记降级为未播放（对照上游 DBWriter.removeAllNewFlags） */
  async removeAllFromInbox(): Promise<void> {
    this.showRemoveAll = false;
    UserPreferences.setRemoveAllInboxDoNotPrompt(this.removeAllChecked);
    try {
      await EpisodeRepository.removeAllNewFlags();
      const data: FeedItemUpdateData = { feedId: 0, itemId: 0 };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      this.cursor = undefined;
      this.loadedIds = new Set<number>();
      this.dataSource.setData([]);
      this.loadedCount = 0;
      this.totalCount = 0;
      this.hasMore = false;
      this.exitSelectMode();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.removed_all_inbox_msg')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  // ---------------------------------------------------------------- 刷新

  /** 标题栏「全部移出收件箱」：勾过「不再显示」就直接执行（上游 PREF_DO_NOT_PROMPT_REMOVE_ALL_FROM_INBOX） */
  private onRemoveAllTap(): void {
    if (UserPreferences.getRemoveAllInboxDoNotPrompt()) {
      this.removeAllFromInbox();
      return;
    }
    this.removeAllChecked = false;
    this.showRemoveAll = true;
  }

  /** 下拉 / 溢出菜单刷新：拉取订阅更新（上游 FeedUpdateManager.runOnceOrAsk） */
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

  // ---------------------------------------------------------------- 排序

  /** 收件箱排序项（上游 InboxSortDialog.onAddItem：只保留 日期 / 时长） */
  private sortChips(): InboxSortChip[] {
    const chips: InboxSortChip[] = [];
    chips.push({
      label: $r('app.string.sort_date_label'),
      ascending: SortOrder.DATE_OLD_NEW,
      descending: SortOrder.DATE_NEW_OLD,
      // 上游 ascendingIsDefault = false：首次点「日期」用降序（最新在前）
      ascendingIsDefault: false
    });
    chips.push({
      label: $r('app.string.sort_duration_label'),
      ascending: SortOrder.DURATION_SHORT_LONG,
      descending: SortOrder.DURATION_LONG_SHORT,
      ascendingIsDefault: true
    });
    return chips;
  }

  /** 激活的排序格：标签带 ▲（升序）/ ▼（降序）（上游 sort_dialog_item_active.xml） */
  private sortChipLabel(chip: InboxSortChip): ResourceStr {
    if (!this.isSortChipActive(chip)) {
      return chip.label;
    }
    const arrow: string = this.sortOrder === chip.ascending ? ' ▲' : ' ▼';
    return getContext(this).resourceManager.getStringSync(chip.label as Resource) + arrow;
  }

  private isSortChipActive(chip: InboxSortChip): boolean {
    return this.sortOrder === chip.ascending || this.sortOrder === chip.descending;
  }

  /**
   * 点排序格：未激活时用默认方向，已激活时翻转方向（上游 ItemSortDialog.onAddItem 的点击分支）。
   * 上游排序对话框选中后**不关闭**，格上的 ▲/▼ 就是方向反馈，这里保持一致（关闭走「取消」）。
   */
  private async pickSortChip(chip: InboxSortChip): Promise<void> {
    let order: SortOrder = chip.ascendingIsDefault ? chip.ascending : chip.descending;
    if (this.isSortChipActive(chip)) {
      order = this.sortOrder === chip.ascending ? chip.descending : chip.ascending;
    }
    this.sortOrder = order;
    UserPreferences.setInboxSortedOrder(order);
    await this.load();
  }

  private openSortSheet(): void {
    this.sortOrder = UserPreferences.getInboxSortedOrder() as SortOrder;
    this.showSortSheet = true;
  }

  // ---------------------------------------------------------------- 长按操作弹层

  private openRowMenu(item: FeedItem): void {
    if (this.selectMode) {
      return;
    }
    this.actionItem = item;
    this.actionTitle = item.title;
    this.showActionSheet = true;
  }

  private actionItemPlayed(): boolean {
    return this.actionItem !== undefined && this.actionItem!.isPlayed;
  }

  private actionItemQueued(): boolean {
    return this.actionItem !== undefined && this.queueIds.includes(this.actionItem!.id);
  }

  private actionItemFavorite(): boolean {
    return this.actionItem !== undefined && this.favoriteIds.includes(this.actionItem!.id);
  }

  private actionItemHasPosition(): boolean {
    return this.actionItem !== undefined && this.actionItem!.media !== undefined
      && this.actionItem!.media!.position !== 0;
  }

  /** 上游 canSkip：只有正在播放的那一集能「跳过这一集」 */
  private canSkipActionItem(): boolean {
    return this.actionItem !== undefined && this.isPlaying(this.actionItem!.id);
  }

  private actionItemDownloadable(): boolean {
    if (this.actionItem === undefined) {
      return false;
    }
    const state: string = this.downloadState(this.actionItem!);
    return state !== 'DONE' && state !== 'RUNNING' && state !== 'PAUSED';
  }

  private actionItemDeletable(): boolean {
    if (this.actionItem === undefined) {
      return false;
    }
    const state: string = this.downloadState(this.actionItem!);
    return state === 'DONE' || state === 'RUNNING' || state === 'PAUSED';
  }

  /** 跳过这一集：结束当前播放并接着播队列里的下一集（上游 KEYCODE_MEDIA_NEXT） */
  private skipEpisode(): void {
    QueueEngine.autoAdvance(false).catch((error: Error) => {
      this.showMessage(error.message);
    });
  }

  private removeFromInboxItem(): void {
    if (this.actionItem !== undefined) {
      this.removeFromInbox(this.actionItem!);
    }
  }

  private markPlayedItem(played: boolean): void {
    if (this.actionItem === undefined) {
      return;
    }
    // 菜单项按当前状态二选一（标记已播 / 标记未播），因此这里等价于取反
    if (this.actionItem!.isPlayed === played) {
      return;
    }
    this.togglePlayed(this.actionItem!);
  }

  private addToQueueItem(): void {
    if (this.actionItem !== undefined) {
      this.addToQueue(this.actionItem!);
    }
  }

  private removeFromQueueItem(): void {
    if (this.actionItem === undefined) {
      return;
    }
    const item: FeedItem = this.actionItem!;
    QueueEngine.remove(item.id).then(() => {
      this.queueIds = QueueEngine.getItems().map((entry: FeedItem) => entry.id);
      this.replaceRow(item);
    }).catch((error: Error) => {
      this.showMessage(error.message);
    });
  }

  private downloadItem(): void {
    if (this.actionItem !== undefined) {
      this.startDownload(this.actionItem!);
    }
  }

  private deleteItem(): void {
    if (this.actionItem === undefined || this.actionItem!.media === undefined) {
      return;
    }
    DownloadManager.deleteFile(this.actionItem!.media!).catch((error: Error) => {
      this.showMessage(error.message);
    });
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

  // ---------------------------------------------------------------- 多选

  private enterSelectMode(): void {
    this.selectMode = true;
    this.selectedIds = [];
  }

  /** 操作弹层里的「多选」：进入多选并选中长按项 */
  private startSelectFromSheet(): void {
    if (this.actionItem === undefined) {
      return;
    }
    this.selectMode = true;
    this.selectedIds = [this.actionItem!.id];
  }

  private exitSelectMode(): void {
    this.selectMode = false;
    this.selectedIds = [];
    this.selectAllLazy = false;
    this.showMarkConfirm = false;
  }

  /**
   * 标题栏分子：上游 `onSelectedItemsUpdated` 在 `shouldSelectLazyLoadedItems` 为真时
   * 把 `totalNumberOfItems - getItemCount()`（即未加载的条数）也算作已选。
   */
  private selectedForLabel(): number {
    if (!this.selectAllLazy) {
      return this.selectedIds.length;
    }
    const unloaded: number = this.totalCount - this.loadedCount;
    return this.selectedIds.length + (unloaded > 0 ? unloaded : 0);
  }

  private toggleSelected(itemId: number): void {
    const index: number = this.dataSource.getDataArray()
      .findIndex((entry: FeedItem) => entry.id === itemId);
    if (this.selectedIds.includes(itemId)) {
      this.selectedIds = this.selectedIds.filter((id: number) => id !== itemId);
    } else {
      this.selectedIds = this.selectedIds.concat([itemId]);
    }
    if (this.selectedIds.length === 0) {
      this.selectMode = false;
    }
    if (index >= 0) {
      this.dataSource.notifyDataChange(index);
    }
  }

  /** 行被移出列表（移出收件箱 / 入队 / 标记已播）时同步清掉它的选中态 */
  private removeFromSelection(itemId: number): void {
    if (!this.selectedIds.includes(itemId)) {
      return;
    }
    this.selectedIds = this.selectedIds.filter((id: number) => id !== itemId);
    if (this.selectedIds.length === 0) {
      this.selectMode = false;
    }
  }

  private allSelected(): boolean {
    return this.loadedCount > 0 && this.selectedIds.length === this.loadedCount;
  }

  /**
   * 「全选 / 全部取消」（上游 `SelectableAdapter` 的 select_toggle）：
   * `selectAll = selectedIds.size() != getItemCount()`，选中时把
   * `shouldSelectLazyLoadedItems` 置真 —— 批量动作因此会连带尚未加载的页。
   */
  private toggleSelectAll(): void {
    if (this.allSelected()) {
      this.selectedIds = [];
      this.selectAllLazy = false;
      this.selectMode = false;
      this.refreshAllRows();
      return;
    }
    this.selectedIds = this.dataSource.getDataArray().map((item: FeedItem) => item.id);
    this.selectAllLazy = true;
    this.refreshAllRows();
  }

  /**
   * 向上全选：选中第一项到「第一个已选项」之前（上游 select_all_above）。
   * 上游这一支**不**改 `shouldSelectLazyLoadedItems`（向上不存在未加载的页）。
   */
  private selectAllAbove(): void {
    const data: FeedItem[] = this.dataSource.getDataArray();
    let first: number = -1;
    for (let i: number = 0; i < data.length; i++) {
      if (this.selectedIds.includes(data[i].id)) {
        first = i;
        break;
      }
    }
    if (first <= 0) {
      return;
    }
    const ids: number[] = this.selectedIds.slice();
    for (let i: number = 0; i < first; i++) {
      if (!ids.includes(data[i].id)) {
        ids.push(data[i].id);
      }
    }
    this.selectedIds = ids;
    this.refreshAllRows();
  }

  /**
   * 向下全选：选中「最后一个已选项」之后到列表末尾（上游 select_all_below）。
   * 上游这一支会把 `shouldSelectLazyLoadedItems` 置真 —— 往下的未加载页也纳入批量动作。
   */
  private selectAllBelow(): void {
    const data: FeedItem[] = this.dataSource.getDataArray();
    let last: number = -1;
    for (let i: number = data.length - 1; i >= 0; i--) {
      if (this.selectedIds.includes(data[i].id)) {
        last = i;
        break;
      }
    }
    if (last < 0 || last >= data.length - 1) {
      return;
    }
    const ids: number[] = this.selectedIds.slice();
    for (let i: number = last + 1; i < data.length; i++) {
      if (!ids.includes(data[i].id)) {
        ids.push(data[i].id);
      }
    }
    this.selectedIds = ids;
    this.selectAllLazy = true;
    this.refreshAllRows();
  }

  private refreshAllRows(): void {
    const data: FeedItem[] = this.dataSource.getDataArray();
    for (let i: number = 0; i < data.length; i++) {
      this.dataSource.notifyDataChange(i);
    }
  }

  private selectedItems(): FeedItem[] {
    return this.dataSource.getDataArray()
      .filter((item: FeedItem) => this.selectedIds.includes(item.id));
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

  /** 多选动作栏的可见项（上游 episodes_apply_action_speeddial + onPrepareMenu） */
  private batchActions(): InboxMenuItem[] {
    const actions: InboxMenuItem[] = [];
    if (this.anySelected((item: FeedItem) => item.isPlayed)) {
      actions.push({
        id: 'MARK_UNPLAYED',
        label: $r('app.string.episode_mark_unplayed'),
        icon: $r('sys.symbol.circle'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem) => !item.isPlayed)) {
      actions.push({
        id: 'MARK_PLAYED',
        label: $r('app.string.episode_mark_played'),
        icon: $r('sys.symbol.checkmark_circle'),
        destructive: false
      });
    }
    actions.push({
      id: 'REMOVE_INBOX',
      label: $r('app.string.remove_inbox_label'),
      icon: $r('sys.symbol.inbox'),
      destructive: true
    });
    if (this.anySelected((item: FeedItem) => !this.queueIds.includes(item.id))) {
      actions.push({
        id: 'ADD_QUEUE',
        label: $r('app.string.episode_add_queue'),
        icon: $r('sys.symbol.music_note_list'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem) => !this.favoriteIds.includes(item.id))) {
      actions.push({
        id: 'MARK_FAV',
        label: $r('app.string.add_to_favorites_label'),
        icon: $r('sys.symbol.star_fill'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem) => this.downloadState(item) === 'IDLE')) {
      actions.push({
        id: 'DOWNLOAD',
        label: $r('app.string.episode_download'),
        icon: $r('sys.symbol.arrow_down_circle'),
        destructive: false
      });
    }
    if (this.anySelected((item: FeedItem) => {
      const state: string = this.downloadState(item);
      return state === 'DONE' || state === 'RUNNING' || state === 'PAUSED';
    })) {
      actions.push({
        id: 'DELETE_FILE',
        label: $r('app.string.episode_delete_download'),
        icon: $r('sys.symbol.trash'),
        destructive: true
      });
    }
    if (this.selectedIds.length === 1) {
      actions.push({
        id: 'SHARE',
        label: $r('app.string.episode_share'),
        icon: $r('sys.symbol.share'),
        destructive: false
      });
    }
    return actions;
  }

  private runBatchAction(id: string): void {
    const selected: FeedItem[] = this.selectedItems();
    if (selected.length === 0) {
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.no_items_selected_message')));
      return;
    }
    if (id === 'MARK_PLAYED' || id === 'MARK_UNPLAYED') {
      const played: boolean = id === 'MARK_PLAYED';
      // 上游：选中 >= 25 条、或「全选」连带未加载页时，标已播 / 未播要先确认
      if (this.selectedIds.length >= InboxView.MARK_CONFIRM_THRESHOLD || this.selectAllLazy) {
        this.pendingMarkPlayed = played;
        this.showMarkConfirm = true;
        return;
      }
      this.batchMarkPlayed(selected, played);
      return;
    }
    if (id === 'REMOVE_INBOX') {
      this.batchRemoveFromInbox(selected);
      return;
    }
    if (id === 'ADD_QUEUE') {
      this.batchAddToQueue(selected);
      return;
    }
    if (id === 'MARK_FAV') {
      this.batchFavorite(selected, true);
      return;
    }
    if (id === 'DOWNLOAD') {
      this.batchDownload(selected);
      return;
    }
    if (id === 'DELETE_FILE') {
      this.batchDelete(selected);
      return;
    }
    if (id === 'SHARE' && selected.length > 0) {
      this.exitSelectMode();
      this.refreshAllRows();
      this.share(selected[0]);
    }
  }

  /** 确认弹层里的「确认」（上游 ConfirmationDialog.onConfirmButtonPressed） */
  private confirmMarkPlayed(): void {
    this.showMarkConfirm = false;
    this.batchMarkPlayed(this.selectedItems(), this.pendingMarkPlayed);
  }

  async batchMarkPlayed(selected: FeedItem[], played: boolean): Promise<void> {
    try {
      for (const item of selected) {
        await EpisodeRepository.markPlayed(item.id, played);
      }
      await this.forEachUnloadedItem(async (item: FeedItem): Promise<void> => {
        await EpisodeRepository.markPlayed(item.id, played);
      });
      // 标已播 / 标未播都会把条目降出「新」，这些行随之移出收件箱 → 整体重载
      this.exitSelectMode();
      this.publishBulkUpdate();
      this.showMessage(getContext(this).resourceManager.getStringSync(
        played ? $r('app.string.marked_played_message') : $r('app.string.marked_unplayed_message')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchRemoveFromInbox(selected: FeedItem[]): Promise<void> {
    try {
      for (const item of selected) {
        await EpisodeRepository.setNewFlag(item.id, false);
      }
      await this.forEachUnloadedItem(async (item: FeedItem): Promise<void> => {
        await EpisodeRepository.setNewFlag(item.id, false);
      });
      this.exitSelectMode();
      this.publishBulkUpdate();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.removed_from_inbox_msg')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchAddToQueue(selected: FeedItem[]): Promise<void> {
    try {
      for (const item of selected) {
        await QueueEngine.add(item);
        await EpisodeRepository.setNewFlag(item.id, false);
      }
      await this.forEachUnloadedItem(async (item: FeedItem): Promise<void> => {
        await QueueEngine.add(item);
        await EpisodeRepository.setNewFlag(item.id, false);
      });
      this.exitSelectMode();
      this.publishBulkUpdate();
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.queue_added')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async batchFavorite(selected: FeedItem[], favorite: boolean): Promise<void> {
    try {
      for (const item of selected) {
        await this.setFavoriteRecord(item, favorite);
      }
      await this.forEachUnloadedItem(async (item: FeedItem): Promise<void> => {
        await this.setFavoriteRecord(item, favorite);
      });
      // 收藏不改「新」标记，行留在列表里就地重绘（不整体重载，避免滚动位置回到顶部）
      await this.refreshRowState();
      this.exitSelectMode();
      this.refreshAllRows();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  private async setFavoriteRecord(item: FeedItem, favorite: boolean): Promise<void> {
    if (favorite) {
      await FavoritesRepository.add(item.id, item.feedId);
    } else {
      await FavoritesRepository.remove(item.id);
    }
  }

  async batchDownload(selected: FeedItem[]): Promise<void> {
    try {
      for (const item of selected) {
        await this.downloadIfNeeded(item);
      }
      await this.forEachUnloadedItem(async (item: FeedItem): Promise<void> => {
        await this.downloadIfNeeded(item);
      });
      this.exitSelectMode();
      this.refreshAllRows();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  private async downloadIfNeeded(item: FeedItem): Promise<void> {
    if (item.media !== undefined && item.media.downloadUrl !== '' && item.media.fileUrl === '') {
      await DownloadManager.startDownload(item.media, item.title);
    }
  }

  async batchDelete(selected: FeedItem[]): Promise<void> {
    try {
      for (const item of selected) {
        await this.deleteLocalFile(item);
      }
      await this.forEachUnloadedItem(async (item: FeedItem): Promise<void> => {
        await this.deleteLocalFile(item);
      });
      // 已加载的行 file_url 变了：逐条广播，靠 replaceRow 就地刷新
      this.publishItemUpdates(selected);
      this.exitSelectMode();
      this.refreshAllRows();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  private async deleteLocalFile(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    if (item.media.fileUrl !== '') {
      await DownloadManager.deleteFile(item.media);
    } else {
      await DownloadManager.remove(item.media.id);
    }
  }

  // ---------------------------------------------------------------- 提示与行内文本

  /** 顶部提示自动消失（上游 MessageEvent / Snackbar 语义），避免提示条永久占位 */
  private showMessage(text: string): void {
    this.message = text;
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
    }
    this.messageTimerId = setTimeout(() => {
      this.message = '';
      this.messageTimerId = -1;
    }, 4000);
  }

  private openSearch(): void {
    router.pushUrl({ url: 'pages/SearchPage', params: { term: '' } });
  }

  isVideo(item: FeedItem): boolean {
    const media: FeedMedia | undefined = item.media;
    return media !== undefined && media.getMediaType() === MediaType.VIDEO;
  }

  positionText(item: FeedItem): string {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      return '';
    }
    if (this.isCurrentlyPlaying(item.id) && this.playingMediaId === media.id) {
      return this.playingPosition > 0 ? DurationUtils.format(this.playingPosition) : '';
    }
    if (media.position <= 0) {
      return '';
    }
    return DurationUtils.format(media.position);
  }

  durationText(item: FeedItem): string {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      return '';
    }
    if (this.isCurrentlyPlaying(item.id) && this.playingMediaId === media.id
      && this.playingDuration > 0) {
      return DurationUtils.format(this.playingDuration);
    }
    if (media.duration <= 0) {
      return '';
    }
    return DurationUtils.format(media.duration);
  }

  progress(item: FeedItem): number {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      return 0;
    }
    let position: number = media.position;
    let duration: number = media.duration;
    if (this.isCurrentlyPlaying(item.id) && this.playingMediaId === media.id) {
      position = this.playingPosition;
      if (this.playingDuration > 0) {
        duration = this.playingDuration;
      }
    }
    if (duration <= 0 || position <= 0) {
      return 0;
    }
    const percent: number = Math.floor(position * 100 / duration);
    return percent > 100 ? 100 : (percent < 5 ? 5 : percent);
  }

  /** 状态行：发布日期 · 文件大小（上游 feeditemlist_item 的 pubDate · size，不含订阅名） */
  metaText(item: FeedItem): string {
    const parts: string[] = [];
    if (item.pubDate > 0) {
      parts.push(new Date(item.pubDate).toLocaleDateString());
    }
    const media: FeedMedia | undefined = item.media;
    if (media !== undefined && media.size > 0) {
      parts.push(this.sizeText(media.size));
    }
    return parts.join(' · ');
  }

  private sizeText(bytes: number): string {
    const mb: number = bytes / (1024 * 1024);
    return mb < 1 ? (bytes / 1024).toFixed(0) + ' KB' : mb.toFixed(1) + ' MB';
  }

  /**
   * ForEach / LazyForEach 只在 key 变化时重建行。下载进度与「正在播放」都存在
   * DownloadManager / PlayerManager 里、不是 @State，因此把这两项编进 key，变化时才会重建。
   */
  private rowKey(item: FeedItem): string {
    const parts: string[] = [item.id.toString()];
    if (item.media !== undefined) {
      const state: string = DownloadManager.getStatus(item.media.id);
      parts.push(state);
      if (state === 'RUNNING' || state === 'PAUSED') {
        parts.push(DownloadManager.getProgressPercent(item.media.id).toString());
      }
    }
    parts.push(this.isPlaying(item.id) ? 'playing' : 'idle');
    return parts.join('-');
  }
}
