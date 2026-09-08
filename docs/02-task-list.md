# 02 · 顺序任务清单（执行主清单）

> 使用方式：**严格从上到下逐项执行**。每项完成后在 `docs/progress-log.md` 记录 `[x]` 与验证证据；受阻则记 `[ ]` + 原因，跳到下一个无前置依赖的任务。
>
> “验证”栏分两类：
> - `静态`：无 DevEco 工具链时做自查（对照 docs/01、docs/04、官方 API 链接），记录 `build: deferred`；
> - `hvigor`：环境有 `hvigorw` 时运行 `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`，必须零错误。
>
> 所有“参考”路径均相对 `./antenna-repo/`，**只读**。

---

## Phase 0 · 初始化（M0）

### T0.1 初始化工作区与进度日志
- **前置**：无
- **参考**：无
- **产出**：`antennapod-harmony/`（空目录）、`docs/progress-log.md`
- **步骤**：
  1. 创建 `antennapod-harmony/` 与 `docs/`（如不存在）。
  2. 创建 `docs/progress-log.md`，写入表头：`# 进度日志`、环境信息（node -v、java -version、`which ohpm hvigorw` 的结果、代理可用性测试 `curl -x http://127.0.0.1:7893 -sI https://github.com` 的状态码）。
  3. 记录参考仓库快照：`antenna-repo` 的 commit 与分支（`git -C antenna-repo log -1 --format='%H %s'`）。
- **DoD**：目录与日志存在；日志含上述 3 项事实。
- **验证**：静态

### T0.2 研读参考实现并输出笔记
- **前置**：T0.1
- **参考**：`AGENTS.md`、各模块 `README.md`（`net/README.md`、`parser/README.md`、`playback/README.md`、`storage/README.md`、`ui/README.md`）、`app/src/main/AndroidManifest.xml`
- **产出**：`docs/reference-notes.md`
- **步骤**：
  1. 通读 AGENTS.md 的 Architecture 一节与 5 个模块 README。
  2. 按“模块 → 职责 → 关键类清单（≤8 个/模块）→ 对外接口/事件 → 与鸿蒙映射”格式记录。
  3. 单独一节记录 Manifest 中的权限、四大组件清单（只保留与 MVP 相关者）。
- **DoD**：笔记覆盖 app/model/event/net(common+download)/parser(feed)/playback(service)/storage(database+preferences)/ui(i18n) 七个领域，每领域 ≥ 5 行；无虚构类名。
- **验证**：静态（抽查 10 个类名用 `find antenna-repo -name 'Xxx.java'` 核对存在）

### T0.3 创建 DevEco 工程骨架
- **前置**：T0.1
- **参考**：`docs/03-project-templates.md`（逐文件照抄）
- **产出**：`antennapod-harmony/` 下全部骨架文件：根 4 个 + AppScope 2 个 + entry 配置 4 个 + 资源 8 个 + `EntryAbility.ets` + `Index.ets`
- **步骤**：
  1. 按 docs/03 的顺序创建文件，**先建资源后建引用资源的配置**。
  2. JSON5 文件写完与 docs/03 模板逐行 diff 自查（模板已避开注释与尾逗号陷阱；Node 原生不校验 JSON5，工具链可用时以 hvigor 构建为准）。
  3. 创建 `entry/src/main/ets/` 下 §01 规定的全部空目录，每个目录放 `.gitkeep` 或 `README.md` 一句话说明。
  4. `Index.ets` 显示一行欢迎文本（字符串走资源）。
- **DoD**：`find antennapod-harmony -type f | wc -l` ≥ 25；所有文件路径与 docs/03 一致。
- **验证**：静态；hvigor 可用时运行 `hvigorw --version` 与构建命令并记录结果

### T0.4 工具链探测与决策记录
- **前置**：T0.3
- **参考**：无
- **产出**：`docs/progress-log.md` 中“工具链结论”段
- **步骤**：
  1. 探测 `which hvigorw ohpm`、`ls $DEVECO_SDK_HOME 2>/dev/null`、`node -v`。
  2. 结论二选一写入日志：`build: enabled`（工具链齐）或 `build: deferred`（记录缺什么、需要用户提供什么）。
  3. 若 enabled：在骨架工程执行构建，把完整错误输出贴进日志并逐条修复到零错误。
- **DoD**：日志有明确结论与证据；enabled 时骨架构建通过。
- **验证**：静态/hvigor

### T0.5 移植测试夹具与基础资源
- **前置**：T0.3
- **参考**：`parser/feed/src/test/resources/*.xml`、`parser/feed/src/test/java/de/danoeh/antennapod/parser/feed/element/namespace/{RssParserTest,AtomParserTest}.java`、`ui/i18n/src/main/res/values/strings.xml`
- **产出**：`entry/src/test/resources/feed/*.xml`（9 个 fixture 复制）；`entry/src/test/resources/feed/EXPECTATIONS.md`；应用图标 `app_icon.svg` 占位图
- **步骤**：
  1. 复制 `feed-rss-testRss2Basic.xml`、`feed-atom-testAtomBasic.xml` 等全部 9 个 fixture 到测试资源目录。
  2. 从 AntennaPod 测试类中摘录每个 fixture 的**断言要点**（关键字段期望值）整理成 `entry/src/test/resources/feed/EXPECTATIONS.md`。
  3. 用 SVG 画一个简单圆形+天线占位图标，放入 `resources/base/media/app_icon.svg`。
