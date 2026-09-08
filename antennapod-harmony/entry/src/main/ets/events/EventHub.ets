// Port of: event/ 模块的 EventBus 事件；封装 @ohos.events.emitter 为类型化事件中心
import emitter from '@ohos.events.emitter';

export const EventType = {
  FEED_LIST_UPDATE: 'FeedListUpdateEvent',
  FEED_ITEM: 'FeedItemEvent',
  QUEUE: 'QueueEvent',
  PLAYER_STATUS: 'PlayerStatusEvent',
  PLAYBACK_POSITION: 'PlaybackPositionEvent',
  PLAYBACK_SERVICE: 'PlaybackServiceEvent',
  EPISODE_DOWNLOAD: 'EpisodeDownloadEvent',
  DOWNLOAD_LOG: 'DownloadLogEvent',
  MESSAGE: 'MessageEvent',
  PLAYER_ERROR: 'PlayerErrorEvent',
  SPEED_CHANGED: 'SpeedChangedEvent',
  SLEEP_TIMER_UPDATED: 'SleepTimerUpdatedEvent'
} as const;

const EVENT_BASE: number = 10000;
const activeEventIds: Map<string, number> = new Map<string, number>();

function eventId(type: string): number {
  let existing: number | undefined = activeEventIds.get(type);
  if (existing !== undefined) {
    return existing;
  }
  let hash: number = 0;
  for (let i: number = 0; i < type.length; i++) {
    hash = (hash * 31 + type.charCodeAt(i)) % 99999;
  }
  const id: number = EVENT_BASE + hash;
  activeEventIds.set(type, id);
  return id;
}

export class EventHub {
  static publish(type: string, data: object): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: eventId(type),
      priority: emitter.EventPriority.NORMAL
    };
    emitter.emit(innerEvent, data);
  }

  static subscribe(type: string, callback: (data: object) => void): number {
    const id: number = eventId(type);
    emitter.on(id, (eventData: emitter.EventData) => {
      if (eventData !== undefined && eventData.data !== undefined) {
        callback(eventData.data as object);
      }
    });
    return id;
  }

  static unsubscribe(type: string): void {
    const id: number = eventId(type);
    emitter.off(id);
  }
}
