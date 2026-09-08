import router from '@ohos.router';
import { FeedItem } from '../model/FeedItem';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { LazyDataSource } from '../components/LazyDataSource';
import { FeedCover } from '../components/FeedCover';

@Entry
@Component
struct FavoritesPage {
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  @State items: FeedItem[] = [];
  @State loading: boolean = false;

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.favorites_title')).fontSize(22).fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 16, top: 8 })
      if (this.loading) {
        Text($r('app.string.loading')).fontSize(14).fontColor($r('app.color.text_secondary')).layoutWeight(1)
      } else if (this.items.length === 0) {
        Text($r('app.string.favorites_empty')).fontSize(14).fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          LazyForEach(this.dataSource, (item: FeedItem) => {
            ListItem() {
              Row({ space: 8 }) {
                FeedCover({ imageUrl: item.imageUrl })
                Column({ space: 4 }) {
                  Text(item.title).fontSize(15)
                  Text(item.pubDate > 0 ? new Date(item.pubDate).toLocaleDateString() : '')
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Button('★').fontSize(16).onClick(() => {
                  FavoritesRepository.remove(item.id);
                  this.load();
                })
              }
              .onClick(() => {
                this.play(item);
              })
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(8)
            }
          }, (item: FeedItem) => item.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  onAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const items: FeedItem[] = await FavoritesRepository.list();
      this.items = items;
      this.dataSource.setData(items);
    } catch (error) {
      this.items = [];
      this.dataSource.setData([]);
    } finally {
      this.loading = false;
    }
  }

  async play(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    const playable: Playable = new Playable(
      item.media.id,
      item.id,
      item.title,
      'Favorites',
      item.media.downloadUrl,
      item.media.fileUrl,
      item.media.duration,
      item.media.position,
      item.media.getMediaType()
    );
    await PlayerManager.load(playable, item.media.position, true);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }
}