- **DoD**：9 个 fixture + EXPECTATIONS.md 存在；fixture 文件与上游 `diff` 一致（二进制除外，全是文本）。
- **验证**：`diff -r` 对比源 fixture

---

## Phase 1 · 领域层（M1）

### T1.1 移植领域模型
- **前置**：T0.5
- **参考**：
  - `model/src/main/java/de/danoeh/antennapod/model/feed/{Feed,FeedItem,FeedMedia,FeedPreferences,Chapter,FeedFilter,FeedItemFilter,SortOrder,MediaType?}.java`
  - `model/src/main/java/de/danoeh/antennapod/model/playback/{Playable,MediaType,TimerValue}.java`
  - `model/src/main/java/de/danoeh/antennapod/model/download/{DownloadStatus,DownloadResult,DownloadError,DownloadRequest}.java`
- **产出**：`entry/src/main/ets/model/` 下：`Feed.ets, FeedItem.ets, FeedMedia.ets, FeedPreferences.ets, Chapter.ets, FeedFilter.ets, FeedItemFilter.ets, SortOrder.ets, MediaType.ets, Playable.ets, DownloadStatus.ets, DownloadResult.ets, DownloadError.ets`
- **步骤**：
  1. 对照 docs/04 的接口定义与参考类逐字段移植，Java 的 `List<T>` → `T[]`，`Date` → `number`（epoch ms），`boolean` → `boolean`。
  2. 保留枚举语义（`MediaType.AUDIO/VIDEO`、`Feed.STATE_SUBSCRIBED/STATE_NOT_SUBSCRIBED` 等），用 ArkTS `enum`。
  3. 移植纯逻辑方法：`FeedItem.getMedia()`、`FeedMedia.getDuration()`、`FeedFilter.shouldAutoDownload()`、`FeedItemFilter.isAllowed()` 等（先读原实现再写）。
  4. 不引入任何 `@ohos.*` 依赖。
- **DoD**：文件数 ≥ 12；每个文件头注释含 `Port of:` 路径；与 docs/04 接口字段一一对应；无 `any`。
- **验证**：静态；hvigor 可用时编译通过

### T1.2 数据库层：建表 + DAO/Repository
- **前置**：T1.1
- **参考**：`storage/database/src/main/java/de/danoeh/antennapod/storage/database/{PodDBAdapter,DBReader,DBWriter,FeedDatabaseWriter}.java`
- **产出**：
  - `entry/src/main/ets/db/DbManager.ets`（getRdbStore 单例 + 版本号 + 建表 + 索引）
  - `entry/src/main/ets/db/Tables.ets`（表名/列名常量 + DDL，照 docs/04）
  - `entry/src/main/ets/db/mappers/{FeedMapper,FeedItemMapper,FeedMediaMapper,QueueMapper,DownloadLogMapper}.ets`（ResultSet ↔ model）
  - `entry/src/main/ets/db/repositories/{FeedRepository,EpisodeRepository,QueueRepository,DownloadLogRepository}.ets`
- **步骤**：
  1. 先读 PodDBAdapter 的建表段，与 docs/04 核对列名/类型/默认值。
  2. 实现 `DbManager.init(context)`：`relationalStore.getRdbStore(context, {name:'Antennapod.db', securityLevel: S1})`，version=1 时执行 DDL；version>1 走 `DbMigrator`（MVP 只留空结构）。
  3. 实现泛型 `queryAll/insert/update/delete` + 事务（`beginTransaction/commit/rollBack`）。
  4. 按 DBReader/DBWriter 的查询语义实现 Repository 的方法清单（见 DoD）。
  5. Feed 的隐藏/排序/筛选字段原样保留，MVP 页面可暂不使用。
- **DoD**：7 张表 + 6 个索引全部建出；Repository 至少提供：Feed 增删改查/按 id 查/全部订阅、FeedItem 按 feed 查/按状态查/标记已读、FeedMedia 保存与查询/进度更新、Queue 增删改查/排序、DownloadLog 增查。SQL 与上游语义一致（抽查 5 条）。
- **验证**：静态 + docs/04 逐列核对；hvigor 可用时编译 + 后续设备冒烟（T3.11 覆盖）

### T1.3 偏好设置封装
- **前置**：T1.1
- **参考**：`storage/preferences/src/main/java/de/danoeh/antennapod/storage/preferences/UserPreferences.java`
- **产出**：`entry/src/main/ets/prefs/UserPreferences.ets`
- **步骤**：
  1. 初始化 `preferences.getPreferencesSync(context, {name:'UserPreferences'})`。
  2. 实现 MVP 设置项的类型化 getter/setter：`theme(0/1/2)`、`defaultPlaybackSpeed`、`skipSilence`（isSupported=false）、`streamOverDownload`、`mobileUpdateAllowed`、`updateIntervalMinutes`、`enqueueLocation`、`episodeCacheSizeMb`、`lastPlayedFeedMediaId`。
  3. 默认值与 AntennaPod 相同；key 名沿用 `prefTheme/prefSkipSilence/...`。
- **DoD**：≥ 9 个设置项；getter 有默认值；setter 后 `flush()`。
- **验证**：静态；hvigor 可用时编译

### T1.4 基础工具与事件中心
- **前置**：T1.1
- **参考**：
  - `parser/feed/util/{DurationParser,DateUtils,MimeTypeUtils,SyndStringUtils}.java`
  - `system/src/main/java/de/danoeh/antennapod/system/CrashReportWriter.java`（仅参考其日志持久化策略；上游普通日志用 android.util.Log，ArkTS 侧改用 hilog）
  - `event/src/main/java/de/danoeh/antennapod/event/*.java`（事件字段）
  - `ui/cleaner/HtmlToPlainText.java`
