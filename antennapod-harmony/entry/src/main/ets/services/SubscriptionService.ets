// Port of: net/download/service/feed/local/LocalFeedUpdater.java + FeedDatabaseWriter.java
import { FeedFetcher } from './FeedFetcher';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { Logger } from '../utils/Logger';

const TAG: string = 'SubscriptionService';

export class SubscriptionService {
  static async subscribe(url: string): Promise<Feed> {
    const result = await FeedFetcher.fetchFeed(url);
    const feed: Feed = result.feed;
    feed.downloadUrl = url;
    const feedId: number = await FeedRepository.insert(feed);
    feed.id = feedId;
    for (const item of feed.items) {
      item.feedId = feedId;
      const itemId: number = await EpisodeRepository.insertItem(item);
      item.id = itemId;
      if (item.media !== undefined) {
        item.media.feedItemId = itemId;
        const mediaId: number = await EpisodeRepository.insertMedia(item.media);
        item.media.id = mediaId;
      }
    }
    Logger.info(TAG, 'subscribed feed id=' + feedId + ' items=' + feed.items.length);
    return feed;
  }
}
