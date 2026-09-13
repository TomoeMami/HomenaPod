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

  /**
   * 全部收藏的单集 id（一条 SQL）。
   * 列表页整页判定收藏时用它，替代逐条 `isFavorite`（订阅详情页面对上千集时是上千次查询）。
   */
  static async listIds(): Promise<number[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT feeditem FROM ${TABLE_FAVORITES}`
    );
    const ids: number[] = [];
    if (rs.goToFirstRow()) {
      do {
        ids.push(rs.getLong(rs.getColumnIndex('feeditem')));
      } while (rs.goToNextRow());
    }
    rs.close();
    return ids;
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
