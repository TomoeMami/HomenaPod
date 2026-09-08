// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/Feed.java
import { FeedState, SortOrder } from './Enums';
import { FeedItem } from './FeedItem';
import { FeedPreferences } from './FeedPreferences';

export interface FeedOptions {
  id: number;
  title: string;
  customTitle: string;
  fileUrl: string;
  downloadUrl: string;
  lastRefreshAttempt: number;
  link: string;
  description: string;
  paymentLink: string;
  lastUpdate: string;
  language: string;
  author: string;
  imageUrl: string;
  type: string;
  feedIdentifier: string;
  autoDownloadEnabled: boolean;
  username: string;
  password: string;
  includeFilter: string;
  excludeFilter: string;
  minimalDurationFilter: number;
  keepUpdated: boolean;
  isPaged: boolean;
  nextPageLink: string;
  hide: string;
  sortOrder: SortOrder;
  lastUpdateFailed: boolean;
  autoDeleteAction: number;
  feedPlaybackSpeed: number;
  feedSkipSilence: number;
  feedVolumeAdaption: number;
  feedTags: string;
  feedSkipIntro: number;
  feedSkipEnding: number;
  episodeNotification: boolean;
  state: FeedState;
  newEpisodesAction: number;
}

export class Feed {
  id: number = 0;
  title: string = '';
  customTitle: string = '';
  fileUrl: string = '';
  downloadUrl: string = '';
  lastRefreshAttempt: number = 0;
  link: string = '';
  description: string = '';
  paymentLink: string = '';
  lastUpdate: string = '';
  language: string = '';
  author: string = '';
  imageUrl: string = '';
  type: string = '';
  feedIdentifier: string = '';
  autoDownloadEnabled: boolean = true;
  username: string = '';
  password: string = '';
  includeFilter: string = '';
  excludeFilter: string = '';
  minimalDurationFilter: number = -1;
  keepUpdated: boolean = true;
  isPaged: boolean = false;
  nextPageLink: string = '';
  hide: string = '';
  sortOrder: SortOrder = SortOrder.DATE_NEW_OLD;
  lastUpdateFailed: boolean = false;
  autoDeleteAction: number = 0;
  feedPlaybackSpeed: number = 0;
  feedSkipSilence: number = 0;
  feedVolumeAdaption: number = 0;
  feedTags: string = '';
  feedSkipIntro: number = 0;
  feedSkipEnding: number = 0;
  episodeNotification: boolean = false;
  state: FeedState = FeedState.STATE_SUBSCRIBED;
  newEpisodesAction: number = 0;
  items: FeedItem[] = [];
  paymentLinks: PaymentLink[] = [];
  preferences: FeedPreferences = new FeedPreferences();

  constructor(options: FeedOptions) {
    this.id = options.id;
    this.title = options.title;
    this.customTitle = options.customTitle;
    this.fileUrl = options.fileUrl;
    this.downloadUrl = options.downloadUrl;
    this.lastRefreshAttempt = options.lastRefreshAttempt;
    this.link = options.link;
    this.description = options.description;
    this.paymentLink = options.paymentLink;
    this.lastUpdate = options.lastUpdate;
    this.language = options.language;
    this.author = options.author;
    this.imageUrl = options.imageUrl;
    this.type = options.type;
    this.feedIdentifier = options.feedIdentifier;
    this.autoDownloadEnabled = options.autoDownloadEnabled;
    this.username = options.username;
    this.password = options.password;
    this.includeFilter = options.includeFilter;
    this.excludeFilter = options.excludeFilter;
    this.minimalDurationFilter = options.minimalDurationFilter;
    this.keepUpdated = options.keepUpdated;
    this.isPaged = options.isPaged;
    this.nextPageLink = options.nextPageLink;
    this.hide = options.hide;
    this.sortOrder = options.sortOrder;
    this.lastUpdateFailed = options.lastUpdateFailed;
    this.autoDeleteAction = options.autoDeleteAction;
    this.feedPlaybackSpeed = options.feedPlaybackSpeed;
    this.feedSkipSilence = options.feedSkipSilence;
    this.feedVolumeAdaption = options.feedVolumeAdaption;
    this.feedTags = options.feedTags;
    this.feedSkipIntro = options.feedSkipIntro;
    this.feedSkipEnding = options.feedSkipEnding;
    this.episodeNotification = options.episodeNotification;
    this.state = options.state;
    this.newEpisodesAction = options.newEpisodesAction;
  }

  getTitle(): string {
    if (this.customTitle !== '') {
      return this.customTitle;
    }
    return this.title;
  }

  getFeedIdentifier(): string {
    return this.feedIdentifier;
  }

  isSubscribed(): boolean {
    return this.state === FeedState.STATE_SUBSCRIBED;
  }
}

export interface PaymentLink {
  content: string;
  url: string;
}
