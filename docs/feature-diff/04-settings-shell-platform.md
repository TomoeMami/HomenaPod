# 04 — 设置、外壳与平台集成：上游 AntennaPod vs 鸿蒙移植版

- 上游：`antenna-repo`（commit `d05a58b`），sparse-checkout 含 `app/src/main`、`ui/`、`storage/preferences`；`system`、`event`、`storage:database`、`net:sync:*`、`playback:cast`、`app-wearos` **未检出**（见 `settings.gradle:19-61`），涉及未检出类的条目按"模块未检出，依据 UI/偏好调用点推断"标注。
- 移植版：`antennapod-harmony/entry/src/main/ets`（ArkTS）+ `resources`。
- 说明：上游 `ui/preferences/src/main/res/xml/` 实际有 **12** 个 `preferences*.xml`（任务描述的 11 个未含 `preferences_about.xml`）。

## 结论摘要

1. **设置面大幅收缩**：上游 12 个偏好屏、约 90 个设置项 + 设置内搜索（`MainPreferencesFragment.java:151-179`），移植版压成单页 `SettingsPage.ets` 的 6 个分类、约 20 个控件。用户界面设置里只剩「主题 + 语言」两项，`prefEpisodeCover` / `showTimeLeft` / `prefPlaybackTimeRespectsSpeed` / `prefThemeBlack` / `prefTintedColors` 全部缺失。
2. **导航外壳重写而非移植**：上游 `DrawerLayout + NavigationView + BottomNavigationView`（`MainActivity.java:143`、`NavDrawerFragment.java:147`）在移植版变成固定 5 项底栏 + 溢出菜单（`Index.ets:82-188`）。抽屉、抽屉项排序/隐藏、`prefDefaultPage`、`prefBottomNavigation`、`prefBackButtonOpensDrawer` 全部没有；`UserPreferences.getDefaultPage()`（`UserPreferences.ets:98`）是**定义但从未调用**的死代码。
3. **四个整块能力缺失**：家长控制、同步（gpodder/Nextcloud）、应用内评分、错误报告/崩溃上报，在移植版**零实现**；关于页（版本/贡献者/许可证/特别感谢/译者）也完全缺失。
4. **平台集成只保留了最核心三项**：通知（无通道分级）、后台刷新（WorkScheduler）、后台播放（AVSession）。桌面小部件、深链 `antennapod.org/deeplink/*`、快捷方式、Google Assistant actions、Android Auto、Wear OS、投屏均无对应实现。
5. **统计做了三标签但图表降级**：`StatsPage.ets:27-105` 对齐了 Subscriptions/Years/Downloads 三标签，但上游自绘 `PieChartView` / `BarChartView`（`PieChartView.java:1-173`、`BarChartView.java:1-162`）被等宽比例条替代；单订阅统计与「重置统计」缺失，Echo 年度回顾完全缺失。

## 逐项对比表

### 1. 设置入口与设置项

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 设置入口/主屏 | `app/.../preferences/MainPreferencesFragment.java:39-71`；`ui/preferences/src/main/res/xml/preferences.xml:2-79` | `pages/SettingsPage.ets:30-241`；入口 `pages/Index.ets:183-186` | 🔸 简化/替代 | 上游 11 个子屏入口（界面/播放/下载/同步/导入导出/通知/家长控制/项目组），移植版单页扁平滚动，无子屏、无返回栈标题 |
| 设置内搜索 | `MainPreferencesFragment.java:151-179`（`searchPreference`，含面包屑索引 9 个 xml） | 无 | ⬜ 缺失 | 移植版无设置搜索 |
| 偏好屏分发 | `PreferenceActivity.java:64-133`（`getPreferenceScreen` / `openScreen`，通知屏在 API26+ 跳系统设置） | 无（单页） | ⬜ 缺失 | 移植版无 PreferenceFragment 体系；通知项直接在本页开关 |
| 用户界面设置 | `preferences_user_interface.xml:1-102`；`UserInterfacePreferencesFragment.java:32-116` | `SettingsPage.ets:70-79`（仅主题行 + 语言行） | 🔸 简化/替代 | 上游 4 个分类 17 项，移植版 2 项 |
| 播放设置 | `preferences_playback.xml:1-95`；`PlaybackPreferencesFragment.java:38-110` | `SettingsPage.ets:81-116` | 🔸 简化/替代 | 上游 13 项（中断/控制/硬件键/队列），移植版 6 项，无头戴断开、硬件键、smart mark as played、follow queue、skip keeps episode |
| 下载设置 | `preferences_downloads.xml:1-55`；`DownloadsPreferencesFragment.java:48-86` | `SettingsPage.ets:118-140` | 🔸 简化/替代 | 上游含数据目录选择、代理、新单集动作、自动删除子屏；移植版仅刷新间隔 + Wi-Fi 开关 |
| 自动下载设置 | `preferences_autodownload.xml:2-26`；`ui/preferences/.../AutoDownloadPreferencesFragment.java:1-19` | `SettingsPage.ets:142-168` | 🔸 简化/替代 | 上游 4 项（全局/仅队列/集数上限/允许电池）；移植版 3 项（缺「仅加入队列」） |
| 自动删除设置 | `preferences_auto_deletion.xml:2-31`；`AutomaticDeletionPreferencesFragment.java:1-92` | `SettingsPage.ets:170-191`（仅 `prefAutoDelete` + 删除移出队列） | 🔸 简化/替代 | 缺 `prefAutoDeleteLocal`、`prefFavoriteKeepsEpisode`、`prefEpisodeCleanup` |
| 导入导出 | `preferences_import_export.xml:2-45`；`ImportExportPreferencesFragment.java:58-190`（数据库导入导出/自动备份/OPML/HTML/收藏） | `pages/OpmlPage.ets:254-322`（仅 OPML 导入导出） | 🔸 简化/替代 | 数据库备份/恢复、HTML 导出、收藏导出、自动备份全缺 |
| 通知设置 | `preferences_notifications.xml:2-19`；`ui/preferences/.../NotificationPreferencesFragment.java:1-27` | `SettingsPage.ets:193-204`（单开关 `prefEpisodeNotification`） | 🔸 简化/替代 | 上游是错误组（下载报告/同步错误）开关 + 系统通知设置跳转；移植版是新单集通知总开关 |
| 家长控制 | `preferences_parental_control.xml:2-12`；`ParentalControlPreferencesFragment.java:18-87` | 无 | ⬜ 缺失 | 见第 5 节 |
| 同步设置 | `preferences_synchronization.xml:2-30`；`SynchronizationPreferencesFragment.java:39-230` | 无 | ⬜ 缺失 | 见第 6 节 |
| 关于页 | `preferences_about.xml:2-28`；`about/AboutFragment.java:17-70` | 无 | ⬜ 缺失 | 见第 12 节 |
| 错误报告入口 | `preferences.xml:71-74`；`bugreport/BugReportFragment.java:1-199` | 无 | ⬜ 缺失 | 见第 11 节 |
| 文档/论坛/贡献链接 | `MainPreferencesFragment.java:112-123`（3 个外链） | 无 | ⬜ 缺失 | 移植版无外链打开能力 |
| 项目分类可见性/版权提示 | `MainPreferencesFragment.java:50-70`（按包名 hash 隐藏项目组、插入 GPL 提示） | 无 | ⬜ 缺失 | 移植版设置页无「项目」分类 |
| 设置变更即时生效 | `UserInterfacePreferencesFragment.java:45-51`（`ActivityCompat.recreate`） | `SettingsPage.ets:576-580,654-667`（`setColorMode` 即时） | 🔸 简化/替代 | 语言需冷启动（`SettingsPage.ets:586` 提示「重启生效」），主题即时生效 |
| 设置项搜索高亮 | `PreferenceActivity.java:150-164`（`onSearchResultClicked` / `result.highlight`） | 无 | ⬜ 缺失 | — |

