# 03 · 下载与自动化域 — 上游 vs 鸿蒙移植版逐项对比

**基准**
- 上游：`antenna-repo/`（sparse-checkout 仅含 `app/src/main`、`ui/`、`storage/preferences`）。
  `net:download:*`、`storage:database`、`storage:importexport`、`storage:database-maintenance-service`、`system`、`event`、`model`、`parser:feed`、`playback:*` **未检出**。
  凡涉及 `DownloadService` / `EpisodeDownloadWorker` / `DBWriter` / `AutomaticDownloadAlgorithm` / `DatabaseExporter` / `OpmlBackupAgent` / `FeedMedia` / `FeedFilter` / `MimeTypeUtils` 的结论，均为**依据 UI/偏好调用点推断**（表中逐条标注）。
- 移植版：`antennapod-harmony\entry\src\main\ets`。
- 状态：`✅ 对齐` / `🔸 简化/替代` / `⬜ 缺失` / `➕ 移植版独有`。

## 结论摘要

1. **下载执行层是重写而非移植**：上游依赖 WorkManager + 前台 `DownloadService`（模块未检出），移植版用 `@ohos.request` 的 `request.downloadFile`（`DownloadManager.ets:72`）。能力面显著收窄：无队列/并发上限、无重试退避、无失败原因分类、无跨进程持久化（`statusMap` 为静态内存表，`DownloadManager.ets:22,31`，进程重启即丢失）。
2. **下载日志页只做到"能看能清"**：清空历史、空状态、进行中进度行对齐；但失败原因文案（`DownloadErrorLabel` 22 种映射）、重试按钮、详情对话框、排序、下拉刷新、搜索、批量选择 **全部缺失**；日志行 `onTap` 为空实现（`DownloadsPage.ets:168-169`）。
3. **自动下载只保留最小可用子集**：全局开关 + 仅 WiFi + 仅充电 + 集数上限 + 每 Feed 过滤器。缺 `prefEnableAutoDlQueue`（入队自动下载）；缓存上限由"集数枚举含无限"改为自由数字输入（**默认 50 vs 上游 20/25**）；"仅充电"**默认值与上游相反**。
4. **自动清理只剩二元开关**：`prefAutoDeleteLocal`、`prefFavoriteKeepsEpisode`、`prefEpisodeCleanup`（-3/-1/0/12/24/72/120/168/-2 九档）全缺，只在"播放完成"时按每 Feed 4 档策略删除（`PlaybackOrchestrator.ets:77-98`），无周期性维护任务。
5. **6 类能力整块缺失**：数据目录选择、数据库导出/导入、自动数据库备份、代理、HTML/收藏导出、移动网络更新类型 6 项粒度。移植版以 `StoragePage`（按订阅占用 + 单订阅删除 + 清空全部）作为上游所没有的替代物。
6. **定时刷新键名与默认值漂移**：上游 `prefAutoUpdateIntervall`（默认 720）→ 移植版 `prefAutoUpdateInterval`（默认 360）；最小间隔被硬抬到 2 小时（`WorkSchedulerManager.ets:8,12`）且强制 WiFi（`:17`）；**冷启动不恢复调度**（`EntryAbility.ets` 无 `WorkSchedulerManager` 调用）。
7. **移植版补齐的部分**：`StoragePage`、图片缓存清理入口、`prefEpisodeNotification` 全局通知开关、条件检测失败兜底、残留分片文件显式清理。

