// Port of: WorkManager scheduling -> HarmonyOS workScheduler
import { workScheduler } from '@kit.BackgroundTasksKit';
import common from '@ohos.app.ability.common';
import { Logger } from '../utils/Logger';

const TAG: string = 'WorkSchedulerManager';
const WORK_ID: number = 1001;
const MIN_INTERVAL_MS: number = 2 * 60 * 60 * 1000;

export class WorkSchedulerManager {
  static schedule(context: common.Context, intervalMinutes: number): void {
    const intervalMs: number = Math.max(MIN_INTERVAL_MS, intervalMinutes * 60 * 1000);
    const workInfo: workScheduler.WorkInfo = {
      workId: WORK_ID,
      bundleName: context.applicationInfo.name,
      abilityName: 'RefreshWorkSchedulerExtensionAbility',
      networkType: workScheduler.NetworkType.NETWORK_TYPE_WIFI,
      isRepeat: true,
      repeatCycleTime: intervalMs,
      isPersisted: true
    };
    try {
      workScheduler.startWork(workInfo);
      Logger.info(TAG, 'scheduled, interval=' + intervalMs);
    } catch (error) {
      Logger.error(TAG, 'schedule failed', new Error((error as Error).message));
    }
  }

  static cancel(): void {
    try {
      const workInfo: workScheduler.WorkInfo = {
        workId: WORK_ID,
        bundleName: '',
        abilityName: ''
      };
      workScheduler.stopWork(workInfo, true);
    } catch (error) {
      Logger.error(TAG, 'cancel failed', new Error((error as Error).message));
    }
  }
}
