// Port of: Android Foreground Service -> HarmonyOS backgroundTaskManager AUDIO_PLAYBACK 长时任务
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import common from '@ohos.app.ability.common';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';

const TAG: string = 'BackgroundPlaybackGuard';

export class BackgroundPlaybackGuard {
  private static running: boolean = false;
  private static context: common.Context | undefined = undefined;

  static setContext(context: common.Context): void {
    BackgroundPlaybackGuard.context = context;
  }

  static async start(): Promise<void> {
    if (BackgroundPlaybackGuard.running || BackgroundPlaybackGuard.context === undefined) {
      return;
    }
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: BackgroundPlaybackGuard.context.applicationInfo.name,
          abilityName: 'EntryAbility'
        }
      ],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
    try {
      await backgroundTaskManager.startBackgroundRunning(
        BackgroundPlaybackGuard.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      );
      BackgroundPlaybackGuard.running = true;
      Logger.info(TAG, 'continuous task started');
    } catch (error) {
      Logger.error(TAG, 'startBackgroundRunning failed', new Error((error as Error).message));
    }
  }

  static async stop(): Promise<void> {
    if (!BackgroundPlaybackGuard.running || BackgroundPlaybackGuard.context === undefined) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(BackgroundPlaybackGuard.context);
      BackgroundPlaybackGuard.running = false;
      Logger.info(TAG, 'continuous task stopped');
    } catch (error) {
      Logger.error(TAG, 'stopBackgroundRunning failed', new Error((error as Error).message));
    }
  }

  static isRunning(): boolean {
    return BackgroundPlaybackGuard.running;
  }
}
