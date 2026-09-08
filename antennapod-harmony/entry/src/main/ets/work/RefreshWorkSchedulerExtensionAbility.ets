// Port of: WorkManager FeedUpdateWorker -> HarmonyOS WorkSchedulerExtensionAbility
import { WorkSchedulerExtensionAbility, workScheduler } from '@kit.BackgroundTasksKit';
import { RefreshService } from '../services/RefreshService';
import { Logger } from '../utils/Logger';

const TAG: string = 'RefreshWork';

export default class RefreshWorkSchedulerExtensionAbility extends WorkSchedulerExtensionAbility {
  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    Logger.info(TAG, 'work start, workId=' + workInfo.workId);
    RefreshService.refreshAll().then((count: number) => {
      Logger.info(TAG, 'refresh done, new=' + count);
    }).catch((error: Error) => {
      Logger.error(TAG, 'refresh failed', error);
    });
  }

  onWorkStop(workInfo: workScheduler.WorkInfo): void {
    Logger.info(TAG, 'work stop, workId=' + workInfo.workId);
  }
}
