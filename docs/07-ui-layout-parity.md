# 07 · AntennaPod 布局对齐报告（UI layout parity）

- 制定日期：2026-09-09（第 27 轮）
- 上游基线：`AntennaPod/AntennaPod` 分支 `develop`，`app/build.gradle` `versionName "3.12.1"` / `versionCode 3120195`
- 本地克隆：`D:\Git\antennapod-harmony\antenna-repo`（`git clone --depth 1 --filter=blob:none`，sparse-checkout `app/src/main`、`ui`、`storage/preferences`；已在 `.gitignore` 中忽略）
- 对齐原则：**控件保持鸿蒙原生风味**（`SymbolGlyph`、`Text`、`List`、`Grid`、`Toggle`、`Menu`、`Refresh` 等），
  **几何与层级尽量与上游一致**（高度、间距、圆角、封面尺寸、区块顺序、操作位次）。
- **对齐目标是"相对布局"，不是 1:1 复刻**（用户明确要求）：对齐**结构、顺序、层级、操作位次**；
  尺寸只在上游数值与鸿蒙可读性冲突时才偏离，且必须逐条记录（见 §4）。凡"上游是 X dp/sp、本端就用 X vp/fp"
  只是默认取值，不是目标本身。
- 证据链：上游逐文件读数见 `docs/_ref-spec-home-subscriptions.md`、`_ref-spec-queue-episodes.md`、`_ref-spec-player-misc.md`（含 `file:line` 引用）。
- **第 41 轮（队列页专项）**：用户对队列页 26 项差异逐条选择「与上游同步 / 保持当前」，据选择实施并对齐，
  结果见 §3.3、§4 #33–#39、§6（含实机取证与未能复现项）。

---

## 1. 方法

1. `git clone --depth 1 --filter=blob:none` + sparse-checkout 取上游源码，只读不改。
2. 三个并行子代理按屏幕把上游 XML/Java 里的**几何数值**逐条抄录成规范（dp/sp 精确到数值 + 出处行号）。
3. 逐屏比对当前实现，分为三类：
   - **已对齐**：直接改当前实现（本轮主体）。
   - **替代实现**：上游用某控件、鸿蒙无对应物，用原生等价物实现（记录替代方式）。
   - **跳过**：无法在鸿蒙侧合理实现或超出本轮范围（逐条记录理由）。
4. 每轮改动后：`arkts_check` 静态检查 → hvigor `CompileArkTS` 编译 → 模拟器安装 → 截图取证。

---

## 2. 全局外壳与设计令牌

| 项 | 上游 | 本轮实现 | 状态 |
|---|---|---|---|
| 底部导航栏高度 | `64dp`（`main.xml:56`） | `DesignTokens.HEIGHT_TAB_BAR = 64` | 已对齐 |
| 底部导航文字 | `TextBottomNav` = `TitleSmall` + `11sp`（`styles.xml:352`） | `FONT_NAV = 11` | 已对齐 |
| 底部导航项 | 取抽屉可见项前 4 个 + 「More」（`BottomNavigation.java:53-61`），默认序 Home/Queue/Inbox/Subscriptions | 首页 / 队列 / 待处理 / 订阅 / 更多 | 已对齐 |
| 「More」弹出菜单 | `ListPopupWindow`，宽 250dp，锚定底栏右下 | 原生 `Menu` + `MenuItem`（图标 + 文案），锚定「更多」 | 替代实现 |
| 底部导航角标 | 只给 Inbox 显示未读数，`99+` 截断（`BottomNavigation.java:80-83`） | 待处理页签显示 `countNew()`（`read = -1`） | 已对齐 |
| 迷你播放条 | 整行 `64dp`，封面 ≤96dp、标题/作者各 16sp 单行、播放键 52dp、底部 4dp 进度条（`external_player_fragment.xml`） | `MiniPlayer` 重写为同构：64vp、56vp 封面、16fp 双行、52vp 播放键、4vp 进度条、`surface_container` 底 | 已对齐 |
| 首页横滑卡片 | `horizontal_itemlist_item.xml`：128dp 封面 + 圆角 12 + `colorSurfaceContainer` 底 + 48dp 播放圆钮 + 4dp 进度条 + 两行 14sp 标题 + 14sp 日期 | `components/EpisodeCard.ets` 同构（128vp / 12vp / `surface_container` / 48vp / 4vp / 14fp / 14fp） | 已对齐 |
| 剧集列表行 | `feeditemlist_item.xml`：可选拖拽手柄 + 56dp 封面（圆角 8）+ 状态图标行（收件箱/视频/收藏/在队列，12sp）+ 两行 16sp 标题 + 进度行 + 48dp 次级操作 | 新增 `components/EpisodeRow.ets`，首页/队列/待处理/订阅详情共用 | 已对齐 |
| 已播状态 | 整行 `alpha 0.5`（`bg_episode_list_item` 无独立已播 drawable） | `EpisodeRow.opacity(isPlayed ? 0.5 : 1)` | 已对齐 |
| 选中态底色 | `colorSecondaryContainer`（`#C8D8DE` / `#3C4E68`） | 新增 `surface_container_playing`，卡片播放中/选中时使用 | 已对齐 |
| 溢出菜单 | `ActionBar` overflow | 新增 `components/OverflowButton.ets`（`bindMenu` 必须挂在无 `onClick` 的容器上，否则弹不出菜单） | 替代实现 |
| 下拉刷新 | 首页/订阅页 `SwipeRefreshLayout` | 原生 `Refresh` 组件 | 替代实现 |
| 导航抽屉 | `DrawerLayout` + `NavDrawerFragment`，宽 ≤480dp | 未实现（「更多」菜单已覆盖同一批入口；平板上上游本身也隐藏抽屉） | **跳过** |

---

## 3. 逐屏对齐结果

### 3.1 首页 `HomePage.ets`

上游 `HomeFragment` + `home_section.xml` + `horizontal_itemlist_item.xml`。
**第 40 轮已把首页逐项对齐（数据源 + 布局）**，下表为对齐后的状态。

| 上游 | 本轮实现 |
|---|---|
| 区块顺序由 `PrefHomeSectionOrder` / `PrefHomeSectionsString` 决定（对话框里可拖拽排序 + 移入「隐藏」组） | 同两个偏好（`prefHomeSectionOrder` / `prefHomeHiddenSections`）；编辑模式分「显示 / 隐藏」两组，行内上/下移按钮调顺序、开关控制显隐（见 §4 #26） |
| 继续收听：横滑卡片 ×8，**数据源 = `DBReader.getPausedQueue(8)`**（队列内 `position>=1s` 或 30 秒内播过的排最前，含从未播放的入队项） | `EpisodeRepository.listPausedQueue(8)` 逐字对照该 SQL；横滑 `EpisodeCard` ×8，进度条 + 播放中底色；卡片日期用 `pubDate`（上游同） |
| 看新内容：**竖排 2 行** + 未读数胶囊（`99+`）+ 更多→Inbox | 竖排 `EpisodeRow` ×2（`listInboxPage(2)`，即收件箱 `read = -1` 的前两条）+ `SectionHeader.countPill`（`countNew()`，99+ 封顶）+ 更多→待处理页签 |
| 随机惊喜：横滑卡片 ×8 + 乱序按钮 + 更多→Episodes，数据源 = `getRandomEpisodes(8, seed)`（2 年内 / 仅已订阅 / 每订阅 1 集 / 排除 1 小时前未听完 / seed 稳定） | `EpisodeRepository.listRandomEpisodes(8, seed)` 同语义；`HomePage.surpriseSeed` 页面内稳定，点乱序才换；更多→`pages/EpisodesPage` |
| 常听经典：横滑订阅封面 96dp（圆角 16），数据源 = 最近 3 年 `feedTime`、仅 `STATE_SUBSCRIBED`、受统计口径开关影响 | `listStatsByFeed(includeMarked, 3 年前, MAX)` 同语义（时间窗加在 `last_played_time_statistics`）；横滑 `FeedCover` 96vp（圆角 16）+ 标题（见 §4 #22 的字号取舍同源） |
| 管理下载：竖排 2 行，按 `UserPreferences.getDownloadsSortedOrder()` 排序 | `listDownloadedItems(2, 下载排序偏好)`；竖排 `EpisodeRow` ×2 |
| 区块标题：16sp Medium，右侧乱序 / 数字胶囊（1dp 品牌色描边）/「更多」文案 + 24dp 尾随箭头（`padding 12dp×8dp`、`marginStart 16dp`、`marginEnd 8dp`） | `SectionHeader` 同几何（胶囊为实底，见 §4 #10） |
| 行/卡片长按 = 上下文菜单（`FeedItemMenuHandler`：播放 / 队列 / 已播 / 收藏 / 下载…） | 底部操作弹层（同样的动作集合，见 §4 #27） |
| 看新内容 / 管理下载挂 `SwipeActions`（右滑 / 左滑动作按用户设置） | 右滑=加入队列；左滑：看新内容=标记已播、管理下载=删除文件（见 §4 #28） |
| 各 Section 监听 `QueueEvent`/`PlayerStatusEvent`/`PlaybackPositionEvent`/`EpisodeDownloadEvent`/`DownloadLogEvent`/`FeedItemEvent`/`FeedListUpdateEvent` | 首页统一订阅同一批事件；`PLAYBACK_POSITION` 只更新当前播放项的进度条与位置文本，其余整体重载 |
| 标题栏动作：搜索（常驻）+ 溢出（刷新 / 配置首页） | 搜索 + 刷新 + 编辑（配置区块）三个图标动作（见 §4 #29） |
| 欢迎页条件 = 全库单集总数为 0；含 80dp `ic_curved_arrow` 引导箭头 | `EpisodeRepository.countAllEpisodes() == 0`；补 80vp 曲线箭头（`arrow_uturn_down`，见 §4 #30） |
| 区块空状态文案（每区块不同），常听经典不设 | 新增 `home_*_empty` 四条专属文案（中/英/zh_CN），常听经典同样不显示空态 |
| 加载中渲染 dummy 骨架（`setDummyViews`，alpha 0.1） | 仍是空态文案（见 §4 #4） |


