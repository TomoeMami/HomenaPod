// Port of: storage/database/DBReader.java + DBWriter.java (episodes/media operations)
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_FEED_ITEMS, TABLE_FEED_MEDIA, TABLE_FEEDS, TABLE_QUEUE } from '../Tables';
import { FeedItem } from '../../model/FeedItem';
import { FeedMedia } from '../../model/FeedMedia';
import { SortOrder, FeedState } from '../../model/Enums';
import { FeedItemMapper } from '../mappers/FeedItemMapper';
import { SortUtils } from '../../utils/SortUtils';

/** 播放历史行（FeedMedia × FeedItems × Feeds 投影） */
export interface EpisodeHistoryRow {
  mediaId: number;
  feedItemId: number;
  feedId: number;
  title: string;
  feedTitle: string;
  position: number;
  duration: number;
  lastPlayedTime: number;
  played: boolean;
}

/** media id → 单集（下载页：封面 + 详情页跳转用的单集 id） */
export interface MediaRef {
  itemId: number;
  imageUrl: string;
}

/** 每个订阅的下载占用（存储管理页） */
export interface FeedStorageUsage {
  feedId: number;
  title: string;
  count: number;
  size: number;
}

export interface MonthlyStat {
  month: string;
  totalMs: number;
}

/** 单个订阅的剧集计数（订阅页计数胶囊 / 过滤 / 排序使用） */
export interface FeedCounter {
  /** 收件箱新单集数（read = -1，对照上游 FeedCounter.SHOW_NEW） */
  newCount: number;
  unplayed: number;
  downloaded: number;
  downloadedUnplayed: number;
  /** 已播放集数（对照上游 getPlayedEpisodesCounters，「最多播放」排序用） */
  played: number;
}

/** Episodes 全库列表过滤条件（对照上游 FeedItemFilter 的常用子集） */
export class EpisodeListFilter {
  playedOnly: boolean = false;
  unplayedOnly: boolean = false;
  downloadedOnly: boolean = false;
  notDownloadedOnly: boolean = false;
  inProgressOnly: boolean = false;

  isUnfiltered(): boolean {
    return !this.playedOnly && !this.unplayedOnly && !this.downloadedOnly
      && !this.notDownloadedOnly && !this.inProgressOnly;
  }
}

export interface FeedStat {
  feedId: number;
  title: string;
  totalMs: number;
}

/**
 * Inbox 游标分页位置（最后一条已加载单集的排序键 + id）。
 * 日期排序用 `pubDate`，时长排序用 `duration`（无媒体按 0），两条键都带上以便切换排序后仍可续读。
 */
export interface InboxCursor {
  pubDate: number;
  duration: number;
  id: number;
}

/**
 * Episodes 全库列表的游标分页位置（最后一条已加载单集的排序键 + id）。
 * 与 {@link InboxCursor} 同一套写法，多一条 `title`（该列表支持按标题排序）。
 */
export interface EpisodeListCursor {
  pubDate: number;
  duration: number;
  title: string;
  id: number;
}

export class EpisodeRepository {
  /**
   * Inbox 分页查询的媒体列（别名前缀 media_，与 FeedItemMapper.mapMediaPrefixed 对应）。
   * 用一条 LEFT JOIN 取回整页的媒体，替代逐条 getMediaByFeedItem（上千条新单集时是主要卡顿源）。
   */
  private static readonly MEDIA_COLUMNS: string =
    'm.id AS media_id, m.duration AS media_duration, m.file_url AS media_file_url,' +
      ' m.download_url AS media_download_url, m.download_date AS media_download_date,' +
      ' m.position AS media_position, m.size AS media_size, m.mime_type AS media_mime_type,' +
      ' m.last_played_time_history AS media_last_played_time_history, m.feeditem AS media_feeditem,' +
      ' m.played_duration AS media_played_duration,' +
      ' m.has_embedded_picture AS media_has_embedded_picture,' +
      ' m.last_played_time_statistics AS media_last_played_time_statistics';

