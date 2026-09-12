import { describe, it, expect } from '@ohos/hypium';
import { InboxBaseline } from '../../main/ets/utils/InboxBaseline';
import { Feed } from '../../main/ets/model/Feed';
import { FeedItem } from '../../main/ets/model/FeedItem';
import { FeedMedia } from '../../main/ets/model/FeedMedia';
import { FeedState } from '../../main/ets/model/Enums';

/** 基线时刻（毫秒） */
const BASELINE: number = 10000;

function makeItem(id: number, pubDate: number): FeedItem {
  const media: FeedMedia = new FeedMedia({
    id: id * 10,
    duration: 60000,
    fileUrl: '',
    downloadUrl: 'https://example.com/' + id + '.mp3',
    downloadDate: 0,
    position: 0,
    size: 0,
    mimeType: 'audio/mpeg',
    lastPlayedTimeHistory: 0,
    feedItemId: id,
    playedDuration: 0,
    hasEmbeddedPicture: false,
    lastPlayedTimeStatistics: 0
  });
  return new FeedItem({
    id: id,
    title: 'ep' + id,
    pubDate: pubDate,
    isPlayed: false,
    playState: FeedItem.UNPLAYED,
    link: '',
    description: '',
    paymentLink: '',
    media: media,
    feedId: 1,
    hasChapters: false,
    itemIdentifier: 'guid-' + id,
    imageUrl: '',
    autoDownloadEnabled: false,
    podcastIndexChapterUrl: '',
    podcastIndexTranscriptType: '',
    podcastIndexTranscriptUrl: '',
    socialInteractUrl: ''
  });
}

function makeFeed(baseline: number): Feed {
  return new Feed({
    id: 1,
    title: 'T',
    customTitle: '',
    fileUrl: '',
    downloadUrl: 'https://example.com/feed.xml',
    lastRefreshAttempt: 0,
    link: '',
    description: '',
    paymentLink: '',
    lastUpdate: '',
    language: '',
    author: '',
    imageUrl: '',
    type: 'rss',
    feedIdentifier: 'id',
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
    inboxBaseline: baseline
  });
}

/**
 * 收件箱基线：批量导入以「导入时刻」为界，只有之后发布的单集才进收件箱。
 * 旧行为会把整库历史剧集都标成 read=-1（86 个订阅 = 15519 条），收件箱被灌满。
 */
export default function inboxBaselineTest() {
  describe('InboxBaselineTest', () => {
    it('BeforeBaselineIsHistory', 0, () => {
      expect(InboxBaseline.isBefore(BASELINE, 9999, true)).assertTrue();
      expect(InboxBaseline.isBefore(BASELINE, BASELINE, true)).assertTrue();
      expect(InboxBaseline.isBefore(BASELINE, 9000, false)).assertTrue();
    });

    it('AfterBaselineIsNew', 0, () => {
      expect(InboxBaseline.isBefore(BASELINE, BASELINE + 1, true)).assertFalse();
      expect(InboxBaseline.isBefore(BASELINE, 20000, false)).assertFalse();
    });

    it('MissingPubDateOnlyHistoryOnFirstSubscribe', 0, () => {
      expect(InboxBaseline.isBefore(BASELINE, 0, true)).assertTrue();
      expect(InboxBaseline.isBefore(BASELINE, 0, false)).assertFalse();
    });

    it('UnsetBaselineKeepsLegacyBehaviour', 0, () => {
      expect(InboxBaseline.isBefore(0, 12345, true)).assertFalse();
    });

    it('FeedItemForm', 0, () => {
      const feed: Feed = makeFeed(BASELINE);
      expect(InboxBaseline.isItemBefore(makeItem(1, 5000), feed, true)).assertTrue();
      expect(InboxBaseline.isItemBefore(makeItem(2, 15000), feed, true)).assertFalse();
    });
  });
}
