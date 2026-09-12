// Port of: parser/feed/FeedHandler.java + SyndHandler.java + namespace/*.java
import { XmlReader, XmlTag } from './XmlReader';
import { Feed, PaymentLink, FeedOptions } from '../model/Feed';
import { FeedItem, FeedItemOptions } from '../model/FeedItem';
import { FeedMedia, FeedMediaOptions } from '../model/FeedMedia';
import { FeedState } from '../model/Enums';
import { DateUtils } from '../utils/DateUtils';
import { DurationUtils } from '../utils/DurationUtils';
import { MimeTypeUtils } from '../utils/MimeTypeUtils';

export class UnsupportedFeedException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UnsupportedFeedException';
  }
}

export interface ParseResult {
  feed: Feed;
  alternateUrls: string[];
}

const knownElements: Set<string> = new Set<string>([
  'rss', 'feed', 'channel', 'item', 'entry', 'title', 'description', 'summary', 'subtitle',
  'language', 'author', 'itunes:author', 'link', 'atom:link', 'image', 'url', 'logo',
  'id', 'guid', 'pubdate', 'published', 'updated', 'enclosure', 'media:content',
  'media:thumbnail', 'media:group',
  'itunes:duration', 'duration', 'podcast:transcript', 'podcast:funding', 'itunes:image'
]);

