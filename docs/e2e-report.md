# E2E 验收报告（T3.11 / T4.8）

> 当前无真机、无 DevEco 工具链。以下为“代码路径推演 + deferred”验收状态，待设备可用后逐项回填实际结果。

## A1 · 订阅闭环 — deferred
- 代码路径：`AddFeedPage → SubscriptionService.subscribe → FeedFetcher → FeedRepository/EpisodeRepository.insert`
- 待验证：URL、预览、订阅、列表展示、未播计数

## A2 · 浏览与在线播放 — deferred
- 代码路径：`FeedDetailPage.loadEpisodes → PlayerPage/FeedDetail.play → PlayerManager.load`
- 待验证：筛选、在线播放、seek、±30s

## A3 · 后台锁屏播放 — deferred
- 代码路径：`PlayerManager + AvSessionBridge + BackgroundPlaybackGuard`
- 待验证：锁屏控制、后台 5 分钟持续

## A4 · 倍速 — deferred
- 代码路径：`PlayerManager.setSpeed`（六档）
- 待验证：1.5x 变速与重启持久化

## A5 · 队列与连播 — deferred
- 代码路径：`QueueEngine`（内存 + DB）+ `PlaybackOrchestrator`（completed → autoAdvance）
- 状态：自动连播代码已实现，待真机验证

## A6 · 下载 — deferred
- 代码路径：`DownloadManager` + `DownloadsPage`
- 待验证：暂停/继续/离线播放/删除

## A7 · 持久化 — deferred
- 代码路径：DB 表、`ProgressPersister`、`UserPreferences`
- 待验证：强杀重启恢复

## A8 · 刷新与通知 — deferred
- 代码路径：`RefreshService + NotificationService`；`WorkSchedulerManager` 定时
- 待验证：真实 feed 更新、通知点击

## A9 · OPML 往返 — deferred
- 代码路径：`OpmlService + OpmlPage`
- 待验证：导出→清空→导入逐项一致

## A10 · 主题与语言 — deferred
- 代码路径：UserPreferences.theme + dark color 资源 + 57 条三语字符串
- 待验证：系统深浅色、中英文切换

## 缺陷预备清单
- [x] PlayerManager completed 未自动连播下一集（A5，已由 PlaybackOrchestrator 实现）
- [ ] FeedDetail/Player/Downloads 缺少 loading/error 提示（见 quality-audit.md）
- [ ] ImageCache 未在全部封面页接入（仅 SubscriptionsPage 接入）
