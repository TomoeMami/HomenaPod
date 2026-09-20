// 播放编排：订阅 PlayerStatusEvent，在 completed 时按重复模式处理，并自动连播队列下一集
import { EventHub, EventType } from '../events/EventHub';
import { QueueEngine } from './QueueEngine';
import { PlayerManager } from './PlayerManager';
import { SleepTimer } from './SleepTimer';
import { ProgressPersister } from './ProgressPersister';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { DownloadManager } from '../download/DownloadManager';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { Playable } from '../model/Playable';
import { UserPreferences } from '../prefs/UserPreferences';
import { Logger } from '../utils/Logger';

const TAG: string = 'PlaybackOrchestrator';
/** 与 Feed.autoDeleteAction 的取值约定（对照上游 AutoDeleteAction） */
const AUTO_DELETE_NEVER: number = 0;
const AUTO_DELETE_GLOBAL: number = 1;
const AUTO_DELETE_ALWAYS: number = 2;
const AUTO_DELETE_WHEN_PLAYED: number = 3;

export class PlaybackOrchestrator {
  static start(): void {
    EventHub.subscribe(EventType.PLAYER_STATUS, (data: object) => {
      const record = data as Record<string, string>;
      const status: string | undefined = record['status'];
      if (status === 'COMPLETED') {
        Logger.info(TAG, 'completed');
        PlaybackOrchestrator.onCompleted();
      }
    });
    // 播放中定期落盘进度（上游 PlaybackServiceTaskManager 的 PositionSaver）：
    // 只靠播放页的定时器不够——在队列页用迷你条后台播放时进度不会保存，
    // 换集后队列里刚播过的那一集就会显示成很久以前的位置。save() 内部 5s 节流。
    EventHub.subscribe(EventType.PLAYBACK_POSITION, (data: object) => {
      ProgressPersister.save();
    });
    // 程序改动位置（目前只有「蓝牙断开后的补偿回退」）：暂停态没有 timeUpdate，
    // 5s 节流的周期保存不会再覆盖到新位置，这里按事件带回的目标位置强制落盘一次。
    EventHub.subscribe(EventType.PLAYBACK_SEEKED, (data: object) => {
      const record: Record<string, number> = data as Record<string, number>;
      const time: number | undefined = record['time'];
      ProgressPersister.save(true, time !== undefined ? time : -1).catch((error: Error) => {
        Logger.warn(TAG, 'save after seek failed: ' + error.message);
      });
    });
    // 睡眠定时器渐弱音量：注入音量回调，页面不可见时也生效
    SleepTimer.setFadeHandler((volume: number) => {
      PlayerManager.setVolume(volume);
    });
  }

  private static async onCompleted(): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    const repeatMode: number = UserPreferences.getRepeatMode();
    // 单集循环：重播当前集，不计入已播、不连播
    if (repeatMode === 1 && playable !== undefined) {
      Logger.info(TAG, 'repeat one, reload current episode');
      await PlayerManager.load(playable, 0, true);
      return;
    }
    await PlaybackOrchestrator.markCompleted();
    // 连播：移除刚播完的一集并播放队列中它之后的一集；列表循环时播到队尾回到队首
    await QueueEngine.autoAdvance(repeatMode === 2);
  }

  /** 播放结束时落盘进度、标记已播放，并按每 Feed 自动删除策略清理文件 */
  private static async markCompleted(): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable === undefined) {
      return;
    }
    try {
      await ProgressPersister.save(true);
      if (playable.feedItemId > 0) {
        await EpisodeRepository.markPlayed(playable.feedItemId, true);
        await PlaybackOrchestrator.applyAutoDelete(playable.feedItemId);
      }
    } catch (error) {
      Logger.error(TAG, 'markCompleted failed', new Error((error as Error).message));
    }
  }

  /** 自动删除：播放后删除 / 跟随全局开关 */
  private static async applyAutoDelete(feedItemId: number): Promise<void> {
    const item: FeedItem | undefined = await EpisodeRepository.getById(feedItemId);
    if (item === undefined || item.media === undefined || item.media.fileUrl === '') {
      return;
    }
    const feed: Feed | undefined = await FeedRepository.getById(item.feedId);
    const action: number = feed !== undefined ? feed.autoDeleteAction : AUTO_DELETE_NEVER;
    let shouldDelete: boolean = false;
    if (action === AUTO_DELETE_WHEN_PLAYED || action === AUTO_DELETE_ALWAYS) {
      shouldDelete = true;
    } else if (action === AUTO_DELETE_GLOBAL && UserPreferences.getAutoDelete()) {
      shouldDelete = true;
    }
    if (!shouldDelete) {
      return;
    }
    if (UserPreferences.getDeleteRemovesFromQueue()) {
      await QueueEngine.remove(item.id);
    }
    await DownloadManager.deleteFile(item.media);
    Logger.info(TAG, 'auto deleted download for item ' + item.id);
  }
}
