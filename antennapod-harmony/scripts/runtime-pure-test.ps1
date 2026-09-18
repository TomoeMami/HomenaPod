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
New-Item -ItemType Directory -Path (Join-Path $work 'model'), (Join-Path $work 'utils'), (Join-Path $work 'parser'), (Join-Path $work 'player') -Force | Out-Null

$models = @('Enums','Feed','FeedItem','FeedMedia','FeedPreferences','Chapter','Playable','QueueItem',
            'DownloadLogEntry','FeedFilter','FeedItemFilter')
$utils = @('DurationUtils','DateUtils','MimeTypeUtils','HtmlCleaner','ShownotesText','SortUtils','InboxBaseline')
$parser = @('XmlReader','FeedParser')
# player 下只有「纯逻辑」文件能进这里：不 import 任何 @kit.*（OutputDevicePolicy 便是如此）
$player = @('OutputDevicePolicy','MediaButtonPolicy')
foreach ($m in $models) { Copy-Item (Join-Path $src "model/$m.ets") (Join-Path $work "model/$m.ts") }
foreach ($u in $utils) { Copy-Item (Join-Path $src "utils/$u.ets") (Join-Path $work "utils/$u.ts") }
foreach ($p in $parser) { Copy-Item (Join-Path $src "parser/$p.ets") (Join-Path $work "parser/$p.ts") }
foreach ($q in $player) { Copy-Item (Join-Path $src "player/$q.ets") (Join-Path $work "player/$q.ts") }

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
const { ShownotesText } = require('./utils/ShownotesText.js');
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

// ---- 耳机/蓝牙断开的暂停策略（OutputDevicePolicy）----
const { OutputDevicePolicy, DeviceClasses, DeviceChangeReasons } =
  require('./player/OutputDevicePolicy.js');

// ① 该不该暂停：只有「本意是在播放」且设置开关打开时才暂停
assert.strictEqual(OutputDevicePolicy.shouldPauseOnDeviceLost(true, true), true);
assert.strictEqual(OutputDevicePolicy.shouldPauseOnDeviceLost(false, true), false);  // 用户自己按过暂停
assert.strictEqual(OutputDevicePolicy.shouldPauseOnDeviceLost(true, false), false);  // 设置里关掉了
assert.strictEqual(OutputDevicePolicy.shouldPauseOnDeviceLost(false, false), false);

// ② 该不该恢复：只有「因设备丢失而暂停」才谈得上自动恢复
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable([DeviceClasses.WIRED], false, true, true), false);
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable([DeviceClasses.WIRED], true, true, false), true);
// ③ 蓝牙重连：上游默认「不恢复」，用户显式打开才恢复
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable([DeviceClasses.BLUETOOTH], true, true, false), false);
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable([DeviceClasses.BLUETOOTH], true, true, true), true);
// ④ 非耳机设备接入（扬声器 / HDMI / 投屏）一律不恢复
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable([DeviceClasses.BUILT_IN], true, true, true), false);
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable([DeviceClasses.OTHER], true, true, true), false);
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable([], true, true, true), false);
// ⑤ 一次变更里混着扬声器与耳机：以耳机为准
assert.strictEqual(OutputDevicePolicy.shouldResumeOnDeviceAvailable(
  [DeviceClasses.BUILT_IN, DeviceClasses.WIRED], true, true, false), true);
// ⑥ 耳机类别判定
assert.strictEqual(OutputDevicePolicy.isHeadset(DeviceClasses.WIRED), true);
assert.strictEqual(OutputDevicePolicy.isHeadset(DeviceClasses.BLUETOOTH), true);
assert.strictEqual(OutputDevicePolicy.isHeadset(DeviceClasses.BUILT_IN), false);
assert.strictEqual(OutputDevicePolicy.isHeadset(DeviceClasses.OTHER), false);
assert.strictEqual(OutputDevicePolicy.isBluetooth(DeviceClasses.BLUETOOTH), true);
assert.strictEqual(OutputDevicePolicy.isBluetooth(DeviceClasses.WIRED), false);

// ---- 蓝牙耳机「下一首 / 上一首」按键重映射（MediaButtonPolicy）----
const { MediaButtonPolicy, MediaButtonCommands, MediaButtonActions } =
  require('./player/MediaButtonPolicy.js');
const NEXT = MediaButtonCommands.NEXT;
const PREVIOUS = MediaButtonCommands.PREVIOUS;
const SEEK_FORWARD = MediaButtonActions.SEEK_FORWARD;
const SEEK_BACK = MediaButtonActions.SEEK_BACK;
const NEXT_EPISODE = MediaButtonActions.NEXT_EPISODE;
const RESTART = MediaButtonActions.RESTART;
const DURATION = 30 * 60 * 1000;