### 3.2 订阅页 `SubscriptionsPage.ets`

上游 `SubscriptionFragment` + `fragment_subscriptions.xml` + `subscription_grid_item.xml`。
**第 43 轮按用户逐条选择把订阅页对齐（下表为对齐后状态；逐条证据见 §8）。**

| 上游 | 本轮实现 |
|---|---|
| 订阅页 `SubscriptionsPage.ets` | |
| 3 列网格（`subscriptions_default_num_of_columns` = 3），瓦片 4dp 内边距、圆角 12、elevation 1 | `Grid` + `columnsTemplate('1fr …')`（默认 3 列），瓦片 4vp 内边距、圆角 12 |
| 加载中居中 `ProgressBar`，且加载期间隐藏空态 | 居中 `LoadingProgress`（48vp），加载完成前不渲染空态 |
| 空态：`ic_subscriptions` +「No subscriptions」+ 说明句（**按全局过滤器是否启用**二选一） | `EmptyState`（图标仍为 `sys.symbol.folder`，见 §4 #5）+ `placeholder_subscriptions`；说明句改按 `filterValues` 是否为空判定（对齐 `SubscriptionsFilter.isEnabled()`） |
| 封面 1:1，无图时把标题画在占位底上（`fallbackTitleLabel`，`#55333333` + 白字 + 6dp 内边距） | `FeedCover.fallbackTitle`，同色同内边距（「显示标题」关闭时使用） |
| 计数胶囊：`TextPill`（`#D2404040`、圆角 18、白字 14sp、margin 8dp）在封面右上角；计数用 `NumberFormat.getInstance()` | `pill_on_cover` 同几何；计数按千分位分组（`formatCount`） |
| 计数口径 `FeedCounterDialog` 5 档：**收件箱新单集 / 未播放 / 已下载 / 已下载未播放 / 不显示**，默认「收件箱新单集」 | 居中单选对话框，取值与上游 `FeedCounter.id` 一一对应，默认 1（`read = -1`；新增 `FeedCounter.newCount` 聚合） |
| 刷新失败图标 24dp 在封面右下角（`alignBottom=coverImage`、margin 8dp） | `exclamationmark_circle` 24vp，用整块 `Column` 贴右下角（不再写死距顶 100vp） |
| 瓦片文字内边距随列数（≤3 列 16dp / 4–5 列 8dp）、字号随列数（2 列 16sp / 3 列 15sp / 其余 14sp）、标题 `lines="2"` | 同：`tileTextPadding()` / `tileTitleSize()` + `constraintSize({ minHeight: 行高×2 })` |
| 「显示标题」关闭时标题不上屏、画在封面占位底上（默认关闭） | 默认 `false`（`prefSubscriptionShowTitles`），瓦片下方标题固定 2 行 |
| 标签筛选胶囊行：左右 12dp、4dp 间距、仅存在 ROOT/UNTAGGED 之外的标签时显示 | 横向 `List` + `TagChip`（**显式 `height(44)`**：横向 List 在纵向 Column 里会撑满剩余高度）；集合 = 全部 + **命名标签（字母序）** + **未标记**（存在未标记订阅时）；>20 字符截为 19+… |
| 选中标签胶囊滚动到水平居中（`scrollToPositionWithOffset`） | `tagScroller.scrollToIndex(index, true, ScrollAlign.CENTER)`（索引 0 不滚动） |
| 选中标签持久化（`PREF_LAST_TAG`），标签不存在时回落「全部」 | `prefSubscriptionLastTag` + `validateActiveTag()` |
| 长按标签胶囊 → `nav_folder_context`（重命名 / 删除标签；删除带确认，作用于全部相关订阅） | 长按胶囊弹居中菜单；重命名对话框 + 删除确认框（`tag_delete_confirm`），底层 `FeedRepository.renameTag/deleteTag` |
| 「Filtered」提示行：点击打开过滤器弹层 | 选中标签时点击清除标签（本移植版既有行为）；**仅全局过滤器生效时**点击打开过滤器弹层 |
| 过滤器弹层（`SubscriptionsFilterDialog`）4 组、组内单选、**可再点取消**；重置 / 确认 | 底部弹层保留既有形态（见 §4 #9）；**修掉「只能取消、永远选不上」的开关缺陷**；「计数 > 0」组改按当前计数口径判定（`SubscriptionsFilterExecutor`） |
| 排序 `FeedSortDialog`：居中单选对话框 4 项（计数 / 字母 / 最近更新 / 最多播放） | 居中单选对话框；**计数**=当前计数口径降序、**最多播放**=已播放集数降序、**最近更新**=`MAX(pubdate)`、并列按标题忽略大小写（对齐 `DBReader.getNavDrawerData` 的 comparator） |
| 列数子菜单：`List` / 2 / 3 / 4 / 5 单选（有勾选态） | **原生二级菜单**（`MenuItem({ builder })` + `Menu()`），当前项用 `labelInfo` 打勾 |
| 「显示标题」是勾选项，且列数 = 1 时隐藏 | 同：`labelInfo` 打勾；`columns <= 1` 时不渲染该项 |
| 右下角 FAB 56dp / margin 16dp / 加号；多选时隐藏 | 圆形 `Button` 56vp + margin 16vp，多选时隐藏 |
| 列表模式（列数 = 1）：56dp 封面 + 标题两行 + 纯文本计数（无胶囊） | `listRow` 同构；多选时行首加勾选图标、整行 `primary_container` 底色 |
| 多选（长按进入）：ActionMode「N/M selected」+ 全选·取消全选 / 向上全选 / 向下全选 + 关闭 | 同：多选态标题栏 + 溢出三项 + ✕；选中集合变化只 `notifyDataChange` 对应行（不用 `setData`，避免滚动回顶） |
| 多选瓦片：左上角勾选圈 32dp + 封面顶部 48dp 渐变遮罩 + 选中卡片内缩 12dp（`ValueAnimator` 100ms） | 同：`checkmark_circle_fill` 32vp、`linearGradient` 48vp 遮罩、内缩 12vp（`animateTo` 100ms） |
| 多选动作栏 `FloatingSelectMenu`（112dp 卡片、横向滚动）`nav_feed_action_speeddial`：编辑标签 / 分享 / 全部移出收件箱 / 取消订阅·归档 / 取消订阅·恢复 / 保持更新 / 新单集通知 / 自动下载 / 自动删除 / 播放速度 | 同形态（112vp 卡片 + 横向滚动）；本移植版无归档，第 4 项为「取消订阅」并省略「恢复」；自动下载用开关对话框（本端为布尔字段，上游三态，见 §7） |
| 批量动作后 Snackbar「已更新 N 个订阅」，且所选 ≤1 时退出多选 | 顶部提示行 + `updated_feeds_batch`；所选 ≤1 时退出多选 |
| 编辑标签 `TagSettingsDialog`：所选订阅的**公共**标签胶囊（可移除）+ 新标签输入 + 确认 | 底部弹层同构（胶囊点按移除 +「新标签」输入 + 添加 + 取消/确认），批量写回 `feed_tags` |
| 分享订阅：`ShareUtils.shareFeedLink` | 复制 RSS 链接到剪贴板（本 SDK 无系统分享面板 API，与单集分享同一处理） |
| 事件：`FeedListUpdateEvent` + `FeedItemEvent.unreadStatusChanged` + sticky `FeedUpdateRunningEvent` | `FEED_LIST_UPDATE` + `FEED_ITEM_UPDATE` + 新增 `REFRESH_STATE`；另加 `onVisibleAreaChange` 在页面重新可见时重查库（对齐上游 `onStart → loadSubscriptionsAndTags()`，避免事件在页面不可见时丢失） |
| 滚动位置：`onPause` 保存、重新进入恢复 | 模块内静态 `SubscriptionsScroll.firstIndex` + `onScrollIndex` 记录 + 首屏 `scrollToIndex` |

### 3.3 队列页 `QueuePage.ets`

上游 `QueueFragment` + `queue_fragment.xml` + `feeditemlist_item.xml` + `floating_select_menu.xml`。
**第 41 轮按用户逐条选择把队列页对齐（下表为对齐后状态；逐条证据见 §5）。**

