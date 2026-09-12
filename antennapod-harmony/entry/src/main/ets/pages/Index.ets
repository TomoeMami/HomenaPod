import router from '@ohos.router';
import { HomePage } from './HomePage';
import { SubscriptionsPage } from './SubscriptionsPage';
import { QueuePage } from './QueuePage';
import { InboxView } from './InboxView';
import { BottomTabItem } from '../components/BottomTabItem';
import { MiniPlayer } from '../components/MiniPlayer';
import { DesignTokens } from '../common/DesignTokens';
import { menuIcon } from '../common/MenuIcons';
import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { EventHub, EventType } from '../events/EventHub';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';

/**
 * 应用外壳（对齐上游 main.xml + BottomNavigation）：
 * 底部导航固定 4 个页签 + 「更多」溢出菜单（上游把抽屉项前 4 个放进底栏，其余进 More）。
 */
@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State playerStatus: string = PlayerManager.getStatus();
  @State playerTitle: string = '';
  @State playerFeedTitle: string = '';
  /** 迷你播放条封面（当前播放对象的 imageUrl） */
  @State playerImage: string = '';
  @State playerProgress: number = 0;
  @State unreadCount: number = 0;

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          HomePage({
            onNavigate: (target: string) => {
              this.navigate(target);
            }
          })
        }
        .tabBar('')

        TabContent() {
          QueuePage()
        }
        .tabBar('')

        TabContent() {
          InboxView({ asTab: true })
        }
        .tabBar('')

        TabContent() {
          SubscriptionsPage()
        }
        .tabBar('')
      }
      .barHeight(0)
      // 关闭页签之间的左右滑动切换：与列表行的左右滑动手势（收件箱入队/标已播、队列移除/下载）冲突
      .scrollable(false)
      .onChange((index: number) => {
        this.currentTab = index;
        this.refreshCounts();
      })
      .layoutWeight(1)

      // 迷你播放条：有播放任务时常驻于底部导航之上（上游 external_player_height = 64vp）
      MiniPlayer({
        title: this.playerTitle,
        feedTitle: this.playerFeedTitle,
        imageUrl: this.playerImage,
        progress: this.playerProgress,
        playing: this.playerStatus === 'PLAYING',
        show: this.playerStatus === 'PLAYING' || this.playerStatus === 'PAUSED'
          || this.playerStatus === 'PREPARED',
        onToggle: () => {
          if (this.playerStatus === 'PLAYING') {
            PlayerManager.pause();
          } else {
            PlayerManager.play();
          }
          this.playerStatus = PlayerManager.getStatus();
        }
      })

      // 底部导航栏：首页 / 队列 / 收件箱 / 订阅 / 更多（图标 + 文字 + 未读角标）
      Row() {
        BottomTabItem({
          label: $r('app.string.tab_home'),
          icon: $r('sys.symbol.house'),
          iconActive: $r('sys.symbol.house_fill'),
          selected: this.currentTab === 0,
          onTap: () => {
            this.currentTab = 0;
            this.refreshCounts();
          }
        })

        BottomTabItem({
          label: $r('app.string.tab_queue'),
          icon: $r('sys.symbol.music_note_list'),
          iconActive: $r('sys.symbol.music_note_list'),
          selected: this.currentTab === 1,
          onTap: () => {
            this.currentTab = 1;
            this.refreshCounts();
          }
        })

        BottomTabItem({
          label: $r('app.string.inbox_title'),
          icon: $r('sys.symbol.inbox'),
          iconActive: $r('sys.symbol.inbox'),
          selected: this.currentTab === 2,
          badge: this.unreadCount,
          onTap: () => {
            this.currentTab = 2;
            this.refreshCounts();
          }
        })

        BottomTabItem({
          label: $r('app.string.tab_subscriptions'),
          icon: $r('sys.symbol.folder'),
          iconActive: $r('sys.symbol.folder_fill'),
          selected: this.currentTab === 3,
          onTap: () => {
            this.currentTab = 3;
            this.refreshCounts();
          }
        })

        // 「更多」不是页签，点击弹出溢出菜单（上游 bottom_navigation_more）
        Column({ space: 2 }) {
          Stack() {
            SymbolGlyph($r('sys.symbol.more'))
              .fontSize(DesignTokens.ICON_XL)
              .fontColor([$r('app.color.text_tertiary')])
          }
          .width(56)
          .height(30)
          .borderRadius(15)
          .alignContent(Alignment.Center)

          Text($r('app.string.tab_more'))
            .fontSize(DesignTokens.FONT_NAV)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
        }
        .layoutWeight(1)
        .height(DesignTokens.HEIGHT_TAB_BAR)
        .justifyContent(FlexAlign.Center)
        .bindMenu(this.moreMenu)
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .border({ width: { top: 1 }, color: $r('app.color.divider') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  /** 「更多」溢出菜单（上游 BottomNavigation 的 ListPopupWindow 内容） */
  @Builder
  moreMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.list_bullet')), content: $r('app.string.episodes_label') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/EpisodesPage' });
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.download_1')), content: $r('app.string.tab_downloads') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/DownloadsPage' });
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.clock')), content: $r('app.string.more_history') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/HistoryPage' });
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.star')), content: $r('app.string.favorites_title') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/FavoritesPage' });
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.histogram')), content: $r('app.string.more_statistics') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/StatsPage' });
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.plus')), content: $r('app.string.more_add_feed') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddFeedPage' });
        })
      MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.gearshape')), content: $r('app.string.tab_settings') })
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })
    }
  }

  /** 首页区块「更多」跳转：页签直接切换，子页面走路由 */
  navigate(target: string): void {
    if (target === 'queue') {
      this.currentTab = 1;
      return;
    }
    if (target === 'inbox') {
      this.currentTab = 2;
      return;
    }
    if (target === 'subscriptions') {
      this.currentTab = 3;
      return;
    }
    if (target === 'downloads') {
      router.pushUrl({ url: 'pages/DownloadsPage' });
      return;
    }
    // 首页「随机惊喜」的「更多 → Episodes」（上游 AllEpisodesFragment）
    if (target === 'episodes') {
      router.pushUrl({ url: 'pages/EpisodesPage' });
      return;
    }
    if (target === 'search') {
      router.pushUrl({ url: 'pages/SearchPage', params: { term: '' } });
      return;
    }
  }

  aboutToAppear(): void {
    EventHub.subscribe(EventType.PLAYER_STATUS, (data: object) => {
      const record = data as Record<string, string>;
      const status: string | undefined = record['status'];
      if (status !== undefined) {
        this.playerStatus = status;
      }
      this.refreshPlayerTitle();
    });
    EventHub.subscribe(EventType.QUEUE, (data: object) => {
      this.refreshCounts();
    });
    EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.refreshCounts();
    });
    EventHub.subscribe(EventType.FEED_ITEM_UPDATE, (data: object) => {
      this.refreshCounts();
    });
    EventHub.subscribe(EventType.FEED_LIST_UPDATE, (data: object) => {
      this.refreshCounts();
    });
    EventHub.subscribe(EventType.PLAYBACK_POSITION, (data: object) => {
      this.refreshPlayerProgress();
    });
    this.refreshCounts();
    this.refreshPlayerTitle();
  }

  /** 迷你播放条标题/订阅名/封面（PlayerManager 保存当前播放对象） */
  refreshPlayerTitle(): void {
    const current: Playable | undefined = PlayerManager.getCurrent();
    this.playerTitle = current === undefined ? '' : current.title;
    this.playerFeedTitle = current === undefined ? '' : current.feedTitle;
    this.playerImage = current === undefined ? '' : current.imageUrl;
    this.refreshPlayerProgress();
  }

  /** 迷你播放条底部 4vp 进度条（上游 episodeProgress） */
  refreshPlayerProgress(): void {
    const duration: number = PlayerManager.getDuration();
    if (duration <= 0) {
      this.playerProgress = 0;
      return;
    }
    const percent: number = Math.floor(PlayerManager.getCurrentTime() * 100 / duration);
    this.playerProgress = percent > 100 ? 100 : percent;
  }

  /** 刷新底部页签角标：上游只给「收件箱」显示新单集数（read = -1） */
  async refreshCounts(): Promise<void> {
    try {
      this.unreadCount = await EpisodeRepository.countNew();
    } catch (error) {
      this.unreadCount = 0;
    }
  }
}