// ① 非蓝牙来源（播控中心卡片 / 锁屏 / 车机 / 其它应用）：语义与改造前完全一致
assert.strictEqual(MediaButtonPolicy.resolve(NEXT, false, 5 * 60 * 1000, DURATION), NEXT_EPISODE);
assert.strictEqual(MediaButtonPolicy.resolve(NEXT, false, DURATION - 1000, DURATION), NEXT_EPISODE);
assert.strictEqual(MediaButtonPolicy.resolve(PREVIOUS, false, 5 * 60 * 1000, DURATION), RESTART);
assert.strictEqual(MediaButtonPolicy.resolve(PREVIOUS, false, 0, DURATION), RESTART);

// ② 蓝牙「下一首」= 快进；只有结尾前 10 秒内才真的切下一集
assert.strictEqual(MediaButtonPolicy.resolve(NEXT, true, 5 * 60 * 1000, DURATION), SEEK_FORWARD);
assert.strictEqual(MediaButtonPolicy.resolve(NEXT, true, DURATION - 10001, DURATION), SEEK_FORWARD);
assert.strictEqual(MediaButtonPolicy.resolve(NEXT, true, DURATION - 10000, DURATION), NEXT_EPISODE);
assert.strictEqual(MediaButtonPolicy.resolve(NEXT, true, DURATION, DURATION), NEXT_EPISODE);
// 时长未知（未 prepare / 直播）：按「不在结尾」处理，快进由播放器自行 clamp
assert.strictEqual(MediaButtonPolicy.resolve(NEXT, true, 5 * 60 * 1000, 0), SEEK_FORWARD);

// ③ 蓝牙「上一首」= 快退；只有开头 2 秒内保持「回到开头」
assert.strictEqual(MediaButtonPolicy.resolve(PREVIOUS, true, 0, DURATION), RESTART);
assert.strictEqual(MediaButtonPolicy.resolve(PREVIOUS, true, 2000, DURATION), RESTART);
assert.strictEqual(MediaButtonPolicy.resolve(PREVIOUS, true, 2001, DURATION), SEEK_BACK);
assert.strictEqual(MediaButtonPolicy.resolve(PREVIOUS, true, 5 * 60 * 1000, DURATION), SEEK_BACK);

// ④ 结尾判定自身的边界
assert.strictEqual(MediaButtonPolicy.isNearEnd(0, 10000), true);
assert.strictEqual(MediaButtonPolicy.isNearEnd(0, 10001), false);
assert.strictEqual(MediaButtonPolicy.isNearEnd(5000, 5000), true);
assert.strictEqual(MediaButtonPolicy.isNearEnd(0, 0), false);

// ---- 节目详情（shownotes）：去标签保留换行 + 时间码识别 ----
// 换行：旧的 PlayerPage.plainText 把标签换成空格后 `\s+` → ' '，<br>/<p>/真实换行全被吃掉
assert.strictEqual(HtmlCleaner.stripHtml('a<br>b'), 'a\nb');
assert.strictEqual(HtmlCleaner.stripHtml('a<br/>b'), 'a\nb');
// 相邻两个 <p>：上游 head 与 tail 各补一个换行，所以段间是空行
assert.strictEqual(HtmlCleaner.stripHtml('<p>a</p><p>b</p>'), 'a\n\nb');
assert.strictEqual(HtmlCleaner.stripHtml('<p style="color:red">a</p>'), 'a');
assert.strictEqual(HtmlCleaner.stripHtml('<div>a</div><div>b</div>'), 'a\n\nb');
assert.strictEqual(HtmlCleaner.stripHtml('<h2>标题</h2>正文'), '标题\n正文');
assert.strictEqual(HtmlCleaner.stripHtml('<ul><li>一</li><li>二</li></ul>'), '* 一\n* 二');
assert.strictEqual(HtmlCleaner.stripHtml('第一行\n第二行'), '第一行\n第二行');
assert.strictEqual(HtmlCleaner.stripHtml('<p>a<br>b</p><p>c</p>'), 'a\nb\n\nc');
assert.strictEqual(HtmlCleaner.stripHtml('  <p>  a  </p>  '), 'a');

