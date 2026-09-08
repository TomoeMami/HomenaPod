// Port of: net/download/service/feed/{FeedUpdateManagerImpl,FeedUpdateWorker,NewEpisodesNotification}.java
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FeedFetcher } from './FeedFetcher';
import { NotificationService } from './NotificationService';
import { Logger } from '../utils/Logger';

const TAG: string = 'RefreshService';

export class RefreshService {
  static async refreshAll(): Promise<number> {
    const feeds: Feed[] = await FeedRepository.listSubscribed();
    let newCount: number = 0;
    for (const feed of feeds) {
      try {
        const result = await FeedFetcher.fetchFeed(feed.downloadUrl);
        const parsed: Feed = result.feed;
        newCount += await RefreshService.mergeFeed(feed, parsed);
      } catch (error) {
        Logger.warn(TAG, 'refresh failed for feed ' + feed.id + ': ' + (error as Error).message);
      }
    }
    await NotificationService.notifyNewEpisodes(newCount);
    return newCount;
  }

  static async mergeFeed(existing: Feed, parsed: Feed): Promise<number> {
    let added: number = 0;
    const existingItems: FeedItem[] = await EpisodeRepository.listByFeed(existing.id, false);
    const existingIds: Set<string> = new Set<string>();
    for (const item of existingItems) {
      if (item.itemIdentifier !== '') {
        existingIds.add(item.itemIdentifier);
      }
    }
    for (const item of parsed.items) {
      if (item.itemIdentifier === '') {
        continue;
      }
      if (existingIds.has(item.itemIdentifier)) {
        continue;
      }
      item.feedId = existing.id;
      const itemId: number = await EpisodeRepository.insertItem(item);
      item.id = itemId;
      if (item.media !== undefined) {
        item.media.feedItemId = itemId;
        const mediaId: number = await EpisodeRepository.insertMedia(item.media);
        item.media.id = mediaId;
      }
      added++;
    }
    existing.title = parsed.title;
    existing.description = parsed.description;
    existing.imageUrl = parsed.imageUrl;
    existing.lastUpdate = parsed.lastUpdate;
    existing.lastRefreshAttempt = Date.now();
    await FeedRepository.update(existing);
    return added;
  }

  static async refreshFeed(feedId: number): Promise<void> {
    const feed: Feed | undefined = await FeedRepository.getById(feedId);
    if (feed === undefined) {
      return;
    }
    const result = await FeedFetcher.fetchFeed(feed.downloadUrl);
    await RefreshService.mergeFeed(feed, result.feed);
  }
}
