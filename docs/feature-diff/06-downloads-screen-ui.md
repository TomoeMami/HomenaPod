# 06 · 下载界面（下载页）UI 布局与功能 — 上游 vs 鸿蒙移植版逐项对比

> **第 53 轮已按本文决策实施**（用户逐项决定：结构对齐 + 页面级功能全补 + 日志行视觉全对齐 + 进行中行保持 + 数据语义除 F2 外全补 + 文档更新）。
> 各表的「决策」列是待填清单，最终裁决与代码落点见文末「实施记录」。

**基准**
- 上游：`antenna-repo/`（sparse-checkout：`app/src/main`、`ui/`、`storage/preferences`）。
  下载列表与日志的 UI 全在 `app/src/main/java/de/danoeh/antennapod/ui/screen/download/` 与 `app/src/main/res/layout|menu/`，**已检出，结论可直接核对**。
  `net:download:*`、`storage:database` 未检出；本文中标注「(上游 develop 源码核对)」的结论来自通过 `127.0.0.1:7890` 拉取的 `AntennaPod/develop` 对应文件。
- 移植版：`antennapod-harmony/entry/src/main/ets`（`pages/DownloadsPage.ets` 为主）。
- 状态：`⬜ 缺失` / `🔸 简化·替代` / `✅ 对齐` / `➕ 移植版独有`。
- 每条末尾「决策」留空，供逐项填写：**对齐** 或 **保持**。

## 结论摘要

1. **两个"下载页"语义不同**：上游下载页 = **本机已下载单集列表**（可排序/搜索/多选/删除文件管理）；移植版下载页 = **进行中任务 + 下载记录（日志）**。上游的「日志」是另开的底部弹层。
2. **工具栏只剩一个动作**：上游 5 项（搜索 / 日志 / 删除已播放 / 刷新 / 排序），移植版只有「清空历史」。
3. **行布局是"日志行 + EpisodeRow"的混合体**：上游日志行无封面、有 16dp 状态图标、红色原因行、"点按查看详情"提示；移植版共用 `EpisodeRow`（56vp 封面 + 灰色副标题），并额外补了重试钮与失败原因文案（上游对应能力已对齐）。
4. **管理类能力整块缺失**：删除本地文件、删除已播放、多选批量、滑动动作、长按上下文菜单、下拉刷新、排序、搜索在下载页均无入口。
5. **进行中行的呈现与操作是移植版自造**：行内 4vp 线性进度 + 百分比 + 暂停/继续按钮；上游是"48dp 操作钮 + 40dp 进度环 + 取消(X)按钮"，且上游 `DownloadServiceInterface` **没有** pause/resume API（移植版的暂停/继续属独有增强）。
6. **数据语义差异**：上游日志记录 `FEED`/`FEEDMEDIA` 两种类型 + 真实 `DownloadError` 枚举 + 200 条上限；移植版只记 media、`reason` 恒 0、日志无上限。
7. **`docs/feature-diff/03`、`docs/07` 中关于下载页的若干结论已过期**（见文末勘误）。

## 逐项对比表

### A 页面结构与入口