### 2. 主题与外观

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 主题三选（系统/浅/深） | `ui/preferences/.../preference/ThemePreference.java:33-52`；`preferences_user_interface.xml:7-8` | `SettingsPage.ets:455-504`（`TagChip` 三选） | ✅ 对齐 | 上游用 3 张卡片 + 高程配色，移植版用胶囊；取值 0/1/2 一致（`SettingsPage.ets:15-17`） |
| 黑色主题 `prefThemeBlack` | `preferences_user_interface.xml:9-13`；`UserPreferences.java:48` | 无 | ⬜ 缺失 | 移植版无纯黑 AMOLED 主题 |
| 着色主题 `prefTintedColors` | `preferences_user_interface.xml:14-18`；`UserInterfacePreferencesFragment.java:51-54` | 无 | ⬜ 缺失 | 无 Material You 取色 |
| 深色资源 | 上游 `ui/common/.../ThemeSwitcher.java:1-58` + `values-night` | `resources/dark/element/color.json:1-96` | ✅ 对齐 | 双套色值资源，系统深色自动切换 |
| 设计令牌 | 上游散落于 `dimens.xml`/`styles.xml` | `common/DesignTokens.ets:6-60` | ➕ 移植版独有 | 统一 8vp 网格 + 字阶 + 圆角，上游无此集中层 |
| 集封面 `prefEpisodeCover` | `preferences_user_interface.xml:21-26`；`UserPreferences.java:55,313` | 无 | ⬜ 缺失 | 移植版无「用章节图作封面」开关 |
| 显示剩余时间 `showTimeLeft` | `preferences_user_interface.xml:27-32`；`UserInterfacePreferencesFragment.java:56-63` | 无 | ⬜ 缺失 | — |
| 时间受播放速度影响 | `preferences_user_interface.xml:33-37`；`UserPreferences.java:94,792` | 无 | ⬜ 缺失 | — |
| 通知外观开关 | `preferences_user_interface.xml:39-57`（`prefExpandNotify`/`prefPersistNotify`/`prefFullNotificationButtons`） | 无 | ⬜ 缺失 | 移植版通知不可展开/常驻/自定义按钮 |

