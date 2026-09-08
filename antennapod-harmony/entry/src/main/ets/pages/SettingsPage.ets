import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { UserPreferences } from '../prefs/UserPreferences';
import { WorkSchedulerManager } from '../work/WorkSchedulerManager';
import { ImageCache } from '../services/ImageCache';

@Component
export struct SettingsPage {
  @State theme: number = 0;
  @State streamOverDownload: boolean = false;
  @State speedText: string = '1.0x';
  @State intervalText: string = '360';
  @State message: string = '';

  build() {
    Column({ space: 12 }) {
      Text($r('app.string.tab_settings')).fontSize(22).fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 16, top: 8 })
      Text(this.message).fontSize(13).fontColor('#2962FF')
      Row() {
        Text($r('app.string.setting_theme')).fontSize(15).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.theme === 2 })
          .onChange((isOn: boolean) => {
            this.theme = isOn ? 2 : 1;
            UserPreferences.setTheme(this.theme);
          })
      }
      .width('90%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(8)

      Row() {
        Text($r('app.string.setting_stream_first')).fontSize(15).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.streamOverDownload })
          .onChange((isOn: boolean) => {
            this.streamOverDownload = isOn;
            UserPreferences.setStreamOverDownload(isOn);
          })
      }
      .width('90%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(8)

      Row() {
        Text($r('app.string.setting_speed')).fontSize(15).layoutWeight(1)
        Text(this.speedText).fontSize(14)
      }
      .width('90%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(8)
      .onClick(() => {
        // MVP: 固定 1.5x 示例；后续接入 SpeedDialog
        UserPreferences.setDefaultPlaybackSpeed(1.5);
        this.speedText = '1.5x';
      })

      Row({ space: 8 }) {
        Text($r('app.string.setting_schedule_refresh')).fontSize(15).layoutWeight(1)
        TextInput({ text: this.intervalText, placeholder: $r('app.string.setting_interval_hint') })
          .width(90)
          .onChange((value: string) => {
            this.intervalText = value;
          })
        Button($r('app.string.setting_schedule_apply'))
          .onClick(() => {
            const interval: number = Number(this.intervalText);
            if (Number.isFinite(interval) && interval >= 120) {
              UserPreferences.setUpdateIntervalMinutes(interval);
              const context = getContext(this) as common.Context;
              WorkSchedulerManager.schedule(context, interval);
              this.message = getContext(this).resourceManager.getStringSync($r('app.string.schedule_set')) + interval;
            } else {
              this.message = getContext(this).resourceManager.getStringSync($r('app.string.schedule_invalid'));
            }
          })
        Button($r('app.string.setting_schedule_cancel'))
          .onClick(() => {
            WorkSchedulerManager.cancel();
            this.message = getContext(this).resourceManager.getStringSync($r('app.string.schedule_cancelled'));
          })
      }
      .width('90%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(8)

      Row() {
        Text($r('app.string.setting_opml')).fontSize(15).layoutWeight(1)
        Button($r('app.string.opml_export'))
          .onClick(() => {
            router.pushUrl({ url: 'pages/OpmlPage' });
          })
      }
      .width('90%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(8)

      Row() {
        Text($r('app.string.setting_clear_cache')).fontSize(15).layoutWeight(1)
        Button($r('app.string.setting_clear_cache_button'))
          .onClick(() => {
            ImageCache.clearCache(getContext(this));
            this.message = getContext(this).resourceManager.getStringSync($r('app.string.cache_cleared'));
          })
      }
      .width('90%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(8)
    }
    .width('100%')
    .height('100%')
  }

  onAppear(): void {
    this.theme = UserPreferences.getTheme();
    this.streamOverDownload = UserPreferences.getStreamOverDownload();
    const speed: number = UserPreferences.getDefaultPlaybackSpeed();
    this.speedText = speed.toFixed(1) + 'x';
    this.intervalText = String(UserPreferences.getUpdateIntervalMinutes());
  }
}