| ID | 上游 | 移植版现状 | 状态 | 建议 | 决策 |
|---|---|---|---|---|---|
| A1 | 「下载页」= 已下载单集列表：`CompletedDownloadsFragment.java:306-343` `DBReader.getEpisodes(0, MAX, FeedItemFilter(DOWNLOADED, INCLUDE_ALL_FEED_STATES), sortOrder)`，并把正在下载的单集按 URL 合并进同一列表（`:316-328`） | `DownloadsPage.ets:74-129`：第一段「进行中任务」（`DownloadManager.getActiveTasks()`）+ 第二段「下载记录」（`DownloadLogRepository.list()`，含成功与失败历史） | 🔸 | **建议对齐**：第二段改为"本机已下载单集"（可管理），日志另开弹层；否则"下载管理"能力无落点 | |
| A2 | 日志是独立底部弹层 `DownloadLogFragment`（`download_log_fragment.xml`：自带 56dp 工具栏 + Clear history；空态 `no_log_downloads_*`），从下载页溢出菜单进入（`CompletedDownloadsFragment.java:176-178`） | 日志与进行中任务同页两段 `DownloadsPage.ets:74-129` | 🔸 | 若做 A1 则**建议对齐**（拆出日志弹层）；否则**保持** | |
| A3 | 下载页是**顶层导航目的地**：抽屉项顺序前 4 进底栏、其余进 More 弹窗（`ui/screen/drawer/BottomNavigation.java:47-64`），另有 `DOWNLOADS` 深链（`MainActivity.java:795-797`） | 底栏固定 4 页签 + More（`Index.ets:87-154`）；下载页是 push 子页（`Index.ets:171-178`、`:216-218`），带返回箭头 | 🔸 | **保持**（底栏可定制是上游整块能力，见 07 文档） | |
| A4 | 无分区标题、无计数 | 两段 `SectionHeader` + 计数胶囊（`DownloadsPage.ets:76-81`、`:99-104`；`SectionHeader.ets:38-49`） | ➕ | **保持** | |
| A5 | 第二段若为下载页 = 文件仍在的单集；日志标题为 "Download log"（`downloads_log_label`） | 第二段标题 "Completed"（`downloads_section_completed`），内容是含失败的完整历史；`downloads_active_title`("Active downloads")、`downloads_history_title`("Download history") 两个字符串已定义但**全库未使用** | 🔸 | **建议对齐文案**（改用 Download history / Download log）；若 A1 落地则随之调整 | |

### B 标题栏与菜单

| ID | 上游 | 移植版现状 | 状态 | 建议 | 决策 |
|---|---|---|---|---|---|
| B1 | 工具栏两枚常驻图标 + 3 项溢出：搜索 `action_search`、日志 `action_download_logs`、删除已播放、刷新、排序（`res/menu/downloads_completed.xml:7-31`；`CompletedDownloadsFragment.java:172-205`） | 只有 trash「清空历史」一项，且仅当有记录才渲染（`DownloadsPage.ets:55-64`） | ⬜ | **建议对齐**（至少补刷新、删除已播放、排序；搜索可评估） | |
| B2 | 「清空历史」在日志弹层工具栏（`res/menu/download_log.xml:6-11`，always） | 在下载页 AppBar（`DownloadsPage.ets:55-64`） | 🔸 | **保持**（融合架构下位置合理；且两端都无二次确认，行为一致） | |
| B3 | 日志上限 200 条：`DBReader.DOWNLOAD_LOG_SIZE = 200`（(上游 develop 源码核对)） | `SELECT * FROM DownloadLog ORDER BY completion_date DESC` 无 limit（`DownloadLogRepository.ets:10-12`） | ⬜ | **建议对齐**（查询加 limit 或写入时裁剪） | |
| B4 | 工具栏长按彩蛋：先 `scrollToPosition(5)` 再 `smoothScrollToPosition(0)`（`CompletedDownloadsFragment.java:93-97`） | 无 | ⬜ | **保持**（趣味项） | |
| B5 | 溢出「搜索」→ `SearchFragment`（全局搜索） | 下载页无搜索入口（应用有 `pages/SearchPage.ets`） | ⬜ | **建议对齐**（成本低：push SearchPage） | |

### C 列表与行布局

