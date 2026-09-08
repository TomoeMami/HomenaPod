// Hypium regression tests for FeedParser (T1.8). Fixtures are stored in rawfile/feed_test.
import { describe, it, expect } from '@ohos/hypium';
import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import { FeedParser, ParseResult } from '../../main/ets/parser/FeedParser';

async function parseRaw(fileName: string): Promise<ParseResult> {
  const data: Uint8Array = await resourceManager.getRawFileContent('feed_test/' + fileName);
  const decoder: util.TextDecoder = util.TextDecoder.create();
  const xml: string = decoder.decodeToString(data);
  return FeedParser.parseFeed(xml);
}

export default function feedParserTest() {
  describe('FeedParserRegression', () => {
    it('Rss2Basic', 0, async () => {
      const result: ParseResult = await parseRaw('feed-rss-testRss2Basic.xml');
      expect(result.feed.type).assertEqual('rss');
      expect(result.feed.title).assertEqual('title');
      expect(result.feed.language).assertEqual('en');
      expect(result.feed.link).assertEqual('http://example.com');
      expect(result.feed.imageUrl).assertEqual('http://example.com/picture');
      expect(result.feed.items.length).assertEqual(10);
      expect(result.feed.items[0].title).assertEqual('item-0');
      expect(result.feed.items[0].link).assertEqual('http://example.com/items/0');
      expect(result.feed.items[0].media?.downloadUrl).assertEqual('http://example.com/media-0');
      expect(result.feed.items[0].media?.size).assertEqual(1048576);
      expect(result.feed.items[0].media?.mimeType).assertEqual('audio/mp3');
    });

    it('RssImageWhitespace', 0, async () => {
      const result: ParseResult = await parseRaw('feed-rss-testImageWithWhitespace.xml');
      expect(result.feed.imageUrl).assertEqual('https://example.com/image.png');
      expect(result.feed.items.length).assertEqual(0);
    });

    it('RssMediaContentMime', 0, async () => {
      const result: ParseResult = await parseRaw('feed-rss-testMediaContentMime.xml');
      expect(result.feed.items.length).assertEqual(1);
      expect(result.feed.items[0].media?.mimeType).assertEqual('video/mp4');
      expect(result.feed.items[0].media?.downloadUrl).assertEqual('https://www.example.com/file.mp4');
    });

    it('RssMultipleFunding', 0, async () => {
      const result: ParseResult = await parseRaw('feed-rss-testMultipleFundingTags.xml');
      expect(result.feed.paymentLinks.length).assertEqual(3);
      expect(result.feed.paymentLinks[0].url).assertEqual('https://example.com/funding1');
      expect(result.feed.paymentLinks[1].url).assertEqual('https://example.com/funding2');
      expect(result.feed.paymentLinks[2].url).assertEqual('https://example.com/funding3');
    });

    it('RssPodcastIndexTranscript', 0, async () => {
      const result: ParseResult = await parseRaw('feed-rss-testPodcastIndexTranscript.xml');
      expect(result.feed.items[0].podcastIndexTranscriptUrl).assertEqual('https://podnews.net/audio/podnews231011.mp3.json');
      expect(result.feed.items[0].podcastIndexTranscriptType).assertEqual('application/json');
    });

    it('RssUnsupportedElements', 0, async () => {
      const result: ParseResult = await parseRaw('feed-rss-testUnsupportedElements.xml');
      expect(result.feed.items.length).assertEqual(1);
      expect(result.feed.items[0].title).assertEqual('item-0');
    });

    it('AtomBasic', 0, async () => {
      const result: ParseResult = await parseRaw('feed-atom-testAtomBasic.xml');
      expect(result.feed.type).assertEqual('atom');
      expect(result.feed.feedIdentifier).assertEqual('http://example.com/feed');
      expect(result.feed.link).assertEqual('http://example.com');
      expect(result.feed.imageUrl).assertEqual('http://example.com/picture');
      expect(result.feed.items.length).assertEqual(10);
      expect(result.feed.items[0].itemIdentifier).assertEqual('http://example.com/item-0');
      expect(result.feed.items[0].media?.downloadUrl).assertEqual('http://example.com/media-0');
    });

    it('AtomEmptyRelLinks', 0, async () => {
      const result: ParseResult = await parseRaw('feed-atom-testEmptyRelLinks.xml');
      expect(result.feed.items.length).assertEqual(1);
      expect(result.feed.items[0].link).assertEqual('http://example.com/items/0');
      expect(result.feed.items[0].hasMedia()).assertFalse();
    });

    it('AtomLogoWhitespace', 0, async () => {
      const result: ParseResult = await parseRaw('feed-atom-testLogoWithWhitespace.xml');
      expect(result.feed.imageUrl).assertEqual('https://example.com/image.png');
      expect(result.feed.items.length).assertEqual(0);
    });
  });
}
