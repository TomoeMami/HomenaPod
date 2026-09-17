// Port of: net/download/service/feed/{FeedUpdateManagerImpl,FeedUpdateWorker,NewEpisodesNotification}.java
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedFilter } from '../model/FeedFilter';
import { NewEpisodesAction } from '../model/Enums';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { DownloadManager } from '../download/DownloadManager';
import { QueueEngine } from '../player/QueueEngine';
import { FeedFetcher } from './FeedFetcher';
import { NotificationService, FeedNotificationEntry } from './NotificationService';
import { AutoDownloadService } from './AutoDownloadService';
import { UserPreferences } from '../prefs/UserPreferences';
import { EventHub, EventType, FeedUpdateData, RefreshStateData } from '../events/EventHub';
import { InboxBaseline } from '../utils/InboxBaseline';
import { Logger } from '../utils/Logger';

const TAG: string = 'RefreshService';
/** 分页订阅最多抓取的页数（防止异常 feed 无限翻页） */
const MAX_PAGES: number = 5;

/** 合并结果：新增数量 + 新增单集（供自动下载与通知复用，避免重复查询） */
export interface MergeResult {
  count: number;
  added: FeedItem[];
}

export class RefreshService {
  /**
   * 是否有刷新正在跑（对照上游 `FeedUpdateManager` 的单实例语义）。
   *
   * 没有这道闸时，两个并发的 `refreshAll()` 会各自把同一个源抓一遍：两边都在
   * 插入前查过「已存在的 item_identifier」，于是同一条新单集被插入两次
   * （第 40 轮验收实测：`epv-010` / `epv-011` 各出现两行）。
   */
  private static running: boolean = false;

  /**
   * 刷新进行中又收到了新的刷新请求（例如批量导入刚写完订阅就触发刷新）。
   * 进行中的那一轮抓的是「开始时的订阅列表」，新建的订阅不在其中，必须补跑一轮，否则要等下一次定时刷新。
   */
  private static rerunRequested: boolean = false;

  /** 刷新是否正在跑（订阅页在订阅 REFRESH_STATE 之前先读一次，补偿事件非 sticky） */
  static isRunning(): boolean {
    return RefreshService.running;
  }

  /**
   * 自动刷新全部订阅。
   * 与上游一致：keepUpdated=false 的订阅被跳过（手动 refreshFeed 不受此限制）。
   * 与上游 `FeedUpdateManager` 一致地合并并发请求：进行中再来的请求会补跑一轮。
   */
  static async refreshAll(): Promise<number> {
    if (RefreshService.running) {
      RefreshService.rerunRequested = true;
      Logger.info(TAG, 'refresh already running, will run again afterwards');
      return 0;
    }
    RefreshService.running = true;
    RefreshService.publishRefreshState(true);
    let total: number = 0;
    try {
      do {
        RefreshService.rerunRequested = false;
        total += await RefreshService.runRefreshAll();
      } while (RefreshService.rerunRequested);
      return total;
    } finally {
      RefreshService.running = false;
      RefreshService.publishRefreshState(false);
    }
  }

  private static publishRefreshState(running: boolean): void {
    const data: RefreshStateData = { running: running };
    EventHub.publish(EventType.REFRESH_STATE, data);
  }

