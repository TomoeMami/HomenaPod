// Port of: Android XmlPullParser usage in parser/feed/SyndHandler.java
// 轻量 XML 分词器（纯 ArkTS，不依赖 @ohos.xml）。
// 提示：宿主端 LocalTest 中 @ohos.xml 为 no-op 桩，无法驱动解析；
// 本实现保证单元测试宿主与真机行为一致，且提前于实体解码（&amp;、&#123;）。
// 回调顺序：start tag 解析完成后立即 onStart（属性已附着），随后 onText/onEnd。

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
  onStart: (tag: XmlTag) => void;
  onEnd: (name: string) => void;
  onText: (text: string) => void;
  onAttribute: (name: string, value: string) => void;
}

class ParsedTag {
  tag: XmlTag;
  nextIndex: number;

  constructor(tag: XmlTag, nextIndex: number) {
    this.tag = tag;
    this.nextIndex = nextIndex;
  }
}

export class XmlReader {
  static parse(content: string, callback: XmlReaderCallback): void {
    const text: string = content;
    let i: number = 0;
    const len: number = text.length;
    const emitText = (start: number, end: number, decode: boolean): void => {
      if (end > start) {
        const raw: string = text.substring(start, end);
        callback.onText(decode ? XmlReader.decodeEntities(raw) : raw);
      }
    };

    while (i < len) {
      const lt: number = text.indexOf('<', i);
      if (lt === -1) {
        emitText(i, len, true);
        break;
      }
      if (lt > i) {
        emitText(i, lt, true);
      }
      if (text.startsWith('<?', lt)) {
        const close: number = text.indexOf('?>', lt + 2);
        i = close === -1 ? len : close + 2;
      } else if (text.startsWith('<!--', lt)) {
        const close: number = text.indexOf('-->', lt + 4);
        i = close === -1 ? len : close + 3;
      } else if (text.startsWith('<![CDATA[', lt)) {
        const close: number = text.indexOf(']]>', lt + 9);
        if (close === -1) {
          emitText(lt + 9, len, false);
          i = len;
        } else {
          emitText(lt + 9, close, false);
          i = close + 3;
        }
      } else if (text.startsWith('<!DOCTYPE', lt) || text.startsWith('<!doctype', lt)) {
        let close: number = text.indexOf('>', lt);
        if (close === -1) {
          i = len;
        } else if (text.substring(lt, close).indexOf('[') >= 0) {
          const subset: number = text.indexOf(']>', lt);
          i = subset === -1 ? len : subset + 2;
        } else {
          i = close + 1;
        }
      } else if (text.startsWith('</', lt)) {
        const gt: number = text.indexOf('>', lt + 2);
        if (gt === -1) {
          i = len;
        } else {
          const name: string = text.substring(lt + 2, gt).trim();
          if (name.length > 0) {
            callback.onEnd(name);
          }
          i = gt + 1;
        }
      } else {
        const parsed: ParsedTag | undefined = XmlReader.parseTag(text, lt);
        if (parsed === undefined) {
          i = len;
        } else {
          callback.onStart(parsed.tag);
          if (parsed.tag.isEmpty) {
            callback.onEnd(parsed.tag.name);
          }
          i = parsed.nextIndex;
        }
      }
    }
  }

