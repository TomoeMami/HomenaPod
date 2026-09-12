// Port of: net/download/service/feed/NewEpisodesNotification.java
import notificationManager from '@ohos.notificationManager';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import common from '@ohos.app.ability.common';
import { UserPreferences } from '../prefs/UserPreferences';
import { Logger } from '../utils/Logger';

const TAG: string = 'NotificationService';
const NOTIFICATION_ID: number = 1001;
/** 与 AppScope/app.json5 保持一致 */
const BUNDLE_NAME: string = 'com.homenapod.app';
const ABILITY_NAME: string = 'EntryAbility';

/** 单个订阅的新集统计（仅包含开启 episodeNotification 的订阅） */
export interface FeedNotificationEntry {
  title: string;
  count: number;
}

export class NotificationService {
  private static context: common.Context | undefined = undefined;

  static init(context: common.Context): void {
    NotificationService.context = context;
  }

  /**
   * 确保本应用已获得通知权限。
   * 未授权时 publish() 会直接失败（1600004 Notification disabled）且用户看不到任何提示，
   * 因此首次进入应用时主动弹一次系统授权框（对应上游 Android 13+ 的 POST_NOTIFICATIONS 申请）。
   * 注意：该 API 必须在 loadContent 之后调用。
   */
  static async ensureEnabled(): Promise<boolean> {
    const context: common.Context | undefined = NotificationService.context;
    if (context === undefined) {
      return false;
    }
    try {
      if (await notificationManager.isNotificationEnabled()) {
        return true;
      }
      await notificationManager.requestEnableNotification(context as common.UIAbilityContext);
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      Logger.info(TAG, 'notification enabled=' + enabled);
      return enabled;
    } catch (error) {
      Logger.warn(TAG, 'requestEnableNotification failed: ' + (error as Error).message);
      return false;
    }
  }

  static async notifyNewEpisodes(count: number): Promise<void> {
    if (count <= 0) {
      return;
    }
    await NotificationService.publish(count + ' 个新单集');
  }

  /**
   * 按订阅聚合通知：全局开关关闭时静默；文本逐行列出各订阅新增集数。
   * 与上游 NewEpisodesNotification 一致：只有 feed.episodeNotification 为真的订阅才计入。
   * 通知携带 wantAgent（点击进入应用）与操作按钮「查看新单集」。
   */
  static async notifyNewEpisodesByFeed(entries: FeedNotificationEntry[]): Promise<void> {
    let total: number = 0;
    const lines: string[] = [];
    for (const entry of entries) {
      if (entry.count <= 0) {
        continue;
      }
      total += entry.count;
      lines.push(entry.title + '：+' + entry.count);
    }
    if (total <= 0) {
      return;
    }
    if (!UserPreferences.getEpisodeNotification()) {
      Logger.info(TAG, 'episode notification disabled, skip ' + total + ' new episodes');
      return;
    }
    await NotificationService.publish(lines.join('\n'));
  }

  private static async publish(text: string): Promise<void> {
    try {
      if (!await notificationManager.isNotificationEnabled()) {
        Logger.warn(TAG, 'notification disabled for app, skip publish');
        return;
      }
    } catch (error) {
      Logger.warn(TAG, 'isNotificationEnabled failed: ' + (error as Error).message);
    }
    const agent: WantAgent | undefined = await NotificationService.createWantAgent();
    const request: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: 'HomenaPod',
          text: text
        }
      }
    };
    if (agent !== undefined) {
      request.wantAgent = agent;
      const button: notificationManager.NotificationActionButton = {
        title: NotificationService.openButtonTitle(),
        wantAgent: agent
      };
      request.actionButtons = [button];
    }
    try {
      await notificationManager.publish(request);
    } catch (error) {
      Logger.error(TAG, 'publish failed', new Error((error as Error).message));
    }
  }

  /** 点击通知/操作按钮进入应用主页 */
  private static async createWantAgent(): Promise<WantAgent | undefined> {
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      return await wantAgent.getWantAgent(info);
    } catch (error) {
      Logger.warn(TAG, 'create wantAgent failed: ' + (error as Error).message);
      return undefined;
    }
  }

  /** 操作按钮文案（取应用资源，取不到时用英文兜底） */
  private static openButtonTitle(): string {
    const context: common.Context | undefined = NotificationService.context;
    if (context === undefined) {
      return 'Open';
    }
    try {
      return context.resourceManager.getStringSync($r('app.string.notification_open'));
    } catch (error) {
      return 'Open';
    }
  }
}
