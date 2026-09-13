import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import i18n from '@ohos.i18n';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
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
  /** 主窗口（主题/语言切换后重新下发状态栏配色要用） */
  private mainWindow: window.Window | undefined = undefined;

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
    // 沉浸式状态栏（全应用）：状态栏背景设为全透明，由各页面根容器的 expandSafeArea
    // 把页面背景（page_bg）绘制到状态栏区域。旧行为下状态栏是系统白底，与应用顶部的
    // #F1F3F5 之间有横向色差带（实测 y≈132 处分界）。
    try {
      this.mainWindow = windowStage.getMainWindowSync();
    } catch (error) {
      hilog.warn(0x0000, TAG, 'getMainWindowSync failed: %{public}s', (error as Error).message);
    }
    EntryAbility.applyImmersiveStatusBar(this.mainWindow, this.context);
    // 先初始化 DB 再加载首屏，避免页面 aboutToAppear 早于 DB 就绪导致空列表
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

  /**
   * 沉浸式状态栏：状态栏背景全透明，让页面自己的背景色透上来。
   *
   * 只改状态栏**背景**，不改窗口布局（不调用 setWindowLayoutFullScreen）：内容仍由系统安全区
   * 自动避开状态栏，各页面根容器只需 `expandSafeArea` 把背景绘制区上延即可——
   * 既不会遮住标题栏，也不需要在每个页面手算状态栏高度做 padding。
   *
   * 图标/文字颜色必须显式下发：背景设成透明后，系统无法再按背景亮度自动选图标色，
   * 深色主题下会继续用深色图标 → 黑底黑字（实测深色模式下状态栏整条不可见）。
   * 这里直接取当前主题的 text_primary（浅色 #DD000000 / 深色 #E5FFFFFF）。
   */
  private static applyImmersiveStatusBar(windowClass: window.Window | undefined,
                                         context: common.UIAbilityContext): void {
    if (windowClass === undefined) {
      return;
    }
    const props: window.SystemBarProperties = {
      statusBarColor: '#00000000',
      statusBarContentColor: EntryAbility.themeColor(context, 'text_primary', '#DD000000')
    };
    windowClass.setWindowSystemBarProperties(props).then(() => {
      hilog.info(0x0000, TAG, 'immersive status bar ok');
    }).catch((error: BusinessError) => {
      hilog.warn(0x0000, TAG, 'setWindowSystemBarProperties failed: %{public}s', error.message);
    });
  }

  /** 按当前配置解析颜色资源为 '#AARRGGBB'（失败时用兜底色） */
  private static themeColor(context: common.UIAbilityContext, name: string, fallback: string): string {
    try {
      const argb: number = context.resourceManager.getColorByNameSync(name) >>> 0;
      return '#' + argb.toString(16).padStart(8, '0');
    } catch (error) {
      hilog.warn(0x0000, TAG, 'resolve color %{public}s failed: %{public}s', name,
        (error as Error).message);
      return fallback;
    }
  }

  /** 深浅色模式 / 语言变化后重新下发状态栏配色（换主题时 text_primary 会变） */
  onConfigurationUpdate(newConfig: Configuration): void {
    EntryAbility.applyImmersiveStatusBar(this.mainWindow, this.context);
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
