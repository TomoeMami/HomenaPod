# 01 · 架构与 Android→鸿蒙 API 映射

> 本文档是执行者在写任何代码前必须遵守的设计约束。所有 ArkTS 文件的放置位置、命名与分层以本文为准。

## 1. 总体架构

单 `entry` 模块 + 严格分层目录（未来拆分 HAR/HSP 时按目录边界切开即可）：

```
antennapod-harmony/
├── AppScope/                       # 应用级配置与资源
├── entry/
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/       # UIAbility、AVSession 持有者
│   │   │   ├── pages/              # @Entry 页面（每页一个文件）
│   │   │   ├── components/         # 跨页复用 ArkUI 组件（EpisodeListItem 等）
│   │   │   ├── model/              # 纯数据模型（不 import 任何 @ohos.*）
│   │   │   ├── db/                 # RDB 连接、建表、迁移、DAO/Repository
│   │   │   ├── prefs/              # preferences 封装（UserPreferences）
│   │   │   ├── net/                # HttpClient、FeedFetcher、Discovery
│   │   │   ├── parser/             # XML 读取封装、RSS/Atom 解析、工具函数
│   │   │   ├── player/             # PlayerManager、AVSession 桥、队列引擎
│   │   │   ├── download/           # DownloadManager（封装 @ohos.request）
│   │   │   ├── events/             # 类型化事件中心（封装 @ohos.events.emitter）
│   │   │   ├── utils/              # Logger、日期/时长/MIME/HTML 工具
│   │   │   └── services/           # 应用级服务：RefreshService、NotificationService
│   │   ├── resources/
│   │   │   ├── base/element/       # string.json、color.json（英文为默认）
│   │   │   ├── en_US/element/      # 英文
│   │   │   ├── zh_CN/element/      # 中文
│   │   │   ├── base/media/         # 图标、封面占位图
│   │   │   └── base/profile/       # main_pages.json
│   │   └── module.json5
│   ├── oh-package.json5
│   ├── build-profile.json5
│   └── hvigorfile.ts
├── build-profile.json5
├── hvigorfile.ts
├── hvigor/hvigor-config.json5
└── oh-package.json5
```

**依赖方向（不可反向）**：
`pages/components → services → db/net/parser/download/player/prefs → model/utils → events`
任何 `@ohos.*` 的 import 只允许出现在 `player / db / prefs / net / download / pages / components / entryability / services` 层；`model` 与纯工具函数必须保持平台无关（便于单测和未来复用）。

**线程/异步约定**：
- UI 层只做 `async/await + Promise`；解析与数据库操作不开启新线程（MVP 数据量安全）。
- 单例采用“模块级单例 + 初始化函数”模式：`PlayerManager.init(context)` / `DbManager.init(context)`，在 `EntryAbility.onCreate` 中完成。
- 跨层通信一律走 `events/EventHub`，不允许页面互相引用或全局可变对象裸奔（播放器除外，它本身是唯一权威状态源）。

## 2. 关键设计决策

