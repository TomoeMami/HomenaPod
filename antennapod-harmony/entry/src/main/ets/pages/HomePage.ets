import router from '@ohos.router';
import { EpisodeRepository, FeedStat } from '../db/repositories/EpisodeRepository';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { Playable } from '../model/Playable';
import { MediaType, SortOrder } from '../model/Enums';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { DownloadManager } from '../download/DownloadManager';
import { RefreshService } from '../services/RefreshService';
import { Feed } from '../model/Feed';
import { UserPreferences } from '../prefs/UserPreferences';
import { EventHub, EventType, FeedItemUpdateData } from '../events/EventHub';
import { DurationUtils } from '../utils/DurationUtils';
import { DesignTokens } from '../common/DesignTokens';
import {
  SwipeActionId,
  SwipeActionSpec,
  SwipeActions,
  SwipeScreen,
  isDestructiveSwipeAction,
  swipeActionSpec
} from '../common/SwipeActions';
import { EpisodeCard } from '../components/EpisodeCard';
import { EpisodeRow } from '../components/EpisodeRow';
import { FeedCover } from '../components/FeedCover';
import { SectionHeader } from '../components/SectionHeader';
import { AppIconButton } from '../components/AppIconButton';
import { SwipeActionButton } from '../components/SwipeActionButton';

/** 编辑模式里的区块行（顺序 + 显隐，对照上游 HomeSectionsSettingsDialog 的两个分组） */
interface HomeSectionRow {
  tag: string;
  title: ResourceStr;
  icon: Resource;
  hidden: boolean;
}

/** 随机惊喜的种子（上游 `EpisodesSurpriseSection.seed`）：页面内稳定，只在点「乱序」时更换 */
function newSurpriseSeed(): number {
  return Math.floor(Math.random() * 2147483646) + 1;
}

/**
 * 首页五区块（对齐上游 HomeFragment / home_section.xml / 五个 Section）：
 * 继续收听（队列横滑卡片）/ 看新内容（竖排两行 + 未读角标）/ 随机惊喜（横滑卡片 + 乱序）/
 * 常听经典（横滑订阅封面）/ 管理下载（竖排两行）。
 *
 * 数据源与上游逐条对齐：
 * - 继续收听 = 队列 `DBReader.getPausedQueue(8)`（不是播放历史）；
 * - 随机惊喜 = `getRandomEpisodes(8, seed)`（2 年内、每订阅 1 集、seed 稳定）；
 * - 常听经典 = 最近 3 年的 feedTime、仅已订阅源；
 * - 管理下载 = 用户设置的下载排序；
 * - 欢迎页条件 = 全库单集总数为 0（不是订阅数为 0）。
 */
