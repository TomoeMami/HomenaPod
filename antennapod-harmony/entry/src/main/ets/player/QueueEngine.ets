// Port of: playback/service/PlaybackService.java queue semantics + ui/screen/queue/QueueFragment.java
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { Playable } from '../model/Playable';
import { SortOrder, EnqueueLocation } from '../model/Enums';
import { QueueRepository } from '../db/repositories/QueueRepository';
import { QueueItem } from '../model/QueueItem';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { Feed } from '../model/Feed';
import { EventHub, EventType, QueueUpdatedData } from '../events/EventHub';
import { UserPreferences } from '../prefs/UserPreferences';
import { SortUtils } from '../utils/SortUtils';
import { PlayerManager } from './PlayerManager';
import { Logger } from '../utils/Logger';

const TAG: string = 'QueueEngine';

export class QueueEngine {
  private static items: FeedItem[] = [];

  /**
   * 队列 DB 操作的串行化闸门。
   * `QueueRepository.replaceOrder` 是「先清空再逐条插入」，中间存在一段空队列窗口；
   * 并发的 load() 若读到这个窗口，内存队列会被清空，之后任何一次落库都会把队列真的清掉
   * （实测：拖拽落库时并发 load 命中窗口 → 队列被清空）。所有队列读写都排队走这里。
   */
  private static gate: Promise<void> = Promise.resolve();

  private static async exclusive(task: () => Promise<void>): Promise<void> {
    const run: Promise<void> = QueueEngine.gate.then(task, task);
    QueueEngine.gate = run.then((): void => {
    }, (): void => {
    });
    await run;
  }