### 3. 导航与外壳

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 主界面骨架 | `activity/MainActivity.java:143,579-591`（DrawerLayout + FragmentContainer + 底栏二选一） | `pages/Index.ets:29-157`（Tabs + 底栏） | 🔸 简化/替代 | 上游是抽屉/底栏可切换，移植版只有底栏 |
| 底部导航 | `ui/screen/drawer/BottomNavigation.java:33-177` | `Index.ets:82-149` + `components/BottomTabItem.ets:8-57` | 🔸 简化/替代 | 上游菜单由 `BottomNavigation.buildMenu()` 动态生成（`BottomNavigation.java:47-64`）；移植版硬编码 5 项，无角标外的动态性 |
| 底栏「更多」溢出 | `BottomNavigation.java:96-136`；`BottomNavigationMoreAdapter.java:1-35` | `Index.ets:159-188`（`bindMenu`） | ✅ 对齐 | 溢出项集合一致（下载/历史/收藏/统计/添加/设置） |
| 底栏未读角标 | `BottomNavigation.java:66-95,167-174` | `Index.ets:105-115,262-268` | ✅ 对齐 | 都只给「待处理」显示未读数 |
| 抽屉 | `NavDrawerFragment.java:147-510` | 无 | ⬜ 缺失 | 移植版无侧滑抽屉 |
| 抽屉项与计数 | `DrawerItem.java:7-58`；`NavListAdapter.java:1-348` | 无 | ⬜ 缺失 | — |
| 导航名称/图标表 | `NavigationNames.java:18-153` | `Index.ets:163-186` + `common/MenuIcons.ets:1-13` | 🔸 简化/替代 | 上游有 getDrawable/getLabel/getShortLabel/getBottomNavigationItemId 四张映射表 |
| `prefDefaultPage` | `preferences_user_interface.xml:59-65`；`UserPreferences.java:772-776` | `UserPreferences.ets:98-100`（**定义未使用**） | ⬜ 缺失 | 默认页恒为首页 Tab 0 |
| `prefBottomNavigation` | `preferences_user_interface.xml:66-70`；`MainActivity.java:143,591` | 无 | ⬜ 缺失 | 无法关闭底栏 |
| `prefHiddenDrawerItems` | `preferences_user_interface.xml:71-74`；`DrawerPreferencesDialog.java:14-93`；`UserPreferences.java:219-246` | 无 | ⬜ 缺失 | — |
| `prefBackButtonOpensDrawer` | `preferences_user_interface.xml:75-79`；`UserInterfacePreferencesFragment.java:118-120` | 无 | ⬜ 缺失 | — |
| 迷你播放条 | `ui/screen/playback/audio/ExternalPlayerFragment.java:1-192` | `components/MiniPlayer.ets:1-77`；`Index.ets:64-79` | ✅ 对齐 | 均常驻底栏之上，含标题/进度 |
| 标题栏 | `ui/common/ToolbarActivity.java:1-33`、`NavigationToolbarActivity.java:1-7` | `components/AppBar.ets:9-51` | 🔸 简化/替代 | 移植版统一 56vp + 返回 + trailing 插槽，无 Material 折叠/搜索栏 |
| 启动闪屏 | `activity/SplashActivity.java:1-49` | `EntryAbility.ets:60-89`（startWindowIcon 直接进 Index） | 🔸 简化/替代 | 无独立闪屏页 |

### 4. 滑动操作

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 滑动设置屏 | `preferences_swipe.xml:2-32`；`SwipePreferencesFragment.java:15-64`（7 个屏各自配置） | 无 | ⬜ 缺失 | 移植版无滑动动作设置 |
| 滑动动作框架 | `app/.../ui/swipeactions/SwipeActions.java:33-273`（ItemTouchHelper + 独立 SharedPreferences `SwipeActionsPrefs`） | `pages/FeedDetailPage.ets:157-158,407-428` | 🔸 简化/替代 | 仅订阅详情列表固定「标记已播 + 收藏」两个按钮，队列/收件箱/下载/历史/收藏页**无滑动** |
| 14 个滑动动作 | `ui/swipeactions/AddToQueueSwipeAction.java:1-54`、`RemoveFromInboxSwipeAction.java:1-45`、`StartDownloadSwipeAction.java:1-49`、`MarkFavoriteSwipeAction.java:1-43`、`RemoveFromFavoritesSwipeAction.java:1-43`、`TogglePlaybackStateSwipeAction.java:1-48`、`RemoveFromQueueSwipeAction.java:1-67`、`DeleteSwipeAction.java:1-50`、`RemoveFromHistorySwipeAction.java:1-52`、`MoveToTopSwipeAction.java:1-46`、`MoveToBottomSwipeAction.java:1-46`、`ShareSwipeAction.java:1-48`（注册表 `SwipeActions.java:38-44`） | 无 | ⬜ 缺失 | 移植版无动作注册表 |
| 滑动动作选择对话框 | `SwipeActionsDialog.java:1-224` | 无 | ⬜ 缺失 | — |
| 首次滑动提示 | `ShowFirstSwipeDialogAction.java:1-42` | 无 | ⬜ 缺失 | — |

### 5. 家长控制

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 家长控制开关 | `ParentalControlPreferencesFragment.java:31-45`；`preferences_parental_control.xml:4-6` | 无 | ⬜ 缺失 | — |
| 密码设置对话框 | `ParentalControlPreferencesFragment.java:53-86`（两次输入 + 空值/不一致校验） | 无 | ⬜ 缺失 | — |
| 密码验证对话框 | `ui/preferences/.../ParentalControlDialog.java:16-50` | 无 | ⬜ 缺失 | — |
| 订阅前需密码 | `preferences_parental_control.xml:8-10`（`prefParentalControlRequireSubscribe`） | 无 | ⬜ 缺失 | — |
| 入口可见性判定 | `MainPreferencesFragment.java:130-149`（Family Link 儿童设备 / DEBUG / 已设密码） | 无 | ⬜ 缺失 | — |

### 6. 同步

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 同步设置屏 | `ui/preferences/.../synchronization/SynchronizationPreferencesFragment.java:39-230`；`preferences_synchronization.xml:2-30` | 无 | ⬜ 缺失 | 无登录/手动同步/全量同步/登出 |
| gpodder.net 登录 | `synchronization/GpodnetAuthenticationFragment.java:1-322` | 无 | ⬜ 缺失 | `net:sync:gpoddernet` 模块未检出，依据 `SynchronizationPreferencesFragment.java:164-230` 的 `chooseProviderAndLogin` 推断 |
| Nextcloud 登录 | `synchronization/NextcloudAuthenticationFragment.java:1-123` | 无 | ⬜ 缺失 | 同上，调用点 `SynchronizationPreferencesFragment.java:209-210` |
| 认证对话框 | `synchronization/AuthenticationDialog.java:1-54` | 无 | ⬜ 缺失 | — |
| 凭据存储 | `storage/preferences/.../SynchronizationCredentials.java:1-60` | 无 | ⬜ 缺失 | 该文件已检出，移植版无对应类 |

