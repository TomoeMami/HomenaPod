import { SubscriptionsPage } from './SubscriptionsPage';
import { QueuePage } from './QueuePage';
import { DownloadsPage } from './DownloadsPage';
import { SettingsPage } from './SettingsPage';
import { PlayerManager } from '../player/PlayerManager';
import { EventHub, EventType } from '../events/EventHub';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State playerStatus: string = PlayerManager.getStatus();

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          SubscriptionsPage()
        }
        .tabBar(this.tabItem($r('app.string.tab_subscriptions'), 0))

        TabContent() {
          QueuePage()
        }
        .tabBar(this.tabItem($r('app.string.tab_queue'), 1))

        TabContent() {
          DownloadsPage()
        }
        .tabBar(this.tabItem($r('app.string.tab_downloads'), 2))

        TabContent() {
          SettingsPage()
        }
        .tabBar(this.tabItem($r('app.string.tab_settings'), 3))
      }
      .onChange((index: number) => {
        this.currentTab = index;
      })
      .layoutWeight(1)

      if (this.playerStatus === 'PLAYING' || this.playerStatus === 'PAUSED') {
        Row({ space: 8 }) {
          Text($r('app.string.mini_player'))
          Button(this.playerStatus === 'PLAYING' ? 'Pause' : 'Play')
            .onClick(() => {
              if (this.playerStatus === 'PLAYING') {
                PlayerManager.pause();
                this.playerStatus = PlayerManager.getStatus();
              } else {
                PlayerManager.play();
                this.playerStatus = PlayerManager.getStatus();
              }
            })
        }
        .width('100%')
        .height(48)
        .backgroundColor('#F0000000')
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  onAppear(): void {
    EventHub.subscribe(EventType.PLAYER_STATUS, (data: object) => {
      const record = data as Record<string, string>;
      const status: string | undefined = record['status'];
      if (status !== undefined) {
        this.playerStatus = status;
      }
    });
  }

  @Builder
  tabItem(text: ResourceStr, index: number) {
    Column({ space: 4 }) {
      Text(text)
        .fontSize(12)
        .fontColor(this.currentTab === index ? '#2962FF' : '#666666')
      Text(index.toString()).fontSize(10).fontColor(this.currentTab === index ? '#2962FF' : '#999999')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