## 逐项对比表

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| **1 下载执行 · 触发下载（移动网络确认）** | `app/.../actionbutton/DownloadActionButton.java:49-90`；300s 免打扰窗口 `:20-25`（BYPASS_TYPE_NOW/LATER） | `pages/FeedDetailPage.ets:855-867`、`:383-400` | 🔸 简化/替代 | 无"允许本次/稍后下载"对话框与 300 秒 bypass 记忆，直接下载（`DownloadManager.ets:69-70` `enableMetered/enableRoaming: true`） |
| 1 · 重复/已下载判定 | `DownloadActionButton.java:92-95`（isDownloadingEpisode \|\| isDownloaded） | `download/DownloadManager.ets:50-55` | 🔸 | 仅按 `mediaId` 在 `statusMap` 去重，不看 `fileUrl`；已下载判定交给 UI（`FeedDetailPage.ets:952-961`） |
| 1 · 取消下载 | `actionbutton/CancelDownloadActionButton.java:31-37`（cancel + `disableAutoDownload()` + `DBWriter.setFeedItem`） | `DownloadManager.ets:141-158`；`DownloadsPage.ets:387-397` | 🔸 | **不回写 `item.autoDownloadEnabled=false`**，取消后下次刷新仍可能被自动下载 |
| 1 · 暂停/继续 | UI 侧 `ui/episodeslist/EpisodeItemViewHolder.java:141-146`；服务侧未检出 | `DownloadManager.ets:119-139`；`DownloadsPage.ets:370-385` | ✅ 对齐 | 均为会话内暂停/继续 |
| 1 · 删除本地文件 | `actionbutton/DeleteActionButton.java:34-43`；可见性 `:45-52` | `DownloadManager.ets:164-175`；`db/repositories/EpisodeRepository.ets:189-194` | ✅ 对齐 | 均清 `file_url` 保留单集；移植版额外清 `size`/`download_date` |
| 1 · 流播 | `actionbutton/StreamActionButton.java:34-49` | `FeedDetailPage.ets:881-893`、`:236-266` | 🔸 | 无独立"流播"按钮（点播即流播）；额外提供 `prefStreamConfirmMobile` 二次确认 |
| 1 · 本地播放按钮 | `actionbutton/PlayLocalActionButton.java:31-45`；`ItemActionButton.java:45-46` | 无 | ⬜ 缺失 | 移植版无 local feed 概念 |
| 1 · 主按钮决策链 | `actionbutton/ItemActionButton.java:35-56`（playing→pause / local→playLocal / downloaded→play / downloading→cancel / streamOverDownload→stream / else→download） | `FeedDetailPage.ets:383-400`、`:952-961` | 🔸 | 缺 playing/pause 与 `prefStreamOverDownload` 分支；`downloadState()` 只用 fileUrl + 会话状态 |
| 1 · MIME/扩展名推断 | `parser/feed/util/MimeTypeUtils.java`（**模块未检出**，依据 `FeedMedia` 调用点推断） | `utils/MimeTypeUtils.ets:18-45`（guessExtension）、`:47-87`（guessMimeType） | 🔸 | 映射表较短（无上游 `TypeGetter` 的多级回退）；`guessExtension` 兜底 `.mp3` |
| 1 · 进度/失败事件 | `event` 模块未检出；`activity/MainActivity.java:235-267` 用 WorkManager LiveData 取进度 | `events/EventHub.ets` + `DownloadManager.ets:79-116` | 🔸 简化/替代 | EventHub 替代 EventBus+WorkManager LiveData；**进程重启后任务态丢失** |
| 1 · 下载日志写入 | `DBWriter`（`storage:database` **未检出**，依据 `DownloadLogFragment.java:103` 推断） | `DownloadManager.ets:198-208` | 🔸 | `reason` 恒为 `REASON_USER=0`（`:17`）；detail 为硬编码中文 `'下载完成'/'下载失败 code=N'` |
| **2 下载列表 · 已完成列表数据源** | `ui/screen/download/CompletedDownloadsFragment.java:306-343`（`DBReader.getEpisodes` + runningDownloads 合并） | `DownloadsPage.ets:257-294` | 🔸 | 移植版把"进行中"与"下载记录"拆成两个区块，记录来自 DownloadLog 表（`DownloadLogRepository.ets:9-21`）而非 FeedItem 表 |
| 2 · 排序 | `CompletedDownloadsFragment.java:396-417`（DownloadsSortDialog，4 种） | 无 | ⬜ 缺失 | 固定 `ORDER BY completion_date DESC`（`DownloadLogRepository.ets:11`） |
| 2 · 工具栏菜单 | `app/src/main/res/menu/downloads_completed.xml:7-31`（搜索/日志/删除已播放/刷新/排序）；`CompletedDownloadsFragment.java:172-205` | `DownloadsPage.ets:45-54`（仅"清空历史"） | ⬜ 缺失 | 无搜索、无刷新、无"删除已播放的下载"（上游 `:185-203`）、无排序 |
| 2 · 下拉刷新 | `CompletedDownloadsFragment.java:104-107`（→ `FeedUpdateManager.runOnceOrAsk`） | 无 | ⬜ 缺失 | 下载页无法触发订阅刷新 |
| 2 · 批量选择/滑动操作 | `CompletedDownloadsFragment.java:113-130`（SwipeActions + FloatingSelectMenu） | 无 | ⬜ 缺失 | |
| 2 · 空状态 | `CompletedDownloadsFragment.java:242-248`；`DownloadLogFragment.java:65-69` | `DownloadsPage.ets:73-79`、`:104-111` | ✅ 对齐 | |
| 2 · 清空下载日志 | `DownloadLogFragment.java:100-107` → `DBWriter.clearDownloadLog()`；`res/menu/download_log.xml:6-11` | `DownloadsPage.ets:296-304` → `DownloadLogRepository.ets:36-39` | ✅ 对齐 | |
| 2 · 日志条目状态文案 | `DownloadLogAdapter.java:55-71`（类型 + 相对时间 `DateUtils.getRelativeTimeSpanString`） | `DownloadsPage.ets:342-355` | 🔸 | 不区分 feed/media 类型；用 `toLocaleString()` 绝对时间 |
| 2 · 失败原因分类 | `DownloadErrorLabel.java:14-45`（22 种 `DownloadError` → 文案） | 无 | ⬜ 缺失 | 只显示"下载失败"（`DownloadsPage.ets:344-345`），不展示 `reasonDetailed` |
| 2 · 重试按钮 | `DownloadLogAdapter.java:90-121`（feed→`runOnce`；media→`DownloadActionButton.onClick`） | 无 | ⬜ 缺失 | |
| 2 · "更新已成功"判定 | `DownloadLogAdapter.java:125-133`（`newerWasSuccessful`） | 无 | ⬜ 缺失 | 不会隐藏已过期的失败项 |
| 2 · 详情对话框 | `DownloadLogDetailsDialog.java:61-168`；`res/layout/download_log_details_dialog.xml:1-154` | 无 | ⬜ 缺失 | `logRow.onTap` 空实现（`DownloadsPage.ets:168-169`）；无播客/单集/人读原因/技术原因/URL、无复制、无跳转订阅 |
| 2 · 日志行视图 | `DownloadLogItemViewHolder.java:14-37`；`res/layout/downloadlog_item.xml` | `DownloadsPage.ets:163-171`（复用 `EpisodeRow`，`showAction:false`） | 🔸 简化/替代 | 无 icon、无 reason 行、无 `tapForDetails`、无次要动作按钮 |
| **3 自动下载 · 全局开关** | `ui/preferences/.../res/xml/preferences_autodownload.xml:4-8` `prefEnableAutoDl`(false)；`storage/preferences/.../UserPreferences.java:570-572` | `SettingsPage.ets:146-150`；`prefs/UserPreferences.ets:150-157`（键 `prefAutoDownload`） | ✅ 对齐 | 语义一致（默认 false）；**键名不同** |
| 3 · 入队时自动下载 | `preferences_autodownload.xml:9-13` `prefEnableAutoDlQueue`(false)；`UserPreferences.java:574-576` | 无 | ⬜ 缺失 | |
| 3 · 缓存上限 | `preferences_autodownload.xml:14-20` `prefEpisodeCacheSize`（values 5/10/25/50/100/500/-1，`ui/preferences/.../values/arrays.xml:118-136`）；`UserPreferences.java:566-568` | `SettingsPage.ets:158-165`、`:632-638`；`UserPreferences.ets:178-185` | 🔸 | 上游枚举含"无限(-1)"，XML 默认 25 而 `UserPreferences.java:567` 默认 20（上游自身不一致）；移植版自由数字输入，默认 **50**，无"无限"档 |
| 3 · 仅充电时下载 | `preferences_autodownload.xml:21-25` `prefEnableAutoDownloadOnBattery`(**true**)；`UserPreferences.java:578-580` | `SettingsPage.ets:152-156`；`UserPreferences.ets:168-175`（默认 **false**） | 🔸 | **默认值相反** |
| 3 · 仅 WiFi | 上游由 `prefMobileUpdateTypes` 的 `auto_download` 项控制（`preferences_downloads.xml:43-49`；`UserPreferences.java:512-514`） | `SettingsPage.ets:133-137`；`UserPreferences.ets:159-166`（默认 true） | 🔸 替代 | 新增独立布尔开关，替代上游 6 项多选中的一项 |
| 3 · 自动下载判定算法 | `net/download/service/autodownload/AutomaticDownloadAlgorithm`、`EpisodeAutomaticDownloadAlgorithm`（**模块未检出**，依据 `ui/preferences/.../AutoDownloadPreferencesFragment.java:11` 与偏好项推断） | `services/AutoDownloadService.ets:19-55` | 🔸 | 移植版顺序：全局开关 → `feed.autoDownloadEnabled` → `conditionsOk()` → 逐条 `item.autoDownloadEnabled` + `countDownloaded() >= limit` 即 return；上游另有每 Feed 上限与队列分支 |
| 3 · 每 Feed 过滤器 | `model/.../FeedFilter.java`（**模块未检出**）；`ui/screen/feed/preferences/FeedSettingsPreferenceFragment.java:232-259` | `model/FeedFilter.ets:15-45`；`RefreshService.ets:121`（入库时写 `item.autoDownloadEnabled`） | ✅ 对齐 | 包含词/排除词/最小时长三项语义一致 |
| 3 · 条件检测失败兜底 | 未检出 | `AutoDownloadService.ets:68-86`（异常时放行并记日志） | ➕ 移植版独有 | |
| **4 自动清理 · 播放后删除** | `ui/preferences/.../res/xml/preferences_auto_deletion.xml:5-10` `prefAutoDelete`(false)；`UserPreferences.java:440` | `SettingsPage.ets:174-178`；`UserPreferences.ets:187-194` | ✅ 对齐 | |
| 4 · 本地文件删除开关 | `preferences_auto_deletion.xml:11-16` `prefAutoDeleteLocal`(false)；`AutomaticDeletionPreferencesFragment.java:36-63`（首次开启弹确认） | 无 | ⬜ 缺失 | 无独立开关，也无开启确认对话框 |
| 4 · 收藏保留单集 | `preferences_auto_deletion.xml:17-22` `prefFavoriteKeepsEpisode`(true)；`UserPreferences.java:436` | 无 | ⬜ 缺失 | 自动删除不检查收藏状态 |
| 4 · 清理阈值 | `preferences_auto_deletion.xml:23-29` `prefEpisodeCleanup`(-2)；values -3/-1/0/12/24/72/120/168/-2（`arrays.xml:201-211`）；`AutomaticDeletionPreferencesFragment.java:66-91` 动态文案；`UserPreferences.java:701-707` | 无 | ⬜ 缺失 | 缺"保留收藏/保留队列/听完后 N 小时或 N 天/永不"全部策略 |
| 4 · 每 Feed 删除策略 | `FeedSettingsPreferenceFragment.java:311-323`（4 档） | `FeedSettingsPage.ets:150-153`、`:606-617`；`model/Enums.ets:38-43` | ✅ 对齐 | 4 档枚举（NEVER/GLOBAL_DEFAULT/ALWAYS/WHEN_PLAYED）一致 |
| 4 · 执行点 | `ui/view/LocalDeleteModal`、`storage/database-maintenance-service`（**未检出**，依据 `DeleteActionButton.java:14,41` 推断） | `player/PlaybackOrchestrator.ets:77-98`（播放完成时） | 🔸 简化/替代 | 只在播放完成触发，无周期性数据库维护任务 |
| 4 · 删除同时移出队列 | `preferences_downloads.xml:34-39` `prefDeleteRemovesFromQueue`(**false**)；`UserPreferences.java:452-454` | `SettingsPage.ets:180-184`；`UserPreferences.ets:196-203`（默认 **true**）；`PlaybackOrchestrator.ets:93-95` | 🔸 | **默认值相反** |
| **5 数据目录 · 选择对话框** | `ui/preferences/.../screen/downloads/ChooseDataFolderDialog.java:15-35`；`DataFolderAdapter.java:29-142`（枚举外置/内部目录，显示可用/总空间 + 占用进度条 + 单选） | 无 | ⬜ 缺失 | 固定写 `context.filesDir + '/downloads'`（`DownloadManager.ets:58`）；无 `prefDataFolder` |
| 5 · 当前路径摘要 | `app/.../DownloadsPreferencesFragment.java:63-78`；`preferences_downloads.xml:6-8` `prefChooseDataDir`；`UserPreferences.java:717-753` | 无 | ⬜ 缺失 | |
| **6 存储统计 · 上游位置** | **无独立存储页**；能力分散在 `ui/statistics/downloads/DownloadStatisticsFragment.java:63-89`（按订阅下载量排序）与 `preferences_downloads.xml:6-8`（数据目录入口） | `pages/StoragePage.ets:222-239`（按订阅占用 + 总量卡） | ➕ 移植版独有 | 移植版把上游统计页的"按订阅下载量"与数据目录入口合并为独立存储页 |
| 6 · 按订阅删除 | 未检出（`DBReader.StatisticsResult` 只读） | `StoragePage.ets:241-252`；`EpisodeRepository.ets:416-431` | ➕ 移植版独有 | |
| 6 · 清空全部下载 | 未检出 | `StoragePage.ets:254-268`；确认弹层 `:179-211` | ➕ 移植版独有 | |
| 6 · 容量单位格式 | `DataFolderAdapter.java:48-53`（`Formatter.formatShortFileSize`，自动 B/KB/MB/GB） | `StoragePage.ets:270-279`、`DownloadsPage.ets:331-340`（仅 KB/MB 两档） | 🔸 | 无 GB 档 |
| **7 定时刷新 · 间隔设置** | `preferences_downloads.xml:11-17` `prefAutoUpdateIntervall` 默认 720；values 0/60/120/240/480/720/1440/4320（`arrays.xml:49-69`）；`UserPreferences.java:481-491` | `SettingsPage.ets:122-131`、`:613-624`；`UserPreferences.ets:67-74`（键 `prefAutoUpdateInterval`，默认 **360**） | 🔸 | **键名拼写不同**；**默认 720→360**；改为数字输入；`0`（永不）不可选（`SettingsPage.ets:616` 要求 ≥120） |
| 7 · 最小间隔 | 上游最小档 60 分钟，无硬下限 | `work/WorkSchedulerManager.ets:8` `MIN_INTERVAL_MS=2h`、`:12` `Math.max` 抬升；`SettingsPage.ets:616` | 🔸 | 实际最小 2 小时，与上游 1 小时档不对齐 |
| 7 · 调度实现 | `FeedUpdateManager.restartUpdateAlarm`（`net/download` **未检出**）；调用点 `DownloadsPreferencesFragment.java:81-86`、`activity/MainActivity.java:216`、`:369` | `WorkSchedulerManager.ets:11-28`（workScheduler，`NETWORK_TYPE_WIFI`、isRepeat、isPersisted） | 🔸 替代 | workScheduler 替代 WorkManager/AlarmManager；**强制 WiFi**（上游受 `prefMobileUpdateTypes.feed_refresh` 控制） |
| 7 · 启动时登记 | `MainActivity.java:216`（每次启动 `restartUpdateAlarm`） | 无 | ⬜ 缺失 | 仅在设置页点"应用"时登记（`SettingsPage.ets:619`）；`entryability/EntryAbility.ets` 无 `WorkSchedulerManager` 调用 → **冷启动不恢复调度** |
| 7 · 取消/关闭 | 间隔设 0（`UserPreferences.java:489-491` `isAutoUpdateDisabled`） | `SettingsPage.ets:626-629` → `WorkSchedulerManager.cancel()` | 🔸 替代 | 无"永不"档，用独立取消动作 |
| 7 · 执行体 | `FeedUpdateWorker`（未检出） | `work/RefreshWorkSchedulerExtensionAbility.ets:9-16` → `RefreshService.refreshAll()` | ✅ 对齐 | |
| **8 新单集行为 · 全局动作** | `preferences_downloads.xml:18-24` `prefNewEpisodesAction` 默认 1；values 1/3/2（`arrays.xml:71-81`）；`UserPreferences.java:72,844-847` | 无 | ⬜ 缺失 | 只有每 Feed 动作，无全局默认项 |
| 8 · 每 Feed 动作 | `FeedSettingsPreferenceFragment.java:231-243`、`:326-349`（含"跟随全局"档） | `FeedSettingsPage.ets:155-158`、`:619-628`；`Enums.ets:46-50`；`RefreshService.ets:152-163` | 🔸 | 3 档且无"跟随全局"；`applyNewEpisodesAction` **只实现 ADD_TO_QUEUE**，ADD_TO_INBOX 无实际动作 |
| 8 · 新单集通知 | `net/download/service/feed/NewEpisodesNotification`（**未检出**）；渠道 `ui/notifications/.../NotificationUtils.java:21,111`（IMPORTANCE_DEFAULT） | `services/NotificationService.ets:64-82`、`:84-117` | 🔸 替代 | 固定单渠道 ID 1001（`:9`），无 channel 分组/重要性分级 |
| 8 · 通知开关 | 无全局开关（`preferences_notifications.xml` 仅 `prefShowDownloadReport`/`pref_gpodnet_notifications`）；每 Feed `episodeNotification` | `SettingsPage.ets:197-201`；`UserPreferences.ets:104-111` `prefEpisodeNotification`(true) | ➕ 移植版独有 | 新增全局开关 |
| 8 · 通知权限申请 | `app/src/main/AndroidManifest.xml:10` POST_NOTIFICATIONS | `NotificationService.ets:33-50` `ensureEnabled()` | ✅ 对齐 | |
| 8 · 点击跳转 | 未检出 | `NotificationService.ets:120-136` `createWantAgent()` | ✅ | |
| **9 刷新服务 · 全量刷新** | `FeedUpdateManagerImpl`（`net/download` **未检出**）；注册点 `app/.../ClientConfigurator.java:51` | `services/RefreshService.ets:30-55` | 🔸 | 跳过 `keepUpdated=false` 的订阅（`:35-38`）；**串行**逐 Feed，无并发 |
| 9 · 并发数 | 未检出 | `RefreshService.ets:34-51`（for 串行） | 🔸 | 无并发上限/队列控制（下载侧 `DownloadManager` 亦无） |
| 9 · 分页抓取 | 未检出（`Feed.isPaged`/`nextPageLink` 在 model 模块） | `RefreshService.ets:17` `MAX_PAGES=5`、`:78-94`（visited 去重） | 🔸 | 硬上限 5 页 |
| 9 · 去重 | 未检出 | `RefreshService.ets:64-70`（`itemIdentifier` 集合） | ✅ 对齐 | |
| 9 · 合并字段 | 未检出 | `RefreshService.ets:95-102`（title/description/imageUrl/lastUpdate/lastRefreshAttempt） | 🔸 | 未回写 author/language/funding 等字段 |
| 9 · 手动单 Feed 刷新 | `FeedUpdateManager.runOnce(context, feed)`（`DownloadLogAdapter.java:106`、`FeedItemlistFragment.java:176`） | `RefreshService.ets:134-149` | ✅ 对齐 | 均不受 `keepUpdated` 限制 |
| 9 · 失败重试/退避 | 未检出（WorkManager backoff） | 无（`RefreshService.ets:48-50` 记日志后继续） | ⬜ 缺失 | |
| 9 · 移动网络更新类型 | `preferences_downloads.xml:43-49` `prefMobileUpdateTypes` 6 项多选（`arrays.xml:138-159`，默认 images+sync）；`UserPreferences.java:493-559`（6 个 getter） | `UserPreferences.ets:56-65`（单布尔 `wifi_only`/`wifi_and_mobile`） | ⬜ 缺失 | 6 个粒度（feed_refresh/episode_download/auto_download/streaming/images/sync）压缩成 1 个布尔，且**全代码库无调用点**（死代码） |
| 9 · 代理 | `preferences_downloads.xml:50-53` `prefProxy`；`ui/preferences/.../screen/ProxyDialog.java:40-260`（DIRECT/HTTP/SOCKS + 连接测试）；`UserPreferences.java:590-623` | 无 | ⬜ 缺失 | `net/HttpClient.ets:89-124` 无代理配置入口 |
| **10 导入导出 · 数据库导出** | `ui/preferences/.../res/xml/preferences_import_export.xml:7-11`；`app/.../ImportExportPreferencesFragment.java:151-160`、`:271-283`（`DatabaseExporter.exportToDocument`，**未检出**） | 无 | ⬜ 缺失 | |
| 10 · 数据库导入 | `preferences_import_export.xml:17-21`；`ImportExportPreferencesFragment.java:146-149`、`:190-220`、`:256-269`（含警告弹窗 + 重启） | 无 | ⬜ 缺失 | |
| 10 · 自动备份 | `preferences_import_export.xml:12-16`；`ImportExportPreferencesFragment.java:161-178`、`:379-388`；`AutomaticDatabaseExportWorker`（**未检出**）；`UserPreferences.java:335-339` | 无 | ⬜ 缺失 | |
| 10 · OPML 导出 | `preferences_import_export.xml:25-28`；`ImportExportPreferencesFragment.java:125-130`、`:358-377`（`OpmlWriter`，**未检出**） | `pages/OpmlPage.ets:306-322`；`services/OpmlService.ets:16-26` | 🔸 | 用 DocumentViewPicker 落盘；OPML `<title>` 硬编码 `Homenna Podcast Subscriptions`（`OpmlService.ets:17`） |
| 10 · OPML 导入 | `preferences_import_export.xml:29-32`；`ImportExportPreferencesFragment.java:136-144` → `activity/OpmlImportActivity.java:127`（勾选界面） | `OpmlPage.ets:254-303`、`:104-163`；`OpmlService.ets:28-63` | ✅ 对齐 | 均有勾选界面与逐条导入 |
| 10 · HTML / 收藏导出 | `preferences_import_export.xml:36-43`；`ImportExportPreferencesFragment.java:131-135`、`:179-188`（`HtmlWriter`/`FavoritesWriter`，**未检出**） | 无 | ⬜ 缺失 | |
| 10 · Android 备份代理 | `app/src/main/AndroidManifest.xml:35` `android:backupAgent=".storage.importexport.OpmlBackupAgent"`（**未检出**） | 无 | ⬜ 缺失 | 无系统级备份集成 |
| 10 · 导出结果反馈 | `ImportExportPreferencesFragment.java:222-254`（Snackbar + 错误对话框） | `OpmlPage.ets:322`（页面 message 文本） | 🔸 | |
| **11 缓存 · 流播优先于下载** | `ui/preferences/.../res/xml/preferences_user_interface.xml:90-94` `prefStreamOverDownload`(false)；`UserPreferences.java:796-801`；`ItemActionButton.java:51-52` | `SettingsPage.ets:103-107`；`UserPreferences.ets:47-54` | 🔸 | 偏好项对齐，但**未接入主按钮决策链**（`FeedDetailPage.ets:383-400` 未读取） |
| 11 · 下载页按钮动作 | `preferences_user_interface.xml:95-100` `prefDownloadsButtonAction`(false)；`UserPreferences.java:456-458`；`CompletedDownloadsFragment.java:371-375` | 无 | ⬜ 缺失 | 无"下载页按钮改为播放"的开关 |
| 11 · 删除移出队列 | 见第 4 节（默认 false） | 见第 4 节（默认 true） | 🔸 | 默认值相反 |
| 11 · 图片缓存清理 | 上游由 Glide 模块（`ui/glide`）管理，无用户入口 | `SettingsPage.ets:640-643` → `ImageCache.clearCache` | ➕ 移植版独有 | |

