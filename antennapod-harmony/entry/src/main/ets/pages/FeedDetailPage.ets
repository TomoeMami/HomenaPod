import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedFilter } from '../model/FeedFilter';
import { SortOrder } from '../model/Enums';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { RefreshService } from '../services/RefreshService';
import { AutoDownloadService } from '../services/AutoDownloadService';
import { DownloadManager } from '../download/DownloadManager';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { MediaType } from '../model/Enums';
import { UserPreferences } from '../prefs/UserPreferences';
import { EventHub, EventType, EpisodeDownloadData, FeedItemUpdateData } from '../events/EventHub';
import { LazyDataSource } from '../components/LazyDataSource';
import { FeedCover } from '../components/FeedCover';
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
import { TagChip } from '../components/TagChip';
import { EmptyState } from '../components/EmptyState';
import { EpisodeRow } from '../components/EpisodeRow';
import { SwipeActionButton } from '../components/SwipeActionButton';

interface FeedDetailParams {
  feedId: number;
}

@Entry
@Component
struct FeedDetailPage {
  /** 划出后继续拖动的距离阈值（vp）：进入该区域松手立即执行「标记为已播放/未播放」 */
  private static readonly SWIPE_ACTION_DISTANCE: number = 40;
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  @State feed: Feed | undefined = undefined;
  @State episodes: FeedItem[] = [];
  @State filter: string = 'all';
  @State loading: boolean = false;
  @State errorMessage: string = '';
  @State favoriteIds: number[] = [];
  @State queueIds: number[] = [];
  @State message: string = '';
  @State filterActive: boolean = false;
  // 弹层
  @State showSortSheet: boolean = false;
  @State showFilterSheet: boolean = false;
  @State showActionSheet: boolean = false;
  @State actionTitle: string = '';
  @State filterInclude: string = '';
  @State filterExclude: string = '';
  @State filterMinDuration: string = '';
  @State showStreamConfirm: boolean = false;
  /** 剧集列表左右滑动作 id（对照上游 SwipeActions.getSwipeActions；设置页保存后重新解析） */
  @State swipeRightId: string = SwipeActionId.NONE;
  @State swipeLeftId: string = SwipeActionId.NONE;
  // 多选（对照上游 EpisodeMultiSelectActionHandler + FloatingSelectMenu）
  @State selecting: boolean = false;
  @State selectedIds: number[] = [];
  private actionItem: FeedItem | undefined = undefined;
  private pendingItem: FeedItem | undefined = undefined;
  private streamConfirmed: boolean = false;
  private downloadToken: number = -1;
  /** 滑动动作偏好变化订阅 token */
  private swipeToken: number = -1;
  private messageTimerId: number = -1;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        AppBar({
          title: this.feed === undefined ? $r('app.string.loading') : this.feed!.getTitle(),
          showBack: true
        }) {
          this.appBarActions()
        }