| ID | 上游 | 移植版现状 | 状态 | 建议 | 决策 |
|---|---|---|---|---|---|
| C1 | 日志行 `downloadlog_item.xml`：左 16dp 状态图标 + 单行标题 + 状态行 + 红色原因行 + "点按查看详情" + 右侧 48dp 次级操作 | 日志行复用 `EpisodeRow`：56vp 封面 + 标题 + 状态行 + 原因副标题 + 右侧重试钮（`DownloadsPage.ets:178-198`） | 🔸 | 跟随 A1/A2 决策 | |
| C2 | 日志行**无封面** | 有 56vp 封面（`DownloadsPage.ets:183`；`EpisodeRow.ets:131-139`；07 文档 #19 已记为替代实现） | ➕ | **建议保持**（视觉一致性） | |
| C3 | 前置图标 16dp：成功 `ic_check`、失败 `ic_error`、`ERROR_PARSER_EXCEPTION_DUPLICATE` 用 `ic_info`（`DownloadLogAdapter.java:73-85`） | 无图标，用文本 `OK`/`FAIL`（`DownloadsPage.ets:451-456`；`download_ok`/`download_fail`） | 🔸 | **建议对齐**（图标 + 文本，成本低） | |
| C4 | 状态行 = 「类型 · 相对时间」：`Media file`/`Feed` + `DateUtils.getRelativeTimeSpanString`（`DownloadLogAdapter.java:55-65`） | 「OK · 2026/9/9 11:04:00」（`toLocaleString()` 绝对时间），无类型前缀（`DownloadsPage.ets:451-463`） | 🔸 | **建议对齐**（相对时间 + 类型前缀） | |
| C5 | 原因单独一行，`14sp`，`?attr/icon_red` 红色（`downloadlog_item.xml:58-64`） | 复用 `EpisodeRow.subtitle`：11fp、`text_tertiary` 灰色（`DownloadsPage.ets:186`；`EpisodeRow.ets:225-232`） | 🔸 | **建议对齐**（错误信息应醒目） | |
| C6 | "Tap to view details." 提示行（`downloadlog_item.xml:66-72`，`download_error_tap_for_details`） | 无 | ⬜ | 与 E2 绑定；做日志详情则**建议对齐** | |
| C7 | 仅当"更早的记录里没有同 id 的成功记录"才显示重试钮（`DownloadLogAdapter.java:90-96` `newerWasSuccessful`） | 所有失败行都显示重试钮（`DownloadsPage.ets:187`）→ 已重试成功的旧失败行仍可点重试 | 🔸 | **建议对齐** | |
| C8 | 重试动作按类型分流：feed → `FeedUpdateManager.runOnce(feed)`；media → `DownloadActionButton.onClick`（含移动网络确认 + 300s bypass + "正在下载"提示）（`DownloadLogAdapter.java:98-120`；`DownloadActionButton.java:49-90`） | 只有 media：直接 `DownloadManager.startDownload`，无移动网络确认、无提示（`DownloadsPage.ets:250-263`） | 🔸 | **建议对齐**（至少补移动网络确认与提示） | |
| C9 | 进行中行的操作钮 = **取消下载**（`CancelDownloadActionButton`，`ic_cancel`；`ItemActionButton.java:49-50`）；上游无 pause/resume API（(上游 develop 源码核对) `DownloadServiceInterface.java`） | 操作钮 = 暂停/继续（`pause_fill`/`play_fill`，`DownloadsPage.ets:159`），取消藏在长按弹层 | ➕/🔸 | **建议保持增强**，可评估再加"取消"按钮 | |
| C10 | 进度用 40dp `CircularProgressBar` 套在 48dp 操作钮外圈，总大小未知时虚线等待态（`secondary_action.xml:24-29`；`EpisodeItemViewHolder.java:141-152`）；行内进度条只表示**播放位置** | 行内 4vp 线性进度条 + 百分比占 `durationText` 位 + 尺寸占 `positionText` 位；无进度环（`DownloadsPage.ets:155-158`；`EpisodeRow.ets:234-257`） | 🔸 | 二选一：**保持**（信息更直观）或对齐进度环 | |
| C11 | 已下载行次级操作 = 删除文件（`DeleteActionButton`，`CompletedDownloadsFragment.java:369-377`）；`prefDownloadsButtonAction=true` 时改为播放 | 下载页**无任何"删除本地文件"动作**（`clearMediaFile` 只在首页管理下载区块/单集详情/订阅详情/存储页调用） | ⬜ | **建议对齐**（下载页的核心管理动作） | |
| C12 | 已播行 0.5 alpha、播放中行 `setActivated` 高亮、播放位置实时刷新（`EpisodeItemViewHolder.java:107,139,157-174`；`CompletedDownloadsFragment.java:278-289`） | 日志行不传 `isPlayed`/`playing`，不订阅播放事件 | ⬜ | 跟随 A1 决策 | |
| C13 | 行元信息：发布日 · 大小（自动 B/KB/MB/GB）+ 收件箱/视频/收藏/队列图标（`feeditemlist_item.xml:93-215`；`EpisodeItemViewHolder.java:104-106,176-193`） | 日志行无日期/大小/状态图标；进行中行显示「已下载/总大小」，但 `fileSize()` 只有 KB/MB 两档（`DownloadsPage.ets:432-448`） | 🔸 | 跟随 A1；`fileSize` 补 GB 档可单独做 | |