| 上游 | 本轮实现 |
|---|---|
| 标题栏：`Queue` + 搜索 + 溢出（搜索 / 刷新 / 锁定 / 排序 / 清空队列）；其中「锁定队列」是勾选项且「保持排序」开启时隐藏 | 同：溢出菜单去掉本移植版自加的「多选」（改由长按弹层进入），锁定项用 `lock_fill`/`lock_open` 表达勾选态，`keepSorted` 时整项隐藏 |
| 多选态由 ActionMode 承载：标题 `N/M selected` + 溢出「全选·取消全选 / 向上全选 / 向下全选」+ 关闭 | 同：标题栏换为「N/M 已选」+ 全选系列溢出 + ✕；信息条在多选时隐藏（上游 `setVisibility(INVISIBLE)`） |
| 信息条：12sp、`marginTop −12dp`、`"%1$s • %2$s left"` | `queue_info`，12fp、`margin top −12vp`；`timeRespectsSpeed` 开启时剩余时长按每集倍速折算 |
| 空态：`ic_playlist_play` + 「No queued episodes」+ 说明句 +（收件箱有新单集时）「Go to inbox」按钮 | `EmptyState` 同构：`queue_empty_title` / `queue_empty_hint` + `countNew() > 0` 时显示「前往收件箱」跳 `pages/InboxPage` |
| 行：可选拖拽手柄 + 56dp 封面 + 状态行 + 两行标题 + 进度行 + 48dp 次级操作（播放/暂停/下载/取消）+ 40dp 下载进度环 | `EpisodeRow`：**新增播放中 `surface_container_playing` 高亮底**（上游 `setActivated(isCurrentlyPlaying)`）、**恢复右侧 48vp 次级操作与下载进度环**（随 `EPISODE_DOWNLOAD` 实时刷新该行） |
| 「显示剩余时间」开启时行内时长显示 `-剩余`（上游 `shouldShowRemainingTime`） | `durationText` 支持 `-剩余`；剩余为 0 显示 `0:00`（上游 `Converter.getDurationStringLong(0)`） |
| 拖拽排序：手柄 **或封面左半区**起拖；锁定 / 保持排序时手柄 GONE 且禁用 | `EpisodeRow` 手柄与封面左半区（`localX < 28vp`，右半区不接管）都可起拖；锁定 / 多选 / 保持排序时 `showDragHandle=false` |
| 左右滑默认两侧都是「移出队列」，动作可在设置里按屏幕配置 | 默认值对齐上游（`SwipeActions.resolve(QUEUE)`）；划出项由 `SwipeActionButton` 承载（视觉仍为鸿蒙彩色动作块，见 §4 #33） |
| 长按 = `queue_context` + `feeditemlist_context` 上下文菜单：移到顶部/底部、跳过、移出收件箱、标记已播/未播、移出队列、删除、收藏、重置播放位置、分享、多选 | 底部操作弹层，逐项按状态显隐（`canMove` / `canDelete` / `canDownload` / `position≠0` / `isNew` / 播放中）；「多选」进入多选并**选中长按项** |
| 多选动作栏 `FloatingSelectMenu` + `episodes_apply_action_speeddial`（按状态显隐，队列页排除「加入队列 / 移出收件箱」） | 动态项：删除文件 / 下载 / 标记未播放 / 标记已播放 / 移出队列 / 分享（仅单选）/ 加入收藏 / 取消收藏 / 重置播放位置 / 移到顶部 / 移到底部；「清空队列」只留在溢出菜单（上游同） |
| `canMove(queue, selected)`：队首、队尾、连续块、全选、锁定、保持排序都不允许再挪 | `canMoveTop` / `canMoveBottom` 同语义（长按弹层里的顶部/底部判据是长按项本身，与上游 `QueueRecyclerAdapter` 一致） |
| 排序对话框：双列 chip 网格（每类一项、点击翻转升降序、激活项带 ▲/▼）+「Keep sorted」复选框（Random 时强制取消并禁用） | 同：chip 网格 + **播客标题排序** + 保持排序（开启后入队自动排序、锁定项隐藏、拖拽禁用） |
| 刷新：`SwipeRefreshLayout` 下拉 + 菜单项 = `FeedUpdateManager.runOnceOrAsk` | `Refresh` 组件 + 两个入口都走 `RefreshService.refreshAll()`（`AceRefresh` 日志已验） |
| 搜索：队列内检索（`FeedItemFilter(QUEUED)`） | `SearchPage` 支持 `queuedOnly`：标题/占位「队列内搜索」，只查队列内单集、不查在线目录 |
| 移出队列：Snackbar + 「撤销」（插回原位置） | 顶部提示行 + 「撤销」（`QueueEngine.addAt`） |
| 锁定：首次弹确认框（标题 + 警告 + 「不再提示」复选框）；空队列时提示已锁定/已解锁 | 同：`lockDialog` + `prefShowQueueLockWarning` |
| 清空队列：`ConfirmationDialog` 二次确认 | 同：`clearDialog`（复用已有的 `queue_clear_confirm` / `clear_queue_confirmation_msg`） |
| 事件：Queue / FeedItem / EpisodeDownload / PlaybackPosition / PlayerStatus / SpeedChanged | 全部订阅；另加 `SWIPE_ACTIONS_CHANGED` / `PREFS_CHANGED` 让设置页改动即时生效 |
| 滚动位置：`onPause` 保存、队列重新加载时恢复 | `aboutToDisappear` 存 yOffset，冷启动首次加载恢复（`prefQueueScrollOffset`） |


### 3.4 订阅详情 `FeedDetailPage.ets`

上游 `FeedItemlistFragment` + `feeditemlist_header.xml` + `feeditemlist_item.xml`，菜单 `menu/feedlist.xml`。

| 上游 | 本轮实现 |
|---|---|
| 156dp 头图区：封面铺满 + `#80000000` 可读性蒙层 | 同（封面 `blur(12)` 铺满 + `#80000000` 蒙层） |
| 封面 124dp、圆角 16、左边距 16、底边距 24 | `COVER_DETAIL = 124`、圆角 16、同边距 |
| 标题 22sp 白色带阴影 + 作者 14sp 白色 | 同（22fp / 14fp 白色） |
| 底部操作带：`#80000000` 底、148dp 占位后跟 48dp 图标按钮（信息/过滤/设置） | 同结构，按钮为排序/过滤/设置（`headerIcon`） |
| 菜单：搜索常驻 + 溢出（排序 / 刷新 / 访问网站 / 分享 / 全部标已播） | 搜索常驻 + 溢出（排序 / 刷新 / 过滤 / 分享 / 订阅设置） |
| 列表行 = 队列同款 `feeditemlist_item`（无拖拽手柄） | 复用 `EpisodeRow` |
| 次级操作按 `ItemActionButton.forItem`：已下载→播放，否则→下载 | 同（`downloadState` 决定图标与动作） |
| 「Filtered」提示行 | `filter_active_hint` 行 |

### 3.5 播放页 `PlayerPage.ets`

上游 `AudioPlayerFragment` + `audioplayer_fragment.xml` + `cover_fragment.xml`。

| 上游 | 本轮实现 |
|---|---|
| 工具栏导航图标 = `ic_arrow_down`（下箭头），右侧收藏 / 睡眠定时 / 分享 | `arrow_down` + 星标 / 月亮 / 分享 |
| 封面 1:1，宽度 = min(屏宽−64dp, 可用高)，圆角 16 | `display.getDefaultDisplaySync()` 计算，夹在 160–280vp，圆角 16 |
| 订阅名 14sp 次级 + 单集标题 14sp 主色，各 2 行居中 | 订阅名 14fp 次级 + 标题 16fp 主色（字号上浮 2fp，中文可读性取舍，见 §4） |
| 「节目详情 / 章节」描边按钮：36dp 高、8dp 圆角、1dp 描边、minWidth 150dp | `detailButton` 36vp / 8vp / 1vp 描边 / minWidth 130vp |
| 进度条左右时间 12sp | 12fp，左右 16vp 内边距 |
| 控制行（底部 margin 24dp）：倍速 48 + 快退 48 + 播放 64 + 快进 48 + 下一集 48，48dp 按钮下方 12sp 数值标签 | 同序同尺寸（`controlButton`），标签 12fp |
| 章节在对话框里 | 章节弹层（`chaptersSheet`） |
| 节目详情是 WebView 页面 | 弹层纯文本降级（去标签），见 §4 |
| 睡眠定时对话框：预设 + 自定义 + 两个开关 | 保留原实现 |

### 3.6 其余页面

