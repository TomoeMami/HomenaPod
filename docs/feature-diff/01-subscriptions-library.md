# 「订阅与内容库」域：上游 AntennaPod vs 鸿蒙移植版 逐项功能对比

- 上游：`antenna-repo`（sparse checkout 仅 `app/src/main`、`ui/`、`storage/preferences`；`model/`、`parser/`、`net/`、`storage/database`、`storage/importexport` **未检出**）
- 移植版：`antennapod-harmony/entry/src/main/ets`（97 个 .ets）
- 证据写法 `文件:行`；上游路径省略 `antenna-repo/`，移植版路径省略 `antennapod-harmony/entry/src/main/ets/`
- 状态：`✅ 对齐`、`🔸 简化/替代`、`⬜ 缺失`、`➕ 移植版独有`

## 结论摘要

1. **添加/订阅链路缺「确认与预览」整段**：移植版点「订阅」即落库返回（`pages/AddFeedPage.ets:351-374`）；上游先以 `STATE_NOT_SUBSCRIBED` 落库、进剧集列表预览、再点 `butSubscribe`（`ui/screen/onlinefeedview/OnlineFeedViewActivity.java:292-312` + `ui/screen/feed/FeedItemlistFragment.java:534,548-557`）。
2. **订阅页「过滤/排序」菜单是死路**：两项都跳 `FeedSettingsPage(feedId:0, focus:…)`（`pages/SubscriptionsPage.ets:203-210`），而该页只读 `feedId`（`pages/FeedSettingsPage.ets:513-519`），`FeedRepository.getById(0)` 无记录（`db/repositories/FeedRepository.ets:46-57`）→ 页面显示「订阅失败」（`FeedSettingsPage.ets:63-67`）。上游是两个独立对话框（`ui/screen/subscriptions/SubscriptionsFilterDialog.java:42-84`、`FeedSortDialog.java:19-39`）。
3. **标签（tags as folders）退化为逗号字符串 + 子串匹配**：标签由 `feed.feedTags` 逗号切分（`SubscriptionsPage.ets:361-381`），筛选用 `indexOf`（:376-379）→ 标签 `Tech` 会命中 `Technology`；上游是 `NavDrawerData.TagItem` 精确包含（`SubscriptionFragment.java:391-411`），另有 `TAG_ROOT`/`TAG_UNTAGGED` 与重命名/删除标签菜单（`SubscriptionTagAdapter.java:70-74,104-114`、`TagMenuHandler.java:22-41`）。
4. **多选批量与归档 Feed 完全缺失**：`FeedMultiSelectActionHandler.java:43-70` 的 9 类批量动作、`Feed.STATE_ARCHIVED` 归档页（`SubscriptionFragment.java:184-196,283-295`、`RemoveFeedDialog.java:81-84,161-168`）在移植版均无实现；`Feed.hide` 字段虽入库（`model/Feed.ets:115`；`FeedRepository.ets:98,149`）但无任何 UI/状态语义。
5. **单集列表被压缩成「3 个硬编码 chip + 6 项排序 + 5 项长按菜单」**：上游是 6 组可持久化过滤（`ItemFilterDialog.java:42-74` + `FeedItemFilterGroup.java:7-18`）、8 维排序 + 保持排序（`ItemSortDialog.java:30-31,43-50`）、12 项上下文菜单（`res/menu/feeditemlist_context.xml:3-62` + `FeedItemMenuHandler.java:76-131`）；移植版对应 `pages/FeedDetailPage.ets:78-103`、:438-443、:567-603，且 `model/FeedItemFilter.ets` **全仓无调用点**。
6. **单集详情页只接到收件箱、仍无分页**：收件箱单击进新增的单集详情页（`pages/EpisodeDetailPage.ets`，第 52 轮，含换行正确的纯文本正文 + 时码可点），其余列表单击仍是直接播放（`FeedDetailPage.ets:387-389`），播放页保留纯文本弹层（`pages/PlayerPage.ets`，同样已修换行/时码）；上游 `ItemFragment` 用 WebView 渲染经 `ShownotesCleaner` 处理的内容（`ui/screen/episode/ItemFragment.java:252-255,432-434`），另有左右滑动换集（`ItemPagerFragment`）与 `PlainTextLinksConverter` 的网址链接化未做。上游每页 150 条（`FeedItemlistFragment.java:88`），移植版一次全量（`EpisodeRepository.ets:44-64`）。
7. **Feed 设置覆盖 11/15 项，缺 3 项**：缺「编辑 Feed URL」（`EditUrlSettingsDialog.java:28-87`，15 秒确认倒计时）、「重连本地文件夹」（`FeedSettingsPreferenceFragment.java:295-308,369-403`）、「Feed 信息页」（`FeedInfoFragment.java:154-280`）；且移植版是统一「保存」按钮（`FeedSettingsPage.ets:540-560`），上游每项即时写库（`FSPF:181-308`）。
8. **OPML 双向可用但丢反馈与元数据**：导入逐条订阅、失败只计数（`pages/OpmlPage.ets:280-304`），上游弹含灰色详情的错误框（`activity/OpmlImportActivity.java:248-271`）；导出文件名写死 `homenna-opml.xml`、无日期戳/mimeType（`OpmlPage.ets:306-328` vs `ui/screen/preferences/ImportExportPreferencesFragment.java:67-68`）。
9. **搜索只保留 iTunes 一路、无去抖**：`net/Discovery.ets:12-30` 仅 iTunes（`limit=30`），fyyd/PodcastIndex 置灰（`AddFeedPage.ets:252-299`）；无 1500ms 去抖（上游 `ui/screen/SearchFragment.java:73`），从订阅详情进入时传入的 `feedId` 被忽略（`FeedDetailPage.ets:198` vs `SearchPage.ets:191-195`）。
10. **Inbox 语义不等价**：移植版 = 全库未播放（`EpisodeRepository.ets:356-371`，`read=0`），上游 = 新标记集合 `FeedItemFilter(NEW)`（`ui/screen/InboxFragment.java:57-59`）→ 未播放但已看过的单集在移植版会一直留在 Inbox。