  static async load(): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      const rows: QueueItem[] = await QueueRepository.list();
      const loaded: FeedItem[] = [];
      for (const row of rows) {
        const item: FeedItem | undefined = await EpisodeRepository.getById(row.feedItemId);
        if (item !== undefined) {
          loaded.push(item);
        }
      }
      QueueEngine.items = loaded;
    });
    // 注意：load() 是只读操作，绝不能在这里 publish(QUEUE)。
    // QueuePage/Index 都订阅 QUEUE 并回调 load()，一旦 load 再发事件就会形成
    // load -> publish -> load 的无限循环，把 UI 线程拖死（表现为页面空白）。
    // 队列变更事件统一由 publish()（add/remove/move/排序等写操作）发出。
  }

  static getItems(): FeedItem[] {
    return QueueEngine.items;
  }

  /**
   * 加入队列。location 省略时使用全局 prefEnqueueLocation
   * （BACK 队尾 / FRONT 队首 / AFTER_CURRENTLY_PLAYING 当前播放之后）。
   * 开启「保持排序」时，插入后立即按 prefQueueKeepSortedOrder 重排
   * （对照上游 DBWriter.addQueueItem 在 isQueueKeepSorted 时插到排序位置）。
   */
  static async add(item: FeedItem, location: number = -1): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      const exists: boolean = QueueEngine.items.some((entry: FeedItem) => entry.id === item.id);
      if (exists) {
        return;
      }
      const target: number = location >= 0 ? location : UserPreferences.getEnqueueLocation();
      let index: number = QueueEngine.items.length;
      if (target === EnqueueLocation.FRONT) {
        index = 0;
      } else if (target === EnqueueLocation.AFTER_CURRENTLY_PLAYING) {
        const current: Playable | undefined = PlayerManager.getCurrent();
        if (current !== undefined) {
          const currentIndex: number = QueueEngine.items.findIndex((entry: FeedItem) => entry.id === current.feedItemId);
          index = currentIndex >= 0 ? currentIndex + 1 : QueueEngine.items.length;
        }
      }
      QueueEngine.items.splice(index, 0, item);
      if (UserPreferences.getQueueKeepSorted()) {
        // 保持排序：插入后整体重排（槽位可能变化，逐条 addAt 无法表达新顺序）
        await QueueEngine.applyKeepSorted();
        await QueueEngine.persistOrderLocked();
        QueueEngine.publish();
        return;
      }
      await QueueRepository.addAt(item.id, item.feedId, index);
      QueueEngine.publish();
    });
  }

  /** 保持排序开启时按当前偏好顺序重排内存队列（关闭时为空操作） */
  private static async applyKeepSorted(): Promise<void> {
    if (!UserPreferences.getQueueKeepSorted()) {
      return;
    }
    const order: number = UserPreferences.getQueueKeepSortedOrder();
    QueueEngine.items = SortUtils.sortQueue(QueueEngine.items, order,
      await QueueEngine.feedTitles(QueueEngine.items));
  }

  /**
   * 队列项所属订阅的标题（播客标题排序用）。
   * 队列可能包含未订阅剧集，因此按 id 直接查库而不是走 listSubscribed。
   */
  static async feedTitles(items: FeedItem[]): Promise<Map<number, string>> {
    const ids: number[] = [];
    for (const item of items) {
      ids.push(item.feedId);
    }
    const feeds: Feed[] = await FeedRepository.listByIds(ids);
    const titles: Map<number, string> = new Map<number, string>();
    for (const feed of feeds) {
      titles.set(feed.id, feed.getTitle());
    }
    return titles;
  }

  /**
   * 把某一集插回指定位置（供「移出队列」撤销使用，对照上游
   * `DBWriter.addQueueItemAt`）。已在队列中时先移除再插入。
   */
  static async addAt(item: FeedItem, index: number): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      QueueEngine.items = QueueEngine.items.filter((entry: FeedItem) => entry.id !== item.id);
      const target: number = index < 0 ? 0 : (index > QueueEngine.items.length ? QueueEngine.items.length : index);
      QueueEngine.items.splice(target, 0, item);
      await QueueEngine.persistOrderLocked();
      QueueEngine.publish();
    });
  }

  /** 把某一集移到队首（上游 MoveToTopSwipeAction / moveQueueItemsToTop） */
  static async moveToTop(itemId: number): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      const from: number = QueueEngine.items.findIndex((entry: FeedItem) => entry.id === itemId);
      if (from < 0) {
        return;
      }
      const moved: FeedItem = QueueEngine.items[from];
      QueueEngine.items.splice(from, 1);
      QueueEngine.items.splice(0, 0, moved);
      await QueueEngine.persistOrderLocked();
      QueueEngine.publish();
    });
  }

  /** 把某一集移到队尾（上游 MoveToBottomSwipeAction / moveQueueItemsToBottom） */
  static async moveToBottom(itemId: number): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      const from: number = QueueEngine.items.findIndex((entry: FeedItem) => entry.id === itemId);
      if (from < 0) {
        return;
      }
      const moved: FeedItem = QueueEngine.items[from];
      QueueEngine.items.splice(from, 1);
      QueueEngine.items.push(moved);
      await QueueEngine.persistOrderLocked();
      QueueEngine.publish();
    });
  }

  /**
   * 开始播放前的入队保证（对照上游 PlaybackService.startPlaying → addPlayableToQueue：
   * 任何一次「开始播放某一集」都会把它放进队列，已在队列中的不做任何改动）。
   * 位置由 add() 按全局 prefEnqueueLocation 决定（默认队尾）。
   * 页面可能从未加载过队列，这里先从 DB 校准一次内存队列，避免同一集重复入队。
   */
  static async ensureQueued(item: FeedItem): Promise<void> {
    await QueueEngine.load();
    await QueueEngine.add(item);
  }

  static async remove(itemId: number): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      QueueEngine.items = QueueEngine.items.filter((item: FeedItem) => item.id !== itemId);
      await QueueRepository.remove(itemId);
      QueueEngine.publish();
    });
  }

  static async clear(): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      QueueEngine.items = [];
      await QueueRepository.clear();
      QueueEngine.publish();
    });
  }

  static async move(itemId: number, targetIndex: number): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      const currentIndex: number = QueueEngine.items.findIndex((item: FeedItem) => item.id === itemId);
      if (currentIndex < 0) {
        return;
      }
      const moved: FeedItem = QueueEngine.items[currentIndex];
      QueueEngine.items.splice(currentIndex, 1);
      QueueEngine.items.splice(targetIndex, 0, moved);
      await QueueRepository.move(itemId, targetIndex);
      QueueEngine.publish();
    });
  }

  /**
   * 队列中「当前播放项之后」的一集（对照上游 DBReader.getNextInQueue）。
   * 当前播放项不在队列里（从订阅页直接播放）时回落到队首。
   */
  static nextItem(): FeedItem | undefined {
    if (QueueEngine.items.length === 0) {
      return undefined;
    }
    const current: Playable | undefined = PlayerManager.getCurrent();
    if (current !== undefined && current.feedItemId > 0) {
      const index: number = QueueEngine.items.findIndex((entry: FeedItem) => entry.id === current.feedItemId);
      if (index >= 0) {
        return index + 1 < QueueEngine.items.length ? QueueEngine.items[index + 1] : undefined;
      }
    }
    return QueueEngine.items[0];
  }

  /**
   * 队列排序：单集标题 / 播客标题 / 时长 / 日期 / 随机 / 智能乱序（对照上游 QueueSortDialog
   * 的排序项集合），结果整体落库。
   */
  static async applySort(order: SortOrder): Promise<void> {
    QueueEngine.items = SortUtils.sortQueue(QueueEngine.items, order,
      await QueueEngine.feedTitles(QueueEngine.items));
    await QueueEngine.persistOrder();
  }

  static async shuffle(): Promise<void> {
    QueueEngine.items = SortUtils.shuffle(QueueEngine.items);
    await QueueEngine.persistOrder();
  }

  static async smartShuffle(): Promise<void> {
    QueueEngine.items = SortUtils.smartShuffle(QueueEngine.items);
    await QueueEngine.persistOrder();
  }

  /** 按当前内存顺序整体重写 Queue 表（供批量"移到顶部/底部"使用） */
  static async replaceOrder(items: FeedItem[]): Promise<void> {
    QueueEngine.items = items;
    await QueueEngine.persistOrder();
  }

  private static async persistOrder(): Promise<void> {
    await QueueEngine.exclusive(async (): Promise<void> => {
      await QueueEngine.persistOrderLocked();
      QueueEngine.publish();
    });
  }

  /** 落库但不取闸门、不发事件（供已经持有闸门的调用方使用，避免重入死锁） */
  private static async persistOrderLocked(): Promise<void> {
    const rows: QueueItem[] = [];
    for (const item of QueueEngine.items) {
      rows.push(new QueueItem(0, item.id, item.feedId));
    }
    await QueueRepository.replaceOrder(rows);
  }

  static async toPlayable(item: FeedItem): Promise<Playable | undefined> {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      return undefined;
    }
    let feedTitle: string = 'Podcast';
    let speed: number = 1.0;
    let skipIntro: number = 0;
    let skipEnding: number = 0;
    let volumeAdaption: number = 0;
    // 封面：单集封面优先，回落到播客封面（播放页 / 迷你播放条共用）
    let imageUrl: string = item.imageUrl;
    const feed: Feed | undefined = await FeedRepository.getById(item.feedId);
    if (feed !== undefined) {
      feedTitle = feed.getTitle();
      speed = feed.feedPlaybackSpeed > 0 ? feed.feedPlaybackSpeed : 1.0;
      skipIntro = feed.feedSkipIntro;
      skipEnding = feed.feedSkipEnding;
      volumeAdaption = feed.feedVolumeAdaption;
      if (imageUrl === '') {
        imageUrl = feed.imageUrl;
      }
    }
    return new Playable(
      media.id,
      item.id,
      item.title,
      feedTitle,
      media.downloadUrl,
      media.fileUrl,
      media.duration,
      media.position,
      media.getMediaType(),
      speed,
      skipIntro,
      skipEnding,
      volumeAdaption,
      imageUrl
    );
  }

  static log(): void {
    Logger.info(TAG, 'queue size=' + QueueEngine.items.length);
  }

  /**
   * 自动连播：移除刚播完的一集，并播放队列中「它之后」的一集
   * （对照上游 onPostPlayback → DBWriter.removeQueueItem + DBReader.getNextInQueue）。
   * 因此播放顺序始终是「从当前播放项往下」的队列顺序，与拖拽排序结果一致。
   * `loop` 为 true（列表循环）时，播到队尾回到队首继续。
   */
  static async autoAdvance(loop: boolean = false): Promise<void> {
    const current: Playable | undefined = PlayerManager.getCurrent();
    const next: FeedItem | undefined = QueueEngine.nextItem();
    const wrapCandidate: FeedItem | undefined = QueueEngine.items.length > 0 ? QueueEngine.items[0] : undefined;
    if (current !== undefined && current.feedItemId > 0) {
      const index: number = QueueEngine.items.findIndex((entry: FeedItem) => entry.id === current.feedItemId);
      if (index >= 0) {
        await QueueEngine.remove(current.feedItemId);
      }
    }
    let target: FeedItem | undefined = next;
    if (target === undefined && loop) {
      target = wrapCandidate;
    }
    if (target === undefined) {
      return;
    }
    const playable: Playable | undefined = await QueueEngine.toPlayable(target);
    if (playable !== undefined) {
      await PlayerManager.load(playable, 0, true);
    }
  }

  private static publish(): void {
    const data: QueueUpdatedData = { items: QueueEngine.items.length };
    EventHub.publish(EventType.QUEUE, data);
  }
}
