// Port of: storage/database/DBReader.java + DBWriter.java (episodes/media operations)
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_FEED_ITEMS, TABLE_FEED_MEDIA } from '../Tables';
import { FeedItem } from '../../model/FeedItem';
import { FeedMedia } from '../../model/FeedMedia';
import { FeedItemMapper } from '../mappers/FeedItemMapper';

export class EpisodeRepository {
  static async listByFeed(feedId: number, unplayedOnly: boolean = false): Promise<FeedItem[]> {
    const where: string = unplayedOnly ? ` AND read = 0` : '';
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId}${where} ORDER BY pubdate DESC`
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

  static async getMediaByFeedItem(feedItemId: number): Promise<FeedMedia | undefined> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEED_MEDIA} WHERE feeditem = ${feedItemId}`
    );
    if (rs.goToFirstRow()) {
      const media: FeedMedia = FeedItemMapper.mapMedia(rs);
      rs.close();
      return media;
    }
    rs.close();
    return undefined;
  }

  static async markPlayed(itemId: number, played: boolean): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    predicates.equalTo('id', itemId);
    const values: relationalStore.ValuesBucket = { read: played ? 1 : 0 };
    await DbManager.getStore().update(values, predicates);
  }

  static async updatePosition(mediaId: number, position: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    predicates.equalTo('id', mediaId);
    const values: relationalStore.ValuesBucket = {
      position: position,
      last_played_time_history: Date.now()
    };
    await DbManager.getStore().update(values, predicates);
  }

  static async countUnplayed(feedId: number): Promise<number> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT COUNT(*) AS c FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId} AND read = 0`
    );
    if (rs.goToFirstRow()) {
      const count: number = rs.getLong(rs.getColumnIndex('c'));
      rs.close();
      return count;
    }
    rs.close();
    return 0;
  }

  static async updateMediaFile(mediaId: number, fileUrl: string, size: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    predicates.equalTo('id', mediaId);
    const values: relationalStore.ValuesBucket = {
      file_url: fileUrl,
      size: size,
      download_date: Date.now()
    };
    await DbManager.getStore().update(values, predicates);
  }

  static async insertItem(item: FeedItem): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      title: item.title,
      pubdate: item.pubDate,
      read: item.isPlayed ? 1 : 0,
      link: item.link,
      description: item.description,
      payment_link: item.paymentLink,
      feed: item.feedId,
      has_chapters: item.hasChapters ? 1 : 0,
      item_identifier: item.itemIdentifier,
      image_url: item.imageUrl,
      auto_download_enabled: item.autoDownloadEnabled ? 1 : 0,
      podcastindex_chapter_url: item.podcastIndexChapterUrl,
      podcastindex_transcript_type: item.podcastIndexTranscriptType,
      podcastindex_transcript_url: item.podcastIndexTranscriptUrl,
      social_interact_url: item.socialInteractUrl
    };
    return await DbManager.insert(TABLE_FEED_ITEMS, values);
  }

  static async insertMedia(media: FeedMedia): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      duration: media.duration,
      file_url: media.fileUrl,
      download_url: media.downloadUrl,
      download_date: media.downloadDate,
      position: media.position,
      size: media.size,
      mime_type: media.mimeType,
      last_played_time_history: media.lastPlayedTimeHistory,
      feeditem: media.feedItemId,
      played_duration: media.playedDuration,
      has_embedded_picture: media.hasEmbeddedPicture ? 1 : 0,
      last_played_time_statistics: media.lastPlayedTimeStatistics
    };
    return await DbManager.insert(TABLE_FEED_MEDIA, values);
  }

  static async findByItemIdentifier(feedId: number, itemIdentifier: string): Promise<FeedItem | undefined> {
    const escaped: string = itemIdentifier.replace(/'/g, "''");
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId} AND item_identifier = '${escaped}'`
    );
    if (rs.goToFirstRow()) {
      const item: FeedItem = FeedItemMapper.map(rs);
      rs.close();
      item.media = await EpisodeRepository.getMediaByFeedItem(item.id);
      return item;
    }
    rs.close();
    return undefined;
  }

  static async getById(feedItemId: number): Promise<FeedItem | undefined> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEED_ITEMS} WHERE id = ${feedItemId}`
    );
    if (rs.goToFirstRow()) {
      const item: FeedItem = FeedItemMapper.map(rs);
      rs.close();
      item.media = await EpisodeRepository.getMediaByFeedItem(item.id);
      return item;
    }
    rs.close();
    return undefined;
  }
}
