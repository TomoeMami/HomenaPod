import router from '@ohos.router';
import { Feed } from '../model/Feed';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { RefreshService } from '../services/RefreshService';
import { FeedCover } from '../components/FeedCover';
import { LazyDataSource } from '../components/LazyDataSource';

@Component
export struct SubscriptionsPage {
  private dataSource: LazyDataSource<Feed> = new LazyDataSource<Feed>();
  @State feeds: Feed[] = [];
  @State loading: boolean = false;

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text($r('app.string.tab_subscriptions')).fontSize(22).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button($r('app.string.refresh_all'))
          .fontSize(12)
          .onClick(() => {
            this.refreshAll();
          })
        Button($r('app.string.discover_search'))
          .fontSize(12)
          .onClick(() => {
            router.pushUrl({ url: 'pages/SearchPage', params: { term: '' } });
          })
        Button($r('app.string.favorites_button'))
          .fontSize(12)
          .onClick(() => {
            router.pushUrl({ url: 'pages/FavoritesPage' });
          })
      }
      .width('100%')
      .padding({ left: 16, top: 8 })

      if (this.feeds.length === 0 && !this.loading) {
        Column({ space: 8 }) {
          Text($r('app.string.placeholder_subscriptions')).fontSize(14).fontColor($r('app.color.text_secondary'))
          Button($r('app.string.add_feed'))
            .onClick(() => {
              router.pushUrl({ url: 'pages/AddFeedPage' });
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          LazyForEach(this.dataSource, (feed: Feed) => {
            ListItem() {
              Row({ space: 12 }) {
                FeedCover({ imageUrl: feed.imageUrl })
                Column() {
                  Text(feed.getTitle()).fontSize(16).fontWeight(FontWeight.Medium)
                  Text(feed.author === '' ? feed.link : feed.author)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(feed.items.length.toString()).fontSize(12).fontColor($r('app.color.text_secondary'))
              }
              .onClick(() => {
                router.pushUrl({ url: 'pages/FeedDetailPage', params: { feedId: feed.id } });
              })
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(8)
            }
          }, (feed: Feed) => feed.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }

      Button($r('app.string.add_feed'))
        .margin({ bottom: 12 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddFeedPage' });
        })
    }
    .width('100%')
    .height('100%')
  }

  onAppear(): void {
    this.loadFeeds();
  }

  async loadFeeds(): Promise<void> {
    this.loading = true;
    try {
      const feeds: Feed[] = await FeedRepository.listSubscribed();
      this.feeds = feeds;
      this.dataSource.setData(feeds);
    } catch (error) {
      this.feeds = [];
      this.dataSource.setData([]);
    } finally {
      this.loading = false;
    }
  }

  async refreshAll(): Promise<void> {
    try {
      await RefreshService.refreshAll();
    } catch (error) {
      // 通知/刷新失败不阻断 UI
    }
    await this.loadFeeds();
  }
}
