// Port of: net/download/service/episode/{EpisodeDownloadWorker,DownloadAnnouncer}.java
import request from '@ohos.request';
import common from '@ohos.app.ability.common';
import { FeedMedia } from '../model/FeedMedia';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { EventHub, EventType, EpisodeDownloadData } from '../events/EventHub';
import { MimeTypeUtils } from '../utils/MimeTypeUtils';
import { Logger } from '../utils/Logger';

const TAG: string = 'DownloadManager';

export class DownloadManager {
  private static context: common.Context | undefined = undefined;
  private static tasks: Map<number, request.DownloadTask> = new Map<number, request.DownloadTask>();
  private static statusMap: Map<number, string> = new Map<number, string>();

  static init(context: common.Context): void {
    DownloadManager.context = context;
  }

  static async startDownload(media: FeedMedia): Promise<void> {
    if (DownloadManager.context === undefined) {
      throw new Error('DownloadManager not initialized');
    }
    if (DownloadManager.statusMap.has(media.id)) {
      return;
    }
    const extension: string = MimeTypeUtils.guessExtension(media.downloadUrl, media.mimeType);
    const filePath: string = DownloadManager.context.filesDir + '/downloads/' + media.id + extension;
    const config: request.DownloadConfig = {
      url: media.downloadUrl,
      filePath: filePath,
      enableMetered: true,
      enableRoaming: true
    };
    const task: request.DownloadTask = await request.downloadFile(DownloadManager.context, config);
    DownloadManager.tasks.set(media.id, task);
    DownloadManager.statusMap.set(media.id, 'RUNNING');
    const runningData: EpisodeDownloadData = { mediaId: media.id, state: 'RUNNING' };
    EventHub.publish(EventType.EPISODE_DOWNLOAD, runningData);

    task.on('progress', (receivedSize: number, totalSize: number) => {
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
      DownloadManager.statusMap.set(media.id, 'DONE');
      EpisodeRepository.updateMediaFile(media.id, filePath, media.size);
      const doneData: EpisodeDownloadData = { mediaId: media.id, state: 'DONE', filePath: filePath };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, doneData);
      Logger.info(TAG, 'download complete ' + media.id);
    });
    task.on('fail', (err: number) => {
      DownloadManager.tasks.delete(media.id);
      DownloadManager.statusMap.set(media.id, 'FAILED');
      const failData: EpisodeDownloadData = { mediaId: media.id, state: 'FAILED', code: err };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, failData);
    });
  }

  static async pause(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.pause();
      DownloadManager.statusMap.set(mediaId, 'PAUSED');
      const pausedData: EpisodeDownloadData = { mediaId: mediaId, state: 'PAUSED' };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, pausedData);
    }
  }

  static async resume(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.resume();
      DownloadManager.statusMap.set(mediaId, 'RUNNING');
      const resumedData: EpisodeDownloadData = { mediaId: mediaId, state: 'RUNNING' };
      EventHub.publish(EventType.EPISODE_DOWNLOAD, resumedData);
    }
  }

  static async remove(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.remove();
      DownloadManager.tasks.delete(mediaId);
    }
    DownloadManager.statusMap.delete(mediaId);
    const removedData: EpisodeDownloadData = { mediaId: mediaId, state: 'REMOVED' };
    EventHub.publish(EventType.EPISODE_DOWNLOAD, removedData);
  }

  static getStatus(mediaId: number): string {
    const value: string | undefined = DownloadManager.statusMap.get(mediaId);
    return value === undefined ? 'IDLE' : value;
  }
}