- **产出**：`entry/src/main/ets/utils/{Logger,DurationUtils,DateUtils,MimeTypeUtils,HtmlCleaner}.ets`；`entry/src/main/ets/events/EventHub.ets`
- **步骤**：
  1. Logger 封装 `hilog`（tag 前缀 `APod/`），四级：debug/info/warn/error。
  2. 移植 DurationParser（"1:23:45"、"123"、ISO8601 "PT1H2M3S"）、DateUtils（RFC822/ISO8601 → epoch ms）、MimeTypeUtils（audio/mpeg 等 → MediaType）、HtmlToPlainText（段落/换行处理）。
  3. EventHub 基于 `@ohos.events.emitter`：`publish(evt)`、`subscribe(type, cb)`、`unsubscribe`；事件类型常量与 §01-8 清单一致。
- **DoD**：每个工具类有输入输出示例注释；EventHub 事件类型覆盖 MVP 清单 11 个。
- **验证**：静态；hvigor 可用时编译

### T1.5 HttpClient 封装
- **前置**：T1.4
- **参考**：`net/common/src/main/java/de/danoeh/antennapod/net/common/{AntennapodHttpClient,RedirectChecker,BasicAuthorizationInterceptor,UserAgentInterceptor,UrlChecker}.java`
- **产出**：`entry/src/main/ets/net/HttpClient.ets`、`entry/src/main/ets/net/NetworkError.ets`
- **步骤**：
  1. 用 `@ohos.net.http.createHttp()` 实现 `get(url, options)` / `head(url)`。
  2. options 支持：`headers`（含 Authorization/Range/If-Modified-Since）、`timeoutMs`、`maxRedirects`（默认 5，手动跟随 301/302，循环重定向报错）。
  3. 响应模型：`{status: number, headers: Record<string,string>, body: string, bodyBytes: ArrayBuffer}`；GZIP 由系统处理。
  4. 默认 UA：`AntennaPod/3.12.1 (HarmonyOS NEXT)`；错误分类 `TIMEOUT/NETWORK/HTTP_4XX/HTTP_5XX/REDIRECT_LOOP/PARSE`。
- **DoD**：head/get 齐全；重定向与错误分类有单元测试占位（hvigor 可用时跑）；无 OkHttp 依赖。
- **验证**：静态；真机冒烟在 T3.3 覆盖

### T1.6 RSS/Atom 解析器核心
- **前置**：T1.5
- **参考**：`parser/feed/src/main/java/de/danoeh/antennapod/parser/feed/{FeedHandler,SyndHandler,FeedHandlerResult,HandlerState,UnsupportedFeedtypeException}.java`、`parser/feed/namespace/{Rss20,Atom,Itunes,Media,DublinCore,PodcastIndex,SimpleChapters,Content,Namespace}.java`、`parser/feed/element/*.java`
- **产出**：`entry/src/main/ets/parser/{FeedParser,SyndHandler?}`（合并为 `FeedParser.ets` 内多函数）、`parser/namespaces/{Rss20,Atom,Itunes,Media,DublinCore,PodcastIndex}.ets`、`parser/XmlReader.ets`
- **步骤**：
  1. 实现 `XmlReader`：封装 `@ohos.xml.XmlPullParser` 的 START_TAG/END_TAG/TEXT 事件、`getName()/getAttributeValue(prefix,name)/getText()`，API12 用 `parse()`、API14+ 优先 `parseXml()`（能力探测 try/catch）。
  2. 按 SyndHandler 的状态机移植：顶层 channel/feed 元数据 → item/entry 循环 → 子元素分发（title/link/description/enclosure/media:content/itunes:*）。
  3. 命名空间路由表：Rss20、Atom（含 link rel=enclosure）、Itunes（author/duration/image/subtitle/explicit）、Media（content/thumbnail）、DublinCore、PodcastIndex（chapters/transcript 字段只存不解析）。
  4. 生成 `Feed` + `FeedItem[]` + 备用 URL 列表；feed 无有效条目时抛 `UnsupportedFeedException`。
- **DoD**：`FeedParser.parseFeed(xmlText): ParseResult` 可调用；逻辑分支与 SyndHandler 一致（自查表：channel 级 ≥ 15 字段、item 级 ≥ 12 字段）。
- **验证**：静态；正式验证见 T1.8

### T1.7 解析器工具函数与容错补全
- **前置**：T1.6
- **参考**：`parser/feed/util/{TypeGetter,DurationParser,DateUtils,SyndStringUtils,MimeTypeUtils}.java`
- **产出**：T1.6 产出文件中补全容错；`parser/FeedSanitizer.ets`（feed 检查与清洗）
- **步骤**：
  1. 补 `TypeGetter`（enclosure type 缺失时按扩展名/URL 猜）、`SyndStringUtils`（HTML 标签剥离、空白折叠、描述截断 800 字符保留链接）。
  2. 实现 `FeedSanitizer.checkFeed(url, html)`：对 feedburner 类页面提取真实 XML URL；text/html 响应报 `UnsupportedFeedException` 且附提示。
- **DoD**：与参考行为一致（对照每个方法写 3 个用例注释）。
- **验证**：静态

