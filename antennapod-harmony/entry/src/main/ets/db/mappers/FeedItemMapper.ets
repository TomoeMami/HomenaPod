// Port of: storage/database/mapper/FeedItemCursor.java + FeedMediaCursor.java
import relationalStore from '@ohos.data.relationalStore';
import { FeedItem, FeedItemOptions } from '../../model/FeedItem';
import { FeedMedia, FeedMediaOptions } from '../../model/FeedMedia';

export class FeedItemMapper {
  static map(rs: relationalStore.ResultSet): FeedItem {
    const options: FeedItemOptions = {
      id: rs.getLong(rs.getColumnIndex('id')),
      title: FeedItemMapper.str(rs, 'title'),
      pubDate: rs.getLong(rs.getColumnIndex('pubdate')),
      isPlayed: rs.getLong(rs.getColumnIndex('read')) !== 0,
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

  private static str(rs: relationalStore.ResultSet, column: string): string {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return '';
    }
    return rs.getString(index);
  }
}
