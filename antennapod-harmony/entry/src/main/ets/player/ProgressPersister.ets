// Port of: playback/service/internal/PlaybackServiceTaskManager.java (position saving)
import { PlayerManager } from './PlayerManager';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { Playable } from '../model/Playable';
import { Logger } from '../utils/Logger';

const TAG: string = 'ProgressPersister';

export class ProgressPersister {
  private static lastSavedAt: number = 0;
  private static lastPosition: number = 0;
  private static lastMediaId: number = 0;

  /**
   * @param force 跳过 5s 节流
   * @param positionMs 指定要落盘的位置；负数（默认）表示读播放器当前位置。
   *        「蓝牙断开回退」用它传**刚算出来的目标位置**：AVPlayer 的 seek 是异步完成的，
   *        紧接着读 `getCurrentTime()` 很可能还是回退前的旧值。
   */
  static async save(force: boolean = false, positionMs: number = -1): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable === undefined || playable.id <= 0) {
      return;
    }
    const now: number = Date.now();
    if (!force && now - ProgressPersister.lastSavedAt < 5000) {
      return;
    }
    const position: number = positionMs >= 0 ? positionMs : PlayerManager.getCurrentTime();
    try {
      // Playable.id 对应 FeedMedia.id（由调用方保证）
      await EpisodeRepository.updatePosition(playable.id, position);
      await ProgressPersister.accumulatePlayedDuration(playable.id, position);
      ProgressPersister.lastSavedAt = now;
    } catch (error) {
      Logger.error(TAG, 'save position failed', new Error((error as Error).message));
    }
  }

  /** 重置基线（换集时调用，避免把上一集的位置差计入本集收听时长） */
  static resetBaseline(position: number = 0): void {
    ProgressPersister.lastPosition = position;
  }

  /**
   * 累计实际收听时长（统计页数据源）：
   * 换集后的首次保存只建立基线；只在位置前进且增量合理（>0 且不超过 10 分钟）时累加，seek 回退不计数。
   */
  private static async accumulatePlayedDuration(mediaId: number, position: number): Promise<void> {
    if (mediaId !== ProgressPersister.lastMediaId) {
      ProgressPersister.lastMediaId = mediaId;
      ProgressPersister.lastPosition = position;
      return;
    }
    const delta: number = position - ProgressPersister.lastPosition;
    ProgressPersister.lastPosition = position;
    if (delta <= 0 || delta > 10 * 60 * 1000) {
      return;
    }
    if (PlayerManager.getStatus() !== 'PLAYING') {
      return;
    }
    await EpisodeRepository.addPlayedDuration(mediaId, delta);
  }
}