### 7. 应用内语言

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 语言清单 | `app/src/main/res/xml/locale_config.xml:1-42`（39 种语言） | `resources/base/element/string.json` + `en_US` + `zh_CN` 各 1080 行 | 🔸 简化/替代 | 上游 39 语言，移植版仅 zh-Hans / en-US 两套 |
| 语言切换入口 | 上游走系统「应用语言」设置（`locale_config.xml` 声明），**设置页无语言项** | `SettingsPage.ets:507-556,582-587`（系统/中文/英文三胶囊 + `i18n.System.setAppPreferredLanguage`） | ➕ 移植版独有 | 移植版把语言选择做进设置页 |
| 语言生效时机 | 系统级 | `EntryAbility.ets:31-42`（冷启动应用） | 🔸 简化/替代 | 切换后需重启应用（`SettingsPage.ets:586` 明确提示） |

### 8. 平台集成

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 桌面小部件 | `ui/widget/PlayerWidget.java:1-108`、`WidgetConfigActivity.java:1-180`、`WidgetUpdater.java:1-260`、`WidgetUpdaterWorker.java:1-58`；`res/xml/player_widget_info.xml:1-12` | 无 | ⬜ 缺失 | 移植版无 FormExtensionAbility、无卡片定义 |
| 通知通道分级 | `ui/notifications/.../NotificationUtils.java:15-111`（7 通道 + 2 组） | `services/NotificationService.ets:84-117` | 🔸 简化/替代 | 移植版单条通知（id 1001），**无 slotType/通道分组**，用户无法按类关闭 |
| 通知权限申请 | `AndroidManifest.xml:10`（POST_NOTIFICATIONS）+ 系统弹窗 | `NotificationService.ets:33-50`（`requestEnableNotification`） | ✅ 对齐 | — |
| 通知栏播放控制 | `playback:service` + MediaSession（模块未检出） | `player/AvSessionBridge.ets:1-371` | 🔸 简化/替代 | AVSession 提供播放/暂停/上一集/下一集/收藏；无速度/睡眠定时/章节按钮 |
| 深链 | `AndroidManifest.xml:104-118`（`antennapod.org/deeplink`）+ `MainActivity.java:775-800`（`/deeplink/search`、`/deeplink/main`） | 无 | ⬜ 缺失 | `module.json5:27-36` 只有 `action.system.home`，无 uri 匹配 |
| 应用快捷方式 | `app/src/main/res/xml/shortcuts.xml:1-58`（队列/单集/订阅/刷新 4 个） | 无 | ⬜ 缺失 | — |
| Google Assistant actions | `app/src/main/res/xml/actions.xml:1-25`（OPEN_APP_FEATURE / GET_THING + 5 个实体） | 无 | ⬜ 缺失 | — |
| 快捷方式创建（固定订阅） | `activity/SelectSubscriptionActivity.java:1-142`（`CREATE_SHORTCUT`，`AndroidManifest.xml:272-278`） | 无 | ⬜ 缺失 | — |
| 外部打开 OPML | `activity/OpmlImportActivity.java:1-273`（SEND/VIEW + file/content/http/https，`AndroidManifest.xml:151-164`） | `pages/OpmlPage.ets:254-322`（应用内 `picker` 选文件） | 🔸 简化/替代 | 移植版不能接收外部 OPML 文件/链接 |
| Android Auto | `app/src/main/res/xml/automotive_app_desc.xml:1-4` + `AndroidManifest.xml:63-65` | 无 | ⬜ 缺失 | — |
| 投屏（Chromecast） | `playback:cast` **模块未检出**（`settings.gradle:41`）；调用点 `MainActivity.java:51`（`CastEnabledActivity`） | 无 | ⬜ 缺失 | 依调用点推断上游有投屏能力 |
| Wear OS | `app-wearos` **模块未检出**（`settings.gradle:20`） | 无 | ⬜ 缺失 | 仅知存在独立模块 |
| 媒体键/耳机按键 | `ui/app-start-intent/.../MediaButtonStarter.java:1-49`、`MainActivity.java` keyEvent、`PlaybackService.java:688-774`（keycode 处理，未检出模块） | `player/AvSessionBridge.ets:104-200`（AVSession 媒体控制）+ `player/MediaButtonPolicy.ets`（第 53 轮） | 🔸 简化/替代 | 移植版仍依赖系统媒体控制、不做按键可配置；但已补上「蓝牙来源的下一首/上一首 = 快进/快退」（靠 `CommandInfo.callerType === TYPE_BLUETOOTH`，API 22+；详见 `02-playback-audio.md`） |
| 权限声明 | `AndroidManifest.xml:6-14`（9 项） | `module.json5:47-63`（5 项） | 🔸 简化/替代 | 移植版缺 WAKE_LOCK/BOOT_COMPLETED/BLUETOOTH 对应能力 |
| 后台任务 | `MainActivity.java:53-54`（`DatabaseMaintenanceWorker`、`AutomaticDatabaseExportWorker`） | `work/WorkSchedulerManager.ets:1-42`、`work/RefreshWorkSchedulerExtensionAbility.ets:1-21` | 🔸 简化/替代 | 移植版只有定时刷新，无数据库维护/自动备份任务 |
| 启动意图参数 | `PreferenceActivity.java:34-61`（`OPEN_AUTO_DOWNLOAD_SETTINGS` / `OPEN_PLAYBACK_SETTINGS`） | 无 | ⬜ 缺失 | 移植版不能从外部直接打开某设置子屏 |

