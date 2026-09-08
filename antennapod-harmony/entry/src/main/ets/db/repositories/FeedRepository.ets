// Port of: storage/database/DBReader.java + DBWriter.java (feed operations)
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_FEEDS } from '../Tables';
import { Feed } from '../../model/Feed';
import { FeedMapper } from '../mappers/FeedMapper';

export class FeedRepository {
  static async listSubscribed(): Promise<Feed[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEEDS} WHERE state = 1 ORDER BY custom_title, title`
    );
    const result: Feed[] = [];
    if (rs.goToFirstRow()) {
      do {
        result.push(FeedMapper.map(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    return result;
  }

  static async getById(id: number): Promise<Feed | undefined> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEEDS} WHERE id = ${id}`
    );
    if (rs.goToFirstRow()) {
      const feed: Feed = FeedMapper.map(rs);
      rs.close();
      return feed;
    }
    rs.close();
    return undefined;
  }

  static async getByDownloadUrl(downloadUrl: string): Promise<Feed | undefined> {
    const escaped: string = downloadUrl.replace(/'/g, "''");
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEEDS} WHERE download_url = '${escaped}'`
    );
    if (rs.goToFirstRow()) {
      const feed: Feed = FeedMapper.map(rs);
      rs.close();
      return feed;
    }
    rs.close();
    return undefined;
  }

  static async insert(feed: Feed): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      title: feed.title,
      custom_title: feed.customTitle,
      file_url: feed.fileUrl,
      download_url: feed.downloadUrl,
      last_refresh_attempt: feed.lastRefreshAttempt,
      link: feed.link,
      description: feed.description,
      payment_link: feed.paymentLink,
      last_update: feed.lastUpdate,
      language: feed.language,
      author: feed.author,
      image_url: feed.imageUrl,
      type: feed.type,
      feed_identifier: feed.feedIdentifier,
      auto_download_enabled: feed.autoDownloadEnabled ? 1 : 0,
      username: feed.username,
      password: feed.password,
      include_filter: feed.includeFilter,
      exclude_filter: feed.excludeFilter,
      minimal_duration_filter: feed.minimalDurationFilter,
      keep_updated: feed.keepUpdated ? 1 : 0,
      is_paged: feed.isPaged ? 1 : 0,
      next_page_link: feed.nextPageLink,
      hide: feed.hide,
      sort_order: feed.sortOrder.toString(),
      last_update_failed: feed.lastUpdateFailed ? 1 : 0,
      auto_delete_action: feed.autoDeleteAction,
      feed_playback_speed: feed.feedPlaybackSpeed,
      feed_skip_silence: feed.feedSkipSilence,
      feed_volume_adaption: feed.feedVolumeAdaption,
      feed_tags: feed.feedTags,
      feed_skip_intro: feed.feedSkipIntro,
      feed_skip_ending: feed.feedSkipEnding,
      episode_notification: feed.episodeNotification ? 1 : 0,
      state: feed.state,
      new_episodes_action: feed.newEpisodesAction
    };
    return await DbManager.insert(TABLE_FEEDS, values);
  }

  static async update(feed: Feed): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEEDS);
    predicates.equalTo('id', feed.id);
    const values: relationalStore.ValuesBucket = {
      title: feed.title,
      custom_title: feed.customTitle,
      description: feed.description,
      language: feed.language,
      author: feed.author,
      link: feed.link,
      feed_identifier: feed.feedIdentifier,
      last_update: feed.lastUpdate,
      last_refresh_attempt: feed.lastRefreshAttempt,
      image_url: feed.imageUrl,
      state: feed.state,
      last_update_failed: feed.lastUpdateFailed ? 1 : 0
    };
    await DbManager.getStore().update(values, predicates);
  }

  static async delete(id: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEEDS);
    predicates.equalTo('id', id);
    await DbManager.getStore().delete(predicates);
  }
}
