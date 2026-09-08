// Port of: playback/service/PlaybackService.java queue semantics + ui/screen/queue/QueueFragment.java
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { Playable } from '../model/Playable';
import { QueueRepository } from '../db/repositories/QueueRepository';
import { QueueItem } from '../model/QueueItem';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { EventHub, EventType, QueueUpdatedData } from '../events/EventHub';
import { PlayerManager } from './PlayerManager';
import { Logger } from '../utils/Logger';

const TAG: string = 'QueueEngine';

export class QueueEngine {
  private static items: FeedItem[] = [];

  static async load(): Promise<void> {
    const rows: QueueItem[] = await QueueRepository.list();
    const loaded: FeedItem[] = [];
    for (const row of rows) {
      const item: FeedItem | undefined = await EpisodeRepository.getById(row.feedItemId);
      if (item !== undefined) {
        loaded.push(item);
      }
    }
    QueueEngine.items = loaded;
    const loadData: QueueUpdatedData = { items: loaded.length };
    EventHub.publish(EventType.QUEUE, loadData);
  }

  static getItems(): FeedItem[] {
    return QueueEngine.items;
  }

  static async add(item: FeedItem): Promise<void> {
    const exists: boolean = QueueEngine.items.some((entry: FeedItem) => entry.id === item.id);
    if (exists) {
      return;
    }
    QueueEngine.items.push(item);
    await QueueRepository.add(item.id, item.feedId);
    const addData: QueueUpdatedData = { items: QueueEngine.items.length };
    EventHub.publish(EventType.QUEUE, addData);
  }

  static async remove(itemId: number): Promise<void> {
    QueueEngine.items = QueueEngine.items.filter((item: FeedItem) => item.id !== itemId);
    await QueueRepository.remove(itemId);
    const removeData: QueueUpdatedData = { items: QueueEngine.items.length };
    EventHub.publish(EventType.QUEUE, removeData);
  }

  static async clear(): Promise<void> {
    QueueEngine.items = [];
    await QueueRepository.clear();
    const clearData: QueueUpdatedData = { items: 0 };
    EventHub.publish(EventType.QUEUE, clearData);
  }

  static async move(itemId: number, targetIndex: number): Promise<void> {
    const currentIndex: number = QueueEngine.items.findIndex((item: FeedItem) => item.id === itemId);
    if (currentIndex < 0) {
      return;
    }
    const moved: FeedItem = QueueEngine.items[currentIndex];
    QueueEngine.items.splice(currentIndex, 1);
    QueueEngine.items.splice(targetIndex, 0, moved);
    await QueueRepository.move(itemId, targetIndex);
    const moveData: QueueUpdatedData = { items: QueueEngine.items.length };
    EventHub.publish(EventType.QUEUE, moveData);
  }

  static nextItem(): FeedItem | undefined {
    if (QueueEngine.items.length === 0) {
      return undefined;
    }
    return QueueEngine.items[0];
  }

  static toPlayable(item: FeedItem): Playable | undefined {
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      return undefined;
    }
    return new Playable(
      media.id,
      item.id,
      item.title,
      'Podcast',
      media.downloadUrl,
      media.fileUrl,
      media.duration,
      media.position,
      media.getMediaType()
    );
  }

  static log(): void {
    Logger.info(TAG, 'queue size=' + QueueEngine.items.length);
  }

  static async autoAdvance(): Promise<void> {
    const next: FeedItem | undefined = QueueEngine.nextItem();
    if (next === undefined) {
      return;
    }
    await QueueEngine.remove(next.id);
    const playable: Playable | undefined = QueueEngine.toPlayable(next);
    if (playable !== undefined) {
      await PlayerManager.load(playable, 0, true);
    }
  }


}