| 页面 | 上游 | 本轮实现 |
|---|---|---|
| 添加播客 `AddFeedPage` | `addfeed.xml`：标题「Add podcast」、无工具栏动作；圆角 28dp 搜索卡 + 6 行 `AddPodcastTextView`（minHeight 48dp、上下 8dp、左右 16dp、图标 + 14sp 文案） | 同构：28vp 搜索卡 + 6 行（RSS 地址 / 本地文件夹 / Apple Podcasts / fyyd / Podcast Index / OPML），RSS 行内联原有 URL 输入 + 私有订阅开关 + 订阅按钮 |
| 搜索 `SearchPage` | `search_fragment.xml`：标题「Search」+ 搜索动作；先订阅结果、后单集结果两个列表 | 同构：标题 + 搜索动作 + 圆角输入框 + 加载指示；`FeedCover` 行（订阅结果）在前、`EpisodeRow`（单集结果，本地全库检索）在后；空态图标 32vp + 16sp 文案 |
| OPML `OpmlPage` | `opml_selection.xml`：多选列表 + Select all/Deselect all + Confirm/Cancel | 同构：`OverflowButton`（全选/取消全选）+ 导出动作；多选行（勾选图标 + 标题，minHeight 48vp）+ 底部「取消 / 确认」40vp 双按钮 |
| 下载 `DownloadsPage` | `downloadlog_fragment.xml` + `downloadlog_item.xml`：运行中 / 已完成两组列表 + 「Clear history」 | `AppBar` + 清空动作 + 两组 `SectionHeader`（带计数）+ `EpisodeRow`；运行中行显示「已下载/总量」与 4vp 进度 |
| 播放历史 `HistoryPage` | `playback_history.xml`：标题 + Clear history（列表非空时显示） | `AppBar` + 清空动作 + 「继续收听 / 全部记录」两组 + `EpisodeRow` |
| 收藏 `FavoritesPage` | `favorites.xml`：标题 + 搜索动作 | `AppBar` + 搜索动作 + `EpisodeRow`（星标状态图标） |
| 收听统计 `StatsPage` | `ui/statistics`：三个页签「Subscriptions / Years / Downloads」+ 饼图/柱状图 | `AppBar` + `TagChip` 三页签（订阅/年份/下载）；图表用**等比横向条**替代（见 §4 #13） |
| 设置 `SettingsPage` | `ui/preferences`：`PreferenceCategory` 分组 + 行（图标 + 标题 + 摘要 + 尾部控件） | 同构：分类标题 14fp 品牌色 + `surface` 卡片（圆角 12vp）+ 1vp 分隔线 + 行最小高 56vp；分类：用户界面 / 播放 / 网络 / 自动下载 / 存储 / 通知 / 库与统计 |
| 存储 `StoragePage` | 上游无独立屏幕（`remove_feed_dialog.xml` 的破坏性样式可参考） | `AppBar` + 总占用卡片（48vp 图标底 + 20fp 数值）+ 按订阅列表（56vp 封面 + 计数 · 大小）+ 底部 `error_container` 底「删除全部下载」 |
| 订阅设置 `FeedSettingsPage` | `feedsettings.xml` + `FeedSettingsActivity` | `AppBar`（标题 = 订阅标题）+ 头部卡片（56vp 封面 + 标题 + 原订阅名）+ 分组：剧集过滤器 / 排序方式 / 自动下载 / 播放 / 自动化 / 显示 / 高级 / 取消订阅（`error_container` + `error`） |

---

## 4. 跳过 / 替代 / 取舍清单

| # | 上游布局 | 处理 | 理由 |
|---|---|---|---|
| 1 | 左侧导航抽屉（`DrawerLayout` + `NavDrawerFragment`） | **跳过** | 入口已由「更多」溢出菜单覆盖；鸿蒙侧需 `SideBarContainer` 另起一套手势/状态，收益低。平板上上游本身隐藏抽屉（`main.xml` 注释）。 |
| 2 | 折叠工具栏（`CollapsingToolbarLayout`，头图与标题栏重叠、滚动时标题下沉） | **跳过** | ArkUI 无折叠工具栏组件，需自绘滚动监听 + 视差，超出本轮范围；当前用「固定标题栏 + 下方头图」近似。 |
| 3 | 首页区块「随机惊喜」的「更多 → Episodes（全部单集）」 | **已同步（第 40 轮）** | 原先的跳过理由「本移植版没有全部单集页」已过时：`pages/EpisodesPage.ets` 存在（`Index` 溢出菜单本来就在跳它），现补上该链接。 |
| 4 | 首页区块骨架屏（`setDummyViews` + `alpha 0.1` 占位） | **跳过**（第 40 轮维持） | 需为每个区块实现骨架组件；当前用各区块专属空状态文案替代。 |
| 5 | Echo 年度回顾卡片（`home_section_echo.xml`） | **跳过** | 上游功能（EchoActivity + 年度统计）在本移植版不存在。 |
| 6 | 订阅页列数子菜单（`List` / 2 / 3 / 4 / 5 单选） | **已同步（第 43 轮）** | 上一轮的判断「原生 `Menu` 不支持嵌套单选子菜单」有误：`MenuItemOptions.builder`（API 9+）= 二级菜单构造器，实测可弹出（模拟器已验有勾选态）。 |
| 7 | 播放页节目详情（上游 WebView 渲染 HTML shownotes） | **替代实现** | 无 Web 组件依赖，弹层内纯文本降级（去 HTML 标签）。 |
| 8 | 播放页封面左右滑动切页（`ViewPager2`：封面 / shownotes） | **替代实现** | 改为「封面 + 节目详情按钮」；ArkUI `Swiper` 可实现但本轮未做（记录为后续项）。 |
| 9 | 播放页单集标题 14sp | **替代实现** | 改 16fp：14fp 中文标题在 2 行居中时过小，属字号取舍，几何位置一致。 |
| 10 | 首页/订阅页 Material3 波纹与 active indicator | **替代实现** | 鸿蒙用 `primary_container` 图标底胶囊 + 颜色/字重变化表达选中态，不用水波纹。 |
| 11 | 队列「已播」行的 `bg_episode_list_item` 内嵌 4dp/2dp 内缩圆角底 | **替代实现** | 鸿蒙侧统一用白色卡片 + 12vp 圆角承载行内容（与全局卡片规范一致）。 |
| 12 | 订阅瓦片选中时整卡内缩 12dp 的动画（`ValueAnimator`） | **已同步（第 43 轮）** | 订阅页已有多选模式（长按进入），内缩用 `animateTo({duration:100})` 实现（`animation()` 属性式动画会污染同屏其它组件，见 §7）。 |
| 13 | 统计页饼图 / 柱状图（`PieChartView`、200dp `BarChartView`，自绘 Canvas） | **替代实现** | 鸿蒙侧用等比横向进度条表达同一数据，无原生图表组件。 |
| 14 | 搜索页筛选胶囊行（`filter_chips`） | **跳过** | 本移植版搜索无筛选模型。 |
| 15 | 搜索页工具栏内展开的 `SearchView`（CollapsibleSearchView） | **替代实现** | `AppBar` 的 `@BuilderParam` 无法承载展开式搜索框，改为布局内圆角输入框。 |
| 16 | 添加播客的「快速发现」网格（`quickFeedDiscovery`） | **跳过** | 本移植版无对应发现 API。 |
| 17 | 添加播客的「本地文件夹 / fyyd / Podcast Index」三个入口 | **替代实现** | 后端能力不存在，按上游几何渲染但置灰（`text_disabled`）且不可点击，避免误点。 |
| 18 | 下载/收藏/统计页的溢出菜单项（Delete played / Refresh / Sort / Reset statistics / Filter） | **跳过** | 对应功能在本移植版不存在，不渲染空菜单项。 |
| 19 | 下载行无封面（`downloadlog_item.xml`） | **替代实现** | 共用 `EpisodeRow` 始终渲染 56vp 封面；一致性优先于该细节。 |
| 20 | 清空历史 / 清空下载的二次确认对话框 | **跳过** | 本轮未加确认弹窗（原行为即立即执行），记录为后续项。 |
| 21 | 设置页「关于」分类 | **跳过** | 本移植版无对应设置项，新增版本/隐私行属于功能新增。 |
| 22 | 订阅页默认 3 列、且**不显示标题**（标题画在封面上） | **已同步（第 43 轮，用户选择**，覆盖第 27 轮的「相对调整」**）** | 默认回到上游口径：3 列 + 标题画在封面占位底上（`prefSubscriptionShowTitles` 默认 `false`）；瓦片下方标题仍可手动开启，字号/内边距按上游随列数变化。 |
| 23 | 首页横滑卡片标题 14sp、日期 14sp | **相对调整** | 标题提到 15fp、日期降到 12fp（次级），保持"封面 + 两行标题 + 日期"的相对结构。 |
| 24 | 播放页单集标题 14sp | **相对调整** | 提到 20fp 中粗：封面已放大到 240–280vp，14fp 标题与之不成比例。 |
| 25 | 添加播客 / OPML 行文案 14sp | **相对调整** | 行高 48vp 的可点行文案提到 16fp，符合鸿蒙列表行字阶。 |
| 26 | 首页「配置首页」对话框：拖拽手柄排序 + 拖入/拖出「隐藏」组（`ReorderDialog`） | **替代实现（第 40 轮）** | 保留「显示 / 隐藏」两组与两个偏好（顺序 + 隐藏），但行内改用上/下移按钮调顺序：首页内容区是可滚动的 `List`，行内拖拽会与滚动抢手势（项目里只有队列页用 `PanGesture` + 浮层实现了拖拽，代价较高）。 |
| 27 | 首页行/卡片的 Android `ContextMenu`（长按弹系统菜单） | **替代实现（第 40 轮）** | 鸿蒙侧用底部操作弹层承载同一批动作（播放 / 标记已播·未播 / 加入·移出队列 / 收藏 / 下载·取消·删除文件），与下载页、单集总表的长按菜单形态一致。 |
| 28 | 首页竖排行挂 `SwipeActions` | **已同步（第 40 轮，形态同收件箱页）** | 右滑=加入队列；左滑：看新内容=标记已播、管理下载=删除文件。为此首页内容区由 `Scroll + Column + ForEach` 改为**单个纵向 `List`**：`swipeAction` 是 `ListItem` 的属性，挂在自定义组件上无法识别。 |
| 29 | 标题栏「刷新 / 配置首页」收进溢出菜单 | **替代实现（第 40 轮）** | 鸿蒙侧标题栏用三个图标动作（搜索 / 刷新 / 编辑），与队列页、单集总表的标题栏形态一致；不再为两项单独开溢出菜单。 |
| 30 | 欢迎页 80dp `ic_curved_arrow` 引导箭头 | **替代实现（第 40 轮）** | 上游是手绘曲线箭头（右下角实例翻转 180°）；鸿蒙侧用系统曲线箭头符号 `sys.symbol.arrow_uturn_down` 近似，位置/尺寸（80vp、margin 16vp、右下角）一致。 |
| 31 | 下载排序偏好由下载页的排序动作设置 | **替代实现（第 40 轮）** | `prefDownloadsSortedOrder` 与「首页管理下载」的排序已对齐；入口放在设置页「存储」分类一行（点击循环 6 种排序）——本移植版下载页展示的是下载记录而非可排序的单集列表，放在那里没有作用对象。 |
| 32 | 统计口径复选项在 `StatisticsFilterDialog`（含时间范围选择） | **替代实现（第 40 轮）** | 本移植版统计页没有过滤对话框；新增的「包含仅标记为已播的单集时长」开关放在统计页「Subscriptions」标签顶部，与首页「常听经典」共用同一口径。 |
| 33 | 队列划出项视觉（中性抬升底 + 图标着色 + 最大位移 2/5 宽、正弦阻尼、85% 阈值执行） | **保持（第 41 轮，用户选择）** | 本端用品牌色/错误色整块动作区 + 40vp 动作区、「越过即执行」，与收件箱 / 首页 / 订阅详情同一套划出风格；改一处就得改四处。 |
| 34 | 队列行内日期格式 `DateFormatter.formatAbbrev`（"Sep 1"，不带年份） | **保持（第 41 轮，用户选择）** | 本端沿用系统本地格式（`toLocaleDateString`，带年份），对老单集更易辨认，且与复用 `EpisodeRow` 的其它列表一致。 |
| 35 | 点击行打开单集详情页（`ItemPagerFragment`） | **保持（第 41 轮，用户选择）** | 本移植版没有单集详情页；点击行仍是「直接播放 + 跳播放页」，新增详情页超出队列范围。 |
| 36 | 长按菜单「跳过这一集」发 `KEYCODE_MEDIA_NEXT` | **替代实现（第 41 轮）** | 无 skip API，改用 `QueueEngine.autoAdvance(false)`：结束当前一集（移出队列）并接着播队列里的下一集。 |
| 37 | 滑动动作可配置的屏幕集合（队列 / 收件箱 / 全部单集 / 已下载 / 订阅详情 / 播放历史 / 收藏） | **替代实现（第 41 轮）** | 只提供本移植版真实存在的 4 个滑动面：队列 / 收件箱 / 订阅详情 / 已下载（首页「看新内容」用收件箱配置、「管理下载」用已下载配置）；「全部单集 / 播放历史 / 收藏」当前没有滑动面，不列出空配置项。 |
| 38 | 各屏滑动默认值（收件箱左滑 = 移出收件箱、订阅详情 = 收藏/下载…） | **相对调整（第 41 轮）** | 队列默认值按上游对齐（左右都是「移出队列」）；其余屏幕沿用本移植版既有默认值，避免在队列改造里顺带改掉别的页面的手势习惯。 |
| 39 | 队列页作为独立 Fragment（含 systembar inset、`LiftOnScrollListener` 抬升标题栏） | **保持** | 本端队列是底栏页签（`Index.ets` 的 `TabContent`），标题栏为大标题式，与首页 / 待处理 / 订阅同一套外壳（第 27 轮已记录）。 |

