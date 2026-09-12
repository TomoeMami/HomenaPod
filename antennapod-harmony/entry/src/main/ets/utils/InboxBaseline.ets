// 收件箱基线（订阅 / 批量导入时刻）判定：纯逻辑，便于单测
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';

/**
 * 收件箱基线（`Feed.inboxBaseline`，毫秒时间戳，0 = 未设置）。
 *
 * 语义：**以订阅 / 批量导入的时刻为基准，只有晚于该时刻发布的单集才算「新」，才进收件箱**；
 * 早于基准发布的单集属于订阅前就已存在的历史内容，落库为「未播放」。
 *
 * 没有这层判定时，批量导入 OPML 会把整库历史剧集全部标成 `read = -1`（实测 86 个订阅
 * 产生 15519 条「新」单集），收件箱瞬间被灌满，「待处理」页也因上千行而卡顿。
 */
export class InboxBaseline {
  /**
   * 单集是否早于基线（= 属于历史内容）。
   *
   * - 有发布日期：严格比较，`pubDate <= 基线` 即历史；
   * - 无发布日期（`pubDate <= 0`）：只在首次订阅 / 批量导入时视为历史（此时源里全部内容
   *   都是导入前就存在的），之后的刷新沿用原有动作规则——否则「整源都不给日期」的订阅
   *   将永远进不了收件箱。
   * - 基线未设置（`<= 0`）：不做判定，保持原有行为（老库升级前的订阅）。
   */
  static isBefore(baseline: number, pubDate: number, initialSubscribe: boolean): boolean {
    if (baseline <= 0) {
      return false;
    }
    if (pubDate > 0) {
      return pubDate <= baseline;
    }
    return initialSubscribe;
  }

  /** Feed + FeedItem 形态的便捷入口 */
  static isItemBefore(item: FeedItem, feed: Feed, initialSubscribe: boolean): boolean {
    return InboxBaseline.isBefore(feed.inboxBaseline, item.pubDate, initialSubscribe);
  }
}
