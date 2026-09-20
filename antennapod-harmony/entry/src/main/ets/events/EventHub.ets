// Port of: event/ 模块的 EventBus 事件；封装 @ohos.events.emitter 为类型化事件中心
import emitter from '@ohos.events.emitter';

export class EventType {
  static readonly FEED_LIST_UPDATE: string = 'FeedListUpdateEvent';
  static readonly FEED_ITEM: string = 'FeedItemEvent';
  static readonly QUEUE: string = 'QueueEvent';
  static readonly PLAYER_STATUS: string = 'PlayerStatusEvent';
  static readonly PLAYBACK_POSITION: string = 'PlaybackPositionEvent';
  /**
   * 播放器被**程序**改动了位置（不是 timeUpdate 的自然推进）：目前只有「蓝牙断开后的补偿回退」。
   * 载荷是**改动后的目标位置**（`PlaybackPositionData.time`）—— 暂停态下不再有 timeUpdate，
   * 订阅方（PlaybackOrchestrator）据此把新位置立即落盘，否则冷启动会从回退前的位置继续。
   */
  static readonly PLAYBACK_SEEKED: string = 'PlaybackSeekedEvent';
  /** 换集（load 开始）：播控中心需要在 prepare 前就拿到新单集的元数据 */
  static readonly PLAYER_TRACK_CHANGED: string = 'PlayerTrackChangedEvent';
  static readonly PLAYBACK_SERVICE: string = 'PlaybackServiceEvent';
  static readonly EPISODE_DOWNLOAD: string = 'EpisodeDownloadEvent';
  static readonly DOWNLOAD_LOG: string = 'DownloadLogEvent';
  static readonly MESSAGE: string = 'MessageEvent';
  static readonly PLAYER_ERROR: string = 'PlayerErrorEvent';
  static readonly SPEED_CHANGED: string = 'SpeedChangedEvent';
  static readonly SLEEP_TIMER_UPDATED: string = 'SleepTimerUpdatedEvent';
  /** 单集状态（已播/未播、收藏）变化，驱动计数与列表刷新 */
  static readonly FEED_ITEM_UPDATE: string = 'FeedItemUpdateEvent';
  /** 每 Feed 设置（过滤器/排序/开关）变化 */
  static readonly FEED_UPDATE: string = 'FeedUpdateEvent';
  /** 下载队列构成变化（开始/完成/取消），驱动下载页与角标 */
  static readonly DOWNLOADS_CHANGED: string = 'DownloadsChangedEvent';
  /** 滑动动作配置变化（设置页保存后广播，各列表页重新读取左右滑动作） */
  static readonly SWIPE_ACTIONS_CHANGED: string = 'SwipeActionsChangedEvent';
  /** 影响列表显示的偏好变化（显示剩余时间 / 时长按倍速折算），队列页据此重新读取并重绘 */
  static readonly PREFS_CHANGED: string = 'PrefsChangedEvent';
  /**
   * 整库刷新开始/结束（对照上游 sticky `FeedUpdateRunningEvent`）：
   * 让任何入口发起的刷新都能驱动订阅页的下拉刷新指示。
   */
  static readonly REFRESH_STATE: string = 'RefreshStateEvent';
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

export interface PlayerTrackData {
  /** Playable.id（FeedMedia 主键），订阅方据此从 PlayerManager.getCurrent() 取完整对象 */
  assetId: number;
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

export interface FeedItemUpdateData {
  feedId: number;
  itemId: number;
}

export interface FeedUpdateData {
  feedId: number;
}

export interface DownloadsChangedData {
  active: number;
}

/** 整库刷新状态（对照上游 FeedUpdateRunningEvent.isFeedUpdateRunning） */
export interface RefreshStateData {
  running: boolean;
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

/** 单个订阅记录：token 用于精确退订，避免多页面共享事件时互相误删 */
class Subscription {
  token: number;
  callback: (data: object) => void;

  constructor(token: number, callback: (data: object) => void) {
    this.token = token;
    this.callback = callback;
  }
}

/** 每个事件类型只向 emitter 注册一次，内部分发给全部订阅者 */
const registries: Map<number, Subscription[]> = new Map<number, Subscription[]>();
let nextToken: number = 1;

function dispatch(id: number, data: object): void {
  const list: Subscription[] | undefined = registries.get(id);
  if (list === undefined) {
    return;
  }
  const snapshot: Subscription[] = list.slice();
  for (const sub of snapshot) {
    sub.callback(data);
  }
}

export class EventHub {
  static publish(type: string, data: object): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: eventId(type),
      priority: emitter.EventPriority.LOW
    };
    // emitter.emit 的第二个参数是 EventData，负载必须放在 data 字段里，
    // 否则订阅端 eventData.data 为 undefined，回调不会被触发。
    const eventData: emitter.EventData = { data: data as Record<string, Object> };
    emitter.emit(innerEvent, eventData);
  }

  /** 订阅并返回 token；页面退出时用 unsubscribeToken(token) 精确退订 */
  static subscribe(type: string, callback: (data: object) => void): number {
    const id: number = eventId(type);
    let list: Subscription[] | undefined = registries.get(id);
    if (list === undefined) {
      list = [];
      registries.set(id, list);
      const innerEvent: emitter.InnerEvent = {
        eventId: id,
        priority: emitter.EventPriority.LOW
      };
      emitter.on(innerEvent, (eventData: emitter.EventData): void => {
        if (eventData !== undefined && eventData.data !== undefined) {
          dispatch(id, eventData.data as object);
        }
      });
    }
    const token: number = nextToken++;
    list.push(new Subscription(token, callback));
    return token;
  }

  /** 精确退订单个订阅（推荐） */
  static unsubscribeToken(token: number): void {
    registries.forEach((list: Subscription[]) => {
      const index: number = list.findIndex((sub: Subscription) => sub.token === token);
      if (index >= 0) {
        list.splice(index, 1);
      }
    });
  }

  /** 退订某类型的全部订阅（仅用于页面独占事件，勿用于共享事件） */
  static unsubscribe(type: string): void {
    registries.delete(eventId(type));
  }
}
