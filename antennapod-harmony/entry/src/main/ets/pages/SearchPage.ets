import router from '@ohos.router';
import { Discovery, PodcastSearchResult } from '../net/Discovery';
import { SubscriptionService } from '../services/SubscriptionService';
import { LazyDataSource } from '../components/LazyDataSource';
import { FeedCover } from '../components/FeedCover';

interface SearchParams {
  term: string;
}

@Entry
@Component
struct SearchPage {
  private dataSource: LazyDataSource<PodcastSearchResult> = new LazyDataSource<PodcastSearchResult>();
  @State term: string = '';
  @State results: PodcastSearchResult[] = [];
  @State loading: boolean = false;
  @State message: string = '';

  build() {
    Column({ space: 12 }) {
      Text($r('app.string.discover_title')).fontSize(22).fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 16, top: 8 })
      Row({ space: 8 }) {
        TextInput({ placeholder: $r('app.string.discover_hint'), text: this.term })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.term = value;
          })
        Button($r('app.string.discover_search'))
          .onClick(() => {
            this.search();
          })
      }
      .width('90%')

      Text(this.message).fontSize(13).fontColor('#CC0000')

      if (this.loading) {
        Text($r('app.string.loading')).fontSize(14).fontColor($r('app.color.text_secondary')).layoutWeight(1)
      } else if (this.results.length === 0) {
        Text($r('app.string.discover_empty')).fontSize(14).fontColor($r('app.color.text_secondary')).layoutWeight(1)
      } else {
        List({ space: 8 }) {
          LazyForEach(this.dataSource, (item: PodcastSearchResult, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                FeedCover({ imageUrl: item.imageUrl })
                Column({ space: 4 }) {
                  Text(item.title).fontSize(15)
                  Text(item.author).fontSize(12).fontColor($r('app.color.text_secondary'))
                  Button($r('app.string.discover_subscribe'))
                    .fontSize(12)
                    .onClick(() => {
                      this.subscribe(item.feedUrl);
                    })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(8)
            }
          }, (item: PodcastSearchResult, index: number) => item.feedUrl + '-' + index)
        }
        .layoutWeight(1)
        .width('90%')
      }
    }
    .width('100%')
    .height('100%')
  }

  aboutToAppear(): void {
    const params = router.getParams() as SearchParams;
    if (params !== undefined && params.term !== undefined) {
      this.term = params.term;
      this.search();
    }
  }

  async search(): Promise<void> {
    if (this.term === '') {
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const results: PodcastSearchResult[] = await Discovery.searchPodcasts(this.term);
      this.results = results;
      this.dataSource.setData(results);
    } catch (error) {
      this.results = [];
      this.dataSource.setData([]);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.search_failed')) + (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  async subscribe(feedUrl: string): Promise<void> {
    if (feedUrl === '') {
      return;
    }
    try {
      await SubscriptionService.subscribe(feedUrl);
      router.back();
    } catch (error) {
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.subscribe_failed')) + (error as Error).message;
    }
  }
}