// 时间码：只有落在单集时长之内的才转成可点段（上游 `if (time < playableDuration)`）
const notesShort = ShownotesText.segments('开场 00:30 正题 12:00', 60000);
assert.strictEqual(notesShort.length, 3);
assert.strictEqual(notesShort[1].text, '00:30');
assert.strictEqual(notesShort[1].timeMs, 30000);
assert.strictEqual(notesShort[2].timeMs, ShownotesText.NO_TIME);
// 带小时的时码按 h:mm:ss 解析
assert.strictEqual(ShownotesText.segments('跳到 1:02:03', 7200000)[1].timeMs, 3723000);
// 短时码默认按 HH:MM 解析（上游 useHourFormat）：整集 2 小时时 12:00 = 12 小时 0 分 > 时长，
// 于是整篇改按 MM:SS → 12:00 应落在 12 分钟处（而不是不可点）
assert.strictEqual(ShownotesText.segments('12:00', 7200000)[0].timeMs, 720000);
// 若有一个短时码按 HH:MM 解析就超过时长，则整篇改按 MM:SS 解析
const notesMinute = ShownotesText.segments('00:30 和 12:00', 1800000);
assert.strictEqual(notesMinute[0].text, '00:30');
assert.strictEqual(notesMinute[0].timeMs, 30000);
assert.strictEqual(notesMinute[2].text, '12:00');
assert.strictEqual(notesMinute[2].timeMs, 720000);
// 时长未知（<=0）时与上游 `Integer.MAX_VALUE` 等价：全部按 HH:MM 且都可点
assert.strictEqual(ShownotesText.segments('00:30', 0)[0].timeMs, 1800000);
// 分段拼回原文（含换行；相邻 <p> 之间是空行），不丢字符
const notesRound = ShownotesText.segments('<p>第一段 00:10</p><p>第二段 01:00</p>', 600000);
assert.strictEqual(ShownotesText.toPlainText(notesRound), '第一段 00:10\n\n第二段 01:00');
assert.strictEqual(ShownotesText.segments('', 1000).length, 0);
assert.strictEqual(ShownotesText.segments('没有时码', 1000)[0].timeMs, ShownotesText.NO_TIME);

// ---- 单集简介取「最长者」（上游 FeedItem.setDescriptionIfLonger）----
const descRss = '<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">'
  + '<channel><title>C</title>'
  + '<item><title>e</title><guid>g1</guid>'
  + '<description>短摘要</description>'
  + '<content:encoded><![CDATA[<p>完整 shownotes</p><p>第二段</p>]]></content:encoded>'
  + '</item>'
  + '<item><title>e2</title><guid>g2</guid>'
  + '<content:encoded><![CDATA[<p>完整 shownotes 先出现</p>]]></content:encoded>'
  + '<description>短</description>'
  + '</item></channel></rss>';
const descParsed = FeedParser.parseFeed(descRss);
// 后到的短摘要不能覆盖先到的 content:encoded（旧实现是「后到覆盖先到」）
assert.strictEqual(descParsed.feed.items[0].description.indexOf('完整 shownotes') >= 0, true);
assert.strictEqual(descParsed.feed.items[0].description.indexOf('短摘要') >= 0, false);
assert.strictEqual(descParsed.feed.items[1].description, '<p>完整 shownotes 先出现</p>');
// Atom：summary 通常排在 content 之后，完整正文不能被短摘要顶掉
const descAtom = '<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title>F</title>'
  + '<entry><title>t</title><id>i1</id>'
  + '<content type="html">&lt;p&gt;完整正文&lt;/p&gt;</content>'
  + '<summary>摘要</summary>'
  + '</entry></feed>';
const atomParsed = FeedParser.parseFeed(descAtom);
assert.strictEqual(atomParsed.feed.items[0].description, '<p>完整正文</p>');
// 没有 content:encoded 时仍取 description（回归）
assert.strictEqual(FeedParser.parseFeed(
  '<rss version="2.0"><channel><title>C</title>'
  + '<item><title>e</title><guid>g</guid><description>只有摘要</description></item>'
  + '</channel></rss>').feed.items[0].description, '只有摘要');
// itunes:summary 比 description 长时胜出
assert.strictEqual(FeedParser.parseFeed(
  '<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel><title>C</title>'
  + '<item><title>e</title><guid>g</guid><description>短</description>'
  + '<itunes:summary>itunes 里的长摘要</itunes:summary></item>'
  + '</channel></rss>').feed.items[0].description, 'itunes 里的长摘要');

console.log('RUNTIME PURE LOGIC TESTS PASSED');
'@ | Set-Content $runJs -Encoding UTF8

& $node $runJs
if ($LASTEXITCODE -ne 0) { throw "runtime tests failed with $LASTEXITCODE" }