### D 空态 / 加载 / 文案

| ID | 上游 | 移植版现状 | 状态 | 建议 | 决策 |
|---|---|---|---|---|---|
| D1 | 下载页空态：`No downloaded episodes` + `You can download episodes on the podcast details screen.`（`CompletedDownloadsFragment.java:242-248`）；日志弹层空态：`No download log` + `Download logs will appear here when available.`（`DownloadLogFragment.java:65-69`） | 段1「No active downloads」；段2「No downloads」+「可在播客详情页下载剧集」（后者取自**上游下载页**空态文案）（`DownloadsPage.ets:83-121`） | 🔸 | **建议对齐**段2文案为日志语义 | |
| D2 | 空态图标 `ic_download` 矢量 + 标题 + 说明（`EmptyViewHandler`） | `EmptyState`：同一符号图标 + 96vp 圆形底 + 标题 + 说明（`EmptyState.ets`） | ✅ | **保持** | |
| D3 | 列表加载时居中 `ProgressBar` + 骨架行（`setDummyViews`，`CompletedDownloadsFragment.java:116-117,335`） | 「Loading」文本行（`DownloadsPage.ets:106-113`） | 🔸 | **保持**（或改居中转圈） | |
| D4 | 页内反馈走 Snackbar/Toast（`MessageEvent`，`MainActivity:674-675`） | 页内 message 文本行（`DownloadsPage.ets:66-72`） | ➕ | **保持** | |
| D5 | 列表纵向 padding 8dp、行 `paddingStart 12dp`、行底 `bg_episode_list_item` 圆角 | List 左右 16vp 页面边距 + 行内 12vp 左内边距 + 12vp 圆角卡片底（`DownloadsPage.ets:130-132`；`EpisodeRow.ets:292-298`） | ✅ | **保持** | |

### E 交互