  private static async runRefreshAll(): Promise<number> {
    const feeds: Feed[] = await FeedRepository.listSubscribed();
    let newCount: number = 0;
    const notifications: FeedNotificationEntry[] = [];
    for (const feed of feeds) {
      if (!feed.keepUpdated) {
        Logger.info(TAG, 'skip feed ' + feed.id + ' (keepUpdated=false)');
        continue;
      }
      try {
        const result = await FeedFetcher.fetchFeed(feed.downloadUrl, feed.username, feed.password);
        // 「从未抓取过」的订阅（OPML 批量导入只登记行，见 SubscriptionService.subscribeDeferred）
        // 这一次抓取就是它的首次订阅：源里全是订阅前既有的历史内容，未带日期的单集也不进收件箱。
        const firstFetch: boolean = feed.lastRefreshAttempt <= 0;
        const merge: MergeResult = await RefreshService.mergeFeed(feed, result.feed, firstFetch);
        newCount += merge.count;
        // 首次抓取（= 批量导入刚登记、或从未成功抓取过）不按「新单集」处理：这一轮收录的是整源
        // 历史内容，既不该发「N 个新单集」通知，也不该触发自动下载 / 自动入队
        // （旧实现里 OPML 导入走的是同步 subscribe()，同样不产生通知与自动下载）。
        if (!firstFetch && merge.count > 0) {
          notifications.push({ title: feed.getTitle(), count: merge.count });
          await RefreshService.applyNewEpisodesAction(feed, merge.added);
          await AutoDownloadService.onNewItems(feed, merge.added);
        }
      } catch (error) {
        Logger.warn(TAG, 'refresh failed for feed ' + feed.id + ': ' + (error as Error).message);
        // 订阅更新失败也入下载日志（对照上游 DownloadLog 的 FEEDFILETYPE_FEED 记录），
        // 其重试动作是「重新刷新订阅」而不是重新下载文件
        await DownloadManager.logFeedFailure(feed.id, feed.getTitle());
      }
      // 每抓完一个就广播一次（上游 FeedUpdateWorker 也是逐 Feed 发事件）：
      // 批量导入后订阅页能看着封面与计数一个个补齐，而不是整轮跑完才一次性刷新。
      RefreshService.publishFeedListUpdate();
    }
    await NotificationService.notifyNewEpisodesByFeed(notifications);
    RefreshService.publishFeedListUpdate();
    return newCount;
  }

  /**
   * 合并单个订阅的解析结果。
   * - 每 Feed 过滤器在此处落为 FeedItem.autoDownloadEnabled（入库即生效，供自动下载判定）
   * - 分页订阅（rel="next"）会继续抓取后续页，最多 MAX_PAGES 页
   *
   * @param initialSubscribe true = 本次合并来自「首次订阅 / 批量导入」。此时源里的单集都是
   *        订阅前就已存在的历史内容，一律落「未播放」，不灌进收件箱（见 resolvePlayState）。
   */
  static async mergeFeed(existing: Feed, parsed: Feed, initialSubscribe: boolean = false): Promise<MergeResult> {
    const added: FeedItem[] = [];
    const existingItems: FeedItem[] = await EpisodeRepository.listByFeed(existing.id, false);
    const existingIds: Set<string> = new Set<string>();
    const existingById: Map<string, FeedItem> = new Map<string, FeedItem>();
    for (const item of existingItems) {
      if (item.itemIdentifier !== '') {
        existingIds.add(item.itemIdentifier);
        existingById.set(item.itemIdentifier, item);
      }
    }
    const filter: FeedFilter = new FeedFilter(
      existing.includeFilter, existing.excludeFilter, existing.minimalDurationFilter);

    let current: Feed = parsed;
    let page: number = 0;
    let nextLink: string = '';
    const visited: Set<string> = new Set<string>();
    while (page < MAX_PAGES) {
      await RefreshService.insertNewItems(existing, current, filter, existingIds, existingById, added,
        initialSubscribe);
      nextLink = current.isPaged ? current.nextPageLink : '';
      page++;
      if (nextLink === '' || visited.has(nextLink)) {
        break;
      }
      visited.add(nextLink);
      try {
        const nextResult = await FeedFetcher.fetchFeed(nextLink, existing.username, existing.password);
        current = nextResult.feed;
      } catch (error) {
        Logger.warn(TAG, 'paged feed fetch failed for feed ' + existing.id + ': ' + (error as Error).message);
        nextLink = '';
        break;
      }
    }
    existing.isPaged = nextLink !== '';
    existing.nextPageLink = nextLink;
    existing.title = parsed.title;
    existing.description = parsed.description;
    existing.imageUrl = parsed.imageUrl;
    existing.lastUpdate = parsed.lastUpdate;
    existing.lastRefreshAttempt = Date.now();
    await FeedRepository.update(existing);
    if (page > 1) {
      Logger.info(TAG, 'merged ' + page + ' pages for feed ' + existing.id + ', added ' + added.length);
    }
    return { count: added.length, added: added };
  }