## 关键行为差异

1. **并发数**：上游 `DownloadService`（未检出）由 WorkManager 唯一任务名 + 队列约束管理；移植版**无并发上限**——每次 `startDownload` 都新建一个 `request.downloadFile` 任务（`DownloadManager.ets:72-74`），`AutoDownloadService.ets:36-54` 可在循环中连续创建多个任务，仅靠 `statusMap` 按 `mediaId` 去重。
2. **重试**：上游依赖 WorkManager 退避重试（`net/download` 未检出）；移植版失败后直接清残留并置 `FAILED`（`DownloadManager.ets:105-116`），**无自动重试、无退避**；刷新侧同理（`RefreshService.ets:48-50` 仅记日志）。
3. **暂停/继续**：移植版走 `task.pause()/resume()`（`DownloadManager.ets:119-139`），只对**当前进程内**存活任务有效；`statusMap` 是静态内存表（`:22`），进程被杀后任务与进度丢失，`fileUrl` 为空的单集在 UI 退回 `IDLE`（`FeedDetailPage.ets:960`）。上游由持久化 Worker 保证跨进程续传。
4. **失败原因分类**：上游 `DownloadErrorLabel.java:14-45` 把 22 种 `DownloadError` 映射为可读文案，并对 `ERROR_PARSER_EXCEPTION_DUPLICATE` 用 info 图标（`DownloadLogAdapter.java:80-84`）；移植版只写 `'下载失败 code=' + err`（`DownloadManager.ets:111`），UI 不展示该字段（`DownloadsPage.ets:343-348`）。
5. **自动下载缓存阈值语义**：上游 `getEpisodeCacheSize()`（`UserPreferences.java:566-568`）按**集数**且含 `-1` 无限档；移植版 `getEpisodeCacheCount()`（`UserPreferences.ets:178-185`）默认 50、无无限档，判定是"已下载数 ≥ limit 即整体停止"（`AutoDownloadService.ets:44-47`），非上游的按 Feed 分摊。另：`UserPreferences.ets:85-87` 的 `getEpisodeCacheSizeMb()` 保留但**全库无调用**。
6. **自动清理算法阈值**：上游 9 档（`arrays.xml:201-211`：-3 保留收藏 / -1 保留队列 / 0 听完即删 / 12、24、72、120、168 小时后 / -2 永不），由 `AutomaticDeletionPreferencesFragment.java:66-91` 动态生成文案；移植版只有布尔 `prefAutoDelete`（`PlaybackOrchestrator.ets:85-89`）叠加每 Feed 4 档，**无时间阈值、无收藏/队列保留策略**。
7. **定时刷新最小间隔**：上游最小档 60 分钟（`arrays.xml:60-69`）；移植版 `WorkSchedulerManager.ets:8,12` 用 `Math.max(2h, interval)` 硬抬到 2 小时，输入侧另限 ≥120（`SettingsPage.ets:616`）。同时 `networkType: NETWORK_TYPE_WIFI`（`:17`）强制 WiFi，忽略上游 `prefMobileUpdateTypes.feed_refresh`。
8. **定时刷新生命周期**：上游每次 `MainActivity` 启动都 `restartUpdateAlarm`（`MainActivity.java:216`）；移植版只在设置页点"应用"时 `workScheduler.startWork`（`SettingsPage.ets:619`），`EntryAbility.ets` 无调用——**重装/清数据后调度不会自动重建**。
9. **默认值相反的两处**：`prefEnableAutoDownloadOnBattery` 上游 **true**（`preferences_autodownload.xml:22-25`、`UserPreferences.java:578-580`）vs 移植版 `prefAutoDownloadChargingOnly` **false**（`UserPreferences.ets:168-175`）；`prefDeleteRemovesFromQueue` 上游 **false**（`UserPreferences.java:452`）vs 移植版 **true**（`UserPreferences.ets:196-198`）。
10. **取消下载不解除自动下载**：上游 `CancelDownloadActionButton.java:35-36` 显式 `item.disableAutoDownload()` + `DBWriter.setFeedItem`；移植版 `DownloadManager.remove()`（`:141-158`）只清任务与文件，`item.autoDownloadEnabled` 不变，下次刷新会被 `AutoDownloadService` 重新拉起。
11. **时间显示**：上游日志用相对时间（`DownloadLogAdapter.java:63-64`），移植版用 `toLocaleString()`（`DownloadsPage.ets:354`）。
12. **刷新并发与分页**：移植版 `refreshAll` 串行、每 Feed 最多 5 页（`RefreshService.ets:17,34-51,78-94`），无并发；上游（未检出）由 Worker 并发调度。

