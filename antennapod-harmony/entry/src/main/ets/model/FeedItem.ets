// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/FeedItem.java
import { FeedMedia } from './FeedMedia';
import { Chapter } from './Chapter';

export interface FeedItemOptions {
  id: number;
  title: string;
  pubDate: number;
  isPlayed: boolean;
  link: string;
  description: string;
  paymentLink: string;
  media: FeedMedia | undefined;
  feedId: number;
  hasChapters: boolean;
  itemIdentifier: string;
  imageUrl: string;
  autoDownloadEnabled: boolean;
  podcastIndexChapterUrl: string;
  podcastIndexTranscriptType: string;
  podcastIndexTranscriptUrl: string;
  socialInteractUrl: string;
}

export class FeedItem {
  id: number = 0;
  title: string = '';
  pubDate: number = 0;
  isPlayed: boolean = false;
  link: string = '';
  description: string = '';
  paymentLink: string = '';
  media: FeedMedia | undefined = undefined;
  feedId: number = 0;
  hasChapters: boolean = false;
  itemIdentifier: string = '';
  imageUrl: string = '';
  autoDownloadEnabled: boolean = false;
  podcastIndexChapterUrl: string = '';
  podcastIndexTranscriptType: string = '';
  podcastIndexTranscriptUrl: string = '';
  socialInteractUrl: string = '';
  chapters: Chapter[] = [];

  constructor(options: FeedItemOptions) {
    this.id = options.id;
    this.title = options.title;
    this.pubDate = options.pubDate;
    this.isPlayed = options.isPlayed;
    this.link = options.link;
    this.description = options.description;
    this.paymentLink = options.paymentLink;
    this.media = options.media;
    this.feedId = options.feedId;
    this.hasChapters = options.hasChapters;
    this.itemIdentifier = options.itemIdentifier;
    this.imageUrl = options.imageUrl;
    this.autoDownloadEnabled = options.autoDownloadEnabled;
    this.podcastIndexChapterUrl = options.podcastIndexChapterUrl;
    this.podcastIndexTranscriptType = options.podcastIndexTranscriptType;
    this.podcastIndexTranscriptUrl = options.podcastIndexTranscriptUrl;
    this.socialInteractUrl = options.socialInteractUrl;
  }

  hasMedia(): boolean {
    return this.media !== undefined;
  }

  getMedia(): FeedMedia | undefined {
    return this.media;
  }

  getChapterCount(): number {
    return this.chapters.length;
  }

  isDownloaded(): boolean {
    return this.media !== undefined && this.media.fileUrl !== '';
  }

  isInProgress(): boolean {
    return this.media !== undefined && this.media.position > 0
      && (this.media.duration <= 0 || this.media.position < this.media.duration - 1000);
  }

  isNew(now: number = Date.now()): boolean {
    if (this.isPlayed) {
      return false;
    }
    const sevenDays: number = 7 * 24 * 60 * 60 * 1000;
    return this.pubDate > 0 && now - this.pubDate < sevenDays;
  }
}