## 逐项对比表

### 1. 添加 / 订阅

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 添加页 6 行入口 | `ui/screen/AddFeedFragment.java:95-127`；`res/layout/addfeed.xml:96-148` | `pages/AddFeedPage.ets:198-322` | 🔸 | 6 行都在，但「本地文件夹」「fyyd」「Podcast Index」置灰不可点（:199-221、:252-299） |
| 顶部合并搜索框 | `AddFeedFragment.java:102-105`；`addfeed.xml:67-82` | `AddFeedPage.ets:47-61,337-349` | ✅ | 语义一致：`http(s)://` 直接进 URL 输入，否则进在线搜索 |
| Add-by-URL 输入 + 校验 | `AddFeedFragment.java:147-195`（`Patterns.WEB_URL`:188-191） | `AddFeedPage.ets:99-192,377-385` | 🔸 | 移植版是常驻可折叠卡片而非对话框；校验为正则+主机名含点，比 `WEB_URL` 宽 |
| 剪贴板自动预填 | `AddFeedFragment.java:172-179` | 无 | ⬜ | 移植版不读剪贴板 |
| 私有 Feed 认证 | `OnlineFeedViewActivity.java:274-290,503-524`（401 后弹框） | `AddFeedPage.ets:127-161`；`services/FeedFetcher.ets:12-16` | 🔸 | 移植版在添加卡片内联开关，Basic 头仅随该请求发送 |
| Feed 预览与确认订阅 | `OnlineFeedViewActivity.java:292-312,363-374`；`FeedItemlistFragment.java:534,548-557` | 无 | ⬜ | 订阅成功即 `router.back()`（`AddFeedPage.ets:364-368`） |
| HTML 自动发现 | `ui/screen/onlinefeedview/FeedDiscoverer.java:48-68`；`OnlineFeedViewActivity.java:338-361,438-491` | `services/FeedFetcher.ets:25-34` | 🔸 | 移植版实现存在但**无调用点**；只匹配 `type` 不校验 `rel`，无相对 URL 解析、无「单候选跳过对话框」（上游 :462-467） |
| 网页/非 feed 拦截 | `OnlineFeedViewActivity.java:315-328` | `parser/FeedSanitizer.ets:5-13` | ✅ | 都识别 HTML 页面并报错 |
| 错误详情与「编辑 URL 重试」 | `OnlineFeedViewActivity.java:384-411,413-432` | `AddFeedPage.ets:163-174,369-371` | 🔸 | 移植版只显示一行 `error.message` |
| 已订阅去重 | `OnlineFeedViewActivity.java:233-253` | `services/SubscriptionService.ets:16-20` | ✅ | 都按 `downloadUrl` 查重后复用 |
| 添加本地文件夹 | `AddFeedFragment.java:119-126,239-267` | `AddFeedPage.ets:199-221`（置灰） | ⬜ | 移植版无本地文件夹订阅能力 |
| HTTP 缓存（etag/last-modified） | 未检出（全仓 grep 0 命中；`HttpDownloader` 在未检出模块） | `net/HttpClient.ets:40-46,89-135` | ⬜ | 两侧均未见条件请求 |

