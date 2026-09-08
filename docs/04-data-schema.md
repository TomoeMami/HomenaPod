# 04 · 数据模型与数据库表结构

> 来源：`antenna-repo/storage/database/src/main/java/de/danoeh/antennapod/storage/database/PodDBAdapter.java`（建表语句）、`antenna-repo/model/...`（模型类）。
> 本文件的 SQL 与 ArkTS 接口是 T1.1/T1.2 的**唯一权威来源**；执行时发现与参考仓库不一致，以参考仓库为准并更新本文件。

## 1. 数据库元信息

- 库名：`Antennapod.db`
- 引擎：SQLite（`@ohos.data.relationalStore`）
- 版本：`1`（MVP 从 1 开始；未来导入 AntennaPod 安卓库时做专用迁移器）
- 存储配置：`securityLevel: relationalStore.SecurityLevel.S1`

## 2. DDL（直接可用）

列名沿用 AntennaPod（下划线风格）。`id` 均为自增主键。

```sql
CREATE TABLE Feeds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  custom_title TEXT,
  file_url TEXT,
  download_url TEXT,
  last_refresh_attempt INTEGER,
  link TEXT,
  description TEXT,
  payment_link TEXT,
  last_update TEXT,
  language TEXT,
  author TEXT,
  image_url TEXT,
  type TEXT,
  feed_identifier TEXT,
  auto_download_enabled INTEGER DEFAULT 1,
  username TEXT,
  password TEXT,
  include_filter TEXT DEFAULT '',
  exclude_filter TEXT DEFAULT '',
  minimal_duration_filter INTEGER DEFAULT -1,
  keep_updated INTEGER DEFAULT 1,
  is_paged INTEGER DEFAULT 0,
  next_page_link TEXT,
  hide TEXT,
  sort_order TEXT,
  last_update_failed INTEGER DEFAULT 0,
  auto_delete_action INTEGER DEFAULT 0,
  feed_playback_speed REAL DEFAULT 0,
  feed_skip_silence INTEGER DEFAULT 0,
  feed_volume_adaption INTEGER DEFAULT 0,
  feed_tags TEXT,
  feed_skip_intro INTEGER DEFAULT 0,
  feed_skip_ending INTEGER DEFAULT 0,
  episode_notification INTEGER DEFAULT 0,
  state INTEGER DEFAULT 1,
  new_episodes_action INTEGER DEFAULT 0
);

CREATE TABLE FeedItems (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  pubdate INTEGER,
  read INTEGER,
  link TEXT,
  description TEXT,
  payment_link TEXT,
  media INTEGER,
  feed INTEGER,
  has_chapters INTEGER,
  item_identifier TEXT,
  image_url TEXT,
  auto_download_enabled INTEGER,
  podcastindex_chapter_url TEXT,
  podcastindex_transcript_type TEXT,
  podcastindex_transcript_url TEXT,
  social_interact_url TEXT
);

CREATE TABLE FeedMedia (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  duration INTEGER,
  file_url TEXT,
  download_url TEXT,
  download_date INTEGER,
  position INTEGER,
  size INTEGER,
  mime_type TEXT,
  last_played_time_history INTEGER,
  feeditem INTEGER,
  played_duration INTEGER,
  has_embedded_picture INTEGER,
  last_played_time_statistics INTEGER
);

CREATE TABLE DownloadLog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  feedfile INTEGER,
  feedfiletype INTEGER,
  reason INTEGER,
  successful INTEGER,
  completion_date INTEGER,
  reason_detailed TEXT,
  downloadstatus_title TEXT
);

CREATE TABLE Queue (
  id INTEGER PRIMARY KEY,
  feeditem INTEGER,
  feed INTEGER
);

CREATE TABLE SimpleChapters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  start INTEGER,
  feeditem INTEGER,
  link TEXT,
  image_url TEXT
);

CREATE TABLE Favorites (
  id INTEGER PRIMARY KEY,
  feeditem INTEGER,
  feed INTEGER
);

CREATE INDEX FeedItems_feed ON FeedItems (feed);
CREATE INDEX FeedItems_pubdate ON FeedItems (pubdate);
CREATE INDEX FeedItems_read ON FeedItems (read);
CREATE INDEX Queue_feeditem ON Queue (feeditem);
CREATE INDEX FeedMedia_feeditem ON FeedMedia (feeditem);
CREATE INDEX SimpleChapters_feeditem ON SimpleChapters (feeditem);
```

> 注：上游还有 `FeedImages` 表名常量（历史遗留，当前主代码未建表）。MVP 不建该表，封面缓存用文件系统实现（`filesDir/image_cache`）。

## 3. ArkTS 模型接口（T1.1 依据）

### 枚举

```ts
export enum FeedState {
  STATE_NOT_SUBSCRIBED = 0,
  STATE_SUBSCRIBED = 1,
  STATE_SUBSCRIBING = 2
}

export enum MediaType {
  AUDIO = 0,
  VIDEO = 1,
  UNKNOWN = 2
}

export enum DownloadStatus {
  DOWNLOADING = 0,
  COMPLETED = 1,
  PAUSED = 2,
  FAILED = 3,
  REMOVED = 4
}

export enum SortOrder {
  DATE_NEW_OLD = 0,
  DATE_OLD_NEW = 1,
  TITLE_A_Z = 2,
  TITLE_Z_A = 3,
  DURATION_SHORT_LONG = 4,
  DURATION_LONG_SHORT = 5
}

export enum EnqueueLocation {
  BACK = 0,
  FRONT = 1,
  AFTER_CURRENTLY_PLAYING = 2
}
```

