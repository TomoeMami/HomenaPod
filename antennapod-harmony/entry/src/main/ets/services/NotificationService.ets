// Port of: net/download/service/feed/NewEpisodesNotification.java
import notificationManager from '@ohos.notificationManager';
import { Logger } from '../utils/Logger';

const TAG: string = 'NotificationService';
const NOTIFICATION_ID: number = 1001;

export class NotificationService {
  static async notifyNewEpisodes(count: number): Promise<void> {
    if (count <= 0) {
      return;
    }
    const request: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID,
      content: {
        notificationType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: 'AntennaPod',
          text: count + ' 个新单集'
        }
      }
    };
    try {
      await notificationManager.publish(request);
    } catch (error) {
      Logger.error(TAG, 'publish failed', new Error((error as Error).message));
    }
  }
}
