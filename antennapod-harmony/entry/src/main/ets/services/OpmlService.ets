// Port of: storage/importexport OpmlImporter/OpmlExporter
import { Feed } from '../model/Feed';
import { SubscriptionService } from './SubscriptionService';
import { XmlReader, XmlTag } from '../parser/XmlReader';
import { Logger } from '../utils/Logger';

const TAG: string = 'OpmlService';

export interface OpmlOutline {
  text: string;
  xmlUrl: string;
  htmlUrl: string;
}

export class OpmlService {
  static exportOpml(feeds: Feed[]): string {
    let body: string = '<?xml version="1.0" encoding="UTF-8"?>\n<opml version="2.0">\n<head><title>HomenaPod Subscriptions</title></head>\n<body>\n';
    for (const feed of feeds) {
      const title: string = OpmlService.escapeXml(feed.getTitle());
      const xmlUrl: string = OpmlService.escapeXml(feed.downloadUrl);
      const htmlUrl: string = OpmlService.escapeXml(feed.link);
      body += `  <outline text="${title}" title="${title}" type="rss" xmlUrl="${xmlUrl}" htmlUrl="${htmlUrl}"/>\n`;
    }
    body += '</body>\n</opml>\n';
    return body;
  }

  /**
   * 批量导入 OPML 中的订阅源：只登记订阅行（不抓取），返回新增的 Feed。
   *
   * 抓取交给调用方随后触发的后台整库刷新（对照上游 `OpmlImportActivity.doImport` 末尾的
   * `FeedUpdateManager.runOnce`）——否则 86 个订阅要逐条同步抓取，导入页会一直转圈。
   *
   * @param inboxBaseline 收件箱基线（毫秒时间戳，默认取本次导入时刻）。整批订阅共用同一条基线：
   *        源里早于导入时刻发布的剧集都是「导入时既已存在」的历史内容，落「未播放」不进收件箱；
   *        之后的刷新里只有晚于该时刻发布的单集才会进收件箱。
   */
  static async importOpml(xml: string, inboxBaseline: number = 0): Promise<Feed[]> {
    const baseline: number = inboxBaseline > 0 ? inboxBaseline : Date.now();
    const outlines: OpmlOutline[] = [];
    let currentOutline: OpmlOutline | undefined = undefined;
    XmlReader.parse(xml, {
      onStart: (tag: XmlTag): void => {
        if (tag.name.toLowerCase() === 'outline') {
          const xmlUrl: string = tag.getAttribute('xmlUrl');
          if (xmlUrl !== '') {
            currentOutline = {
              text: tag.getAttribute('text') !== '' ? tag.getAttribute('text') : tag.getAttribute('title'),
              xmlUrl: xmlUrl,
              htmlUrl: tag.getAttribute('htmlUrl')
            };
          }
        }
      },
      onEnd: (name: string): void => {
        if (name.toLowerCase() === 'outline' && currentOutline !== undefined) {
          outlines.push(currentOutline);
          currentOutline = undefined;
        }
      },
      onText: (text: string): void => undefined,
      onAttribute: (name: string, value: string): void => undefined
    });
    const imported: Feed[] = [];
    for (const outline of outlines) {
      try {
        const feed: Feed | undefined = await SubscriptionService.subscribeDeferred(
          outline.text, outline.xmlUrl, outline.htmlUrl, baseline);
        if (feed !== undefined) {
          imported.push(feed);
        }
      } catch (error) {
        Logger.warn(TAG, 'import failed for ' + outline.xmlUrl + ': ' + (error as Error).message);
      }
    }
    return imported;
  }

  private static escapeXml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }
}
