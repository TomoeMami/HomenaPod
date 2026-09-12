// Port of: WorkManager scheduling -> HarmonyOS workScheduler
import { workScheduler } from '@kit.BackgroundTasksKit';
import common from '@ohos.app.ability.common';
import { UserPreferences } from '../prefs/UserPreferences';
import { Logger } from '../utils/Logger';

const TAG: string = 'WorkSchedulerManager';
const WORK_ID: number = 1001;
const MIN_INTERVAL_MS: number = 2 * 60 * 60 * 1000;
/** 0 = 从不自动刷新（上游 feed_refresh_interval_values 首项） */
const INTERVAL_NEVER: number = 0;

export class WorkSchedulerManager {
  static schedule(context: common.Context, intervalMinutes: number): void {
    const intervalMs: number = Math.max(MIN_INTERVAL_MS, intervalMinutes * 60 * 1000);
    // 移动网络更新类型（上游 prefMobileUpdateTypes.feed_refresh）：允许时 WiFi/移动网络都触发
    const allowMobile: boolean = UserPreferences.isMobileUpdateAllowed('feed_refresh');
    const workInfo: workScheduler.WorkInfo = {
      workId: WORK_ID,
      bundleName: context.applicationInfo.name,
      abilityName: 'RefreshWorkSchedulerExtensionAbility',
      networkType: allowMobile
        ? workScheduler.NetworkType.NETWORK_TYPE_ANY
        : workScheduler.NetworkType.NETWORK_TYPE_WIFI,
      isRepeat: true,
      repeatCycleTime: intervalMs,
      isPersisted: true
    };
    try {
      workScheduler.startWork(workInfo);
      Logger.info(TAG, 'scheduled, interval=' + intervalMs + ', allowMobile=' + allowMobile);
    } catch (error) {
      const message: string = (error as Error).message;
      // 9700005 = 任务已存在：冷启动重复登记属正常，不是失败
      if (message.indexOf('9700005') >= 0) {
        Logger.info(TAG, 'work already registered, skip');
        return;
      }
      Logger.error(TAG, 'schedule failed', new Error(message));
    }
  }

  /**
   * 冷启动恢复定时刷新（对照上游 MainActivity 每次启动都 restartUpdateAlarm）。
   * workScheduler 的任务不会随进程重启自动恢复，必须每次启动重新登记；
   * 间隔为 0（从不）时不登记。
   */
  static restore(context: common.Context): void {
    const intervalMinutes: number = UserPreferences.getUpdateIntervalMinutes();
    if (intervalMinutes <= INTERVAL_NEVER) {
      Logger.info(TAG, 'auto update disabled, skip restore');
      return;
    }
    WorkSchedulerManager.schedule(context, intervalMinutes);
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
