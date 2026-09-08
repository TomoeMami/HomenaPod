// Port of: Android XmlPullParser usage in parser/feed/SyndHandler.java
// HarmonyOS 封装：@ohos.xml.XmlPullParser + util.TextEncoder
// 注意官方回调顺序：START_TAG token 先于该标签的 attributeValueCallback，
// 因此这里使用“延迟 onStart”策略，确保回调时属性已填充完整。
import { xml, util } from '@kit.ArkTS';

export class XmlTag {
  name: string = '';
  attributes: Map<string, string> = new Map<string, string>();
  isEmpty: boolean = false;

  constructor(name: string, attributes: Map<string, string>, isEmpty: boolean) {
    this.name = name;
    this.attributes = attributes;
    this.isEmpty = isEmpty;
  }

  getAttribute(name: string): string {
    const value: string | undefined = this.attributes.get(name);
    return value === undefined ? '' : value;
  }
}

export interface XmlReaderCallback {
  onStart(tag: XmlTag): void;
  onEnd(name: string): void;
  onText(text: string): void;
  onAttribute(name: string, value: string): void;
}

export class XmlReader {
  static parse(content: string, callback: XmlReaderCallback): void {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const uint8: Uint8Array = encoder.encodeInto(content);
    const parser: xml.XmlPullParser = new xml.XmlPullParser(uint8.buffer as object as ArrayBuffer, 'UTF-8');
    let pendingTag: XmlTag | undefined = undefined;
    let currentTag: XmlTag | undefined = undefined;

    const flushPending = (): void => {
      if (pendingTag !== undefined) {
        callback.onStart(pendingTag);
        pendingTag = undefined;
      }
      currentTag = undefined;
    };

    const options: xml.ParseOptions = {
      supportDoctype: true,
      ignoreNameSpace: false,
      attributeValueCallbackFunction: (name: string, value: string): boolean => {
        if (currentTag !== undefined) {
          currentTag.attributes.set(name, value);
        }
        return true;
      },
      tokenValueCallbackFunction: (eventType: xml.EventType, info: xml.ParseInfo): boolean => {
        if (eventType === xml.EventType.START_TAG) {
          flushPending();
          const attrs: Map<string, string> = new Map<string, string>();
          const tag: XmlTag = new XmlTag(info.getName(), attrs, info.isEmptyElementTag());
          pendingTag = tag;
          currentTag = tag;
        } else if (eventType === xml.EventType.END_TAG) {
          flushPending();
          callback.onEnd(info.getName());
        } else if (eventType === xml.EventType.TEXT || eventType === xml.EventType.CDSECT) {
          flushPending();
          const text: string = info.getText();
          callback.onText(text !== null ? text : '');
        } else if (eventType === xml.EventType.END_DOCUMENT) {
          flushPending();
        }
        return true;
      }
    };
    parser.parse(options);
  }
}