## 移植版独有

- `pages/StoragePage.ets:222-239` 存储页（按订阅占用汇总 + 总量卡）。上游无对应独立页面（其"按订阅下载量"在 `ui/statistics/downloads/DownloadStatisticsFragment.java:63-89`，且只读）。
- `StoragePage.ets:241-252` 按订阅删除下载、`:254-268` 清空全部下载（含确认弹层 `:179-211`）。
- `SettingsPage.ets:640-643` 图片缓存清理入口（`ImageCache.clearCache`），上游由 Glide 模块隐式管理、无用户入口。
- `UserPreferences.ets:104-111` `prefEpisodeNotification` 全局新单集通知开关（上游只有每 Feed 开关）。
- `AutoDownloadService.ets:68-86` 网络/电量检测失败时放行并记日志的兜底策略。
- `DownloadManager.ets:64,109,148-152` 显式清理残留分片文件（取消/失败/中断），并注明 `request` 不删已落盘部分文件。
- `DownloadsPage.ets:174-211` 下载行长按菜单（暂停/继续 + 取消下载）；上游取消入口在列表主按钮（`CancelDownloadActionButton`）。
- `FeedDetailPage.ets:236-266` 流播前移动网络二次确认（`prefStreamConfirmMobile`，`UserPreferences.ets:205-212`），语义上对应上游 `DownloadActionButton.java:66-88` 的下载确认。