export class FeedParser {
  static parseFeed(xmlText: string): ParseResult {
    const feed: Feed = new Feed(FeedParser.emptyFeedOptions());
    const items: FeedItem[] = [];
    let currentItem: FeedItem | undefined = undefined;
    let textBuffer: string = '';
    let inImage: boolean = false;
    let unsupportedDepth: number = 0;

    const onStart = (tag: XmlTag): void => {
      const name: string = tag.name.toLowerCase();
      if (unsupportedDepth > 0) {
        unsupportedDepth++;
        return;
      }
      if (!knownElements.has(name)) {
        unsupportedDepth++;
        return;
      }
      if (name === 'rss') {
        feed.type = 'rss';
      } else if (name === 'feed') {
        feed.type = 'atom';
      } else if (name === 'item' || name === 'entry') {
        currentItem = new FeedItem(FeedParser.emptyFeedItemOptions());
      } else if (name === 'image') {
        inImage = true;
      } else if (name === 'enclosure') {
        if (currentItem !== undefined) {
          const url: string = tag.getAttribute('url');
          const href: string = tag.getAttribute('href');
          FeedParser.applyEnclosure(currentItem, url !== '' ? url : href,
            tag.getAttribute('length'), tag.getAttribute('type'));
        }
      } else if (name === 'media:content') {
        // media:content 既可能是音视频（等价 enclosure），也可能是封面（medium="image" / type="image/*"）。
        // 旧实现一律当 enclosure，会把封面写成单集的音频地址。
        const contentUrl: string = tag.getAttribute('url') !== '' ? tag.getAttribute('url') : tag.getAttribute('href');
        const contentType: string = tag.getAttribute('type').toLowerCase();
        const contentMedium: string = tag.getAttribute('medium').toLowerCase();
        if (contentMedium === 'image' || contentType.startsWith('image/')) {
          if (contentUrl !== '') {
            FeedParser.applyImage(feed, currentItem, contentUrl);
          }
        } else if (currentItem !== undefined) {
          FeedParser.applyEnclosure(currentItem, contentUrl,
            tag.getAttribute('length'), tag.getAttribute('type'));
        }
      } else if (name === 'media:thumbnail') {
        const thumbUrl: string = tag.getAttribute('url');
        if (thumbUrl !== '') {
          FeedParser.applyImage(feed, currentItem, thumbUrl);
        }
      } else if (name === 'podcast:transcript') {
        if (currentItem !== undefined) {
          const transcriptUrl: string = tag.getAttribute('url');
          const transcriptType: string = tag.getAttribute('type');
          if (currentItem.podcastIndexTranscriptUrl === '' && transcriptUrl !== '') {
            currentItem.podcastIndexTranscriptUrl = transcriptUrl;
          }
          if (currentItem.podcastIndexTranscriptType === '' && transcriptType !== '') {
            currentItem.podcastIndexTranscriptType = transcriptType;
          }
        }
      } else if (name === 'podcast:funding') {
        const fundingUrl: string = tag.getAttribute('url');
        if (fundingUrl !== '') {
          const payment: PaymentLink = { content: '', url: fundingUrl };
          feed.paymentLinks.push(payment);
          feed.paymentLink = fundingUrl;
        }
      } else if (name === 'link' || name === 'atom:link') {
        const rel: string = tag.getAttribute('rel');
        const href: string = tag.getAttribute('href');
        if (currentItem === undefined) {
          if (rel === 'next' && href !== '') {
            // RFC 5005 / Atom 分页：rel="next" 指向下一页
            feed.isPaged = true;
            feed.nextPageLink = href;
          } else if (rel === 'payment' || href !== '') {
            if (rel === 'payment') {
              feed.paymentLink = href;
              const payment: PaymentLink = { content: '', url: href };
              feed.paymentLinks.push(payment);
            } else if (rel === 'self') {
              feed.feedIdentifier = href;
            } else if (rel === 'alternate') {
              feed.link = href;
            } else if (rel === '' && href !== '') {
              feed.link = href;
            }
          }
        } else {
          if (rel === 'enclosure') {
            const type: string = tag.getAttribute('type');
            const lengthStr: string = tag.getAttribute('length');
            const mimeType: string = MimeTypeUtils.guessMimeType(href, type);
            const mediaOptions: FeedMediaOptions = {
              id: 0,
              duration: 0,
              fileUrl: '',
              downloadUrl: href,
              downloadDate: 0,
              position: 0,
              size: lengthStr !== '' ? Number(lengthStr) : 0,
              mimeType: mimeType,
              lastPlayedTimeHistory: 0,
              feedItemId: currentItem.id,
              playedDuration: 0,
              hasEmbeddedPicture: false,
              lastPlayedTimeStatistics: 0
            };
            currentItem.media = new FeedMedia(mediaOptions);
          } else if (rel === 'alternate') {
            currentItem.link = href;
          } else if (rel === '' && href !== '') {
            currentItem.link = href;
          }
        }
      } else if (name === 'itunes:image') {
        // 关键：item 内的 itunes:image 是「单集封面」，不能写成 Feed.imageUrl——
        // 旧实现无条件覆盖 feed.imageUrl，导致播客封面变成最后一集的封面，
        // 且单集永远拿不到自己的封面。
        const href: string = tag.getAttribute('href');
        if (href !== '') {
          FeedParser.applyImage(feed, currentItem, href);
        }
      }
    };

    const onEnd = (name: string): void => {
      const lower: string = name.toLowerCase();
      if (unsupportedDepth > 0) {
        unsupportedDepth--;
        textBuffer = '';
        return;
      }
      const text: string = textBuffer.trim();
      if (currentItem !== undefined) {
        if (lower === 'title') {
          currentItem.title = text;
        } else if (lower === 'link' && currentItem.link === '') {
          currentItem.link = text;
        } else if (lower === 'guid' || lower === 'id') {
          currentItem.itemIdentifier = text;
        } else if (lower === 'pubdate' || lower === 'published' || lower === 'updated') {
          currentItem.pubDate = DateUtils.parseToEpochMillis(text);
        } else if (lower === 'description' || lower === 'summary' || lower === 'subtitle') {
          currentItem.description = text;
        } else if (lower === 'url' && inImage) {
          if (text !== '') {
            currentItem.imageUrl = text;
          }
        } else if (lower === 'itunes:duration' || lower === 'duration') {
          if (currentItem.media !== undefined) {
            currentItem.media.duration = DurationUtils.parseToMillis(text);
          }
        } else if (lower === 'podcast:funding') {
          if (feed.paymentLinks.length > 0) {
            feed.paymentLinks[feed.paymentLinks.length - 1].content = text;
          }
        } else if (lower === 'item' || lower === 'entry') {
          items.push(currentItem);
          currentItem = undefined;
        }
      } else {
        if (lower === 'title') {
          feed.title = text;
        } else if (lower === 'link' && feed.link === '') {
          feed.link = text;
        } else if (lower === 'description' || lower === 'subtitle') {
          feed.description = text;
        } else if (lower === 'language') {
          feed.language = text;
        } else if (lower === 'author' || lower === 'itunes:author') {
          feed.author = text;
        } else if (lower === 'url' && inImage) {
          if (text !== '') {
            feed.imageUrl = text;
          }
        } else if (lower === 'logo') {
          if (text !== '') {
            feed.imageUrl = text;
          }
        } else if (lower === 'id') {
          feed.feedIdentifier = text;
        }
      }
      textBuffer = '';
      if (lower === 'image') {
        inImage = false;
      }
    };

    const onText = (text: string): void => {
      textBuffer += text;
    };

    XmlReader.parse(xmlText, {
      onStart: onStart,
      onEnd: onEnd,
      onText: onText,
      onAttribute: (name: string, value: string): void => {
        // 属性已在 XmlReader 中附着到 XmlTag，这里无需处理。
      }
    });

    feed.items = items;
    // 单集没有自己的封面时回落到播客封面（对照上游 Feed.getImageUrl() 的显示语义）
    for (const item of items) {
      if (item.imageUrl === '') {
        item.imageUrl = feed.imageUrl;
      }
    }
    feed.downloadUrl = feed.downloadUrl;
    return { feed: feed, alternateUrls: [] };
  }

