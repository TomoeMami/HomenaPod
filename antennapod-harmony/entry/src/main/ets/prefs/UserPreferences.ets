// Port of: storage/preferences/src/main/java/de/danoeh/antennapod/storage/preferences/UserPreferences.java
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

const PREF_NAME: string = 'UserPreferences';

export class UserPreferences {
  private static instance: preferences.Preferences | undefined = undefined;

  static init(context: common.Context): void {
    if (UserPreferences.instance !== undefined) {
      return;
    }
    const options: preferences.Options = { name: PREF_NAME };
    UserPreferences.instance = preferences.getPreferencesSync(context, options);
  }

  private static getPrefs(): preferences.Preferences {
    if (UserPreferences.instance === undefined) {
      throw new Error('UserPreferences not initialized');
    }
    return UserPreferences.instance;
  }

  static getTheme(): number {
    return UserPreferences.getPrefs().getSync('prefTheme', 0) as number;
  }

  static setTheme(value: number): void {
    UserPreferences.getPrefs().putSync('prefTheme', value);
    UserPreferences.getPrefs().flush();
  }

  static getDefaultPlaybackSpeed(): number {
    return UserPreferences.getPrefs().getSync('prefPlaybackSpeed', 1.0) as number;
  }

  static setDefaultPlaybackSpeed(value: number): void {
    UserPreferences.getPrefs().putSync('prefPlaybackSpeed', value);
    UserPreferences.getPrefs().flush();
  }

  static getSkipSilence(): boolean {
    return UserPreferences.getPrefs().getSync('prefSkipSilence', false) as boolean;
  }

  static getStreamOverDownload(): boolean {
    return UserPreferences.getPrefs().getSync('prefStreamOverDownload', false) as boolean;
  }

  static setStreamOverDownload(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefStreamOverDownload', value);
    UserPreferences.getPrefs().flush();
  }

  static getMobileUpdateAllowed(): boolean {
    const value: string = UserPreferences.getPrefs().getSync('prefMobileUpdateTypes', 'wifi_only') as string;
    return value === 'wifi_and_mobile';
  }

  static setMobileUpdateAllowed(value: boolean): void {
    const keyValue: string = value ? 'wifi_and_mobile' : 'wifi_only';
    UserPreferences.getPrefs().putSync('prefMobileUpdateTypes', keyValue);
    UserPreferences.getPrefs().flush();
  }

  static getUpdateIntervalMinutes(): number {
    return UserPreferences.getPrefs().getSync('prefAutoUpdateInterval', 360) as number;
  }

  static setUpdateIntervalMinutes(value: number): void {
    UserPreferences.getPrefs().putSync('prefAutoUpdateInterval', value);
    UserPreferences.getPrefs().flush();
  }

  static getEnqueueLocation(): number {
    return UserPreferences.getPrefs().getSync('prefEnqueueLocation', 0) as number;
  }

  static setEnqueueLocation(value: number): void {
    UserPreferences.getPrefs().putSync('prefEnqueueLocation', value);
    UserPreferences.getPrefs().flush();
  }

  static getEpisodeCacheSizeMb(): number {
    return UserPreferences.getPrefs().getSync('prefEpisodeCacheSize', 20) as number;
  }

  static getLastPlayedFeedMediaId(): number {
    return UserPreferences.getPrefs().getSync('prefLastPlayedFeedMediaId', -1) as number;
  }

  static setLastPlayedFeedMediaId(value: number): void {
    UserPreferences.getPrefs().putSync('prefLastPlayedFeedMediaId', value);
    UserPreferences.getPrefs().flush();
  }

  static getDefaultPage(): string {
    return UserPreferences.getPrefs().getSync('prefDefaultPage', 'subscriptions') as string;
  }
}
