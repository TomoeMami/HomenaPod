# 纯逻辑运行时验证（PowerShell 版，替代 runtime-pure-test.sh）
# 把纯模型/工具 .ets 编译为 JS，用 Node assert 断言；不依赖 python3/全局 tsc。
# 用法：pwsh -File scripts/runtime-pure-test.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$src = Join-Path $root 'entry/src/main/ets'
$work = Join-Path $root '.dsh-hvigor-tmp/pure-test'
$out = Join-Path $work 'out'
# 依赖 tsc 与 node：优先用 DEVECO_TSC / DEVECO_NODE 显式指定，
# 其次在 DEVECO_HOME（DevEco Studio 安装目录）下按相对路径查找，最后回退到 PATH。
function Find-Tool([string]$explicit, [string]$relative, [string]$fallbackCmd) {
  if ($explicit -and (Test-Path $explicit)) { return $explicit }
  if ($env:DEVECO_HOME) {
    $candidate = Join-Path $env:DEVECO_HOME $relative
    if (Test-Path $candidate) { return $candidate }
  }
  $cmd = Get-Command $fallbackCmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}
$tsc = Find-Tool $env:DEVECO_TSC 'tools\hvigor\hvigor\node_modules\typescript\bin\tsc' 'tsc'
$node = Find-Tool $env:DEVECO_NODE 'tools\node\node.exe' 'node'

if (-not $tsc) {
  throw "找不到 tsc。请设置 DEVECO_HOME 指向 DevEco Studio 安装目录，或设置 DEVECO_TSC 指向 typescript/bin/tsc。"
}
if (-not $node) {
  throw "找不到 node。请安装 Node.js，或设置 DEVECO_NODE 指向 node 可执行文件。"
}
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $work 'model'), (Join-Path $work 'utils'), (Join-Path $work 'parser') -Force | Out-Null

$models = @('Enums','Feed','FeedItem','FeedMedia','FeedPreferences','Chapter','Playable','QueueItem',
            'DownloadLogEntry','FeedFilter','FeedItemFilter')
$utils = @('DurationUtils','DateUtils','MimeTypeUtils','HtmlCleaner','SortUtils','InboxBaseline')
$parser = @('XmlReader','FeedParser')
foreach ($m in $models) { Copy-Item (Join-Path $src "model/$m.ets") (Join-Path $work "model/$m.ts") }
foreach ($u in $utils) { Copy-Item (Join-Path $src "utils/$u.ets") (Join-Path $work "utils/$u.ts") }
foreach ($p in $parser) { Copy-Item (Join-Path $src "parser/$p.ets") (Join-Path $work "parser/$p.ts") }

@"
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "moduleResolution": "node",
    "strict": false,
    "outDir": "$($out -replace '\\','/')",
    "esModuleInterop": true
  },
  "include": ["**/*.ts"]
}
"@ | Set-Content (Join-Path $work 'tsconfig.json') -Encoding UTF8

Push-Location $work
try {
  & $node $tsc -p tsconfig.json
  if ($LASTEXITCODE -ne 0) { throw "tsc failed with $LASTEXITCODE" }
} finally { Pop-Location }

$runJs = Join-Path $out 'run.js'
@'
const assert = require('assert');
const { DurationUtils } = require('./utils/DurationUtils.js');
const { DateUtils } = require('./utils/DateUtils.js');
const { MimeTypeUtils } = require('./utils/MimeTypeUtils.js');
const { HtmlCleaner } = require('./utils/HtmlCleaner.js');
const { SortUtils } = require('./utils/SortUtils.js');
const { MediaType, SortOrder } = require('./model/Enums.js');
const { Playable } = require('./model/Playable.js');
const { FeedFilter } = require('./model/FeedFilter.js');
const { FeedMedia } = require('./model/FeedMedia.js');
const { Feed } = require('./model/Feed.js');
const { FeedState } = require('./model/Enums.js');
const { QueueItem } = require('./model/QueueItem.js');
const { Chapter } = require('./model/Chapter.js');
const { FeedItemFilter } = require('./model/FeedItemFilter.js');
const { FeedItem } = require('./model/FeedItem.js');
const { InboxBaseline } = require('./utils/InboxBaseline.js');

