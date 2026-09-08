// Port of: event/ 模块的 EventBus 事件；封装 @ohos.events.emitter 为类型化事件中心
import emitter from '@ohos.events.emitter';

export class EventType {
  static readonly FEED_LIST_UPDATE: string = 'FeedListUpdateEvent';
  static readonly FEED_ITEM: string = 'FeedItemEvent';
  static readonly QUEUE: string = 'QueueEvent';
  static readonly PLAYER_STATUS: string = 'PlayerStatusEvent';
  static readonly PLAYBACK_POSITION: string = 'PlaybackPositionEvent';
  static readonly PLAYBACK_SERVICE: string = 'PlaybackServiceEvent';
  static readonly EPISODE_DOWNLOAD: string = 'EpisodeDownloadEvent';
  static readonly DOWNLOAD_LOG: string = 'DownloadLogEvent';
  static readonly MESSAGE: string = 'MessageEvent';
  static readonly PLAYER_ERROR: string = 'PlayerErrorEvent';
  static readonly SPEED_CHANGED: string = 'SpeedChangedEvent';
  static readonly SLEEP_TIMER_UPDATED: string = 'SleepTimerUpdatedEvent';
}

export interface EpisodeDownloadData {
  mediaId: number;
  state: string;
  received?: number;
  total?: number;
  filePath?: string;
  code?: number;
}

export interface QueueUpdatedData {
  items: number;
}

export interface PlayerStatusData {
  status: string;
}

export interface PlaybackPositionData {
  time: number;
  duration: number;
}

export interface PlayerErrorData {
  code: number;
  message: string;
}

export interface SpeedChangedData {
  speed: number;
}

export interface SleepTimerData {
  remainingMs: number;
}

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
      priority: emitter.EventPriority.LOW
    };
    emitter.emit(innerEvent, data);
  }

  static subscribe(type: string, callback: (data: object) => void): number {
    const id: number = eventId(type);
    const innerEvent: emitter.InnerEvent = {
      eventId: id,
      priority: emitter.EventPriority.LOW
    };
    emitter.on(innerEvent, (eventData: emitter.EventData): void => {
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
