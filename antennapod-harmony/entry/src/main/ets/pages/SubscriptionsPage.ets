import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';
import { Feed } from '../model/Feed';
import { AutoDeleteAction } from '../model/Enums';
import { FeedRepository, FeedTagState } from '../db/repositories/FeedRepository';
import { EpisodeRepository, FeedCounter } from '../db/repositories/EpisodeRepository';
import { SubscriptionService } from '../services/SubscriptionService';
import { RefreshService } from '../services/RefreshService';
import { PlayerManager } from '../player/PlayerManager';
import { FeedCover } from '../components/FeedCover';
import { LazyDataSource } from '../components/LazyDataSource';
import { EventHub, EventType, RefreshStateData, FeedItemUpdateData } from '../events/EventHub';
import { DesignTokens } from '../common/DesignTokens';
import { menuIcon } from '../common/MenuIcons';
import { AppIconButton } from '../components/AppIconButton';
import { OverflowButton } from '../components/OverflowButton';
import { TagChip } from '../components/TagChip';
import { EmptyState } from '../components/EmptyState';
import { UserPreferences } from '../prefs/UserPreferences';

/** 订阅排序（对照上游 FeedOrder：0=计数 1=字母 2=最近更新 3=最多播放） */
const FEED_ORDER_COUNTER: number = 0;
const FEED_ORDER_ALPHABETICAL: number = 1;
const FEED_ORDER_LAST_UPDATE: number = 2;
const FEED_ORDER_MOST_PLAYED: number = 3;

/** 计数口径（取值与上游 FeedCounter 的 id 一一对应） */
const COUNTER_INBOX: number = 1;
const COUNTER_UNPLAYED: number = 2;
const COUNTER_NONE: number = 3;
const COUNTER_DOWNLOADED: number = 4;
const COUNTER_DOWNLOADED_UNPLAYED: number = 5;

/**
 * 「未标记」伪标签。上游用 `FeedPreferences.TAG_UNTAGGED`（"untagged"）作为保留名，
 * 本移植版同样需要与真实标签名区分开，用一个不可能出现在 feed_tags 里的控制字符前缀。
 */
const TAG_UNTAGGED: string = '\u0001untagged';

/** 标签胶囊文字截断长度（上游 SubscriptionTagAdapter：>20 截为 19+…） */
const TAG_TITLE_MAX: number = 20;

/** 每次进入订阅页恢复的滚动位置（对照上游 SubscriptionFragment 的静态 scrollPosition） */
class SubscriptionsScroll {
  static firstIndex: number = 0;
  /**
   * 用户是否正在拖动 / 惯性滑动。
   *
   * 刷新期间订阅页会因 `FEED_LIST_UPDATE`（逐 Feed 广播）反复重查库，若此时用户正在下滑，
   * 任何 `scrollToIndex` 回跳都会把手指下的列表拽走 —— 表现为「怎么滑都被拉回原位」。
   * 因此手势进行中只登记待恢复目标，等 `ScrollState.Idle` 再补做。
   */
  static scrolling: boolean = false;
}

/** 单选对话框的一项（排序 / 计数 / 列数） */
interface ChoiceOption {
  id: number;
  label: ResourceStr;
}

/** 多选动作栏的一项 */
interface SelectAction {
  id: string;
  label: ResourceStr;
  icon: Resource;
  destructive: boolean;
}

/** 标签行的一项 */
interface TagEntry {
  key: string;
  label: ResourceStr;
  value: string;
}

/** 订阅过滤组（对照上游 SubscriptionsFilterGroup） */
interface FilterOption {
  id: string;
  label: Resource;
}

interface FilterGroup {
  key: string;
  options: FilterOption[];
}

/**
 * 订阅页（对齐上游 fragment_subscriptions.xml + SubscriptionFragment）：
 * 标题栏（搜索 + 刷新 + 溢出）+ 标签筛选胶囊行 + 封面网格 + 右下角 56vp FAB。
 * 溢出菜单提供 过滤 / 排序 / 计数 / 每行列数（二级菜单）/ 显示标题。
 * 长按瓦片进入多选（上游 ActionMode + FloatingSelectMenu）。
 */
@Component
export struct SubscriptionsPage {
  private dataSource: LazyDataSource<Feed> = new LazyDataSource<Feed>();
  /** 网格 / 列表的滚动控制器（B15：重新进入恢复上次位置） */
  private listScroller: Scroller = new Scroller();
  /** 标签行的滚动控制器（B14：选中的胶囊滚动到居中） */
  private tagScroller: Scroller = new Scroller();
  @State feeds: Feed[] = [];
  @State filtered: Feed[] = [];
  /** 命名标签（字母序，来自数据库全量订阅，不受过滤影响） */
  @State tagNames: string[] = [];
  @State hasUntagged: boolean = false;
  @State activeTag: string = '';
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State columns: number = 3;
  @State showTitles: boolean = false;
  @State message: string = '';
  @State showFilterSheet: boolean = false;
  @State showSortDialog: boolean = false;
  @State showCounterDialog: boolean = false;
  @State showColumnsDialog: boolean = false;
  @State showTagMenu: boolean = false;
  @State showTagRenameDialog: boolean = false;
  @State showTagDeleteDialog: boolean = false;
  @State showTagsSheet: boolean = false;
  @State showUnsubscribeDialog: boolean = false;
  @State showRemoveInboxDialog: boolean = false;
  @State showKeepUpdatedDialog: boolean = false;
  @State showNotificationDialog: boolean = false;
  @State showAutoDownloadDialog: boolean = false;
  @State showAutoDeleteDialog: boolean = false;
  @State showSpeedDialog: boolean = false;
  /** 当前过滤器选中的 filterId（逗号分隔，持久化到 prefSubscriptionsFilter） */
  @State filterValues: string = '';
  @State feedOrder: number = FEED_ORDER_COUNTER;
  @State counterMode: number = COUNTER_INBOX;
  /** 多选（上游 ActionMode） */
  @State selectMode: boolean = false;
  @State selectedIds: number[] = [];
  /** 标签编辑弹层：所选订阅的公共标签集合 */
  @State tagEditValues: string[] = [];
  @State newTagText: string = '';
  /** 重命名标签弹层的输入值 */
  @State renameTagValue: string = '';
  /** Toggle 型弹层的临时值 */
  @State dialogSwitch: boolean = false;
  /** 长按打开标签菜单的时刻（吞掉紧随其后的点击，避免同时切换标签） */
  private longPressAt: number = 0;
  /** 当前长按的标签名（重命名 / 删除用） */
  private menuTag: string = '';
  private feedToken: number = -1;
  private itemToken: number = -1;
  private refreshToken: number = -1;
  /** 加载序号：并发重查库时只认最后一次的结果（onVisibleAreaChange 会连续触发多次） */
  private loadSeq: number = 0;
  /** 上次提交给 LazyForEach 的数据指纹（内容未变则跳过 setData，避免整屏瓦片重建 → 封面闪动） */
  private listSignature: string = '';
  /** 「成员 + 顺序」指纹：与之相同即走增量刷新，不必 setData（onDataReloaded 会把列表拉回顶部） */
  private listOrderSignature: string = '';
  /** 手势进行中被推迟的滚动位置恢复目标（-1 表示无） */
  private pendingScrollIndex: number = -1;

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 标题栏：多选态换成 ActionMode 式标题栏（上游 SelectableAdapter.startSelectMode）
        if (this.selectMode) {
          this.selectHeader()
        } else {
          this.titleBar()
        }

        // 标签筛选胶囊行（上游 tags_recycler；多选时置为不可见但保留占位）
        if (this.tagNames.length > 0) {
          this.tagRow()
        }

