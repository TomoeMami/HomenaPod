// Port of: storage/database/mapper/FeedCursor.java
import relationalStore from '@ohos.data.relationalStore';
import { Feed, FeedOptions } from '../../model/Feed';
import { FeedState, SortOrder } from '../../model/Enums';

export class FeedMapper {
  static map(rs: relationalStore.ResultSet): Feed {
    const options: FeedOptions = {
      id: rs.getLong(rs.getColumnIndex('id')),
      title: FeedMapper.str(rs, 'title'),
      customTitle: FeedMapper.str(rs, 'custom_title'),
      fileUrl: FeedMapper.str(rs, 'file_url'),
      downloadUrl: FeedMapper.str(rs, 'download_url'),
      lastRefreshAttempt: rs.getLong(rs.getColumnIndex('last_refresh_attempt')),
      link: FeedMapper.str(rs, 'link'),
      description: FeedMapper.str(rs, 'description'),
      paymentLink: FeedMapper.str(rs, 'payment_link'),
      lastUpdate: FeedMapper.str(rs, 'last_update'),
      language: FeedMapper.str(rs, 'language'),
      author: FeedMapper.str(rs, 'author'),
      imageUrl: FeedMapper.str(rs, 'image_url'),
      type: FeedMapper.str(rs, 'type'),
      feedIdentifier: FeedMapper.str(rs, 'feed_identifier'),
      autoDownloadEnabled: rs.getLong(rs.getColumnIndex('auto_download_enabled')) !== 0,
      username: FeedMapper.str(rs, 'username'),
      password: FeedMapper.str(rs, 'password'),
      includeFilter: FeedMapper.str(rs, 'include_filter'),
      excludeFilter: FeedMapper.str(rs, 'exclude_filter'),
      minimalDurationFilter: rs.getLong(rs.getColumnIndex('minimal_duration_filter')),
      keepUpdated: rs.getLong(rs.getColumnIndex('keep_updated')) !== 0,
      isPaged: rs.getLong(rs.getColumnIndex('is_paged')) !== 0,
      nextPageLink: FeedMapper.str(rs, 'next_page_link'),
      hide: FeedMapper.str(rs, 'hide'),
      sortOrder: FeedMapper.sortOrder(rs),
      lastUpdateFailed: rs.getLong(rs.getColumnIndex('last_update_failed')) !== 0,
      autoDeleteAction: rs.getLong(rs.getColumnIndex('auto_delete_action')),
      feedPlaybackSpeed: rs.getDouble(rs.getColumnIndex('feed_playback_speed')),
      feedSkipSilence: rs.getLong(rs.getColumnIndex('feed_skip_silence')),
      feedVolumeAdaption: rs.getLong(rs.getColumnIndex('feed_volume_adaption')),
      feedTags: FeedMapper.str(rs, 'feed_tags'),
      feedSkipIntro: rs.getLong(rs.getColumnIndex('feed_skip_intro')),
      feedSkipEnding: rs.getLong(rs.getColumnIndex('feed_skip_ending')),
      episodeNotification: rs.getLong(rs.getColumnIndex('episode_notification')) !== 0,
      state: rs.getLong(rs.getColumnIndex('state')) as FeedState,
      newEpisodesAction: rs.getLong(rs.getColumnIndex('new_episodes_action')),
      inboxBaseline: FeedMapper.num(rs, 'inbox_baseline')
    };
    return new Feed(options);
  }

  /** 列缺失（旧库尚未迁移）或为 NULL 时返回 0，避免取列索引抛错 */
  private static num(rs: relationalStore.ResultSet, column: string): number {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return 0;
    }
    return rs.getLong(index);
  }

  private static sortOrder(rs: relationalStore.ResultSet): SortOrder {
    const value: string = FeedMapper.str(rs, 'sort_order');
    if (value === 'DATE_NEW_OLD') {
      return SortOrder.DATE_NEW_OLD;
    }
    if (value === 'DATE_OLD_NEW') {
      return SortOrder.DATE_OLD_NEW;
    }
    if (value === 'TITLE_A_Z') {
      return SortOrder.TITLE_A_Z;
    }
    if (value === 'TITLE_Z_A') {
      return SortOrder.TITLE_Z_A;
    }
    if (value === 'DURATION_SHORT_LONG') {
      return SortOrder.DURATION_SHORT_LONG;
    }
    if (value === 'DURATION_LONG_SHORT') {
      return SortOrder.DURATION_LONG_SHORT;
    }
    return SortOrder.DATE_NEW_OLD;
  }

  private static str(rs: relationalStore.ResultSet, column: string): string {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return '';
    }
    return rs.getString(index);
  }
}