  /** 封面归属：在 item 内 → 单集封面；否则 → 播客封面（对照上游 Itunes/Media 命名空间解析） */
  private static applyImage(feed: Feed, item: FeedItem | undefined, url: string): void {
    if (item !== undefined) {
      item.imageUrl = url;
    } else {
      feed.imageUrl = url;
    }
  }

  /** enclosure / media:content（非图片）→ 单集媒体 */
  private static applyEnclosure(item: FeedItem, downloadUrl: string, lengthStr: string, type: string): void {
    const size: number = lengthStr !== '' ? Number(lengthStr) : 0;
    const mimeType: string = MimeTypeUtils.guessMimeType(downloadUrl, type);
    const mediaOptions: FeedMediaOptions = {
      id: 0,
      duration: 0,
      fileUrl: '',
      downloadUrl: downloadUrl,
      downloadDate: 0,
      position: 0,
      size: size,
      mimeType: mimeType,
      lastPlayedTimeHistory: 0,
      feedItemId: item.id,
      playedDuration: 0,
      hasEmbeddedPicture: false,
      lastPlayedTimeStatistics: 0
    };
    item.media = new FeedMedia(mediaOptions);
  }

  private static emptyFeedOptions(): FeedOptions {
    return {
      id: 0,
      title: '',
      customTitle: '',
      fileUrl: '',
      downloadUrl: '',
      lastRefreshAttempt: 0,
      link: '',
      description: '',
      paymentLink: '',
      lastUpdate: '',
      language: '',
      author: '',
      imageUrl: '',
      type: '',
      feedIdentifier: '',
      autoDownloadEnabled: true,
      username: '',
      password: '',
      includeFilter: '',
      excludeFilter: '',
      minimalDurationFilter: -1,
      keepUpdated: true,
      isPaged: false,
      nextPageLink: '',
      hide: '',
      sortOrder: 0,
      lastUpdateFailed: false,
      autoDeleteAction: 0,
      feedPlaybackSpeed: 0,
      feedSkipSilence: 0,
      feedVolumeAdaption: 0,
      feedTags: '',
      feedSkipIntro: 0,
      feedSkipEnding: 0,
      episodeNotification: false,
      state: FeedState.STATE_SUBSCRIBED,
      newEpisodesAction: 0,
      inboxBaseline: 0
    };
  }

  private static emptyFeedItemOptions(): FeedItemOptions {
    return {
      id: 0,
      title: '',
      pubDate: 0,
      isPlayed: false,
      playState: FeedItem.UNPLAYED,
      link: '',
      description: '',
      paymentLink: '',
      media: undefined,
      feedId: 0,
      hasChapters: false,
      itemIdentifier: '',
      imageUrl: '',
      autoDownloadEnabled: true,
      podcastIndexChapterUrl: '',
      podcastIndexTranscriptType: '',
      podcastIndexTranscriptUrl: '',
      socialInteractUrl: ''
    };
  }
}