| ID | 上游 | 移植版现状 | 状态 | 建议 | 决策 |
|---|---|---|---|---|---|
| E1 | 下载行单击 → 单集分页详情（`ItemPagerFragment`，可左右翻页，`EpisodeItemListAdapter.java:88-100`）；日志行单击 → 日志详情对话框（`DownloadLogFragment.java:87-93`） | 两种行单击都 → 单集详情页 push（`DownloadsPage.ets:162-167`、`:190-193`） | 🔸 | **建议对齐**（日志行 → 日志详情） | |
| E2 | 日志详情对话框：订阅名 +「打开」按钮跳订阅 + 单集名 + Status（人读原因）+ Technical details + File URL + 点按复制 +「复制到剪贴板」中性按钮（`download_log_details_dialog.xml`；`DownloadLogDetailsDialog.java:61-168`） | 无（点按进单集详情页） | ⬜ | **建议对齐**（若 A2 拆分则与日志弹层一起做） | |
| E3 | 长按行 → 上下文菜单：跳过这一集 / 移出收件箱 / 标记已播·未播 / 加入·移出队列 / 删除 / 收藏 / 重置播放位置 / 分享 / 多选（`feeditemlist_context.xml`；`EpisodeItemListAdapter.java:197-216`） | 进行中行长按 → 底部弹层（暂停·继续 / 取消下载 / 取消）（`DownloadsPage.ets:265-303`）；日志行无长按 | 🔸 | 跟随 A1；进行中行的弹层**保持** | |
| E4 | 多选：长按菜单「多选」+ 标题栏计数 + `FloatingSelectMenu` 批量动作（删除/下载/标记已播·未播/移出队列/分享/收藏/重置位置）+ 全选/以上/以下（`CompletedDownloadsFragment.java:121-130,345-360`；`episodes_apply_action_speeddial.xml`、`multi_select_options.xml`） | 下载页无多选 | ⬜ | 跟随 A1 | |
| E5 | 挂 `SwipeActions(DOWNLOADED)`，按屏偏好取左右动作（默认右=加入队列、左=删除文件）（`CompletedDownloadsFragment.java:113-114`；`ui/swipeactions/*`） | `SwipeScreen.DOWNLOADS='CompletedDownloadsFragment'` 与默认值已定义（`SwipeActions.ets:32,120-121,140`），但只挂在首页「管理下载」区块，下载页未挂 | 🔸 | 跟随 A1（日志行不适合挂删除） | |
| E6 | 下拉刷新 → `FeedUpdateManager.runOnceOrAsk` + `FeedUpdateRunningEvent` 联动转圈（`CompletedDownloadsFragment.java:104-107,301-304`） | 下载页无下拉刷新（`Refresh` 只在首页/队列/收件箱/订阅页） | ⬜ | **建议对齐**（低成本，模式已有） | |
| E7 | 溢出「排序」对话框：日期/时长/标题/大小 × 正反，写 `prefDownloadsSortedOrder`（`CompletedDownloadsFragment.java:396-417`；`ItemSortDialog`） | 入口在设置页「存储」分类一行，点击循环 6 种（`SettingsPage.ets:278-279,417-453`），只作用于首页区块与 `EpisodeRepository.listDownloadedItems`；下载页固定按 `completion_date DESC` | 🔸 | 跟随 A1（做排序对象后再谈是否移回页面） | |
| E8 | 溢出「删除已播放的下载」+ 确认对话框 → 批量删除（`CompletedDownloadsFragment.java:185-203`） | 无 | ⬜ | 跟随 A1 | |
| E9 | 溢出「搜索」→ 全局搜索（同 B5） | 无 | ⬜ | 见 B5 | |
| E10 | 下载页订阅 6 类事件：`EpisodeDownloadEvent`(sticky)/`FeedItemEvent`/`PlayerStatusEvent`/`PlaybackPositionEvent`/`DownloadLogEvent`/`FeedUpdateRunningEvent`(sticky)（`CompletedDownloadsFragment.java:207-304`） | 只订阅 `EPISODE_DOWNLOAD`（DONE/FAILED 时重查日志）+ 进入页面时重载（`DownloadsPage.ets:322-347`） | 🔸 | **保持**（按需再补，避免无谓重载） | |

### F 数据与文案语义