### Feed

```ts
export interface FeedOptions {
  id: number;
  title: string;
  customTitle: string;
  fileUrl: string;       // 本地 feed 文件（MVP 不用，留空）
  downloadUrl: string;   // 订阅 URL
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
  feedPlaybackSpeed: number;   // 0 = 使用全局倍速
  feedSkipSilence: number;     // 0=全局 1=关 2=开
  feedVolumeAdaption: number;
  feedTags: string;
  feedSkipIntro: number;
  feedSkipEnding: number;
  episodeNotification: boolean;
  state: FeedState;
  newEpisodesAction: number;
}

export class Feed {
  readonly options: FeedOptions;
  readonly items: FeedItem[];   // 内存态，不入库
  preferences: FeedPreferences;
  // 移植方法：getTitle()（customTitle 优先）、isSubscribed()、
  // getImageUrl()、getHumanReadableIdentifier()
}
```

### FeedItem / FeedMedia

```ts
export interface FeedItemOptions {
  id: number;
  title: string;
  pubDate: number;          // epoch ms；0 = 未知
  isPlayed: boolean;        // DB 列名 read
  link: string;
  description: string;
  paymentLink: string;
  media: FeedMedia | undefined;
  feedId: number;
  hasChapters: boolean;
  itemIdentifier: string;
  imageUrl: string;
  autoDownloadEnabled: boolean;
  podcastIndexChapterUrl: string;
  podcastIndexTranscriptType: string;
  podcastIndexTranscriptUrl: string;
  socialInteractUrl: string;
}

export interface FeedMediaOptions {
  id: number;
  duration: number;         // ms；0 = 未知
  fileUrl: string;          // 本地文件路径
  downloadUrl: string;      // 媒体流 URL
  downloadDate: number;
  position: number;         // 上次播放位置 ms
  size: number;             // 字节
  mimeType: string;
  lastPlayedTimeHistory: number;
  feedItemId: number;
  playedDuration: number;
  hasEmbeddedPicture: boolean;
  lastPlayedTimeStatistics: number;
}

export interface Chapter {
  id: number;
  title: string;
  start: number;            // ms
  feedItemId: number;
  link: string;
  imageUrl: string;
}

export interface DownloadLogEntry {
  id: number;
  feedFileId: number;
  feedFileType: number;     // 0=feed 1=媒体
  reason: number;
  successful: boolean;
  completionDate: number;
  reasonDetailed: string;
  downloadStatusTitle: string;
}

export interface QueueItem {
  id: number;
  feedItemId: number;
  feedId: number;
}
```

### FeedPreferences（MVP 子集，其余字段保留占位）

```ts
export class FeedPreferences {
  autoDownload: boolean = true;
  autoDeleteAction: number = 0;
  feedPlaybackSpeed: number = 0;
  feedSkipSilence: number = 0;     // 0=全局
  feedVolumeAdaption: number = 0;
  feedSkipIntro: number = 0;
  feedSkipEnding: number = 0;
  episodeNotification: boolean = false;
  newEpisodesAction: number = 0;
}
```

## 4. ResultSet → 模型映射规则

- SQLite `INTEGER` 读 `getLong/getDouble`，0/1 列统一转 `boolean`（`value !== 0`）。
- `REAL`（倍速）读 `getDouble`。
- 可空列：`resultSet.isColumnNull(index)` 检查后给默认值（字符串 `''`、数字 `0`、布尔 `false`）。
- 关联加载：`Feed` 不自动带 items；页面需要时调用 `EpisodeRepository.listByFeed(feedId, filter)`。
- 事务：刷新合并（feed+items+media 写入）必须用 `beginTransaction/commit/rollBack`。

## 5. 偏好键（preferences，与 AntennaPod 同名）

| key | 类型 | 默认值 | 说明 |
|---|---|---|---|
| prefTheme | number | 0 | 0=跟随系统 1=浅色 2=深色 |
| prefPlaybackSpeed | number | 1.0 | 全局倍速（MVP 仅允许 §01-4 档位） |
| prefSkipSilence | boolean | false | UI 隐藏（AVPlayer 不支持） |
| prefStreamOverDownload | boolean | false | true=优先在线播放 |
| prefMobileUpdateTypes | string | 'wifi_only' | wifi_only / wifi_and_mobile |
| prefAutoUpdateInterval | number | 6 | 小时（Phase 4 用） |
| prefEnqueueLocation | number | 0 | EnqueueLocation |
| prefEpisodeCacheSize | number | 20 | 缓存上限（GB），MVP 只用于显示 |
| prefLastPlayedFeedMediaId | number | -1 | 启动恢复用 |
| prefDefaultPage | string | 'subscriptions' | 预留 |

## 6. 与 AntennaPod 安卓库的兼容性备忘

1. 列名完全一致，因此未来可通过“导出 Antennapod.db → 读取导入”实现数据迁移（T6.9）。
2. `read` 列在 AntennaPod 语义是“已播放”，ArkTS 属性命名为 `isPlayed`，映射时注意不要与“未读计数”混淆：未播放数 = `COUNT(read=0)`。
3. `Queue.id` 与 `Favorites.id` 是**业务主键**（非自增）：Queue 用 feeditem 作为 id（单集唯一入队语义由上游逻辑保证）；插入用 `insert + conflictPolicy`，MVP 保持与上游一致的 id 生成逻辑。
4. 时间字段：`pubdate`、`download_date`、`completion_date`、`last_played_time_*` 均 epoch **ms**；`last_update` 是 feed 的文本日期（RFC822/ISO 原样保存）。