  static async listByFeed(feedId: number, unplayedOnly: boolean = false,
                          order: SortOrder = SortOrder.DATE_NEW_OLD): Promise<FeedItem[]> {
    // read 三态：-1=新、0=未播放、1=已播放 →「未播放」= read != 1（与上游 FeedItemFilterQuery 一致）
    const where: string = unplayedOnly ? ` AND i.read != 1` : '';
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.*, ${EpisodeRepository.MEDIA_COLUMNS}
       FROM ${TABLE_FEED_ITEMS} i
       LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       WHERE i.feed = ${feedId}${where}
       ORDER BY i.pubdate DESC`
    );
    const items: FeedItem[] = [];
    if (rs.goToFirstRow()) {
      do {
        const item: FeedItem = FeedItemMapper.map(rs);
        // 媒体随主查询一次取回（与 listInboxPage / listPage 同一套写法）：
        // 订阅详情页面对的是上千集的播客，逐条 getMediaByFeedItem 是上千次串行查询
        item.media = FeedItemMapper.mapMediaPrefixed(rs, 'media_');
        items.push(item);
      } while (rs.goToNextRow());
    }
    rs.close();
    if (order !== SortOrder.DATE_NEW_OLD) {
      return SortUtils.sortItems(items, order);
    }
    return items;
  }

  /**
   * 全库单集列表的一页（Episodes 总表，对照上游 AllEpisodesFragment 的**分页**读取）。
   *
   * 上游是 PagedList 一页页读；这里同样只取一页、按游标续读。**不能再一次性把全库读出来**：
   * 本机库里 1.5 万条单集，全量 SELECT + 逐条映射会把 JS 线程占住好几秒
   * （实测：Episodes 页打开时主线程卡 3 s、批量入队后的 reload 让列表消失 9 s，
   * 并在 ArkUI 组件构建里触发 THREAD_BLOCK_6S appfreeze）。
   *
   * 过滤与排序都在 SQL 里完成（上游 `ItemSortDialog` 也是把排序下推到查询），
   * 游标用「排序键 + id」双键：同日/同标题/同时长的条目也有稳定顺序，翻页不会漏读或重复。
   */
  static async listPage(filter: EpisodeListFilter = new EpisodeListFilter(),
                        order: SortOrder = SortOrder.DATE_NEW_OLD,
                        limit: number = 100,
                        cursor?: EpisodeListCursor): Promise<FeedItem[]> {
    const conditions: string[] = [];
    if (filter.playedOnly) {
      conditions.push('i.read = 1');
    }
    if (filter.unplayedOnly) {
      conditions.push('i.read != 1');
    }
    if (filter.downloadedOnly) {
      conditions.push(`m.file_url IS NOT NULL AND m.file_url != ''`);
    }
    if (filter.notDownloadedOnly) {
      conditions.push(`(m.file_url IS NULL OR m.file_url = '')`);
    }
    if (filter.inProgressOnly) {
      conditions.push(`m.position IS NOT NULL AND m.position > 0
        AND (m.duration IS NULL OR m.duration <= 0 OR m.position < m.duration - 1000)`);
    }
    const byDuration: boolean = order === SortOrder.DURATION_SHORT_LONG
      || order === SortOrder.DURATION_LONG_SHORT;
    const byTitle: boolean = order === SortOrder.TITLE_A_Z || order === SortOrder.TITLE_Z_A;
    const descending: boolean = order === SortOrder.DATE_NEW_OLD
      || order === SortOrder.DURATION_LONG_SHORT || order === SortOrder.TITLE_Z_A;
    const key: string = byDuration ? 'COALESCE(m.duration, 0)' : (byTitle ? 'i.title' : 'i.pubdate');
    if (cursor !== undefined) {
      const compare: string = descending ? '<' : '>';
      const last: string = byTitle
        ? `'${cursor.title.replace(/'/g, "''")}'`
        : (byDuration ? cursor.duration.toString() : cursor.pubDate.toString());
      // 游标条件必须和过滤条件一起组成 WHERE：单独拼在后面会落到 LEFT JOIN 的 ON 里
      // （不设过滤时 WHERE 为空），条件对结果集失效 → 翻页永远返回同一页。
      conditions.push(`(${key} ${compare} ${last} OR (${key} = ${last} AND i.id ${compare} ${cursor.id}))`);
    }
    const where: string = conditions.length > 0 ? ' WHERE ' + conditions.join(' AND ') : '';
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.*, f.custom_title AS feedCustomTitle, f.title AS feedTitle,
         f.image_url AS feedImage, ${EpisodeRepository.MEDIA_COLUMNS}
       FROM ${TABLE_FEED_ITEMS} i
       JOIN ${TABLE_FEEDS} f ON f.id = i.feed
       LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id${where}
       ORDER BY ${key} ${descending ? 'DESC' : 'ASC'}, i.id ${descending ? 'DESC' : 'ASC'} LIMIT ${limit}`
    );
    const items: FeedItem[] = [];
    if (rs.goToFirstRow()) {
      do {
        const item: FeedItem = FeedItemMapper.map(rs);
        // 媒体随主查询一次取回（LEFT JOIN），与 listInboxPage 同一套写法。
        // 曾经这里写成「逐条 await getMediaByFeedItem」：上千条就是上千次串行查询。
        item.media = FeedItemMapper.mapMediaPrefixed(rs, 'media_');
        const customTitle: string = EpisodeRepository.str(rs, 'feedCustomTitle');
        item.feedTitle = customTitle !== '' ? customTitle : EpisodeRepository.str(rs, 'feedTitle');
        item.feedImage = EpisodeRepository.str(rs, 'feedImage');
        items.push(item);
      } while (rs.goToNextRow());
    }
    rs.close();
    return items;
  }

  /**
   * Inbox 一页「新」单集（read = -1，对照上游 InboxFragment 的 FeedItemFilter(NEW)
   * + `DBReader.getEpisodes(..., UserPreferences.getInboxSortedOrder())`）。
   * 游标分页：`cursor` 传上一页最后一条的排序键 + id，SQL 用双键续读。
   * 用游标而不是 OFFSET，是因为翻页期间把条目标为已播会删除行，
   * OFFSET 会整体前移导致漏掉一条（游标不受删除影响）。
   * 排序键与 id 都参与排序：同键的条目也有稳定顺序，分页不会重复/漏读。
   *
   * 支持的排序（上游 InboxSortDialog 只提供「日期 / 时长」两类）：
   * DATE_NEW_OLD（默认）/ DATE_OLD_NEW / DURATION_SHORT_LONG / DURATION_LONG_SHORT。
   */
  static async listInboxPage(limit: number, order: SortOrder = SortOrder.DATE_NEW_OLD,
                             cursor?: InboxCursor): Promise<FeedItem[]> {
    const byDuration: boolean = order === SortOrder.DURATION_SHORT_LONG
      || order === SortOrder.DURATION_LONG_SHORT;
    const descending: boolean = order === SortOrder.DATE_NEW_OLD
      || order === SortOrder.DURATION_LONG_SHORT;
    // 排序键表达式：时长排序用 COALESCE(duration, 0)（无媒体的条目排在最后/最前都稳定）
    const key: string = byDuration ? 'COALESCE(m.duration, 0)' : 'i.pubdate';
    let where: string = '';
    if (cursor !== undefined) {
      const last: number = byDuration ? cursor.duration : cursor.pubDate;
      const compare: string = descending ? '<' : '>';
      where = ` AND (${key} ${compare} ${last} OR (${key} = ${last} AND i.id ${compare} ${cursor.id}))`;
    }
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.*, ${EpisodeRepository.MEDIA_COLUMNS}
       FROM ${TABLE_FEED_ITEMS} i
       LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       WHERE i.read = ${FeedItem.NEW}${where}
       ORDER BY ${key} ${descending ? 'DESC' : 'ASC'}, i.id ${descending ? 'DESC' : 'ASC'} LIMIT ${limit}`
    );
    const items: FeedItem[] = [];
    if (rs.goToFirstRow()) {
      do {
        const item: FeedItem = FeedItemMapper.map(rs);
        item.media = FeedItemMapper.mapMediaPrefixed(rs, 'media_');
        items.push(item);
      } while (rs.goToNextRow());
    }
    rs.close();
    return items;
  }

  static async countNew(): Promise<number> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT COUNT(*) AS c FROM ${TABLE_FEED_ITEMS} WHERE read = -1`
    );
    if (rs.goToFirstRow()) {
      const count: number = rs.getLong(rs.getColumnIndex('c'));
      rs.close();
      return count;
    }
    rs.close();
    return 0;
  }

  /**
   * 全库单集总数（对照上游 `DBReader.getTotalEpisodeCount(FeedItemFilter.unfiltered())`）。
   * 「不筛选」= 不限制读状态、也不限制订阅状态（含归档/已退订源），因此等价于无 WHERE 的计数。
   * 首页用它决定欢迎页：只有**一集都没有**时才显示欢迎页。
   */
  static async countAllEpisodes(): Promise<number> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT COUNT(*) AS c FROM ${TABLE_FEED_ITEMS}`
    );
    if (rs.goToFirstRow()) {
      const count: number = rs.getLong(rs.getColumnIndex('c'));
      rs.close();
      return count;
    }
    rs.close();
    return 0;
  }

  /** 「移除 Inbox 全部」：把所有新标记降级为未播放（对照上游 DBWriter.removeAllNewFlags） */
  static async removeAllNewFlags(): Promise<void> {
    await DbManager.executeSql(`UPDATE ${TABLE_FEED_ITEMS} SET read = 0 WHERE read = -1`);
  }

  /** 标记/取消单集的「新」状态（read = -1 / 0） */
  static async setNewFlag(itemId: number, isNew: boolean): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    predicates.equalTo('id', itemId);
    const values: relationalStore.ValuesBucket = { read: isNew ? FeedItem.NEW : FeedItem.UNPLAYED };
    await DbManager.getStore().update(values, predicates);
  }

  /** 只更新单集封面（刷新时纠正历史错误的封面 / 补上新增的单集封面） */
  static async updateImageUrl(itemId: number, imageUrl: string): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    predicates.equalTo('id', itemId);
    const values: relationalStore.ValuesBucket = { image_url: imageUrl };
    await DbManager.getStore().update(values, predicates);
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
    // 标已播 → 1；标未播 → 0（同时清除「新」标记，与上游 setPlayed 一致）
    const values: relationalStore.ValuesBucket = { read: played ? FeedItem.PLAYED : FeedItem.UNPLAYED };
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
      `SELECT COUNT(*) AS c FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId} AND read != 1`
    );
    if (rs.goToFirstRow()) {
      const count: number = rs.getLong(rs.getColumnIndex('c'));
      rs.close();
      return count;
    }
    rs.close();
    return 0;
  }

  /**
   * 全库按订阅聚合「收件箱新单集 / 未播放 / 已下载 / 已播放」剧集数
   * （订阅页计数胶囊 / 过滤 / 排序使用）。一次查询代替逐 Feed 的 N+1 查询。
   */
  static async listFeedCounters(): Promise<Map<number, FeedCounter>> {
    const counters: Map<number, FeedCounter> = new Map<number, FeedCounter>();
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.feed AS feed,
              SUM(CASE WHEN i.read = -1 THEN 1 ELSE 0 END) AS new_count,
              SUM(CASE WHEN i.read != 1 THEN 1 ELSE 0 END) AS unplayed,
              SUM(CASE WHEN m.file_url IS NOT NULL AND m.file_url != '' THEN 1 ELSE 0 END) AS downloaded,
              SUM(CASE WHEN i.read != 1 AND m.file_url IS NOT NULL AND m.file_url != '' THEN 1 ELSE 0 END)
                AS downloaded_unplayed,
              SUM(CASE WHEN i.read = 1 THEN 1 ELSE 0 END) AS played
       FROM ${TABLE_FEED_ITEMS} i
       LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       GROUP BY i.feed`
    );
    if (rs.goToFirstRow()) {
      do {
        const counter: FeedCounter = {
          newCount: rs.getLong(rs.getColumnIndex('new_count')),
          unplayed: rs.getLong(rs.getColumnIndex('unplayed')),
          downloaded: rs.getLong(rs.getColumnIndex('downloaded')),
          downloadedUnplayed: rs.getLong(rs.getColumnIndex('downloaded_unplayed')),
          played: rs.getLong(rs.getColumnIndex('played'))
        };
        counters.set(rs.getLong(rs.getColumnIndex('feed')), counter);
      } while (rs.goToNextRow());
    }
    rs.close();
    return counters;
  }

  /**
   * 全库按订阅聚合「最新单集发布时间」（对照上游 PodDBAdapter.getMostRecentItemDates：
   * `SELECT feed, MAX(pubdate) GROUP BY feed`）。订阅页「最近更新」排序用它，
   * 而不是 Feed.lastUpdate（刷新时刻），二者在「源里没有新单集」时并不相等。
   */
  static async listMostRecentPubDates(): Promise<Map<number, number>> {
    const dates: Map<number, number> = new Map<number, number>();
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT feed AS feed, MAX(pubdate) AS most_recent FROM ${TABLE_FEED_ITEMS} GROUP BY feed`
    );
    if (rs.goToFirstRow()) {
      do {
        dates.set(rs.getLong(rs.getColumnIndex('feed')), rs.getLong(rs.getColumnIndex('most_recent')));
      } while (rs.goToNextRow());
    }
    rs.close();
    return dates;
  }

  /**
   * 批量把若干订阅的「新」单集移出收件箱（read = -1 → 0）。
   * 对照上游 FeedMultiSelectActionHandler.removeAllFromInbox → DBWriter.removeFeedNewFlag。
   */
  static async clearNewFlagsByFeeds(feedIds: number[]): Promise<void> {
    if (feedIds.length === 0) {
      return;
    }
    await DbManager.executeSql(
      `UPDATE ${TABLE_FEED_ITEMS} SET read = 0 WHERE read = -1 AND feed IN (${feedIds.join(',')})`
    );
  }

  /** 全库按订阅聚合累计收听时长（订阅页「最多播放」排序使用） */
  static async listPlayedDurationByFeed(): Promise<Map<number, number>> {
    const durations: Map<number, number> = new Map<number, number>();
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.feed AS feed, SUM(COALESCE(m.played_duration, 0)) AS total
       FROM ${TABLE_FEED_ITEMS} i
       LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       GROUP BY i.feed`
    );
    if (rs.goToFirstRow()) {
      do {
        durations.set(rs.getLong(rs.getColumnIndex('feed')), rs.getLong(rs.getColumnIndex('total')));
      } while (rs.goToNextRow());
    }
    rs.close();
    return durations;
  }

  /** 按 FeedMedia.id 取单集（取消下载后回写自动下载标记用） */
  static async getByMediaId(mediaId: number): Promise<FeedItem | undefined> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.* FROM ${TABLE_FEED_ITEMS} i
       JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       WHERE m.id = ${mediaId}`
    );
    if (rs.goToFirstRow()) {
      const item: FeedItem = FeedItemMapper.map(rs);
      rs.close();
      return item;
    }
    rs.close();
    return undefined;
  }

  /**
   * 按 FeedMedia.id 批量反查单集（下载页用：DownloadLog 只存 media id 与标题，
   * 行内的封面与「单击进详情页」所需的单集 id 都得回查）。
   * 封面取单集自带图，为空时回落到订阅封面（与各列表行的取图规则一致）。
   */
  static async mediaRefs(mediaIds: number[]): Promise<Map<number, MediaRef>> {
    const result: Map<number, MediaRef> = new Map<number, MediaRef>();
    const ids: number[] = mediaIds.filter((id: number) => Number.isFinite(id) && id > 0);
    if (ids.length === 0) {
      return result;
    }
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT m.id AS media_id, COALESCE(i.id, 0) AS item_id,
              COALESCE(i.image_url, '') AS item_image, COALESCE(f.image_url, '') AS feed_image
       FROM ${TABLE_FEED_MEDIA} m
       LEFT JOIN ${TABLE_FEED_ITEMS} i ON i.id = m.feeditem
       LEFT JOIN ${TABLE_FEEDS} f ON f.id = i.feed
       WHERE m.id IN (${ids.join(',')})`
    );
    if (rs.goToFirstRow()) {
      do {
        const itemImage: string = rs.getString(rs.getColumnIndex('item_image'));
        const feedImage: string = rs.getString(rs.getColumnIndex('feed_image'));
        result.set(rs.getLong(rs.getColumnIndex('media_id')), {
          itemId: rs.getLong(rs.getColumnIndex('item_id')),
          imageUrl: itemImage !== '' ? itemImage : feedImage
        });
      } while (rs.goToNextRow());
    }
    rs.close();
    return result;
  }

  /**
   * 关闭单集的自动下载标记（对照上游 CancelDownloadActionButton 的 disableAutoDownload()）。
   * 否则用户取消下载后，下次刷新会被 AutoDownloadService 重新拉起。
   */
  static async setAutoDownloadEnabled(itemId: number, enabled: boolean): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_ITEMS);
    predicates.equalTo('id', itemId);
    const values: relationalStore.ValuesBucket = { auto_download_enabled: enabled ? 1 : 0 };
    await DbManager.getStore().update(values, predicates);
  }

  static async updateMediaFile(mediaId: number, fileUrl: string, size: number): Promise<void> {    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
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
      read: item.playState,
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

  /** 清空已下载文件引用（删除本地文件后调用，单集记录保留） */
  static async clearMediaFile(mediaId: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEED_MEDIA);
    predicates.equalTo('id', mediaId);
    const values: relationalStore.ValuesBucket = { file_url: '', size: 0, download_date: 0 };
    await DbManager.getStore().update(values, predicates);
  }

  /** 已下载（file_url 非空）的单集数，用于自动下载上限判定 */
  static async countDownloaded(): Promise<number> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT COUNT(*) AS c FROM ${TABLE_FEED_MEDIA} WHERE file_url IS NOT NULL AND file_url != ''`
    );
    if (rs.goToFirstRow()) {
      const count: number = rs.getLong(rs.getColumnIndex('c'));
      rs.close();
      return count;
    }
    rs.close();
    return 0;
  }

  /** 播放历史（含未听完），按最近播放时间倒序 */
  static async listHistory(limit: number = 200): Promise<EpisodeHistoryRow[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT m.id AS mediaId, m.feeditem AS feedItemId, i.feed AS feedId, i.title AS title,
              COALESCE(f.custom_title, '') AS customTitle, COALESCE(f.title, '') AS feedTitle,
              m.position AS position, m.duration AS duration,
              m.last_played_time_history AS lastPlayedTime, i.read AS read
       FROM ${TABLE_FEED_MEDIA} m
       JOIN ${TABLE_FEED_ITEMS} i ON i.id = m.feeditem
       LEFT JOIN Feeds f ON f.id = i.feed
       WHERE m.last_played_time_history > 0
       ORDER BY m.last_played_time_history DESC LIMIT ${limit}`
    );
    const rows: EpisodeHistoryRow[] = [];
    if (rs.goToFirstRow()) {
      do {
        const customTitle: string = EpisodeRepository.str(rs, 'customTitle');
        rows.push({
          mediaId: rs.getLong(rs.getColumnIndex('mediaId')),
          feedItemId: rs.getLong(rs.getColumnIndex('feedItemId')),
          feedId: rs.getLong(rs.getColumnIndex('feedId')),
          title: EpisodeRepository.str(rs, 'title'),
          feedTitle: customTitle !== '' ? customTitle : EpisodeRepository.str(rs, 'feedTitle'),
          position: rs.getLong(rs.getColumnIndex('position')),
          duration: rs.getLong(rs.getColumnIndex('duration')),
          lastPlayedTime: rs.getLong(rs.getColumnIndex('lastPlayedTime')),
          played: rs.getLong(rs.getColumnIndex('read')) === 1
        });
      } while (rs.goToNextRow());
    }
    rs.close();
    return rows;
  }

  /**
   * 首页「继续收听」区块（对照上游 `DBReader.getPausedQueue` → `PodDBAdapter.getPausedQueueCursor`）。
   *
   * 上游取的是**队列**而不是播放历史：`Queue JOIN FeedItems`，把「已有播放位置（≥1 秒）」
   * 或「30 秒内播放过」的条目按统计时间倒序排前面，其余条目按队列顺序排在后面
   * ——所以刚加入队列、还没播过的单集也会出现在这里，只是排在最后。
   */
  static async listPausedQueue(limit: number): Promise<FeedItem[]> {
    const recentlyPlayed: number = Date.now() - 30000;
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.*, ${EpisodeRepository.MEDIA_COLUMNS}
       FROM ${TABLE_QUEUE} q
       JOIN ${TABLE_FEED_ITEMS} i ON i.id = q.feeditem
       LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       ORDER BY (CASE WHEN m.position >= 1000 OR m.last_played_time_statistics >= ${recentlyPlayed}
                      THEN m.last_played_time_statistics ELSE 0 END) DESC, q.id
       LIMIT ${limit}`
    );
    const items: FeedItem[] = [];
    if (rs.goToFirstRow()) {
      do {
        const item: FeedItem = FeedItemMapper.map(rs);
        item.media = FeedItemMapper.mapMediaPrefixed(rs, 'media_');
        items.push(item);
      } while (rs.goToNextRow());
    }
    rs.close();
    return items;
  }

  /**
   * 首页「随机惊喜」区块（对照上游 `DBReader.getRandomEpisodes` → `PodDBAdapter.getRandomEpisodesCursor`）：
   * 仅「新 / 未播放」、仅已订阅源、发布时间在 **2 年内**、排除「1 小时前播放过但没听完」的单集，
   * **每个订阅最多取 1 集**（`GROUP BY feed`），取哪一集与订阅之间的顺序都由 `seed` 决定。
   * seed 在页面内保持稳定（只有点「乱序」才换），因此刷新页面不会换掉这一批推荐。
   *
   * 上游用 `(id * seed) % 46471` 造伪随机数（SQLite 没有可复现的随机种子）：
   * 内层每组取该值最大的一集，外层按同一函数（seed*3）对**选中那一集**的 id 排序。
   */
  static async listRandomEpisodes(limit: number, seed: number): Promise<FeedItem[]> {
    const now: number = Date.now();
    const twoYearsAgo: number = now - 1000 * 3600 * 24 * 356 * 2;
    const oneHourAgo: number = now - 1000 * 3600;
    const pickNumber: string = `((i.id * ${seed}) % 46471)`;
    const orderNumber: string = `((picked.pickId * ${seed * 3}) % 46471)`;
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM (
         SELECT i.id AS pickId, MAX(${pickNumber}) AS rnd, i.*, ${EpisodeRepository.MEDIA_COLUMNS}
         FROM ${TABLE_FEED_ITEMS} i
         JOIN ${TABLE_FEEDS} f ON f.id = i.feed
         LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
         WHERE (i.read = ${FeedItem.NEW} OR i.read = ${FeedItem.UNPLAYED})
           AND i.pubdate > ${twoYearsAgo}
           AND (m.last_played_time_statistics IS NULL OR m.last_played_time_statistics = 0
                OR m.last_played_time_statistics > ${oneHourAgo})
           AND f.state = ${FeedState.STATE_SUBSCRIBED}
         GROUP BY i.feed
       ) picked
       ORDER BY ${orderNumber} DESC
       LIMIT ${limit}`
    );
    const items: FeedItem[] = [];
    if (rs.goToFirstRow()) {
      do {
        const item: FeedItem = FeedItemMapper.map(rs);
        item.media = FeedItemMapper.mapMediaPrefixed(rs, 'media_');
        items.push(item);
      } while (rs.goToNextRow());
    }
    rs.close();
    return items;
  }

  /** 累计实际收听时长（统计页数据源），同时刷新统计时间戳 */
  static async addPlayedDuration(mediaId: number, deltaMs: number): Promise<void> {
    if (deltaMs <= 0) {
      return;
    }
    await DbManager.executeSql(
      `UPDATE ${TABLE_FEED_MEDIA} SET played_duration = COALESCE(played_duration, 0) + ${Math.floor(deltaMs)},
       last_played_time_statistics = ${Date.now()} WHERE id = ${mediaId}`
    );
  }

  /** 每个订阅的已下载集数与占用字节（存储管理页） */
  static async listStorageByFeed(): Promise<FeedStorageUsage[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.feed AS feedId, COALESCE(f.custom_title, '') AS customTitle,
              COALESCE(f.title, '') AS feedTitle, COUNT(*) AS c, COALESCE(SUM(m.size), 0) AS totalSize
       FROM ${TABLE_FEED_MEDIA} m
       JOIN ${TABLE_FEED_ITEMS} i ON i.id = m.feeditem
       LEFT JOIN Feeds f ON f.id = i.feed
       WHERE m.file_url IS NOT NULL AND m.file_url != ''
       GROUP BY i.feed ORDER BY totalSize DESC`
    );
    const rows: FeedStorageUsage[] = [];
    if (rs.goToFirstRow()) {
      do {
        const customTitle: string = EpisodeRepository.str(rs, 'customTitle');
        rows.push({
          feedId: rs.getLong(rs.getColumnIndex('feedId')),
          title: customTitle !== '' ? customTitle : EpisodeRepository.str(rs, 'feedTitle'),
          count: rs.getLong(rs.getColumnIndex('c')),
          size: rs.getLong(rs.getColumnIndex('totalSize'))
        });
      } while (rs.goToNextRow());
    }
    rs.close();
    return rows;
  }

  /** 收听统计：按月 */
  static async listStatsByMonth(): Promise<MonthlyStat[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT strftime('%Y-%m', m.last_played_time_statistics / 1000, 'unixepoch', 'localtime') AS month,
              COALESCE(SUM(m.played_duration), 0) AS totalMs
       FROM ${TABLE_FEED_MEDIA} m
       WHERE m.last_played_time_statistics > 0
       GROUP BY month ORDER BY month DESC`
    );
    const rows: MonthlyStat[] = [];
    if (rs.goToFirstRow()) {
      do {
        rows.push({
          month: EpisodeRepository.str(rs, 'month'),
          totalMs: rs.getLong(rs.getColumnIndex('totalMs'))
        });
      } while (rs.goToNextRow());
    }
    rs.close();
    return rows;
  }

  /**
   * 收听统计：按订阅（对照上游 `DBReader.getStatistics(...).feedTime` + `getFeedStatisticsCursor`）。
   *
   * 与上游一致的三点：
   * 1. 时间窗加在 `last_played_time_statistics` 上（`[fromTime, toTime)`），首页「常听经典」传最近 3 年；
   * 2. 只统计 `state != STATE_NOT_SUBSCRIBED` 的订阅（归档/已退订源不参与）；
   * 3. `includeMarkedAsPlayed`（统计页「包含仅标记为已播的单集」）打开时，
   *    「手动标记已播但没有实际收听时长」的单集按**整集时长**计入。
   *
   * 窗口内没有收听的订阅同样会返回（totalMs = 0），由调用方自行截断——上游也是这个行为。
   */
  static async listStatsByFeed(includeMarkedAsPlayed: boolean = false,
                               fromTime: number = 0,
                               toTime: number = Number.MAX_SAFE_INTEGER): Promise<FeedStat[]> {
    const playedTime: string = includeMarkedAsPlayed
      ? `(CASE WHEN COALESCE(m.played_duration, 0) != 0 THEN COALESCE(m.played_duration, 0)
               WHEN i.read = ${FeedItem.PLAYED} THEN COALESCE(m.duration, 0) ELSE 0 END)`
      : 'COALESCE(m.played_duration, 0)';
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.feed AS feedId, COALESCE(f.custom_title, '') AS customTitle,
              COALESCE(f.title, '') AS feedTitle,
              COALESCE(SUM(CASE WHEN m.last_played_time_statistics >= ${fromTime}
                                 AND m.last_played_time_statistics < ${toTime}
                            THEN ${playedTime} ELSE 0 END), 0) AS totalMs
       FROM ${TABLE_FEED_ITEMS} i
       JOIN ${TABLE_FEEDS} f ON f.id = i.feed
       LEFT JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       WHERE f.state != ${FeedState.STATE_NOT_SUBSCRIBED}
       GROUP BY i.feed
       ORDER BY totalMs DESC, feedId ASC`
    );
    const rows: FeedStat[] = [];
    if (rs.goToFirstRow()) {
      do {
        const customTitle: string = EpisodeRepository.str(rs, 'customTitle');
        rows.push({
          feedId: rs.getLong(rs.getColumnIndex('feedId')),
          title: customTitle !== '' ? customTitle : EpisodeRepository.str(rs, 'feedTitle'),
          totalMs: rs.getLong(rs.getColumnIndex('totalMs'))
        });
      } while (rs.goToNextRow());
    }
    rs.close();
    return rows;
  }

  /** Feed 内搜索（标题 + 简介），keyword 为空时等价 listByFeed */
  static async searchByFeed(feedId: number, keyword: string): Promise<FeedItem[]> {
    const trimmed: string = keyword.trim();
    if (trimmed === '') {
      return await EpisodeRepository.listByFeed(feedId);
    }
    const escaped: string = trimmed.replace(/'/g, "''").toLowerCase();
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId}
       AND (LOWER(title) LIKE '%${escaped}%' OR LOWER(description) LIKE '%${escaped}%')
       ORDER BY pubdate DESC`
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

  /** 全库未播放剧集（首页「看新内容」），按发布时间倒序；未播放 = read != 1（含新标记） */
  static async listUnplayed(limit: number = 100): Promise<FeedItem[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEED_ITEMS} WHERE read != 1 ORDER BY pubdate DESC LIMIT ${limit}`
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

  /** 全库未播放总数（首页「看新内容」区块角标）；未播放 = read != 1（含新标记） */
  static async countAllUnplayed(): Promise<number> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT COUNT(*) AS cnt FROM ${TABLE_FEED_ITEMS} WHERE read != 1`
    );
    let count: number = 0;
    if (rs.goToFirstRow()) {
      count = rs.getLong(rs.getColumnIndex('cnt'));
    }
    rs.close();
    return count;
  }

  /**
   * 已下载剧集（首页「管理下载」区块）。
   * 对照上游 `DownloadsSection` 的 `DBReader.getEpisodes(0, 2, DOWNLOADED, UserPreferences.getDownloadsSortedOrder())`：
   * 排序由调用方按用户设置传入（默认新→旧）。非默认排序时必须先取全量再排序，
   * 否则 `LIMIT` 会先按发布时间截断，排序结果就不是"该排序下的前 N 条"。
   */
  static async listDownloadedItems(limit: number = 20,
                                   order: SortOrder = SortOrder.DATE_NEW_OLD): Promise<FeedItem[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT i.* FROM ${TABLE_FEED_ITEMS} i
       JOIN ${TABLE_FEED_MEDIA} m ON m.feeditem = i.id
       WHERE m.file_url IS NOT NULL AND m.file_url != ''
       ORDER BY i.pubdate DESC`
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
    const ordered: FeedItem[] = order === SortOrder.DATE_NEW_OLD
      ? items
      : SortUtils.sortItems(items, order);
    return limit > 0 ? ordered.slice(0, limit) : ordered;
  }

  private static str(rs: relationalStore.ResultSet, column: string): string {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return '';
    }
    return rs.getString(index);
  }

  /** 某订阅已下载的媒体记录（存储管理页删除用） */
  static async listDownloadedMediaByFeed(feedId: number): Promise<FeedMedia[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT m.* FROM ${TABLE_FEED_MEDIA} m
       JOIN ${TABLE_FEED_ITEMS} i ON i.id = m.feeditem
       WHERE i.feed = ${feedId} AND m.file_url IS NOT NULL AND m.file_url != ''`
    );
    const media: FeedMedia[] = [];
    if (rs.goToFirstRow()) {
      do {
        media.push(FeedItemMapper.mapMedia(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    return media;
  }

  /** 全部已下载媒体记录（"全部删除"用） */
  static async listAllDownloadedMedia(): Promise<FeedMedia[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEED_MEDIA} WHERE file_url IS NOT NULL AND file_url != ''`
    );
    const media: FeedMedia[] = [];
    if (rs.goToFirstRow()) {
      do {
        media.push(FeedItemMapper.mapMedia(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    return media;
  }

  /** 某订阅已下载的文件路径（取消订阅时先删文件再删记录） */
  static async listDownloadedFilesByFeed(feedId: number): Promise<string[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT m.file_url AS fileUrl FROM ${TABLE_FEED_MEDIA} m
       JOIN ${TABLE_FEED_ITEMS} i ON i.id = m.feeditem
       WHERE i.feed = ${feedId} AND m.file_url IS NOT NULL AND m.file_url != ''`
    );
    const paths: string[] = [];
    if (rs.goToFirstRow()) {
      do {
        paths.push(EpisodeRepository.str(rs, 'fileUrl'));
      } while (rs.goToNextRow());
    }
    rs.close();
    return paths;
  }

  /** 删除某订阅的全部剧集数据（媒体、章节、队列项、收藏、单集），供取消订阅使用 */
  static async deleteByFeed(feedId: number): Promise<void> {
    await DbManager.executeSql(
      `DELETE FROM ${TABLE_FEED_MEDIA} WHERE feeditem IN (SELECT id FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId})`);
    await DbManager.executeSql(
      `DELETE FROM SimpleChapters WHERE feeditem IN (SELECT id FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId})`);
    await DbManager.executeSql(`DELETE FROM Queue WHERE feed = ${feedId}`);
    await DbManager.executeSql(`DELETE FROM Favorites WHERE feed = ${feedId}`);
    await DbManager.executeSql(`DELETE FROM ${TABLE_FEED_ITEMS} WHERE feed = ${feedId}`);
  }
}