### T1.8 解析器回归测试（M1 门槛）
- **前置**：T0.5、T1.6、T1.7
- **参考**：`parser/feed/src/test/java/de/danoeh/antennapod/parser/feed/element/namespace/{RssParserTest,AtomParserTest,FeedParserTestHelper}.java`
- **产出**：`entry/src/test/parser/FeedParser.test.ets`（Hypium 用例）+ EXPECTATIONS.md 补充实际值
- **步骤**：
  1. 为 9 个 fixture 各写 1 个用例：解析不抛异常；断言 3–5 个关键字段（title、条目数、首条 title/link/duration、image）。
  2. 若工具链不可用：把每个 fixture 的解析过程用**人工逐步推演**记录到 EXPECTATIONS.md（标记“待 hvigor 运行”）。
  3. 修 bug 直到逻辑上全部通过。
- **DoD**：12 用例齐；hvigor 可用时 `hvigorw test` 全部通过。
- **验证**：hvigor（可用时）；否则静态推演记录

### T1.9 领域层收口（M1 检查）
- **前置**：T1.1–T1.8
- **参考**：无
- **产出**：`docs/progress-log.md` 的 M1 总结段
- **步骤**：对照 §01 检查依赖方向与文件位置；确认模型/DB/解析无 `@ohos.*` 泄漏进 model 层；列出 M1 未决项。
- **DoD**：M1 总结含“通过/未决”两项列表。
- **验证**：静态

---

## Phase 2 · 播放内核（M2）

### T2.1 PlayerManager：生命周期与状态机
- **前置**：T1.4、T1.1
- **参考**：`playback/service/src/main/java/de/danoeh/antennapod/playback/service/internal/{ExoPlayerWrapper,LocalPSMP,ExoPlayerUtils}.java`
- **产出**：`entry/src/main/ets/player/PlayerManager.ets`
- **步骤**：
  1. 模块级单例，`init(context)` 创建 AVPlayer 并注册 `stateChange/timeUpdate/error/bufferingUpdate` 回调。
  2. 按 §01-4 实现状态机与 `loadMedia(media, {autoplay, startPosition})`：`reset → setMediaSource(url 或 fd) → prepare → (seek) → play`。
  3. 所有回调节流转发到 EventHub（`PlayerStatusEvent/PlaybackPositionEvent/PlayerErrorEvent`）。
- **DoD**：状态转换表写在文件头注释；对外方法签名与 §01-4 一致；错误码映射（801/5400101 等常用码先列 5 个）。
- **验证**：静态；设备冒烟 T2.7

### T2.2 播放操作：seek/倍速/音量
- **前置**：T2.1
- **参考**：`ExoPlayerWrapper.java` 的 `seekTo/setPlaybackParams/setVolume`、`SkipUtils.java`（跳过步长逻辑）
- **产出**：`player/PlaybackControls.ets`（纯逻辑）+ PlayerManager 补全方法
- **步骤**：
  1. `seekTo(ms)`、`seekBy(deltaMs)`（边界 clamp）、`setSpeed(speed)`（档位映射表 0.75/1.0/1.25/1.5/1.75/2.0）、`setVolume(0–1)`。
  2. 位置与时长读属性 `currentTime/duration`，无效值（-1）处理。
  3. 倍速在 prepared/playing/paused 任一状态可调；seek 完成后发 `seekDone` 再更新 UI。
- **DoD**：方法齐全；档位映射与 docs/05 官方链接一致；无超出 API 12 的档位（3.0 留给 API13+ 注释）。
- **验证**：静态 + T2.7 冒烟

### T2.3 进度持久化与播完上报
- **前置**：T2.2、T1.2
- **参考**：`LocalPSMP.java`（position 保存/恢复、completed 处理）、`PlaybackServiceTaskManager.java`
- **产出**：`player/ProgressPersister.ets`；PlayerManager 集成
- **步骤**：
  1. `timeUpdate` 节流（5s 间隔）写 `FeedMedia.position`；暂停/切后台/换集时强制写一次。
  2. 加载时若 `FeedMedia.position>0` 且 < duration-10s 则 seek 到该位置（用户设置“从头播放”选项可后置）。
  3. `completed`：标记已播放（played_duration=duration）、写历史时间戳、触发 QueueEngine 自动连播。
- **DoD**：重启恢复进度逻辑完成；不会把 completed 重复计数。
- **验证**：静态 + T3.11 场景 A7

### T2.4 AVSession 媒体会话
- **前置**：T2.2
- **参考**：`playback/service/src/main/java/de/danoeh/antennapod/playback/service/internal/MediaLibrarySessionCallback.java`、`PlaybackServiceNotificationBuilder.java`（控件语义）
- **产出**：`player/AvSessionBridge.ets`
- **步骤**：
  1. `avSession.createAVSession(context, 'AntennaPod', 'audio')` → `activate()`。
  2. `setAVMetaData`：assetId=episode id、title=单集标题、artist=节目名、专辑封面用 `image.createPixelMap`（缓存目录取图，失败用占位图）。
  3. `setAVPlaybackState`：state 映射（play/pause/stop/completed）、position、speed、循环模式。
  4. `setAVQueueItems`：当前队列前 20 项。
  5. 订阅控件事件：`play/pause/stop/playNext/playPrevious/seek/fastForward/rewind/setSpeed`，转发给 PlayerManager。
  6. 销毁时 `deactivate() + destroy()`。
- **DoD**：桥接类完整；事件名与官方 `arkts-apis-avsession-AVSession.md` 一致；无未处理的 Promise 拒绝。
- **验证**：静态 + T2.7/T3.11 锁屏验证

