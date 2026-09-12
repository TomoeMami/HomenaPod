// Port of: net/download/service/episode/{EpisodeDownloadWorker,DownloadAnnouncer}.java
import request from '@ohos.request';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { FeedMedia } from '../model/FeedMedia';
import { FeedItem } from '../model/FeedItem';
import { DownloadLogEntry } from '../model/DownloadLogEntry';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { DownloadLogRepository } from '../db/repositories/DownloadLogRepository';
import { EventHub, EventType, EpisodeDownloadData, DownloadsChangedData } from '../events/EventHub';
import { MimeTypeUtils } from '../utils/MimeTypeUtils';
import { DownloadErrorLabel } from '../common/DownloadErrorLabel';
import { Logger } from '../utils/Logger';

const TAG: string = 'DownloadManager';
/** DownloadLog.feedfiletype：对应上游 FeedFileType.FEEDMEDIA */
const FEED_FILE_TYPE_MEDIA: number = 2;
/** DownloadLog.reason：0=用户主动触发 */
const REASON_USER: number = 0;

export class DownloadManager {
  private static context: common.Context | undefined = undefined;
  private static tasks: Map<number, request.DownloadTask> = new Map<number, request.DownloadTask>();
  private static statusMap: Map<number, string> = new Map<number, string>();
  private static titles: Map<number, string> = new Map<number, string>();
  /** 任务对应的落盘路径；取消/失败时据此清理残留文件，否则下次下载会因"文件已存在"失败 */
  private static paths: Map<number, string> = new Map<number, string>();
  /**
   * mediaId -> 已接收字节 / 总字节（总字节 0 = 服务端未给 Content-Length）。
   * 对照上游 `DownloadServiceInterface.getProgress(url)`：进度存服务侧，列表每行按需读取，
   * 这样任何页面（订阅详情 / 全库总表）都能画进度环，不必各自缓存事件负载。
   */
  private static received: Map<number, number> = new Map<number, number>();
  private static totals: Map<number, number> = new Map<number, number>();

  static init(context: common.Context): void {
    DownloadManager.context = context;
  }

  /** 会话内下载任务状态快照（重启后为空，页面状态应以 FeedMedia.fileUrl 为准） */
  static getActiveTasks(): Map<number, string> {
    const snapshot: Map<number, string> = new Map<number, string>();
    DownloadManager.statusMap.forEach((value: string, key: number) => {
      snapshot.set(key, value);
    });
    return snapshot;
  }

  static getTitle(mediaId: number): string {
    const value: string | undefined = DownloadManager.titles.get(mediaId);
    return value === undefined ? '' : value;
  }

  /** 触发单集下载；title 仅用于下载日志展示 */
  static async startDownload(media: FeedMedia, title: string = ''): Promise<void> {
    if (DownloadManager.context === undefined) {
      throw new Error('DownloadManager not initialized');
    }
    if (DownloadManager.statusMap.has(media.id)) {
      return;
    }
    if (media.downloadUrl === '') {
      throw new Error('该单集没有可下载的音频地址');
    }
    DownloadManager.titles.set(media.id, title);
    const extension: string = MimeTypeUtils.guessExtension(media.downloadUrl, media.mimeType);
    const dir: string = DownloadManager.context.filesDir + '/downloads';
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const filePath: string = dir + '/' + media.id + extension;
    // 取消/中断留下的残留文件会让 request.downloadFile 直接失败（legacy DownloadConfig 无 overwrite 字段）
    DownloadManager.deleteLocalFile(filePath);
    DownloadManager.paths.set(media.id, filePath);
    // 任务创建前就置为 RUNNING 并广播：列表行立刻出现进度等待环（对照上游
    // `EpisodeItemViewHolder.bind()`：isDownloadingEpisode 为真就 setPercentage + setIndeterminate）
    DownloadManager.received.delete(media.id);
    DownloadManager.totals.delete(media.id);
    DownloadManager.statusMap.set(media.id, 'RUNNING');
    const runningData: EpisodeDownloadData = { mediaId: media.id, state: 'RUNNING' };
    EventHub.publish(EventType.EPISODE_DOWNLOAD, runningData);
    DownloadManager.publishChanged();

    const config: request.DownloadConfig = {
      url: media.downloadUrl,
      filePath: filePath,
      enableMetered: true,
      enableRoaming: true
    };
    let task: request.DownloadTask;
    try {
      task = await request.downloadFile(DownloadManager.context, config);
    } catch (error) {
      // 任务没能建起来（URL 非法 / 无网络 / 权限）：撤掉 RUNNING，否则该单集永远停在"下载中"
      DownloadManager.statusMap.delete(media.id);
      DownloadManager.paths.delete(media.id);
      DownloadManager.received.delete(media.id);
      DownloadManager.totals.delete(media.id);
      const startFailData: EpisodeDownloadData = { mediaId: media.id, state: 'FAILED' };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, startFailData);
      DownloadManager.publishChanged();
      throw error as Error;
    }
    DownloadManager.tasks.set(media.id, task);