---

## 5. 验收方式

1. `arkts_check` 静态检查：本仓库自身文件 0 错误（仅 SDK `@arkts.lang.d.ets` 解析噪音）。
2. hvigor `CompileArkTS` 编译通过（`SignHap` 因 `signingConfigs` 留空而跳过，与 UI 无关）。
3. 模拟器 `127.0.0.1:5555` 安装未签名 HAP → 启动 → 逐页截图核对。
4. 深浅色两套主题各验一轮（色值全部走资源限定符）。

### 取证截图（本轮）

| 页面 | 结论 |
|---|---|
| 首页 | 横滑卡片（128vp 封面 + 播放钮 + 进度条）、区块标题右侧「更多 + 箭头」、未读胶囊、竖排两行、底部 5 页签（含 `primary_container` 选中底） |
| 队列 | 信息条 `"2 集 · 剩余 0 分钟"`、拖拽手柄、封面 + 状态行 + 进度行、右侧移除 |
| 待处理 | 作为页签的大标题 + 未读胶囊 + 剧集行列表 |
| 订阅 | 3 列封面网格 + 封面上的计数胶囊 + 右下角 FAB |
| 订阅详情 | 156vp 头图 + 124vp 封面 + 白色标题 + `#80000000` 操作带 + 过滤胶囊 + 剧集行；工具栏溢出菜单（排序/刷新/过滤器/分享/订阅设置） |
| 播放 | 下箭头工具栏 + 方形封面 + 订阅名/标题 + 描边按钮 + 滑杆 + 五键控制行（倍速·快退·播放·快进·下一集） |
| 更多菜单 | 图标 + 文案六项（下载/播放历史/收藏/收听统计/添加播客/设置） |
| 下载 / 播放历史 / 收藏 / 收听统计 | 标题栏 + 分组计数 + `EpisodeRow`；统计页三页签 |
| 设置 / 存储 / 订阅设置 | 分类标题 + `surface` 卡片 + 1vp 分隔线 + 尾部控件 |
| 添加播客 / 搜索 / OPML | 28vp 搜索卡 + 六行入口；两组搜索结果；多选 + 确认/取消 |
| 深色主题 | 首页整体复核：黑底、`surface`/`surface_container` 分层、白字与品牌色正常 |

> 环境备注：本轮取证期间模拟器显示密度曾一度异常（`hw.lcd.density=560` 被运行时改写为等效 ~240，
> 表现为整个系统 UI 与桌面图标都变小），**重启模拟器后恢复正常**，与代码无关；
> 排查方法：用 UI dump 的节点坐标反推 vp（底栏项 96px ÷ 64vp = 1.5 px/vp，正常应为 3.5）。
>
> 本轮同时修掉一个真实缺陷：`EpisodeRow` 把 `onClick` 与 `gesture(LongPressGesture())` 绑在同一节点上，
> 普通点击被手势竞争吞掉（点播放图标有效、点行体无效）。改用 **`parallelGesture`** 后行体点击恢复正常
> （队列 / 待处理 / 订阅详情均验证通过）。

---

## 6. 第 41 轮：队列页专项（用户逐条选择后的实施与取证）

### 6.1 选择结果

用户对 26 项差异逐条选择：**同步 22 项 / 保持 4 项**。

- 同步：L1 行内次级操作与下载进度环、L2 播放中高亮、L3 多选计数进标题栏且隐藏信息条、
  L4 多选动作栏按状态显隐、L5 全选系列、L6 溢出菜单（去「多选」、锁定项勾选态与隐藏规则）、
  L7 空态文案 + 「前往收件箱」、L8 chip 排序网格 + 播客标题 + Keep sorted、L10 下拉刷新、
  I1 长按弹层、I2 长按进入多选时选中长按项、I3 封面左半区起拖、I5 左右滑默认都移除、
  F1 刷新 = 拉取订阅更新、F2 队列内搜索、F3 提示 + 撤销、F4 锁定确认框、F5 清空确认框、
  F6 时长按倍速折算、F7 显示剩余时间、F9 设置页「滑动动作」自定义、F10 滚动位置记忆、F12 事件订阅补齐。
- 保持：L9 划出项视觉、I4 点击行 = 直接播放、F11 日期格式，另 §4 #39 外壳形态。

### 6.2 新增 / 改动文件

| 文件 | 内容 |
|---|---|
| `pages/QueuePage.ets` | 队列页主体（上述大部分条目） |
| `components/EpisodeRow.ets` | 播放中高亮底、封面左半区起拖、长按后忽略紧随 click（修掉「长按进多选变 0 选中」） |
| `components/EmptyState.ets` | 可选动作按钮（空态「前往收件箱」） |
| `components/SwipeActionButton.ets` | 新增：划出项按钮（图标 + 文案 + 破坏性配色） |
| `common/SwipeActions.ets` | 新增：动作 id / 屏幕 / 可选动作 / 默认值 / 读写偏好 |
| `prefs/UserPreferences.ets` | keepSorted、keepSortedOrder、锁定警告、滚动位置、倍速折算、显示剩余时间、每屏滑动动作 |
| `player/QueueEngine.ets` | 保持排序自动重排、播客标题排序、`addAt`（撤销）、`moveToTop/Bottom` |
| `utils/SortUtils.ets` | `sortQueue`（含播客标题 / 随机 / 智能乱序双向） |
| `model/Enums.ets` | `SortOrder` 追加 6–10（播客标题 / 随机 / 智能乱序，0–5 落库值不变） |
| `db/repositories/FeedRepository.ets` | `listByIds`（队列行的订阅标题 / 封面 / 倍速） |
| `components/LazyDataSource.ets` | `notifyDataChange`（单行刷新，不重建列表） |
| `events/EventHub.ets` | `SWIPE_ACTIONS_CHANGED` / `PREFS_CHANGED` |
| `pages/SettingsPage.ets` | 显示剩余时间 / 时长按倍速折算 两个开关 + 「滑动动作」底部弹层 |
| `pages/SearchPage.ets` | `queuedOnly`（队列内搜索） |
| `pages/InboxView.ets` / `FeedDetailPage.ets` / `HomePage.ets` | 划出动作改读设置（含「移出收件箱」实现） |
| 三套 `string.json` | 新增 45 条文案（队列空态 / 多选 / 锁定 / 滑动动作 / 搜索 / 排序标签） |

