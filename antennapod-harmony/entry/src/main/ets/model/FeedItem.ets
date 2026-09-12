// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/FeedItem.java
import { FeedMedia } from './FeedMedia';
import { Chapter } from './Chapter';

export interface FeedItemOptions {
  id: number;
  title: string;
  pubDate: number;
  isPlayed: boolean;
  playState: number;
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
  /** 播放状态三态（上游 FeedItem.NEW/UNPLAYED/PLAYED，数据库落在 read 列） */
  static readonly NEW: number = -1;
  static readonly UNPLAYED: number = 0;
  static readonly PLAYED: number = 1;

  id: number = 0;
  title: string = '';
  pubDate: number = 0;
  isPlayed: boolean = false;
  playState: number = FeedItem.UNPLAYED;
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
  // 以下为列表运行时字段（不落库，由查询/页面填充）
  /** 所属订阅标题（Episodes 全库总表副标题） */
  feedTitle: string = '';
  /** 所属订阅封面（Episodes 全库总表行封面） */
  feedImage: string = '';
  /** 是否已在队列中（列表状态图标） */
  inQueue: boolean = false;
  /** 是否已收藏（列表状态图标） */
  isFavorite: boolean = false;

  constructor(options: FeedItemOptions) {
    this.id = options.id;
    this.title = options.title;
    this.pubDate = options.pubDate;
    this.isPlayed = options.isPlayed;
    this.playState = options.playState;
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

  /** 上游 FeedItem.isNew()：state == NEW（数据库 read = -1），与「未播放」不等价 */
  isNew(): boolean {
    return this.playState === FeedItem.NEW;
  }

  setNew(): void {
    this.playState = FeedItem.NEW;
    this.isPlayed = false;
  }

  setPlayed(played: boolean): void {
    this.playState = played ? FeedItem.PLAYED : FeedItem.UNPLAYED;
    this.isPlayed = played;
  }
}