### T2.5 后台持续播放（长时任务）
- **前置**：T2.4
- **参考**：官方 `backgroundTaskManager` 文档（docs/05 链接）
- **产出**：`player/BackgroundPlaybackGuard.ets`；`module.json5` 权限/backgroundModes 修改
- **步骤**：
  1. module.json5 增加 `ohos.permission.KEEP_BACKGROUND_RUNNING`、`ohos.permission.INTERNET`，ability 增加 `"backgroundModes": ["audioPlayback"]`。
  2. play 时：构造 wantAgent（跳转播放页）→ `startBackgroundRunning(ctx, BackgroundMode.AUDIO_PLAYBACK, wantAgent)`。
  3. pause/stop/error 时 `stopBackgroundRunning()`；连续 10 分钟无播放进度由系统取消的兜底日志。
- **DoD**：start/stop 成对出现（代码中无单边调用）；权限声明齐。
- **验证**：静态 + T2.7 真机锁屏 5 分钟持续播放

### T2.6 队列引擎
- **前置**：T1.2
- **参考**：`playback/service/src/main/java/de/danoeh/antennapod/playback/service/PlaybackService.java`（队列与自动连播语义）、`model/playback/Playable.java`
- **产出**：`player/QueueEngine.ets`
- **步骤**：
  1. 内存队列（启动时从 Queue 表载入）：`enqueue/remove/move(item,toIndex)/clear/peek/current/next/prev`。
  2. 自动连播：completed → 出队当前 → 队首播放；队列空则停止并保存“空队列”状态。
  3. “播放历史”：内存数组，会话内有效（持久化历史 Phase 4）。
  4. 每次变更发 `QueueEvent` 并落库。
- **DoD**：next/prev 在边界不越界；播完自动出队与 AntennaPod 默认行为一致。
- **验证**：静态 + T3.11 场景 A5

### T2.7 播放器冒烟页（M2 门槛）
- **前置**：T2.1–T2.6
- **参考**：无（临时页面）
- **产出**：`pages/PlayerSmokePage.ets`
- **步骤**：
  1. 页面含：URL 输入、load、play/pause、±30s、倍速下拉（6 档）、当前时间/总时长、状态文本、错误文本、进度条。
  2. 用公开测试音频（如 `https://file-examples.com/.../sample.mp3`，记录所用 URL 到日志）验证流播放。
  3. 验证锁屏后仍播放、控制中心可暂停/继续。
- **DoD**：三个场景过：①流播放+seek+倍速 ②后台持续 ③错误 URL 显示可读错误。结果截图/文字记录进日志。
- **验证**：真机/模拟器手工（无设备则标记 deferred，逻辑自查）

---

## Phase 3 · MVP UI（M3）

> 每个 UI 任务都要求：数据来自 Repository/服务层；所有字符串走资源；空/加载/错误三态齐全；列表用 `LazyForEach`。

### T3.1 应用壳：导航 + 底部 Tab
- **前置**：T0.3、T1.9、T2.6
- **参考**：`app/src/main/java/de/danoeh/antennapod/activity/MainActivity.java`、`ui/screen/home/HomeFragment.java`（信息架构）
- **产出**：`pages/Index.ets` 重写为壳页；`components/MiniPlayerBar.ets` 占位（显示标题+播放/暂停）
- **步骤**：
  1. `Tabs` 四个 tab：订阅、队列、下载、设置；底部 `MiniPlayerBar`（无播放时隐藏）。
  2. 订阅 `PlayerStatusEvent/PlaybackPositionEvent` 刷新迷你条。
  3. 路由：点迷你条 `router.pushUrl` 到播放页。
- **DoD**：四个 tab 可切换；迷你条随播放状态显隐与刷新。
- **验证**：静态；设备验收 T3.11

### T3.2 订阅列表页
- **前置**：T3.1
- **参考**：`ui/screen/subscriptions/{SubscriptionFragment,SubscriptionsRecyclerAdapter}.java`、`ui/glide`（图片加载语义）
- **产出**：`pages/SubscriptionsPage.ets`、`components/FeedListCard.ets`、`services/ImageCache.ets`
- **步骤**：
  1. 列表项：封面（Image 网络 src + 磁盘缓存 + 占位图）、标题（自定义标题优先）、未播计数（FeedItems 里 read=0 的数量，Repository 一次查询返回计数）。
  2. 长按菜单：重命名（对话框）、退订（二次确认）、刷新该 feed。
  3. 空状态：“还没有订阅”+ 添加按钮。
  4. ImageCache：URL→hash 文件名；下载成功后写 `filesDir/image_cache`；≥50MB LRU 清理。
- **DoD**：订阅/退订/重命名/刷新闭环；封面二次进入不重复网络请求（缓存命中）。
- **验证**：设备场景 A1

### T3.3 添加订阅页（URL 输入 + 在线预览）
- **前置**：T1.6、T3.2
- **参考**：`ui/screen/AddFeedFragment.java`、`ui/screen/onlinefeedview/{OnlineFeedViewActivity,FeedDiscoverer}.java`
- **产出**：`pages/AddFeedPage.ets`、`services/FeedFetcher.ets`（HttpClient+FeedParser 组合，含 HTTP 缓存头语义）
- **步骤**：
  1. 输入框校验 URL（http/https），提交后显示 loading。
  2. `FeedFetcher.fetchFeed(url)`：head→content-type 判断，下载 XML → parseFeed；失败分类提示（不是 feed/网络/超时/解析失败）。
  3. 预览：标题、作者、简介、封面、单集数、[订阅] 按钮；订阅成功后写库并返回订阅列表。
  4. 已订阅的 feed 再次添加：提示并跳到该 feed。