### 6.3 实机取证（模拟器 `127.0.0.1:5555`）

| 条目 | 取证 |
|---|---|
| L1 / F12 | 行右端出现 48vp 次级操作；点下载后该行图标即时变为「播放」（`EPISODE_DOWNLOAD` 单行刷新，无整页重载） |
| L2 | 播放器当前装载的那一集行底色为 `surface_container_playing`，与其余白底行可肉眼区分 |
| L3 / L5 | 多选态标题栏「1/3 已选」+ ✕；溢出菜单「全选 / 向上全选 / 向下全选」；信息条隐藏 |
| L4 | 多选栏随状态变化：单选时含「分享链接」、全选后消失；选中项在队首时只出现「移到底部」 |
| L6 | 溢出菜单为「搜索 / 刷新 / 锁定 / 排序 / 清空队列」（无「多选」）；开启保持排序后「锁定」整项消失 |
| L7 | 清空后空态显示「队列里还没有单集 / 下载单集，或长按单集选择"加入队列"。 / 前往收件箱」，点按钮进收件箱 |
| L8 | chip 网格 6 项；点「日期」即时重排队列并显示「日期 ▲」；勾选「保持排序」后拖拽手柄全部消失 |
| L10 / F1 | `Refresh` 容器 + 菜单「刷新」→ `AceRefresh: Refresh status changed 3/4` 日志 |
| I1 / I2 | 长按弹层（移到顶部/底部按长按项显隐）；弹层「多选」进入后为「1/3 已选」，不再是 0 选中 |
| I5 | 左右滑默认都是「移出队列」（设置页弹层显示「右滑 移出队列 / 左滑 移出队列」） |
| F2 | 队列页搜索 → 标题「队列内搜索」+ 占位「在队列中搜索单集」，键入「第 8」只返回队列内的该集 |
| F3 | 滑出后顶部提示「已移出队列 + 撤销」；点撤销后条目回到原位（1 → 2 集） |
| F4 | 锁定确认框（标题 / 警告 / 不再提示 / 取消 / 锁定队列）；锁定后手柄消失 |
| F5 | 清空确认框（「确定要把全部单集从队列中移除吗？」） |
| F7 | 开启「显示剩余时间」后行内右侧显示 `0:00`（该集已播完，剩余为 0；上游同） |
| F9 | 设置页「滑动动作」弹层：屏幕胶囊（队列/收件箱/订阅详情/已下载）+ 启用开关 + 右滑/左滑选择器（队列可选 移出队列/下载/标记已播放/加入收藏/删除文件/分享链接/移到顶部/移到底部/无） |

### 6.4 本轮未能在设备上复现的部分（代码级核对）

- **I3 封面左半区起拖**：`hdc` 的注入式 swipe 速度过高，被识别成 fling，手柄拖拽也同样无法在自动化下触发
  （与第 27 轮记录一致）；实现与已验收的手柄拖拽同一 `PanGesture`，仅多了 `localX < 28vp` 的右半区排除。
- **F6 信息条按倍速折算**：偏好读取与 `SpeedChangedEvent` 重算链路已接，实机因测试单集仅 5 秒、倍速为 1x
  无法肉眼区分；换算公式为 `left / speed`（与上游 `itemTimeLeft / playbackSpeed` 一致）。
- **F10 滚动位置恢复**：需长队列 + 冷启动组合，本轮队列仅 2 集；写入发生在 `aboutToDisappear`、
  恢复发生在冷启动首次加载（`prefQueueScrollOffset`）。

---

## 7. 第 42 轮：收件箱专项（用户逐条选择后的实施与取证）

上游参照：`ui/screen/InboxFragment.java` + `ui/episodeslist/EpisodesListFragment.java`
+ `res/menu/inbox.xml` + `res/menu/feeditemlist_context.xml` + `feeditemlist_item.xml`
+ `ItemSortDialog`/`InboxSortDialog` + `ItemActionButton` + `SelectableAdapter`/`FloatingSelectMenu`。

### 7.1 选择结果

用户对 19 项差异逐条选择：**同步 17 项 / 保持 2 项**。

- 同步：1 标题栏加搜索入口（`action_search` 常显图标）、2 排序入口（`inbox_sort`，只列「日期 / 时长」
  两类 + `prefInboxSortedOrder` 持久化）、3 刷新 = 联网抓取订阅（`FeedUpdateManager.runOnceOrAsk`
  → 本端 `RefreshService.refreshAll`，并补上 `SwipeRefreshLayout` 下拉刷新）、
  4「全部移出收件箱」收进右侧 ⋮ 溢出菜单、6 长按 = 上下文操作弹层（`feeditemlist_context`）、
  7 多选（`ActionMode` + `FloatingSelectMenu`）、8 行内次级按钮状态化 + 下载进度环（`ItemActionButton`）、
  9 事件订阅补齐（`FeedItemEvent` / `PlayerStatusEvent` / `EpisodeDownloadEvent` / `PlaybackPositionEvent`）、
  10 移除标题栏未读数胶囊、11 列表内边距改为 4vp（上游 `additional_horizontal_spacing=0dp` + 行 4dp inset）、
  12 行副标题 = 发布日期 · 文件大小（不再显示订阅名）、13 无封面时封面位置画订阅名占位（`txtvPlaceholder`）、
  14 默认左滑 = 移出收件箱、15 滑动可选集合去掉「标记已播放」与「删除文件」、
  16 确认弹层补「不再提示」勾选、17 空态改为「收件箱里还没有单集」+ 说明句、18 滚动位置记忆。
- 保持：5 单击行 = 直接播放（与第 35 条同结论，本移植版无单集详情页）、
  19 每页 50 条 + 居中文字「加载中」（为性能调小，未取上游 150 条 + 转圈指示）。

### 7.2 新增 / 改动文件

| 文件 | 内容 |
|---|---|
| `pages/InboxView.ets` | 本轮主体：标题栏（搜索 + ⋮ 溢出菜单 / 多选态标题栏）、排序面板、长按操作弹层、多选与全选系列（含「连带未加载页」与标已播确认框）、状态化次级按钮、事件订阅、滚动位置记忆 |
| `db/repositories/EpisodeRepository.ets` | `listInboxPage(limit, order, cursor?)`：新增 4 种排序（日期/时长 × 升降序），游标改为排序键 + id 双键续读 |
| `prefs/UserPreferences.ets` | `prefInboxSortedOrder` / `prefInboxScrollOffset` / `prefDoNotPromptRemovalAllFromInbox` |
| `components/EpisodeRow.ets` | 新增 `coverFallbackTitle`（无封面占位文字），转发给 `FeedCover.fallbackTitle` |
| `common/SwipeActions.ets` | 收件箱默认值改为 `[加入队列, 移出收件箱]`；可选集合去掉「标记已播放」「删除文件」 |
| `pages/HomePage.ets` | 「看新内容」区块同步读 `prefInboxSortedOrder`（上游 `InboxSection` 同） |
| 三套 `string.json` | `inbox_empty` 改为「收件箱里还没有单集 / No episodes in the inbox」；新增 `inbox_empty_message`、`removed_from_inbox_msg`、`multi_select_mark_played/unplayed_confirmation` |

### 7.3 实机取证（模拟器 `127.0.0.1:5555`）

| 条目 | 取证 |
|---|---|
| 10 / 17 | 空态：大标题「收件箱」右侧只有「搜索 + ⋮」（无计数胶囊）；空态图标 + 「收件箱里还没有单集」+ 「新单集会出现在这里，你可以再决定是否感兴趣。」 |
| 4 / 3 | ⋮ 菜单为「刷新 / 排序 / 全部移出收件箱」；点「刷新」走联网刷新，新单集进列表、底栏角标 6 |
| 11 / 12 / 13 | 行：封面位置画订阅名「Homenna 验收播客」；状态行 `▣ · 9/13/2026 · 78 KB`（日期 · 大小，无订阅名）；行左右各 4vp 留白 |
| 8 / 9 | 未下载行的钮为「下载」；点下载后该行即时变为「播放」图标（`EPISODE_DOWNLOAD` 单行刷新）；顶部提示「下载中」 |
| 2 | 排序面板只有「日期 ▼ / 时长」两格 + 取消；点「时长」后列表变为 0:05 → 0:10 → 0:20 → 0:30 → 0:45 → 1:00，面板不关闭且该格即显示「时长 ▲」 |
| 6 | 长按弹层：「移出收件箱 / 标记为已播放 / 加入队列 / 下载 / 加入收藏 / 分享链接 / 多选」（未播放中、未下载、位置为 0 时自动隐藏跳过这一集 / 删除文件 / 重置播放位置） |
| 7 | 弹层「多选」进入后标题栏变「1/6 已选 + ⋮ + ✕」，长按项高亮 `primary_container`，底部浮动动作栏为「标记为已播放 / 移出收件箱 / 加入队列 / 加入收藏 / 下载…」 |
| 14 | 左滑一行 → 顶部提示「已移出收件箱」、该行消失、角标 6 → 5 |
| 16 | 「全部移出收件箱」弹层含「不再提示」勾选框 + 取消 / 确认 |
| 1 | 点搜索图标进入搜索页（占位「搜索播客 / 输入关键词开始搜索」） |