| 决策点 | 结论 | 理由 |
|---|---|---|
| 工程形态 | 先单模块分层，不建 HAR/HSP | 单执行者顺序开发时模块化只会增加 hvigor 配置与编译风险；目录边界已按未来模块划分 |
| 播放内核 | `@ohos.multimedia.media` **AVPlayer** + `@ohos.multimedia.avsession` **AVSession** | 系统唯一支持 http/file 流媒体、seek、倍速、后台播放的完整链路；无 ExoPlayer 等价物 |
| 后台播放 | `backgroundTaskManager.startBackgroundRunning(ctx, BackgroundMode.AUDIO_PLAYBACK, wantAgent)` + module.json5 声明 `backgroundModes: ["audioPlayback"]` + 权限 `ohos.permission.KEEP_BACKGROUND_RUNNING` | 官方标准音频后台链路；AVSession 激活后锁屏/控制中心才有媒体卡片 |
| 下载 | `@ohos.request.downloadFile(context, config)`，封装为 `DownloadManager` | 系统下载任务自带断点续传/暂停恢复（API 9+）；预留 Plan B 见风险 R3 |
| 数据库 | `@ohos.data.relationalStore` RdbStore，版本号从 1 开始，表结构照搬 AntennaPod（去掉安卓字段） | 直接复用经过验证的 schema；未来可做 AntennaPod DB 导入 |
| 偏好 | `@ohos.data.preferences`，key 与 AntennaPod `UserPreferences` 保持一致 | 便于设置项对照与后续迁移 |
| 网络 | `@ohos.net.http` 封装 `HttpClient` | 支持自定义 header（含 `Authorization`、`Range`、`If-Modified-Since`）、超时、错误码；不需要 OkHttp 生态 |
| XML | `@ohos.xml.XmlPullParser`，写一层 `XmlReader` 适配 | 与 AntennaPod 的 Android XmlPullParser 语义最接近；`parse()` 在 API 14 起标记 deprecated、`parseXml()` 为 API 14+，封装层内部做版本兼容 |
| 事件总线 | `@ohos.events.emitter` 之上写**类型化** `EventHub`（事件名+payload 接口枚举） | 替代 EventBus，同时保留编译期类型检查 |
| 图片 | `Image` 组件网络 `src` + 自管磁盘缓存目录 `filesDir/image_cache`（URL hash 为文件名 + LRU 清理） | 不引 Glide 等价库；封面尺寸小、数量可控 |
| shownotes | 优先 `RichText`（受限 HTML 子集）；内容复杂时降级 `Web` 组件 | 安全、轻量 |
| 定时刷新 | `@ohos.resourceschedule.workScheduler` + `WorkSchedulerExtensionAbility`（Phase 4） | 系统统一调度，替代 WorkManager |
| 通知 | `@ohos.notificationManager`（普通新单集通知）；播放通知由 AVSession 呈现 | 职责与安卓一致 |
| 文件导入导出 | `@ohos.file.picker`（DocumentViewPicker/DocumentSaveOptions）+ `@ohos.file.fs` | OPML 导入导出（Phase 4） |

## 3. Android → HarmonyOS 组件映射总表

| AntennaPod（Android） | HarmonyOS NEXT 替代 | 移植要点 |
|---|---|---|
| Activity / Fragment / View / Adapter | `@Entry` 页面 + `Navigation`/`Tabs` + `List`/`Grid` + `@Builder` 复用组件 | 页面与 `components/` 一一对应；适配器逻辑改为 `LazyForEach` 数据源 |
| ViewBinding + XML layout | ArkUI 声明式组件 | 用 `ForEach/LazyForEach` 渲染列表；行内交互用 `onClick`/`gesture` |
| LiveData / 状态分发 | `@State/@Prop/@Link/@Provide/@Consume/AppStorage` + `EventHub` | 数据流单向：service 更新 → EventHub → 页面 setState |
| `PlaybackService`（Media3/ExoPlayer） | `PlayerManager`（AVPlayer 封装，模块级单例） | 状态机见 §4；service 生命周期改为 ability 生命周期 + 长时任务 |
| `MediaSession` / `PlaybackServiceNotificationBuilder` / `MediaButtonReceiver` | `AVSession`（setAVPlaybackState / setAVMetaData / setAVQueueItems / 控件事件回调） | 锁屏卡片、耳机按键由系统分发到 AVSession 回调 |
| `Room` / `PodDBAdapter` / `DBReader` / `DBWriter` | `relationalStore.RdbStore` + `db/` 下的 Repository | SQL 照搬；游标遍历改为 ResultSet |
| `SharedPreferences`（`UserPreferences`） | `preferences.getPreferencesSync` | key 保持一致；类型化 getter/setter |
| `OkHttp`（`AntennapodHttpClient`） | `HttpClient` 封装 `@ohos.net.http` | 保留下载认证/UA/重定向策略语义 |
| `EventBus`（`event` 模块 23 个事件类） | `events/EventHub`（一个文件定义全部事件类型） | 事件粒度照搬，去掉安卓依赖字段 |
| `RxJava` | 删除，全部改 `Promise/async-await` | 不引入 RxJS；解析用流式回调 + 分批 `await` |
| `Glide` | `Image` + 磁盘缓存 | 图片加载失败显示占位图 |
| `WorkManager`（FeedUpdateWorker 等） | `workScheduler`（Phase 4） | 触发条件：网络+充电+周期 |
| `DownloadManager`（EpisodeDownloadWorker） | `@ohos.request.downloadFile` 封装 | progress/complete/fail 事件桥接进 EventHub |
| `MediaMetadataRetriever` / ID3 | Phase 4+ 用 `@ohos.multimedia.media` AVMetadataExtractor；MVP 只解析 feed 元数据 | 嵌入章节/嵌入封面后置 |
| `WebView`（ShownotesWebView） | `RichText` / `Web` | 先清洗 HTML（HtmlToPlainText 移植） |
| `NotificationManager`（新单集通知） | `notificationManager.publish` | Phase 4 |
| `QuickSettingsTileService`（快捷磁贴） | 无直接等价；做服务卡片（backlog） | 排除 |
| `Chromecast`（playback:cast） | AVCastPicker（backlog） | 排除 |
| 深链（antennapod.org/deeplink） | module.json5 `skills` 声明 scheme `https` + host `antennapod.org` | Phase 5 |

