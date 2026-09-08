# Reference Notes · AntennaPod 源码研读（T0.2）

> 来源：`antenna-repo` 的 AGENTS.md、各模块 README、AndroidManifest 与关键类目检。
> 用途：为 T1/T2/T3 提供索引；所有路径相对 `antenna-repo/`。

## 1. 工程总览

- 多模块 Gradle 工程，模块即领域：`event / model / system / net:common / net:discovery / net:download / net:sync / parser:feed|media|transcript / playback:base|cast|service / storage:database|importexport|preferences / ui:* / app`。
- 服务接口/实现分离：如 `net:download:service-interface` 与 `net:download:service`，app 启动时由 `ClientConfigurator` 注册实现。
- 技术栈：Java 21、Android View/XML、Media3 ExoPlayer、Room/SQLite（自定义 PodDBAdapter）、OkHttp、EventBus、RxJava、Glide、WorkManager。
- 版本快照：v3.12.1，versionCode 3120195；AGP 9.0.1；Media3 1.10.0；minSdk 23 / targetSdk 36。

## 2. 模块职责与关键类

| 模块 | 职责 | 关键类（移植参考） |
|---|---|---|
| `model` | 纯数据模型，不依赖平台 | `Feed/FeedItem/FeedMedia/FeedPreferences/Chapter/FeedFilter/SortOrder/Playable/MediaType/DownloadStatus` |
| `event` | EventBus 事件 | `FeedEvent/QueueEvent/PlayerStatusEvent/PlaybackPositionEvent/EpisodeDownloadEvent/MessageEvent/...` |
| `system` | 崩溃/包/线程工具 | `CrashReportWriter/ThreadUtils/PackageUtils` |
| `net:common` | OkHttp 封装、重定向、认证、UA | `AntennapodHttpClient/RedirectChecker/BasicAuthorizationInterceptor/UserAgentInterceptor/NetworkUtils` |
| `net:discovery` | 播客搜索 | `ItunesPodcastSearcher/PodcastIndexPodcastSearcher/PodcastSearcherRegistry/PodcastSearchResult` |
| `net:download:service` | 下载/刷新实现 | `HttpDownloader/Downloader/FeedUpdateManagerImpl/EpisodeDownloadWorker/DownloadAnnouncer/NewEpisodesNotification` |
| `parser:feed` | RSS/Atom 解析 | `FeedHandler/SyndHandler/HandlerState/FeedHandlerResult/namespace(Rss20/Atom/Itunes/Media/DublinCore/PodcastIndex/SimpleChapters)/util(DurationParser/DateUtils/MimeTypeUtils/SyndStringUtils)` |
| `parser:media` | 媒体标签/嵌入章节 | `id3/*/m4a/*/vorbis/*`（MVP 后置） |
| `playback:base` | 播放抽象 | `Playable/PlaybackServiceMediaPlayer` |
| `playback:service` | 播放服务、Media3 封装、会话 | `Media3PlaybackService/PlaybackService/PlaybackController/LocalPSMP/ExoPlayerWrapper/ExoPlayerUtils/SleepTimer/PlaybackServiceNotificationBuilder/MediaLibrarySessionCallback/WearMediaSession` |
| `storage:database` | SQLite 数据访问 | `PodDBAdapter/DBReader/DBWriter/FeedDatabaseWriter/DBUpgrader/ItemEnqueuePositionCalculator` |
| `storage:preferences` | 用户设置 | `UserPreferences` |
| `storage:importexport` | OPML 导入导出 | `OpmlImporter/OpmlExporter`（计划 T4.3） |
| `ui:episodes` | 单集列表 UI 逻辑 | `EpisodesListFragment/EpisodeItemListAdapter/EpisodeItemViewHolder` |
| `ui:screen` | 各页面 | `HomeFragment/SubscriptionsRecyclerAdapter/AddFeedFragment/FeedItemlistFragment/AudioPlayerFragment/QueueFragment/DownloadLogFragment/PreferenceActivity` |
| `ui:i18n` | 多语言 | `values/strings.xml`（约 1500+ 条；MVP 只取核心 ~120 条） |

## 3. AndroidManifest 要点（`app/src/main/AndroidManifest.xml`）

