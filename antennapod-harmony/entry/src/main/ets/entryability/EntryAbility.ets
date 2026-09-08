import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbManager } from '../db/DbManager';
import { UserPreferences } from '../prefs/UserPreferences';
import { DownloadManager } from '../download/DownloadManager';
import { AvSessionBridge } from '../player/AvSessionBridge';
import { BackgroundPlaybackGuard } from '../player/BackgroundPlaybackGuard';
import { PlaybackOrchestrator } from '../player/PlaybackOrchestrator';

const TAG: string = 'APod/EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'EntryAbility onCreate');
    UserPreferences.init(this.context);
    PlaybackOrchestrator.start();
    DownloadManager.init(this.context);
    BackgroundPlaybackGuard.setContext(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed, code=%{public}d', err.code);
        return;
      }
      hilog.info(0x0000, TAG, 'loadContent succeeded');
    });
    DbManager.init(this.context).then(() => {
      hilog.info(0x0000, TAG, 'DbManager init ok');
    }).catch((error: Error) => {
      hilog.error(0x0000, TAG, 'DbManager init failed: %{public}s', error.message);
    });
    AvSessionBridge.init(this.context).then(() => {
      hilog.info(0x0000, TAG, 'AvSession init ok');
    }).catch((error: Error) => {
      hilog.error(0x0000, TAG, 'AvSession init failed: %{public}s', error.message);
    });
  }
}