- **DoD**：成功/失败/重复订阅三条路径都有明确 UX；真实 feed 至少测 2 个（日志记录 URL）。
- **验证**：设备场景 A1

### T3.4 Feed 详情页（单集列表）
- **前置**：T3.2
- **参考**：`ui/screen/feed/{FeedItemlistFragment,FeedInfoFragment}.java`、`ui/episodeslist/{EpisodesListFragment,EpisodeItemListAdapter}.java`
- **产出**：`pages/FeedDetailPage.ets`、`components/EpisodeListItem.ets`
- **步骤**：
  1. 顶部：封面、简介（可折叠）、刷新/退订入口。
  2. 筛选 chips：全部/未播放/已下载。
  3. 列表项：标题、日期（相对日期格式化）、时长、播放进度条、状态图标（已下载/在播/已播）；点击行为：已下载播本地，否则在线播；右侧按钮：下载/入队。
  4. 长按：标记已播/未播、加入队列、删除本地文件。
- **DoD**：筛选正确；点击播放正确选源（streamOverDownload 偏好生效）。
- **验证**：设备场景 A2

### T3.5 播放页 + 迷你播放条
- **前置**：T2.7、T3.4
- **参考**：`ui/screen/playback/audio/{AudioPlayerFragment,CoverFragment,ItemDescriptionFragment,PlaybackSpeedDialogActivity,VariableSpeedDialog}.java`
- **产出**：`pages/PlayerPage.ets`、`components/MiniPlayerBar.ets` 完善、`components/SpeedDialog.ets`
- **步骤**：
  1. 大卡：封面、标题/节目名、进度条（可拖动 seek）、当前/剩余时间、±跳过按钮、播放/暂停、倍速、睡眠（Phase 4 入口占位）、队列入口。
  2. shownotes：折叠区，RichText 渲染清洗后 HTML；无 notes 显示占位文案。
  3. 倍速对话框：仅 API12 支持档位；选择后即时生效并持久化。
  4. 迷你条：全 app 底部可见，带播放/暂停与进度细条。
- **DoD**：播放页与 AVSession 状态双向同步（锁屏操作后页面 1s 内更新）；拖动进度不抖。
- **验证**：设备场景 A2/A3/A4

### T3.6 队列页
- **前置**：T2.6、T3.1
- **参考**：`ui/screen/queue/{QueueFragment,QueueRecyclerAdapter}.java`
- **产出**：`pages/QueuePage.ets`
- **步骤**：
  1. 队列列表（LazyForEach）：缩略图、标题、来源、当前位置高亮、上移/下移/移除按钮。
  2. 点击项直接播放；清空队列需二次确认。
  3. 空状态引导。
- **DoD**：增删移与播放联动正确；列表变更后 Queue 表同步。
- **验证**：设备场景 A5

### T3.7 下载管理器
- **前置**：T1.2、T1.5
- **参考**：`net/download/service/src/main/java/de/danoeh/antennapod/net/download/service/episode/{EpisodeDownloadWorker,DownloadAnnouncer}.java`、`net/download/service/feed/DownloadServiceInterfaceImpl.java`
- **产出**：`download/DownloadManager.ets`（按 §01-5 接口实现）
- **步骤**：
  1. 实现 `startDownload(feedMedia, networkPref)`：先检查已存在文件；写 DownloadLog（开始）；创建 request 任务并注册进度/完成/失败回调。
  2. 完成：更新 FeedMedia 行（file_url/size/duration/下载时间），发 `EpisodeDownloadEvent`。
  3. 失败分类写 DownloadLog（网络/空间不足/取消），可重试。
  4. `pause/resume/remove` 全部可用；app 重启后未完成任务不再自动恢复（MVP 限制，日志记录）。
- **DoD**：接口按 §01-5 实现；断点续传行为依赖系统任务（真机验证）；Plan B 接口位已留注释。
- **验证**：设备场景 A6

### T3.8 下载页与下载日志页
- **前置**：T3.7
- **参考**：`ui/screen/download/{DownloadLogFragment,DownloadLogAdapter,DownloadLogDetailsDialog}.java`、`app/.../CompletedDownloadsFragment.java`（如有）
- **产出**：`pages/DownloadsPage.ets`、`pages/DownloadLogPage.ets`
- **步骤**：
  1. 进行中列表：标题、进度条、速度、暂停/继续/取消；点击暂停态可重试。
  2. 日志页：成功/失败分组，显示原因与时间；长按清空日志。
  3. 空状态与错误提示。
- **DoD**：下载状态与事件实时联动；删除本地文件会同步清理 FeedMedia.file_url。
- **验证**：设备场景 A6

### T3.9 设置页
- **前置**：T1.3、T3.1
- **参考**：`ui/screen/preferences/{MainPreferencesFragment,PlaybackPreferencesFragment,DownloadsPreferencesFragment,UserInterfacePreferencesFragment}.java`
- **产出**：`pages/SettingsPage.ets`
- **步骤**：
  1. 分组：外观（浅色/深色/跟随系统）、播放（默认倍速、跳过静音-隐藏）、下载（在线优先/下载优先、移动数据开关）、存储（缓存大小显示+清理按钮）、关于（版本、开源协议入口文本）。
  2. 设置修改立即生效：主题走 `AppStorage` + `ConfigurationConstant` 资源限定；默认倍速在下次播放生效。
  3. 缓存清理：删除 image_cache 与无引用下载文件（二次确认）。