// ---- 既有回归 ----
assert.strictEqual(DurationUtils.parseToMillis('01:30'), 90000);
assert.strictEqual(DurationUtils.parseToMillis('1:02:03'), 3723000);
assert.strictEqual(DurationUtils.parseToMillis('PT1H2M3S'), 3723000);
assert.strictEqual(DurationUtils.format(90000), '1:30');
assert.strictEqual(DurationUtils.format(3723000), '1:02:03');
assert.strictEqual(DateUtils.parseToEpochMillis('1970-01-01T00:00:00Z'), 0);
assert.strictEqual(MimeTypeUtils.mediaTypeFromMime('audio/mpeg'), MediaType.AUDIO);
assert.strictEqual(MimeTypeUtils.guessExtension('http://x/a.mp3', 'audio/mpeg'), '.mp3');
assert.strictEqual(HtmlCleaner.stripHtml('<p>Hello <b>World</b></p>'), 'Hello World');

function makeItem(id, title, pubDate, durationMs, feedId) {
  const media = new FeedMedia({
    id: id * 10, duration: durationMs, fileUrl: '', downloadUrl: 'https://e/' + id + '.mp3', downloadDate: 0,
    position: 0, size: 0, mimeType: 'audio/mpeg', lastPlayedTimeHistory: 0, feedItemId: id,
    playedDuration: 0, hasEmbeddedPicture: false, lastPlayedTimeStatistics: 0
  });
  return new FeedItem({
    id, title, pubDate, isPlayed: false, link: '', description: 'desc ' + title, paymentLink: '',
    media, feedId, hasChapters: false, itemIdentifier: 'guid-' + id, imageUrl: '', autoDownloadEnabled: false,
    podcastIndexChapterUrl: '', podcastIndexTranscriptType: '', podcastIndexTranscriptUrl: '', socialInteractUrl: ''
  });
}

// ---- Playable 新字段 ----
const p = new Playable(1, 2, 'T', 'F', 'http://u', '/local/x.mp3', 0, 0, MediaType.AUDIO, 1.5, 30, 20, 0.75);
assert.strictEqual(p.getSourceUrl(), '/local/x.mp3');
assert.strictEqual(p.speed, 1.5);
assert.strictEqual(p.skipIntro, 30);
assert.strictEqual(p.skipEnding, 20);
assert.strictEqual(p.volumeAdaption, 0.75);

// ---- FeedFilter ----
const item = makeItem(1, 'Hello World', 0, 60000, 1);
assert.strictEqual(new FeedFilter().shouldAutoDownload(item), true);
assert.strictEqual(new FeedFilter('hello', 'bad', -1).shouldAutoDownload(item), true);
assert.strictEqual(new FeedFilter('bad', '', -1).shouldAutoDownload(item), false);
assert.strictEqual(new FeedFilter('', '', 120).shouldAutoDownload(item), false);
assert.strictEqual(new FeedFilter('"hello world"', '', -1).shouldAutoDownload(item), true);
assert.strictEqual(new FeedFilter('"hello world"', '', -1).shouldAutoDownload(makeItem(2, 'hello', 0, 60000, 1)), false);

// ---- SortUtils：6 种排序 ----
const items = [makeItem(3, 'Charlie', 3000, 60000, 1), makeItem(1, 'Alpha', 1000, 180000, 1),
               makeItem(4, 'Delta', 4000, 30000, 2), makeItem(2, 'Bravo', 2000, 120000, 2)];
assert.strictEqual(SortUtils.sortItems(items, SortOrder.DATE_NEW_OLD)[0].id, 4);
assert.strictEqual(SortUtils.sortItems(items, SortOrder.DATE_OLD_NEW)[0].id, 1);
assert.strictEqual(SortUtils.sortItems(items, SortOrder.TITLE_A_Z)[0].title, 'Alpha');
assert.strictEqual(SortUtils.sortItems(items, SortOrder.TITLE_Z_A)[0].title, 'Delta');
assert.strictEqual(SortUtils.sortItems(items, SortOrder.DURATION_SHORT_LONG)[0].id, 4);
assert.strictEqual(SortUtils.sortItems(items, SortOrder.DURATION_LONG_SHORT)[0].id, 1);

// ---- 智能乱序不变量：相邻不来自同一订阅 ----
const skew = [makeItem(1, 'A1', 5000, 1000, 1), makeItem(2, 'A2', 4000, 1000, 1),
              makeItem(3, 'A3', 3000, 1000, 1), makeItem(4, 'B1', 2000, 1000, 2)];
const smart = SortUtils.smartShuffle(skew);
assert.strictEqual(smart.length, 4);
let adjacentSame = 0;
for (let i = 1; i < smart.length; i++) { if (smart[i].feedId === smart[i - 1].feedId) adjacentSame++; }
assert.ok(adjacentSame <= 1, 'smart shuffle should interleave feeds, adjacentSame=' + adjacentSame);
assert.strictEqual(SortUtils.shuffle(items).length, 4);