### 2. 订阅列表 / 标签 / 归档 / 多选 / 重命名

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 列表数据源与排序 | `SubscriptionFragment.java:375-382`（`DBReader.getNavDrawerData(filter, feedOrder, feedCounter, state)`）；排序项 `ui/preferences/.../arrays.xml:213-224`（未播/字母/最近更新/最多播放） | `db/repositories/FeedRepository.ets:10-23`（`ORDER BY custom_title, title`） | 🔸 | 移植版排序写死，且无排序入口（见「全局排序对话框」） |
| 列数 1–5 + 持久化 | `SubscriptionFragment.java:65,71-76,240-242,302-321`；`res/menu/subscriptions.xml:26-50`；默认 3：`res/values/integers.xml:3` | `pages/SubscriptionsPage.ets:313-326`；`prefs/UserPreferences.ets:280-287` | 🔸 | 上游菜单单选（列表/2/3/4/5）；移植版点一次循环 +1（1→5→1），默认 2（:281，注释却写 3） |
| 瓦片 / 列表行渲染 | `SubscriptionViewHolder.java:43-86` | `SubscriptionsPage.ets:224-311` | ✅ | 封面+计数胶囊+失败图标；列数=1 走列表行（:139-150） |
| 点击行为 | `SubscriptionsRecyclerAdapter.java:107-114` | `SubscriptionsPage.ets:267-269,305-307` | ✅ | 都进入单订阅剧集列表 |
| 长按行为 | `SubscriptionsRecyclerAdapter.java:100-106` + `SubscriptionFragment.java:149-150,199` | `SubscriptionsPage.ets:270-272,308-310` | 🔸 | 上游长按=进多选批量；移植版长按=打开该订阅设置 |
| 多选批量动作 | `FeedMultiSelectActionHandler.java:43-70`；`res/menu/nav_feed_action_speeddial.xml:3-55`；可见性 `FeedMenuHandler.java:22-42`；计数 `ui/SelectableAdapter.java:200-202` | 无 | ⬜ | 移植版仅 `pages/QueuePage.ets:35,451-568` 有队列多选 |
| 订阅过滤对话框 | `SubscriptionsFilterDialog.java:42-84`；`SubscriptionsFilterGroup.java:7-16`（计数器>0/自动下载/保持更新/新集通知） | 无 | ⬜ | 菜单跳 `feedId=0` 设置页（`SubscriptionsPage.ets:203-206`） |
| 全局订阅排序对话框 | `FeedSortDialog.java:19-39` | 无 | ⬜ | 同上（`SubscriptionsPage.ets:207-210`） |
| 计数器显示模式 | `FeedCounterDialog.java:16-37`；选项 `arrays.xml:226-239`（收件箱/未播/已下载/已下载未播/无） | 无 | ⬜ | 移植版只显示剧集总数（`SubscriptionsPage.ets:236-244,291-295`） |
| 归档 Feed | `SubscriptionFragment.java:184-196,283-295`；`RemoveFeedDialog.java:81-84,161-168`；搜索用 `FeedItemFilter.INCLUDE_ARCHIVED` :283-285 | 无 | ⬜ | 无归档页、无「归档/恢复」动作、无「显示归档」入口 |
| 标签胶囊行 | `SubscriptionTagAdapter.java:68-97`；`SubscriptionFragment.java:207-229,431-458` | `SubscriptionsPage.ets:66-92,361-386` | 🔸 | 缺 `TAG_ROOT`/`TAG_UNTAGGED`（上游 :70-74），无「未标记」桶 |
| 标签筛选语义 | `SubscriptionFragment.java:391-411` | `SubscriptionsPage.ets:376-379` | 🔸 | 移植版 `feedTags.indexOf(activeTag)>=0` 是子串匹配，非精确成员判定 |
| 标签重命名 / 删除 | `SubscriptionTagAdapter.java:104-114`；`TagMenuHandler.java:22-41`；`RenameFeedDialog.java:28-31,64-71` | 无 | ⬜ | 移植版标签不可重命名/删除 |
| 标签编辑对话框 | `ui/screen/feed/preferences/TagSettingsDialog.java:55-63,140-149,151-160` | `FeedSettingsPage.ets:219-222,545` | 🔸 | 移植版只能手输逗号分隔字符串；无交集计算、无芯片、无补全、无校验（上游 :141 拒绝空/重复/UNTAGGED） |
| 重命名订阅 | `RenameFeedDialog.java:46-61`（`setCustomTitle` + reset） | `FeedSettingsPage.ets:214-217,544` | 🔸 | 移植版是设置页内文本框 + 保存，无独立对话框、无 reset |

### 3. OPML 导入 / 导出

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 入口 | `AddFeedFragment.java:110-117`；`ImportExportPreferencesFragment.java:87-94` | `AddFeedPage.ets:302-322`；`pages/SettingsPage.ets:218-219` | ✅ | 添加页 + 设置页两个入口都在 |
| 文件选择与编码 | `OpmlImportActivity.java:226-235`（`BOMInputStream` 判编码） | `OpmlPage.ets:254-277`（`util.TextDecoder` 默认） | 🔸 | 移植版不处理 BOM/非 UTF-8 |
| 多选列表 + 全选/取消 | `OpmlImportActivity.java:71-87,167-201` | `OpmlPage.ets:103-141,190-206` | ✅ | 默认都不勾选（上游仅菜单触发 `selectAllItems`:197-201；移植版 `selected:false` :343） |
| 逐条导入 | `OpmlImportActivity.java:113-127` | `OpmlPage.ets:280-304` | ✅ | 都逐条写入；移植版复用 `SubscriptionService.subscribe` |
| 导入失败报告 | `OpmlImportActivity.java:248-271` | `OpmlPage.ets:291-293`（`Logger.warn` + 计数） | 🔸 | 移植版不告知哪些条目失败 |
| 嵌套 outline / 文件夹→标签 | `OpmlImportActivity.java:121-125`（只取 xmlUrl/text；`OpmlReader` 未检出） | `OpmlPage.ets:330-358`（只取 xmlUrl/text/title） | ✅ | 两侧都丢弃嵌套结构（上游是否保留未核实） |
| 导出触发/文件名/类型 | `ImportExportPreferencesFragment.java:67-68,125-130,285-307`（`antennapod-feeds-yyyy-MM-dd.opml`、`text/x-opml`） | `OpmlPage.ets:306-328`（固定 `homenna-opml.xml`） | 🔸 | 无日期戳、无 mimeType、无分享动作（上游 `showExportSuccessSnackbar`:222-236） |
| 导出内容 | `ImportExportPreferencesFragment.java:358-365`（`OpmlWriter.writeDocument(DBReader.getFeedList())`） | `services/OpmlService.ets:16-26` | ✅ | 字段一致（text/title/type/xmlUrl/htmlUrl）；移植版标题写死 `Homenna Podcast Subscriptions`（:17） |
| 设置页 OPML 分类 | `ui/preferences/src/main/res/xml/preferences_import_export.xml:24-33` | `SettingsPage.ets:218-219` | ✅ | 都是单个入口项 |

