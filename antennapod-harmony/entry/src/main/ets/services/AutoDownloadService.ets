// Port of: net/download/service/autodownload/{AutomaticDownloadManager,EpisodeAutomaticDownloadAlgorithm}.java
import connection from '@ohos.net.connection';
import batteryInfo from '@ohos.batteryInfo';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { DownloadManager } from '../download/DownloadManager';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { UserPreferences } from '../prefs/UserPreferences';
import { Logger } from '../utils/Logger';

const TAG: string = 'AutoDownloadService';

export class AutoDownloadService {
  /**
   * 刷新产生新单集后调用：
   * 全局开关 + 每 Feed autoDownloadEnabled + 单集 autoDownloadEnabled（由 FeedFilter 判定）
   * + 下载条件（仅 WiFi / 仅充电）+ 缓存集数上限 全部满足才下载。
   */
  static async onNewItems(feed: Feed, items: FeedItem[]): Promise<void> {
    if (items.length === 0) {
      return;
    }
    if (!UserPreferences.getAutoDownload()) {
      return;
    }
    if (!feed.autoDownloadEnabled) {
      Logger.info(TAG, 'feed ' + feed.id + ' auto download disabled');
      return;
    }
    if (!AutoDownloadService.conditionsOk()) {
      Logger.info(TAG, 'download conditions not met, skip auto download');
      return;
    }
    const limit: number = UserPreferences.getEpisodeCacheCount();
    let downloaded: number = await EpisodeRepository.countDownloaded();
    for (const item of items) {
      if (!item.autoDownloadEnabled) {
        continue;
      }
      const media = item.media;
      if (media === undefined || media.downloadUrl === '') {
        continue;
      }
      if (downloaded >= limit) {
        Logger.info(TAG, 'cache limit reached (' + limit + '), stop auto download');
        return;
      }
      try {
        await DownloadManager.startDownload(media, item.title);
        downloaded++;
      } catch (error) {
        Logger.warn(TAG, 'auto download failed for item ' + item.id + ': ' + (error as Error).message);
      }
    }
  }

  /** 下载条件判定；检测失败时放行并记日志，避免权限缺失导致自动下载完全失效 */
  static conditionsOk(): boolean {
    if (UserPreferences.getAutoDownloadWifiOnly() && AutoDownloadService.isMetered()) {
      return false;
    }
    // 上游 prefEnableAutoDownloadOnBattery 语义为「允许在电池供电时下载」（默认允许）
    if (!UserPreferences.getAutoDownloadOnBattery() && !AutoDownloadService.isCharging()) {
      return false;
    }
    return true;
  }

  static isMetered(): boolean {
    try {
      return connection.isDefaultNetMeteredSync();
    } catch (error) {
      Logger.warn(TAG, 'metered check failed, assume wifi: ' + (error as Error).message);
      return false;
    }
  }

  static isCharging(): boolean {
    try {
      const status: batteryInfo.BatteryChargeState = batteryInfo.chargingStatus;
      return status === batteryInfo.BatteryChargeState.ENABLE
        || status === batteryInfo.BatteryChargeState.FULL;
    } catch (error) {
      Logger.warn(TAG, 'charging check failed, assume charging: ' + (error as Error).message);
      return true;
    }
  }
}
