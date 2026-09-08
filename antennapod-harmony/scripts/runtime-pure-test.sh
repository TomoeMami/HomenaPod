#!/usr/bin/env bash
# 纯逻辑运行时验证：把纯模型/工具 .ets 编译为 JS，用 Node actuale 断言。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/antennapod-harmony/entry/src/main/ets"
WORK="$(mktemp -d)"
OUT="$(mktemp -d)"
trap 'rm -rf "$WORK" "$OUT"' EXIT

mkdir -p "$WORK/model" "$WORK/utils"
cp "$SRC"/model/{Enums,Feed,FeedItem,FeedMedia,FeedPreferences,Chapter,Playable,QueueItem,DownloadLogEntry,FeedFilter,FeedItemFilter}.ets "$WORK/model/"
cp "$SRC"/utils/{DurationUtils,DateUtils,MimeTypeUtils,HtmlCleaner}.ets "$WORK/utils/"

python3 - <<'PY'
import glob, os
for f in glob.glob('/tmp/**/pure*/**/*.ets', recursive=True):
    pass
# The actual temp path is provided via argv below; use simpler explicit rename in bash instead.
PY

# rename .ets -> .ts in temp
python3 - "$WORK" <<'PY'
import glob, os, sys
root = sys.argv[1]
for f in glob.glob(root + '/**/*.ets', recursive=True):
    os.rename(f, f[:-4] + '.ts')
PY

cat > "$WORK/tsconfig.json" <<JSON
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "moduleResolution": "node",
    "strict": false,
    "outDir": "$OUT",
    "esModuleInterop": true
  },
  "include": ["**/*.ts"]
}
JSON
cd "$WORK"
tsc -p tsconfig.json

cat > "$OUT/run.js" <<'EOF'
const assert = require('assert');
const { DurationUtils } = require('./utils/DurationUtils.js');
const { DateUtils } = require('./utils/DateUtils.js');
const { MimeTypeUtils } = require('./utils/MimeTypeUtils.js');
const { HtmlCleaner } = require('./utils/HtmlCleaner.js');
const { MediaType } = require('./model/Enums.js');
const { Playable } = require('./model/Playable.js');
const { FeedFilter } = require('./model/FeedFilter.js');
const { FeedMedia } = require('./model/FeedMedia.js');
const { Feed } = require('./model/Feed.js');
const { FeedState } = require('./model/Enums.js');
const { QueueItem } = require('./model/QueueItem.js');
const { Chapter } = require('./model/Chapter.js');
const { FeedItemFilter } = require('./model/FeedItemFilter.js');
const { FeedItem } = require('./model/FeedItem.js');

assert.strictEqual(DurationUtils.parseToMillis('01:30'), 90000);
assert.strictEqual(DurationUtils.parseToMillis('1:02:03'), 3723000);
assert.strictEqual(DurationUtils.parseToMillis('PT1H2M3S'), 3723000);
assert.strictEqual(DateUtils.parseToEpochMillis('1970-01-01T00:00:00Z'), 0);
assert.strictEqual(DateUtils.parseToEpochMillis('1970-01-01T00:01:00Z'), 60000);
assert.strictEqual(MimeTypeUtils.mediaTypeFromMime('audio/mpeg'), MediaType.AUDIO);
assert.strictEqual(MimeTypeUtils.mediaTypeFromMime('video/mp4'), MediaType.VIDEO);
assert.strictEqual(MimeTypeUtils.guessExtension('http://x/a.mp3', 'audio/mpeg'), '.mp3');
assert.strictEqual(HtmlCleaner.stripHtml('<p>Hello <b>World</b></p>'), 'Hello World');
const p = new Playable(1, 2, 'T', 'F', 'http://u', '/local/x.mp3', 0, 0, MediaType.AUDIO);
assert.strictEqual(p.feedItemId, 2);
assert.strictEqual(p.getSourceUrl(), '/local/x.mp3');