### 4. 单集列表 / 排序 / 过滤

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 分页（每页 150 + 触底加载） | `FeedItemlistFragment.java:88,222-229,365-378,655`；`EpisodesListFragment.java:65,260-304` | 无（`EpisodeRepository.ets:44-64` 一次全量） | ⬜ | 移植版无分页；且为每条 item 单独查 media（:57-59，N+1） |
| 「更多内容」页脚（抓 RSS 下一页） | `FeedItemlistFragment.java:173-178,231-243`；`ui/episodeslist/MoreContentListFooterUtil.java:19-43` | 无（自动分页见「移植版独有」） | 🔸 | 上游手动触发抓下一页，移植版在订阅/刷新时自动抓 |
| 顶部过滤 chip | `FeedItemlistFragment.java:515-527,570-575`；`ItemFilterDialog.java:42-74`；`FeedItemFilterGroup.java:7-18`（6 组） | `FeedDetailPage.ets:41,78-103`（all/unplayed/downloaded） | 🔸 | 移植版 3 种硬编码、不落库；上游 6 组（已播/暂停/收藏/有媒体/在队列/已下载）且持久化 |
| 剧集过滤模型 | `FeedItemFilter`（含 `PAUSED`/`QUEUED`/`NEW`/`IS_IN_HISTORY`/`INCLUDE_ARCHIVED`） | `model/FeedItemFilter.ets:5-12`（8 项，**全仓无调用点**） | ⬜ | 移植版有类但未接入任何页面 |
| 排序对话框 | `ItemSortDialog.java:30-31,43-85`（8 维 + 方向箭头 + 保持排序） | `FeedDetailPage.ets:430-479`（6 项） | 🔸 | 缺 按订阅名/文件大小/文件名/随机/智能乱序；无「保持排序」开关 |
| 排序持久化与实现 | `FeedPreferences`/`SingleFeedSortDialog.java:68-72`（`DBWriter.setFeedItemSortOrder`，未检出） | `FeedDetailPage.ets:784-796`；`utils/SortUtils.ets:8-31` | 🔸 | 移植版按 feed 存，但排序在内存做（`EpisodeRepository.ets:60-63`） |
| 行渲染 | `ui/episodeslist/EpisodeItemViewHolder.java:69-111,157-174` | `components/EpisodeRow.ets:35-152` | ✅ | 封面/状态图标行/两行标题/进度行/48vp 次级操作；已播整行 0.5 透明（:143） |
| 行点击 | `EpisodeItemListAdapter.java:88-104`（进单集详情） | `FeedDetailPage.ets:387-389`（直接播放）；**收件箱已改为进详情页**（`InboxView.ets` → `pages/EpisodeDetailPage.ets`，第 52 轮） | 🔸 | 移植版新增了单集详情页，但只有收件箱接上；订阅详情等列表仍是单击即播 |
| 长按菜单 | `res/menu/feeditemlist_context.xml:3-62` + `FeedItemMenuHandler.java:76-131` | `FeedDetailPage.ets:559-619`（5 项） | 🔸 | 缺 跳过本集、移出队列、移出收件箱、重置播放位置、收藏切换、删除单集、多选 |
| 滑动操作 | `FeedItemlistFragment.java:157,656`；`ui/swipeactions/SwipeActions.java:38-44`（12 种动作可配置） | `FeedDetailPage.ets:157-159,408-428` | 🔸 | 移植版固定「标已播 + 收藏」，不可配置 |
| 剧集多选 | `EpisodesListFragment.java:207-234,313-321`；`EpisodeMultiSelectActionHandler.java:41-71` | 无 | ⬜ | 移植版无剧集多选（含「标记以上/以下为已播」） |
| 每 Feed 过滤（含/不含/最短时长） | `ui/screen/feed/preferences/EpisodeFilterDialog.java:28-111`（分钟→秒 :84-103、词条 chip :55-80、`"词"` 拼接 :105-111） | `FeedDetailPage.ets:481-557,808-825`；`model/FeedFilter.ets:15-45` | 🔸 | 移植版三个自由文本框（单位秒），无 chip/radio；匹配为 title 子串（`FeedFilter.ets:27-37`） |
| 订阅头图 | `FeedItemlistFragment.java:152,489-540`；`res/layout/feeditemlist_header.xml:32-85` | `FeedDetailPage.ets:280-352` | ✅ | 156vp 模糊背景+蒙层+124vp 封面+标题/作者+底部 3 图标 |
| 空态 | `FeedItemlistFragment` 无空态视图（grep `emptyView` 0 命中，仅 progressBar :158,658） | `FeedDetailPage.ets:144-150` | ➕ | 移植版补了空态（上游该页没有） |
| 滚动位置恢复 | `FeedItemlistFragment.java:246-249,663`；`EpisodeItemListRecyclerView.java:47-59` | 无 | ⬜ | 移植版不恢复滚动位置 |