// ---- 既有模型回归 ----
assert.strictEqual(new FeedItemFilter(FeedItemFilter.UNPLAYED).matches(item), true);
const feed = new Feed({
  id: 1, title: 'T', customTitle: 'Custom', fileUrl: '', downloadUrl: '', lastRefreshAttempt: 0,
  link: '', description: '', paymentLink: '', lastUpdate: '', language: '', author: '', imageUrl: '',
  type: 'rss', feedIdentifier: 'id', autoDownloadEnabled: true, username: '', password: '',
  includeFilter: '', excludeFilter: '', minimalDurationFilter: -1, keepUpdated: true, isPaged: false,
  nextPageLink: '', hide: '', sortOrder: 0, lastUpdateFailed: false, autoDeleteAction: 0,
  feedPlaybackSpeed: 0, feedSkipSilence: 0, feedVolumeAdaption: 0, feedTags: '', feedSkipIntro: 0,
  feedSkipEnding: 0, episodeNotification: false, state: FeedState.STATE_SUBSCRIBED, newEpisodesAction: 0,
  inboxBaseline: 0
});
assert.strictEqual(feed.getTitle(), 'Custom');

// ---- OPML 批量导入的「先登记、后抓取」模型（Feed.pending）----
const pending = Feed.pending('https://example.com/feed.xml', '示例播客', 'https://example.com', 1700000000000);
assert.strictEqual(pending.state, FeedState.STATE_SUBSCRIBED);
assert.strictEqual(pending.downloadUrl, 'https://example.com/feed.xml');
assert.strictEqual(pending.link, 'https://example.com');
assert.strictEqual(pending.getTitle(), '示例播客');
assert.strictEqual(pending.items.length, 0);
assert.strictEqual(pending.inboxBaseline, 1700000000000);
assert.strictEqual(pending.keepUpdated, true);
assert.strictEqual(pending.lastRefreshAttempt, 0);
// 未抓取过的订阅（lastRefreshAttempt = 0）在整库刷新里按「首次订阅」处理：
// 未带日期的历史单集也不算新，不会灌进收件箱。
const undatedItem = makeItem(9, 'no date', 0, 60000, 0);
assert.strictEqual(InboxBaseline.isItemBefore(undatedItem, pending, pending.lastRefreshAttempt <= 0), true);
assert.strictEqual(InboxBaseline.isItemBefore(undatedItem, pending, false), false);

assert.strictEqual(new QueueItem(1, 2, 3).toValues().feeditem, 2);
assert.strictEqual(new Chapter(1, 't', 2000, 3, 'link', 'img').start, 2000);

// ---- FeedParser 封面归属：频道封面 vs 单集封面 ----
const { FeedParser } = require('./parser/FeedParser.js');
const feedXml = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"',
  '     xmlns:media="http://search.yahoo.com/mrss/" version="2.0">',
  '  <channel>',
  '    <title>Chan</title>',
  '    <itunes:image href="https://cdn.example/cover.jpg"/>',
  '    <item>',
  '      <title>ep1</title><guid>g1</guid>',
  '      <enclosure url="https://cdn.example/1.m4a" type="audio/mp4" length="100"/>',
  '      <itunes:image href="https://cdn.example/ep1.png"/>',
  '    </item>',
  '    <item>',
  '      <title>ep2</title><guid>g2</guid>',
  '      <media:thumbnail url="https://cdn.example/ep2-thumb.jpg"/>',
  '      <media:content url="https://cdn.example/2.m4a" type="audio/mp4" length="200"/>',
  '    </item>',
  '    <item>',
  '      <title>ep3</title><guid>g3</guid>',
  '      <media:content url="https://cdn.example/ep3.png" medium="image"/>',
  '      <media:content url="https://cdn.example/3.m4a" type="audio/mp4"/>',
  '    </item>',
  '    <item>',
  '      <title>ep4</title><guid>g4</guid>',
  '      <media:group>',
  '        <media:content url="https://cdn.example/ep4.jpg" type="image/jpeg"/>',
  '        <media:content url="https://cdn.example/4.m4a" type="audio/mp4"/>',
  '      </media:group>',
  '    </item>',
  '  </channel>',
  '</rss>'
].join('\n');
const parsedFeed = FeedParser.parseFeed(feedXml);
// 频道封面不能被单集内的 itunes:image 覆盖（旧缺陷：播客封面变成最后一集的封面）
assert.strictEqual(parsedFeed.feed.imageUrl, 'https://cdn.example/cover.jpg');
assert.strictEqual(parsedFeed.feed.items.length, 4);
assert.strictEqual(parsedFeed.feed.items[0].imageUrl, 'https://cdn.example/ep1.png');
assert.strictEqual(parsedFeed.feed.items[1].imageUrl, 'https://cdn.example/ep2-thumb.jpg');
assert.strictEqual(parsedFeed.feed.items[2].imageUrl, 'https://cdn.example/ep3.png');
assert.strictEqual(parsedFeed.feed.items[3].imageUrl, 'https://cdn.example/ep4.jpg');
// media:content 的音频变体仍应落成媒体（不能被当成封面）
assert.strictEqual(parsedFeed.feed.items[0].media.downloadUrl, 'https://cdn.example/1.m4a');
assert.strictEqual(parsedFeed.feed.items[1].media.downloadUrl, 'https://cdn.example/2.m4a');
assert.strictEqual(parsedFeed.feed.items[2].media.downloadUrl, 'https://cdn.example/3.m4a');
assert.strictEqual(parsedFeed.feed.items[3].media.downloadUrl, 'https://cdn.example/4.m4a');
assert.strictEqual(parsedFeed.feed.items[3].media.mimeType, 'audio/mp4');
// 单集无自己的封面时回落频道封面
const fallbackXml = '<rss version="2.0"><channel><title>C</title>'
  + '<image><url>https://cdn.example/c.png</url></image>'
  + '<item><title>e</title><guid>g</guid></item></channel></rss>';
