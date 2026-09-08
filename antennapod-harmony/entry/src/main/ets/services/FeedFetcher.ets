// Port of: net/download/service/feed/remote/FeedParserTask.java + Downloader.java
import { HttpClient, HttpResponse, NetworkError } from '../net/HttpClient';
import { FeedParser, ParseResult, UnsupportedFeedException } from '../parser/FeedParser';
import { FeedSanitizer } from '../parser/FeedSanitizer';

export class FeedFetcher {
  static async fetchFeed(url: string): Promise<ParseResult> {
    const response: HttpResponse = await HttpClient.get(url);
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
