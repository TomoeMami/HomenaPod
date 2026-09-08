# 解析夹具断言要点（来源：AntennaPod RssParserTest/AtomParserTest）

共 9 个 XML fixture。T1.8 回归测试必须覆盖下列关键断言。

## RSS2 基础（feed-rss-testRss2Basic.xml）
- feed.type == RSS2
- title = "title"；language = "en"；link = "http://example.com"
- description = "This is the description"
- paymentLinks[0].url = "http://example.com/payment"
- imageUrl = "http://example.com/picture"
- items.size == 10
- 第 i 条：itemIdentifier = "http://example.com/item-" + i；title = "item-" + i；
  link = "http://example.com/items/" + i；pubDate = 1970-01-01T00:00:00Z + i * 60000ms；
  imageUrl = "http://example.com/picture"；hasMedia == true；
  media.downloadUrl = "http://example.com/media-" + i；media.size = 1048576；media.mimeType = "audio/mp3"

## RSS 图片含空白（feed-rss-testImageWithWhitespace.xml）
- imageUrl = "https://example.com/image.png"（修剪空白）
- items.size == 0

## RSS media:content MIME（feed-rss-testMediaContentMime.xml）
- items.size == 1
- media.mediaType == VIDEO；media.downloadUrl = "https://www.example.com/file.mp4"

## RSS 多个 funding（feed-rss-testMultipleFundingTags.xml）
- paymentLinks.size == 3
- [0] content="Text 1" url="https://example.com/funding1"
- [1] content="Text 2" url="https://example.com/funding2"
- [2] content="" url="https://example.com/funding3"

## RSS PodcastIndex 转录（feed-rss-testPodcastIndexTranscript.xml）
- items[0].transcriptUrl = "https://podnews.net/audio/podnews231011.mp3.json"
- items[0].transcriptType = "application/json"

## RSS 未支持元素（feed-rss-testUnsupportedElements.xml）
- items.size == 1；items[0].title = "item-0"（未知标签不中断解析）

## Atom 基础（feed-atom-testAtomBasic.xml）
- feed.type == ATOM1；title = "title"；feedIdentifier = "http://example.com/feed"
- link = "http://example.com"；description = "This is the description"
- paymentLinks[0].url = "http://example.com/payment"；imageUrl = "http://example.com/picture"
- items.size == 10；每项同 RSS2 基础：itemIdentifier/title/link/pubDate/图片/媒体 URL、size、mimeType

## Atom 空 rel 链接（feed-atom-testEmptyRelLinks.xml）
- paymentLinks == null/empty；imageUrl = "http://example.com/picture"
- items.size == 1；item.media == null（hasMedia false）
- item.pubDate = epoch 0

## Atom logo 含空白（feed-atom-testLogoWithWhitespace.xml）
- imageUrl = "https://example.com/image.png"
- items.size == 0