### 9. 统计与 Echo

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 统计三标签骨架 | `ui/statistics/.../StatisticsFragment.java:40-149`（ViewPager2 + TabLayoutMediator） | `pages/StatsPage.ets:27-105`（TagChip 切换） | ✅ 对齐 | 标签集合一致（订阅/年度/下载） |
| 订阅统计 | `statistics/subscriptions/SubscriptionStatisticsFragment.java:1-137` | `StatsPage.ets:109-`（`subscriptionsTab`） | 🔸 简化/替代 | 上游带 `StatisticsFilterDialog.java:1-141` 筛选，移植版无筛选 |
| 年度统计 | `statistics/years/YearsStatisticsFragment.java:1-97` | `StatsPage.ets`（`yearsTab`，`YearStat` 聚合） | 🔸 简化/替代 | — |
| 下载统计 | `statistics/downloads/DownloadStatisticsFragment.java:1-90` | `StatsPage.ets`（`downloadsTab`） | 🔸 简化/替代 | — |
| 饼图/柱状图 | `statistics/PieChartView.java:1-173`、`statistics/years/BarChartView.java:1-162` | `StatsPage.ets:19-23`（等宽比例条替代） | 🔸 简化/替代 | 自绘 Canvas 图表无 HarmonyOS 原生对应，降级为比例条 |
| 单订阅统计 | `statistics/feed/FeedStatisticsFragment.java:1-219`、`FeedStatisticsDialogFragment.java:1-51` | 无 | ⬜ 缺失 | — |
| 统计重置 | `StatisticsFragment.java:120-135` | 无 | ⬜ 缺失 | — |
| Echo 年度回顾 | `ui/echo/.../EchoActivity.java:30-154` + 8 个 screen（`IntroScreen`/`HoursPlayedScreen`/`QueueScreen`/`HoarderScreen`/`TimeReleasePlayScreen`/`ThanksScreen`/`FinalShareScreen`）+ 7 种背景 | 无 | ⬜ 缺失 | `StatisticsFragment.java:115` 的 Echo 入口亦无 |

### 10. 评分/评价

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 评分对话框 | `app/.../ui/screen/rating/RatingDialogFragment.java:1-79` | 无 | ⬜ 缺失 | — |
| 评分触发策略 | `RatingDialogManager.java:19-94`（安装 20 天后 + 累计播放 ≥15h + 最老记录 >20 天） | 无 | ⬜ 缺失 | 调用点 `MainActivity.java:579` |

### 11. 错误上报/崩溃处理

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 未捕获异常捕获 | `app/.../CrashReportExceptionHandler.java:7-20` | 无 | ⬜ 缺失 | — |
| RxJava 全局错误处理 | `app/.../RxJavaErrorHandlerSetup.java:9-37` | 无 | ⬜ 缺失 | 移植版无 RxJava 等价全局兜底 |
| 崩溃日志写入 | `system/.../CrashReportWriter`（**模块未检出**，依 `CrashReportExceptionHandler.java:5,17` 推断） | 无 | ⬜ 缺失 | — |
| 错误报告页 | `ui/preferences/.../bugreport/BugReportFragment.java:1-199` | 无 | ⬜ 缺失 | — |
| 环境信息/崩溃日志组装 | `bugreport/BugReportViewModel.java:26-204`（版本/系统/厂商/机型 + 崩溃日志 Markup） | 无 | ⬜ 缺失 | — |
| 日志设施 | `android.util.Log`（全仓） | `utils/Logger.ets:4-27`（hilog，domain 0x0000，前缀 `APod/`） | 🔸 简化/替代 | 移植版只有 4 级日志，无持久化、无崩溃落盘 |

### 12. 关于页/许可证/贡献者

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 关于页 | `ui/preferences/.../about/AboutFragment.java:17-70`；`preferences_about.xml:2-28` | 无 | ⬜ 缺失 | 设置页无「关于」入口 |
| 版本号 | `AboutFragment.java:35-40` | 无 | ⬜ 缺失 | — |
| 贡献者 | `about/ContributorsPagerFragment.java:1-96` | 无 | ⬜ 缺失 | — |
| 开发者 | `about/DevelopersFragment.java:1-67` | 无 | ⬜ 缺失 | — |
| 许可证 | `about/LicensesFragment.java:1-134`；`ui/preferences/src/main/assets/licenses.xml` | 无 | ⬜ 缺失 | 移植版无 licenses 资源 |
| 特别感谢 | `about/SpecialThanksFragment.java:1-77` | 无 | ⬜ 缺失 | — |
| 译者 | `about/TranslatorsFragment.java:1-57` | 无 | ⬜ 缺失 | — |
| 隐私政策外链 | `preferences_about.xml:18-21` | 无 | ⬜ 缺失 | — |
| NOTICE.md | 上游仓库根**仅有 LICENSE**（无 NOTICE.md） | 无 | ⬜ 缺失 | 任务书提及的 NOTICE.md 在上游不存在 |

## 设置项映射表

上游 preference key → 移植版键名（"无" = 未实现）。移植版键名取自 `prefs/UserPreferences.ets`。