- 权限：INTERNET、WAKE_LOCK、ACCESS_NETWORK_STATE、FOREGROUND_SERVICE、POST_NOTIFICATIONS、ACCESS_WIFI_STATE、RECEIVE_BOOT_COMPLETED、BLUETOOTH、VIBRATE。
- 入口：`SplashActivity`（MAIN/LAUNCHER + MEDIA_PLAY_FROM_SEARCH + MUSIC_PLAYER）→ `MainActivity`。
- 深链：`antennapod.org/deeplink/main`、`/deeplink/search`（https autoVerify）。
- 服务：PlaybackService（前台媒体播放）、QuickSettingsTileService、下载/刷新相关 Worker/Receiver。
- 组件：多个 Activity（偏好、OPML 导入、在线 Feed 预览、视频播放器、倍速对话框）。
- 备份：`OpmlBackupAgent`（Android Auto Backup）。
- Cast：Google Play 版本附带 Chromecast（本移植排除）。

## 4. 播放链路（T2 重点）

- `PlaybackService` + `Media3PlaybackService` 持有媒体 session；
- `LocalPSMP` 维护状态：IDLE/INITIALIZED/PREPARING/PREPARED/PLAYING/PAUSED/STOPPED；
- `ExoPlayerWrapper` 提供 `seekTo/setPlaybackParams(speed, skipSilence)/setVolume/getCurrentPosition/getDuration`；
- `PlaybackServiceTaskManager` 管理睡眠、自动连播、位置保存；
- `MediaLibrarySessionCallback` 处理媒体会话命令（play/pause/next/previous/seek/speed）；
- 队列语义：`QueueFragment`/`PlaybackService` 中的“播放完毕自动出队→下一集”。

## 5. 数据层（T1 重点）

- 表：`Feeds / FeedItems / FeedMedia / DownloadLog / Queue / SimpleChapters / Favorites`（详见 docs/04）。
- `PodDBAdapter` 单例 SQLiteOpenHelper，DB version 由 `DBUpgrader` 管理。
- 去重：`FeedItemDuplicateGuesser`（按 item_identifier/link/pubdate）。
- 排序/过滤：`FeedItemSortQuery`、`FeedItemFilterQuery`、`SubscriptionsFilterExecutor`。
- `UserPreferences` 对外全是静态 getter/setter，key 形如 `prefTheme/prefSkipSilence...`。

## 6. 解析器（T1.6 重点）

- `FeedHandler` 入口：`parse(File)` -> `FeedHandlerResult{feed, alternateUrls}`。
- `SyndHandler` 基于 Android `XmlPullParser` 事件流，按 “currentState” 路由命名空间；
- `HandlerState` 记录了当前在 channel/item/子元素哪个层级；
- 返回的 Feed 的 `items` 中 `FeedMedia` 已被关联到 `FeedItem`；
- 容错：未知 namespace 忽略、无 `enclosure` 用 `media:content` 兜底、日期/时长解析失败给默认值。

## 7. UI 结构（T3 重点）

- `MainActivity` 承载 `HomeFragment` 等，底部导航/抽屉；
- 列表 `RecyclerView + Adapter + ViewHolder` -> ArkTS `LazyForEach`；
- 播放页 `AudioPlayerFragment`：封面、进度、控制、shownotes、倍速对话框；
- 设置页 `PreferenceActivity` 多 Fragment：分组、PreferenceSearch 等；
- 手势：swipe actions（队列/滑动删除）-> ArkUI `ListItem.swipeAction`。

## 8. 鸿蒙移植映射提示

- 安卓 `Service` -> ArkTS 无对应前台服务；用 `UIAbility` + 长时任务 + AVSession。
- 安卓 `ContentProvider`/`DocumentFile` -> `@ohos.file.fs` / `@ohos.file.picker`。
- 安卓 `WorkManager` -> `workScheduler`（T4.2）。
- 安卓 `EventBus` -> 类型化 `EventHub`（T1.4）。
- 安卓 `Glide` -> `Image` + 自管磁盘缓存（T3.2）。
- `ViewBinding` -> 声明式 UI，无 XML 布局。
