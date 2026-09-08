# MVP / MVP+ 功能矩阵

> 更新时间：2026-09-08（第10轮）
> 状态图例：`✅ 已实现代码` · `🔧 待工具链验证` · `⏳ 待真机` · `⬜ 未做`

## 一、MVP（M3）

| 能力 | 状态 | 主要代码 | 说明 |
|---|---|---|---|
| 添加订阅（URL） | ✅ | `pages/AddFeedPage.ets` + `services/SubscriptionService.ets` | 拉取→解析→入库 |
| 在线预览 | ✅ | `services/FeedFetcher.ets` + `AddFeedPage` | 解析后显示标题/条目数 |
| 订阅列表 | ✅ | `pages/SubscriptionsPage.ets` + `FeedRepository` | LazyForEach + 封面 + 未播数 |
| Feed 详情/筛选 | ✅ | `pages/FeedDetailPage.ets` + `EpisodeRepository` | 全部/未播放/已下载 |
| 在线播放 | ✅ | `player/PlayerManager.ets` | AVPlayer 流播放 |
| 本地播放 | ✅ | `PlayerManager` + `Playable.getSourceUrl` | 优先本地文件 |
| 播放控制 | ✅ | `PlayerPage.ets` + `PlayerManager` | 播放/暂停/seek/±30s |
| 倍速 | ✅ | `PlayerManager.setSpeed` | 0.75–2.0 六档 |
| 进度记忆 | ✅ | `player/ProgressPersister.ets` | 5s 节流/强制保存 |
| 自动连播 | ✅ | `player/PlaybackOrchestrator.ets` + `QueueEngine.autoAdvance` | completed 自动下一集 |
| 队列管理 | ✅ | `pages/QueuePage.ets` + `QueueEngine` | 上移/下移/移除/持久化 |
| 后台播放 | ✅ | `player/BackgroundPlaybackGuard.ets` + AVSession | AUDIO_PLAYBACK 长时任务 |
| 锁屏控制 | ✅ | `player/AvSessionBridge.ets` | 播放/暂停/seek/倍速 |
| 下载 | ✅ | `download/DownloadManager.ets` | @ohos.request 下载 |
| 下载暂停/继续 | ✅ | `DownloadManager.pause/resume` | 依赖系统任务 |
| 下载日志 | ✅ | `pages/DownloadsPage.ets` + `DownloadLogRepository` | 成功/失败列表 |
| 设置 | ✅ | `pages/SettingsPage.ets` + `UserPreferences` | 主题/在线优先/倍速/缓存/定时刷新/OPML |
| 离线播放 | ✅ | `PlayerManager` 本地文件路径 | 需真机验证 |
| 重启持久化 | ✅ | relationalStore + preferences | 需真机验证 |

## 二、MVP+（M4）

| 能力 | 状态 | 主要代码 | 说明 |
|---|---|---|---|
| 全部刷新 | ✅ | `services/RefreshService.ets` | 按 item_identifier 去重 |
| 新单集通知 | ✅ | `services/NotificationService.ets` | notificationManager |
| 定时刷新 | ✅ | `work/WorkSchedulerManager.ets` + ExtensionAbility | 系统 workScheduler |
| OPML 导入 | ✅ | `pages/OpmlPage.ets` + `OpmlService.importOpml` | 文件选择器 + fs |
| OPML 导出 | ✅ | `OpmlPage.exportOpml` + `OpmlService.exportOpml` | DocumentSaveOptions |
| 睡眠定时器 | ✅ | `player/SleepTimer.ets` + PlayerPage | 15m 示例，可扩展 |
| 收藏 | ✅ | `FavoritesRepository` + `FavoritesPage` + FeedDetail 星标 | 列表+播放 |
| 章节 | ✅ | `ChapterRepository` + PlayerPage 章节列表 | 点击跳转 |
| 搜索/发现 | ✅ | `net/Discovery.ets` + `SearchPage` | iTunes Search API |
| 图片缓存 | ✅ | `services/ImageCache.ets` + `FeedCover` | LRU 50MB |

## 三、Backlog / 明确排除

| 能力 | 状态 |
|---|---|
| gpodder 同步 | ⬜ backlog |
| 转录/字幕 | ⬜ backlog |
| 统计页 | ⬜ backlog |
| 自动下载/清理算法 | ⬜ backlog |
| 视频播客 | ⬜ backlog |
| 投屏 | ⬜ backlog |
| 服务卡片 | ⬜ backlog |
| 智能手表 | ⬜ backlog |
| WearOS/Android 兼容 | 不适用 |

## 四、验证状态

| 验证类型 | 状态 | 证据 |
|---|---|---|
| 非 UI 层静态类型检查 | ✅ 通过 | `scripts/check-project.sh`：53 TS files 0 error |
| 路径/资源/页面一致性 | ✅ 通过 | check-project.sh 全绿 |
| 解析器测试源码 | ✅ 已编写 | `entry/src/test/parser/FeedParser.test.ets`（9 用例） |
| 工具层测试源码 | ✅ 已编写 | `entry/src/test/utils/Utils.test.ets`（5 用例） |
| Hypium 实际运行 | 🕐 待工具链 | 无 hvigor/ohpm |
| DevEco 构建 | 🕐 待工具链 | 无 hvigor |
| 真机 E2E | 🕐 待设备/工具链 | `docs/e2e-report.md` |