@Component
export struct HomePage {
  @State continueItems: FeedItem[] = [];
  @State newItems: FeedItem[] = [];
  @State newCount: number = 0;
  @State surpriseItems: FeedItem[] = [];
  @State topFeeds: FeedStat[] = [];
  @State downloadItems: FeedItem[] = [];
  @State queueIds: number[] = [];
  @State favoriteIds: number[] = [];
  @State feedImages: Map<number, string> = new Map<number, string>();
  /** 全库是否已有单集（上游 updateWelcomeScreenVisibility 的条件） */
  @State hasEpisodes: boolean = false;
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State editMode: boolean = false;
  /** 区块顺序 / 隐藏区块（对照上游 PrefHomeSectionOrder 与 PrefHomeSectionsString） */
  @State sectionOrder: string[] = [];
  @State hiddenSections: string[] = [];
  @State message: string = '';
  /** 当前播放项的实时进度（PlaybackPositionEvent 只更新它，不重查数据库） */
  @State playbackPercent: number = 0;
  /** 当前播放项的实时播放位置（上游 notifyPlaybackPositionUpdated 会同时刷新进度条与位置文本） */
  @State playbackPositionMs: number = 0;
  /** 长按操作菜单的目标单集 */
  @State menuItem: FeedItem | undefined = undefined;
  @State menuShown: boolean = false;
  /** 「看新内容」区块的左右滑动作 id（对照上游 InboxFragment 的滑动动作配置） */
  @State newRightId: string = SwipeActionId.NONE;
  @State newLeftId: string = SwipeActionId.NONE;
  /** 「管理下载」区块的左右滑动作 id（对照上游 CompletedDownloadsFragment 的滑动动作配置） */
  @State dlRightId: string = SwipeActionId.NONE;
  @State dlLeftId: string = SwipeActionId.NONE;
  /**
   * 长按打开菜单的时刻。`EpisodeRow` / `EpisodeCard` 用的是
   * `.onClick()` + `.parallelGesture(LongPressGesture())`（项目的既有写法，换成普通
   * `.gesture()` 会把单击吞掉），两者是并行识别：长按抬手时 onClick 仍会命中。
   * 首页 onClick = 播放（会 push 播放页），所以必须在这个窗口期内把随后的 click 吞掉，
   * 否则「长按弹菜单」会同时跳进播放页。
   */
  private menuOpenedAt: number = 0;
  /** refreshAll 防重入标记（见该方法注释） */
  private refreshingNow: boolean = false;
  /** 「看新内容」区块行数（上游 InboxSection.NUM_EPISODES = 2） */
  private static readonly NEW_EPISODES: number = 2;
  /** 继续收听 / 随机惊喜条数（上游 QueueSection、EpisodesSurpriseSection 的 NUM_EPISODES = 8） */
  private static readonly NUM_EPISODES: number = 8;
  /** 常听经典最多几个订阅（上游 SubscriptionsSection.NUM_FEEDS = 8） */
  private static readonly NUM_FEEDS: number = 8;
  /** 管理下载两行（上游 DownloadsSection.NUM_EPISODES = 2） */
  private static readonly NUM_DOWNLOADS: number = 2;
  /** 默认区块顺序（上游 R.array.home_section_tags） */
  private static readonly DEFAULT_SECTIONS: string[] = ['continue', 'new', 'random', 'top', 'downloads'];
  /** 滑动动作触发距离（与收件箱页保持一致） */
  private static readonly SWIPE_ACTION_DISTANCE: number = 40;
  private surpriseSeed: number = newSurpriseSeed();
  private eventTokens: number[] = [];
  onNavigate: (target: string) => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 标题栏（上游 MaterialToolbar + menu/home.xml：搜索常驻，刷新与「配置首页」进溢出菜单）
        Row({ space: DesignTokens.SPACE_XS }) {
          Text($r('app.string.home_title'))
            .fontSize(DesignTokens.FONT_TITLE1)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          AppIconButton({
            symbol: $r('sys.symbol.magnifyingglass'),
            onTap: () => {
              this.onNavigate('search');
            }
          })
          AppIconButton({
            symbol: $r('sys.symbol.arrow_clockwise'),
            onTap: () => {
              this.refreshAll();
            }
          })
          AppIconButton({
            symbol: this.editMode ? $r('sys.symbol.checkmark') : $r('sys.symbol.square_and_pencil'),
            tint: this.editMode ? $r('app.color.primary') : $r('app.color.text_secondary'),
            onTap: () => {
              this.editMode = !this.editMode;
            }
          })
        }
        .width('100%')
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.SPACE_S })
        .height(DesignTokens.HEIGHT_APP_BAR)

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
        }

        if (this.editMode) {
          this.editSections()
        } else if (!this.hasEpisodes && !this.loading) {
          // 欢迎页（上游 welcomeContainer）：图标 64vp + 标题 20fp + 说明 14fp，左右 32vp
          this.welcome()
        } else {
          Refresh({ refreshing: this.refreshing }) {
            // 内容区是一个纵向 List（上游 homeContainer 里每个 Section 都是独立 RecyclerView）：
            // 竖排的单集行必须是 ListItem，`swipeAction`（ListItem 的属性）才能挂上去。
            List({ space: 0 }) {
              ForEach(this.visibleSections(), (tag: string) => {
                if (tag === 'continue') {
                  ListItem() {
                    this.continueHeader()
                  }
                  ListItem() {
                    if (this.continueItems.length === 0) {
                      this.emptyLabel($r('app.string.home_continue_empty'))
                    } else {
                      this.horizontalCards()
                    }
                  }
                } else if (tag === 'new') {
                  ListItem() {
                    this.newSectionHeader()
                  }
                  if (this.newItems.length === 0) {
                    ListItem() {
                      this.emptyLabel($r('app.string.home_new_empty'))
                    }
                  } else {
                    ForEach(this.newItems, (item: FeedItem) => {
                      ListItem() {
                        this.episodeRow(item)
                      }
                      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
                      // 「看新内容」区块的左右滑动作取自「收件箱」屏幕的配置
                      .swipeAction(this.newSwipeOptions(item))
                    }, (item: FeedItem) => 'n-' + item.id.toString())
                  }
                } else if (tag === 'random') {
                  ListItem() {
                    this.randomHeader()
                  }
                  ListItem() {
                    if (this.surpriseItems.length === 0) {
                      this.emptyLabel($r('app.string.home_surprise_empty'))
                    } else {
                      this.horizontalEpisodes()
                    }
                  }
                } else if (tag === 'top') {
                  ListItem() {
                    this.topHeader()
                  }
                  if (this.topFeeds.length > 0) {
                    ListItem() {
                      this.horizontalFeeds()
                    }
                  }
                } else if (tag === 'downloads') {
                  ListItem() {
                    this.downloadsHeader()
                  }
                  if (this.downloadItems.length === 0) {
                    ListItem() {
                      this.emptyLabel($r('app.string.home_downloads_empty'))
                    }
                  } else {
                    ForEach(this.downloadItems, (item: FeedItem) => {
                      ListItem() {
                        this.episodeRow(item)
                      }
                      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
                      // 「管理下载」区块的左右滑动作取自「已完成下载」屏幕的配置
                      .swipeAction(this.downloadSwipeOptions(item))
                    }, (item: FeedItem) => 'd-' + item.id.toString())
                  }
                }
              }, (tag: string) => tag)
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ bottom: DesignTokens.SPACE_XXL })
            .scrollBar(BarState.Off)
          }
          .layoutWeight(1)
          .onRefreshing(() => {
            this.refreshAll();
          })
        }
      }
      .width('100%')
      .height('100%')

      // 长按操作菜单（对照上游 HomeSection 的 registerForContextMenu + FeedItemMenuHandler）
      if (this.menuShown) {
        this.sheetBackdrop()
      }
      if (this.menuShown) {
        this.actionSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  // ---------------------------------------------------------------- 欢迎页

  @Builder
  welcome() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: DesignTokens.SPACE_L }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.mic'))
            .fontSize(40)
            .fontColor([$r('app.color.primary')])
        }
        .width(64)
        .height(64)
        .borderRadius(DesignTokens.RADIUS_CARD)
        .backgroundColor($r('app.color.primary_container'))
        .alignContent(Alignment.Center)
        .margin({ top: 48 })

        Text($r('app.string.home_welcome_title'))
          .fontSize(DesignTokens.FONT_TITLE3)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)

        Text($r('app.string.home_welcome_text'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 32, right: 32 })
      .alignItems(HorizontalAlign.Center)

      // 引导箭头（上游 80dp ic_curved_arrow，底部导航时在右下角、margin 16dp，指向底部「更多」入口）
      SymbolGlyph($r('sys.symbol.arrow_uturn_down'))
        .fontSize(80)
        .fontColor([$r('app.color.text_tertiary')])
        .margin({ right: DesignTokens.SPACE_L, bottom: DesignTokens.SPACE_L })
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ---------------------------------------------------------------- 五个区块（表头 + 内容分别成 ListItem）

  @Builder
  continueHeader() {
    this.sectionHeader($r('app.string.home_continue'), $r('app.string.tab_queue'), -1, false,
      () => {
        this.onNavigate('queue');
      }, () => {
      })
  }

  @Builder
  randomHeader() {
    this.sectionHeader($r('app.string.home_random'), $r('app.string.episodes_label'), -1, true, () => {
      this.onNavigate('episodes');
    }, () => {
      this.shuffleSurprise();
    })
  }

  @Builder
  topHeader() {
    // 上游 SubscriptionsSection 不设置 emptyLabel：没有收听数据时该区块只留标题
    this.sectionHeader($r('app.string.home_top'), $r('app.string.tab_subscriptions'), -1, false,
      () => {
        this.onNavigate('subscriptions');
      }, () => {
      })
  }

  @Builder
  downloadsHeader() {
    this.sectionHeader($r('app.string.home_downloads'), $r('app.string.tab_downloads'), -1, false,
      () => {
        this.onNavigate('downloads');
      }, () => {
      })
  }

  @Builder
  sectionHeader(title: ResourceStr, moreLabel: ResourceStr, countPill: number, shuffle: boolean,
                onMore: () => void, onShuffle: () => void) {
    Row() {
      SectionHeader({
        title: title,
        actionText: moreLabel,
        countPill: countPill,
        shuffle: shuffle,
        onAction: onMore,
        onShuffle: onShuffle
      })
    }
    .width('100%')
    // 左 16vp（标题 marginStart）+ 右 8vp（「更多」按钮的 marginEnd），与上游 home_section.xml 一致
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.SPACE_S })
  }

  /**
   * 「看新内容」区块标题（上游 InboxSection 的 `numNewItemsLabel`：未读数胶囊，空则不显示）。
   *
   * 计数必须在这里直接读 `this.newCount`：`@Builder` 的多参数是**按值传递**，参数变化不会刷新
   * —— 经 `sectionHeader(..., this.newCount, ...)` 传入时，胶囊永远停在首帧（加载完成前的 0），
   * 收件箱有内容也显示不出来。本文件其余区块的 `sectionHeader` 参数都是静态资源，不受影响。
   */
  @Builder
  newSectionHeader() {
    Row() {
      SectionHeader({
        title: $r('app.string.home_new'),
        actionText: $r('app.string.inbox_title'),
        countPill: this.newCount,
        onAction: () => {
          this.onNavigate('inbox');
        }
      })
    }
    .width('100%')
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.SPACE_S })
  }

  /** 横滑剧集卡片（上游 LinearLayoutManager(HORIZONTAL)，左右 12vp 边距） */
  @Builder
  horizontalCards() {
    List({ space: 0 }) {
      ForEach(this.continueItems, (item: FeedItem) => {
        ListItem() {
          EpisodeCard({
            title: item.title,
            dateText: this.dateText(item.pubDate),
            imageUrl: this.itemImage(item),
            progress: this.progressFor(item),
            playing: this.isCurrentlyPlaying(item.id),
            actionIcon: this.secondaryIcon(item),
            downloadProgress: this.cardDownloadProgress(item),
            downloadIndeterminate: this.downloadIndeterminate(item),
            onTap: () => {
              this.onRowTap(item);
            },
            onAction: () => {
              this.secondaryAction(item);
            },
            onLongPress: () => {
              this.openRowMenu(item);
            }
          })
        }
      }, (item: FeedItem) => 'c-' + item.id.toString())
    }
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
  }

  @Builder
  horizontalEpisodes() {
    List({ space: 0 }) {
      ForEach(this.surpriseItems, (item: FeedItem) => {
        ListItem() {
          EpisodeCard({
            title: item.title,
            dateText: this.dateText(item.pubDate),
            imageUrl: this.itemImage(item),
            progress: this.progressFor(item),
            playing: this.isCurrentlyPlaying(item.id),
            actionIcon: this.secondaryIcon(item),
            downloadProgress: this.cardDownloadProgress(item),
            downloadIndeterminate: this.downloadIndeterminate(item),
            onTap: () => {
              this.onRowTap(item);
            },
            onAction: () => {
              this.secondaryAction(item);
            },
            onLongPress: () => {
              this.openRowMenu(item);
            }
          })
        }
      }, (item: FeedItem) => 'h-' + item.id.toString())
    }
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
  }

  /** 横滑订阅封面（上游 horizontal_feed_item：96vp 封面、圆角 16vp） */
  @Builder
  horizontalFeeds() {
    List({ space: 0 }) {
      ForEach(this.topFeeds, (stat: FeedStat) => {
        ListItem() {
          Column({ space: DesignTokens.SPACE_XS }) {
            FeedCover({
              imageUrl: this.feedImage(stat.feedId),
              coverSize: DesignTokens.COVER_FEED_TILE,
              radius: DesignTokens.RADIUS_CARD,
              fallbackTitle: stat.title,
              placeholderColor: $r('app.color.cover_placeholder')
            })
              .shadow({ radius: 8, color: '#1A000000', offsetY: 2 })
            Text(stat.title)
              .width(DesignTokens.COVER_FEED_TILE)
              .fontSize(DesignTokens.FONT_FOOTNOTE)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          .margin(DesignTokens.SPACE_XS)
          .onClick(() => {
            router.pushUrl({ url: 'pages/FeedDetailPage', params: { feedId: stat.feedId } });
          })
          // 订阅封面长按进订阅设置（与订阅页同一套交互）
          .gesture(LongPressGesture().onAction(() => {
            router.pushUrl({ url: 'pages/FeedSettingsPage', params: { feedId: stat.feedId } });
          }))
        }
      }, (stat: FeedStat) => 't-' + stat.feedId.toString())
    }
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
  }

  /**
   * 竖排单集行（上游 InboxSection / DownloadsSection 用 feeditemlist_item + EpisodeItemListAdapter）。
   * 左右滑动由外层 `ListItem.swipeAction` 提供（`swipeAction` 是 ListItem 的属性），
   * 长按打开操作菜单（上游 registerForContextMenu）。
   */
  @Builder
  episodeRow(item: FeedItem) {
    EpisodeRow({
      title: item.title,
      imageUrl: this.itemImage(item),
      metaText: this.metaText(item),
      positionText: this.positionText(item),
      durationText: this.durationText(item),
      progress: this.progressFor(item),
      playing: this.isCurrentlyPlaying(item.id),
      isPlayed: item.isPlayed,
      isNew: item.isNew(),
      isFavorite: this.favoriteIds.includes(item.id),
      inQueue: this.queueIds.includes(item.id),
      isVideo: this.isVideo(item),
      actionIcon: this.secondaryIcon(item),
      downloadProgress: this.downloadProgress(item),
      downloadIndeterminate: this.downloadIndeterminate(item),
      onTap: () => {
        this.onRowTap(item);
      },
      onAction: () => {
        this.secondaryAction(item);
      },
      onLongPress: () => {
        this.openRowMenu(item);
      }
    })
  }

  /**
   * 划出项配置：「看新内容」区块（对照上游 InboxSection，屏幕 = 收件箱）。
   * 该屏幕关闭滑动动作、或某一侧配置为「无」时，对应侧不挂划出项。
   */
  private newSwipeOptions(item: FeedItem): SwipeActionOptions {
    const options: SwipeActionOptions = {};
    if (!SwipeActions.isEnabled(SwipeScreen.INBOX)) {
      return options;
    }
    if (this.newRightId !== SwipeActionId.NONE) {
      const rightSpec: SwipeActionSpec = swipeActionSpec(this.newRightId);
      const rightItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(rightSpec, SwipeScreen.INBOX, item);
        },
        actionAreaDistance: HomePage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(SwipeScreen.INBOX, this.newRightId, item);
        }
      };
      options.start = rightItem;
    }
    if (this.newLeftId !== SwipeActionId.NONE) {
      const leftSpec: SwipeActionSpec = swipeActionSpec(this.newLeftId);
      const leftItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(leftSpec, SwipeScreen.INBOX, item);
        },
        actionAreaDistance: HomePage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(SwipeScreen.INBOX, this.newLeftId, item);
        }
      };
      options.end = leftItem;
    }
    return options;
  }

  /**
   * 划出项配置：「管理下载」区块（对照上游 DownloadsSection，屏幕 = 已完成下载）。
   * 该屏幕关闭滑动动作、或某一侧配置为「无」时，对应侧不挂划出项。
   */
  private downloadSwipeOptions(item: FeedItem): SwipeActionOptions {
    const options: SwipeActionOptions = {};
    if (!SwipeActions.isEnabled(SwipeScreen.DOWNLOADS)) {
      return options;
    }
    if (this.dlRightId !== SwipeActionId.NONE) {
      const rightSpec: SwipeActionSpec = swipeActionSpec(this.dlRightId);
      const rightItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(rightSpec, SwipeScreen.DOWNLOADS, item);
        },
        actionAreaDistance: HomePage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(SwipeScreen.DOWNLOADS, this.dlRightId, item);
        }
      };
      options.start = rightItem;
    }
    if (this.dlLeftId !== SwipeActionId.NONE) {
      const leftSpec: SwipeActionSpec = swipeActionSpec(this.dlLeftId);
      const leftItem: SwipeActionItem = {
        builder: () => {
          this.swipeButton(leftSpec, SwipeScreen.DOWNLOADS, item);
        },
        actionAreaDistance: HomePage.SWIPE_ACTION_DISTANCE,
        onAction: () => {
          this.runSwipeAction(SwipeScreen.DOWNLOADS, this.dlLeftId, item);
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
  swipeButton(spec: SwipeActionSpec, screen: string, item: FeedItem) {
    SwipeActionButton({
      spec: spec,
      destructive: isDestructiveSwipeAction(spec.id),
      onTap: () => {
        this.runSwipeAction(screen, spec.id, item);
      }
    })
  }

  /** 划出项动作分发：只调用本页已有方法，不在这里重复实现动作逻辑 */
  private runSwipeAction(screen: string, id: string, item: FeedItem): void {
    if (id === SwipeActionId.NONE) {
      return;
    }
    if (id === SwipeActionId.ADD_TO_QUEUE) {
      this.addToQueue(item);
      return;
    }
    if (id === SwipeActionId.MARK_PLAYED) {
      this.markPlayed(item);
      return;
    }
    if (id === SwipeActionId.REMOVE_FROM_INBOX) {
      this.removeFromInbox(item);
      return;
    }
    if (id === SwipeActionId.START_DOWNLOAD) {
      this.downloadAction(item);
      return;
    }
    if (id === SwipeActionId.DELETE) {
      // 「删除已下载文件」只属于「管理下载」区块
      if (screen === SwipeScreen.DOWNLOADS) {
        this.deleteDownload(item);
      }
      return;
    }
    if (id === SwipeActionId.MARK_FAV && !this.favoriteIds.includes(item.id)) {
      this.toggleFavorite(item);
      return;
    }
    if (id === SwipeActionId.REMOVE_FROM_FAVORITES && this.favoriteIds.includes(item.id)) {
      this.toggleFavorite(item);
    }
    // 其余动作（SHARE / MOVE_* / NONE）本页没有对应实现，按「无动作」处理
  }

  /** 解析两个区块的 [右滑, 左滑] 动作 id（aboutToAppear 与 SWIPE_ACTIONS_CHANGED 时调用） */
  private loadSwipeActions(): void {
    const newIds: string[] = SwipeActions.resolve(SwipeScreen.INBOX);
    this.newRightId = newIds[0];
    this.newLeftId = newIds[1];
    const downloadIds: string[] = SwipeActions.resolve(SwipeScreen.DOWNLOADS);
    this.dlRightId = downloadIds[0];
    this.dlLeftId = downloadIds[1];
  }

  @Builder
  emptyLabel(text: ResourceStr) {
    Text(text)
      .width('100%')
      .fontSize(DesignTokens.FONT_FOOTNOTE)
      .fontColor($r('app.color.text_tertiary'))
      .textAlign(TextAlign.Center)
      .padding({ left: 32, right: 32, top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_S })
  }

  // ---------------------------------------------------------------- 编辑模式

  /** 编辑模式：区块顺序（上/下移）+ 显示开关（上游 HomeSectionsSettingsDialog 的「显示 / 隐藏」两组） */
  @Builder
  editSections() {
    Column() {
      Text($r('app.string.home_edit_hint'))
        .width('100%')
        .fontSize(DesignTokens.FONT_CAPTION)
        .fontColor($r('app.color.text_tertiary'))
        .padding({
          left: DesignTokens.PAGE_MARGIN,
          right: DesignTokens.PAGE_MARGIN,
          bottom: DesignTokens.SPACE_S
        })

      Scroll() {
        Column({ space: DesignTokens.SPACE_S }) {
          Row() {
            SectionHeader({ title: $r('app.string.home_section_shown') })
          }
          .width('100%')

          ForEach(this.sectionRows(true), (row: HomeSectionRow) => {
            this.editRow(row)
          }, (row: HomeSectionRow) => 'v-' + row.tag)

          Row() {
            SectionHeader({ title: $r('app.string.home_section_hidden') })
          }
          .width('100%')

          ForEach(this.sectionRows(false), (row: HomeSectionRow) => {
            this.editRow(row)
          }, (row: HomeSectionRow) => 'h-' + row.tag)
        }
        .width('100%')
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_XXL })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  editRow(row: HomeSectionRow) {
    Row({ space: DesignTokens.SPACE_S }) {
      SymbolGlyph(row.icon)
        .fontSize(DesignTokens.ICON_L)
        .fontColor([$r('app.color.text_secondary')])
      Text(row.title)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      // 上移 / 下移（上游对话框是拖拽手柄；这里用同一列表行内的按钮，避免与页面滚动抢手势）
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_up'))
          .fontSize(DesignTokens.ICON_M)
          .fontColor([$r('app.color.text_secondary')])
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.moveSection(row.tag, -1);
      })

      Row() {
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(DesignTokens.ICON_M)
          .fontColor([$r('app.color.text_secondary')])
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.moveSection(row.tag, 1);
      })

      Toggle({ type: ToggleType.Switch, isOn: !row.hidden })
        .onChange((isOn: boolean) => {
          // 与当前状态一致就不写：某些版本 Toggle 在首次渲染时也会回调 onChange，
          // 那时若照抄 isOn 会把区块无故隐藏掉（本轮验收还专门查过：本机未复现，纯防御）。
          if (isOn === !row.hidden) {
            return;
          }
          this.setSectionHidden(row.tag, !isOn);
        })
    }
    .width('100%')
    .padding(DesignTokens.SPACE_M)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_ROW)
  }

  // ---------------------------------------------------------------- 长按菜单

  /** 菜单遮罩：点击关闭（不拦截列表滚动，仅在菜单打开时存在） */
  @Builder
  sheetBackdrop() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .onClick(() => {
        this.menuShown = false;
      })
  }

  /** 单集操作菜单（对照上游 FeedItemMenuHandler 的常用动作） */
  @Builder
  actionSheet() {
    Column({ space: 2 }) {
      Text(this.menuTitle())
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding(DesignTokens.SPACE_L)

      this.menuRow($r('sys.symbol.play_fill'), $r('app.string.episode_play'), () => {
        this.playMenuItem();
      })
      this.menuRow($r('sys.symbol.checkmark_circle'),
        this.menuItemPlayed() ? $r('app.string.episode_mark_unplayed') : $r('app.string.episode_mark_played'),
        () => {
          this.togglePlayedMenuItem();
        })
      this.menuRow($r('sys.symbol.music_note_list'),
        this.menuItemQueued() ? $r('app.string.queue_remove') : $r('app.string.episode_add_queue'),
        () => {
          this.toggleQueueMenuItem();
        })
      this.menuRow(this.menuItemFavorite() ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
        $r('app.string.favorites_button'),
        () => {
          this.toggleFavoriteMenuItem();
        })
      this.menuRow($r('sys.symbol.arrow_down_circle'), this.menuDownloadLabel(), () => {
        this.downloadMenuItem();
      })

      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
        .onClick(() => {
          this.menuShown = false;
          this.menuItem = undefined;
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
  }

  @Builder
  menuRow(icon: Resource, label: ResourceStr, onTap: () => void) {
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
      this.menuShown = false;
      onTap();
    })
  }

  // ---------------------------------------------------------------- 生命周期与数据

  aboutToAppear(): void {
    this.sectionOrder = UserPreferences.getHomeSectionOrder();
    this.hiddenSections = UserPreferences.getHiddenHomeSections();
    this.loadSwipeActions();
    // 事件订阅（上游各 Section 分别监听；这里统一重载首屏，播放进度走轻量更新）
    this.eventTokens.push(EventHub.subscribe(EventType.FEED_ITEM_UPDATE, () => {
      this.load();
    }));
    this.eventTokens.push(EventHub.subscribe(EventType.FEED_LIST_UPDATE, () => {
      this.load();
    }));
    this.eventTokens.push(EventHub.subscribe(EventType.QUEUE, () => {
      this.load();
    }));
    this.eventTokens.push(EventHub.subscribe(EventType.PLAYER_STATUS, () => {
      this.load();
    }));
    this.eventTokens.push(EventHub.subscribe(EventType.EPISODE_DOWNLOAD, () => {
      this.load();
    }));
    this.eventTokens.push(EventHub.subscribe(EventType.DOWNLOAD_LOG, () => {
      this.load();
    }));
    this.eventTokens.push(EventHub.subscribe(EventType.PLAYBACK_POSITION, (data: object) => {
      this.onPlaybackPosition(data);
    }));
    // 设置页保存「滑动动作」后重新解析两个区块的左右滑动作
    this.eventTokens.push(EventHub.subscribe(EventType.SWIPE_ACTIONS_CHANGED, () => {
      this.loadSwipeActions();
    }));
    this.load();
  }

  aboutToDisappear(): void {
    for (const token of this.eventTokens) {
      EventHub.unsubscribeToken(token);
    }
    this.eventTokens = [];
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      // 上游 QueueSection.loadItems()：DBReader.getPausedQueue(8)
      this.continueItems = await EpisodeRepository.listPausedQueue(HomePage.NUM_EPISODES);

      // 上游 InboxSection.loadItems()：`DBReader.getEpisodes(0, 2, FeedItemFilter(NEW), ...)`
      // + `getTotalEpisodeCount(FeedItemFilter(NEW))` —— 「看新内容」就是收件箱（read = -1）
      // 里的前两条，计数也是收件箱总数，不是全库未播放（read != 1）。
      this.newItems = await EpisodeRepository.listInboxPage(HomePage.NEW_EPISODES,
        UserPreferences.getInboxSortedOrder());
      this.newCount = await EpisodeRepository.countNew();

      // 上游 EpisodesSurpriseSection.loadItems()：DBReader.getRandomEpisodes(8, seed)
      this.surpriseItems = await EpisodeRepository.listRandomEpisodes(HomePage.NUM_EPISODES, this.surpriseSeed);

      // 上游 SubscriptionsSection.loadItems()：最近 3 年的 feedTime，按收时长降序取 8 个已订阅源
      const threeYearsAgo: number = Date.now() - 3 * 365 * 24 * 60 * 60 * 1000;
      const stats: FeedStat[] = await EpisodeRepository.listStatsByFeed(
        UserPreferences.getStatisticsIncludeMarked(), threeYearsAgo, Number.MAX_SAFE_INTEGER);
      this.topFeeds = stats.slice(0, HomePage.NUM_FEEDS);

      // 上游 DownloadsSection.loadItems()：按用户设置的下载排序取前 2 条
      this.downloadItems = await EpisodeRepository.listDownloadedItems(
        HomePage.NUM_DOWNLOADS, UserPreferences.getDownloadsSortedOrder() as SortOrder);

      await QueueEngine.load();
      this.queueIds = QueueEngine.getItems().map((item: FeedItem) => item.id);

      // 上游 updateWelcomeScreenVisibility()：全库单集总数为 0 才显示欢迎页
      this.hasEpisodes = (await EpisodeRepository.countAllEpisodes()) > 0;

      const feeds: Feed[] = await FeedRepository.listSubscribed();
      const images: Map<number, string> = new Map<number, string>();
      for (const feed of feeds) {
        images.set(feed.id, feed.imageUrl);
      }
      this.feedImages = images;

      const favorites: FeedItem[] = await FavoritesRepository.list();
      this.favoriteIds = favorites.map((item: FeedItem) => item.id);
    } catch (error) {
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
      this.refreshing = false;
    }
  }

  async shuffleSurprise(): Promise<void> {
    this.surpriseSeed = newSurpriseSeed();
    this.surpriseItems = await EpisodeRepository.listRandomEpisodes(HomePage.NUM_EPISODES, this.surpriseSeed);
  }

  async refreshAll(): Promise<void> {
    // 防重入：`Refresh` 组件在 `refreshing` 被置真时会再回调一次 `onRefreshing`，
    // 而标题栏的刷新动作也会置真 —— 不拦的话一次点击会并发跑两遍 refreshAll，
    // 同一个源被插入两次（第 40 轮验收实测到重复单集）。
    if (this.refreshingNow) {
      return;
    }
    this.refreshingNow = true;
    this.refreshing = true;
    try {
      await RefreshService.refreshAll();
    } catch (error) {
      this.message = (error as Error).message;
    } finally {
      this.refreshingNow = false;
      await this.load();
    }
  }

  /** 播放进度事件：只更新当前播放项的进度条（上游 notifyPlaybackPositionUpdated），不重查数据库 */
  onPlaybackPosition(data: object): void {
    const payload: Record<string, number> = data as Record<string, number>;
    const time: number = payload['time'];
    const duration: number = payload['duration'];
    if (duration <= 0) {
      return;
    }
    const percent: number = Math.floor(time * 100 / duration);
    this.playbackPercent = percent > 100 ? 100 : (percent < 5 ? 5 : percent);
    this.playbackPositionMs = time;
  }

  // ---------------------------------------------------------------- 菜单目标动作

  menuTitle(): string {
    return this.menuItem === undefined ? '' : this.menuItem!.title;
  }

  menuItemPlayed(): boolean {
    return this.menuItem !== undefined && this.menuItem!.isPlayed;
  }

  menuItemQueued(): boolean {
    return this.menuItem !== undefined && this.queueIds.includes(this.menuItem!.id);
  }

  menuItemFavorite(): boolean {
    return this.menuItem !== undefined && this.favoriteIds.includes(this.menuItem!.id);
  }

  menuDownloadLabel(): ResourceStr {
    if (this.menuItem === undefined) {
      return $r('app.string.episode_download');
    }
    const state: string = this.downloadState(this.menuItem!);
    if (state === 'DONE') {
      return $r('app.string.episode_delete_download');
    }
    if (state === 'RUNNING' || state === 'PAUSED') {
      return $r('app.string.episode_download_cancel');
    }
    return $r('app.string.episode_download');
  }

  playMenuItem(): void {
    if (this.menuItem !== undefined) {
      this.playItem(this.menuItem!);
    }
  }

  togglePlayedMenuItem(): void {
    if (this.menuItem !== undefined) {
      this.togglePlayed(this.menuItem!);
    }
  }

  toggleQueueMenuItem(): void {
    if (this.menuItem !== undefined) {
      this.addToQueue(this.menuItem!);
    }
  }

  toggleFavoriteMenuItem(): void {
    if (this.menuItem !== undefined) {
      this.toggleFavorite(this.menuItem!);
    }
  }

  downloadMenuItem(): void {
    if (this.menuItem !== undefined) {
      this.downloadAction(this.menuItem!);
    }
  }

  openRowMenu(item: FeedItem): void {
    this.menuItem = item;
    this.menuShown = true;
    this.menuOpenedAt = Date.now();
  }

  /**
   * 行 / 横滑卡片的单击：长按刚打开菜单时不播放
   * （`parallelGesture` 下同一次长按手势的 onClick 也会命中，见 `menuOpenedAt`）。
   */
  onRowTap(item: FeedItem): void {
    if (this.menuShown && Date.now() - this.menuOpenedAt < 1000) {
      return;
    }
    this.playItem(item);
  }

  // ---------------------------------------------------------------- 动作

  /** 标记为已播放（左滑动作：幂等，不因当前状态反转） */
  async markPlayed(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.markPlayed(item.id, true);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  async togglePlayed(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.markPlayed(item.id, !item.isPlayed);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /**
   * 加入 / 移出队列（上游 add to queue / remove from queue）。
   * 入队时清除「新」标记（read = -1 → 0），与收件箱页 `addToQueue` 和上游
   * `DBWriter.addQueueItem` 一致：从「看新内容」入队的单集会随之移出该区块。
   */
  async addToQueue(item: FeedItem): Promise<void> {
    try {
      if (this.queueIds.includes(item.id)) {
        await QueueEngine.remove(item.id);
      } else {
        await QueueEngine.add(item);
        if (item.isNew()) {
          await EpisodeRepository.setNewFlag(item.id, false);
        }
      }
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 加入 / 取消收藏 */
  async toggleFavorite(item: FeedItem): Promise<void> {
    try {
      if (this.favoriteIds.includes(item.id)) {
        await FavoritesRepository.remove(item.id);
      } else {
        await FavoritesRepository.add(item.id, item.feedId);
      }
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /**
   * 移出收件箱（对照上游 RemoveFromInboxSwipeAction）：清除「新」标记。
   * 与其它改动一样发 FEED_ITEM_UPDATE，让收件箱页同步刷新。
   */
  async removeFromInbox(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.setNewFlag(item.id, false);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 删除已下载文件（上游 delete file） */
  async deleteDownload(item: FeedItem): Promise<void> {
    try {
      if (item.media !== undefined) {
        await DownloadManager.deleteFile(item.media);
      }
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /**
   * 菜单里的下载动作（对照上游 ItemActionButton 的三种下载态）：
   * 未下载 → 开始下载；下载中/已暂停 → 取消下载（删掉半成品）；已下载 → 删除文件。
   */
  async downloadAction(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = item.media;
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
        await DownloadManager.startDownload(media, item.title);
      }
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /**
   * 横滑卡片 / 列表行的副操作钮动作，逐条对照上游 `ItemActionButton.forItem`：
   * 无媒体 → 标记已播；正在播放 → 暂停；已下载 → 播放；
   * 下载中 → 取消下载；开了「流播优先」→ 流播；其余 → 下载。
   */
  async secondaryAction(item: FeedItem): Promise<void> {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      await this.togglePlayed(item);
      return;
    }
    if (this.isPlaying(item.id)) {
      PlayerManager.pause();
      return;
    }
    if (media.fileUrl !== '') {
      await this.playItem(item);
      return;
    }
    const state: string = this.downloadState(item);
    if (state === 'RUNNING' || state === 'PAUSED') {
      await this.downloadAction(item);
      return;
    }
    if (UserPreferences.getStreamOverDownload()) {
      await this.playItem(item);
      return;
    }
    await this.downloadAction(item);
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

  async playItem(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    const playable: Playable | undefined = await QueueEngine.toPlayable(item);
    if (playable === undefined) {
      return;
    }
    await QueueEngine.ensureQueued(item);
    await PlayerManager.load(playable, item.media.position, true);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  // ---------------------------------------------------------------- 状态查询

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

  /** 列表行的下载进度环（-1 = 不画） */
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

  /**
   * 横滑卡片的下载进度环（上游 HorizontalItemViewHolder.bind）：
   * 下载中画进度，已下载画满（`setPercentage(1)`），未下载清零（只留圆钮底色）。
   */
  private cardDownloadProgress(item: FeedItem): number {
    if (item.media === undefined) {
      return -1;
    }
    const state: string = this.downloadState(item);
    if (state === 'DONE') {
      return 100;
    }
    if (state === 'RUNNING' || state === 'PAUSED') {
      const percent: number = DownloadManager.getProgressPercent(item.media.id);
      return percent < 0 ? 1 : percent;
    }
    return -1;
  }

  private downloadIndeterminate(item: FeedItem): boolean {
    if (item.media === undefined) {
      return false;
    }
    return DownloadManager.isProgressIndeterminate(item.media.id);
  }

  /** 当前播放中的项（上游 PlaybackStatus.isCurrentlyPlaying：当前媒体且状态为播放中） */
  isPlaying(feedItemId: number): boolean {
    return this.isCurrentlyPlaying(feedItemId) && PlayerManager.getStatus() === 'PLAYING';
  }

  /** 当前播放项（不看播放/暂停状态，上游 PlaybackStatus.isPlaying） */
  private isCurrentlyPlaying(feedItemId: number): boolean {
    const current: Playable | undefined = PlayerManager.getCurrent();
    return current !== undefined && current.feedItemId === feedItemId;
  }

  itemImage(item: FeedItem): string {
    return item.imageUrl !== '' ? item.imageUrl : this.feedImage(item.feedId);
  }

  feedImage(feedId: number): string {
    return this.feedImages.get(feedId) ?? '';
  }

  dateText(timestamp: number): string {
    if (timestamp <= 0) {
      return '';
    }
    return new Date(timestamp).toLocaleDateString();
  }

  /** 行的进度值：当前播放项用实时进度（上游 notifyPlaybackPositionUpdated），其余用库里的 position */
  progressFor(item: FeedItem): number {
    if (this.isCurrentlyPlaying(item.id) && this.playbackPercent > 0) {
      return this.playbackPercent;
    }
    return this.itemProgress(item);
  }

  itemProgress(item: FeedItem): number {
    if (item.media === undefined || item.media.duration <= 0 || item.media.position <= 0) {
      return 0;
    }
    const percent: number = Math.floor(item.media.position * 100 / item.media.duration);
    return percent > 100 ? 100 : (percent < 5 ? 5 : percent);
  }

  /** 位置文本（上游 txtvPosition）：当前播放项显示实时位置 */
  positionText(item: FeedItem): string {
    if (this.isCurrentlyPlaying(item.id) && this.playbackPositionMs > 0) {
      return DurationUtils.format(this.playbackPositionMs);
    }
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

  isVideo(item: FeedItem): boolean {
    const media: FeedMedia | undefined = item.media;
    return media !== undefined && media.getMediaType() === MediaType.VIDEO;
  }

  /** 状态行：发布日期 · 文件大小（上游 feeditemlist_item 的 pubDate · size） */
  metaText(item: FeedItem): string {
    const parts: string[] = [];
    if (item.pubDate > 0) {
      parts.push(this.dateText(item.pubDate));
    }
    if (item.media !== undefined && item.media.size > 0) {
      parts.push(this.sizeText(item.media.size));
    }
    return parts.join(' · ');
  }

  sizeText(bytes: number): string {
    if (bytes <= 0) {
      return '0 MB';
    }
    const mb: number = bytes / (1024 * 1024);
    return mb < 1 ? (bytes / 1024).toFixed(0) + ' KB' : mb.toFixed(1) + ' MB';
  }

  // ---------------------------------------------------------------- 区块顺序 / 显隐

  /** 当前完整区块顺序（未配置过时用默认顺序，并补齐后来新增的区块） */
  private fullOrder(): string[] {
    const order: string[] = this.sectionOrder.length > 0
      ? this.sectionOrder.slice() : HomePage.DEFAULT_SECTIONS.slice();
    for (const tag of HomePage.DEFAULT_SECTIONS) {
      if (!order.includes(tag)) {
        order.push(tag);
      }
    }
    return order;
  }

  /** 首页要渲染的区块顺序（上游 HomePreferences.getSortedSectionTags） */
  visibleSections(): string[] {
    const result: string[] = [];
    for (const tag of this.fullOrder()) {
      if (!this.hiddenSections.includes(tag)) {
        result.push(tag);
      }
    }
    return result;
  }

  /**
   * 编辑模式的行：`shown = true` 取「显示」组（`hidden === false`），`false` 取「隐藏」组。
   *
   * 注意这里的比较方向：`hidden === shown` 才是**要跳过**的行。
   * 第 40 轮验收把它写反过（保留 `hidden !== shown`），后果是「显示」组恒为空：
   * `sectionRows(true)` 返回的其实是隐藏组，于是「显示」标题所在的槽位什么都不渲染，
   * 5 个区块行全部来自隐藏组 —— 在界面上看起来就像「隐藏」标题被排到了行前面，
   * 一度被误判成 ArkUI 的兄弟节点重排（换了 6 种布局写法都"复现"，其实是同一个过滤条件写反）。
   */
  sectionRows(shown: boolean): HomeSectionRow[] {
    const rows: HomeSectionRow[] = [];
    for (const tag of this.fullOrder()) {
      const hidden: boolean = this.hiddenSections.includes(tag);
      if (hidden === shown) {
        continue;
      }
      rows.push({
        tag: tag,
        title: this.sectionTitle(tag),
        icon: this.sectionIcon(tag),
        hidden: hidden
      });
    }
    return rows;
  }

  private sectionTitle(tag: string): ResourceStr {
    if (tag === 'continue') {
      return $r('app.string.home_continue');
    }
    if (tag === 'new') {
      return $r('app.string.home_new');
    }
    if (tag === 'random') {
      return $r('app.string.home_random');
    }
    if (tag === 'top') {
      return $r('app.string.home_top');
    }
    return $r('app.string.home_downloads');
  }

  private sectionIcon(tag: string): Resource {
    if (tag === 'continue') {
      return $r('sys.symbol.play_circle');
    }
    if (tag === 'new') {
      return $r('sys.symbol.inbox');
    }
    if (tag === 'random') {
      return $r('sys.symbol.shuffle');
    }
    if (tag === 'top') {
      return $r('sys.symbol.headphones');
    }
    return $r('sys.symbol.download_1');
  }

  private moveSection(tag: string, delta: number): void {
    const order: string[] = this.fullOrder();
    const from: number = order.indexOf(tag);
    const to: number = from + delta;
    if (from < 0 || to < 0 || to >= order.length) {
      return;
    }
    const moved: string = order[from];
    order.splice(from, 1);
    order.splice(to, 0, moved);
    this.sectionOrder = order;
    UserPreferences.setHomeSectionOrder(order);
  }

  private setSectionHidden(tag: string, hidden: boolean): void {
    let hiddenList: string[] = this.hiddenSections.slice();
    if (hidden) {
      if (!hiddenList.includes(tag)) {
        hiddenList.push(tag);
      }
    } else {
      hiddenList = hiddenList.filter((entry: string) => entry !== tag);
    }
    this.hiddenSections = hiddenList;
    UserPreferences.setHiddenHomeSections(hiddenList);
  }
}
