// Port of: storage/database Favorites table operations
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_FAVORITES, TABLE_FEED_ITEMS } from '../Tables';
import { FeedItem } from '../../model/FeedItem';
import { FeedItemMapper } from '../mappers/FeedItemMapper';
import { EpisodeRepository } from './EpisodeRepository';

export class FavoritesRepository {
  static async isFavorite(feedItemId: number): Promise<boolean> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT id FROM ${TABLE_FAVORITES} WHERE feeditem = ${feedItemId}`
    );
    const found: boolean = rs.goToFirstRow();
    rs.close();
    return found;
  }

  static async add(feedItemId: number, feedId: number): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      id: feedItemId,
      feeditem: feedItemId,
      feed: feedId
    };
    await DbManager.insert(TABLE_FAVORITES, values);
  }

  static async remove(feedItemId: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FAVORITES);
    predicates.equalTo('feeditem', feedItemId);
    await DbManager.getStore().delete(predicates);
  }

  static async list(): Promise<FeedItem[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.* FROM ${TABLE_FEED_ITEMS} i INNER JOIN ${TABLE_FAVORITES} f ON i.id = f.feeditem ORDER BY i.pubdate DESC`
    );
    const items: FeedItem[] = [];
    if (rs.goToFirstRow()) {
      do {
        items.push(FeedItemMapper.map(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    for (const item of items) {
      item.media = await EpisodeRepository.getMediaByFeedItem(item.id);
    }
    return items;
  }
}
