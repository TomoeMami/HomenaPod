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
      } else if (name === 'enclosure' || name === 'media:content') {
        if (currentItem !== undefined) {
          const url: string = tag.getAttribute('url');
          const href: string = tag.getAttribute('href');
          const lengthStr: string = tag.getAttribute('length');
          const type: string = tag.getAttribute('type');
          const size: number = lengthStr !== '' ? Number(lengthStr) : 0;
          const mimeType: string = MimeTypeUtils.guessMimeType(url !== '' ? url : href, type);
          const mediaOptions: FeedMediaOptions = {
            id: 0,
            duration: 0,
            fileUrl: '',
            downloadUrl: url !== '' ? url : href,
            downloadDate: 0,
            position: 0,
            size: size,
            mimeType: mimeType,
            lastPlayedTimeHistory: 0,
            feedItemId: currentItem.id,
            playedDuration: 0,
            hasEmbeddedPicture: false,
            lastPlayedTimeStatistics: 0
          };
          currentItem.media = new FeedMedia(mediaOptions);
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
          if (rel === 'payment' || href !== '') {
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
        const href: string = tag.getAttribute('href');
        if (href !== '') {
          feed.imageUrl = href;
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
          feed.imageUrl = text;
        } else if (lower === 'logo') {
          feed.imageUrl = text;
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
    for (const item of items) {
      if (item.imageUrl === '') {
        item.imageUrl = feed.imageUrl;
      }
    }
    feed.downloadUrl = feed.downloadUrl;
    return { feed: feed, alternateUrls: [] };
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
      newEpisodesAction: 0
    };
  }

  private static emptyFeedItemOptions(): FeedItemOptions {
    return {
      id: 0,
      title: '',
      pubDate: 0,
      isPlayed: false,
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