| 上游 key | 上游 file:line | 移植版键名 | 说明 |
|---|---|---|---|
| `searchPreference` | `preferences.xml:7` | 无 | 设置搜索 |
| `prefScreenInterface` | `preferences.xml:15` | 无 | 子屏入口，移植版扁平化 |
| `prefScreenPlayback` | `preferences.xml:21` | 无 | 同上 |
| `prefScreenDownloads` | `preferences.xml:27` | 无 | 同上 |
| `prefScreenSynchronization` | `preferences.xml:33` | 无 | 同步整块缺失 |
| `prefScreenImportExport` | `preferences.xml:39` | 无 | 同上 |
| `notifications` | `preferences.xml:45` | 无 | 上游跳系统通知设置 |
| `prefScreenParentalControl` | `preferences.xml:50` | 无 | — |
| `prefDocumentation` | `preferences.xml:59` | 无 | 外链 |
| `prefViewForum` | `preferences.xml:63` | 无 | 外链 |
| `prefContribute` | `preferences.xml:67` | 无 | 外链 |
| `prefSendBugReport` | `preferences.xml:71` | 无 | — |
| `prefAbout` | `preferences.xml:75` | 无 | — |
| `prefTheme` | `preferences_user_interface.xml:8` | `prefTheme` | 0/1/2 语义一致（`UserPreferences.ets:25-32`） |
| `prefThemeBlack` | `preferences_user_interface.xml:11` | 无 | — |
| `prefTintedColors` | `preferences_user_interface.xml:16` | 无 | — |
| `prefEpisodeCover` | `preferences_user_interface.xml:23` | 无 | — |
| `showTimeLeft` | `preferences_user_interface.xml:29` | 无 | — |
| `prefPlaybackTimeRespectsSpeed` | `preferences_user_interface.xml:35` | 无 | — |
| `prefExpandNotify` | `preferences_user_interface.xml:43` | 无 | — |
| `prefPersistNotify` | `preferences_user_interface.xml:50` | 无 | — |
| `prefFullNotificationButtons` | `preferences_user_interface.xml:54` | 无 | — |
| `prefDefaultPage` | `preferences_user_interface.xml:62` | `prefDefaultPage`（**仅定义，未读取**） | `UserPreferences.ets:98-100` |
| `prefBottomNavigation` | `preferences_user_interface.xml:70` | 无 | — |
| `prefHiddenDrawerItems` | `preferences_user_interface.xml:72` | 无 | — |
| `prefBackButtonOpensDrawer` | `preferences_user_interface.xml:76` | 无 | — |
| `prefGlobalDefaultSortedOrder` | `preferences_user_interface.xml:83` | 无 | 全局默认排序（另有域负责） |
| `prefSwipe` | `preferences_user_interface.xml:87` | 无 | 滑动设置入口 |
| `prefStreamOverDownload` | `preferences_user_interface.xml:92` | `prefStreamOverDownload` | ✅ 对齐 |
| `prefDownloadsButtonAction` | `preferences_user_interface.xml:98` | 无 | — |
| `prefPauseOnHeadsetDisconnect` | `preferences_playback.xml:9` | 无（近似 `prefAutoResumeAfterInterrupt`） | 语义不等价 |
| `prefUnpauseOnHeadsetReconnect` | `preferences_playback.xml:16` | 无 | — |
| `prefUnpauseOnBluetoothReconnect` | `preferences_playback.xml:24` | 无 | — |
| `prefPlaybackFastForwardDeltaLauncher` | `preferences_playback.xml:32` | `prefFastForwardSecs` | 键名不同，语义一致 |
| `prefPlaybackRewindDeltaLauncher` | `preferences_playback.xml:36` | `prefRewindSecs` | 键名不同，语义一致 |
| `prefPlaybackSpeedLauncher` | `preferences_playback.xml:40` | `prefPlaybackSpeed` | 移植版用循环切换（`SettingsPage.ets:589-599`） |
| `prefHardwareForwardButton` | `preferences_playback.xml:50` | 无 | — |
| `prefHardwarePreviousButton` | `preferences_playback.xml:57` | 无 | — |
| `prefEnqueueLocation` | `preferences_playback.xml:67` | `prefEnqueueLocation` | ✅ 键名一致 |
| `prefEnqueueDownloaded` | `preferences_playback.xml:72` | 无 | — |
| `prefFollowQueue` | `preferences_playback.xml:78` | 无 | — |
| `prefSmartMarkAsPlayedSecs` | `preferences_playback.xml:85` | 无 | — |
| `prefSkipKeepsEpisode` | `preferences_playback.xml:91` | 无 | — |
| `prefChooseDataDir` | `preferences_downloads.xml:8` | 无 | 移植版数据目录固定 |
| `prefAutoUpdateIntervall` | `preferences_downloads.xml:14` | `prefAutoUpdateInterval`（**键名不同**） | `UserPreferences.ets:67-74` |
| `prefNewEpisodesAction` | `preferences_downloads.xml:21` | 无 | — |
| `prefAutoDownloadSettings` | `preferences_downloads.xml:27` | 无 | 子屏入口 |
| `prefAutoDeleteScreen` | `preferences_downloads.xml:31` | 无 | 子屏入口 |
| `prefDeleteRemovesFromQueue` | `preferences_downloads.xml:37` | `prefDeleteRemovesFromQueue` | ✅ 对齐 |
| `prefMobileUpdateTypes` | `preferences_downloads.xml:47` | `prefMobileUpdateTypes`（**仅定义，未读取**） | `UserPreferences.ets:56-65` |
| `prefProxy` | `preferences_downloads.xml:51` | 无 | 无代理设置 |
| `prefEnableAutoDl` | `preferences_autodownload.xml:6` | `prefAutoDownload`（**键名不同**） | `UserPreferences.ets:150-157` |
| `prefEnableAutoDlQueue` | `preferences_autodownload.xml:11` | 无 | — |
| `prefEpisodeCacheSize` | `preferences_autodownload.xml:17` | `prefEpisodeCacheSize`（**仅定义，未读取**）/ 实际用 `prefEpisodeCacheCount` | `UserPreferences.ets:85-87` vs `178-185` |
| `prefEnableAutoDownloadOnBattery` | `preferences_autodownload.xml:22` | `prefAutoDownloadChargingOnly` | 语义相反（上游=允许电池，移植版=仅充电） |
| `prefAutoDelete` | `preferences_auto_deletion.xml:8` | `prefAutoDelete` | ✅ 对齐 |
| `prefAutoDeleteLocal` | `preferences_auto_deletion.xml:14` | 无 | — |
| `prefFavoriteKeepsEpisode` | `preferences_auto_deletion.xml:20` | 无 | — |
| `prefEpisodeCleanup` | `preferences_auto_deletion.xml:26` | 无 | — |
| `prefDatabaseExport` | `preferences_import_export.xml:8` | 无 | — |
| `prefAutomaticDatabaseExport` | `preferences_import_export.xml:13` | 无 | — |
| `prefDatabaseImport` | `preferences_import_export.xml:18` | 无 | — |
| `prefOpmlExport` | `preferences_import_export.xml:26` | 对应 `OpmlPage.ets:306-322`（无 key） | 功能有，偏好键无 |
| `prefOpmlImport` | `preferences_import_export.xml:30` | 对应 `OpmlPage.ets:254-303`（无 key） | 同上 |
| `prefHtmlExport` | `preferences_import_export.xml:37` | 无 | — |
| `prefFavoritesExport` | `preferences_import_export.xml:41` | 无 | — |
| `prefShowDownloadReport` | `preferences_notifications.xml:10` | 无 | — |
| `pref_gpodnet_notifications` | `preferences_notifications.xml:15` | 无 | — |
| `prefParentalControlEnabled` | `preferences_parental_control.xml:4` | 无 | — |
| `prefParentalControlRequireSubscribe` | `preferences_parental_control.xml:8` | 无 | — |
| `prefSwipeQueue` | `preferences_swipe.xml:5` | 无 | — |
| `prefSwipeInbox` | `preferences_swipe.xml:9` | 无 | — |
| `prefSwipeEpisodes` | `preferences_swipe.xml:13` | 无 | — |
| `prefSwipeDownloads` | `preferences_swipe.xml:17` | 无 | — |
| `prefSwipeHistory` | `preferences_swipe.xml:21` | 无 | — |
| `prefSwipeFavorites` | `preferences_swipe.xml:25` | 无 | — |
| `prefSwipeFeed` | `preferences_swipe.xml:29` | 无 | — |
| `preference_synchronization_description` | `preferences_synchronization.xml:7` | 无 | — |
| `pref_gpodnet_setlogin_information` | `preferences_synchronization.xml:11` | 无 | — |
| `pref_synchronization_sync` | `preferences_synchronization.xml:17` | 无 | — |
| `pref_synchronization_force_full_sync` | `preferences_synchronization.xml:22` | 无 | — |
| `pref_synchronization_logout` | `preferences_synchronization.xml:27` | 无 | — |
| `about_version` | `preferences_about.xml:8` | 无 | — |
| `about_contributors` | `preferences_about.xml:13` | 无 | — |
| `about_privacy_policy` | `preferences_about.xml:18` | 无 | — |
| `about_licenses` | `preferences_about.xml:23` | 无 | — |