## 4. 播放器状态机（PlayerManager）

AVPlayer 状态：`idle → initialized → prepared → playing / paused / completed → released`，由 `on('stateChange')` 驱动。封装要求：

```
PlayerStatus = IDLE | INITIALIZING | PREPARING | PREPARED | PLAYING | PAUSED | COMPLETED | ERROR
```

- 播放源：`media.createMediaSourceWithUrl(url)` 或本地 `fdSrc`（file path 走 `fs.open` 得到 fd）。
- 播放流：`setMediaSource → prepare() → play()`；换集 = 释放当前源重走流程。
- 核心 API：`play / pause / release / seek(ms, SEEK_PREV_SYNC)`、属性 `currentTime/duration/state`、事件 `timeUpdate / stateChange / error / bufferingUpdate / seekDone / speedDone`。
- 倍速档位（API 12 能力）：`SPEED_FORWARD_0_75_X / 1_00_X / 1_25_X / 1_50_X / 1_75_X / 2_00_X`；UI 只允许这些档位；AntennaPod 的自定义 0.5–3.0 连续档在 MVP 不提供。
- **跳过静音**：AVPlayer 无等价能力 → 设置项 MVP 阶段隐藏（UI 保留常量但 `isSupported=false`）。
- 音量：`setVolume(0–1)`；左/右声道不做。
- 进度持久化：`timeUpdate` 节流（每 5s 或暂停/后台切换时）写 `FeedMedia.position`。
- 自动连播：`completed` 事件 → QueueEngine.next() → 若有则播放，否则 release + 停止长时任务。
- 错误恢复：网络中断错误码记录到日志 → 页面展示“播放失败/重试”，不清空进度。

## 5. 下载器接口（DownloadManager）

```ts
interface DownloadTaskHandle {
  readonly id: string;            // FeedMedia.id
  readonly state: DownloadState;  // PENDING | RUNNING | PAUSED | DONE | FAILED | REMOVED
  pause(): Promise<void>;
  resume(): Promise<void>;
  remove(): Promise<void>;
  onProgress(cb: (received: number, total: number, speed: number) => void): void;
}
```
- 底层：`request.downloadFile(context, { url, filePath, networkTypes, enableMetered, roaming })`，用 `on('progress'|'complete'|'fail'|'pause'|'remove')` 订阅。
- `filePath`：`context.filesDir + '/downloads/' + feedMediaId + 扩展名`（扩展名由 URL/MIME 推断，兜底 `.mp3`）。
- 完成后：写 `FeedMedia.file_url/duration/size/download_date`，发 `EpisodeDownloadEvent`，删任务句柄。
- Plan B（若目标 API 的 request 续传有缺陷）：手写 `HttpClient` 带 `Range` header 分片写 `fs`，接口不变。

