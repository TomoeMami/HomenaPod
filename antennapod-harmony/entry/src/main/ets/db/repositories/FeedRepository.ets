// Port of: storage/database/DBReader.java + DBWriter.java (feed operations)
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_FEEDS, TABLE_FEED_ITEMS } from '../Tables';
import { Feed } from '../../model/Feed';
import { SortOrder } from '../../model/Enums';
import { FeedMapper } from '../mappers/FeedMapper';

/** 标签总览（订阅页标签胶囊行 / 标签编辑弹层） */
export interface FeedTagState {
  /** 命名标签，按字母序（忽略大小写） */
  names: string[];
  /** 是否存在未标记（feed_tags 为空）的订阅 */
  hasUntagged: boolean;
}

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
    await FeedRepository.fillItemCounts(result);
    return result;
  }

  /**
   * 一次性聚合每个订阅的剧集数与已下载数。
   * 未播放数在 EpisodeRepository.countUnplayedByFeed 中单独聚合（供订阅页排序/过滤/计数胶囊使用）。
   */
  static async fillItemCounts(feeds: Feed[]): Promise<void> {
    if (feeds.length === 0) {
      return;
    }
    const counts: Map<number, number> = new Map<number, number>();
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT feed, COUNT(*) AS c FROM ${TABLE_FEED_ITEMS} GROUP BY feed`
    );
    if (rs.goToFirstRow()) {
      do {
        counts.set(rs.getLong(rs.getColumnIndex('feed')), rs.getLong(rs.getColumnIndex('c')));
      } while (rs.goToNextRow());
    }
    rs.close();
    for (const feed of feeds) {
      const count: number | undefined = counts.get(feed.id);
      feed.itemCount = count !== undefined ? count : 0;
    }
  }

  /**
   * 按 id 批量取订阅（队列页排序用：播客标题排序需要 feedId → 标题）。
   * 不限于已订阅，队列里可能残留已取消订阅的单集。
   */
  static async listByIds(ids: number[]): Promise<Feed[]> {
    if (ids.length === 0) {
      return [];
    }
    const unique: number[] = [];
    for (const id of ids) {
      if (!unique.includes(id)) {
        unique.push(id);
      }
    }
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_FEEDS} WHERE id IN (${unique.join(',')})`
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
      sort_order: SortOrder[feed.sortOrder],
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
      new_episodes_action: feed.newEpisodesAction,
      inbox_baseline: feed.inboxBaseline
    };
    return await DbManager.insert(TABLE_FEEDS, values);
  }

  /**
   * 写入全部可编辑字段。
   * 关键：RefreshService.mergeFeed 也走此方法（它先 getById 读出全部字段再写回，值不变，无覆盖风险）；
   * 每 Feed 设置页 / 过滤器 / 排序 / 认证凭据等一切持久化都依赖这里的字段完整性。
   */
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
      last_update_failed: feed.lastUpdateFailed ? 1 : 0,
      download_url: feed.downloadUrl,
      file_url: feed.fileUrl,
      payment_link: feed.paymentLink,
      type: feed.type,
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
      sort_order: SortOrder[feed.sortOrder],
      auto_delete_action: feed.autoDeleteAction,
      feed_playback_speed: feed.feedPlaybackSpeed,
      feed_skip_silence: feed.feedSkipSilence,
      feed_volume_adaption: feed.feedVolumeAdaption,
      feed_tags: feed.feedTags,
      feed_skip_intro: feed.feedSkipIntro,
      feed_skip_ending: feed.feedSkipEnding,
      episode_notification: feed.episodeNotification ? 1 : 0,
      new_episodes_action: feed.newEpisodesAction,
      inbox_baseline: feed.inboxBaseline
    };
    await DbManager.getStore().update(values, predicates);
  }

  /** 每 Feed 设置保存的语义化入口（设置页 / 过滤器弹窗 / 排序弹窗调用） */
  static async updatePreferences(feed: Feed): Promise<void> {
    await FeedRepository.update(feed);
  }

  /**
   * 标签总览（对照上游 DBReader.getAllTags + NavDrawerData.TagItem）：
   * 命名标签按字母序（忽略大小写），另给出「是否存在未标记订阅」。
   *
   * 本移植版没有上游的 TAG_ROOT 哨兵（"root" 表示「显示在抽屉里」），
   * 未标记 = feed_tags 为空串。
   */
  static async listTagState(): Promise<FeedTagState> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT feed_tags FROM ${TABLE_FEEDS} WHERE state = 1`
    );
    const names: string[] = [];
    let hasUntagged: boolean = false;
    if (rs.goToFirstRow()) {
      do {
        const raw: string = rs.getString(rs.getColumnIndex('feed_tags'));
        const tags: string[] = FeedRepository.splitTags(raw);
        if (tags.length === 0) {
          hasUntagged = true;
        }
        for (const tag of tags) {
          if (!names.includes(tag)) {
            names.push(tag);
          }
        }
      } while (rs.goToNextRow());
    }
    rs.close();
    names.sort((a: string, b: string) => a.toLowerCase().localeCompare(b.toLowerCase()));
    return { names: names, hasUntagged: hasUntagged };
  }

  /** 重命名标签：所有订阅里同名的标签就地改名（上游 RenameFeedDialog → TagItem.setTitle） */
  static async renameTag(oldName: string, newName: string): Promise<void> {
    if (oldName === '' || newName === '' || oldName === newName) {
      return;
    }
    const feeds: Feed[] = await FeedRepository.listSubscribed();
    for (const feed of feeds) {
      const tags: string[] = FeedRepository.splitTags(feed.feedTags);
      if (!tags.includes(oldName)) {
        continue;
      }
      const next: string[] = [];
      for (const tag of tags) {
        const value: string = tag === oldName ? newName : tag;
        if (!next.includes(value)) {
          next.push(value);
        }
      }
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEEDS);
      predicates.equalTo('id', feed.id);
      await DbManager.getStore().update({ feed_tags: next.join(',') }, predicates);
    }
  }

  /** 删除标签：从所有订阅上摘掉该标签（上游 TagMenuHandler 的 delete_folder_item） */
  static async deleteTag(name: string): Promise<void> {
    if (name === '') {
      return;
    }
    const feeds: Feed[] = await FeedRepository.listSubscribed();
    for (const feed of feeds) {
      const tags: string[] = FeedRepository.splitTags(feed.feedTags);
      if (!tags.includes(name)) {
        continue;
      }
      const next: string[] = tags.filter((tag: string) => tag !== name);
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEEDS);
      predicates.equalTo('id', feed.id);
      await DbManager.getStore().update({ feed_tags: next.join(',') }, predicates);
    }
  }

  /** 标签拆分：逗号分隔 + trim + 去空（上游以 TagItem 集合做精确匹配） */
  static splitTags(value: string): string[] {
    const tags: string[] = [];
    for (const raw of value.split(',')) {
      const trimmed: string = raw.trim();
      if (trimmed !== '' && !tags.includes(trimmed)) {
        tags.push(trimmed);
      }
    }
    return tags;
  }

  static async delete(id: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_FEEDS);
    predicates.equalTo('id', id);
    await DbManager.getStore().delete(predicates);
  }
}