### 5. Feed 详情 / Feed 设置

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| Feed 信息页 | `FeedInfoFragment.java:154-243,258-280`（描述/作者/URL/支持链接/统计/分享/访问网站） | 无 | ⬜ | 移植版无独立信息页，头图只有标题+作者 |
| 设置页结构 | `res/xml/feed_settings.xml:2-114`（4 分类 15 键）；`FeedSettingsPreferenceFragment.java:121-308` | `FeedSettingsPage.ets:119-262` | 🔸 | 移植版覆盖 11 项，缺「编辑 URL」「重连本地文件夹」，且无「Feed 信息」 |
| 播放速度 | `FSPF:181,405-449`（滑杆 0.5–4.0x + 使用全局 + 跳过静音） | `FeedSettingsPage.ets:167-170,578-583` | 🔸 | 移植版点击循环预设，无滑杆、无「使用全局」、无跳过静音 |
| 跳过片头/片尾 | `FeedPreferenceSkipDialog.java:14-44`（两个数字输入框，per-feed，maxLength 5） | `FeedSettingsPage.ets:177-185,548-551` | ✅ | 都是 per-feed 秒数数字输入，均无上限校验 |
| 音量适配 | `VolumeAdaptationPreference.java:20-27`；`ui/preferences/.../arrays.xml:30-47`（6 档，不支持时裁剪为 3 档） | `FeedSettingsPage.ets:172-175,585-589`（循环 0/0.75/1.25/1.5） | 🔸 | 移植版 4 档且用倍率而非语义枚举 |
| 保持更新 | `feed_settings.xml:51-55`；`FSPF:246-254` | `FeedSettingsPage.ets:197-200`；`services/RefreshService.ets:35-38` | ✅ | 都是开关；移植版该开关真实影响自动刷新 |
| 剧集通知（依赖 keepUpdated） | `feed_settings.xml:57-63`（`android:dependency="keepUpdated"`）；`FSPF:268-281`（SDK33 权限） | `FeedSettingsPage.ets:202-205` | 🔸 | 移植版无依赖置灰、无通知权限申请 |
| 自动删除 / 新剧集动作 / 自动下载 | `FSPF:214-262`；`feed_settings.xml:65-86` | `FeedSettingsPage.ets:145-158,606-629` | ✅ | 枚举项都能切换（移植版点按循环） |
| 剧集过滤入口可见性 | `FSPF:352-367`（自动下载关闭则隐藏 `episodeFilter`） | `FeedSettingsPage.ets:120-128` | 🔸 | 移植版恒显示；且该行 `onClick` 是 `router.back()`（:123-125） |
| 认证（用户名/密码） | `AuthenticationDialog`；`FSPF:192-213`（改凭据后自动刷新） | `FeedSettingsPage.ets:231-239,546-547` | 🔸 | 移植版两个文本框 + 保存，无显隐按钮、改凭据不刷新 |
| 编辑 Feed URL | `EditUrlSettingsDialog.java:28-87`（15 秒倒计时确认，无 URL 校验） | 无 | ⬜ | 移植版不能修改订阅地址 |
| 重连本地文件夹 | `FSPF:295-308,369-403` | 无 | ⬜ | — |
| 退订 | `FeedItemlistFragment.java:323-325`；`RemoveFeedDialog` | `FeedSettingsPage.ets:245-262,562-576`；`SubscriptionService.ets:36-50` | ✅ | 都删下载文件 + 剧集 + feed 记录 |
| 保存模型 | 每项即时 `DBWriter.setFeedPreferences`（`FSPF:181-308`） | `FeedSettingsPage.ets:540-560` | 🔸 | 移植版为草稿式保存，离开页面不生效 |