| ID | 上游 | 移植版现状 | 状态 | 建议 | 决策 |
|---|---|---|---|---|---|
| F1 | 日志记录 `FEED`（订阅刷新）与 `FEEDMEDIA` 两类，重试分别走 `runOnce` / 下载（`DownloadLogAdapter.java:57-61,98-120`） | 只写 media（`FEED_FILE_TYPE_MEDIA=2`；`DownloadManager.ets:17,285-290`）：订阅刷新失败**不入日志** | ⬜ | **建议对齐**（刷新失败也入日志） | |
| F2 | `reason` 写真实 `DownloadError` 枚举，`reasonDetailed` 写技术细节（`DownloadResult`） | `reason` 恒 `REASON_USER=0`（`DownloadManager.ets:19`），`reasonDetailed` = `code=N`（失败）或硬编码中文 `'下载完成'`（成功，不上屏） | 🔸 | **建议对齐**（写真实枚举；成功文案走资源） | |
| F3 | 23 种 `DownloadError` → 文案，含 unauthorized/forbidden/not found/certificate/wrong size/blocked/HTML type/duplicate 等（`DownloadErrorLabel.java:15-44`） | 11 种 `@ohos.request` 错误码 → 文案（`DownloadErrorLabel.ets:9-21`；UI 已展示，`DownloadsPage.ets:239-248`） | 🔸 | **保持**（映射粒度受平台错误码限制） | |
| F4 | 文案全部走 `strings.xml`（含 `download_log_title_unknown` 兜底标题） | 成功 detail `'下载完成'` 硬编码中文落库；标题兜底为 `'#'+mediaId`（`DownloadManager.ets:289`；`DownloadsPage.ets:182`） | 🔸 | **建议对齐**（资源化 / 兜底文案） | |
| F5 | 相对时间（同 C4） | 绝对时间（同 C4） | 🔸 | 见 C4 | |

### G 文档勘误

| ID | 说明 | 决策 |
|---|---|---|
| G1 | `docs/feature-diff/03-downloads-automation.md` 第 2 节多条已过期：重试按钮、失败原因文案、日志行点按进详情、长按弹层、取消下载回写 `autoDownloadEnabled=false` **均已实现**；"日志行 onTap 空实现""失败原因全部缺失"不再成立 | 建议更新 |
| G2 | 同文档「存疑」第 8 条「`IDLE` 行会出现在进行中列表」不成立（`statusMap` 只会出现 RUNNING/PAUSED/DONE/FAILED，后三者被过滤；`DownloadsPage.ets:359-383`）；`docs/07-ui-layout-parity.md:177` 对下载页的对齐描述也需按现状（重试/原因/长按菜单）更新 | 已更新（03 存疑 8/9/10、关键差异 10/11、移植版独有；07 §3.6 下载页行 + #18/#19/#20/#31） |

## 实施记录（第 53 轮）

用户裁决：`A1 对齐`、`A2 对齐`、`A3/A4 保持`、`A5 对齐`；`B1/B5/E6/C11/E2/E3/E4/E5/E8 全部实现`；`C3/C4/C5/C6/C7/C2/D1/D3/C13 全部实现`；`C9/C10 保持现状`；`B3/F1/F4/C8 实现`（`F2 不做`，`reason` 仍为 `REASON_USER=0`）；`G1/G2 更新文档`。

代码落点：

- `entry/src/main/ets/pages/DownloadsPage.ets` —— 整页重写：已下载单集列表（含进行中的下载，进行中在前）+ 下拉刷新 + `SwipeActions(DOWNLOADS)` + 长按操作弹层 + 多选动作栏（112vp）+ 排序面板 + 下载记录弹层 + 日志详情对话框 + 删除已播放确认 + 移动网络确认 + 骨架屏加载态。
- `entry/src/main/ets/db/repositories/DownloadLogRepository.ets` —— `MAX_ENTRIES = 200`（B3）。
- `entry/src/main/ets/download/DownloadManager.ets` —— 成功 detail 与标题兜底走资源串（F4）；新增 `logFeedFailure`（FEED 类型日志，F1）与 `getReceivedBytes/getTotalBytes`（行内大小文案）。
- `entry/src/main/ets/services/RefreshService.ets` —— 订阅刷新失败写 FEED 类型日志（F1）。
- `entry/src/main/ets/model/Enums.ets` + `entry/src/main/ets/utils/SortUtils.ets` —— `SIZE_SMALL_LARGE/SIZE_LARGE_SMALL` 与 `sizeOf`（排序面板「大小」类）。
- `entry/src/main/ets/utils/FileSizeUtils.ets`（新增）—— B/KB/MB/GB/TB 自动选档（C13）。
- `entry/src/main/ets/prefs/UserPreferences.ets` + `pages/SettingsPage.ets` —— `prefDownloadsButtonAction`（`getDownloadsButtonPlay`）与「用户界面」开关行（C11 的按偏好改为播放）。
- 三个 `resources/*/element/string.json` —— 新增 34 条资源串（日志弹层/详情对话框/类型与相对时间/移动网络确认/按钮动作开关等）。