        // 「已过滤」提示行（上游 feeds_filtered_message：全局过滤器启用时显示）
        if (this.activeTag !== '' || this.filterValues !== '') {
          this.filteredRow()
        }

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, top: DesignTokens.SPACE_S })
        }

        Refresh({ refreshing: this.refreshing }) {
          Column() {
            if (this.loading) {
              // 上游 progressBar：加载期间居中转圈并隐藏空态
              Column() {
                LoadingProgress()
                  .width(48)
                  .height(48)
                  .color($r('app.color.primary'))
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            } else if (this.filtered.length === 0) {
              Column() {
                EmptyState({
                  icon: $r('sys.symbol.folder'),
                  title: $r('app.string.placeholder_subscriptions'),
                  sub: this.emptyHint()
                })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            } else if (this.columns <= 1) {
              List({ space: DesignTokens.SPACE_XS, scroller: this.listScroller }) {
                LazyForEach(this.dataSource, (feed: Feed) => {
                  ListItem() {
                    this.listRow(feed)
                  }
                }, (feed: Feed) => 'list-' + feed.id)
              }
              .width('100%')
              .height('100%')
              .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: 88 })
              .scrollBar(BarState.Off)
              .onScrollIndex((first: number) => {
                SubscriptionsScroll.firstIndex = first;
              })
              .onDidScroll((offset: number, state: ScrollState) => {
                this.onListScrollState(state);
              })
            } else {
              Grid(this.listScroller) {
                LazyForEach(this.dataSource, (feed: Feed) => {
                  GridItem() {
                    this.gridTile(feed)
                  }
                }, (feed: Feed) => 'grid-' + feed.id)
              }
              .columnsTemplate(this.columnsTemplate())
              .columnsGap(DesignTokens.SPACE_XS)
              .rowsGap(DesignTokens.SPACE_XS)
              .width('100%')
              .height('100%')
              .padding({ left: DesignTokens.SPACE_XS, right: DesignTokens.SPACE_XS, bottom: 88 })
              .scrollBar(BarState.Off)
              .onScrollIndex((first: number) => {
                SubscriptionsScroll.firstIndex = first;
              })
              .onDidScroll((offset: number, state: ScrollState) => {
                this.onListScrollState(state);
              })
            }
          }
          .width('100%')
          .height('100%')
        }
        .layoutWeight(1)
        .onRefreshing(() => {
          // 已经有一轮刷新在跑（例如 OPML 批量导入后自动触发的后台整库刷新）：把 refreshing 置真时
          // Refresh 组件会回弹一次 onRefreshing，这不是用户下拉。忽略它，否则会再排一轮整库刷新
          // （RefreshService 的补跑语义会把 86 个订阅抓两遍）并把「已更新新增：0」写到提示行。
          if (RefreshService.isRunning()) {
            return;
          }
          this.refreshAll();
        })
      }
      .width('100%')
      .height('100%')

      // 悬浮「添加播客」按钮（上游 FAB：56vp、边距 16vp、右下角；多选时隐藏）
      if (!this.selectMode) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(DesignTokens.ICON_XL)
            .fontColor([$r('app.color.on_primary')])
        }
        .width(56)
        .height(56)
        .backgroundColor($r('app.color.primary'))
        .shadow({ radius: 12, color: '#33000000', offsetY: 4 })
        .margin(DesignTokens.PAGE_MARGIN)
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddFeedPage' });
        })
      }

      // 底部浮动多选菜单（上游 FloatingSelectMenu）
      if (this.selectMode) {
        this.floatingSelectMenu()
      }

      if (this.showFilterSheet) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              this.showFilterSheet = false;
            })
          this.filterSheet()
        }
        .width('100%')
        .height('100%')
      }

      if (this.showSortDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showSortDialog = false;
          })
          this.choiceDialog($r('app.string.feed_sort'), this.sortOptions(), this.feedOrder, (id: number) => {
            this.feedOrder = id;
            UserPreferences.setFeedOrder(id);
            this.showSortDialog = false;
            this.reloadSorted();
          }, () => {
            this.showSortDialog = false;
          })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showCounterDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showCounterDialog = false;
          })
          this.choiceDialog($r('app.string.subscriptions_counter'), this.counterOptions(), this.counterMode,
            (id: number) => {
              this.counterMode = id;
              UserPreferences.setSubscriptionCounter(id);
              this.showCounterDialog = false;
              this.reloadSorted();
            }, () => {
              this.showCounterDialog = false;
            })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showColumnsDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showColumnsDialog = false;
          })
          this.choiceDialog($r('app.string.subscriptions_count_columns'), this.columnOptions(), this.columns,
            (id: number) => {
              this.showColumnsDialog = false;
              this.setColumns(id);
            }, () => {
              this.showColumnsDialog = false;
            })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showTagMenu) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showTagMenu = false;
          })
          this.tagMenuDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.showTagRenameDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showTagRenameDialog = false;
          })
          this.tagRenameDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.showTagDeleteDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showTagDeleteDialog = false;
          })
          this.tagDeleteDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.showTagsSheet) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              this.showTagsSheet = false;
            })
          this.tagsSheet()
        }
        .width('100%')
        .height('100%')
      }

      if (this.showKeepUpdatedDialog || this.showNotificationDialog || this.showAutoDownloadDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.closeSwitchDialogs();
          })
          this.switchDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.showAutoDeleteDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showAutoDeleteDialog = false;
          })
          this.choiceDialog($r('app.string.setting_auto_delete'), this.autoDeleteOptions(),
            this.selectedFeeds().length > 0 ? this.selectedFeeds()[0].autoDeleteAction : AutoDeleteAction.GLOBAL_DEFAULT,
            (id: number) => {
              this.showAutoDeleteDialog = false;
              this.applyToSelected((feed: Feed) => {
                feed.autoDeleteAction = id;
              });
            }, () => {
              this.showAutoDeleteDialog = false;
            })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showSpeedDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showSpeedDialog = false;
          })
          this.choiceDialog($r('app.string.setting_playback_speed'), this.speedOptions(),
            this.selectedFeeds().length > 0 ? this.selectedFeeds()[0].feedPlaybackSpeed : 0,
            (id: number) => {
              this.showSpeedDialog = false;
              this.applyToSelected((feed: Feed) => {
                feed.feedPlaybackSpeed = id;
              });
            }, () => {
              this.showSpeedDialog = false;
            })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showUnsubscribeDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showUnsubscribeDialog = false;
          })
          this.confirmDialog($r('app.string.feed_unsubscribe'), $r('app.string.feed_unsubscribe_confirm'),
            $r('app.string.feed_unsubscribe'), () => {
              this.showUnsubscribeDialog = false;
              this.unsubscribeSelected();
            }, () => {
              this.showUnsubscribeDialog = false;
            })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showRemoveInboxDialog) {
        Stack({ alignContent: Alignment.Center }) {
          this.scrim(() => {
            this.showRemoveInboxDialog = false;
          })
          this.confirmDialog($r('app.string.remove_all_inbox_label'),
            $r('app.string.remove_all_inbox_confirmation_msg'), $r('app.string.confirm_label'), () => {
              this.showRemoveInboxDialog = false;
              this.removeSelectedFromInbox();
            }, () => {
              this.showRemoveInboxDialog = false;
            })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, ratio: number) => {
      // 从单集页/订阅设置返回时重新读库：上游 SubscriptionFragment.onStart 每次都会 loadSubscriptionsAndTags()，
      // 只靠事件订阅会漏掉「事件发出时本页不可见」的那一类变更。
      if (isVisible && ratio > 0) {
        this.loadFeeds();
      }
    })
  }

  // ───────────────────────────── 外壳 ─────────────────────────────

  /** 标题栏：大标题 + 搜索 + 刷新 + 溢出菜单 */
  @Builder
  titleBar() {
    Row({ space: DesignTokens.SPACE_XS }) {
      Text($r('app.string.tab_subscriptions'))
        .fontSize(DesignTokens.FONT_TITLE1)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      AppIconButton({
        symbol: $r('sys.symbol.magnifyingglass'),
        onTap: () => {
          router.pushUrl({ url: 'pages/SearchPage', params: { term: '' } });
        }
      })
      AppIconButton({
        symbol: $r('sys.symbol.arrow_clockwise'),
        onTap: () => {
          this.refreshAll();
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

  /** 多选态标题栏（上游 ActionMode：标题 "N/M selected" + 溢出菜单 + 关闭） */
  @Builder
  selectHeader() {
    Row({ space: DesignTokens.SPACE_XS }) {
      Text($r('app.string.subscriptions_selected_count', this.selectedIds.length.toString(),
        this.filtered.length.toString()))
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

  /** 标签筛选胶囊行（上游 tags_recycler：左右 12vp、4vp 间距、多选时不可见） */
  @Builder
  tagRow() {
    List({ space: DesignTokens.SPACE_XS, scroller: this.tagScroller }) {
      ForEach(this.tagEntries(), (entry: TagEntry) => {
        ListItem() {
          Column() {
            TagChip({
              label: entry.label,
              selected: this.activeTag === entry.value,
              onTap: () => {
                // 长按弹出标签菜单时吞掉紧随其后的点击（同一次手势会同时触发 onAction 与 onClick）
                if (Date.now() - this.longPressAt < 800) {
                  return;
                }
                this.selectTag(entry.value);
              }
            })
          }
          .gesture(LongPressGesture().onAction(() => {
            this.openTagMenu(entry.value);
          }))
        }
      }, (entry: TagEntry) => entry.key)
    }
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    // 横向 List 在纵向 Column 里会撑满剩余高度，把后面的列表挤成 0 高，故显式给出行高。
    .height(44)
    .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_S })
    .visibility(this.selectMode ? Visibility.Hidden : Visibility.Visible)
  }

  /**
   * 「已过滤」提示行：选中标签时点击清除标签（本移植版既有行为）；
   * 仅全局过滤器生效时点击打开过滤器弹层（上游 feedsFilteredMsg 的行为）。
   */
  @Builder
  filteredRow() {
    Row({ space: DesignTokens.SPACE_XS }) {
      SymbolGlyph($r('sys.symbol.funnel'))
        .fontSize(DesignTokens.ICON_XS)
        .fontColor([$r('app.color.primary')])
      Text($r('app.string.subscriptions_filtered'))
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.primary'))
    }
    .width('100%')
    .padding({
      left: DesignTokens.PAGE_MARGIN,
      right: DesignTokens.PAGE_MARGIN,
      top: DesignTokens.SPACE_XS,
      bottom: DesignTokens.SPACE_XS
    })
    .visibility(this.selectMode ? Visibility.Hidden : Visibility.Visible)
    .onClick(() => {
      if (this.activeTag !== '') {
        this.selectTag('');
        return;
      }
      this.showFilterSheet = true;
    })
  }

  /** 溢出菜单（上游 subscriptions.xml：过滤 / 排序 / 计数 / 每行列数 / 显示标题） */
  @Builder
  overflowMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.funnel')), content: $r('app.string.feed_filter') })
        .onClick(() => {
          this.showFilterSheet = true;
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.sort')), content: $r('app.string.feed_sort') })
        .onClick(() => {
          this.showSortDialog = true;
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.list_bullet')), content: $r('app.string.subscriptions_counter') })
        .onClick(() => {
          this.showCounterDialog = true;
        })
      // 每行列数：上游是带 5 个单选项的二级菜单（「列表 / 2 / 3 / 4 / 5」）
      MenuItem({
        symbolStartIcon: menuIcon($r('sys.symbol.grid')),
        content: $r('app.string.subscriptions_count_columns'),
        builder: () => {
          this.columnsSubMenu();
        }
      })
      // 「显示标题」是勾选项，且列数 = 1（列表模式）时隐藏（上游 refreshToolbarState）
      if (this.columns > 1) {
        MenuItem({
          symbolStartIcon: menuIcon($r('sys.symbol.textformat')),
          content: $r('app.string.subscriptions_show_titles'),
          labelInfo: this.showTitles ? '✓' : ''
        })
          .onClick(() => {
            this.showTitles = !this.showTitles;
            UserPreferences.setSubscriptionShowTitles(this.showTitles);
            this.refreshAllRows();
          })
      }
    }
  }

  /** 每行列数二级菜单（上游 subscription_num_columns 的 checkableBehavior=single 分组） */
  @Builder
  columnsSubMenu() {
    Menu() {
      ForEach(this.columnOptions(), (option: ChoiceOption) => {
        MenuItem({
          content: option.label,
          labelInfo: this.columns === option.id ? '✓' : ''
        })
          .onClick(() => {
            this.setColumns(option.id);
          })
      }, (option: ChoiceOption) => 'col-' + option.id)
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
      MenuItem({
        symbolStartIcon: menuIcon($r('sys.symbol.arrow_up')),
        content: $r('app.string.queue_select_all_above')
      })
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

  /** 底部浮动多选菜单（上游 FloatingSelectMenu：112vp 卡片 + 横向滚动动作） */
  @Builder
  floatingSelectMenu() {
    Row() {
      Scroll() {
        Row({ space: DesignTokens.SPACE_XS }) {
          ForEach(this.menuItems(), (entry: SelectAction) => {
            this.selectAction(entry);
          }, (entry: SelectAction) => entry.id)
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
  selectAction(entry: SelectAction) {
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
    .padding({
      left: DesignTokens.SPACE_XS,
      right: DesignTokens.SPACE_XS,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_S
    })
    .onClick(() => {
      this.runAction(entry.id);
    })
  }

  // ───────────────────────────── 瓦片 / 行 ─────────────────────────────

  /**
   * 网格瓦片（上游 subscription_grid_item）：封面 1:1、圆角 12vp、
   * 计数胶囊在封面右上角、刷新失败图标贴封面右下角；
   * 多选时封面顶部叠 48vp 渐变遮罩 + 左上角勾选圈，选中卡片内缩 12vp。
   */
  @Builder
  gridTile(feed: Feed) {
    Column({ space: DesignTokens.SPACE_XS }) {
      Stack() {
        FeedCover({
          imageUrl: feed.imageUrl,
          fill: true,
          radius: DesignTokens.RADIUS_ROW,
          fallbackTitle: this.showTitles ? '' : feed.getTitle(),
          placeholderColor: $r('app.color.cover_placeholder')
        })

        // 顶部渐变遮罩（上游 gradientOverlay：48dp、alpha 0.4，仅多选态显示）
        if (this.selectMode) {
          Column() {
            Column()
              .width('100%')
              .height(48)
              .linearGradient({
                angle: 180,
                colors: [['#66000000', 0.0], ['#00000000', 1.0]]
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .borderRadius({ topLeft: DesignTokens.RADIUS_ROW, topRight: DesignTokens.RADIUS_ROW })
          .clip(true)
        }

        // 刷新失败图标：贴封面右下角（上游 alignParentEnd + alignBottom=coverImage、margin 8dp）
        if (feed.lastUpdateFailed) {
          Column() {
            SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
              .fontSize(DesignTokens.ICON_XL)
              .fontColor([$r('app.color.error')])
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.End)
          .padding(DesignTokens.SPACE_S)
        }

        // 多选勾选圈（上游 selectedIcon：32dp、左上角、margin 4dp）
        if (this.selectMode) {
          Column() {
            SymbolGlyph(this.selectedIds.includes(feed.id)
              ? $r('sys.symbol.checkmark_circle_fill')
              : $r('sys.symbol.circle'))
              .fontSize(32)
              .fontColor([this.selectedIds.includes(feed.id) ? $r('app.color.primary') : Color.White])
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding(DesignTokens.SPACE_XS)
        }

        // 计数胶囊（上游 countViewPill，多选时隐藏）
        if (!this.selectMode && this.counterValue(feed) > 0) {
          Column() {
            Text(SubscriptionsPage.formatCount(this.counterValue(feed)))
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.pill_on_cover'))
              .borderRadius(18)
              .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.End)
          .padding(DesignTokens.SPACE_S)
        }
      }
      .width('100%')
      .aspectRatio(1)

      if (this.showTitles) {
        Text(feed.getTitle())
          .width('100%')
          .fontSize(this.tileTitleSize())
          .lineHeight(this.tileTitleSize() * 1.4)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          // 上游 titleLabel 是 android:lines="2"：固定两行高，同排瓦片等高
          .constraintSize({ minHeight: this.tileTitleSize() * 1.4 * 2 })
          .padding({ left: this.tileTextPadding(), right: this.tileTextPadding() })
      }
    }
    .width('100%')
    .padding(this.selectMode && this.selectedIds.includes(feed.id) ? 12 : DesignTokens.SPACE_XS)
    .onClick(() => {
      if (this.selectMode) {
        this.toggleSelected(feed.id);
        return;
      }
      router.pushUrl({ url: 'pages/FeedDetailPage', params: { feedId: feed.id } });
    })
    .gesture(LongPressGesture().onAction(() => {
      this.enterSelectMode(feed.id);
    }))
  }

  /** 列表模式行（上游 subscription_list_item：56vp 封面 + 标题 + 计数） */
  @Builder
  listRow(feed: Feed) {
    Row({ space: DesignTokens.SPACE_S }) {
      if (this.selectMode) {
        SymbolGlyph(this.selectedIds.includes(feed.id)
          ? $r('sys.symbol.checkmark_circle_fill')
          : $r('sys.symbol.circle'))
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([this.selectedIds.includes(feed.id) ? $r('app.color.primary') : $r('app.color.text_tertiary')])
      }
      FeedCover({
        imageUrl: feed.imageUrl,
        coverSize: DesignTokens.COVER_LIST,
        radius: DesignTokens.RADIUS_ROW,
        fallbackTitle: feed.getTitle(),
        placeholderColor: $r('app.color.cover_placeholder')
      })
      Text(feed.getTitle())
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (!this.selectMode && this.counterValue(feed) > 0) {
        Text(SubscriptionsPage.formatCount(this.counterValue(feed)))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_tertiary'))
      }
      if (feed.lastUpdateFailed) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([$r('app.color.error')])
      }
    }
    .width('100%')
    .padding({ top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_S })
    .backgroundColor(this.selectMode && this.selectedIds.includes(feed.id)
      ? $r('app.color.primary_container') : Color.Transparent)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.selectMode) {
        this.toggleSelected(feed.id);
        return;
      }
      router.pushUrl({ url: 'pages/FeedDetailPage', params: { feedId: feed.id } });
    })
    .gesture(LongPressGesture().onAction(() => {
      this.enterSelectMode(feed.id);
    }))
  }

  // ───────────────────────────── 弹层 ─────────────────────────────

  /** 半透明遮罩（点外部关闭，对应上游 BottomSheetDialog / AlertDialog 的取消） */
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

  /** 居中单选对话框（上游 FeedSortDialog / FeedCounterDialog 的 MaterialAlertDialog 形态） */
  @Builder
  choiceDialog(title: ResourceStr, options: ChoiceOption[], selectedId: number,
               onPick: (id: number) => void, onCancel: () => void) {
    Column({ space: DesignTokens.SPACE_XS }) {
      Text(title)
        .fontSize(DesignTokens.FONT_TITLE3)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: DesignTokens.SPACE_XXL, right: DesignTokens.SPACE_XXL, top: DesignTokens.SPACE_XL })
      ForEach(options, (option: ChoiceOption) => {
        Row({ space: DesignTokens.SPACE_S }) {
          SymbolGlyph(selectedId === option.id ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
            .fontSize(DesignTokens.ICON_L)
            .fontColor([selectedId === option.id ? $r('app.color.primary') : $r('app.color.text_tertiary')])
          Text(option.label)
            .fontSize(DesignTokens.FONT_SUBTITLE)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .padding({ left: DesignTokens.SPACE_XXL, right: DesignTokens.SPACE_XXL })
        .onClick(() => {
          onPick(option.id);
        })
      }, (option: ChoiceOption) => 'opt-' + option.id)
      Row() {
        Text($r('app.string.dialog_cancel'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            onCancel();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: DesignTokens.SPACE_M, top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_S })
    }
    .width('82%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_CARD)
    .padding({ bottom: DesignTokens.SPACE_XS })
  }

  /** 二次确认对话框（上游 ConfirmationDialog） */
  @Builder
  confirmDialog(title: ResourceStr, body: ResourceStr, confirmLabel: ResourceStr,
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
        Text($r('app.string.dialog_cancel'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            onCancel();
          })
        Text(confirmLabel)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.error'))
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

  /** 长按标签胶囊的菜单（上游 nav_folder_context：重命名 / 删除） */
  @Builder
  tagMenuDialog() {
    Column({ space: DesignTokens.SPACE_XS }) {
      Row({ space: DesignTokens.SPACE_S }) {
        SymbolGlyph($r('sys.symbol.square_and_pencil'))
          .fontSize(DesignTokens.ICON_M)
          .fontColor([$r('app.color.text_secondary')])
        Text($r('app.string.tag_rename_title'))
          .fontSize(DesignTokens.FONT_SUBTITLE)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ minHeight: 48 })
      .padding({ left: DesignTokens.SPACE_XL, right: DesignTokens.SPACE_XL })
      .onClick(() => {
        this.showTagMenu = false;
        this.renameTagValue = this.menuTag;
        this.showTagRenameDialog = true;
      })
      Row({ space: DesignTokens.SPACE_S }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(DesignTokens.ICON_M)
          .fontColor([$r('app.color.error')])
        Text($r('app.string.tag_delete_title'))
          .fontSize(DesignTokens.FONT_SUBTITLE)
          .fontColor($r('app.color.error'))
          .layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ minHeight: 48 })
      .padding({ left: DesignTokens.SPACE_XL, right: DesignTokens.SPACE_XL })
      .onClick(() => {
        this.showTagMenu = false;
        this.showTagDeleteDialog = true;
      })
      Row() {
        Text($r('app.string.dialog_cancel'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            this.showTagMenu = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: DesignTokens.SPACE_S })
    }
    .width('82%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(DesignTokens.RADIUS_CARD)
    .padding({ top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_XS })
  }

  /** 标签重命名对话框 */
  @Builder
  tagRenameDialog() {
    Column({ space: DesignTokens.SPACE_L }) {
      Text($r('app.string.tag_rename_title'))
        .fontSize(DesignTokens.FONT_TITLE3)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      TextInput({ text: this.renameTagValue, placeholder: $r('app.string.tag_name_hint') })
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .backgroundColor($r('app.color.surface_secondary'))
        .onChange((text: string) => {
          this.renameTagValue = text;
        })
      Row({ space: DesignTokens.SPACE_M }) {
        Text($r('app.string.dialog_cancel'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            this.showTagRenameDialog = false;
          })
        Text($r('app.string.confirm_label'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            this.confirmRenameTag();
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

  /** 删除标签确认框（上游 ConfirmationDialog + delete_tag_confirmation） */
  @Builder
  tagDeleteDialog() {
    this.confirmDialog($r('app.string.tag_delete_title'),
      $r('app.string.tag_delete_confirm', this.menuTag), $r('app.string.tag_delete_title'), () => {
        this.showTagDeleteDialog = false;
        this.confirmDeleteTag();
      }, () => {
        this.showTagDeleteDialog = false;
      })
  }

  /** 编辑标签弹层（上游 TagSettingsDialog：可移除已有标签 + 输入新标签，支持批量） */
  @Builder
  tagsSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      Text($r('app.string.setting_edit_tags'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .padding({ top: DesignTokens.SPACE_L })
      if (this.tagEditValues.length === 0) {
        Text($r('app.string.setting_not_set'))
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .padding({ left: DesignTokens.PAGE_MARGIN })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tagEditValues, (tag: string) => {
            Row({ space: DesignTokens.SPACE_XS }) {
              Text(tag)
                .fontSize(DesignTokens.FONT_FOOTNOTE)
                .fontColor($r('app.color.text_primary'))
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(DesignTokens.ICON_XS)
                .fontColor([$r('app.color.text_secondary')])
            }
            .padding({
              left: DesignTokens.SPACE_M,
              right: DesignTokens.SPACE_M,
              top: DesignTokens.SPACE_S,
              bottom: DesignTokens.SPACE_S
            })
            .margin(DesignTokens.SPACE_XS)
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(DesignTokens.RADIUS_CHIP)
            .onClick(() => {
              this.tagEditValues = this.tagEditValues.filter((item: string) => item !== tag);
            })
          }, (tag: string) => 'edit-' + tag)
        }
        .width('100%')
        .padding({ left: DesignTokens.SPACE_L, right: DesignTokens.SPACE_L })
      }
      Row({ space: DesignTokens.SPACE_S }) {
        TextInput({ text: this.newTagText, placeholder: $r('app.string.tags_new_hint') })
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.surface_secondary'))
          .onChange((text: string) => {
            this.newTagText = text;
          })
        Button($r('app.string.tags_add'))
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.primary_container'))
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            this.addTagToEdit();
          })
      }
      .width('100%')
      .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showTagsSheet = false;
          })
        Button($r('app.string.confirm_label'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            this.showTagsSheet = false;
            this.applyTagsToSelected();
          })
      }
      .width('100%')
      .padding(DesignTokens.PAGE_MARGIN)
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  /** Toggle 型弹层（上游 PreferenceSwitchDialog：保持更新 / 新单集通知 / 自动下载） */
  @Builder
  switchDialog() {
    Column({ space: DesignTokens.SPACE_L }) {
      Text(this.switchDialogTitle())
        .fontSize(DesignTokens.FONT_TITLE3)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.dialogSwitch })
          .selectedColor($r('app.color.primary'))
          .onChange((isOn: boolean) => {
            this.dialogSwitch = isOn;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      Row({ space: DesignTokens.SPACE_M }) {
        Text($r('app.string.dialog_cancel'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            this.closeSwitchDialogs();
          })
        Text($r('app.string.confirm_label'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding(DesignTokens.SPACE_M)
          .onClick(() => {
            this.confirmSwitchDialog();
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

  /** 过滤弹层（对照上游 SubscriptionsFilterDialog：4 组，每组最多选一个，跨组为「与」） */
  @Builder
  filterSheet() {
    Column({ space: 2 }) {
      Text($r('app.string.feed_filter'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .padding(DesignTokens.SPACE_L)
      ForEach(this.filterGroups(), (group: FilterGroup) => {
        Column({ space: DesignTokens.SPACE_XS }) {
          ForEach(group.options, (option: FilterOption) => {
            this.filterOptionRow(group.key, option)
          }, (option: FilterOption) => group.key + '-' + option.id)
        }
        .width('100%')
        .padding({ left: DesignTokens.SPACE_L, right: DesignTokens.SPACE_L, top: DesignTokens.SPACE_XS })
      }, (group: FilterGroup) => group.key)
      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .onClick(() => {
            this.showFilterSheet = false;
          })
        Button($r('app.string.filter_reset'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .onClick(() => {
            this.filterValues = '';
            UserPreferences.setSubscriptionsFilter('');
            this.applyFilter();
          })
      }
      .width('100%')
      .padding(DesignTokens.PAGE_MARGIN)
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  /** 单个过滤选项行（选中态用品牌色勾选图标，同组互斥） */
  @Builder
  filterOptionRow(groupKey: string, option: FilterOption) {
    Row({ space: DesignTokens.SPACE_S }) {
      SymbolGlyph(this.isFilterSelected(option.id) ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
        .fontSize(DesignTokens.ICON_L)
        .fontColor([this.isFilterSelected(option.id) ? $r('app.color.primary') : $r('app.color.text_tertiary')])
      Text(option.label)
        .fontSize(DesignTokens.FONT_SUBTITLE)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .onClick(() => {
      this.toggleFilter(groupKey, option.id);
    })
  }

  // ───────────────────────────── 数据 ─────────────────────────────

  aboutToAppear(): void {
    this.columns = UserPreferences.getSubscriptionColumns();
    this.showTitles = UserPreferences.getSubscriptionShowTitles();
    this.filterValues = UserPreferences.getSubscriptionsFilter();
    this.feedOrder = UserPreferences.getFeedOrder();
    this.counterMode = UserPreferences.getSubscriptionCounter();
    this.activeTag = UserPreferences.getSubscriptionLastTag();
    this.refreshing = RefreshService.isRunning();
    this.loadFeeds();
    this.feedToken = EventHub.subscribe(EventType.FEED_LIST_UPDATE, () => {
      this.loadFeeds();
    });
    // 上游 FeedItemEvent.unreadStatusChanged：别处标记已播/未播后，计数胶囊与排序立即刷新
    this.itemToken = EventHub.subscribe(EventType.FEED_ITEM_UPDATE, (data: object) => {
      const update: FeedItemUpdateData = data as FeedItemUpdateData;
      if (update !== undefined) {
        this.loadFeeds();
      }
    });
    // 上游 sticky FeedUpdateRunningEvent：任何入口发起的整库刷新都驱动下拉指示
    this.refreshToken = EventHub.subscribe(EventType.REFRESH_STATE, (data: object) => {
      const state: RefreshStateData = data as RefreshStateData;
      if (state !== undefined) {
        this.refreshing = state.running;
      }
    });
  }

  aboutToDisappear(): void {
    if (this.feedToken >= 0) {
      EventHub.unsubscribeToken(this.feedToken);
      this.feedToken = -1;
    }
    if (this.itemToken >= 0) {
      EventHub.unsubscribeToken(this.itemToken);
      this.itemToken = -1;
    }
    if (this.refreshToken >= 0) {
      EventHub.unsubscribeToken(this.refreshToken);
      this.refreshToken = -1;
    }
    UserPreferences.setSubscriptionLastTag(this.activeTag);
  }

  async loadFeeds(): Promise<void> {
    // onVisibleAreaChange([0.0, 1.0]) 进入页面时会连续回调（跨 0.0 与跨 1.0 各一次），
    // 用序号只认最后一次结果；配合 applyFilter 的内容指纹，重复重查不会重建瓦片。
    const seq: number = ++this.loadSeq;
    // 只在「屏幕上还没有内容」时才切整页转圈：build 里的 if/else 是结构分支，
    // 切到 LoadingProgress 会销毁整屏瓦片（以及每个瓦片里已就绪的封面），
    // 于是每次重查库（进入页面时 onVisibleAreaChange 必发）都整屏闪一下。
    if (this.feeds.length === 0) {
      this.loading = true;
    }
    try {
      const feeds: Feed[] = await FeedRepository.listSubscribed();
      const counters: Map<number, FeedCounter> = await EpisodeRepository.listFeedCounters();
      const recentDates: Map<number, number> = await EpisodeRepository.listMostRecentPubDates();
      if (seq !== this.loadSeq) {
        return;
      }
      for (const feed of feeds) {
        const counter: FeedCounter | undefined = counters.get(feed.id);
        feed.newCount = counter !== undefined ? counter.newCount : 0;
        feed.unplayedCount = counter !== undefined ? counter.unplayed : 0;
        feed.downloadedCount = counter !== undefined ? counter.downloaded : 0;
        feed.downloadedUnplayedCount = counter !== undefined ? counter.downloadedUnplayed : 0;
        feed.playedCount = counter !== undefined ? counter.played : 0;
      }
      const tagState: FeedTagState = await FeedRepository.listTagState();
      if (seq !== this.loadSeq) {
        return;
      }
      this.tagNames = tagState.names;
      this.hasUntagged = tagState.hasUntagged;
      this.recentPubDates = recentDates;
      this.feeds = this.sortFeeds(feeds);
      this.validateActiveTag();
      // 滚动位置快照必须在 applyFilter() **之前**取：setData 之后 onScrollIndex 会以 first=0 回调，
      // 把 SubscriptionsScroll.firstIndex 冲掉（原先在三次 await 之前取，读到的是过期位置）。
      const keepIndex: number = SubscriptionsScroll.firstIndex;
      // applyFilter 返回「是否整表重建」：只有真的 setData 过（onDataReloaded 会把列表拉回顶部）
      // 才需要显式恢复位置；走增量刷新的路径不该动滚动。
      const rebuilt: boolean = this.applyFilter();
      this.centerSelectedTag();
      if (rebuilt) {
        this.restoreScroll(keepIndex);
      }
    } catch (error) {
      this.feeds = [];
      this.filtered = [];
      this.listSignature = '';
      this.listOrderSignature = '';
      this.pendingScrollIndex = -1;
      this.dataSource.setData([]);
    } finally {
      // 被更新的加载取代时不碰 loading/refreshing，交给那一次收尾
      if (seq === this.loadSeq) {
        this.loading = false;
        this.refreshing = RefreshService.isRunning();
      }
    }
  }

  /** 最近更新排序用的最新单集发布时间（上游 getMostRecentItemDates：MAX(pubdate) GROUP BY feed） */
  private recentPubDates: Map<number, number> = new Map<number, number>();

  /** 排序（对照上游 DBReader.getNavDrawerData 的 comparator，并列时按标题忽略大小写） */
  private sortFeeds(feeds: Feed[]): Feed[] {
    const sorted: Feed[] = feeds.slice();
    const byTitle: (a: Feed, b: Feed) => number = (a: Feed, b: Feed): number => {
      return a.getTitle().toLowerCase().localeCompare(b.getTitle().toLowerCase());
    };
    if (this.feedOrder === FEED_ORDER_ALPHABETICAL) {
      sorted.sort(byTitle);
    } else if (this.feedOrder === FEED_ORDER_LAST_UPDATE) {
      sorted.sort((a: Feed, b: Feed): number => {
        const dateA: number | undefined = this.recentPubDates.get(a.id);
        const dateB: number | undefined = this.recentPubDates.get(b.id);
        const diff: number = (dateB !== undefined ? dateB : 0) - (dateA !== undefined ? dateA : 0);
        return diff !== 0 ? diff : byTitle(a, b);
      });
    } else if (this.feedOrder === FEED_ORDER_MOST_PLAYED) {
      sorted.sort((a: Feed, b: Feed): number => {
        const diff: number = b.playedCount - a.playedCount;
        return diff !== 0 ? diff : byTitle(a, b);
      });
    } else {
      // 上游 COUNTER：按当前计数口径算出的计数降序
      sorted.sort((a: Feed, b: Feed): number => {
        const diff: number = this.counterValue(b) - this.counterValue(a);
        return diff !== 0 ? diff : byTitle(a, b);
      });
    }
    return sorted;
  }

  /** 计数/排序口径变化后重新排序并重建列表 */
  private reloadSorted(): void {
    this.feeds = this.sortFeeds(this.feeds);
    this.applyFilter();
  }

  private columnsTemplate(): string {
    let template: string = '';
    for (let i: number = 0; i < this.columns; i++) {
      template += (i === 0 ? '1fr' : ' 1fr');
    }
    return template;
  }

  private setColumns(value: number): void {
    this.columns = value;
    UserPreferences.setSubscriptionColumns(value);
    this.applyFilter();
  }

  /** 瓦片标题字号（上游 SubscriptionViewHolder：2 列 16sp、3 列 15sp、其余 14sp） */
  private tileTitleSize(): number {
    if (this.columns === 2) {
      return 16;
    }
    if (this.columns === 3) {
      return 15;
    }
    return 14;
  }

  /** 瓦片文字内边距（上游：列数 ≤3 → 16dp，4–5 列 → 8dp） */
  private tileTextPadding(): number {
    return this.columns <= 3 ? 16 : 8;
  }

  /** 计数口径循环（上游 FeedCounterDialog：收件箱 / 未播放 / 已下载 / 已下载未播放 / 不显示） */
  private counterValue(feed: Feed): number {
    if (this.counterMode === COUNTER_INBOX) {
      return feed.newCount;
    }
    if (this.counterMode === COUNTER_UNPLAYED) {
      return feed.unplayedCount;
    }
    if (this.counterMode === COUNTER_DOWNLOADED) {
      return feed.downloadedCount;
    }
    if (this.counterMode === COUNTER_DOWNLOADED_UNPLAYED) {
      return feed.downloadedUnplayedCount;
    }
    return 0;
  }

  /** 计数显示（上游 NumberFormat.getInstance()：千分位本地化） */
  private static formatCount(value: number): string {
    const text: string = value.toString();
    if (text.length <= 3) {
      return text;
    }
    const first: number = text.length % 3;
    let out: string = '';
    for (let i: number = 0; i < text.length; i++) {
      if (i > 0 && i >= first && (i - first) % 3 === 0) {
        out += ',';
      }
      out += text.charAt(i);
    }
    return out;
  }

  private sortOptions(): ChoiceOption[] {
    return [
      { id: FEED_ORDER_COUNTER, label: $r('app.string.feed_order_unplayed') },
      { id: FEED_ORDER_ALPHABETICAL, label: $r('app.string.feed_order_alphabetical') },
      { id: FEED_ORDER_LAST_UPDATE, label: $r('app.string.feed_order_last_update') },
      { id: FEED_ORDER_MOST_PLAYED, label: $r('app.string.feed_order_most_played') }
    ];
  }

  private counterOptions(): ChoiceOption[] {
    return [
      { id: COUNTER_INBOX, label: $r('app.string.subscriptions_counter_inbox') },
      { id: COUNTER_UNPLAYED, label: $r('app.string.subscriptions_counter_unplayed') },
      { id: COUNTER_DOWNLOADED, label: $r('app.string.subscriptions_counter_downloaded') },
      { id: COUNTER_DOWNLOADED_UNPLAYED, label: $r('app.string.subscriptions_counter_downloaded_unplayed') },
      { id: COUNTER_NONE, label: $r('app.string.subscriptions_counter_none') }
    ];
  }

  private columnOptions(): ChoiceOption[] {
    return [
      { id: 1, label: $r('app.string.subscriptions_display_list') },
      { id: 2, label: '2' },
      { id: 3, label: '3' },
      { id: 4, label: '4' },
      { id: 5, label: '5' }
    ];
  }

  private autoDeleteOptions(): ChoiceOption[] {
    return [
      { id: AutoDeleteAction.GLOBAL_DEFAULT, label: $r('app.string.autodelete_global') },
      { id: AutoDeleteAction.ALWAYS, label: $r('app.string.autodelete_always') },
      { id: AutoDeleteAction.WHEN_PLAYED, label: $r('app.string.autodelete_when_played') },
      { id: AutoDeleteAction.NEVER, label: $r('app.string.autodelete_never') }
    ];
  }

  /** 播放速度选项：0 = 跟随全局，其余为上游 PresetSeekBar 的预设值 */
  private speedOptions(): ChoiceOption[] {
    const options: ChoiceOption[] = [{ id: 0, label: $r('app.string.playback_speed_global') }];
    for (const speed of PlayerManager.SPEED_PRESETS) {
      options.push({ id: speed, label: speed.toFixed(2) + 'x' });
    }
    return options;
  }

  /** 标签行数据（上游 DBReader.getAllTags：全部 → 命名标签字母序 → 未标记） */
  private tagEntries(): TagEntry[] {
    const entries: TagEntry[] = [{ key: 'all', label: $r('app.string.filter_all'), value: '' }];
    for (const name of this.tagNames) {
      const label: string = name.length > TAG_TITLE_MAX
        ? name.substring(0, TAG_TITLE_MAX - 1) + '…'
        : name;
      entries.push({ key: 'tag-' + name, label: label, value: name });
    }
    if (this.hasUntagged) {
      entries.push({ key: 'untagged', label: $r('app.string.tag_untagged_label'), value: TAG_UNTAGGED });
    }
    return entries;
  }

  /** 标签被删掉 / 订阅变动后回落「全部」（上游 tagExists 判定） */
  private validateActiveTag(): void {
    if (this.activeTag === '') {
      return;
    }
    const exists: boolean = this.activeTag === TAG_UNTAGGED
      ? this.hasUntagged
      : this.tagNames.includes(this.activeTag);
    if (!exists) {
      this.activeTag = '';
      UserPreferences.setSubscriptionLastTag('');
    }
  }

  /** 把选中的标签胶囊滚动到水平居中（上游 tagsRecycler.post 里的 scrollToPositionWithOffset） */
  private centerSelectedTag(): void {
    const entries: TagEntry[] = this.tagEntries();
    let index: number = -1;
    for (let i: number = 0; i < entries.length; i++) {
      if (entries[i].value === this.activeTag) {
        index = i;
        break;
      }
    }
    // 第一个胶囊（「全部」）本来就在最左，无需滚动
    if (index <= 0) {
      return;
    }
    setTimeout(() => {
      this.tagScroller.scrollToIndex(index, true, ScrollAlign.CENTER);
    }, 50);
  }

  /**
   * 恢复滚动位置（上游 SubscriptionFragment 的静态 `scrollPosition` + `restoreScrollPosition`）。
   *
   * 只在**整表重建**后调用（`applyFilter()` 返回 true，即真的走了 `setData()`）：
   * 本移植版订阅页是底栏页签，组件不会被销毁，而 `onDataReloaded()` 会把 List/Grid 拉回顶部 ——
   * 「切到别的页签再切回来」这类重查库需要显式滚回去，上游靠 `notifyDataSetChanged()` 保留位置。
   *
   * 但**用户正在拖动 / 惯性滑动时必须让路**：刷新期间每次 `FEED_LIST_UPDATE` 都会重查库，
   * 若此时硬跳回旧位置，用户感受到的就是「怎么滑都被拽回去」。手势中只登记目标，回到
   * `ScrollState.Idle` 后由 `onListScrollState()` 补做。
   */
  private restoreScroll(index: number): void {
    if (index <= 0 || this.filtered.length === 0) {
      this.pendingScrollIndex = -1;
      return;
    }
    if (SubscriptionsScroll.scrolling) {
      this.pendingScrollIndex = index;
      return;
    }
    this.pendingScrollIndex = -1;
    const target: number = Math.min(index, this.filtered.length - 1);
    setTimeout(() => {
      this.listScroller.scrollToIndex(target, false, ScrollAlign.START);
    }, 50);
  }

  /**
   * List / Grid 滚动状态跟踪（`onDidScroll`，API 12）。
   * 手势结束时补做被推迟的位置恢复，保证「拖动期间不打断、松手后位置仍正确」。
   */
  private onListScrollState(state: ScrollState): void {
    SubscriptionsScroll.scrolling = state !== ScrollState.Idle;
    if (state === ScrollState.Idle && this.pendingScrollIndex >= 0) {
      const target: number = this.pendingScrollIndex;
      this.pendingScrollIndex = -1;
      this.restoreScroll(target);
    }
  }

  /** 选中集合变化后重绘全部可见行（避免 setData 把滚动位置拉回顶部） */
  private refreshAllRows(): void {
    for (let i: number = 0; i < this.filtered.length; i++) {
      this.dataSource.notifyDataChange(i);
    }
  }

  /**
   * 标签 + 全局过滤（上游 tags_recycler + SubscriptionsFilterDialog）。
   * 标签为精确成员判定（拆分逗号并 trim），避免 `Tech` 命中 `Technology`。
   *
   * @returns 是否发生了**整表重建**（`dataSource.setData()`）。调用方据此决定要不要恢复滚动位置。
   */
  applyFilter(): boolean {
    const filters: string[] = this.filterValues === '' ? [] : this.filterValues.split(',');
    const result: Feed[] = this.feeds.filter((feed: Feed) => {
      const tags: string[] = FeedRepository.splitTags(feed.feedTags);
      if (this.activeTag === TAG_UNTAGGED) {
        if (tags.length !== 0) {
          return false;
        }
      } else if (this.activeTag !== '' && !tags.includes(this.activeTag)) {
        return false;
      }
      // 上游 SubscriptionsFilterExecutor：按**当前计数口径**算出的计数 > 0
      if (filters.includes('counter_greater_zero') && this.counterValue(feed) <= 0) {
        return false;
      }
      if (filters.includes('enabled_auto_download') && !feed.autoDownloadEnabled) {
        return false;
      }
      if (filters.includes('disabled_auto_download') && feed.autoDownloadEnabled) {
        return false;
      }
      if (filters.includes('enabled_updates') && !feed.keepUpdated) {
        return false;
      }
      if (filters.includes('disabled_updates') && feed.keepUpdated) {
        return false;
      }
      if (filters.includes('episode_notification_enabled') && !feed.episodeNotification) {
        return false;
      }
      if (filters.includes('episode_notification_disabled') && feed.episodeNotification) {
        return false;
      }
      return true;
    });
    const selectionKept: number[] = this.selectedIds.filter((id: number) =>
      result.some((feed: Feed) => feed.id === id));
    if (selectionKept.length !== this.selectedIds.length) {
      this.selectedIds = selectionKept;
      if (selectionKept.length === 0) {
        this.selectMode = false;
      }
    }
    this.filtered = result;
    const signature: string = SubscriptionsPage.signature(result);
    // 内容（含顺序）完全没变：连行都不用重绘。
    if (signature === this.listSignature) {
      return false;
    }
    const order: string = SubscriptionsPage.orderSignature(result);
    const rows: Feed[] = this.dataSource.getDataArray();
    if (order === this.listOrderSignature && rows.length === result.length) {
      // 「成员 + 顺序」没变，只有行内数据变了 —— 这是刷新时最常见的形态
      //（RefreshService 逐 Feed 广播 FEED_LIST_UPDATE，每次只补一个订阅的计数/封面）。
      // 逐项替换 + notifyDataChange 只重绘变化的行，不会触发 onDataReloaded，
      // 因而**不会把 List/Grid 拉回顶部**；整表 setData 才是「下滑被强制拉回」的根源。
      for (let i: number = 0; i < result.length; i++) {
        if (SubscriptionsPage.itemSignature(rows[i]) !== SubscriptionsPage.itemSignature(result[i])) {
          rows[i] = result[i];
          this.dataSource.notifyDataChange(i);
        }
      }
      this.listSignature = signature;
      return false;
    }
    // 成员或顺序变了（订阅增删、排序/计数口径切换、标签与过滤器生效）：只能整表重建。
    this.listOrderSignature = order;
    this.listSignature = signature;
    this.dataSource.setData(result);
    return true;
  }

  /** 单项指纹：只含瓦片/行渲染会读到的字段（id、标题、封面地址、各计数、刷新失败标记） */
  private static itemSignature(feed: Feed): string {
    return feed.id + '\u0001' + feed.getTitle() + '\u0001' + feed.imageUrl + '\u0001'
      + feed.newCount + '\u0001' + feed.unplayedCount + '\u0001' + feed.downloadedCount + '\u0001'
      + feed.downloadedUnplayedCount + '\u0001' + feed.playedCount + '\u0001'
      + (feed.lastUpdateFailed ? 1 : 0);
  }

  /** 列表内容指纹：各项指纹按顺序拼接 */
  private static signature(list: Feed[]): string {
    let out: string = '';
    for (const feed of list) {
      out += SubscriptionsPage.itemSignature(feed) + '\u0002';
    }
    return out;
  }

  /** 「成员 + 顺序」指纹：相同即可走增量刷新，不必 setData */
  private static orderSignature(list: Feed[]): string {
    let out: string = '';
    for (const feed of list) {
      out += feed.id + '\u0001';
    }
    return out;
  }

  /** 空态说明：上游只看**全局过滤器**是否启用 */
  private emptyHint(): Resource {
    return this.filterValues !== '' ?
      $r('app.string.subscriptions_filtered_hint') : $r('app.string.subscriptions_empty_hint');
  }

  /** 过滤组定义（对照上游 SubscriptionsFilterGroup：4 组、每组 1–2 个选项） */
  filterGroups(): FilterGroup[] {
    return [
      {
        key: 'counter',
        options: [{ id: 'counter_greater_zero', label: $r('app.string.subscriptions_counter_greater_zero') }]
      },
      {
        key: 'autoDownload',
        options: [
          { id: 'enabled_auto_download', label: $r('app.string.auto_downloaded') },
          { id: 'disabled_auto_download', label: $r('app.string.not_auto_downloaded') }
        ]
      },
      {
        key: 'updated',
        options: [
          { id: 'enabled_updates', label: $r('app.string.kept_updated') },
          { id: 'disabled_updates', label: $r('app.string.not_kept_updated') }
        ]
      },
      {
        key: 'notification',
        options: [
          { id: 'episode_notification_enabled', label: $r('app.string.new_episode_notification_enabled') },
          { id: 'episode_notification_disabled', label: $r('app.string.new_episode_notification_disabled') }
        ]
      }
    ];
  }

  isFilterSelected(id: string): boolean {
    return this.filterValues.split(',').includes(id);
  }

  /**
   * 同组互斥的开关：未选中 → 选中（并清掉同组旧值）；已选中 → 取消（上游 MaterialButtonToggleGroup 可再点取消）。
   *
   * 旧实现只做 `without(selected, id)`（纯删除），因此**任何第一次点选都不会生效**，
   * 过滤弹层实际上从来没有过滤过任何订阅。
   */
  toggleFilter(groupKey: string, id: string): void {
    const groups: FilterGroup[] = this.filterGroups();
    const selected: string[] = this.filterValues === '' ? [] : this.filterValues.split(',');
    const group: FilterGroup | undefined = groups.find((item: FilterGroup) => item.key === groupKey);
    const groupIds: string[] = group !== undefined
      ? group.options.map((option: FilterOption) => option.id)
      : [];
    const alreadySelected: boolean = selected.includes(id);
    let next: string[] = selected.filter((value: string) => !groupIds.includes(value));
    if (!alreadySelected) {
      next.push(id);
    }
    this.filterValues = next.join(',');
    UserPreferences.setSubscriptionsFilter(this.filterValues);
    this.applyFilter();
  }

  selectTag(tag: string): void {
    this.activeTag = tag;
    UserPreferences.setSubscriptionLastTag(tag);
    this.applyFilter();
  }

  // ───────────────────────────── 多选 ─────────────────────────────

  /** 长按瓦片进入多选并选中该项（上游 startSelectMode(position)） */
  private enterSelectMode(feedId: number): void {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      this.selectMode = true;
      this.selectedIds = [feedId];
    });
    this.refreshAllRows();
  }

  private exitSelectMode(): void {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      this.selectMode = false;
      this.selectedIds = [];
    });
    this.refreshAllRows();
  }

  /** 选中集合变化（上游 notifyItemChanged：卡片内缩 12dp 用 100ms ValueAnimator） */
  private toggleSelected(feedId: number): void {
    animateTo({ duration: 100, curve: Curve.EaseOut }, () => {
      if (this.selectedIds.includes(feedId)) {
        this.selectedIds = this.selectedIds.filter((id: number) => id !== feedId);
      } else {
        this.selectedIds = this.selectedIds.concat([feedId]);
      }
      if (this.selectedIds.length === 0) {
        this.selectMode = false;
      }
    });
    this.refreshAllRows();
  }

  private allSelected(): boolean {
    return this.filtered.length > 0 && this.selectedIds.length === this.filtered.length;
  }

  private toggleSelectAll(): void {
    if (this.allSelected()) {
      this.selectedIds = [];
      return;
    }
    this.selectedIds = this.filtered.map((feed: Feed) => feed.id);
    this.refreshAllRows();
  }

  /** 向上全选：选中第一项到「第一个已选项」之前（上游 select_all_above） */
  private selectAllAbove(): void {
    let first: number = -1;
    for (let i: number = 0; i < this.filtered.length; i++) {
      if (this.selectedIds.includes(this.filtered[i].id)) {
        first = i;
        break;
      }
    }
    if (first <= 0) {
      return;
    }
    const ids: number[] = this.selectedIds.slice();
    for (let i: number = 0; i < first; i++) {
      if (!ids.includes(this.filtered[i].id)) {
        ids.push(this.filtered[i].id);
      }
    }
    this.selectedIds = ids;
    this.refreshAllRows();
  }

  /** 向下全选：选中「最后一个已选项」之后到末尾（上游 select_all_below） */
  private selectAllBelow(): void {
    let last: number = -1;
    for (let i: number = this.filtered.length - 1; i >= 0; i--) {
      if (this.selectedIds.includes(this.filtered[i].id)) {
        last = i;
        break;
      }
    }
    if (last < 0 || last >= this.filtered.length - 1) {
      return;
    }
    const ids: number[] = this.selectedIds.slice();
    for (let i: number = last + 1; i < this.filtered.length; i++) {
      if (!ids.includes(this.filtered[i].id)) {
        ids.push(this.filtered[i].id);
      }
    }
    this.selectedIds = ids;
    this.refreshAllRows();
  }

  private selectedFeeds(): Feed[] {
    return this.filtered.filter((feed: Feed) => this.selectedIds.includes(feed.id));
  }

  /** 多选动作栏的可见项（对照上游 nav_feed_action_speeddial.xml + FeedMenuHandler.onPrepareMenu） */
  private menuItems(): SelectAction[] {
    const selected: Feed[] = this.selectedFeeds();
    const entries: SelectAction[] = [];
    if (selected.length === 0) {
      return entries;
    }
    // 上游 remove_all_inbox_item：仅当所选全部为已订阅时可见
    const allSubscribed: boolean = selected.every((feed: Feed) => feed.isSubscribed());
    entries.push({
      id: 'EDIT_TAGS',
      label: $r('app.string.setting_edit_tags'),
      icon: $r('sys.symbol.list_bullet'),
      destructive: false
    });
    if (selected.length === 1) {
      entries.push({
        id: 'SHARE',
        label: $r('app.string.subscriptions_share'),
        icon: $r('sys.symbol.share'),
        destructive: false
      });
    }
    if (allSubscribed) {
      entries.push({
        id: 'REMOVE_INBOX',
        label: $r('app.string.remove_all_inbox_label'),
        icon: $r('sys.symbol.checkmark_circle'),
        destructive: false
      });
      entries.push({
        id: 'UNSUBSCRIBE',
        label: $r('app.string.feed_unsubscribe'),
        icon: $r('sys.symbol.trash'),
        destructive: true
      });
    }
    entries.push({
      id: 'KEEP_UPDATED',
      label: $r('app.string.kept_updated'),
      icon: $r('sys.symbol.arrow_clockwise'),
      destructive: false
    });
    entries.push({
      id: 'NOTIFY',
      label: $r('app.string.setting_episode_notification'),
      icon: $r('sys.symbol.bell'),
      destructive: false
    });
    entries.push({
      id: 'AUTODOWNLOAD',
      label: $r('app.string.setting_auto_download'),
      icon: $r('sys.symbol.download_1'),
      destructive: false
    });
    entries.push({
      id: 'AUTODELETE',
      label: $r('app.string.setting_auto_delete'),
      icon: $r('sys.symbol.trash'),
      destructive: false
    });
    entries.push({
      id: 'SPEED',
      label: $r('app.string.setting_playback_speed'),
      icon: $r('sys.symbol.fast'),
      destructive: false
    });
    return entries;
  }

  private runAction(id: string): void {
    const selected: Feed[] = this.selectedFeeds();
    if (selected.length === 0) {
      return;
    }
    if (id === 'EDIT_TAGS') {
      this.openTagsSheet();
      return;
    }
    if (id === 'SHARE') {
      this.shareFeed(selected[0]);
      return;
    }
    if (id === 'REMOVE_INBOX') {
      this.showRemoveInboxDialog = true;
      return;
    }
    if (id === 'UNSUBSCRIBE') {
      this.showUnsubscribeDialog = true;
      return;
    }
    if (id === 'KEEP_UPDATED') {
      this.dialogSwitch = selected[0].keepUpdated;
      this.showKeepUpdatedDialog = true;
      return;
    }
    if (id === 'NOTIFY') {
      this.dialogSwitch = selected[0].episodeNotification;
      this.showNotificationDialog = true;
      return;
    }
    if (id === 'AUTODOWNLOAD') {
      this.dialogSwitch = selected[0].autoDownloadEnabled;
      this.showAutoDownloadDialog = true;
      return;
    }
    if (id === 'AUTODELETE') {
      this.showAutoDeleteDialog = true;
      return;
    }
    if (id === 'SPEED') {
      this.showSpeedDialog = true;
    }
  }

  /** 批量写入每 Feed 偏好（上游 FeedMultiSelectActionHandler.saveFeedPreferences） */
  private async applyToSelected(mutate: (feed: Feed) => void): Promise<void> {
    const selected: Feed[] = this.selectedFeeds();
    for (const feed of selected) {
      mutate(feed);
      await FeedRepository.updatePreferences(feed);
    }
    this.showMessage(getContext(this).resourceManager.getStringSync(
      $r('app.string.updated_feeds_batch'), selected.length.toString()));
    if (selected.length <= 1) {
      this.exitSelectMode();
    }
  }

  private async removeSelectedFromInbox(): Promise<void> {
    const ids: number[] = this.selectedFeeds().map((feed: Feed) => feed.id);
    if (ids.length === 0) {
      return;
    }
    await EpisodeRepository.clearNewFlagsByFeeds(ids);
    this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.removed_all_inbox_msg')));
    this.exitSelectMode();
    await this.loadFeeds();
  }

  private async unsubscribeSelected(): Promise<void> {
    const selected: Feed[] = this.selectedFeeds();
    for (const feed of selected) {
      try {
        await SubscriptionService.unsubscribe(feed.id);
      } catch (error) {
        this.showMessage((error as Error).message);
      }
    }
    this.exitSelectMode();
    await this.loadFeeds();
  }

  /** 分享订阅：复制 RSS 链接（上游 ShareUtils.shareFeedLink；本 SDK 无系统分享面板 API） */
  private async shareFeed(feed: Feed): Promise<void> {
    const link: string = feed.link !== '' ? feed.link : feed.downloadUrl;
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

  // ───────────────────────────── 标签编辑 / 重命名 / 删除 ─────────────────────────────

  /** 打开编辑标签弹层：预填所选订阅的**公共**标签（上游 commonTags） */
  private openTagsSheet(): void {
    const selected: Feed[] = this.selectedFeeds();
    if (selected.length === 0) {
      return;
    }
    let common: string[] = FeedRepository.splitTags(selected[0].feedTags);
    for (const feed of selected) {
      const tags: string[] = FeedRepository.splitTags(feed.feedTags);
      common = common.filter((tag: string) => tags.includes(tag));
    }
    this.tagEditValues = common;
    this.newTagText = '';
    this.showTagsSheet = true;
  }

  private addTagToEdit(): void {
    const value: string = this.newTagText.trim();
    if (value === '' || this.tagEditValues.includes(value)) {
      this.newTagText = '';
      return;
    }
    this.tagEditValues = this.tagEditValues.concat([value]);
    this.newTagText = '';
  }

  /** 确认：把编辑后的标签集合写到所有选中订阅（上游 setTags(displayedTags)） */
  private async applyTagsToSelected(): Promise<void> {
    const selected: Feed[] = this.selectedFeeds();
    const value: string = this.tagEditValues.join(',');
    for (const feed of selected) {
      feed.feedTags = value;
      await FeedRepository.updatePreferences(feed);
    }
    this.showMessage(getContext(this).resourceManager.getStringSync(
      $r('app.string.updated_feeds_batch'), selected.length.toString()));
    if (selected.length <= 1) {
      this.exitSelectMode();
    }
    await this.loadFeeds();
  }

  private openTagMenu(tag: string): void {
    // 「全部」与「未标记」不是真实标签，没有可重命名/删除的对象（上游同样不弹菜单）
    if (tag === '' || tag === TAG_UNTAGGED) {
      return;
    }
    this.longPressAt = Date.now();
    this.menuTag = tag;
    this.showTagMenu = true;
  }

  private async confirmRenameTag(): Promise<void> {
    const next: string = this.renameTagValue.trim();
    this.showTagRenameDialog = false;
    if (next === '' || next === this.menuTag) {
      return;
    }
    await FeedRepository.renameTag(this.menuTag, next);
    if (this.activeTag === this.menuTag) {
      this.selectTag(next);
    }
    await this.loadFeeds();
  }

  private async confirmDeleteTag(): Promise<void> {
    await FeedRepository.deleteTag(this.menuTag);
    if (this.activeTag === this.menuTag) {
      this.selectTag('');
    }
    await this.loadFeeds();
  }

  // ───────────────────────────── Toggle 弹层 ─────────────────────────────

  private switchDialogTitle(): Resource {
    if (this.showKeepUpdatedDialog) {
      return $r('app.string.kept_updated');
    }
    if (this.showNotificationDialog) {
      return $r('app.string.setting_episode_notification');
    }
    return $r('app.string.setting_auto_download');
  }

  private closeSwitchDialogs(): void {
    this.showKeepUpdatedDialog = false;
    this.showNotificationDialog = false;
    this.showAutoDownloadDialog = false;
  }

  private async confirmSwitchDialog(): Promise<void> {
    const value: boolean = this.dialogSwitch;
    const keepUpdated: boolean = this.showKeepUpdatedDialog;
    const notification: boolean = this.showNotificationDialog;
    this.closeSwitchDialogs();
    await this.applyToSelected((feed: Feed) => {
      if (keepUpdated) {
        feed.keepUpdated = value;
      } else if (notification) {
        feed.episodeNotification = value;
      } else {
        feed.autoDownloadEnabled = value;
      }
    });
  }

  // ───────────────────────────── 刷新 ─────────────────────────────

  async refreshAll(): Promise<void> {
    this.refreshing = true;
    this.message = getContext(this).resourceManager.getStringSync($r('app.string.refresh_running'));
    try {
      const added: number = await RefreshService.refreshAll();
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.feed_refresh_done')) + added;
    } catch (error) {
      this.message = (error as Error).message;
    }
    await this.loadFeeds();
  }

  private showMessage(text: string): void {
    this.message = text;
  }
}