- **DoD**：全部设置可改可持久化；重启后保持。
- **验证**：设备场景 A7/A10

### T3.10 国际化
- **前置**：T3.1–T3.9
- **参考**：`ui/i18n/src/main/res/values/strings.xml`（文案对照，不照抄全部，MVP 约 120 条）
- **产出**：`resources/base/element/string.json`（英文）与 `zh_CN`、`en_US` 副本
- **步骤**：
  1. 扫描代码中所有 `$r('app.string.*')`，生成清单。
  2. 按清单补英文（参考 AntennaPod strings.xml 对应 key 或意译）与中文。
  3. 系统语言切换后 UI 文案随之切换。
- **DoD**：清单条数 = string.json 条数；无硬编码用户可见文案（代码内 grep 检查）。
- **验证**：`grep -rn "'[A-Za-z].*'" pages components` 无用户文案硬编码（技术常量除外）

### T3.11 端到端验收与缺陷修复（M3 门槛）
- **前置**：T3.1–T3.10
- **参考**：`docs/05-risks-and-verification.md` 场景 A1–A7
- **产出**：`docs/e2e-report.md`（每场景：步骤/结果/证据/缺陷号）
- **步骤**：按 docs/05 逐场景执行；每个缺陷回填对应任务修复并复测；无设备时改为“按代码路径推演”，并标注 deferred。
- **DoD**：A1–A7 全部 PASS（或明确 deferred + 推演通过）。
- **验证**：真机/模拟器验收

### T3.12 版本冻结 v0.1.0（M3 完成）
- **前置**：T3.11
- **参考**：无
- **产出**：`antennapod-harmony/CHANGELOG.md`；`app.json5` versionName=1.0.0、versionCode=1000000；`docs/progress-log.md` M3 总结
- **步骤**：冻结代码基线（建议 `git init && git add && git commit`，若用户允许）；写 MVP 已知限制清单。
- **DoD**：CHANGELOG 列 MVP 能力与 10 条以上已知限制；基线可回溯。
- **验证**：静态

---

## Phase 4 · MVP+（M4）

### T4.1 手动全量刷新 + 新单集通知
- **前置**：M3
- **参考**：`net/download/service/src/main/java/de/danoeh/antennapod/net/download/service/feed/{FeedUpdateWorker,FeedUpdateManagerImpl,NewEpisodesNotification}.java`
- **产出**：`services/RefreshService.ets`、`services/NotificationService.ets`
- **步骤**：订阅页“全部刷新”：逐个 feed 拉取解析 → 事务合并（按 item_identifier+pubdate 去重）→ 新条目计数 → 通知（点击进 feed）。
- **DoD**：刷新期间 UI 有进度；重复刷新不产生重复条目；通知点击可跳转。
- **验证**：设备场景 A8（手动部分）

### T4.2 定时自动刷新（workScheduler）
- **前置**：T4.1
- **参考**：官方 workScheduler 文档（docs/05 链接）
- **产出**：`WorkSchedulerExtensionAbility` + `services/WorkSchedulerManager.ets`（注册/取消周期任务）
- **步骤**：按设置间隔注册 repeat 任务（networkType=WiFi 或按用户设置）；扩展内调用 RefreshService；异常静默记录。
- **DoD**：间隔改设置后任务重建；无网络时任务延后。
- **验证**：设备场景 A8（自动部分，等待 ≥1 个周期）

### T4.3 OPML 导入/导出
- **前置**：M3
- **参考**：`storage/importexport` 模块、`ui/screen/preferences/ImportExportPreferencesFragment.java`
- **产出**：`services/OpmlService.ets`（导出/导入/解析）
- **步骤**：
  1. 导出：生成 OPML 2.0（title/xmlUrl/htmlUrl）→ `DocumentSaveOptions` 存为文件。
  2. 导入：`DocumentViewPicker` 选文件 → 解析 outline 列表 → 逐个订阅（失败项汇总报告，不中断）。
  3. 设置页两个入口。
- **DoD**：A9 往返一致；部分失败有报告。
- **验证**：设备场景 A9

### T4.4 睡眠定时器
- **前置**：M3
- **参考**：`playback/service/.../internal/{SleepTimer,EpisodeSleepTimer,ClockSleepTimer}.java`、`ui/screen/playback/SleepTimerDialog.java`
- **产出**：`player/SleepTimer.ets`、播放页对话框
- **步骤**：倒计时（5/10/15/30/60 分钟或章节结束）；到时暂停并停止长时任务；剩余时间发 `SleepTimerUpdatedEvent` 显示。
- **DoD**：计时准确（±1s）；暂停后任务清空。
- **验证**：设备手工

### T4.5 收藏夹
- **前置**：M3
- **参考**：`ui/screen/FavoritesFragment.java`、Favorites 表语义
- **产出**：单集长按“收藏”、订阅页入口收藏列表页
- **步骤**：复用 Favorites 表；单集页与长按菜单加星标；列表页支持取消收藏。
- **DoD**：收藏状态与 DB 一致；重启保持。
- **验证**：设备手工

