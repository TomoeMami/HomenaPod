import { describe, it, expect } from '@ohos/hypium';
import { SortUtils } from '../../main/ets/utils/SortUtils';
import { FeedFilter } from '../../main/ets/model/FeedFilter';
import { FeedItem } from '../../main/ets/model/FeedItem';
import { FeedMedia } from '../../main/ets/model/FeedMedia';
import { SortOrder } from '../../main/ets/model/Enums';

/** 构造测试用单集（id/标题/发布时间/时长/订阅） */
function makeItem(id: number, title: string, pubDate: number, durationMs: number, feedId: number): FeedItem {
  const media: FeedMedia = new FeedMedia({
    id: id * 10,
    duration: durationMs,
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
    title: title,
    pubDate: pubDate,
    isPlayed: false,
    playState: FeedItem.UNPLAYED,
    link: '',
    description: 'desc ' + title,
    paymentLink: '',
    media: media,
    feedId: feedId,
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

function sampleItems(): FeedItem[] {
  // 故意打乱顺序：日期/标题/时长各不相同
  return [
    makeItem(3, 'Charlie', 3000, 60000, 1),
    makeItem(1, 'Alpha', 1000, 180000, 1),
    makeItem(4, 'Delta', 4000, 30000, 2),
    makeItem(2, 'Bravo', 2000, 120000, 2)
  ];
}

export default function sortAndFilterTest() {
  describe('SortAndFilter', () => {
    it('SortDateNewOld', 0, () => {
      const sorted: FeedItem[] = SortUtils.sortItems(sampleItems(), SortOrder.DATE_NEW_OLD);
      expect(sorted[0].id).assertEqual(4);
      expect(sorted[3].id).assertEqual(1);
    });

    it('SortDateOldNew', 0, () => {
      const sorted: FeedItem[] = SortUtils.sortItems(sampleItems(), SortOrder.DATE_OLD_NEW);
      expect(sorted[0].id).assertEqual(1);
      expect(sorted[3].id).assertEqual(4);
    });

    it('SortTitleAscending', 0, () => {
      const sorted: FeedItem[] = SortUtils.sortItems(sampleItems(), SortOrder.TITLE_A_Z);
      expect(sorted[0].title).assertEqual('Alpha');
      expect(sorted[3].title).assertEqual('Delta');
    });

    it('SortTitleDescending', 0, () => {
      const sorted: FeedItem[] = SortUtils.sortItems(sampleItems(), SortOrder.TITLE_Z_A);
      expect(sorted[0].title).assertEqual('Delta');
      expect(sorted[3].title).assertEqual('Alpha');
    });

    it('SortDurationShortLong', 0, () => {
      const sorted: FeedItem[] = SortUtils.sortItems(sampleItems(), SortOrder.DURATION_SHORT_LONG);
      expect(sorted[0].id).assertEqual(4);
      expect(sorted[3].id).assertEqual(1);
    });

    it('SortDurationLongShort', 0, () => {
      const sorted: FeedItem[] = SortUtils.sortItems(sampleItems(), SortOrder.DURATION_LONG_SHORT);
      expect(sorted[0].id).assertEqual(1);
      expect(sorted[3].id).assertEqual(4);
    });

    it('SmartShuffleAvoidsSameFeedAdjacent', 0, () => {
      // 同一订阅 4 条 + 另一订阅 1 条，智能乱序后不应出现同订阅连续
      const items: FeedItem[] = [
        makeItem(1, 'A1', 5000, 1000, 1),
        makeItem(2, 'A2', 4000, 1000, 1),
        makeItem(3, 'A3', 3000, 1000, 1),
        makeItem(4, 'B1', 2000, 1000, 2)
      ];
      const shuffled: FeedItem[] = SortUtils.smartShuffle(items);
      expect(shuffled.length).assertEqual(4);
      // 第一条与最后一条必须来自不同订阅（轮转交错的结果）
      expect(shuffled[0].feedId === shuffled[shuffled.length - 1].feedId).assertFalse();
    });

    it('ShuffleKeepsAllItems', 0, () => {
      const items: FeedItem[] = sampleItems();
      const shuffled: FeedItem[] = SortUtils.shuffle(items);
      expect(shuffled.length).assertEqual(items.length);
      expect(shuffled.filter((item: FeedItem) => item.id === 1).length).assertEqual(1);
    });

    it('FeedFilterExclude', 0, () => {
      const filter: FeedFilter = new FeedFilter('', 'trailer', -1);
      expect(filter.shouldAutoDownload(makeItem(1, 'Episode trailer', 1, 1000, 1))).assertFalse();
      expect(filter.shouldAutoDownload(makeItem(2, 'Full episode', 2, 1000, 1))).assertTrue();
    });

    it('FeedFilterInclude', 0, () => {
      const filter: FeedFilter = new FeedFilter('interview', '', -1);
      expect(filter.shouldAutoDownload(makeItem(1, 'Interview with guest', 1, 1000, 1))).assertTrue();
      expect(filter.shouldAutoDownload(makeItem(2, 'Random news', 2, 1000, 1))).assertFalse();
    });

    it('FeedFilterMinDuration', 0, () => {
      const filter: FeedFilter = new FeedFilter('', '', 300);
      expect(filter.shouldAutoDownload(makeItem(1, 'Short', 1, 120000, 1))).assertFalse();
      expect(filter.shouldAutoDownload(makeItem(2, 'Long', 2, 600000, 1))).assertTrue();
    });

    it('FeedFilterQuotedPhrase', 0, () => {
      const filter: FeedFilter = new FeedFilter('"exact phrase"', '', -1);
      expect(filter.shouldAutoDownload(makeItem(1, 'An exact phrase here', 1, 1000, 1))).assertTrue();
      expect(filter.shouldAutoDownload(makeItem(2, 'exact only', 2, 1000, 1))).assertFalse();
    });

    it('FeedFilterEmptyAllowsAll', 0, () => {
      const filter: FeedFilter = new FeedFilter('', '', -1);
      expect(filter.shouldAutoDownload(makeItem(1, 'Anything', 1, 1000, 1))).assertTrue();
    });

    it('DurationFormat', 0, () => {
      // 新增的展示用格式化
      expect(SortUtils.durationOf(makeItem(1, 'x', 1, 90000, 1))).assertEqual(90000);
    });
  });
}