    task.on('progress', (receivedSize: number, totalSize: number) => {
      DownloadManager.received.set(media.id, receivedSize);
      DownloadManager.totals.set(media.id, totalSize);
      const progressData: EpisodeDownloadData = {
        mediaId: media.id,
        state: 'PROGRESS',
        received: receivedSize,
        total: totalSize
      };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, progressData);
    });
    task.on('complete', () => {
      DownloadManager.tasks.delete(media.id);
      DownloadManager.paths.delete(media.id);
      DownloadManager.received.delete(media.id);
      DownloadManager.totals.delete(media.id);
      DownloadManager.statusMap.set(media.id, 'DONE');
      let size: number = media.size;
      try {
        size = fs.statSync(filePath).size;
      } catch (error) {
        // 取不到真实大小时保留 feed 中的声明值
      }
      // 先落库再广播：订阅方收到 DONE 会立刻重查数据库，file_url 未落盘的话行还是"未下载"
      EpisodeRepository.updateMediaFile(media.id, filePath, size)
        .then(() => DownloadManager.writeLog(media.id, true, '下载完成'))
        .then(() => {
          const doneData: EpisodeDownloadData = { mediaId: media.id, state: 'DONE', filePath: filePath };
          EventHub.publish(EventType.EPISODE_DOWNLOAD, doneData);
          DownloadManager.publishChanged();
          Logger.info(TAG, 'download complete ' + media.id);
        })
        .catch((error: Error) => {
          Logger.warn(TAG, 'save media file failed: ' + error.message);
        });
    });
    task.on('fail', (err: number) => {
      DownloadManager.tasks.delete(media.id);
      DownloadManager.paths.delete(media.id);
      DownloadManager.received.delete(media.id);
      DownloadManager.totals.delete(media.id);
      // 失败后残留的半截文件不可续传（任务已销毁），清掉以免阻塞重试
      DownloadManager.deleteLocalFile(filePath);
      DownloadManager.statusMap.set(media.id, 'FAILED');
      // 同样先写日志再广播：下载页收到 FAILED 会立刻重查下载记录
      DownloadManager.writeLog(media.id, false, DownloadErrorLabel.detail(err)).then(() => {
        const failData: EpisodeDownloadData = { mediaId: media.id, state: 'FAILED', code: err };
        EventHub.publish(EventType.EPISODE_DOWNLOAD, failData);
        DownloadManager.publishChanged();
      });
      Logger.warn(TAG, 'download failed ' + media.id + ' code=' + err);
    });
  }

  static async pause(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.pause();
      DownloadManager.statusMap.set(mediaId, 'PAUSED');
      const pausedData: EpisodeDownloadData = { mediaId: mediaId, state: 'PAUSED' };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, pausedData);
      DownloadManager.publishChanged();
    }
  }

  static async resume(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.resume();
      DownloadManager.statusMap.set(mediaId, 'RUNNING');
      const resumedData: EpisodeDownloadData = { mediaId: mediaId, state: 'RUNNING' };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, resumedData);
      DownloadManager.publishChanged();
    }
  }

  static async remove(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.remove();
      DownloadManager.tasks.delete(mediaId);
    }
    // 取消下载：request 只会删任务，不会删已落盘的部分文件
    const partial: string | undefined = DownloadManager.paths.get(mediaId);
    if (partial !== undefined) {
      DownloadManager.deleteLocalFile(partial);
      DownloadManager.paths.delete(mediaId);
    }
    // 取消下载即关闭该单集的自动下载标记（对照上游 CancelDownloadActionButton.disableAutoDownload()）
    try {
      const item: FeedItem | undefined = await EpisodeRepository.getByMediaId(mediaId);
      if (item !== undefined && item.autoDownloadEnabled) {
        await EpisodeRepository.setAutoDownloadEnabled(item.id, false);
      }
    } catch (error) {
      Logger.warn(TAG, 'disable auto download failed: ' + (error as Error).message);
    }
    DownloadManager.statusMap.delete(mediaId);
    DownloadManager.titles.delete(mediaId);
    DownloadManager.received.delete(mediaId);
    DownloadManager.totals.delete(mediaId);
    const removedData: EpisodeDownloadData = { mediaId: mediaId, state: 'REMOVED' };
    EventHub.publish(EventType.EPISODE_DOWNLOAD, removedData);
    DownloadManager.publishChanged();
  }

  /**
   * 删除已下载的本地文件并清空 FeedMedia.file_url（单集记录保留，可重新下载或在线播放）。
   * 若文件已被外部删除，同样清空引用，避免播放时指向失效路径。
   */
  static async deleteFile(media: FeedMedia): Promise<void> {
    if (media.fileUrl !== '') {
      DownloadManager.deleteLocalFile(media.fileUrl);
    }
    await EpisodeRepository.clearMediaFile(media.id);
    DownloadManager.statusMap.delete(media.id);
    DownloadManager.titles.delete(media.id);
    DownloadManager.paths.delete(media.id);
    DownloadManager.received.delete(media.id);
    DownloadManager.totals.delete(media.id);
    const removedData: EpisodeDownloadData = { mediaId: media.id, state: 'REMOVED' };
    EventHub.publish(EventType.EPISODE_DOWNLOAD, removedData);
    DownloadManager.publishChanged();
  }

  /** 尽力删除本地文件；不存在或已被外部删除都不算错误 */
  private static deleteLocalFile(filePath: string): void {
    try {
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (error) {
      Logger.warn(TAG, 'delete file failed: ' + (error as Error).message);
    }
  }

  static getStatus(mediaId: number): string {
    const value: string | undefined = DownloadManager.statusMap.get(mediaId);
    return value === undefined ? 'IDLE' : value;
  }

  /**
   * 下载进度百分比（0–100）；-1 表示该单集当前没有下载任务（调用方据此隐藏进度指示）。
   * 对照上游 `DownloadServiceInterface.getProgress(url)`（0–100，供 `EpisodeItemViewHolder`
   * 换算成 0–1 交给 CircularProgressBar）。
   */
  static getProgressPercent(mediaId: number): number {
    const state: string = DownloadManager.getStatus(mediaId);
    if (state !== 'RUNNING' && state !== 'PAUSED') {
      return -1;
    }
    const received: number | undefined = DownloadManager.received.get(mediaId);
    const total: number | undefined = DownloadManager.totals.get(mediaId);
    if (received === undefined || total === undefined || total <= 0) {
      return 0;
    }
    const percent: number = Math.floor(received * 100 / total);
    return percent > 100 ? 100 : percent;
  }

  /**
   * 进度是否不可确定：服务端没给 Content-Length（总字节未知）时为真。
   * 对照上游 `EpisodeItemViewHolder`：`isEpisodeQueued()` 时 CircularProgressBar 用虚线等待态。
   */
  static isProgressIndeterminate(mediaId: number): boolean {
    const state: string = DownloadManager.getStatus(mediaId);
    if (state !== 'RUNNING' && state !== 'PAUSED') {
      return false;
    }
    const total: number | undefined = DownloadManager.totals.get(mediaId);
    return total === undefined || total <= 0;
  }

  private static publishChanged(): void {
    const data: DownloadsChangedData = { active: DownloadManager.statusMap.size };
    EventHub.publish(EventType.DOWNLOADS_CHANGED, data);
  }

  /** 写 DownloadLog 表（此前该表零写入，下载页永远为空）；调用方可等待写入完成再广播事件 */
  private static async writeLog(mediaId: number, successful: boolean, detail: string): Promise<void> {
    const title: string = DownloadManager.getTitle(mediaId);
    const entry: DownloadLogEntry = new DownloadLogEntry(
      0, mediaId, FEED_FILE_TYPE_MEDIA, REASON_USER, successful, Date.now(), detail,
      title === '' ? '#' + mediaId : title
    );
    try {
      await DownloadLogRepository.add(entry);
      // 下载记录变化（对照上游 DownloadLogEvent）：首页「管理下载」等订阅方据此刷新
      const logData: DownloadsChangedData = { active: DownloadManager.statusMap.size };
      EventHub.publish(EventType.DOWNLOAD_LOG, logData);
    } catch (error) {
      Logger.warn(TAG, 'write download log failed: ' + (error as Error).message);
    }
  }
}
