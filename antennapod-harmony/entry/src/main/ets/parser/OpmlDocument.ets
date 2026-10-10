// Port of: storage/importexport/OpmlWriter.java + OpmlReader.java + OpmlSymbols.java
// 纯逻辑（只用 XmlReader，不 import 任何 @kit.*），可进 runtime-pure-test 的 tsc 回归。
import { XmlReader, XmlTag } from './XmlReader';

/** OPML 条目（对照上游 OpmlElement：text / xmlUrl / htmlUrl / type） */
export interface OpmlOutline {
  text: string;
  xmlUrl: string;
  htmlUrl: string;
  type: string;
}

/** 上游 OpmlSymbols 里的标签/属性名 */
const TAG_OUTLINE: string = 'outline';
const ATTR_TEXT: string = 'text';
const ATTR_TITLE: string = 'title';
const ATTR_TYPE: string = 'type';
const ATTR_XMLURL: string = 'xmlUrl';
const ATTR_HTMLURL: string = 'htmlUrl';

const OPML_VERSION: string = '2.0';
const ENCODING: string = 'UTF-8';
const DATE_CREATED: string = 'dateCreated';

/** 上游 SimpleDateFormat("dd MMM yy HH:mm:ss Z", Locale.US) 用的月份缩写（不受系统语言影响） */
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/**
 * OPML 文档的读写（对照上游 `OpmlWriter.writeDocument` / `OpmlReader.readDocument`）。
 *
 * 与上游的差异只有一处：head 里的 title 用 HomenaPod 自己的产品名（上游写 "AntennaPod Subscriptions"）。
 */
export class OpmlDocument {
  /**
   * 默认导出文件名（上游 `DEFAULT_OPML_OUTPUT_NAME = "antennapod-feeds-%s.opml"`，
   * %s 为 `yyyy-MM-dd`）：这里换成 HomenaPod 前缀，其余同款。
   */
  static defaultFileName(date: Date): string {
    return 'homenapod-feeds-' + OpmlDocument.dateStamp(date) + '.opml';
  }

  /** `yyyy-MM-dd`（本地时区） */
  static dateStamp(date: Date): string {
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    return year.toString() + '-' + OpmlDocument.pad2(month) + '-' + OpmlDocument.pad2(day);
  }

  /**
   * 写出 OPML 2.0 文档：
   * - head：title + dateCreated（RFC822 风格，上游同样写 dateCreated）
   * - body：每个订阅一条 outline，属性顺序与上游一致（text / title / type / xmlUrl / htmlUrl）；
   *   `type` 只在非空时写（上游 `if (feed.getType() != null)`），`htmlUrl` 也只在非空时写。
   */
  static writeDocument(outlines: OpmlOutline[], title: string, created: Date): string {
    let body: string = '<?xml version="1.0" encoding="' + ENCODING + '"?>\n';
    body += '<opml version="' + OPML_VERSION + '">\n';
    body += '  <head>\n';
    body += '    <title>' + OpmlDocument.escapeXml(title) + '</title>\n';
    body += '    <dateCreated>' + OpmlDocument.formatRfc822(created) + '</dateCreated>\n';
    body += '  </head>\n';
    body += '  <body>\n';
    for (const outline of outlines) {
      const text: string = OpmlDocument.escapeXml(outline.text);
      body += '    <' + TAG_OUTLINE + ' ' + ATTR_TEXT + '="' + text + '" '
        + ATTR_TITLE + '="' + text + '"';
      if (outline.type !== '') {
        body += ' ' + ATTR_TYPE + '="' + OpmlDocument.escapeXml(outline.type) + '"';
      }
      body += ' ' + ATTR_XMLURL + '="' + OpmlDocument.escapeXml(outline.xmlUrl) + '"';
      if (outline.htmlUrl !== '') {
        body += ' ' + ATTR_HTMLURL + '="' + OpmlDocument.escapeXml(outline.htmlUrl) + '"';
      }
      body += '/>\n';
    }
    body += '  </body>\n';
    body += '</opml>\n';
    return body;
  }