### 7.4 第 42 轮补做：多选「全选」连带未加载页（用户追加要求）

**上游依据**：`SelectableAdapter`（`select_toggle` / `select_all_below` 置 `shouldSelectLazyLoadedItems`、
`onSelectedItemsUpdated` 把 `totalNumberOfItems - getItemCount()` 计入已选）
+ `EpisodesListFragment.performMultiSelectAction`（对已加载选中项处理完后，从 `page + 1`
继续 `loadMoreData(applyPage)` 直到某一页不满 `EPISODES_PER_PAGE`）。

- **收件箱（已同步）**：新增 `selectAllLazy`（= `shouldSelectLazyLoadedItems`）、标题栏分母改为
  `countNew()`（上游 `setTotalNumberOfItems(getTotalEpisodeCount(NEW))`）、
  `forEachUnloadedItem()` 按游标续读后面的页并逐条施加同一动作（不把这些页塞进列表，同上游）；
  「全选 / 向下全选」置真、「向上全选」不动（同上游）；退出多选时复位。
  另补上上游的二次确认：标记已播 / 未播时，`选中 >= 25` 或「全选连带未加载页」先弹
  `ConfirmationDialog(multi_select, multi_select_mark_played/unplayed_confirmation)`。
- **队列（无需改动，已一致）**：上游 `QueueFragment` **不继承** `EpisodesListFragment`
  ——它一次性 `DBReader.getQueue()` 全量加载、也从不调 `setTotalNumberOfItems`，
  菜单回调里直接 `handleAction(getSelectedItems())`，因此上游队列本就不存在「未加载页」，
  「全选」就是整条队列；本端队列页同样由 `QueueEngine.load()` 一次性装载整条队列，
  `toggleSelectAll()` 覆盖全部条目、标题栏分母为队列长度，语义与上游一致。

**实机取证（模拟器 `127.0.0.1:5555`）**

| 场景 | 取证 |
|---|---|
| 收件箱 124 条新单集（首屏 50） | 长按 → 多选 → ⋮「全选」→ 标题栏 **124/124 已选**（50 已加载 + 74 未加载） |
| 收件箱「标记为已播放」（全选态） | 弹出确认框「多选 / 请确认要把选中的全部单集标记为已播放。」；确认后收件箱**清空**、底栏角标消失 → 74 条未加载页也确实被处理 |
| 收件箱「标记为已播放」（手工选 1 条） | 直接执行、**不**弹确认框（未达 25 条且未全选） |
| 收件箱 60 条新单集（首屏 50） | ⋮「全选」→ **60/60 已选** → 「移出收件箱」（该动作上游无确认框）→ 收件箱清空、角标消失 |
| 队列 14 条 | 长按 → 多选 → ⋮「全选」→ **14/14 已选** → 浮动动作栏「移出队列」→ 队列清空（`0` 集），证明全选覆盖整条队列 |

### 7.5 本轮未纳入选择范围 / 已知残留差异

- **「移出收件箱」的 Snackbar 撤销**：上游 `removeNewFlagWithUndo` 的 Snackbar 带「撤销」；
  本端沿用顶部提示条（无动作区），与队列页「提示 + 撤销」的差异记录在此，后续可统一。
- **列表 16vp 页面内边距只在收件箱改为 4vp**：上游所有单集列表（队列 / 单集总表 / 下载 / 搜索 /
  订阅详情）都是 `additional_horizontal_spacing=0dp` + 行 4dp inset；本轮按「收件箱专项」只改本页，
  其余页面留待各自轮次对齐（首页「看新内容」区块亦同）。
- **「全部移出」弹层形态**：上游是居中 `MaterialAlertDialog`，本端仍是贴底弹层（本端对话框习惯），
  本轮只同步了内容（标题 / 说明 / 不再提示 / 确认取消）。
- **保持项 5 / 19**：单击行直接播放、每页 50 条 + 文字加载提示（见 7.1）。
- **多选动作栏的范围**：上游 `FloatingSelectMenu` 的项可见性只按**已加载**的选中项计算
  (`FeedItemMenuHandler.onPrepareMenu(menu, getSelectedItems())`)，本端 `batchActions()`
  同样只看已加载选中项 —— 与上游一致（未加载页不参与可见性判断）。

---

## 8. 第 43 轮：订阅页专项（用户逐条选择后的实施与取证）

上游参照：`ui/screen/subscriptions/SubscriptionFragment.java` + `res/layout/fragment_subscriptions.xml`
+ `subscription_grid_item.xml` / `subscription_list_item.xml` + `res/menu/subscriptions.xml`
+ `SubscriptionsRecyclerAdapter` / `SubscriptionViewHolder` / `SubscriptionTagAdapter`
+ `SubscriptionsFilterDialog` / `SubscriptionsFilterGroup` / `FeedSortDialog` / `FeedCounterDialog`
+ `FeedMenuHandler` / `FeedMultiSelectActionHandler` / `TagMenuHandler`
+ `Storage/database` 的 `DBReader.getNavDrawerData` / `PodDBAdapter.getFeedCounters|getPlayedEpisodesCounters|getMostRecentItemDates`
+ `SubscriptionsFilterExecutor`（上游基线 `d05a58b`）。

### 8.1 选择结果

用户对 34 项差异逐条选择：**同步 22 项 / 保持 10 项 / 大项 1 项实现**。

- **同步**：A4 加载指示、A6 空态按全局过滤器判定、A7 标签行（未标记 / 字母序 / 20 字符截断）、
  A10 排序居中单选对话框、A11 计数设置居中单选、A12 列数二级菜单、A13「显示标题」勾选态 + 列数 1 时隐藏、
  A16 瓦片标题固定两行、A17 刷新失败图标贴封面右下角、A18「显示标题」默认关闭、
  B3 计数口径补齐上游 5 档（默认收件箱新单集）、B4 千分位、B5「计数 > 0」按当前计数口径、
  B6「最多播放」= 已播放集数、B7「最近更新」= `MAX(pubdate)`、B13 选中标签持久化、B14 选中标签自动居中、
  B15 滚动位置恢复、B16 事件订阅补齐 + 重新可见时重查库、B11「编辑标签」弹层、B12 标签重命名 / 删除、
  B1 多选（含 B9 全部移出收件箱、B10 分享链接）。
- **保持**：A1 标签行不随滚动折叠、A2 标题栏保留刷新图标、A3 大标题外壳、A5 空态图标仍用 `folder`、
  A8「已过滤」行点击清除标签、A9 过滤器弹层沿用竖排勾选行、A14 瓦片封面裁剪填满、A15 瓦片文字几何不随列数、
  B2 不做归档、B8 排序并列不额外按标题（库序已近似）。

### 8.2 新增 / 改动文件

| 文件 | 内容 |
|---|---|
| `pages/SubscriptionsPage.ets` | 本轮主体：加载指示 / 空态判定 / 标签行（未标记 + 字母序 + 截断 + 居中）/ 三个居中单选对话框 / 列数二级菜单 / 勾选项 / 瓦片几何 / 多选（标题栏 + 浮动动作栏 + 勾选圈 + 渐变遮罩 + 内缩）/ 标签编辑弹层 / 标签重命名删除 / 批量偏好 / 分享 / 全部移出收件箱 / 滚动恢复 |
| `db/repositories/EpisodeRepository.ets` | `FeedCounter` 增 `newCount` / `played`；`listFeedCounters` 增两列聚合；新增 `listMostRecentPubDates()`、`clearNewFlagsByFeeds()` |
| `db/repositories/FeedRepository.ets` | 新增 `FeedTagState` + `listTagState()` / `renameTag()` / `deleteTag()` / `splitTags()` |
| `model/Feed.ets` | 新增 `newCount` / `playedCount` |
| `prefs/UserPreferences.ets` | `prefSubscriptionShowTitles` 默认改 `false`；计数口径改用新键 `prefSubscriptionCounterSetting`（取值 = 上游 `FeedCounter.id`）；新增 `prefSubscriptionLastTag` |
| `events/EventHub.ets` | 新增 `REFRESH_STATE` + `RefreshStateData` |
| `services/RefreshService.ets` | `isRunning()` + 刷新开始 / 结束时广播 `REFRESH_STATE` |
| 三套 `string.json` | 新增 18 条文案（标签未标记 / 重命名 / 删除确认、计数 5 档、已选计数、分享、批量更新等） |

### 8.3 实机取证（模拟器 `127.0.0.1:5555`）