// FeedFilter
const item = new FeedItem({
  id: 1, title: 'Hello World', pubDate: 0, isPlayed: false, link: '', description: '', paymentLink: '',
  media: { id: 1, duration: 60000, fileUrl: '', downloadUrl: '', downloadDate: 0, position: 0, size: 0,
    mimeType: 'audio/mpeg', lastPlayedTimeHistory: 0, feedItemId: 1, playedDuration: 0,
    hasEmbeddedPicture: false, lastPlayedTimeStatistics: 0 }, feedId: 1, hasChapters: false,
  itemIdentifier: 'x', imageUrl: '', autoDownloadEnabled: true, podcastIndexChapterUrl: '',
  podcastIndexTranscriptType: '', podcastIndexTranscriptUrl: '', socialInteractUrl: ''
});
assert.strictEqual(new FeedFilter().shouldAutoDownload(item), true);
assert.strictEqual(new FeedFilter('hello', 'bad', -1).shouldAutoDownload(item), true);
assert.strictEqual(new FeedFilter('bad', '', -1).shouldAutoDownload(item), false);
assert.strictEqual(new FeedFilter('', '', 120).shouldAutoDownload(item), false);
// FeedItemFilter
assert.strictEqual(FeedItemFilter.unfiltered().matches(item), true);
assert.strictEqual(new FeedItemFilter(FeedItemFilter.UNPLAYED).matches(item), true);
assert.strictEqual(new FeedItemFilter(FeedItemFilter.PLAYED).matches(item), false);
assert.strictEqual(new FeedItemFilter(FeedItemFilter.DOWNLOADED).matches(item), false);
assert.strictEqual(new FeedItemFilter(FeedItemFilter.NOT_DOWNLOADED).matches(item), true);


// FeedItem convenience methods
item.media.position = 30000;
assert.strictEqual(item.isInProgress(), true);
item.media.fileUrl = '/downloads/x.mp3';
assert.strictEqual(item.isDownloaded(), true);
item.pubDate = Date.now() - 1000;
assert.strictEqual(item.isNew(Date.now()), true);
item.isPlayed = true;
assert.strictEqual(item.isNew(Date.now()), false);

// FeedMedia
const fm = new FeedMedia({
  id: 1, duration: 1000, fileUrl: '/a.mp3', downloadUrl: 'http://u', downloadDate: 0,
  position: 0, size: 1, mimeType: 'audio/mpeg', lastPlayedTimeHistory: 0, feedItemId: 1,
  playedDuration: 0, hasEmbeddedPicture: false, lastPlayedTimeStatistics: 0
});
assert.strictEqual(fm.isDownloaded(), true);
assert.strictEqual(fm.getMediaType(), MediaType.AUDIO);
// Feed
const feed = new Feed({
  id: 1, title: 'T', customTitle: 'Custom', fileUrl: '', downloadUrl: '', lastRefreshAttempt: 0,
  link: '', description: '', paymentLink: '', lastUpdate: '', language: '', author: '', imageUrl: '',
  type: 'rss', feedIdentifier: 'id', autoDownloadEnabled: true, username: '', password: '',
  includeFilter: '', excludeFilter: '', minimalDurationFilter: -1, keepUpdated: true, isPaged: false,
  nextPageLink: '', hide: '', sortOrder: 0, lastUpdateFailed: false, autoDeleteAction: 0,
  feedPlaybackSpeed: 0, feedSkipSilence: 0, feedVolumeAdaption: 0, feedTags: '', feedSkipIntro: 0,
  feedSkipEnding: 0, episodeNotification: false, state: FeedState.STATE_SUBSCRIBED, newEpisodesAction: 0
});
assert.strictEqual(feed.getTitle(), 'Custom');
assert.strictEqual(feed.isSubscribed(), true);
// QueueItem
const q = new QueueItem(1, 2, 3);
assert.deepStrictEqual(q.toValues(), { id: 1, feeditem: 2, feed: 3 });
// Chapter
const ch = new Chapter(1, 't', 2000, 3, 'link', 'img');
assert.strictEqual(ch.title, 't');
assert.strictEqual(ch.start, 2000);
console.log('RUNTIME PURE LOGIC TESTS PASSED');
EOF

node "$OUT/run.js"
