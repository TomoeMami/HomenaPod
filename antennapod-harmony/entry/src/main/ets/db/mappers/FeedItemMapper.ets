// Port of: storage/database/mapper/FeedItemCursor.java + FeedMediaCursor.java
import relationalStore from '@ohos.data.relationalStore';
import { FeedItem, FeedItemOptions } from '../../model/FeedItem';
import { FeedMedia, FeedMediaOptions } from '../../model/FeedMedia';

export class FeedItemMapper {
  static map(rs: relationalStore.ResultSet): FeedItem {
    // read 列为三态：-1=新（Inbox）、0=未播放、1=已播放（上游 FeedItemFilterQuery）
    const readValue: number = rs.getColumnIndex('read') >= 0 ? rs.getLong(rs.getColumnIndex('read')) : 0;
    const options: FeedItemOptions = {
      id: rs.getLong(rs.getColumnIndex('id')),
      title: FeedItemMapper.str(rs, 'title'),
      pubDate: rs.getLong(rs.getColumnIndex('pubdate')),
      isPlayed: readValue === 1,
      playState: readValue,
      link: FeedItemMapper.str(rs, 'link'),
      description: FeedItemMapper.str(rs, 'description'),
      paymentLink: FeedItemMapper.str(rs, 'payment_link'),
      media: undefined,
      feedId: rs.getLong(rs.getColumnIndex('feed')),
      hasChapters: rs.getColumnIndex('has_chapters') >= 0 && rs.getLong(rs.getColumnIndex('has_chapters')) !== 0,
      itemIdentifier: FeedItemMapper.str(rs, 'item_identifier'),
      imageUrl: FeedItemMapper.str(rs, 'image_url'),
      autoDownloadEnabled: rs.getColumnIndex('auto_download_enabled') >= 0 && rs.getLong(rs.getColumnIndex('auto_download_enabled')) !== 0,
      podcastIndexChapterUrl: FeedItemMapper.str(rs, 'podcastindex_chapter_url'),
      podcastIndexTranscriptType: FeedItemMapper.str(rs, 'podcastindex_transcript_type'),
      podcastIndexTranscriptUrl: FeedItemMapper.str(rs, 'podcastindex_transcript_url'),
      socialInteractUrl: FeedItemMapper.str(rs, 'social_interact_url')
    };
    return new FeedItem(options);
  }

  static mapMedia(rs: relationalStore.ResultSet): FeedMedia {
    const options: FeedMediaOptions = {
      id: rs.getLong(rs.getColumnIndex('id')),
      duration: rs.getLong(rs.getColumnIndex('duration')),
      fileUrl: FeedItemMapper.str(rs, 'file_url'),
      downloadUrl: FeedItemMapper.str(rs, 'download_url'),
      downloadDate: rs.getLong(rs.getColumnIndex('download_date')),
      position: rs.getLong(rs.getColumnIndex('position')),
      size: rs.getLong(rs.getColumnIndex('size')),
      mimeType: FeedItemMapper.str(rs, 'mime_type'),
      lastPlayedTimeHistory: rs.getLong(rs.getColumnIndex('last_played_time_history')),
      feedItemId: rs.getLong(rs.getColumnIndex('feeditem')),
      playedDuration: rs.getLong(rs.getColumnIndex('played_duration')),
      hasEmbeddedPicture: rs.getLong(rs.getColumnIndex('has_embedded_picture')) !== 0,
      lastPlayedTimeStatistics: rs.getLong(rs.getColumnIndex('last_played_time_statistics'))
    };
    return new FeedMedia(options);
  }

  /**
   * JOIN 查询中带别名前缀的媒体列映射（Inbox 分页用）。
   * FeedItems 与 FeedMedia 都有 id 列，同一条结果集里必须用前缀区分；
   * 该行没有媒体（LEFT JOIN 落空）时返回 undefined。
   */
  static mapMediaPrefixed(rs: relationalStore.ResultSet, prefix: string): FeedMedia | undefined {
    const id: number = FeedItemMapper.num(rs, prefix + 'id', -1);
    if (id < 0) {
      return undefined;
    }
    const options: FeedMediaOptions = {
      id: id,
      duration: FeedItemMapper.num(rs, prefix + 'duration', 0),
      fileUrl: FeedItemMapper.str(rs, prefix + 'file_url'),
      downloadUrl: FeedItemMapper.str(rs, prefix + 'download_url'),
      downloadDate: FeedItemMapper.num(rs, prefix + 'download_date', 0),
      position: FeedItemMapper.num(rs, prefix + 'position', 0),
      size: FeedItemMapper.num(rs, prefix + 'size', 0),
      mimeType: FeedItemMapper.str(rs, prefix + 'mime_type'),
      lastPlayedTimeHistory: FeedItemMapper.num(rs, prefix + 'last_played_time_history', 0),
      feedItemId: FeedItemMapper.num(rs, prefix + 'feeditem', 0),
      playedDuration: FeedItemMapper.num(rs, prefix + 'played_duration', 0),
      hasEmbeddedPicture: FeedItemMapper.num(rs, prefix + 'has_embedded_picture', 0) !== 0,
      lastPlayedTimeStatistics: FeedItemMapper.num(rs, prefix + 'last_played_time_statistics', 0)
    };
    return new FeedMedia(options);
  }

  private static str(rs: relationalStore.ResultSet, column: string): string {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return '';
    }
    return rs.getString(index);
  }

  private static num(rs: relationalStore.ResultSet, column: string, fallback: number): number {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return fallback;
    }
    return rs.getLong(index);
  }
}