| 条目 | 取证 |
|---|---|
| A18 / A16 | 默认 3 列、标题画在封面占位底上；开启「显示标题」后瓦片下方出现**固定两行**标题（`Homenna 验收播客` 折两行） |
| A4 | 首屏加载期间为居中 `LoadingProgress`，加载完成才渲染网格/空态 |
| A10 | 溢出 →「排序」= 居中对话框：标题「排序」+ 4 项单选（未播放单集数 / 按字母 / 最近更新 / 收听最多）+ 取消 |
| A11 / B3 | 溢出 →「计数显示」= 居中对话框，5 项与上游一致（收件箱新单集数 / 未播放单集数 / 已下载单集数 / 已下载且未播放的单集数 / 不显示），默认选中「收件箱新单集数」 |
| A12 | 溢出 →「每行列数」弹出**二级菜单**（列表 / 2 / 3 / 4 / 5），当前项 3 带 ✓；选 2 后瓦片变宽、字号 16fp |
| A13 | 列数 = 3 时「显示标题」带 ✓；切到「列表」（列数 1）后该菜单项整项消失 |
| B3 / B4 | 计数切到「未播放单集数」后胶囊显示 80；在订阅详情标记一集已播后返回，胶囊 81 → 80（与 DB 直查一致） |
| B16 | 页面重新可见时 `loadFeeds()`（`onVisibleAreaChange`）与 `FEED_ITEM_UPDATE` 双双生效；拉库核对 `read != 1` = 80，与胶囊一致 |
| B1 / B9 / B10 | 长按瓦片 → 标题栏「1/1 已选」+ ⋮ + ✕，瓦片左上勾选圈 + 顶部渐变遮罩 + 卡片内缩；底部 112vp 横滑动作栏「编辑标签 / 分享 / 全部移出收件箱 / 取消订阅 / 保持更新 / 新单集通知 / 自动下载 / 自动删除 / 播放速度」 |
| B1 批量偏好 | 点「保持更新」弹开关对话框（保持更新 + 开关 + 取消/确认）→ 确认后退出多选并提示「已更新 1 个订阅」 |
| B11 | 点「编辑标签」弹层：无公共标签时显示「未设置」，输入 `Tech` → 添加 → 胶囊 `Tech ✕` → 确认后标签行出现「全部 / Tech」 |
| B12 | 长按 `Tech` 胶囊 → 菜单「重命名标签 / 删除标签 / 取消」；删除 → 确认框「确认删除标签「Tech」？」→ 删除后标签行消失 |
| A6 | 过滤器勾「不自动下载」（该订阅 autoDownload = 1）→ 列表空 → 空态显示「暂无订阅 / **清除过滤条件可看到更多订阅。**」且出现「已过滤」行 |
| A7 | 标签行左侧「全部」选中态为品牌色填充胶囊；命名标签只按存在性显示，删除最后一个标签后整行隐藏 |

### 8.4 本轮修掉的缺陷（含 2 个既有缺陷）

1. **标签行把整页挤空（本轮引入并修复）**：横向 `List` 放进纵向 `Column` 时默认撑满剩余高度，
   使后面的 `Refresh`（列表）拿到 0 高 —— 表现为「加了标签之后订阅瓦片整块消失」。
   修法：给标签行显式 `height(44)`。
2. **`getStringSync($r('app.string.x', arg))` 不做参数替换（本轮引入并修复）**：
   资源里的 `%1$s` 原样显示为「已更新 %1$s 个订阅」。修法：参数移到 `getStringSync` 的实参位
   （`getStringSync($r(...), n.toString())`）。
3. **过滤器开关只能取消、永远选不上（第 28 轮起的既有缺陷）**：`toggleFilter` 只做
   `without(selected, id)`（纯删除），第一次点选必然得到空集合 —— 即**过滤弹层从来没有过滤过任何订阅**。
   修法：改为真正的开关（未选中则加入并清掉同组旧值，已选中则移除）。
4. **订阅页在「页面不可见期间发生的数据变更」后不刷新（既有缺陷）**：只靠事件订阅时，
   上游的 `onStart → loadSubscriptionsAndTags()` 语义（每次回到页面都重查库）缺失。
   修法：根容器加 `onVisibleAreaChange` 重新加载。

### 8.5 残留差异与未纳入选择范围的项

- **A1 / A2 / A3 / A5 / A8 / A9 / A14 / A15 / B2 / B8**：用户选择「保持当前」，见 8.1。
- **归档（B2）缺失的连带项**：多选动作栏第 4 项为「取消订阅」（上游是「取消订阅 / 归档」，
  另有「取消订阅 / 恢复」）；`FeedState` 仍只有 未订阅 / 已订阅 / 订阅中。
- **每 Feed 自动下载仍是布尔**：上游是 `GLOBAL / ENABLED / DISABLED` 三态，
  故批量「自动下载」弹层用开关（无「跟随全局」项）。补齐需先改 `Feeds.auto_download_enabled` 语义。
- **瓦片封面 `scaleType`**：保持 `ImageFit.Cover`（裁剪填满），上游是 `fitCenter`（留边）。
- **过滤器弹层形态**：保持本端竖排勾选行 + 取消/重置（上游是横向按钮组 + 重置/确认）。
- **「计数 > 0」过滤与计数设置联动**：已按上游实现（按当前计数口径判断），因此计数设为「不显示」时
  该过滤会滤掉全部订阅 —— 与上游行为一致，属预期。
- **B6 / B7 / B8 排序口径**：只有 1 个订阅时无法肉眼区分，属代码级核对（对照上游 comparator 逐条实现）；
  **第 43 轮补充验收已用 86 个真实订阅复现，见 §8.6**。
- **A17 刷新失败图标位置**：本机无「刷新失败」的订阅，未触发该分支。
- **B15 滚动位置恢复**：需要超过一屏的订阅量；**第 43 轮补充验收已复现并修掉一个缺陷，见 §8.6**。

### 8.6 第 43 轮补充验收：导入真实 OPML 后的 B6 / B7 / B8 / B15

用户追加要求：导入 `antennapod-feeds-2026-09-09..opml`，并以导入后的订阅复现 B6/B7/B8 与 B15。

**导入结果**（模拟器 `127.0.0.1:5555`，未签名 HAP，`更多 → 添加播客 → 导入播客列表（OPML）`）

- 文件从设备 `我的手机` 选中（`/storage/media/100/local/files/Docs/antennapod-opml.xml`，17451 B，与仓库中的 OPML 同字节数），
  页面解析出「已导入订阅：86」→ 溢出菜单「全选」→「确认」。
- 落库：订阅 **87** 个（86 个导入 + 原有验收源）、单集 **15740** 条（其中 15610 条 `read = 0`）、
  导入的 86 个共用同一条 `inbox_baseline = 1789149762223`（收件箱仍为 0 条，基线语义生效）。
- 导入后整库刷新一次：提示「已更新新增：0」。封面加载正常（3 列网格首屏 15 张瓦片全部渲染真实封面）。

| 条目 | 方法 | 结果 |
|---|---|---|
| **B8**（排序并列按标题忽略大小写） | 计数口径设为「收件箱新单集数」（87 个订阅全为 0，**全并列**）→ 计数排序 → 列表模式读序 | 1983毁三观 → 907编辑部 → AsyncTalk → **big idea 大聪明** → Buidler Talk｜Web3 对谈 → Coffeeplus播客 → EmacsTalk → Homenna 验收播客 → LovePM → OnBoard! → Tech PodFest → TIANYU2FM → …，**与 SQL `ORDER BY lower(title)` 完全一致**。两处判别点：`big idea`（小写 b）排在 `Buidler`/`Coffeeplus` **之前**（大小写敏感时它会掉到大写字母之后），`Tech PodFest` 排在 `TIANYU2FM` **之前**（大小写敏感时相反） |
| **B7**（最近更新 = `MAX(pubdate)`） | 排序切「最近更新」→ 读首屏 | Homenna 验收播客 → 核市奇谭 → 知行小酒馆 → 脑放电波 → 忽左忽右 → 跑者日历 → 开始连接 LinkStart，**与 SQL `MAX(pubdate) DESC` 逐位一致**（`docs` 里同一份 SQL 的期望表）。旧实现用 `Feeds.last_update`：导入后该列全为空串 → 旧口径会把列表排成**字母序**（1983毁三观 开头），与实测完全不符，差异可判别 |
| **B6**（最多播放 = 已播放**集数**） | 在 `big idea 大聪明`（7 集）与 `EmacsTalk`（19 集）里各「全选 → 标记为已播放」，再切「收听最多」 | 顺序 = Homenna 验收播客(130 集) → EmacsTalk(19) → big idea 大聪明(7) → 其余(0) 按字母序。**与「已播放集数降序」逐位一致**；若按旧口径「已播放时长降序」则应为 big idea(15041 s) → EmacsTalk(5055 s) → Homenna(735 s)，**前三名正好相反** |
| **B15**（滚动位置恢复） | 列表模式滚动 3 屏（首项 = 东亚观察局）→ 切到「首页」再切回「订阅」 | **修复后：仍停在原处**（首项 = 世界莫名其妙物语，东亚观察局紧随其后，偏差 1 行）；修复前同一步骤会**跳回顶部** |

**§8.6 修掉的第 5 个缺陷：`setData()` 把滚动位置重置到顶部**

- **现象**：滚到列表中部 → 切到别的页签再切回 → 位置丢失（回到顶部）。
- **根因**：第 43 轮新加的 `onVisibleAreaChange → loadFeeds()` 每次页面重新可见都会重查库，
  而 `applyFilter() → dataSource.setData()` 触发 `onDataReloaded` 时 List/Grid 会回到顶部；
  `restoreScroll()` 却只在**首次加载**执行（`scrollRestored` 一次性标志，对齐上游 `firstLoaded`）。
  由于本移植版订阅页是底栏页签、组件不会被销毁，这个「只恢复一次」的写法等于永不恢复。
- **修法**：`loadFeeds()` 在重载前快照 `SubscriptionsScroll.firstIndex`，`applyFilter()` 之后
  `restoreScroll(keepIndex)` **每次**都按该下标滚回（越界则夹到 `filtered.length - 1`），
  删掉一次性标志。上游靠 `notifyDataSetChanged()` 保留位置，本端只能显式滚回去。
- **复验**：同一台设备、同一份数据，修复前跳顶 / 修复后停在原处（偏差 ≤1 行）。



