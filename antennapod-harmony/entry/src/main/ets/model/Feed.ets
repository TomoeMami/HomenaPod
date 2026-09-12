// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/Feed.java
import { FeedState, NewEpisodesAction, SortOrder } from './Enums';
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
  inboxBaseline: number;
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
  /**
   * 收件箱基线（毫秒时间戳，= 订阅/批量导入的时刻，0 表示未设置）。
   * 早于基线发布的单集属于「订阅前就已存在」的历史剧集，落库时为「未播放」而非「新」，
   * 因此不会灌进收件箱；只有晚于基线发布的单集才按 newEpisodesAction 决定是否进收件箱。
   */
  inboxBaseline: number = 0;
  items: FeedItem[] = [];
  /** 剧集总数（由 FeedRepository 聚合查询填充，避免加载全部 items） */
  itemCount: number = 0;
  /** 未播放剧集数（订阅页计数胶囊 / 过滤 / 排序；由 EpisodeRepository 聚合填充） */
  unplayedCount: number = 0;
  /** 收件箱新剧集数（read = -1，上游 FeedCounter.SHOW_NEW；由 EpisodeRepository 聚合填充） */
  newCount: number = 0;
  /** 已播放剧集数（上游 getPlayedEpisodesCounters，「最多播放」排序用） */
  playedCount: number = 0;
  /** 已下载剧集数（订阅页计数口径之一） */
  downloadedCount: number = 0;
  /** 已下载且未播放的剧集数（订阅页计数口径之一） */
  downloadedUnplayedCount: number = 0;
  /** 累计收听时长（订阅页「最多播放」排序） */
  playedDuration: number = 0;
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
    this.inboxBaseline = options.inboxBaseline;
  }

  /**
   * 「已登记、尚未抓取」的订阅（OPML 批量导入用）。
   *
   * 对照上游 `OpmlImportActivity.doImport`：它只 `new Feed(xmlUrl, null, text)` 后写库，
   * 剧集与封面交给随后的 `FeedUpdateManager.runOnce()`（本移植版即 `RefreshService.refreshAll()`）。
   * 这样导入本身是瞬时的，用户不必在导入页等 86 次网络抓取。
   *
   * @param inboxBaseline 收件箱基线（整批导入共用同一条，语义见 OpmlService.importOpml）
   */
  static pending(downloadUrl: string, title: string, link: string, inboxBaseline: number): Feed {
    return new Feed({
      id: 0,
      title: title,
      customTitle: '',
      fileUrl: '',
      downloadUrl: downloadUrl,
      lastRefreshAttempt: 0,
      link: link,
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
      sortOrder: SortOrder.DATE_NEW_OLD,
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
      newEpisodesAction: NewEpisodesAction.GLOBAL,
      inboxBaseline: inboxBaseline
    });
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