const parsedFallback = FeedParser.parseFeed(fallbackXml);
assert.strictEqual(parsedFallback.feed.imageUrl, 'https://cdn.example/c.png');
assert.strictEqual(parsedFallback.feed.items[0].imageUrl, 'https://cdn.example/c.png');
// ---- 收件箱基线：批量导入以「导入时刻」为界，只有之后发布的单集才进收件箱 ----
const BASELINE = 10000;
// 导入前发布的历史剧集：不管动作设置如何，都不算「新」
assert.strictEqual(InboxBaseline.isBefore(BASELINE, 9999, true), true);
assert.strictEqual(InboxBaseline.isBefore(BASELINE, BASELINE, true), true);
assert.strictEqual(InboxBaseline.isBefore(BASELINE, 9000, false), true);
// 导入之后发布的单集：走原有动作规则（默认 ADD_TO_INBOX → 进收件箱）
assert.strictEqual(InboxBaseline.isBefore(BASELINE, 10001, true), false);
assert.strictEqual(InboxBaseline.isBefore(BASELINE, 20000, false), false);
// 无发布日期：只在首次订阅/批量导入时算历史，之后的刷新沿用原动作（否则无日期的源永远进不了收件箱）
assert.strictEqual(InboxBaseline.isBefore(BASELINE, 0, true), true);
assert.strictEqual(InboxBaseline.isBefore(BASELINE, 0, false), false);
// 未设置基线（老库升级前的订阅）：不做判定，保持原行为
assert.strictEqual(InboxBaseline.isBefore(0, 12345, true), false);
// Feed + FeedItem 形态
const baselineFeed = new Feed({
  id: 7, title: 'T', customTitle: '', fileUrl: '', downloadUrl: '', lastRefreshAttempt: 0,
  link: '', description: '', paymentLink: '', lastUpdate: '', language: '', author: '', imageUrl: '',
  type: 'rss', feedIdentifier: 'id', autoDownloadEnabled: true, username: '', password: '',
  includeFilter: '', excludeFilter: '', minimalDurationFilter: -1, keepUpdated: true, isPaged: false,
  nextPageLink: '', hide: '', sortOrder: 0, lastUpdateFailed: false, autoDeleteAction: 0,
  feedPlaybackSpeed: 0, feedSkipSilence: 0, feedVolumeAdaption: 0, feedTags: '', feedSkipIntro: 0,
  feedSkipEnding: 0, episodeNotification: false, state: FeedState.STATE_SUBSCRIBED, newEpisodesAction: 0,
  inboxBaseline: BASELINE
});
assert.strictEqual(InboxBaseline.isItemBefore(makeItem(1, 'old', 5000, 1000, 7), baselineFeed, true), true);
assert.strictEqual(InboxBaseline.isItemBefore(makeItem(2, 'new', 15000, 1000, 7), baselineFeed, true), false);

console.log('RUNTIME PURE LOGIC TESTS PASSED');
'@ | Set-Content $runJs -Encoding UTF8

& $node $runJs
if ($LASTEXITCODE -ne 0) { throw "runtime tests failed with $LASTEXITCODE" }