验证：`arkts_check` 通过；`build_project`（hvigorw 回退路径）编译通过并产出 `entry-default-unsigned.hap`。

### 模拟器实机验证（phone26 / HarmonyOS 7.0.0(26.0.0)，2026-09-17）

方式：`devecocli emulator start phone26` 启动模拟器 → `hdc install` 安装未签名 HAP → `huitest`/`hdc uiInput` 驱动界面 + `hdc screenshot` 逐屏核对；下载链路用**本机 RSS 源**（`hdc rport` 反向端口转发 + 本地节流 HTTP 服务）构造「正常 / 慢速 / 404 失败」三类单集。

**验证通过**：下载列表（已下载单集 + 时长/大小/封面/已播半透明/排序持久化）、工具栏三动作 + 溢出三项、4 类排序面板与「大小」排序、下载记录弹层（状态图标 + 「媒体文件 · N 分钟前」+ 红色原因行 + 点按提示 + 重试钮显隐）、日志详情对话框（播客/打开/单集/状态/技术细节/文件 URL/复制）、长按操作层（逐项按状态显隐）、多选动作栏与批量删除、滑动删除、行内删除文件、删除已播放（确认框）、下拉刷新（「正在刷新…」+ 转圈）、FEED 类型失败日志 + 重试、媒体失败重试（含移动网络确认 300s 免打扰）、进行中行（下载中/已暂停 + 已下载/总量 + 4vp 进度 + 百分比 + 暂停/继续）、设置页「下载页按钮改为播放」开关生效。全程无新崩溃（faultlog 最后一次 jscrash 为修复前的 13:26）。

**实机发现并修复的 4 个缺陷**（前 3 个是本次改动引入，第 4 个是既有缺陷被新 UI 暴露）：

1. **打开下载记录弹层必崩**（jscrash 9001007）：`time_minutes_ago` 等资源用了 `%d` 占位符而调用方传字符串 → `getStringSync` 抛「placeholder 类型不匹配」，进程被系统杀掉。改为 `%1$s`（与既有 `opened_import_queued` / `queue_selected_count` 同一写法）。
2. **日志行「文件 URL」缺失 / 重试点了没反应**：`EpisodeRepository.getByMediaId` 只查单集行、不查媒体表，`item.media` 恒为 `undefined`。新增 `mediaOf()` 回查 `getMediaByFeedItem`（同时修 `load()` 里进行中行缺媒体导致的进度/操作错乱）。
3. **长按弹层丢了「取消下载」**：改造成上游上下文菜单后，进行中任务只剩行内「暂停/继续」，取消无处可点（相对旧版是功能回退）。为进行中行补回「取消下载」项（`DownloadManager.remove`）。
4. **失败过的单集在进程重启前无法重试**：`DownloadManager.startDownload` 见 `statusMap` 已有键就直接返回，而 `fail` 回调写入的 `FAILED` 永不清除 → 日志重试、订阅页重新下载全部静默失效。改为只挡 `RUNNING/PAUSED`，终态键先删除。

**顺带修正**：`DownloadErrorLabel` 原来按 Android DownloadManager 的枚举顺序写死错误码数值，实机表现为「HTTP 404 失败」被标成「存储空间不足」。改为与 `request.ERROR_*` **运行期常量**比对（同一 `code=8` 现在正确显示为「网络连接错误」兜底）。