## 6. RSS 解析架构（parser/）

移植自 `antenna-repo/parser/feed`，保持三件套：
- `SyndHandler`（Android XmlPullParser 回调状态机）→ ArkTS 的 `XmlReader` + `FeedParser`：`START_TAG/TEXT/END_TAG` 驱动、多命名空间路由（Rss20/Atom/Itunes/Media/DublinCore/PodcastIndex）。
- `FeedHandlerResult`：`{ feed: Feed, alternateUrls: string[] }`。
- 工具函数：`DurationParser`（"HH:MM:SS"/秒数/ISO8601 时长）、`DateUtils`（RFC822/ISO8601）、`MimeTypeUtils`（mime → MediaType）、`SyndStringUtils`（HTML 清洗/裁剪）。
- 容错原则照搬：非法日期取 0、非法时长返回 null、未知命名空间跳过、media:content 兜底 enclosure。

## 7. 页面与路由（pages/）

| 页面 | 文件 | 入口方式 |
|---|---|---|
| Index（主壳 + 底部 Tabs） | `pages/Index.ets` | 首屏 |
| 订阅列表 | `pages/SubscriptionsPage.ets` | Tab 1 |
| 添加订阅 | `pages/AddFeedPage.ets` | 订阅页 FAB / 按钮 |
| Feed 详情（单集列表） | `pages/FeedDetailPage.ets` | 点订阅项 |
| 播放页（大卡） | `pages/PlayerPage.ets` | 点迷你播放条/单集播放按钮 |
| 队列 | `pages/QueuePage.ets` | Tab 2 |
| 下载 | `pages/DownloadsPage.ets` | Tab 3 |
| 下载日志 | `pages/DownloadLogPage.ets` | 下载页入口 |
| 设置 | `pages/SettingsPage.ets` | Tab 4 |
| 冒烟测试页（M2 用，M3 移除） | `pages/PlayerSmokePage.ets` | 临时 |

导航统一用 `Navigation` + `router.replaceUrl/pushUrl`，路由常量集中在 `utils/RouteMap.ets`。

## 8. 事件清单（events/EventHub）

MVP 必须实现（与 AntennaPod 事件语义对应）：
`FeedListUpdateEvent / FeedItemEvent / QueueEvent / PlayerStatusEvent / PlaybackPositionEvent / PlaybackServiceEvent(播放器控制命令) / EpisodeDownloadEvent / DownloadLogEvent / MessageEvent(全局 toast 类提示) / PlayerErrorEvent / SpeedChangedEvent / SleepTimerUpdatedEvent(Phase 4)`。
每个事件定义为 `interface XxxEvent { readonly type: 'XxxEvent'; ... }`，发布用 `EventHub.publish(evt)`，订阅用 `EventHub.subscribe('FeedItemEvent', cb)`。

## 9. 命名与编码约定

- 文件：`PascalCase.ets`；组件参数接口 `XxxOptions`；事件 `XxxEvent`；Repository `XxxRepository`。
- 数据库列名沿用 AntennaPod 的下划线风格（见 docs/04），ArkTS 属性用 camelCase，Repository 内做映射，不允许把 ResultSet 直接漏到页面层。
- 每个文件的头部注释注明 `Port of: <antenna-repo 相对路径>`。
- 错误处理：统一 `BusinessError` 捕获 → `Logger.error(tag, msg, err)` → 通过 `MessageEvent` 给用户可见提示；禁止吞异常。
- 资源：所有字符串在 `string.json` 用 `$r('app.string.xxx')` 引用；颜色在 `color.json`。