  private static parseTag(content: string, start: number): ParsedTag | undefined {
    let j: number = start + 1;
    const len: number = content.length;
    let quote: string = '';
    let gt: number = -1;
    let selfClose: boolean = false;
    while (j < len) {
      const c: string = content.charAt(j);
      if (quote !== '') {
        if (c === quote) {
          quote = '';
        }
      } else if (c === '"' || c === "'") {
        quote = c;
      } else if (c === '>') {
        gt = j;
        break;
      } else if (c === '/' && content.charAt(j + 1) === '>') {
        selfClose = true;
        gt = j + 1;
        break;
      }
      j++;
    }
    if (gt === -1) {
      return undefined;
    }
    const innerEnd: number = selfClose ? gt - 1 : gt;
    const inner: string = content.substring(start + 1, innerEnd);
    let nameStart: number = 0;
    while (nameStart < inner.length && XmlReader.isWhitespace(inner.charAt(nameStart))) {
      nameStart++;
    }
    let nameEnd: number = nameStart;
    while (nameEnd < inner.length && !XmlReader.isWhitespace(inner.charAt(nameEnd))) {
      nameEnd++;
    }
    if (nameEnd <= nameStart) {
      return undefined;
    }
    const name: string = inner.substring(nameStart, nameEnd);
    const attrs: Map<string, string> = new Map<string, string>();
    let k: number = nameEnd;
    while (k < inner.length) {
      while (k < inner.length && XmlReader.isWhitespace(inner.charAt(k))) {
        k++;
      }
      if (k >= inner.length) {
        break;
      }
      if (inner.charAt(k) === '/') {
        k++;
        continue;
      }
      let attrEnd: number = k;
      while (attrEnd < inner.length && !XmlReader.isWhitespace(inner.charAt(attrEnd))
        && inner.charAt(attrEnd) !== '=') {
        attrEnd++;
      }
      const attrName: string = inner.substring(k, attrEnd);
      k = attrEnd;
      while (k < inner.length && XmlReader.isWhitespace(inner.charAt(k))) {
        k++;
      }
      let value: string = '';
      if (k < inner.length && inner.charAt(k) === '=') {
        k++;
        while (k < inner.length && XmlReader.isWhitespace(inner.charAt(k))) {
          k++;
        }
        if (k < inner.length && (inner.charAt(k) === '"' || inner.charAt(k) === "'")) {
          const q: string = inner.charAt(k);
          k++;
          const valueStart: number = k;
          while (k < inner.length && inner.charAt(k) !== q) {
            k++;
          }
          value = inner.substring(valueStart, k);
          if (k < inner.length) {
            k++;
          }
        } else {
          const valueStart: number = k;
          while (k < inner.length && !XmlReader.isWhitespace(inner.charAt(k))) {
            k++;
          }
          value = inner.substring(valueStart, k);
        }
      }
      if (attrName.length > 0) {
        attrs.set(attrName, XmlReader.decodeEntities(value));
      }
    }
    const tag: XmlTag = new XmlTag(name, attrs, selfClose);
    return new ParsedTag(tag, gt + 1);
  }

  static decodeEntities(value: string): string {
    if (value.indexOf('&') === -1) {
      return value;
    }
    let out: string = '';
    let i: number = 0;
    const len: number = value.length;
    while (i < len) {
      const amp: number = value.indexOf('&', i);
      if (amp === -1) {
        out += value.substring(i);
        break;
      }
      out += value.substring(i, amp);
      const semi: number = value.indexOf(';', amp);
      if (semi === -1) {
        out += value.substring(amp);
        break;
      }
      const entity: string = value.substring(amp + 1, semi);
      const decoded: string | undefined = XmlReader.entityChar(entity);
      if (decoded === undefined) {
        out += value.substring(amp, semi + 1);
      } else {
        out += decoded;
      }
      i = semi + 1;
    }
    return out;
  }

  private static entityChar(entity: string): string | undefined {
    if (entity === 'amp') {
      return '&';
    }
    if (entity === 'lt') {
      return '<';
    }
    if (entity === 'gt') {
      return '>';
    }
    if (entity === 'quot') {
      return '"';
    }
    if (entity === 'apos') {
      return "'";
    }
    if (entity.startsWith('#x') || entity.startsWith('#X')) {
      const code: number = Number.parseInt(entity.substring(2), 16);
      return Number.isFinite(code) ? String.fromCodePoint(code) : undefined;
    }
    if (entity.startsWith('#')) {
      const code: number = Number.parseInt(entity.substring(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : undefined;
    }
    return undefined;
  }

  private static isWhitespace(c: string): boolean {
    return c === ' ' || c === '\t' || c === '\n' || c === '\r';
  }
}
