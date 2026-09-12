// Port of: ui/screen/queue/QueueSortOrder + model/feed/FeedItem sorting helpers
// 纯函数排序工具：Feed 详情页与队列页共用；不 import 任何 @ohos.*，便于 Hypium 单测。
import { FeedItem } from '../model/FeedItem';
import { SortOrder } from '../model/Enums';

export class SortUtils {
  /** 按 6 种 SortOrder 排序（同值时回退到发布时间新→旧，保证稳定） */
  static sortItems(items: FeedItem[], order: SortOrder): FeedItem[] {
    const copy: FeedItem[] = items.slice();
    copy.sort((a: FeedItem, b: FeedItem): number => {
      let result: number = 0;
      if (order === SortOrder.DATE_NEW_OLD) {
        result = b.pubDate - a.pubDate;
      } else if (order === SortOrder.DATE_OLD_NEW) {
        result = a.pubDate - b.pubDate;
      } else if (order === SortOrder.TITLE_A_Z) {
        result = SortUtils.compareText(a.title, b.title);
      } else if (order === SortOrder.TITLE_Z_A) {
        result = SortUtils.compareText(b.title, a.title);
      } else if (order === SortOrder.DURATION_SHORT_LONG) {
        result = SortUtils.durationOf(a) - SortUtils.durationOf(b);
      } else if (order === SortOrder.DURATION_LONG_SHORT) {
        result = SortUtils.durationOf(b) - SortUtils.durationOf(a);
      }
      if (result === 0) {
        return b.pubDate - a.pubDate;
      }
      return result;
    });
    return copy;
  }

  /**
   * 队列排序（上游 `QueueSortOrder`）：在基础六项之外增加播客标题、随机、智能乱序。
   * `feedTitles` 提供 feedId → 播客标题，播客标题排序与随机/智能乱序的稳定性都依赖它。
   * 随机与智能乱序每次调用都重新洗牌（与上游 RANDOM / SMART_SHUFFLE 语义一致）。
   */
  static sortQueue(items: FeedItem[], order: SortOrder, feedTitles: Map<number, string>): FeedItem[] {
    if (order === SortOrder.RANDOM) {
      return SortUtils.shuffle(items);
    }
    if (order === SortOrder.SMART_SHUFFLE_OLD_NEW || order === SortOrder.SMART_SHUFFLE_NEW_OLD) {
      const shuffled: FeedItem[] = SortUtils.smartShuffle(items);
      return order === SortOrder.SMART_SHUFFLE_NEW_OLD ? shuffled.reverse() : shuffled;
    }
    if (order === SortOrder.FEED_TITLE_A_Z || order === SortOrder.FEED_TITLE_Z_A) {
      const copy: FeedItem[] = items.slice();
      copy.sort((a: FeedItem, b: FeedItem): number => {
        const titleA: string = SortUtils.feedTitleOf(a, feedTitles);
        const titleB: string = SortUtils.feedTitleOf(b, feedTitles);
        const result: number = order === SortOrder.FEED_TITLE_A_Z
          ? SortUtils.compareText(titleA, titleB)
          : SortUtils.compareText(titleB, titleA);
        if (result === 0) {
          return b.pubDate - a.pubDate;
        }
        return result;
      });
      return copy;
    }
    return SortUtils.sortItems(items, order);
  }

  private static feedTitleOf(item: FeedItem, feedTitles: Map<number, string>): string {
    const title: string | undefined = feedTitles.get(item.feedId);
    return title === undefined ? '' : title;
  }

  /** 随机打乱（Fisher-Yates） */
  static shuffle(items: FeedItem[]): FeedItem[] {
    const copy: FeedItem[] = items.slice();
    for (let i: number = copy.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: FeedItem = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  /**
   * 智能乱序：先按发布时间新→旧排序，再按订阅分组轮转交错，
   * 避免同一订阅的剧集在队列里聚集（上游 QueueSortOrder.SMART_SHUFFLE 语义）。
   */
  static smartShuffle(items: FeedItem[]): FeedItem[] {
    const sorted: FeedItem[] = SortUtils.sortItems(items, SortOrder.DATE_NEW_OLD);
    const groups: Map<number, FeedItem[]> = new Map<number, FeedItem[]>();
    const feedOrder: number[] = [];
    for (const item of sorted) {
      let bucket: FeedItem[] | undefined = groups.get(item.feedId);
      if (bucket === undefined) {
        bucket = [];
        groups.set(item.feedId, bucket);
        feedOrder.push(item.feedId);
      }
      bucket.push(item);
    }
    const result: FeedItem[] = [];
    let index: number = 0;
    let added: boolean = true;
    while (added) {
      added = false;
      for (const feedId of feedOrder) {
        const bucket: FeedItem[] | undefined = groups.get(feedId);
        if (bucket !== undefined && index < bucket.length) {
          result.push(bucket[index]);
          added = true;
        }
      }
      index++;
    }
    return result;
  }

  static durationOf(item: FeedItem): number {
    return item.media !== undefined ? item.media.duration : 0;
  }

  private static compareText(a: string, b: string): number {
    const x: string = a.toLowerCase();
    const y: string = b.toLowerCase();
    if (x < y) {
      return -1;
    }
    if (x > y) {
      return 1;
    }
    return 0;
  }
}