  /** 把一页解析结果中的新单集写入数据库（去重沿用 existingIds） */
  private static async insertNewItems(existing: Feed, page: Feed, filter: FeedFilter,
                                       existingIds: Set<string>, existingById: Map<string, FeedItem>,
                                       added: FeedItem[], initialSubscribe: boolean): Promise<void> {
    for (const item of page.items) {
      if (item.itemIdentifier === '') {
        continue;
      }
      if (existingIds.has(item.itemIdentifier)) {
        // 已存在的单集：只在封面变化时回写。旧解析把「最后一集的 itunes:image」当成播客封面
        // 写进了每条单集，刷新一次即可就地纠正（不必取消订阅再重新订阅）。
        const known: FeedItem | undefined = existingById.get(item.itemIdentifier);
        if (known !== undefined && known.imageUrl !== item.imageUrl) {
          await EpisodeRepository.updateImageUrl(known.id, item.imageUrl);
        }
        continue;
      }
      existingIds.add(item.itemIdentifier);
      item.feedId = existing.id;
      item.autoDownloadEnabled = filter.shouldAutoDownload(item);
      // 新单集动作（对照上游 FeedDatabaseWriter：ADD_TO_INBOX → setNew()，read 落 -1）
      item.playState = RefreshService.resolvePlayState(existing, item, initialSubscribe);
      const itemId: number = await EpisodeRepository.insertItem(item);
      item.id = itemId;
      if (item.media !== undefined) {
        item.media.feedItemId = itemId;
        const mediaId: number = await EpisodeRepository.insertMedia(item.media);
        item.media.id = mediaId;
      }
      added.push(item);
    }
  }

  /**
   * 解析新单集落库时的 read 值：
   * 每 Feed newEpisodesAction 为 GLOBAL 时取全局偏好；ADD_TO_INBOX → -1（新）；
   * 自动下载启用时上游强制走 ADD_TO_INBOX（自动下载只考虑 Inbox 中的单集）。
   *
   * 收件箱基线（feed.inboxBaseline = 订阅 / 批量导入的时刻）：早于基线发布的单集属于
   * 「订阅前就已存在」的历史剧集，一律落「未播放」——只有晚于基线发布的单集才按上面的
   * 动作规则决定是否进收件箱。否则批量导入 86 个订阅会把整库历史剧集灌进收件箱
   * （实测上千条 read=-1，进「待处理」页严重卡顿）。
   */
  private static resolvePlayState(feed: Feed, item: FeedItem, initialSubscribe: boolean): number {
    if (InboxBaseline.isItemBefore(item, feed, initialSubscribe)) {
      return FeedItem.UNPLAYED;
    }
    let action: number = feed.newEpisodesAction;
    if (action === NewEpisodesAction.GLOBAL) {
      action = UserPreferences.getNewEpisodesAction();
    }
    const autoDownload: boolean = feed.autoDownloadEnabled && UserPreferences.getAutoDownload();
    if (autoDownload) {
      action = NewEpisodesAction.ADD_TO_INBOX;
    }
    if (action === NewEpisodesAction.ADD_TO_INBOX) {
      return FeedItem.NEW;
    }
    return FeedItem.UNPLAYED;
  }

  /** 手动刷新单个订阅（不受 keepUpdated 限制），返回新增数量 */
  static async refreshFeed(feedId: number): Promise<number> {
    const feed: Feed | undefined = await FeedRepository.getById(feedId);
    if (feed === undefined) {
      return 0;
    }
    const result = await FeedFetcher.fetchFeed(feed.downloadUrl, feed.username, feed.password);
    const merge: MergeResult = await RefreshService.mergeFeed(feed, result.feed);
    if (merge.count > 0) {
      const notifications: FeedNotificationEntry[] = [{ title: feed.getTitle(), count: merge.count }];
      await NotificationService.notifyNewEpisodesByFeed(notifications);
      await RefreshService.applyNewEpisodesAction(feed, merge.added);
      await AutoDownloadService.onNewItems(feed, merge.added);
    }
    RefreshService.publishFeedListUpdate();
    return merge.count;
  }

  /** 每 Feed 新剧集动作：加入队列（入队位置遵循全局 prefEnqueueLocation） */
  private static async applyNewEpisodesAction(feed: Feed, added: FeedItem[]): Promise<void> {
    if (feed.newEpisodesAction !== NewEpisodesAction.ADD_TO_QUEUE) {
      return;
    }
    for (const item of added) {
      try {
        await QueueEngine.add(item);
      } catch (error) {
        Logger.warn(TAG, 'auto enqueue failed for item ' + item.id + ': ' + (error as Error).message);
      }
    }
  }

  private static publishFeedListUpdate(): void {
    const data: FeedUpdateData = { feedId: 0 };
    EventHub.publish(EventType.FEED_LIST_UPDATE, data);
  }
}