### 6. 单集详情（节目简介）

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 单集详情页 | `ItemFragment.java:251-255,432-434`；`res/layout/feeditem_fragment.xml:213`（ShownotesWebView） | `pages/EpisodeDetailPage.ets`（第 52 轮；头部/动作行/正文），入口 = 收件箱单击 | 🔸 | 布局与动作对齐上游（封面+订阅名+标题+时长·日期、播放/下载两个动作、正文）；正文是纯文本降级而非 WebView，且没有左右滑动换集；播放页弹层（`PlayerPage.ets`）保留 |
| Shownotes HTML 清洗 | `ShownotesCleaner.java:36-41,87-106,135-196`（时码链接、`\n`→`<br />`、追加 `<style>`、去 CSS color、`dir=auto`） | `utils/HtmlCleaner.ets`（换行规则）+ `utils/ShownotesText.ets`（时码分段），第 52 轮 | 🔸 | 换行与时码对齐上游；无 CSS 处理、无 WebView、无 `\n`→`<br />`（纯文本下不需要） |
| 时间码可点跳转 | `ShownotesCleaner.java:112-120`；`ItemFragment.java:121-149` | `utils/ShownotesText.ets:segments()` + `components/ShownotesBody.ets`（`Span.onClick` → `PlayerManager.seek`），第 52 轮 | ✅ | 同样按「短时码先试 HH:MM、超过时长改 MM:SS」推断，只在时长内链接化；非当前播放项时提示先播放（上游 `play_this_to_seek_position_message`） |
| URL 自动链接化 | `ui/cleaner/PlainTextLinksConverter.java:19-29,68-116` | 无 | ⬜ | 简介里的网址不可点 |
| HTML→纯文本 | `ui/cleaner/HtmlToPlainText.java:43-53,85-116` | `utils/HtmlCleaner.ets:stripHtml`（第 52 轮补齐 `p`/`h1`~`h5`/`tr`/`dd`/`dt`/`li`/`br`，另加 `div`） | ✅ | 规则与上游 `FormattingVisitor` 对齐（相邻 `<p>` 之间是空行）；不重建 `<a>` 的裸链接 |
| 单集间左右滑动翻页 | `ItemPagerFragment.java:45-127,200-216`（ViewPager2） | 无（仅播放页「下一集」按钮） | ⬜ | — |
| WebView 链接行为/长按菜单 | `ui/view/ShownotesWebView.java:77-84,117-197`（外链一律外部浏览器、长按复制/分享/时码跳转；未启用 JS） | 无 | ⬜ | — |
| 章节 | `ui/screen/chapter/ChaptersFragment.java`（未检出细节） | `PlayerPage.ets:160-161,356-413,643` | 🔸 | 移植版在播放页做成弹层 |

### 7. 搜索 / 发现

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 搜索去抖 | `ui/screen/SearchFragment.java:73,265-278`（1500ms，延迟 750ms） | `SearchPage.ets:198-221` | 🔸 | 移植版无去抖，仅提交/点按钮触发 |
| 搜索范围（全库 vs 单订阅） | `SearchFragment.java:94-122` | `SearchPage.ets:190-196` | 🔸 | `FeedDetailPage.ets:198` 传的 `feedId` 被忽略 → 从订阅详情进入也是全库搜索 |
| 本地剧集搜索 | `SearchFragment.java:447-468`（`DBReader.searchFeedItems`） | `SearchPage.ets:224-247`；`EpisodeRepository.ets:331-353` | 🔸 | 移植版逐订阅 N 次查询后合并、截断 50 条（:26,241-246） |
| 结果分两块（横向 feed + 单集） | `SearchFragment.java:155-181`；`res/layout/search_fragment.xml:46,55` | `SearchPage.ets:114-179` | ✅ | 都是 feed 结果 + 单集结果两段 |
| 在线搜索 provider | `AddFeedFragment.java:95-100`；`ui/discovery/OnlineSearchFragment.java:77-85` | `net/Discovery.ets:12-30`（仅 iTunes，`limit=30`） | 🔸 | fyyd/PodcastIndex 置灰（`AddFeedPage.ets:252-299`）；provider 注册表在 `net/discovery` 未检出 |
| 在线结果订阅 | `OnlineSearchFragment.java:97-100` → `OnlineFeedviewActivityStarter`（先预览） | `SearchPage.ets:116-153,249-262` | 🔸 | 移植版行点击即订阅并返回 |
| 发现页（热门/国家） | `ui/discovery/DiscoveryFragment.java:148-203`；`QuickFeedDiscoveryFragment.java:94-150` | 无 | ⬜ | 移植版无独立发现页 |
| 搜索多选 | `SearchFragment.java:67`（`OnSelectModeListener`） | 无 | ⬜ | — |