**移植版额外键（上游无对应 preference key）**：`prefLastPlayedFeedMediaId`（`UserPreferences.ets:89-96`）、`prefEpisodeNotification`（`104-111`）、`prefQueueLocked`（`113-120`）、`prefRepeatMode`（`123-130`）、`prefAutoDownloadWifiOnly`（`159-166`）、`prefEpisodeCacheCount`（`178-185`）、`prefStreamConfirmMobile`（`205-212`）、`prefAutoResumeAfterInterrupt`（`214-221`）、`prefSleepTimerMinutes`（`223-230`）、`prefSleepFadeOut`（`232-239`）、`prefSleepStopAtChapterEnd`（`241-248`）、`prefAppLanguage`（`260-267`）、`prefHomeSectionOrder` / `prefHomeHiddenSections`（第 40 轮，对齐上游 `PrefHomeSectionOrder` / `PrefHomeSectionsString`）、`prefSubscriptionColumns`（`280-287`）、`prefSubscriptionShowTitles`（`290-297`）、`prefSkipSilence`（`43-45`，**定义未使用**）。

## 关键行为差异

1. **设置信息架构：11 子屏 → 1 页扁平**。上游靠 `PreferenceActivity.openScreen()` 维护返回栈与每屏标题（`PreferenceActivity.java:118-133`、`getTitleOfPage` `91-116`）；移植版全部塞进一个 `Scroll`，设置项一多就靠滚动，且失去面包屑与深链定位能力。
2. **`prefTheme` 生效方式不同**：上游改主题后 `ActivityCompat.recreate(getActivity())` 重建 Activity（`UserInterfacePreferencesFragment.java:45-51`）；移植版直接 `applicationContext.setColorMode()`（`SettingsPage.ets:654-667`），并对异常静默吞掉，切换失败时用户无感知。
3. **语言切换是移植版反向增强、但需冷启动**：上游根本没有设置页语言项（依赖系统 per-app language + `locale_config.xml`）；移植版提供三选，但 `i18n.System.setAppPreferredLanguage` 需重启（`SettingsPage.ets:586`），且只支持中/英两套资源。
4. **底栏与抽屉互斥关系消失**：上游 `prefBottomNavigation=false` 时显示抽屉并让返回键开抽屉（`MainActivity.java:143`、`UserInterfacePreferencesFragment.java:104-120`）；移植版恒为底栏，`prefDefaultPage` 虽被定义却从不读取（`UserPreferences.ets:98-100`），默认页设置形同虚设。
5. **滑动操作从"每屏可配"降为"单屏固定"**：上游每个列表页用独立 `SwipeActionsPrefs` 存左右滑动动作（`SwipeActions.java:34-36,77-79`）；移植版只在 `FeedDetailPage` 给了 2 个固定按钮（`FeedDetailPage.ets:407-428`），队列/收件箱/下载/历史/收藏页完全没有滑动交互。
6. **通知从"分通道"降为"单条"**：上游 7 个通道分 2 组、按重要级（`NotificationUtils.java:15-111`），用户可单独关闭；移植版所有通知共用 id 1001 且未设置 `slotType`（`NotificationService.ets:94-103`），无法分类管理，连续通知会互相覆盖。
7. **自动下载判定语义反转**：上游 `prefEnableAutoDownloadOnBattery` = 「允许在电池供电时下载」（`preferences_autodownload.xml:22-24`），移植版 `prefAutoDownloadChargingOnly` = 「仅充电时下载」（`UserPreferences.ets:168-175`、`AutoDownloadService.ets:62`），默认值与行为均不同。
8. **自动刷新键名不兼容**：上游 `prefAutoUpdateIntervall`（`UserPreferences.java:100`）vs 移植版 `prefAutoUpdateInterval`（`UserPreferences.ets:68`），拼写修正导致无法从上游偏好迁移。
9. **统计图表降级为比例条**：上游 `PieChartView`（173 行）与 `BarChartView`（162 行）是自绘 Canvas 图表，移植版用等宽比例条（`StatsPage.ets:19-23` 注释明确说明），视觉信息量下降。
10. **崩溃/错误链路整体缺失**：上游三层兜底（`CrashReportExceptionHandler` + `RxJavaErrorHandlerSetup` + `CrashReportWriter`）与用户可见的 `BugReportFragment`；移植版只有 `Logger.ets` 的 hilog 输出，崩溃后无落盘、无上报入口。

