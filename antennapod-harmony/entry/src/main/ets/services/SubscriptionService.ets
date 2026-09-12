// Port of: net/download/service/feed/local/LocalFeedUpdater.java + FeedDatabaseWriter.java
import fs from '@ohos.file.fs';
import { FeedFetcher } from './FeedFetcher';
import { RefreshService, MergeResult } from './RefreshService';
import { Feed } from '../model/Feed';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { Logger } from '../utils/Logger';

const TAG: string = 'SubscriptionService';

export class SubscriptionService {
  /**
   * 订阅订阅源；私有 Feed 可传 username/password（HTTP Basic 认证）。
   *
   * @param inboxBaseline 收件箱基线（毫秒时间戳）。批量导入时由调用方传入**同一个**导入时刻，
   *        使整批订阅共用一条基线；单个添加留空则取本次订阅时刻。
   *        源里早于该时刻发布的剧集属于历史内容，落库为「未播放」，不进收件箱。
   */
  static async subscribe(url: string, username: string = '', password: string = '',
                         inboxBaseline: number = 0): Promise<Feed> {
    // 已订阅同一 feed 时直接返回，避免重复插入（OPML 重复导入 / 重复添加）
    const existing: Feed | undefined = await FeedRepository.getByDownloadUrl(url);
    if (existing !== undefined) {
      Logger.info(TAG, 'already subscribed, reuse feed id=' + existing.id);
      return existing;
    }
    const result = await FeedFetcher.fetchFeed(url, username, password);
    const feed: Feed = result.feed;
    feed.downloadUrl = url;
    feed.username = username;
    feed.password = password;
    feed.inboxBaseline = inboxBaseline > 0 ? inboxBaseline : Date.now();
    const feedId: number = await FeedRepository.insert(feed);
    feed.id = feedId;
    // 复用刷新路径的合并逻辑：分页订阅（atom:link rel="next"）会继续抓取后续页，
    // 此前这里只插入首页 items，导致分页源首次订阅只拿到 2 集。
    // initialSubscribe=true：本次收录的单集都早于基线，一律落「未播放」，不灌收件箱。
    const merge: MergeResult = await RefreshService.mergeFeed(feed, feed, true);
    Logger.info(TAG, 'subscribed feed id=' + feedId + ' items=' + merge.count
      + ' baseline=' + feed.inboxBaseline);
    return feed;
  }

  /**
   * 只「登记」订阅，不抓取（OPML 批量导入用，对照上游 `OpmlImportActivity.doImport` +
   * `FeedUpdateManager.runOnce`）：写一行 Feed（标题 / URL / 收件箱基线）就返回，
   * 剧集与封面由调用方随后触发的 `RefreshService.refreshAll()` 在后台补齐。
   *
   * 旧实现逐条 `await subscribe()`（抓源 + 解析 + 落库全部单集）：86 个订阅要让用户在
   * 导入页对着转圈等好几分钟，而返回订阅页时后台其实早已把订阅写进去了。
   *
   * @returns 新增的 Feed；该 URL 已订阅过时返回 undefined（不重复插行）
   */
  static async subscribeDeferred(title: string, url: string, link: string,
                                 inboxBaseline: number = 0): Promise<Feed | undefined> {
    const existing: Feed | undefined = await FeedRepository.getByDownloadUrl(url);
    if (existing !== undefined) {
      Logger.info(TAG, 'already subscribed, skip deferred import id=' + existing.id);
      return undefined;
    }
    const feed: Feed = Feed.pending(url, title !== '' ? title : url, link,
      inboxBaseline > 0 ? inboxBaseline : Date.now());
    const feedId: number = await FeedRepository.insert(feed);
    feed.id = feedId;
    Logger.info(TAG, 'registered feed id=' + feedId + ' url=' + url);
    return feed;
  }

  /** 取消订阅：删除下载文件 + 剧集数据 + feed 记录 */
  static async unsubscribe(feedId: number): Promise<void> {
    const files: string[] = await EpisodeRepository.listDownloadedFilesByFeed(feedId);
    for (const path of files) {
      try {
        if (fs.accessSync(path)) {
          fs.unlinkSync(path);
        }
      } catch (error) {
        Logger.warn(TAG, 'delete download failed: ' + path + ' ' + (error as Error).message);
      }
    }
    await EpisodeRepository.deleteByFeed(feedId);
    await FeedRepository.delete(feedId);
    Logger.info(TAG, 'unsubscribed feed id=' + feedId + ' files=' + files.length);
  }
}
