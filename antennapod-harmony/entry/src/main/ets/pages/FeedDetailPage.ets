import router from '@ohos.router';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { MediaType } from '../model/Enums';
import { LazyDataSource } from '../components/LazyDataSource';
import { FeedCover } from '../components/FeedCover';

interface FeedDetailParams {
  feedId: number;
}

@Entry
@Component
struct FeedDetailPage {
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  @State feed: Feed | undefined = undefined;
  @State episodes: FeedItem[] = [];
  @State filter: string = 'all';
  @State loading: boolean = false;
  @State errorMessage: string = '';

  build() {
    Column({ space: 8 }) {
      if (this.feed !== undefined) {
        Row({ space: 12 }) {
          FeedCover({ imageUrl: this.feed!.imageUrl })
          Column({ space: 4 }) {
            Text(this.feed!.getTitle()).fontSize(22).fontWeight(FontWeight.Bold)
            Text(this.feed!.author === '' ? this.feed!.link : this.feed!.author)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, top: 8 })
        Row({ space: 8 }) {
          this.filterChip($r('app.string.filter_all'), 'all')
          this.filterChip($r('app.string.filter_unplayed'), 'unplayed')
          this.filterChip($r('app.string.filter_downloaded'), 'downloaded')
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
      }

      if (this.loading) {
        Text($r('app.string.loading')).fontSize(14).fontColor($r('app.color.text_secondary')).layoutWeight(1)
      } else if (this.errorMessage !== '') {
        Text(this.errorMessage).fontSize(14).fontColor('#CC0000').layoutWeight(1)
      } else {
        List({ space: 4 }) {
          LazyForEach(this.dataSource, (item: FeedItem) => {
            ListItem() {
              Row({ space: 8 }) {
                Column({ space: 4 }) {
                  Text(item.title).fontSize(15)
                  Text(item.media !== undefined && item.media.fileUrl !== '' ? $r('app.string.episode_downloaded') : $r('app.string.episode_online'))
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Button('★')
                  .fontSize(16)
                  .onClick(() => {
                    this.toggleFavorite(item);
                  })
                Text(item.pubDate > 0 ? new Date(item.pubDate).toLocaleDateString() : '')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
              }
              .onClick(() => {
                this.play(item);
              })
              .width('100%')
              .padding(12)
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

  @Builder
  filterChip(label: ResourceStr, value: string) {
    Text(label)
      .fontSize(13)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === value ? '#2962FF' : '#EEEEEE')
      .fontColor(this.filter === value ? '#FFFFFF' : '#333333')
      .borderRadius(16)
      .onClick(() => {
        this.filter = value;
        this.loadEpisodes();
      })
  }

  aboutToAppear(): void {
    const params = router.getParams() as FeedDetailParams;
    if (params !== undefined && params.feedId !== undefined) {
      this.load(params.feedId);
    }
  }

  async load(feedId: number): Promise<void> {
    try {
      this.feed = await FeedRepository.getById(feedId);
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
    this.loading = true;
    this.errorMessage = '';
    try {
      const unplayed: boolean = this.filter === 'unplayed';
      const items: FeedItem[] = await EpisodeRepository.listByFeed(this.feed.id, unplayed);
      this.episodes = items;
      this.dataSource.setData(items);
    } catch (error) {
      this.episodes = [];
      this.dataSource.setData([]);
      this.errorMessage = (error as Error).message;
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
      this.feed !== undefined ? this.feed.getTitle() : '',
      item.media.downloadUrl,
      item.media.fileUrl,
      item.media.duration,
      item.media.position,
      item.media.getMediaType()
    );
    await PlayerManager.load(playable, item.media.position, true);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  async toggleFavorite(item: FeedItem): Promise<void> {
    const fav: boolean = await FavoritesRepository.isFavorite(item.id);
    if (fav) {
      await FavoritesRepository.remove(item.id);
    } else {
      await FavoritesRepository.add(item.id, item.feedId);
    }
  }
}
