// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/FeedItemFilter.java
import { FeedItem } from './FeedItem';

export class FeedItemFilter {
  static readonly PLAYED: string = 'played';
  static readonly UNPLAYED: string = 'unplayed';
  static readonly DOWNLOADED: string = 'downloaded';
  static readonly NOT_DOWNLOADED: string = 'not_downloaded';
  static readonly HAS_MEDIA: string = 'has_media';
  static readonly NO_MEDIA: string = 'no_media';
  static readonly IS_FAVORITE: string = 'is_favorite';
  static readonly NOT_FAVORITE: string = 'not_favorite';

  readonly showPlayed: boolean = false;
  readonly showUnplayed: boolean = false;
  readonly showDownloaded: boolean = false;
  readonly showNotDownloaded: boolean = false;
  readonly showHasMedia: boolean = false;
  readonly showNoMedia: boolean = false;
  readonly showIsFavorite: boolean = false;
  readonly showNotFavorite: boolean = false;
  private properties: string[] = [];

  constructor(properties: string[] | string = '') {
    if (typeof properties === 'string') {
      this.properties = properties.split(',').filter((p: string) => p !== '');
    } else {
      this.properties = properties;
    }
    this.showPlayed = this.hasProperty(FeedItemFilter.PLAYED);
    this.showUnplayed = this.hasProperty(FeedItemFilter.UNPLAYED);
    this.showDownloaded = this.hasProperty(FeedItemFilter.DOWNLOADED);
    this.showNotDownloaded = this.hasProperty(FeedItemFilter.NOT_DOWNLOADED);
    this.showHasMedia = this.hasProperty(FeedItemFilter.HAS_MEDIA);
    this.showNoMedia = this.hasProperty(FeedItemFilter.NO_MEDIA);
    this.showIsFavorite = this.hasProperty(FeedItemFilter.IS_FAVORITE);
    this.showNotFavorite = this.hasProperty(FeedItemFilter.NOT_FAVORITE);
  }

  static unfiltered(): FeedItemFilter {
    return new FeedItemFilter('');
  }

  getValues(): string[] {
    return this.properties.slice();
  }

  matches(item: FeedItem): boolean {
    if (this.showPlayed && !item.isPlayed) {
      return false;
    }
    if (this.showUnplayed && item.isPlayed) {
      return false;
    }
    if (this.showDownloaded && (item.media === undefined || item.media.fileUrl === '')) {
      return false;
    }
    if (this.showNotDownloaded && item.media !== undefined && item.media.fileUrl !== '') {
      return false;
    }
    if (this.showHasMedia && !item.hasMedia()) {
      return false;
    }
    if (this.showNoMedia && item.hasMedia()) {
      return false;
    }
    return true;
  }

  private hasProperty(property: string): boolean {
    return this.properties.indexOf(property) >= 0;
  }
}
