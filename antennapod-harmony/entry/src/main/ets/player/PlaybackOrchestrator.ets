// 播放编排：订阅 PlayerStatusEvent，在 completed 时自动连播队列下一集
import { EventHub, EventType } from '../events/EventHub';
import { QueueEngine } from './QueueEngine';
import { Logger } from '../utils/Logger';

const TAG: string = 'PlaybackOrchestrator';

export class PlaybackOrchestrator {
  static start(): void {
    EventHub.subscribe(EventType.PLAYER_STATUS, (data: object) => {
      const record = data as Record<string, string>;
      const status: string | undefined = record['status'];
      if (status === 'COMPLETED') {
        Logger.info(TAG, 'completed, auto advance');
        QueueEngine.autoAdvance();
      }
    });
  }
}
