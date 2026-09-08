# 进度日志

## 环境信息
- node -v: v24.19.0
- java -version: OpenJDK 21.0.11
- ohpm: not found
- hvigorw: not found
- DEVECO_SDK_HOME: not set
- 代理: 127.0.0.1:7893（接通 GitHub）
- 构建能力结论: **build: deferred**（缺少 ohpm/hvigor/DevEco SDK；代码按静态自检执行，待工具链就绪后统一 hvigor 构建验证）

## 参考仓库快照
- repo: https://github.com/AntennaPod/AntennaPod (shallow clone -> ./antenna-repo)
- branch: develop
- commit: 80243910fe620217111a60b0054a968f66084382
- 消息: Implement swipe in queue actions : move to top/bottom and share (#8469)
- 规模: 629 java 文件 / ~80,581 行 Java；29 个 Gradle 模块

## 任务记录
- [x] T0.1 初始化工作区与进度日志
- [x] T0.2 研读参考实现并输出笔记（docs/reference-notes.md 已生成，9 fixtures 已确认）
- [x] T0.3 创建 DevEco 工程骨架（30 个文件，antennapod-harmony/）
- [x] T0.4 工具链探测与决策记录（build: deferred，见环境信息）
- [x] T0.5 移植测试夹具与基础资源（9 个 XML + EXPECTATIONS.md + 占位图标）

## 2026-09-08 T0 完成
- 工程骨架: `antennapod-harmony/` 已创建，30 个文件。
- 参考笔记: `docs/reference-notes.md`。
- 解析夹具: `entry/src/test/resources/feed/` 9 个 fixture + EXPECTATIONS.md。
- 构建状态: build deferred（无 hvigor/ohpm）。

## T1 阶段执行记录（2026-09-08，静态自检，build deferred）
- [x] T1.1 领域模型：model/ 下 9 个 ArkTS 文件（Enums/Feed/FeedItem/FeedMedia/FeedPreferences/Chapter/DownloadLogEntry/QueueItem/Playable）
- [x] T1.2 数据库层：db/ 下 Tables.ets、DbManager.ets、4 个 Mapper、4 个 Repository（DDL 对齐 docs/04）
- [x] T1.3 偏好设置：prefs/UserPreferences.ets（MVP 设置项 + init）
- [x] T1.4 工具与事件：utils/{Logger,DurationUtils,DateUtils,MimeTypeUtils,HtmlCleaner}.ets、events/EventHub.ets
- [x] T1.5 网络层：net/HttpClient.ets（@ohos.net.http + 错误分类）
- [x] T1.6 解析器：parser/XmlReader.ets（延迟 onStart 解决属性时序）、parser/FeedParser.ets（RSS2/Atom 基础 + enclosure/media:content + payment/logo/image）
- [x] T1.7 容错与获取：parser/FeedSanitizer.ets、services/FeedFetcher.ets
- 待办：T1.8 解析器 9 fixture 断言需要 hvigor/ohpm 工具链运行；当前进行静态推演。

## T2 阶段执行记录（2026-09-08，静态自检，build deferred）
- [x] T2.1/T2.2 PlayerManager：player/PlayerManager.ets（AVPlayer 创建/状态机/load/play/pause/seek/seekBy/setSpeed 六档映射/事件发布）
- [x] T2.4 AVSession：player/AvSessionBridge.ets（create/activate/metadata/playbackState/控件事件')
- [x] T2.5 后台长时任务：player/BackgroundPlaybackGuard.ets（AUDIO_PLAYBACK + wantAgent）
- 待办：T2.3 进度持久化、T2.6 QueueEngine、T2.7 冒烟页需继续；UI 层 T3 未开始。

## T2 补充记录（2026-09-08）
- [x] T2.3 ProgressPersister：player/ProgressPersister.ets（5s 节流 + 强制保存）
- [x] T2.6 QueueEngine：player/QueueEngine.ets（内存队列 + 持久化 + 自动下一项接口）
- [x] T2.7 PlayerSmokePage：pages/PlayerSmokePage.ets（已注册到 main_pages）
- [x] EpisodeRepository.getById 补齐，满足 QueueEngine 依赖

## T3.1 执行记录（2026-09-08）
- [x] T3.1 应用壳：pages/Index.ets 重写为 Bottom Tabs（订阅/队列/下载/设置）+ MiniPlayerBar 占位；创建 SubscriptionsPage/QueuePage/DownloadsPage/SettingsPage 四个页面骨架；字符串资源补齐（base/en_US/zh_CN）
- 待办：T3.2 订阅列表真实数据、T3.3 添加订阅、T3.4 详情、T3.5 播放页、T3.6 队列、T3.7 下载、T3.8 下载页、T3.9 设置、T3.10 i18n 完善、T3.11 E2E

## T3 执行记录（2026-09-08，静态实现）
- [x] T3.1 应用壳：Index Tabs + 四个页面骨架 + MiniPlayerBar + 字符串资源（base/en_US/zh_CN 13+ 条）
- [x] T3.2 订阅列表：SubscriptionsPage 从 FeedRepository 加载真实订阅、空状态、添加入口
- [x] T3.3 添加订阅：AddFeedPage + SubscriptionService.subscribe（拉取→解析→入库 Feed/FeedItem/FeedMedia）+ FeedRepository/E pisodeRepository 插入方法
- [x] T3.4 Feed 详情：FeedDetailPage + 筛选 chips（全部/未播放）+ 单集列表 + 跳转导航
- [x] T3.7 下载管理：DownloadManager.ets（@ohos.request.downloadFile + 进度/完成/失败事件 + EpisodeRepository.updateMediaFile）
- 待办：T3.5 播放页、T3.6 队列页真实数据、T3.8 下载页、T3.9 设置页、T3.10 i18n 补全、T3.11 E2E

## T3 补充记录（2026-09-08）
- [x] T3.5 播放页：PlayerPage.ets（状态/进度条/播放暂停/倍速/seek）
- [x] T3.6 队列页：QueuePage.ets 真实加载 QueueEngine + 上移/下移/移除
- [x] T3.8 下载日志页：DownloadsPage.ets 从 DownloadLogRepository 加载
- [x] T3.9 设置页：SettingsPage.ets（主题/在线优先/默认倍速示例，调用 UserPreferences）
- [x] T3.10 国际化部分：全部新增文案同步 base/en_US/zh_CN（当前 17 组 key）
- 待办：T1.8 解析回归测试用例源码、T3.11 E2E、T4 等

## 播放链路补充（2026-09-08）
- FeedDetailPage 单集点击 → PlayerManager.load → PlayerPage
- 播放页已注册到 main_pages；队列/下载/设置页保持页面级功能框架

## 第2轮执行记录（2026-09-08）
- [x] EntryAbility 初始化核心单例（DbManager/UserPreferences/DownloadManager/AvSession/BackgroundPlaybackGuard）并修复相对导入路径
- [x] T1.8 解析回归测试源码：entry/src/test/parser/FeedParser.test.ets（9 用例），夹具复制到 rawfile/feed_test
- [x] T4.1 RefreshService + NotificationService + EpisodeRepository.findByItemIdentifier；订阅页接入“全部刷新”
- [x] T4.2 WorkScheduler：RefreshWorkSchedulerExtensionAbility + WorkSchedulerManager + module.json5 extensionAbilities 注册
- [x] T4.3 OpmlService（导入/导出/转义）
- [x] T4.4 SleepTimer + 播放页“Sleep 15m”按钮
- [x] T4.5 FavoritesRepository
- [x] T4.6 ChapterRepository
- [x] T4.7 Discovery（iTunes 搜索）+ SearchPage + 订阅页搜索入口
- [x] T3.12/T5 文档：antennapod-harmony/README.md、CHANGELOG.md、docs/release-checklist.md
- 静态检查：0 缺失导入；页面注册与实际 @Entry 一致；三语 string 24/24 对齐。

## 静态验证证据（第2轮）
- `tsc --noEmit`：模型层 9 个文件通过（exit 0）
- `tsc --noEmit`：纯工具层（DurationUtils/DateUtils/MimeTypeUtils/HtmlCleaner + 模型依赖）通过（exit 0）
- 导入路径检查：全工程 0 缺失
- 资源三语：base/en_US/zh_CN 各 24 key 完全对齐

## 第2轮补充（T3.10/T4.5 UI 接线）
- [x] T3.10 全量固定文案迁移：新增 21 个资源 key，三语 45/45 对齐；动态消息通过 resourceManager.getStringSync 前缀处理
- [x] T4.5 收藏按钮：FeedDetailPage 单集行“★”切换 FavoritesRepository
- 复查：导入 0 缺失；页面注册与 @Entry 一致；资源三语对齐；纯模型/工具层 tsc 通过

## 第3轮执行记录（2026-09-08）
- [x] T4.3 UI：OpmlPage（DocumentViewPicker select/save + fs 读写）并注册；设置页加 OPML 入口
- [x] T4.5 UI：FavoritesPage（收藏列表/取消/点击播放）并注册；订阅页加收藏入口
- [x] T4.2 UI：设置页“定时刷新”按钮调用 WorkSchedulerManager.schedule
- [x] T5.1 单测：entry/src/test/utils/Utils.test.ets（Duration/Date/Mime/HtmlCleaner）
- [x] T5.2 深色模式：新增 dark/element/color.json，base 增加 surface/accent，页面卡片背景改用 $r(app.color.surface)
- 静态检查：0 导入缺失；资源 56/56/56 对齐；页面注册一致；工程 103 文件

## 第3轮补充（T4.6 章节 UI / T5 文档）
- [x] Playable 增加 feedItemId；所有构造调用更新（FeedDetail/Favorites/QueueEngine/PlayerSmoke）
- [x] PlayerPage 加载章节列表（ChapterRepository），点击章节跳转 seek；新增 player_chapters 三语
- [x] T5.3/T5.4 文档：docs/quality-audit.md（页面三态审计 + 6 条高频 SQL 走查）
- [x] T5.5 文档：docs/signing-guide.md（自动签名/release 签名/构建/上架检查）
- 静态检查：模型层 tsc 通过；导入 0 缺失；资源三语对齐

## 第4轮执行记录（2026-09-08）
- [x] ImageCache：services/ImageCache.ets（URL hash 缓存、LRU 清理、返回 file:// 路径）；HttpClient.getBytes；components/FeedCover.ets 接入订阅列表
- [x] 自动连播：player/PlaybackOrchestrator.ets（completed -> QueueEngine.autoAdvance）；QueueEngine.autoAdvance；EntryAbility 启动编排
- [x] FeedRepository.update 补全 description/language/author/link/feedIdentifier/lastRefreshAttempt 持久化
- [x] MessageHelper（promptAction toast）
- [x] 设置页“清理图片缓存”功能 + 资源
- [x] docs/e2e-report.md：A1–A10 验收状态（deferred）+ 缺陷清单
- 静态检查：导入 0 缺失；资源 60/60/60 对齐；页面注册一致；工程 107 文件

## 第5轮执行记录（2026-09-08）
- [x] 建立可重复的全量静态类型检查：tools/platform-stubs.d.ts + scripts/static-check.sh
- [x] 通过脚本验证：52 个非 ArkUI TS 文件在桩声明下 tsc --noEmit 0 错误
- [x] 该检查可发现 db/player/parser/net 等非 UI 层的类型/语法问题；后续每次改动可运行
- 说明：pages/components 属于 ArkUI 声明式语法，仍须 DevEco 工具链构建验证。

## 第6轮执行记录（2026-09-08）
- [x] 新增 components/LazyDataSource.ets 通用 LazyForEach 数据源（IDataSource + DataChangeListener 通知）
- [x] SubscriptionsPage / FeedDetailPage / QueuePage 重构为 LazyForEach；FeedDetail 增加 loading/error 态
- [x] 全量静态检查脚本再次通过：52 个非 UI TS 文件 0 错误；全工程导入 0 缺失；资源 60/60/60
- 说明：本轮起对工作区 ArkTS 源文件的写入需要更高沙箱权限（已获批），后续继续写文件时保持正确路径。

## 第6轮补充（2026-09-08）
- [x] FavoritesPage 也改用 LazyForEach + LazyDataSource
- [x] 静态检查再次通过：52 个非 UI TS 文件 0 错误；导入 0 缺失；资源 60/60/60
- 注：DownloadsPage/SearchPage 仍为 ForEach，后续可继续 LazyForEach 化。

## 第8轮执行记录（2026-09-08）
- [x] 查明路径问题：真实工作路径始终为 /home/riko/homennapodcast；/home/riko/homenpodcast 是 write 工具路径笔误产生的独立副本目录
- [x] 将误副本中的 7 个最新文件同步回正确工作区（Subscriptions/FeedDetail/Queue/Search/Favorites/Downloads/DbMigration）
- [x] 已用 danger-full-access 删除误目录 /home/riko/homenpodcast（确认不存在）
- [x] DbMigration 接入 DbManager.init：读取旧版本→执行 DDL→迁移→设置新版本
- [x] 静态检查通过：53 个非 UI TS 文件 0 错误；导入 0 缺失；正确工作区 112 文件

## 第8轮补充（2026-09-08）
- [x] 修复 FavoritesRepository.list 未加载 item.media 的缺陷，收藏页点击播放现在可获取媒体
- [x] 静态检查仍通过：53 个非 UI TS 文件 0 错误

## 第9轮执行记录（2026-09-08）
- [x] 新增 scripts/check-project.sh 统一校验（路径/导入/资源/页面注册/静态检查）
- [x] FeedCover 接入：SearchPage 搜索结果、FavoritesPage 收藏列表、FeedDetailPage 头部
- [x] check-project.sh 全部通过：资源 61 三语对齐、页面注册 8、静态 53 文件 0 错误

## 第10轮执行记录（2026-09-08）
- [x] 新增 docs/feature-matrix.md：MVP/MVP+ 功能矩阵、Backlog 与验证状态汇总
- [x] 功能矩阵确认：MVP 全部能力均已实现代码；MVP+ 全部已实现代码；静态验证 53 文件 0 错误；实际构建/真机待工具链

## 第10轮补充（2026-09-08）
- [x] 新增 scripts/runtime-pure-test.sh：纯模型/工具编译为 JS 后由 Node 实际断言
- [x] 运行时验证通过：DurationUtils / DateUtils / MimeTypeUtils / HtmlCleaner / Playable 全部 PASS
- [x] README 增加运行说明

## 第11轮执行记录（2026-09-08）
- [x] 补 FeedFilter / FeedItemFilter 纯模型（移植自 AntennaPod）
- [x] runtime-pure-test.sh 增加 FeedFilter/FeedItemFilter/FeedItem 断言
- [x] 全部通过：静态 55 TS files 0 error；runtime PASS；check-project 全绿

## 第11轮补充（2026-09-08）
- [x] PlayerPage 增加 1s 定时刷新进度/状态，onDisappear 清除定时器
- [x] 统一校验仍全绿：静态 55 文件、runtime PASS、路径/资源/页面一致

## 第12轮执行记录（2026-09-08）
- [x] FeedItem 增加 isDownloaded / isInProgress / isNew 方法
- [x] runtime-pure-test.sh 覆盖这些方法并通过
- [x] Index 迷你播放条订阅 PlayerStatusEvent，播放状态实时刷新
- [x] check-project 全绿：55 TS 静态 0 error，runtime PASS

## 第13轮执行记录（2026-09-08）
- [x] DownloadsPage、FavoritesPage 增加加载态（loading 状态与 finally 清理）
- [x] check-project 全绿：静态 55 TS 0 error，runtime PASS

## 第14轮执行记录（2026-09-08）
- [x] 设置页增强：定时刷新间隔输入（分钟，>=120）、设置并重排、取消定时
- [x] 新增 5 个三语资源，当前 66/66/66 对齐
- [x] check-project 全绿：静态 55 TS 0 error，runtime PASS

## 第15轮执行记录（2026-09-08）
- [x] runtime-pure-test.sh 扩展：FeedMedia / Feed / QueueItem / Chapter 断言
- [x] 全部通过；check-project 全绿（资源 66 对齐，静态 55 TS 0 error）

## 第16轮执行记录（2026-09-08）
- [x] OpmlPage 增加 loading 状态、按钮禁用、finally 复位
- [x] check-project 全绿：静态 55 TS 0 error，runtime PASS，资源 66 对齐

## 第17轮执行记录（2026-09-08）
- [x] 新增 scripts/env-report.sh（工具链/路径/工程状态报告）
- [x] 新增 docs/toolchain-blocker.md（构建阻塞说明）
- [x] 当前工具链：node/js OK，ohpm/hvigorw/SDK 缺失；check-project 全绿

## 第18轮执行记录（2026-09-08）
- [x] 新增 scripts/build.sh（工具链就绪后标准构建入口；缺失时提示）
- [x] 新增 docs/HANDOFF.md（交接文档：构建/测试/验收/已知关注点）
- [x] README 更新

## Git 仓库交付（2026-09-08）
- 工作区已初始化为 git repo，main 分支
- 裸仓库：remote/antennapod-harmony.git、remote/harmony-project.git
- Git daemon 运行于 9418，局域网可 clone
## 第19轮执行记录（2026-09-08，DevEco 工具链就绪）
- [x] 首次 DevEco 构建：修复 41 个 ArkTS 编译错误（untyped-obj-literals / as-const / EventPriority.NORMAL 缺失 / RequestMethod / hasOwnProperty / onAppear+position 属性冲突 / NotificationContent 字段 / XmlReader 回调接口）
- [x] 单测链路打通：安装 @ohos/hypium 1.0.28、补齐 List.test.ets 门面；诊断出宿主 LocalTest 中 @ohos.xml 与 rawfile 均为 no-op 桩
- [x] XmlReader 重写为纯 ArkTS 分词器（无平台依赖，宿主/真机行为一致）
- [x] FeedParser 修复：knownElements 补 'feed'、podcast:funding / podcast:transcript 解析、未知元素子树忽略、link 无 rel 时取 href、mimeType 按 URL 扩展名推导
- [x] Hypium 单测全绿：9 FeedParser + 5 Utils（BUILD SUCCESSFUL，0 Error）
- [x] debug assembleHap BUILD OK（产物 entry/build/default/outputs/default/entry-default-unsigned.hap）
- [ ] 真机 E2E：无设备/模拟器（device list 为空，无 emulator 实例）→ 待用户接入真机
- [ ] 签名发布：未配置 signingConfigs（未登录/未执行 devecocli signature generate）
- [x] 真机运行（2026-09-08）：无线调试连接 Mate 80 Pro（192.168.3.149:40725）；卸载旧包后安装成功并启动 EntryAbility；进程存活、截图确认订阅页正常渲染
- [x] 签名：devecocli signature generate 生成签名并写入 build-profile.json5（SignHap 通过）
