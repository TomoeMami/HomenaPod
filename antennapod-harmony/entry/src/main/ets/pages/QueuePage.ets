import { QueueEngine } from '../player/QueueEngine';
import { FeedItem } from '../model/FeedItem';
import { LazyDataSource } from '../components/LazyDataSource';

@Component
export struct QueuePage {
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  @State items: FeedItem[] = [];
  @State loading: boolean = false;

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.tab_queue')).fontSize(22).fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 16, top: 8 })
      if (this.loading) {
        Text($r('app.string.loading')).fontSize(14).fontColor($r('app.color.text_secondary')).layoutWeight(1)
      } else if (this.items.length === 0) {
        Column({ space: 8 }) {
          Text($r('app.string.placeholder_queue')).fontSize(14).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          LazyForEach(this.dataSource, (item: FeedItem, index: number) => {
            ListItem() {
              Row({ space: 8 }) {
                Column({ space: 4 }) {
                  Text(item.title).fontSize(15)
                  Text(item.feedId.toString()).fontSize(11).fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Button('↑')
                  .onClick(() => {
                    this.move(item.id, index - 1);
                  })
                Button('↓')
                  .onClick(() => {
                    this.move(item.id, index + 1);
                  })
                Button('×')
                  .onClick(() => {
                    this.remove(item.id);
                  })
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(8)
            }
          }, (item: FeedItem, index: number) => item.id + '-' + index)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      await QueueEngine.load();
      const items: FeedItem[] = QueueEngine.getItems();
      this.items = items;
      this.dataSource.setData(items);
    } catch (error) {
      this.items = [];
      this.dataSource.setData([]);
    } finally {
      this.loading = false;
    }
  }

  async move(feedItemId: number, targetIndex: number): Promise<void> {
    if (targetIndex < 0 || targetIndex >= this.items.length) {
      return;
    }
    await QueueEngine.move(feedItemId, targetIndex);
    await this.load();
  }

  async remove(feedItemId: number): Promise<void> {
    await QueueEngine.remove(feedItemId);
    await this.load();
  }
}