## 存疑/需进一步核实

1. **上游 `AutomaticDownloadAlgorithm` 的判定顺序与每 Feed 上限**——`net/download` 未检出；本文对自动下载算法的描述依据 `AutoDownloadPreferencesFragment.java:11`、`UserPreferences.java:566-580` 与偏好项推断，可能与实际实现有出入。
2. **`DownloadService` 的并发/重试/暂停实现**——`net/download:service` 未检出；"无并发控制、无重试"是相对移植版现状的推断，上游真实行为需检出该模块后确认。
3. **`DBWriter.deleteFeedMediaOfItem` 是否联动队列**——`storage:database` 未检出；移植版在 `PlaybackOrchestrator.ets:93-95` 手动实现"删除移出队列"，上游对应逻辑位置未验证。
4. **`DatabaseExporter` / `OpmlBackupAgent` / `AutomaticDatabaseExportWorker` 的格式与触发频率**——`storage:importexport` 未检出，本文只确认 UI 入口与 `AndroidManifest.xml:35` 的备份代理声明。
5. **`prefShowDownloadReport`（下载错误通知开关）**——`preferences_notifications.xml:7-12` 存在，`UserPreferences.java:59,368` 有 getter；移植版无对应实现，但该开关的消费点在 `net/download`（未检出），行为边界无法确认。
6. **上游 `prefEpisodeCacheSize` 默认值冲突**：XML 为 `25`（`preferences_autodownload.xml:15`）而 `UserPreferences.java:567` 为 `20`。移植版 50 是否对应某个上游版本，需核对基线 commit。
7. **移植版 `getMobileUpdateAllowed()`（`UserPreferences.ets:56-59`）无调用点**——确认是死代码还是预留接线（如 `HttpClient` 的移动网络门控）。
8. **`IDLE` 状态行的可见性**：`DownloadManager.getStatus()` 返回 `IDLE`，而 `DownloadsPage.ets:266-268` 过滤 `DONE/REMOVED/FAILED`——`IDLE` 行会出现在进行中列表且进度为 0，是否会造成"任务短暂消失/残留"体验问题需真机验证。
9. **`prefDownloadsButtonAction` 与 `prefStreamOverDownload` 是否应接入 `FeedDetailPage` 主按钮**——目前两者仅存在于设置页（`SettingsPage.ets:103-107`），未参与 `:383-400` 决策，属功能缺口还是有意简化需产品侧确认。
10. **`prefEnableAutoDlQueue` 在移植版的等价语义**：上游该开关控制"仅对已入队单集自动下载"；移植版 `QueueEngine` 是否已有等价路径未核实。
