// Port of: playback/service/internal/PlaybackServiceTaskManager.java (position saving)
import { PlayerManager } from './PlayerManager';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { Playable } from '../model/Playable';
import { Logger } from '../utils/Logger';

const TAG: string = 'ProgressPersister';

export class ProgressPersister {
  private static lastSavedAt: number = 0;

  static async save(force: boolean = false): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable === undefined || playable.id <= 0) {
      return;
    }
    const now: number = Date.now();
    if (!force && now - ProgressPersister.lastSavedAt < 5000) {
      return;
    }
    const position: number = PlayerManager.getCurrentTime();
    try {
      // Playable.id 对应 FeedMedia.id（由调用方保证）
      await EpisodeRepository.updatePosition(playable.id, position);
      ProgressPersister.lastSavedAt = now;
    } catch (error) {
      Logger.error(TAG, 'save position failed', new Error((error as Error).message));
    }
  }
}
