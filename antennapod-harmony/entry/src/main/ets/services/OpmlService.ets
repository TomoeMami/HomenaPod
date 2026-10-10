// Port of: storage/importexport OpmlImporter/OpmlExporter
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { Feed } from '../model/Feed';
import { FeedState } from '../model/Enums';
import { SubscriptionService } from './SubscriptionService';
import { OpmlDocument, OpmlOutline } from '../parser/OpmlDocument';
import { Logger } from '../utils/Logger';

const TAG: string = 'OpmlService';

/** OPML head 里的文档标题（上游写 "AntennaPod Subscriptions"） */
const OPML_TITLE: string = 'HomenaPod Subscriptions';

export class OpmlService {
  /** 默认导出文件名 `homenapod-feeds-yyyy-MM-dd.opml` */
  static defaultExportFileName(date: Date): string {
    return OpmlDocument.defaultFileName(date);
  }

  /**
   * 导出订阅为 OPML 文本（对照上游 `OpmlWriter.writeDocument` + `ImportExportPreferencesFragment.writeToStream`）：
   * 只写**已订阅**（`Feed.STATE_SUBSCRIBED`）的源——上游 OpmlWriter 逐条 `if (feed.getState() != STATE_SUBSCRIBED) continue`。
   */
  static exportOpml(feeds: Feed[], created: Date): string {
    const outlines: OpmlOutline[] = [];
    for (const feed of feeds) {
      if (feed.state !== FeedState.STATE_SUBSCRIBED) {
        continue;
      }
      outlines.push({
        text: feed.getTitle(),
        xmlUrl: feed.downloadUrl,
        htmlUrl: feed.link,
        type: feed.type
      });
    }
    return OpmlDocument.writeDocument(outlines, OPML_TITLE, created);
  }

  /** 解析 OPML 文本为条目列表（对照上游 OpmlReader） */
  static parseOutlines(xml: string): OpmlOutline[] {
    return OpmlDocument.readDocument(xml);
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
    const outlines: OpmlOutline[] = OpmlService.parseOutlines(xml);
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

  /**
   * 读取用户选择的 OPML 文件（对照上游 `OpmlImportActivity.startImport`）：
   * 先按 BOM 判断 UTF-8 / UTF-16，再解码并去掉残留 BOM——中文播客名常见 UTF-8 BOM，
   * 不解码就会把 `<opml>` 首标签读坏、整份文件解析出 0 条。
   */
  static async readFromUri(uri: string): Promise<string> {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat: fs.Stat = fs.statSync(file.fd);
      if (stat.size <= 0) {
        throw new Error('OPML file is empty');
      }
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      const bytes: Uint8Array = new Uint8Array(buffer);
      const charset: string = OpmlDocument.detectCharset(bytes);
      const decoder: util.TextDecoder = util.TextDecoder.create(charset === '' ? 'utf-8' : charset);
      return OpmlDocument.stripBom(decoder.decodeToString(bytes));
    } finally {
      fs.closeSync(file);
    }
  }

  /** 把 OPML 文本写入用户选择的目标（DocumentViewPicker.save 返回的 uri） */
  static async writeToUri(uri: string, xml: string): Promise<void> {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, xml);
    } finally {
      fs.closeSync(file);
    }
  }
}