### T4.6 章节（来自 feed 的 SimpleChapters）
- **前置**：M3
- **参考**：`ui/screen/chapter/{ChaptersFragment,ChaptersListAdapter}.java`、`parser/feed/PodcastIndexChapterParser.java`
- **产出**：解析 podcast:chapters（url 型只保存，内联型解析入 SimpleChapters 表）；播放页章节入口与跳转
- **步骤**：刷新时解析内联章节写表；播放页点击章节 seek；当前章节高亮。
- **DoD**：内联章节完整可用；外链章节显示“暂不支持”提示（backlog）。
- **验证**：设备手工

### T4.7 搜索/发现页
- **前置**：M3
- **参考**：`net/discovery/src/main/java/de/danoeh/antennapod/net/discovery/{ItunesPodcastSearcher,PodcastSearchResult,PodcastSearcherRegistry}.java`
- **产出**：`net/Discovery.ets`（iTunes Search API `https://itunes.apple.com/search?media=podcast&term=...`）+ 订阅页搜索入口
- **步骤**：JSON 解析结果（名称/作者/封面/feedUrl）→ 预览订阅页复用 T3.3 预览。
- **DoD**：搜索、预览、订阅全链路；空结果/网络错误有提示。
- **验证**：设备手工（记录查询词）

### T4.8 MVP+ 验收（M4 门槛）
- **前置**：T4.1–T4.7
- **参考**：docs/05 场景 A8–A10
- **产出**：`docs/e2e-report.md` 增补
- **DoD**：A8–A10 PASS 或明确 deferred。
- **验证**：真机/模拟器

---

## Phase 5 · 质量与发布（M5）

### T5.1 单元测试补强
- **目标**：model/utils/parser 行覆盖率 ≥ 60%（有工具链时用 hvigor 覆盖率报告；无工具链时按“用例数/公开方法数”统计）。
- **产出**：`entry/src/test/` 下补 `FeedFilter/FeedItemFilter/DurationUtils/DateUtils/QueueEngine/ProgressPersister` 测试。
- **DoD**：用例数 ≥ 40，全绿。
- **验证**：hvigor test（可用时）

### T5.2 深色模式与无障碍
- **任务**：双主题资源复查（颜色不写死、全部走 color.json + dark 限定）；关键图标对比度；文字最小 14fp；朗读标签（accessibilityText）覆盖主要按钮。
- **DoD**：A10 深色部分通过；关键交互均有朗读标签。
- **验证**：设备检查

### T5.3 错误与空状态审计
- **任务**：逐页检查 loading/error/empty 三态；网络错误可重试；错误文案可理解（不露出异常堆栈）；日志有 trace。
- **DoD**：审计表覆盖 9 个页面，每页 ≥ 3 态。
- **验证**：静态审计表

### T5.4 性能优化
- **任务**：列表全部 LazyForEach；图片缓存上限与清理；DB 查询加索引走查（EXPLAIN 5 条高频 SQL）；启动 ≤ 2s（真机取数）；内存无 1 小时播放持续增长（真机 Profiler 或系统内存监控）。
- **DoD**：5 条 SQL 有 EXPLAIN 记录；性能数据记录进日志。
- **验证**：真机

### T5.5 签名与 Release 构建
- **任务**：按用户提供的签名材料配置 `build-profile.json5` signingConfigs；`hvigorw assembleHap --mode module -p product=default -p buildMode=release`；生成 HAP 与上架检查清单（图标 1024、隐私声明、权限说明：INTERNET/KEEP_BACKGROUND_RUNNING 用途）。
- **DoD**：release HAP 产出；权限用途说明文案齐全。
- **验证**：构建产物存在 + 安装真机自启动

### T5.6 文档收口（M5 完成）
- **任务**：更新 README（构建/运行/架构/移植对照）、更新 progress-log 总结、标记 backlog。
- **DoD**：README 能让新人按步骤构建；backlog 与 T6 对齐。
- **验证**：静态

---

## Phase 6 · Backlog（可选，不设完成期限）

- **T6.1 模块化拆分**：按 docs/01 目录边界拆 HAR/HSP（common/core/player/features），建立依赖图与 api 导出面。
- **T6.2 gpodder.net 同步**：参考 `net/sync/gpoddernet` + `net/sync/service`。
- **T6.3 转录/字幕**：参考 `parser/transcript` 与 `ui/transcript`。
- **T6.4 统计页**：参考 `ui/statistics` 与 StatisticsItem。
- **T6.5 自动下载与清理算法**：参考 `net/download/service/episode/autodownload/*` 与 `EpisodeCleanupAlgorithm`。
- **T6.6 嵌入章节/嵌入封面**：AVMetadataExtractor 能力评估后实现。
- **T6.7 视频播客**：参考 `VideoplayerActivity`，AVPlayer 视频模式 + PiP 能力评估。
- **T6.8 服务卡片/桌面卡片**：快速播放控制卡片。
- **T6.9 AntennaPod 数据库导入**：OPML 之外的 DB 迁移（读取安卓备份 db 文件）。
- **T6.10 投屏**：AVCastPicker 替代 Chromecast。
- **T6.11 深链**：antennapod.org/deeplink 的 skills 接入。
- **T6.12 智能穿戴（手表）**：对应原 app-wearos，评估 HarmonyOS Wearable。

## 附：单任务执行模板（执行者每项照此格式在日志中记录）

```
## T3.3 添加订阅页 · 2026-09-08
- 产出文件：AddFeedPage.ets, FeedFetcher.ets
- 参考阅读：AddFeedFragment.java, OnlineFeedViewActivity.java
- 验证方式：hvigor(无)/静态
- 结果：PASS（或 BLOCKED: 原因）
- 备注：2 个真实 feed 已测（URL…）
```