## 移植版独有

| 能力 | 移植版实现(file:line) | 说明 |
|---|---|---|
| 集中式设计令牌 | `common/DesignTokens.ets:6-60` | 8vp 网格/字阶/圆角/组件高度统一常量层 |
| 设置页语言三选 | `SettingsPage.ets:507-556,582-587` | 上游无此设置项 |
| 主题即时切换（无需重建） | `SettingsPage.ets:654-667` | 直接调用 `setColorMode` |
| 睡眠定时器偏好三键 | `UserPreferences.ets:223-248` | `prefSleepTimerMinutes` / `prefSleepFadeOut` / `prefSleepStopAtChapterEnd` |
| 队列锁定 / 循环模式偏好 | `UserPreferences.ets:113-130` | `prefQueueLocked` / `prefRepeatMode` |
| 首页区块顺序/显隐偏好 | `UserPreferences.ets:299-343` | `prefHomeSectionOrder` / `prefHomeHiddenSections`（第 40 轮起对齐上游 `HomePreferences` 的两个键；原 `prefHomeBlock_*` 已移除） |
| 订阅页列数/标题偏好 | `UserPreferences.ets:280-297` | `prefSubscriptionColumns` / `prefSubscriptionShowTitles` |
| 移动流量二次确认 | `UserPreferences.ets:205-212`；`FeedDetailPage.ets:887` | `prefStreamConfirmMobile` |
| 统一的 AppBar 组件 | `components/AppBar.ets:9-51` | 上游用多个 Activity 基类 |
| 溢出菜单统一 Builder | `Index.ets:159-188` + `components/OverflowButton.ets` | — |

## 存疑/需进一步核实

1. **`prefSkipSilence` / `getEpisodeCacheSizeMb` / `getMobileUpdateAllowed` / `getDefaultPage` 是否真的无人调用**：本次用 `grep` 在 `entry/src/main/ets` 全量搜索，仅命中定义处；若后续有页面通过字符串拼 key 读取，需复核。
2. **移植版主题切换对 `dark` 资源的实际影响**：`setColorMode` 只影响系统深浅色；`prefTheme` 与 `resources/dark/element/color.json` 的联动未在代码中显式验证（需真机确认）。
3. **`prefMobileUpdateTypes` 的写入方**：`setMobileUpdateAllowed()` 未被调用，但 `UserPreferences.ets:57` 读取的默认值是 `'wifi_only'`；上游该键的取值域（`wifi_only` / `wifi_and_mobile` / `wifi_and_mobile_roaming`？）未在本域展开，建议由网络/下载域复核。
4. **投屏与 Wear OS 的能力范围**：`playback:cast`（`settings.gradle:41`）与 `app-wearos`（`settings.gradle:20`）**模块未检出**，本文仅依 `MainActivity.java:51`（`CastEnabledActivity`）与模块清单推断存在，具体功能清单需检出后确认。
5. **`CrashReportWriter` 与 `net:sync:*` 的接口细节**：模块未检出，本文只标注了调用点与缺失状态，未评估移植工作量。
6. **通知通道对应关系**：HarmonyOS 侧未设置 `slotType`，是否需要用 `notificationManager.addSlot()` 建立等价分组（上游 7 通道 / 2 组）尚未验证。
7. **`OpmlImportActivity` 的 SEND/VIEW 之外是否还有 `intent-filter` 未覆盖**：`AndroidManifest.xml:151-164` 有 4 种 scheme，移植版仅应用内选文件，外部唤起能力为零。
8. **上游 `preferences.xml` 是否还有 flavor 变体**：本次只检查了 `ui/preferences/src/main/res/xml/`，`play`/`free` 等 flavor 目录未逐一确认。