  /**
   * 解析 OPML（对照上游 `OpmlReader.readDocument`）：
   * - 只在 `<opml>` 树里的 `<outline>` 才算数（`isInOpml` 闸门）；
   * - 标题取 `title`，没有才回落到 `text`，两者都没有则用 `xmlUrl` 兜底；
   * - 没有 `xmlUrl` 的 outline 直接跳过（上游 `Skipping element because of missing xml url`）；
   * - 上游用 XmlPullParser 顺序扫全部标签，因此**嵌套 outline（文件夹分组）里的订阅同样读得出来**。
   */
  static readDocument(xml: string): OpmlOutline[] {
    const outlines: OpmlOutline[] = [];
    let inOpml: boolean = false;
    XmlReader.parse(OpmlDocument.stripBom(xml), {
      onStart: (tag: XmlTag): void => {
        const name: string = tag.name.toLowerCase();
        if (name === 'opml') {
          inOpml = true;
          return;
        }
        if (!inOpml || name !== TAG_OUTLINE) {
          return;
        }
        const xmlUrl: string = tag.getAttribute(ATTR_XMLURL);
        if (xmlUrl === '') {
          return;
        }
        const title: string = tag.getAttribute(ATTR_TITLE);
        let text: string = title !== '' ? title : tag.getAttribute(ATTR_TEXT);
        if (text === '') {
          text = xmlUrl;
        }
        outlines.push({
          text: text,
          xmlUrl: xmlUrl,
          htmlUrl: tag.getAttribute(ATTR_HTMLURL),
          type: tag.getAttribute(ATTR_TYPE)
        });
      },
      onEnd: (name: string): void => {
        if (name.toLowerCase() === 'opml') {
          inOpml = false;
        }
      },
      onText: (text: string): void => undefined,
      onAttribute: (name: string, value: string): void => undefined
    });
    return outlines;
  }

  /** 去掉解码后残留的 BOM（上游用 BOMInputStream 在解码前剥掉） */
  static stripBom(xml: string): string {
    return xml.charCodeAt(0) === 0xFEFF ? xml.substring(1) : xml;
  }

  /**
   * 按字节序标记判断文本编码（上游 `BOMInputStream.getBOM().getCharsetName()`）：
   * 返回 'utf-8' / 'utf-16le' / 'utf-16be'，无 BOM 时返回 ''（调用方按 UTF-8 处理）。
   */
  static detectCharset(bytes: Uint8Array): string {
    if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
      return 'utf-8';
    }
    if (bytes.length >= 2 && bytes[0] === 0xFF && bytes[1] === 0xFE) {
      return 'utf-16le';
    }
    if (bytes.length >= 2 && bytes[0] === 0xFE && bytes[1] === 0xFF) {
      return 'utf-16be';
    }
    return '';
  }

  /** XML 属性值转义（与上游 XmlSerializer 输出一致：& < > " ' 全部按实体写） */
  static escapeXml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  /** RFC822 风格时间：`dd MMM yy HH:mm:ss +0800`（上游 SimpleDateFormat，Locale.US） */
  static formatRfc822(date: Date): string {
    const day: string = OpmlDocument.pad2(date.getDate());
    const month: string = MONTHS[date.getMonth()];
    const year: string = OpmlDocument.pad2(date.getFullYear() % 100);
    const clock: string = OpmlDocument.pad2(date.getHours()) + ':' + OpmlDocument.pad2(date.getMinutes())
      + ':' + OpmlDocument.pad2(date.getSeconds());
    return day + ' ' + month + ' ' + year + ' ' + clock + ' ' + OpmlDocument.zoneOffset(date);
  }

  /** `+0800` / `-0530`：取本地时区与 UTC 的分钟差（东为正，对照 SimpleDateFormat 的 Z） */
  private static zoneOffset(date: Date): string {
    const minutes: number = -date.getTimezoneOffset();
    const sign: string = minutes < 0 ? '-' : '+';
    const abs: number = Math.abs(minutes);
    return sign + OpmlDocument.pad2(Math.floor(abs / 60)) + OpmlDocument.pad2(abs % 60);
  }

  private static pad2(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }
}
