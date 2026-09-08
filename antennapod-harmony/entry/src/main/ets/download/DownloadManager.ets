// Port of: net/download/service/episode/{EpisodeDownloadWorker,DownloadAnnouncer}.java
import request from '@ohos.request';
import common from '@ohos.app.ability.common';
import { FeedMedia } from '../model/FeedMedia';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { EventHub, EventType } from '../events/EventHub';
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
    EventHub.publish(EventType.EPISODE_DOWNLOAD, { mediaId: media.id, state: 'RUNNING' });

    task.on('progress', (receivedSize: number, totalSize: number) => {
      EventHub.publish(EventType.EPISODE_DOWNLOAD, {
        mediaId: media.id,
        state: 'PROGRESS',
        received: receivedSize,
        total: totalSize
      });
    });
    task.on('complete', () => {
      DownloadManager.tasks.delete(media.id);
      DownloadManager.statusMap.set(media.id, 'DONE');
      EpisodeRepository.updateMediaFile(media.id, filePath, media.size);
      EventHub.publish(EventType.EPISODE_DOWNLOAD, { mediaId: media.id, state: 'DONE', filePath: filePath });
      Logger.info(TAG, 'download complete ' + media.id);
    });
    task.on('fail', (err: number) => {
      DownloadManager.tasks.delete(media.id);
      DownloadManager.statusMap.set(media.id, 'FAILED');
      EventHub.publish(EventType.EPISODE_DOWNLOAD, { mediaId: media.id, state: 'FAILED', code: err });
    });
  }

  static async pause(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.pause();
      DownloadManager.statusMap.set(mediaId, 'PAUSED');
      EventHub.publish(EventType.EPISODE_DOWNLOAD, { mediaId: mediaId, state: 'PAUSED' });
    }
  }

  static async resume(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.resume();
      DownloadManager.statusMap.set(mediaId, 'RUNNING');
      EventHub.publish(EventType.EPISODE_DOWNLOAD, { mediaId: mediaId, state: 'RUNNING' });
    }
  }

  static async remove(mediaId: number): Promise<void> {
    const task: request.DownloadTask | undefined = DownloadManager.tasks.get(mediaId);
    if (task !== undefined) {
      await task.remove();
      DownloadManager.tasks.delete(mediaId);
    }
    DownloadManager.statusMap.delete(mediaId);
    EventHub.publish(EventType.EPISODE_DOWNLOAD, { mediaId: mediaId, state: 'REMOVED' });
  }

  static getStatus(mediaId: number): string {
    const value: string | undefined = DownloadManager.statusMap.get(mediaId);
    return value === undefined ? 'IDLE' : value;
  }
}