### 8. 收藏 / Inbox / 播放历史

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 收藏列表 | `ui/screen/FavoritesFragment.java:21-22,61-71`（`IS_FAVORITE`+`INCLUDE_ALL_FEED_STATES`，跟随全局排序） | `pages/FavoritesPage.ets:109-122`；`db/repositories/FavoritesRepository.ets:34-49` | 🔸 | 移植版固定 `ORDER BY pubdate DESC`，不跟随排序偏好 |
| 收藏滚动位置恢复 | `FavoritesFragment.java:49-57` | 无 | ⬜ | — |
| Inbox 语义 | `InboxFragment.java:57-59,98-108`（`FeedItemFilter(NEW)` + 2 种排序） | `pages/InboxView.ets:160-179`；`EpisodeRepository.ets:356-371`（`read=0`，LIMIT 200） | 🔸 | 上游是「新标记」集合，移植版是「全库未播放」，语义不等价 |
| Inbox 全清 / 排序 | `InboxFragment.java:82-92,115-136`（含「不再询问」）；`InboxSortDialog.java:147` | 无 | ⬜ | 移植版无「全部移出收件箱」、无排序 |
| Inbox 滑动移出 | `ui/swipeactions/RemoveFromInboxSwipeAction.java:35-44` | `InboxView.ets:121-154` | ✅ | 移植版左滑「标记已播」移出（并修复了「渲染即误标已播」缺陷，:136-140） |
| 播放历史 | `ui/screen/PlaybackHistoryFragment.java:28-29,105-114`（`IS_IN_HISTORY`，硬编码 `COMPLETION_DATE_NEW_OLD`） | `pages/HistoryPage.ets:135-156,159-168` | ✅ | 都按最近播放取；清除都重置 position + 历史时间 |
| 历史「继续收听」分组 | 无 | `HistoryPage.ets:73-85,147-148` | ➕ | 移植版额外分组 + 计数胶囊 |
| 收藏/历史的批量操作 | `EpisodeMultiSelectActionHandler.java:41-71` | 无 | ⬜ | — |

### 9. 封面加载

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 封面加载 | `ui/CoverLoader.java:65-92`（Glide，fitCenter/dontAnimate，`fallbackUri`:84-89） | `components/FeedCover.ets:78-91`；`services/ImageCache.ets:11-35` | 🔸 | 移植版自建磁盘缓存（上限 50MB :8），无内存缓存、无缩放、无 fallbackUri 链 |
| 占位 / 失败回退 | `CoverLoader.java:106-130`；`ui/common/.../ImagePlaceholder.java:11-18` | `FeedCover.ets:43-65,88-90` | ✅ | 无图显示标题或图标；加载失败回退原始 URL |
| 缓存策略 | `ui/glide/ApGlideModule.java:34-42`（`DiskCacheStrategy.ALL`，250MB/50MB）；缩放 `ResizingOkHttpStreamFetcher.java:28-29,74-104`（1500px / 1MB，WEBP 降质） | `ImageCache.ets:37-42,62-74` | 🔸 | 移植版超 50MB 时**全删**目录，非 LRU；无解码尺寸/压缩控制 |
| 定制加载器 | `ui/glide/` 8 文件（内嵌封面、生成式占位图、章节图 Range 请求、StackBlur、420 网络策略拦截等） | 无 | ⬜ | 移植版无音频内嵌封面提取、无生成式占位图、无模糊变换（`FeedDetailPage.ets:287` 用 `.blur(12)` 近似） |

## 关键行为差异

1. **订阅页「过滤/排序」进入死路**：`SubscriptionsPage.ets:203-210` 跳 `FeedSettingsPage(feedId:0, focus:…)`；`FeedSettingsPage.ets:513-519` 只读 `feedId`，`FeedRepository.ets:46-57` 查不到 id=0 → 渲染「订阅失败」（`FeedSettingsPage.ets:63-67`）。
2. **长按语义反转**：订阅页长按 = 打开设置（`SubscriptionsPage.ets:270-272,308-310`）；上游长按 = 进多选（`SubscriptionsRecyclerAdapter.java:100-106` + `SubscriptionFragment.java:149-150,199`）。
3. **标签筛选是子串匹配**：`SubscriptionsPage.ets:376-379` 用 `feedTags.indexOf(activeTag)>=0`；上游按 `TagItem` 精确包含（`SubscriptionFragment.java:391-411`）。标签 `Tech` 命中 `Technology`，且大小写敏感。
4. **单集点击 = 直接播放（收件箱除外）**：`FeedDetailPage.ets:387-389`；上游打开单集详情（`EpisodeItemListAdapter.java:88-104` → `ItemPagerFragment` → `ItemFragment`）。第 52 轮已给收件箱接上 `pages/EpisodeDetailPage.ets`，订阅详情等列表未改。
5. **剧集过滤不持久化且只有 3 个硬编码 chip**：`FeedDetailPage.ets:41,78-103`；上游 6 组可持久化（`ItemFilterDialog.java:42-74` + `FeedItemFilterGroup.java:7-18`），移植版 `model/FeedItemFilter.ets` 无调用点。
6. **排序维度缩水 + 内存排序**：`FeedDetailPage.ets:438-443`（6 项）vs `ItemSortDialog.java:43-50`（8 维 + 保持排序 :30-31）；移植版先按 `pubdate` 取全量再内存排序（`EpisodeRepository.ets:60-63`、`SortUtils.ets:8-31`）。
7. **无分页 + N+1 查询**：上游每页 150（`FeedItemlistFragment.java:88`）；移植版 `EpisodeRepository.ets:44-64` 取全表，并逐条查 media（:57-59）。
8. **添加即订阅、无预览**：`AddFeedPage.ets:364`；上游先落 `STATE_NOT_SUBSCRIBED` 预览再订阅（`OnlineFeedViewActivity.java:292-312` + `FeedItemlistFragment.java:534,548-557`）。
9. **自动发现未接线**：`FeedFetcher.ets:25-34` 无调用点 → 输入普通网页 URL 只会被 `FeedSanitizer.ets:5-13` 拒绝，不会尝试发现 feed 链接。
10. **刷新入口都联网刷新全部订阅，但确认策略不同**：上游 `refresh_item` / 下拉刷新都走 `FeedUpdateManager.runOnceOrAsk(...)`（`SubscriptionFragment.java:255-257,178-180`；`runOnceOrAsk` 的询问逻辑在未检出模块）；移植版 `RefreshService.refreshAll()` 无任何确认（`SubscriptionsPage.ets:388-398`、`RefreshService.ets:30-55`），仅在**播放流媒体**时才用 `AutoDownloadService.isMetered()` 做移动网络二次确认（`FeedDetailPage.ets:886-891`）。
11. **设置页「保存」模型**：`FeedSettingsPage.ets:540-560` 统一保存；上游每项即时写库（`FeedSettingsPreferenceFragment.java:181-308`）。
12. **OPML 导入无失败反馈**：`OpmlPage.ets:288-293` 仅计数 + `Logger.warn`；上游弹错误框（`OpmlImportActivity.java:248-271`）。
13. **Inbox 语义不同**：移植版 = 全库未播放（`EpisodeRepository.ets:356-371`）；上游 = `NEW` 标记集合（`InboxFragment.java:57-59`）。
14. **滑动操作不可配置**：移植版剧集行固定「标已播 + 收藏」（`FeedDetailPage.ets:408-428`）；上游 12 种动作可配（`SwipeActions.java:38-44`，`FeedItemlistFragment.java:656` 还按 filter 调整）。

