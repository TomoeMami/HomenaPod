// 生成的 feed fixture 内嵌常量（单元测试宿主 rawfile 为空时的回退；真机仍走 rawfile）
export const FIXTURES: Map<string, string> = new Map<string, string>();

FIXTURES.set('feed-atom-testAtomBasic.xml', `<?xml version='1.0' encoding='UTF-8' ?><feed xmlns="http://www.w3.org/2005/Atom"><id>http://example.com/feed</id><title>title</title><link rel="alternate" href="http://example.com" /><subtitle>This is the description</subtitle><logo>http://example.com/picture</logo><link rel="payment" href="http://example.com/payment" type="text/html" /><entry><id>http://example.com/item-0</id><title>item-0</title><link rel="alternate" href="http://example.com/items/0" /><published>1970-01-01T00:00:00Z</published><link rel="enclosure" href="http://example.com/media-0" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-1</id><title>item-1</title><link rel="alternate" href="http://example.com/items/1" /><published>1970-01-01T00:01:00Z</published><link rel="enclosure" href="http://example.com/media-1" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-2</id><title>item-2</title><link rel="alternate" href="http://example.com/items/2" /><published>1970-01-01T00:02:00Z</published><link rel="enclosure" href="http://example.com/media-2" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-3</id><title>item-3</title><link rel="alternate" href="http://example.com/items/3" /><published>1970-01-01T00:03:00Z</published><link rel="enclosure" href="http://example.com/media-3" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-4</id><title>item-4</title><link rel="alternate" href="http://example.com/items/4" /><published>1970-01-01T00:04:00Z</published><link rel="enclosure" href="http://example.com/media-4" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-5</id><title>item-5</title><link rel="alternate" href="http://example.com/items/5" /><published>1970-01-01T00:05:00Z</published><link rel="enclosure" href="http://example.com/media-5" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-6</id><title>item-6</title><link rel="alternate" href="http://example.com/items/6" /><published>1970-01-01T00:06:00Z</published><link rel="enclosure" href="http://example.com/media-6" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-7</id><title>item-7</title><link rel="alternate" href="http://example.com/items/7" /><published>1970-01-01T00:07:00Z</published><link rel="enclosure" href="http://example.com/media-7" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-8</id><title>item-8</title><link rel="alternate" href="http://example.com/items/8" /><published>1970-01-01T00:08:00Z</published><link rel="enclosure" href="http://example.com/media-8" type="audio/mp3" length="1048576" /></entry><entry><id>http://example.com/item-9</id><title>item-9</title><link rel="alternate" href="http://example.com/items/9" /><published>1970-01-01T00:09:00Z</published><link rel="enclosure" href="http://example.com/media-9" type="audio/mp3" length="1048576" /></entry></feed>`);
FIXTURES.set('feed-atom-testEmptyRelLinks.xml', `<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
   <id>http://example.com/feed</id>
   <title>title</title>
   <link href="http://example.com" />
   <subtitle>This is the description</subtitle>
   <logo>http://example.com/picture</logo>
   <entry>
      <id>http://example.com/item-0</id>
      <title>item-0</title>
      <link href="http://example.com/items/0" />
      <published>1970-01-01T00:00:00Z</published>
   </entry>
</feed>
`);
FIXTURES.set('feed-atom-testLogoWithWhitespace.xml', `<?xml version='1.0' encoding='UTF-8' ?><feed xmlns="http://www.w3.org/2005/Atom"><id>http://example.com/feed</id><title>title</title><link rel="alternate" href="http://example.com" /><subtitle>This is the description</subtitle><link rel="payment" href="http://example.com/payment" type="text/html" /><logo> https://example.com/image.png
</logo></feed>`);
FIXTURES.set('feed-rss-testImageWithWhitespace.xml', `<?xml version='1.0' encoding='UTF-8' ?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>title</title><description>This is the description</description><link>http://example.com</link><language>en</language><atom:link rel="payment" href="http://example.com/payment" type="text/html" /><image><url> https://example.com/image.png
</url></image></channel></rss>`);
FIXTURES.set('feed-rss-testMediaContentMime.xml', `<?xml version='1.0' encoding='UTF-8' ?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>title</title><description>This is the description</description><link>http://example.com</link><language>en</language><atom:link rel="payment" href="http://example.com/payment" type="text/html" /><item xmlns:media="http://search.yahoo.com/mrss/"><media:content url="https://www.example.com/file.mp4" medium="video" /></item></channel></rss>`);
FIXTURES.set('feed-rss-testMultipleFundingTags.xml', `<?xml version='1.0' encoding='UTF-8' ?>
<rss version="2.0" xmlns:podcast="https://podcastindex.org/namespace/1.0">
    <channel>
        <title>title</title>
    </channel>
    <podcast:funding url="https://example.com/funding1">Text 1</podcast:funding>
    <podcast:funding url="https://example.com/funding2">Text 2</podcast:funding>
    <podcast:funding url="https://example.com/funding3" />
</rss>
`);
FIXTURES.set('feed-rss-testPodcastIndexTranscript.xml', `<?xml version='1.0' encoding='UTF-8' ?>
<rss version="2.0" xmlns:podcast="https://podcastindex.org/namespace/1.0">
    <channel>
        <title>title</title>
        <item>
            <title>Podcasts in YouTube make it to the UK</title>
            <link>https://podnews.net/update/youtube-podcasts-uk</link>
            <pubDate>Tue, 10 Oct 2023 08:46:31 +0000</pubDate>
            <podcast:transcript url="https://podnews.net/audio/podnews231011.mp3.json" type="application/json" />
            <podcast:transcript url="https://podnews.net/audio/podnews231011.mp3.srt" type="application/srt" />
        </item>
    </channel>
</rss>
`);
FIXTURES.set('feed-rss-testRss2Basic.xml', `<?xml version='1.0' encoding='UTF-8' ?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>title</title><description>This is the description</description><link>http://example.com</link><language>en</language><image><url>http://example.com/picture</url></image><atom:link rel="payment" href="http://example.com/payment" type="text/html" /><item><title>item-0</title><link>http://example.com/items/0</link><pubDate>01 Jan 70 01:00:00 +0100</pubDate><guid>http://example.com/item-0</guid><enclosure url="http://example.com/media-0" length="1048576" type="audio/mp3" /></item><item><title>item-1</title><link>http://example.com/items/1</link><pubDate>01 Jan 70 01:01:00 +0100</pubDate><guid>http://example.com/item-1</guid><enclosure url="http://example.com/media-1" length="1048576" type="audio/mp3" /></item><item><title>item-2</title><link>http://example.com/items/2</link><pubDate>01 Jan 70 01:02:00 +0100</pubDate><guid>http://example.com/item-2</guid><enclosure url="http://example.com/media-2" length="1048576" type="audio/mp3" /></item><item><title>item-3</title><link>http://example.com/items/3</link><pubDate>01 Jan 70 01:03:00 +0100</pubDate><guid>http://example.com/item-3</guid><enclosure url="http://example.com/media-3" length="1048576" type="audio/mp3" /></item><item><title>item-4</title><link>http://example.com/items/4</link><pubDate>01 Jan 70 01:04:00 +0100</pubDate><guid>http://example.com/item-4</guid><enclosure url="http://example.com/media-4" length="1048576" type="audio/mp3" /></item><item><title>item-5</title><link>http://example.com/items/5</link><pubDate>01 Jan 70 01:05:00 +0100</pubDate><guid>http://example.com/item-5</guid><enclosure url="http://example.com/media-5" length="1048576" type="audio/mp3" /></item><item><title>item-6</title><link>http://example.com/items/6</link><pubDate>01 Jan 70 01:06:00 +0100</pubDate><guid>http://example.com/item-6</guid><enclosure url="http://example.com/media-6" length="1048576" type="audio/mp3" /></item><item><title>item-7</title><link>http://example.com/items/7</link><pubDate>01 Jan 70 01:07:00 +0100</pubDate><guid>http://example.com/item-7</guid><enclosure url="http://example.com/media-7" length="1048576" type="audio/mp3" /></item><item><title>item-8</title><link>http://example.com/items/8</link><pubDate>01 Jan 70 01:08:00 +0100</pubDate><guid>http://example.com/item-8</guid><enclosure url="http://example.com/media-8" length="1048576" type="audio/mp3" /></item><item><title>item-9</title><link>http://example.com/items/9</link><pubDate>01 Jan 70 01:09:00 +0100</pubDate><guid>http://example.com/item-9</guid><enclosure url="http://example.com/media-9" length="1048576" type="audio/mp3" /></item></channel></rss>`);
FIXTURES.set('feed-rss-testUnsupportedElements.xml', `<?xml version='1.0' encoding='UTF-8' ?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
    <channel>
        <title>title</title>
        <item>
            <title>item-0</title>
        </item>
        <unsupported-element>
            <item>
                <title>item-1</title>
            </item>
        </unsupported-element>
    </channel>
</rss>
`);
