// Port of: net/download/service/feed/remote/FeedParserTask.java + Downloader.java
import { HttpClient, HttpResponse, NetworkError } from '../net/HttpClient';
import { FeedParser, ParseResult, UnsupportedFeedException } from '../parser/FeedParser';
import { FeedSanitizer } from '../parser/FeedSanitizer';
import { Base64Utils } from '../utils/Base64Utils';

export class FeedFetcher {
  /**
   * 拉取并解析订阅源；username/password 非空时附加 HTTP Basic 认证头（私有 Feed）。
   * 认证头只随该订阅自己的 URL 发送，不会外泄到其他请求。
   */
  static async fetchFeed(url: string, username: string = '', password: string = ''): Promise<ParseResult> {
    const headers: Record<string, string> = {};
    if (username !== '' || password !== '') {
      headers['Authorization'] = Base64Utils.basicAuth(username, password);
    }
    const response: HttpResponse = await HttpClient.get(url, headers);
    if (response.status >= 300) {
      throw new NetworkError(0, 'HTTP ' + response.status, response.status);
    }
    FeedSanitizer.checkFeedContent(response.body);
    return FeedParser.parseFeed(response.body);
  }

  static async fetchFeedFromHtml(html: string): Promise<ParseResult> {
    const match: RegExpMatchArray | null = html.match(
      /<link[^>]+(?:type=["']application\/rss\+xml["']|type=["']application\/atom\+xml["'])[^>]*href=["']([^"']+)["']/i
    );
    if (match === null || match[1] === undefined) {
      throw new UnsupportedFeedException('网页中未找到订阅源链接');
    }
    const feedUrl: string = match[1];
    return FeedFetcher.fetchFeed(feedUrl);
  }
}