## 移植版独有

1. **添加页内联认证开关**（`AddFeedPage.ets:127-161`）——上游必须先 401 失败再弹认证框（`OnlineFeedViewActivity.java:274-290`）。
2. **订阅/刷新时自动抓取 `rel=next` 后续页（≤5 页）**（`SubscriptionService.ets:28-32`；`RefreshService.ets:17,78-94`）——上游分页 feed 由用户点「加载更多」手动触发（`FeedItemlistFragment.java:173-178`）。
3. **历史页「继续收听」分组 + 计数胶囊**（`HistoryPage.ets:73-85,147-148`）——上游 `PlaybackHistoryFragment.java:105-114` 无分组。
4. **OPML 页无条目时直接给出导入入口**（`OpmlPage.ets:73-100`），并把导入列表做成页内可勾选列表（:103-141）。
5. **订阅页把搜索/刷新做成常驻图标按钮**（`SubscriptionsPage.ets:45-56`）——上游刷新藏在溢出菜单（`res/menu/subscriptions.xml:9-13`）。
6. **订阅页空态**（`SubscriptionsPage.ets:126-138`）与**剧集列表空态**（`FeedDetailPage.ets:144-150`）——上游 `FeedItemlistFragment` 无空态视图。

## 存疑 / 需进一步核实

1. 上游 `model/`、`parser/feed`、`net/`、`storage/database`、`storage/importexport` 未检出 → 订阅 SQL 排序实现、`OpmlReader` 是否保留嵌套/标签、`FeedFilter` 匹配语义、`SortOrder` 枚举值均**未核实**。
2. 上游 HTTP 缓存：本 checkout 内 grep `etag|last-modified` 0 命中，但 `HttpDownloader`/`DownloadRequestCreator` 未检出 → 不能断定上游无条件请求。
3. 移植版 `ImageCache.ets:22` 命中缓存返回裸路径、:30 未命中返回 `file://` 前缀 → 两分支 scheme 不一致，需真机验证 `Image()` 是否都能渲染。
4. 移植版 `SearchPage` 收到 `feedId` 但忽略（`FeedDetailPage.ets:198` vs `SearchPage.ets:191-195`）——有意全库搜索还是漏接线，待确认。
5. `UserPreferences.ets:281` 默认列数 2 与注释「默认 3」（:279）不一致；上游默认值 `res/values/integers.xml:3` 为 3。
6. 移植版三处实现无调用点：`model/FeedItemFilter.ets`、`FeedFetcher.ets:25-34`、`OpmlService.ets:28-63`——未接线还是已废弃，需与维护者确认。
7. 上游 `FeedItemMenuHandler.java:76-95` 的可见性依赖 model 层标记（`isTagged`/`isNew`/`hasTranscript`，未检出）→ 菜单项精确启用条件未核实。
8. 上游 `TagSettingsDialog` 的 `TAG_ROOT`（根文件夹）语义在移植版不存在；移植版「标签」不再是「文件夹」，也没有导航抽屉式文件夹树。
9. 上游 `AllEpisodesFragment`（全局单集总表，含排序/过滤偏好 `UserPreferences.java:900-915`）在移植版无对应页面；该缺口属「单集列表」范畴，需与其它域确认是否已由首页区块覆盖。
