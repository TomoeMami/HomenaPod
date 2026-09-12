import { AbilityConstant, UIAbility, Want, ConfigurationConstant } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import i18n from '@ohos.i18n';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbManager } from '../db/DbManager';
import { UserPreferences } from '../prefs/UserPreferences';
import { DownloadManager } from '../download/DownloadManager';
import { NotificationService } from '../services/NotificationService';
import { AvSessionBridge } from '../player/AvSessionBridge';
import { BackgroundPlaybackGuard } from '../player/BackgroundPlaybackGuard';
import { PlaybackOrchestrator } from '../player/PlaybackOrchestrator';
import { WorkSchedulerManager } from '../work/WorkSchedulerManager';

const TAG: string = 'APod/EntryAbility';
/** 与 SettingsPage 的主题取值保持一致：0=跟随系统，1=浅色，2=深色 */
const THEME_DARK: number = 2;
const THEME_LIGHT: number = 1;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'EntryAbility onCreate');
    UserPreferences.init(this.context);
    PlaybackOrchestrator.start();
    DownloadManager.init(this.context);
    NotificationService.init(this.context);
    BackgroundPlaybackGuard.setContext(this.context);
    // 冷启动恢复定时刷新：workScheduler 任务不随进程重启自动恢复（对照上游每次启动 restartUpdateAlarm）
    WorkSchedulerManager.restore(this.context);
    EntryAbility.applySavedColorMode(this.context);
    EntryAbility.applySavedLanguage();
  }

  /** 启动时应用已保存的应用语言（'default' = 跟随系统） */
  private static applySavedLanguage(): void {
    const language: string = UserPreferences.getAppLanguage();
    if (language === '') {
      return;
    }
    try {
      i18n.System.setAppPreferredLanguage(language);
    } catch (error) {
      hilog.warn(0x0000, TAG, 'applyLanguage failed: %{public}s', (error as Error).message);
    }
  }

  /** 启动时恢复上次保存的深浅色模式（0=跟随系统） */
  private static applySavedColorMode(context: common.UIAbilityContext): void {
    const theme: number = UserPreferences.getTheme();
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (theme === THEME_DARK) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (theme === THEME_LIGHT) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    try {
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      hilog.warn(0x0000, TAG, 'applyColorMode failed: %{public}s', (error as Error).message);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 先初始化 DB 再加载首屏，避免页面 aboutToAppear 早于数据库就绪导致空列表
    DbManager.init(this.context).then(() => {
      hilog.info(0x0000, TAG, 'DbManager init ok');
      this.loadIndex(windowStage);
    }).catch((error: Error) => {
      hilog.error(0x0000, TAG, 'DbManager init failed: %{public}s', error.message);
      // 初始化失败也要渲染 UI，避免白屏
      this.loadIndex(windowStage);
    });
    AvSessionBridge.init(this.context).then(() => {
      hilog.info(0x0000, TAG, 'AvSession init ok');
    }).catch((error: Error) => {
      hilog.error(0x0000, TAG, 'AvSession init failed: %{public}s', error.message);
    });
  }

  private loadIndex(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed, code=%{public}d', err.code);
        return;
      }
      hilog.info(0x0000, TAG, 'loadContent succeeded');
      // UI 加载完成后申请通知权限（未授权时新单集通知会被系统静默丢弃）
      NotificationService.ensureEnabled().catch((error: Error) => {
        hilog.warn(0x0000, TAG, 'ensureEnabled failed: %{public}s', error.message);
      });
    });
  }

  /** 退出时释放长时任务，避免残留的前台任务影响下次启动 */
  onDestroy(): void {
    BackgroundPlaybackGuard.stop().catch((error: Error) => {
      hilog.warn(0x0000, TAG, 'stopBackgroundRunning failed: %{public}s', error.message);
    });
  }
}