        if (this.feed !== undefined) {
          this.header()
          Row({ space: DesignTokens.SPACE_S }) {
            TagChip({
              label: $r('app.string.filter_all'),
              selected: this.filter === 'all',
              onTap: () => {
                this.filter = 'all';
                this.loadEpisodes();
              }
            })
            TagChip({
              label: $r('app.string.filter_unplayed'),
              selected: this.filter === 'unplayed',
              onTap: () => {
                this.filter = 'unplayed';
                this.loadEpisodes();
              }
            })
            TagChip({
              label: $r('app.string.filter_downloaded'),
              selected: this.filter === 'downloaded',
              onTap: () => {
                this.filter = 'downloaded';
                this.loadEpisodes();
              }
            })
          }
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, top: DesignTokens.SPACE_S })
          .width('100%')

          if (this.message !== '') {
            Text(this.message)
              .fontSize(DesignTokens.FONT_FOOTNOTE)
              .fontColor($r('app.color.primary'))
              .padding({ left: DesignTokens.PAGE_MARGIN, top: DesignTokens.SPACE_S })
          }
          if (this.selecting) {
            this.selectionBar()
          }
          if (this.filterActive) {
            Row({ space: DesignTokens.SPACE_XS }) {
              SymbolGlyph($r('sys.symbol.funnel'))
                .fontSize(DesignTokens.ICON_XS)
                .fontColor([$r('app.color.text_tertiary')])
              Text($r('app.string.filter_active_hint'))
                .fontSize(DesignTokens.FONT_CAPTION)
                .fontColor($r('app.color.text_tertiary'))
            }
            .padding({ left: DesignTokens.PAGE_MARGIN, top: DesignTokens.SPACE_S })
          }
        }

        if (this.loading) {
          Text($r('app.string.loading'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
        } else if (this.errorMessage !== '') {
          Row({ space: DesignTokens.SPACE_S }) {
            SymbolGlyph($r('sys.symbol.warning'))
              .fontSize(DesignTokens.ICON_L)
              .fontColor([$r('app.color.error')])
            Text(this.errorMessage)
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .fontColor($r('app.color.error'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding(DesignTokens.PAGE_MARGIN)
          .layoutWeight(1)
        } else if (this.episodes.length === 0) {
          Column() {
            EmptyState({ icon: $r('sys.symbol.music'), title: $r('app.string.placeholder_episodes') })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: DesignTokens.SPACE_S }) {
            LazyForEach(this.dataSource, (item: FeedItem) => {
              ListItem() {
                this.episodeRow(item)
              }
              // 左右滑动作来自设置页配置（`start` = 右滑，`end` = 左滑）：默认只有左滑「标记为已播放/未播放」；
              // 拖到动作区松手即执行，近距划出时按钮仍可点。
              .swipeAction(this.swipeOptions(item))
            }, (item: FeedItem) => this.rowKey(item))
          }
          .layoutWeight(1)
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, top: DesignTokens.SPACE_M })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')

      if (this.showSortSheet) {
        this.sortSheet()
      }
      if (this.showFilterSheet) {
        this.filterSheet()
      }
      if (this.showActionSheet) {
        this.actionSheet()
      }
      if (this.showStreamConfirm) {
        this.streamConfirmSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 标题栏右侧（对齐上游 menu/feedlist：搜索常驻，其余进溢出菜单） */
  @Builder
  appBarActions() {
    Row({ space: DesignTokens.SPACE_XS }) {
      AppIconButton({
        symbol: $r('sys.symbol.magnifyingglass'),
        onTap: () => {
          router.pushUrl({ url: 'pages/SearchPage', params: { term: '', feedId: this.feed!.id } });
        }
      })
      OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
        this.feedMenu()
      }
    }
  }

  @Builder
  feedMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.sort')), content: $r('app.string.feed_sort') })
        .onClick(() => {
          this.showSortSheet = true;
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.arrow_clockwise')), content: $r('app.string.refresh_label') })
        .onClick(() => {
          this.refreshFeed();
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.funnel')), content: $r('app.string.feed_filter') })
        .onClick(() => {
          this.openFilterSheet();
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.share')), content: $r('app.string.episode_share') })
        .onClick(() => {
          if (this.episodes.length > 0) {
            this.share(this.episodes[0]);
          }
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.gearshape')), content: $r('app.string.feed_settings') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/FeedSettingsPage', params: { feedId: this.feed!.id } });
        })
    }
  }

  @Builder
  streamConfirmSheet() {
    Column({ space: DesignTokens.SPACE_L }) {
      Text($r('app.string.stream_confirm_message'))
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
            this.showStreamConfirm = false;
            this.pendingItem = undefined;
          })
        Button($r('app.string.stream_confirm_play'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            this.showStreamConfirm = false;
            this.streamConfirmed = true;
            const item: FeedItem | undefined = this.pendingItem;
            this.pendingItem = undefined;
            if (item !== undefined) {
              this.playNow(item);
            }
          })
      }
      .width('90%')
      .margin({ bottom: DesignTokens.SPACE_L })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  /** 订阅头图（对齐上游 feeditemlist_header.xml）：156vp 封面背景 + 124vp 封面 + 白色标题 +
   *  底部 #80000000 操作带（148vp 占位后跟 48vp 图标按钮）。 */
  @Builder
  header() {
    Stack() {
      if (this.feed!.imageUrl !== '') {
        Image(this.feed!.imageUrl)
          .width('100%')
          .height(156)
          .objectFit(ImageFit.Cover)
          .blur(12)
      } else {
        Column()
          .width('100%')
          .height(156)
          .backgroundColor($r('app.color.primary_container'))
      }

      // 可读性蒙层（上游 @color/image_readability_tint）
      Column()
        .width('100%')
        .height(156)
        .backgroundColor('#80000000')

      // 封面 + 标题 + 作者
      Row({ space: DesignTokens.SPACE_L }) {
        FeedCover({
          imageUrl: this.feed!.imageUrl,
          coverSize: DesignTokens.COVER_DETAIL,
          radius: DesignTokens.RADIUS_CARD,
          placeholderColor: $r('app.color.cover_placeholder')
        })

        Column({ space: DesignTokens.SPACE_XS }) {
          Text(this.feed!.getTitle())
            .fontSize(DesignTokens.FONT_TITLE2)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.feed!.author === '' ? this.feed!.link : this.feed!.author)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor(Color.White)
            .opacity(0.85)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
      .position({ x: 0, y: 8 })

      // 底部操作带
      Row() {
        Row().width(148)
        Blank()
        this.headerIcon($r('sys.symbol.sort'), () => {
          this.showSortSheet = true;
        })
        this.headerIcon($r('sys.symbol.funnel'), () => {
          this.openFilterSheet();
        })
        this.headerIcon($r('sys.symbol.gearshape'), () => {
          router.pushUrl({ url: 'pages/FeedSettingsPage', params: { feedId: this.feed!.id } });
        })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#80000000')
      .position({ x: 0, y: 100 })
    }
    .width('100%')
    .height(156)
  }

  @Builder
  headerIcon(icon: Resource, onTap: () => void) {
    Stack() {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([Color.White])
    }
    .width(48)
    .height(48)
    .alignContent(Alignment.Center)
    .onClick(() => {
      onTap();
    })
  }

  /** 多选操作条（对照上游 multi_select_options.xml + FloatingSelectMenu） */
  @Builder
  selectionBar() {
    Column({ space: DesignTokens.SPACE_S }) {
      Row({ space: DesignTokens.SPACE_S }) {
        Text(getContext(this).resourceManager.getStringSync($r('app.string.queue_selected')) + ' ' + this.selectedIds.length)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button($r('app.string.select_all_label'))
          .fontSize(DesignTokens.FONT_CAPTION)
          .height(32)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.selectedIds = this.episodes.map((item: FeedItem) => item.id);
          })
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
    .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M, top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_S })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_ROW)
    .margin({
      left: DesignTokens.PAGE_MARGIN,
      right: DesignTokens.PAGE_MARGIN,
      top: DesignTokens.SPACE_S
    })
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
    return this.episodes.filter((item: FeedItem) => this.selectedIds.includes(item.id));
  }

  async batchMarkPlayed(played: boolean): Promise<void> {
    try {
      for (const item of this.selectedItems()) {
        await EpisodeRepository.markPlayed(item.id, played);
        const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
        EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      }
      this.exitSelection();
      await this.loadEpisodes();
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
      await this.loadEpisodes();
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
      await this.loadEpisodes();
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
      await this.loadEpisodes();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 剧集行（对齐上游 feeditemlist_item.xml：封面 + 状态行 + 标题 + 进度行 + 48vp 次级操作） */
  @Builder
  episodeRow(item: FeedItem) {
    EpisodeRow({
      title: item.title,
      imageUrl: item.imageUrl !== '' ? item.imageUrl : (this.feed === undefined ? '' : this.feed.imageUrl),
      metaText: this.metaText(item),
      positionText: this.positionText(item),
      durationText: this.durationText(item),
      progress: this.progressPercent(item),
      isPlayed: item.isPlayed,
      isNew: item.isNew(),
      isFavorite: this.favoriteIds.includes(item.id),
      inQueue: this.queueIds.includes(item.id),
      isVideo: item.media !== undefined && item.media.getMediaType() === MediaType.VIDEO,
      selected: this.selectedIds.includes(item.id),
      actionIcon: this.downloadState(item) === 'DONE'
        ? $r('sys.symbol.play_fill') : $r('sys.symbol.arrow_down_circle'),
      actionTint: this.downloadState(item) === 'DONE'
        ? $r('app.color.primary') : $r('app.color.text_secondary'),
      downloadProgress: this.downloadProgress(item),
      downloadIndeterminate: this.downloadIndeterminate(item),
      onTap: () => {
        if (this.selecting) {
          this.toggleSelected(item.id);
        } else {
          this.play(item);
        }
      },
      onAction: () => {
        if (this.selecting) {
          this.toggleSelected(item.id);
          return;
        }
        if (this.downloadState(item) === 'DONE') {
          this.play(item);
        } else if (this.downloadState(item) === 'RUNNING') {
          DownloadManager.pause(item.media!.id);
        } else if (this.downloadState(item) === 'PAUSED') {
          DownloadManager.resume(item.media!.id);
        } else {
          this.startDownload(item);
        }
      },
      onLongPress: () => {
        if (this.selecting) {
          // 多选态下长按 = 单集操作菜单（多选入口已在非多选态的长按里）
          this.openActionSheet(item);
        } else {
          this.selecting = true;
          this.selectedIds = [item.id];
        }
      }
    })
  }

  /**
   * 划出项配置：左右两个动作都取自偏好（`SwipeActions.resolve`），
   * 该屏幕关闭滑动动作、或某一侧配置为「无」时，对应侧不挂划出项。
   */
  private swipeOptions(item: FeedItem): SwipeActionOptions {
    const options: SwipeActionOptions = {};
    if (!SwipeActions.isEnabled(SwipeScreen.FEED_DETAIL)) {
      return options;
    }
    if (this.swipeRightId !== SwipeActionId.NONE) {
      const rightSpec: SwipeActionSpec = swipeActionSpec(this.swipeRightId);
      const rightItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(rightSpec, item);
        },
        actionAreaDistance: FeedDetailPage.SWIPE_ACTION_DISTANCE,
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
        actionAreaDistance: FeedDetailPage.SWIPE_ACTION_DISTANCE,
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

  /** 划出项动作分发：只调用本页已有方法，不在这里重复实现动作逻辑 */
  private runSwipeAction(id: string, item: FeedItem): void {
    if (id === SwipeActionId.MARK_PLAYED) {
      this.togglePlayed(item);
      return;
    }
    if (id === SwipeActionId.ADD_TO_QUEUE) {
      this.addToQueue(item);
      return;
    }
    if (id === SwipeActionId.START_DOWNLOAD) {
      this.startDownload(item);
      return;
    }
    if (id === SwipeActionId.DELETE) {
      this.deleteDownload(item);
      return;
    }
    if (id === SwipeActionId.MARK_FAV) {
      this.setFavorite(item, true);
      return;
    }
    if (id === SwipeActionId.REMOVE_FROM_FAVORITES) {
      this.setFavorite(item, false);
      return;
    }
    if (id === SwipeActionId.REMOVE_FROM_INBOX) {
      this.removeFromInbox(item);
      return;
    }
    if (id === SwipeActionId.SHARE) {
      this.share(item);
    }
  }

  /** 解析本屏的 [右滑, 左滑] 动作 id（aboutToAppear 与 SWIPE_ACTIONS_CHANGED 时调用） */
  private loadSwipeActions(): void {
    const ids: string[] = SwipeActions.resolve(SwipeScreen.FEED_DETAIL);
    this.swipeRightId = ids[0];
    this.swipeLeftId = ids[1];
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
        .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
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
      Text(label)
        .fontSize(DesignTokens.FONT_SUBTITLE)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.feed !== undefined && this.feed!.sortOrder === order) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(DesignTokens.ICON_M)
          .fontColor([$r('app.color.primary')])
      }
    }
    .width('100%')
    .padding({ left: DesignTokens.SPACE_S, top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
    .onClick(() => {
      this.applySort(order);
    })
  }

  @Builder
  filterSheet() {
    Column({ space: DesignTokens.SPACE_S }) {
      Text($r('app.string.feed_filter'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .padding({ top: DesignTokens.SPACE_L })
      Text($r('app.string.filter_include_label'))
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
      TextInput({ text: this.filterInclude })
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .backgroundColor($r('app.color.surface_secondary'))
        .onChange((value: string) => {
          this.filterInclude = value;
        })
      Text($r('app.string.filter_exclude_label'))
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
      TextInput({ text: this.filterExclude })
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .backgroundColor($r('app.color.surface_secondary'))
        .onChange((value: string) => {
          this.filterExclude = value;
        })
      Text($r('app.string.filter_min_duration_label'))
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
      TextInput({ text: this.filterMinDuration })
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .type(InputType.Number)
        .backgroundColor($r('app.color.surface_secondary'))
        .onChange((value: string) => {
          this.filterMinDuration = value;
        })
      Text($r('app.string.filter_terms_hint'))
        .fontSize(DesignTokens.FONT_CAPTION)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showFilterSheet = false;
          })
        Button($r('app.string.dialog_save'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            this.saveFilter();
          })
      }
      .width('100%')
      .margin({ top: DesignTokens.SPACE_XS, bottom: DesignTokens.SPACE_L })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
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
          this.showActionSheet = false;
          if (this.actionItem !== undefined) {
            this.togglePlayed(this.actionItem!);
          }
        })
      this.actionRow($r('sys.symbol.music_note_list'), $r('app.string.episode_add_queue'), () => {
        this.showActionSheet = false;
        if (this.actionItem !== undefined) {
          this.addToQueue(this.actionItem!);
        }
      })
      this.actionRow($r('sys.symbol.share'), $r('app.string.episode_share'), () => {
        this.showActionSheet = false;
        if (this.actionItem !== undefined) {
          this.share(this.actionItem!);
        }
      })
      if (this.actionItem !== undefined && this.actionItem!.media !== undefined) {
        if (this.downloadState(this.actionItem!) === 'DONE') {
          this.actionRow($r('sys.symbol.trash'), $r('app.string.episode_delete_download'), () => {
            this.showActionSheet = false;
            if (this.actionItem !== undefined) {
              this.deleteDownload(this.actionItem!);
            }
          })
        } else {
          this.actionRow($r('sys.symbol.arrow_down_circle'), $r('app.string.episode_download'), () => {
            this.showActionSheet = false;
            if (this.actionItem !== undefined) {
              this.startDownload(this.actionItem!);
            }
          })
        }
      }
      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
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
      onTap();
    })
  }

  aboutToAppear(): void {
    this.loadSwipeActions();
    const params = router.getParams() as FeedDetailParams;
    if (params !== undefined && params.feedId !== undefined) {
      this.load(params.feedId);
    }
    // 下载进度实时刷新（token 精确退订，不影响 Index/DownloadsPage 的监听）
    this.downloadToken = EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.onDownloadEvent(data as Record<string, Object>);
    });
    // 设置页保存「滑动动作」后重新解析左右滑动作
    this.swipeToken = EventHub.subscribe(EventType.SWIPE_ACTIONS_CHANGED, (data: object) => {
      this.loadSwipeActions();
    });
  }

  aboutToDisappear(): void {
    if (this.downloadToken >= 0) {
      EventHub.unsubscribeToken(this.downloadToken);
      this.downloadToken = -1;
    }
    if (this.swipeToken >= 0) {
      EventHub.unsubscribeToken(this.swipeToken);
      this.swipeToken = -1;
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

  onDownloadEvent(record: Record<string, Object>): void {
    const state: string = record['state'] as string;
    if (state === 'DONE') {
      // 下载完成后 file_url 变了，需要重新查库才能反映"已下载"
      this.loadEpisodes();
      return;
    }
    // RUNNING / PAUSED / PROGRESS / FAILED / REMOVED 只影响行内进度指示，读 DownloadManager 即可
    this.reloadRows();
  }

  reloadRows(): void {
    this.dataSource.setData(this.episodes);
  }

  async load(feedId: number): Promise<void> {
    try {
      this.feed = await FeedRepository.getById(feedId);
      if (this.feed !== undefined) {
        this.filterInclude = this.feed.includeFilter;
        this.filterExclude = this.feed.excludeFilter;
        this.filterMinDuration = this.feed.minimalDurationFilter > 0
          ? this.feed.minimalDurationFilter.toString() : '';
      }
    } catch (error) {
      this.feed = undefined;
      this.errorMessage = (error as Error).message;
    }
    await this.loadEpisodes();
  }

  async loadEpisodes(): Promise<void> {
    if (this.feed === undefined) {
      return;
    }
    // 只有首屏（列表还是空的时候）才整页显示「加载中」：`loading` 是 build 的结构分支，
    // 每次重载都置 true 会把整个列表拆掉重建（上千集时要建上千个行组件，主线程卡死）
    this.loading = this.episodes.length === 0;
    this.errorMessage = '';
    try {
      const unplayed: boolean = this.filter === 'unplayed';
      let items: FeedItem[] = await EpisodeRepository.listByFeed(this.feed.id, unplayed, this.feed.sortOrder);
      if (this.filter === 'downloaded') {
        items = items.filter((item: FeedItem) => item.media !== undefined && item.media.fileUrl !== '');
      }
      // 每 Feed 过滤器：命中规则的剧集不进入列表（与自动下载判定同一套规则）
      const filter: FeedFilter = new FeedFilter(
        this.feed.includeFilter, this.feed.excludeFilter, this.feed.minimalDurationFilter);
      this.filterActive = filter.hasIncludeFilter() || filter.hasExcludeFilter() || filter.hasMinimalDurationFilter();
      if (this.filterActive) {
        items = items.filter((item: FeedItem) => filter.shouldAutoDownload(item));
      }
      this.episodes = items;
      this.dataSource.setData(items);
      await this.loadFavoriteIds();
    } catch (error) {
      this.episodes = [];
      this.dataSource.setData([]);
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  /** 同步收藏状态到 @State，驱动 ★ 按钮显示 */
  async loadFavoriteIds(): Promise<void> {
    // 一条 SQL 取回全部收藏 id，不再逐条 isFavorite（上千集的播客 = 上千次串行查询）
    try {
      this.favoriteIds = await FavoritesRepository.listIds();
    } catch (error) {
      // 收藏查询失败不阻断列表
      this.favoriteIds = [];
    }
    try {
      await QueueEngine.load();
      this.queueIds = QueueEngine.getItems().map((entry: FeedItem) => entry.id);
    } catch (error) {
      this.queueIds = [];
    }
  }

  async refreshFeed(): Promise<void> {
    if (this.feed === undefined) {
      return;
    }
    this.message = '';
    try {
      const added: number = await RefreshService.refreshFeed(this.feed!.id);
      this.feed = await FeedRepository.getById(this.feed!.id);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.feed_refresh_done')) + added);
      await this.loadEpisodes();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async applySort(order: SortOrder): Promise<void> {
    this.showSortSheet = false;
    if (this.feed === undefined) {
      return;
    }
    this.feed.sortOrder = order;
    try {
      await FeedRepository.updatePreferences(this.feed!);
      await this.loadEpisodes();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  openFilterSheet(): void {
    if (this.feed !== undefined) {
      this.filterInclude = this.feed.includeFilter;
      this.filterExclude = this.feed.excludeFilter;
      this.filterMinDuration = this.feed.minimalDurationFilter > 0
        ? this.feed.minimalDurationFilter.toString() : '';
    }
    this.showFilterSheet = true;
  }

  async saveFilter(): Promise<void> {
    this.showFilterSheet = false;
    if (this.feed === undefined) {
      return;
    }
    const minDuration: number = this.filterMinDuration.trim() === ''
      ? -1 : Number(this.filterMinDuration.trim());
    this.feed.includeFilter = this.filterInclude.trim();
    this.feed.excludeFilter = this.filterExclude.trim();
    this.feed.minimalDurationFilter = Number.isFinite(minDuration) ? minDuration : -1;
    try {
      await FeedRepository.updatePreferences(this.feed!);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.dialog_saved')));
      await this.loadEpisodes();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  openActionSheet(item: FeedItem): void {
    this.actionItem = item;
    this.actionTitle = item.title;
    this.showActionSheet = true;
  }

  async togglePlayed(item: FeedItem): Promise<void> {
    const target: boolean = !item.isPlayed;
    try {
      await EpisodeRepository.markPlayed(item.id, target);
      item.isPlayed = target;
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.loadEpisodes();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async addToQueue(item: FeedItem): Promise<void> {
    try {
      await QueueEngine.add(item);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.queue_added')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /**
   * 移出收件箱（对照上游 RemoveFromInboxSwipeAction）：清除「新」标记并刷新列表。
   * 与列表里的其它改动一样发 FEED_ITEM_UPDATE，让首页 / 收件箱同步。
   */
  private async removeFromInbox(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.setNewFlag(item.id, false);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.loadEpisodes();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async startDownload(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    try {
      await DownloadManager.startDownload(item.media, item.title);
      this.reloadRows();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async deleteDownload(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    try {
      await DownloadManager.deleteFile(item.media);
      await this.loadEpisodes();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  async play(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    // 移动流量播放二次确认（仅流播、且开关开启、且当前为计费网络）
    if (item.media.fileUrl === '' && !this.streamConfirmed
      && UserPreferences.getStreamConfirmMobile() && AutoDownloadService.isMetered()) {
      this.pendingItem = item;
      this.showStreamConfirm = true;
      return;
    }
    await this.playNow(item);
  }

  async playNow(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    const feed: Feed | undefined = this.feed;
    const playable: Playable = new Playable(
      item.media.id,
      item.id,
      item.title,
      feed !== undefined ? feed.getTitle() : '',
      item.media.downloadUrl,
      item.media.fileUrl,
      item.media.duration,
      item.media.position,
      item.media.getMediaType(),
      feed !== undefined && feed.feedPlaybackSpeed > 0 ? feed.feedPlaybackSpeed : 1.0,
      feed !== undefined ? feed.feedSkipIntro : 0,
      feed !== undefined ? feed.feedSkipEnding : 0,
      feed !== undefined ? feed.feedVolumeAdaption : 0,
      item.imageUrl !== '' ? item.imageUrl : (feed !== undefined ? feed.imageUrl : '')
    );
    await QueueEngine.ensureQueued(item);
    await PlayerManager.load(playable, item.media.position, true);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  async toggleFavorite(item: FeedItem): Promise<void> {
    const fav: boolean = await FavoritesRepository.isFavorite(item.id);
    if (fav) {
      await FavoritesRepository.remove(item.id);
      this.favoriteIds = this.favoriteIds.filter((id: number) => id !== item.id);
    } else {
      await FavoritesRepository.add(item.id, item.feedId);
      this.favoriteIds = this.favoriteIds.concat([item.id]);
    }
  }

  /**
   * 收藏动作（划出项「加入收藏 / 移出收藏」）：本页只有「切换」实现，
   * 因此先比对目标状态，已经是目标状态就不做无谓的切换。
   */
  private async setFavorite(item: FeedItem, favorite: boolean): Promise<void> {
    if (this.favoriteIds.includes(item.id) === favorite) {
      return;
    }
    await this.toggleFavorite(item);
  }

  /** 分享：复制单集链接到剪贴板（本 SDK 无系统分享面板 API） */
  async share(item: FeedItem): Promise<void> {
    let link: string = item.link;
    if (link === '' && item.media !== undefined) {
      link = item.media.downloadUrl;
    }
    if (link === '' && this.feed !== undefined) {
      link = this.feed.link;
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

  /** 下载按钮状态：优先看数据库 file_url，再看会话内任务状态 */
  downloadState(item: FeedItem): string {
    if (item.media === undefined) {
      return 'IDLE';
    }
    if (item.media.fileUrl !== '') {
      return 'DONE';
    }
    return DownloadManager.getStatus(item.media.id);
  }

  /** 行内下载进度环的百分比；-1 = 不显示（对照上游 secondaryActionProgress 的百分比） */
  downloadProgress(item: FeedItem): number {
    if (item.media === undefined) {
      return -1;
    }
    return DownloadManager.getProgressPercent(item.media.id);
  }

  /** 总大小未知（进度不可确定）时环走等待动画 */
  downloadIndeterminate(item: FeedItem): boolean {
    return item.media !== undefined && DownloadManager.isProgressIndeterminate(item.media.id);
  }

  /**
   * LazyForEach 只在 key 变化时重建行。下载进度存在 DownloadManager 里、不是 @State，
   * 因此必须把状态/百分比编进 key，否则"下载中 xx%"不会实时刷新。
   */
  rowKey(item: FeedItem): string {
    if (item.media === undefined) {
      return item.id.toString();
    }
    const state: string = this.downloadState(item);
    if (state !== 'RUNNING' && state !== 'PAUSED') {
      return item.id.toString() + '-' + state;
    }
    return item.id.toString() + '-' + state + '-' + DownloadManager.getProgressPercent(item.media.id).toString();
  }

  /** 播放进度百分比（上游把小于 5% 抬到 5%，否则圆角下看不见） */
  progressPercent(item: FeedItem): number {
    if (item.media === undefined || item.media.duration <= 0 || item.media.position <= 0) {
      return 0;
    }
    const percent: number = Math.floor(item.media.position * 100 / item.media.duration);
    return percent > 100 ? 100 : (percent < 5 ? 5 : percent);
  }

  positionText(item: FeedItem): string {
    if (item.media === undefined || item.media.position <= 0) {
      return '';
    }
    return DurationUtils.format(item.media.position);
  }

  durationText(item: FeedItem): string {
    if (item.media === undefined || item.media.duration <= 0) {
      return '';
    }
    return DurationUtils.format(item.media.duration);
  }

  /** 状态行：发布日期 · 文件大小（上游 feeditemlist_item 的 pubDate · size） */
  metaText(item: FeedItem): string {
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
}
