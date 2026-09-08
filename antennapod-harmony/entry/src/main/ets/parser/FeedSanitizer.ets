// Port of: parser/feed/util/TypeGetter.java + net/common/UrlChecker.java
import { UnsupportedFeedException } from './FeedParser';

export class FeedSanitizer {
  static checkFeedContent(content: string): void {
    const lower: string = content.toLowerCase();
    if (content.trim().startsWith('<!doctype html') || lower.indexOf('<html') >= 0) {
      throw new UnsupportedFeedException('该地址是网页而非 RSS/Atom 订阅源');
    }
    if (lower.indexOf('<rss') < 0 && lower.indexOf('<feed') < 0) {
      throw new UnsupportedFeedException('未发现可识别的订阅源格式');
    }
  }
}
