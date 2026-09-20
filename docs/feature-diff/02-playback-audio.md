# 02 · 播放与音频域差异（上游 vs 鸿蒙移植版）

- 上游基线：`antenna-repo/`（浅克隆，sparse-checkout 仅 `app/src/main`、`ui/`、`storage/preferences`）
- 移植版：`antennapod-harmony/entry/src/main/ets`
- 状态：`✅ 对齐` · `🔸 简化/替代` · `⬜ 缺失` · `➕ 移植版独有`
- **未检出模块**：`playback:base`、`playback:service`、`model`、`storage:database`、`parser:transcript`、`net:download:service`（见 `antenna-repo/.git/info/sparse-checkout`）。凡涉及 `PlaybackService`/`PlaybackServiceMediaPlayer`/`DBWriter`/`PlaybackServiceTaskManager`/`TranscriptParser` 的结论，均标注「模块未检出，依据 UI 调用点推断」。

## 结论摘要

1. **播放页是「单页 + 弹层」重写**，控制项齐全（倍速/快退/播放/快进/下一集），但封面只画占位图标、进度条退化为普通 `Slider`（无章节分隔线/二级缓冲/拖动浮层），`CoverFragment`/`ItemDescriptionFragment`/`NoRelayoutTextView` 的图片与 WebView 富文本能力丢失。
2. **倍速是离散档位**（`[0.5,0.75,1.0,1.25,1.5,1.75,2.0]`）而非上游 0.5–4.0 连续滑杆 + 用户自定义预设；**跳过静音整条链路缺失**（仅剩一个无调用点的 `getSkipSilence()`）。
3. **耳机/蓝牙中断已补齐上游三条偏好**（第 49 轮）：`prefPauseOnHeadsetDisconnect`（默认开）、`prefUnpauseOnHeadsetReconnect`（默认开）、`prefUnpauseOnBluetoothReconnect`（默认关）均已落库并有设置页「中断」入口；旧的合并开关 `prefAutoResumeAfterInterrupt` 保留，现在只管**音频焦点恢复**这一条路径。断开暂停的**主路径**是 AVPlayer 的 `audioOutputDeviceChangeWithInfo`（`REASON_OLD_DEVICE_UNAVAILABLE`）而不是 `audioInterrupt`——官方《响应输出设备变更时合理暂停》把处理权交给应用，系统不代应用暂停（见下表该行与「关键行为差异」2、12）。另有两条**移植版独有**的补充：**蓝牙断开补偿回退**（第 55 轮，暂停后把进度往回拉 5 秒，设置页可调，见下表与「关键行为差异」13）与**硬件按键重映射**（第 53 轮）：蓝牙来源的「下一首 / 上一首」按上游 `getHardwareForwardButton`/`getHardwarePreviousButton` 的默认值走快进 / 快退，但鸿蒙侧靠 `CommandInfo.callerType` 而不是 keycode，且不可配置（见下表与「关键行为差异」11）。
4. **转录/字幕、视频播放、画中画三块整体缺失**：转录仅落库 `podcast:transcript` 的 URL/type（`parser/FeedParser.ets:82-91`），无解析器、无 UI；视频仅列表角标。
5. **后台播放保障已闭合**：`BackgroundPlaybackGuard.setContext()` 由 `entryability/EntryAbility.ets:31` 注入；长时任务的**启停由播放器驱动** —— `PlayerManager.ets:209` 在真正开始播放后调 `start()`（`play()` → `startBackgroundTask()`，幂等），`release()` 与播放错误时调 `stop()`（`PlayerManager.ets:219`），`module.json5:24-25` 声明的 `backgroundModes: audioPlayback` 因此被激活。（此前「全工程从未调用 `start()`」的描述已过期。）
6. **章节来源被砍到只剩数据库**：无 `podcast:chapters` URL 拉取、无 ID3/OGG/M4A 内嵌章节解析（`ChapterUtils`），无上一/下一章节按钮、无章节图片。
7. **队列语义简化**：「连续播放 followQueue」「保持排序」「入队已下载」「智能标记已播」「跳过保留单集」五项偏好缺失，`PlaybackOrchestrator` 无条件连播。
8. **睡眠定时器是两套不同产品**：移植版有「章节末停止 + 渐弱音量」（上游没有），但缺上游的「按集数计时、自动启用时段、延长按钮、分钟/集数切换」。
9. **默认值对齐项**：快进 30s / 快退 10s、睡眠默认 15 分钟、摇一摇重置默认开；但 `prefDeleteRemovesFromQueue` 默认值双方相反。

## 逐项对比表

| 功能 | 上游实现(file:line) | 移植版实现(file:line) | 状态 | 差异说明 |
|---|---|---|---|---|
| 播放页整体结构 | `app/src/main/res/layout/audioplayer_fragment.xml:1-286`；`ui/screen/playback/audio/AudioPlayerFragment.java:110-166` | `pages/PlayerPage.ets:51-286` | 🔸 简化/替代 | 上游为 Toolbar + ViewPager2 双页（封面页/详情页）；移植版单页滚动 + 底部弹层，无 ViewPager 滑动 |
| 封面/章节图 | `audio/CoverFragment.java:318-340`（Glide 载封面/章节图/fallback） | `pages/PlayerPage.ets:122-132` | 🔸 简化/替代 | 移植版仅 `sys.symbol.music` 占位图标，不加载任何图片；尺寸按屏宽 clamp（`PlayerPage.ets:585-591`） |
| 播放/暂停按钮 | `ui/screen/playback/PlayButton.java:31-51` | `pages/PlayerPage.ets:208-227` | 🔸 简化/替代 | 上游为播放/暂停矢量动画 + 内容描述；移植版静态图标，状态靠 1s 轮询刷新 |
| 进度条（章节分隔） | `audio/ChapterSeekBar.java:55-147`；`AudioPlayerFragment.java:168-187` | `pages/PlayerPage.ets:172-183` | 🔸 简化/替代 | 上游自绘章节分隔线/当前章节高亮/二级缓冲；移植版普通 `Slider` |
| 拖动位置/章节浮层 | `audioplayer_fragment.xml:51-79`；`AudioPlayerFragment.java:422-462` | — | ⬜ 缺失 | 无 `cardViewSeek`/`txtvSeek`，拖动时不显示章节标题与目标时间 |
| 剩余时间切换 | `AudioPlayerFragment.java:265-276,394-403` | `pages/PlayerPage.ets:184-192` | ⬜ 缺失 | 上游点右侧时间可在「总时长/剩余」切换并持久化；移植版固定总时长 |
| 位置按倍速换算 | `AudioPlayerFragment.java:378-382`（`TimeSpeedConverter`） | — | ⬜ 缺失 | 上游位置/时长按倍速折算显示；移植版直接显示毫秒 |
| 缓冲进度/加载指示 | `AudioPlayerFragment.java:358-370`（`BufferUpdateEvent`） | — | ⬜ 缺失 | 无 `progLoading`，无二级缓冲进度 |
| 音频轨道选择 | `ui/screen/playback/PlaybackControlsDialog.java:70-138` | — | ⬜ 缺失 | 上游可切多音轨（`TRACK_TYPE_AUDIO`）；移植版无 UI/无 API 调用 |
| 倍速档位 | `PlaybackSpeedSeekBar.java:69-82`（滑杆 max=70 → 0.5–4.0 连续，见 `res/layout/playback_speed_seek_bar.xml`）；`VariableSpeedDialog.java:120-128` | `player/PlayerManager.ets:38,212-232` | 🔸 简化/替代 | 移植版 7 档离散；`toPlaybackSpeed` 就近取档，>2.0 全部落 2.0（`PlayerManager.ets:228-231`） |
| 倍速自定义预设 | `VariableSpeedDialog.java:158-201`；`UserPreferences.java:473-475,645-654` | — | ⬜ 缺失 | 档位硬编码，不可增删 |
| 倍速优先级（临时>feed>全局） | `ui/episodes/PlaybackSpeedUtils.java:17-35`；`PlaybackPreferences.java:116-118` | `player/PlayerManager.ets:103-108` | 🔸 简化/替代 | 无「当前单集临时倍速」层；有 feed 级用 feed，否则用全局默认 |
| 播放页改速写回全局 | `AudioPlayerFragment.java:279-282`（仅刷新 UI） | `pages/PlayerPage.ets:810-821` | ➕ 移植版独有 | `cycleSpeed()` 同步 `setDefaultPlaybackSpeed`，语义更强 |
| 跳过静音 | `VariableSpeedDialog.java:143-154`；`PlaybackSpeedUtils.java:40-59`；`ui/screen/feed/preferences/FeedSettingsPreferenceFragment.java:415-436` | `prefs/UserPreferences.ets:43-45`（仅 getter，无调用点）；`pages/FeedSettingsPage.ets:187-188` | ⬜ 缺失 | UI 直接标注「不支持」，全局/每 feed 开关均无效 |
| 快进/快退秒数默认值 | `UserPreferences.java:582-588`（30s / 10s） | `prefs/UserPreferences.ets:132-148`（30 / 10） | ✅ 对齐 | 默认值与键名一致 |
| 快进/快退修改入口 | `ui/screen/feed/preferences/SkipPreferenceDialog.java:18-59`；`AudioPlayerFragment.java:199-203,228-232`（长按按钮） | `pages/SettingsPage.ets:89-101,563-608` | 🔸 简化/替代 | 改为设置页数字输入框，**播放页长按改秒数缺失**；无 `seek_delta_values` 固定选项列表 |
| 每 Feed 跳片头/片尾 | `ui/screen/feed/preferences/FeedPreferenceSkipDialog.java:14-45` | `pages/FeedSettingsPage.ets:177-185,548-551`；`player/PlayerManager.ets:93-99,313-327` | ✅ 对齐 | 弹窗改行内输入；跳片尾用 `timeUpdate` 检测，每集只触发一次 |
| 硬件按键重映射 | `preferences_playback.xml:45-60`；`UserPreferences.java:409-417`；`PlaybackService.java:728-757`（未检出模块，取自上游 `develop` 源码） | `player/AvSessionBridge.ets:104-200`；`player/MediaButtonPolicy.ets` | 🔸 简化/替代 | 上游按 keycode 重映射：耳机来的 `KEYCODE_MEDIA_NEXT`→`getHardwareForwardButton()`（默认 `KEYCODE_MEDIA_FAST_FORWARD` = 快进 `fastForwardSecs`，默认 30s）、`KEYCODE_MEDIA_PREVIOUS`→`getHardwarePreviousButton()`（默认 `KEYCODE_MEDIA_REWIND` = 快退 `rewindSecs`，默认 10s），通知卡片上的同名按钮仍是「切下一集 / 回到开头」。鸿蒙侧没有 keycode，改用 AVSession 的 `CommandInfo.callerType === TYPE_BLUETOOTH`（API 22+）判定「命令来自蓝牙设备」；**不做按键可配置**（上游的 `keycodes.xml` 四条选项无对应 UI）。两处边界（第 53 轮用户要求）：结尾前 10s 内「下一首」改判为下一集、开头 2s 内「上一首」保持回到开头 |
| 耳机断开暂停 | `ui/preferences/src/main/res/xml/preferences_playback.xml:5-11`；`UserPreferences.java:397-399`（默认 true）；`PlaybackService.BecomingNoisyReceiver`（`ACTION_AUDIO_BECOMING_NOISY` → 暂停） | `player/OutputDevicePolicy.ets:64-66,84-86`；`player/PlayerManager.ets:491-507`；`prefs/UserPreferences.ets:398-403` | ✅ 对齐 | **第 49 轮对齐、第 54 轮补顺序缺陷**。鸿蒙侧没有 `ACTION_AUDIO_BECOMING_NOISY` 广播，改订阅 AVPlayer 的 `audioOutputDeviceChangeWithInfo`（API 11+）：`REASON_OLD_DEVICE_UNAVAILABLE` → 自动暂停（官方指引明确「应用程序应考虑暂停」，听书/音乐/视频场景均建议暂停），`audioInterrupt` 仅作兜底。暂停前提是「用户本意是在播」（`playIntent`），用户自己按过暂停时不打扰；**两条回调到达顺序不保证，两种顺序已收敛到同一结论**（见「关键行为差异」12） |
| 耳机/蓝牙重连继续 | `preferences_playback.xml:12-27`；`UserPreferences.java:401-407`（耳机 true、蓝牙 false） | `prefs/UserPreferences.ets:406-423`；`player/OutputDevicePolicy.ets:99-113`；`player/PlayerManager.ets:509-520` | ✅ 对齐 | **第 49 轮对齐**。耳机重连默认恢复、蓝牙重连默认不恢复（蓝牙可能在口袋里连上了却没人听），设置页「中断」分类可分别开关。恢复只发生在「本次暂停确实由设备丢失造成」（`pauseCause === DEVICE`）时，焦点恢复 / 用户手动暂停 / 睡眠定时器都不越权；扬声器、HDMI 等非耳机设备接入永不恢复 |
| 蓝牙断开后回退几秒 | 上游无此功能 | `player/OutputDevicePolicy.ets:138-164`；`player/PlayerManager.ets:206-250,311-350,555-590`；`player/ProgressPersister.ets:14-32`；`prefs/UserPreferences.ets:427-456`；`pages/SettingsPage.ets:218-240,1030-1037` | ➕ 移植版独有 | **第 55 轮**（用户要求：蓝牙断开有延迟，自动暂停的同时把播放进度往回调 5 秒左右）。只对**蓝牙**回退（有线拔出瞬间停声、无需补偿），设置页「中断」分类给开关 + 秒数（默认开 / 5 秒，挂在「断开时暂停」之下）。判定「下线的是不是蓝牙」不能只看事件：`AudioStreamDeviceChangeInfo.devices` 是**变更之后**的列表（`preDevices` 需 API 26，本工程 compatibleSdkVersion=14），故在 `play()` 时用 `getPreferredOutputDeviceForRendererInfoSync` 采样「本流此刻的输出设备」并在每次变更后更新记录。顺序为**先暂停再 seek**（否则这几秒会从扬声器重放），回退后的位置经 `PLAYBACK_SEEKED` 事件由 `ProgressPersister.save(true, position)` 落盘 |
| 音频中断 duck/unduck | 模块未检出（`playback:service`），依据焦点处理调用点推断 | `player/PlayerManager.ets:345-350` | ➕ 移植版独有 | 抢占时压到 0.3，恢复时按 `volumeAdaption` 还原 |
| 睡眠定时器 | `ui/screen/playback/SleepTimerDialog.java:150-271,463-477` | `pages/PlayerPage.ets:455-578`；`player/SleepTimer.ets:27-55` | 🔸 简化/替代 | 移植版固定 5/10/15/30/45/60 分钟 + 自定义；上游为分钟/集数双模式 + 任意输入 |
| 睡眠定时器：按集数计时 | `SleepTimerDialog.java:150-158,471-476`；`storage/preferences/SleepTimerType.java:3-6` | — | ⬜ 缺失 | 无 EPISODES 模式，无队列剩余集数提示（`SleepTimerDialog.java:92-108,346-356`） |
| 睡眠定时器：自动启用时段 | `SleepTimerDialog.java:204-234,422-460`；`SleepTimerPreferences.java:86-132` | — | ⬜ 缺失 | 无 autoEnable / from-to 时间区间 |
| 睡眠定时器：延长按钮 | `SleepTimerDialog.java:407-420`（+5/+10/+30 分或 +1/+2/+3 集） | — | ⬜ 缺失 | 无 extend 语义 |
| 睡眠定时器：章节末停止 | 上游无此功能 | `pages/PlayerPage.ets:747-771`；`player/SleepTimer.ets:40-47,80-83` | ➕ 移植版独有 | 到点后由页面 1s 轮询判定章节边界再暂停 |
| 睡眠定时器：渐弱音量 | 上游无此功能 | `player/SleepTimer.ets:8,121-133` | ➕ 移植版独有 | 最后 30s 线性降到 0.05 下限；回调由 `PlaybackOrchestrator.ets:34-36` 注入 |
| 摇一摇重置倒计时 | `storage/preferences/SleepTimerPreferences.java:78-84`（默认 true）；`SleepTimerDialog.java:212-217` | `player/ShakeDetector.ets:16-61`；`pages/PlayerPage.ets:790-802` | 🔸 简化/替代 | 移植版常开、无开关；阈值 25 m/s²、2s 去抖 |
| 睡眠到点震动 | `SleepTimerPreferences.java:70-76`（默认 false，可关） | `player/SleepTimer.ets:135-145`（无条件震动 300ms） | 🔸 简化/替代 | 移植版不可关闭 |
| 章节数据来源 | `ui/chapters/src/main/java/.../ChapterUtils.java:51-136`（DB + podcast:chapters URL + ID3/OGG/M4A） | `db/repositories/ChapterRepository.ets:8-25`（仅 `SimpleChapters` 表） | ⬜ 缺失 | 无 `loadChaptersFromUrl`（`ChapterUtils.java:246-258`）与内嵌章节解析；`parser/FeedParser.ets` 未解析 `podcast:chapters` |
| 章节列表 UI | `ui/screen/chapter/ChaptersFragment.java:69-98,176-189`（高亮/自动滚动/刷新） | `pages/PlayerPage.ets:356-414` | 🔸 简化/替代 | 移植版简单列表 + 点击 seek；无高亮/自动滚动/强制刷新；空章节上游会 dismiss + Toast（`ChaptersFragment.java:160-162`） |
| 上一/下一章节按钮 | `audio/CoverFragment.java:112-113,248-277` | — | ⬜ 缺失 | 封面无章节导航控件 |
| 章节图片 | `CoverFragment.java:331-340`（`EmbeddedChapterImage`） | — | ⬜ 缺失 | 无内嵌章节图提取与展示 |
| 转录/字幕 | `TranscriptDialogFragment.java:172-195`；`TranscriptAdapter.java:28,72-135`；`ui/transcript/.../TranscriptUtils.java:23-91`；`parser:transcript`（未检出） | 仅 `parser/FeedParser.ets:82-91` + `db/Tables.ets:68-69` 落库 URL/type | ⬜ 缺失 | 无解析器、无字幕 UI、无随播放高亮滚动（`TranscriptDialogFragment.java:164-169`） |
| 视频播放 | `video/VideoplayerActivity.java:145-150,517-520`；`Media3VideoPlayerActivity.java:139-174`；`VideoPlayerControlsView.java:140,218,302-303`；`AspectRatioVideoView.java:23-39` | — | ⬜ 缺失 | 仅有 `MediaType.VIDEO` 判定与列表角标（`components/EpisodeRow.ets:61-62`） |
| 画中画 | `video/PictureInPictureUtil.java:11-26` | — | ⬜ 缺失 | 无 PiP 参数与进入/退出逻辑 |
| 迷你播放条 | `audio/ExternalPlayerFragment.java:59-97,156-191` | `components/MiniPlayer.ets:20-76` | 🔸 简化/替代 | 封面传空 URL（`MiniPlayer.ets:24-29`）；点击一律跳播放页，上游按音/视频分流（`ExternalPlayerFragment.java:72-79`） |
| 队列锁定 | `ui/screen/queue/QueueFragment.java:294-296,327-367`；`QueueRecyclerAdapter.java:30-36`；`UserPreferences.java:625-627` | `pages/QueuePage.ets:174-180,446-453,497-499`；`prefs/UserPreferences.ets:113-120` | ✅ 对齐 | 均只禁用拖拽/排序/多选；上游多一个「勿再提示」对话框（`QueueFragment.java:332-350`） |
| 队列保持排序 | `QueueFragment.java:582-628`（`prefQueueKeepSorted`） | — | ⬜ 缺失 | 排序后仍可手动拖拽 |
| 入队位置 | `preferences_playback.xml:62-68`（默认 BACK）；`UserPreferences.java:391-395` | `prefs/UserPreferences.ets:76-83`；`model/Enums.ets:31-35`；`player/QueueEngine.ets:46-65` | 🔸 简化/替代 | 枚举与默认值对齐，但**设置页无入口**（`getEnqueueLocation` 仅被 `QueueEngine.ets:51` 调用） |
| 连续播放 followQueue | `preferences_playback.xml:75-80`；`UserPreferences.java:420-429`（默认 true） | `player/PlaybackOrchestrator.ets:56`（无条件连播） | ⬜ 缺失 | 无开关，关闭连播的语义不存在 |
| 入队已下载 | `preferences_playback.xml:69-74`（默认 true） | — | ⬜ 缺失 | 无该偏好 |
| 智能标记已播 | `preferences_playback.xml:81-87`（默认 30s）；`UserPreferences.java:447-449`；`ui/episodeslist/FeedItemMenuHandler.java:265-270` | — | ⬜ 缺失 | 移植版 `markPlayed` 仅在手动操作与播放完成时调用（`PlaybackOrchestrator.ets:68`），无「剩余 < N 秒自动标记」 |
| 跳过保留单集 | `preferences_playback.xml:88-93`；`UserPreferences.java:431-433`（默认 true） | — | ⬜ 缺失 | `shouldSkipKeepEpisode` 使用点在未检出模块（`storage:database`/`playback:service`），移植版无对应行为 |
| 播放完成→重复/连播 | 模块未检出（`playback:service`），依据 `QueueEvent`/`PlaybackServiceEvent` 调用点推断 | `player/PlaybackOrchestrator.ets:39-57`；`pages/PlayerPage.ets:823-836` | 🔸 简化/替代 | 移植版自建「关闭/单集循环/列表循环」三态按钮；上游循环由 Media3 `LoopMode` 承载 |
| 播放后自动删除 | 未检出（`AutoDeleteAction` in `storage:database`） | `player/PlaybackOrchestrator.ets:77-98`；`model/Enums.ets:38-43` | 🔸 简化/替代 | 实现「播放后删除/跟随全局」；`getDeleteRemovesFromQueue` 默认 true（`UserPreferences.ets:196-198`）与上游默认 false（`UserPreferences.java:451-453`）**相反** |
| 播放位置记忆 | 未检出（`PlaybackServiceTaskManager`），依据 `PlaybackPreferences.java:32-33` 与 `FeedMedia.position` 推断 | `player/ProgressPersister.ets:14-32`（5s 节流 + `force`） | 🔸 简化/替代 | 离开播放页/完成时强制保存（`PlayerPage.ets:65,633`；`PlaybackOrchestrator.ets:66`）；上游周期未检出 |
| 收听时长统计 | 未检出（`storage/preferences/UsageStatistics.java`） | `player/ProgressPersister.ets:43-58` | ➕ 移植版独有 | 仅前进且增量 ≤10 分钟时累加，seek 回退不计 |
| 暂停后自动回退 | 模块未检出（`PlaybackServiceMediaPlayer`），移植版注释自称对齐 | `player/PlayerManager.ets:22-25,157-177`（>1min→3s，>1h→10s，>1d→20s） | 存疑 | 上游常量无法核对 |
| 后台长时任务 | Android 前台 Service（`playback:service`，未检出）；通知渠道 `ui/notifications/.../NotificationUtils.java:18,72-79` | `player/BackgroundPlaybackGuard.ets:17-44`；`entryability/EntryAbility.ets:26`；`entry/src/main/module.json5:24-25,55` | ⬜ 缺失 | **`start()`/`stop()` 无任何调用点**，长时任务从未启动；`KEEP_BACKGROUND_RUNNING` 权限已声明 |
| 锁屏/播控中心 | Media3 MediaSession + `PlaybackServiceNotificationBuilder`（未检出）；`AvSessionBridge.ets:1-11` 自述对应 | `player/AvSessionBridge.ets:46-128` | 🔸 简化/替代 | 命令集齐全（play/pause/stop/next/prev/ff/rewind/seek/setSpeed/setLoopMode/toggleFavorite），但无应用自绘通知，依赖系统播控卡片 |
| 播控快进/快退档位 | 未检出（通知按钮直接调 service） | `player/AvSessionBridge.ets:239-252,262-270` | 🔸 简化/替代 | 系统仅支持 10/15/30 秒三档，用户任意秒数被就近映射 |
| 播控进度上报节流 | 未检出 | `player/AvSessionBridge.ets:29-30,211-221`（1s） | ➕ 移植版独有 | 并对 `setAVPlaybackState` 做串行化（`AvSessionBridge.ets:42-44,295-313`） |
| 新单集通知 | `ui/notifications/.../NotificationUtils.java:21,109-111`；`NewEpisodesNotification`（未检出） | `services/NotificationService.ets:52-117` | 🔸 简化/替代 | 按订阅聚合文本 + 一个「打开」按钮；无通知渠道分组、无逐订阅跳转 |
| 每 Feed 音量适配 | `ui/screen/feed/preferences/VolumeAdaptationPreference.java:20-27` | `pages/FeedSettingsPage.ets:172-175,585-604`；`player/PlayerManager.ets:234-254` | 🔸 简化/替代 | 档位 `[0,0.75,1.25,1.5]`；**>1.0 被 clamp 到 1.0**（AVPlayer 无增益） |
| 每 Feed 播放倍速设置 | `FeedSettingsPreferenceFragment`（速度项，未逐行核对） | `pages/FeedSettingsPage.ets:167-170,578-583` | 🔸 简化/替代 | 档位 `[0]+SPEED_PRESETS`，0 表示「未设置」走全局 |
| 队列信息条剩余时长 | `QueueFragment.java:502-523`（`timeRespectsSpeed`） | `pages/QueuePage.ets:426-444` | 🔸 简化/替代 | 不按倍速折算，无 `prefTimeRespectsSpeed`（`UserPreferences.java:791-793`） |
| 节目详情（shownotes） | `audio/ItemDescriptionFragment.java:44,129,173`（WebView 加载 HTML + 滚动置顶） | `pages/PlayerPage.ets`（弹层）+ `utils/ShownotesText.ets` + `components/ShownotesBody.ets`（第 52 轮） | 🔸 简化/替代 | 去标签转纯文本但**保留换行**（`<br>`/`<p>`/`li`…），时长内的时间码可点跳转（上游 `ShownotesCleaner` 同款推断）；仍无链接/图片/样式 |
| 时间文本不重排 | `audio/NoRelayoutTextView.java:26-48` | `pages/PlayerPage.ets:184-192` | ⬜ 缺失 | 无等价控件，时间变化触发重新布局 |
| 播放页菜单项 | `app/src/main/res/menu/mediaplayer.xml:5-96`（12 项） | `pages/PlayerPage.ets:55-106`（4 个图标） | 🔸 简化/替代 | 缺 open_podcast/visit_website/audio_controls/transcript/social/switch_to_audio_only 等 |

## 关键行为差异

1. **状态机**：上游由 `PlaybackPreferences.PLAYER_STATUS_PLAYING/PAUSED/OTHER`（`PlaybackPreferences.java:75-85`）+ `PlaybackService.isRunning` 双条件驱动（`AudioPlayerFragment.java:318-320`）。移植版为 8 态自建状态机（`PlayerManager.ets:11-20,353-371`），且 `PlayerPage.ets:607-613` 用 **1 秒轮询** 刷新 UI 而非事件订阅（仅睡眠定时器用 `EventHub`，`PlayerPage.ets:594-606`）。
2. **中断与设备丢失是两条互不越权的恢复路径**（第 49 轮起）：`PlayerManager` 用 `playIntent`（对照 ExoPlayer 的 `playWhenReady`）+ `pauseCause`（`NONE`/`INTERRUPT`/`DEVICE`）区分暂停来源。焦点恢复（`INTERRUPT_HINT_RESUME`）只在 `pauseCause === INTERRUPT` 且 `prefAutoResumeAfterInterrupt`（默认开）时续播；设备重连只在 `pauseCause === DEVICE` 时按 `prefUnpauseOnHeadsetReconnect`（默认开）/ `prefUnpauseOnBluetoothReconnect`（默认关）恢复。**焦点恢复不会在耳机拔掉后把声音从扬声器放出来**——这正是上游 `prefAutoResumeAfterInterrupt` 与 `prefPauseOnHeadsetDisconnect` 并存时最容易踩的坑。
3. **进度保存节流**：移植版 5 秒（`ProgressPersister.ets:20-22`），离开播放页与播放完成强制落盘（`PlayerPage.ets:65,633`；`PlaybackOrchestrator.ets:66`）。上游周期在未检出的 `PlaybackServiceTaskManager`，无法逐值比对。
4. **倍速档位**：移植版 7 档离散、上限 2.0（`PlayerManager.ets:38`，注释称 3.0x 需 API 13）；上游滑杆连续 0.5–4.0（`PlaybackSpeedSeekBar.java:69-82` + `playback_speed_seek_bar.xml` max=70）。播放页改速会同时写全局默认（`PlayerPage.ets:810-821`），上游只写全局（`VariableSpeedDialog.java:120-128`），临时倍速另有 `PlaybackPreferences.java:155-159` 一层。
5. **快进/快退默认值**：双方均 30s / 10s（`UserPreferences.java:582-588` vs `UserPreferences.ets:132-148`）；但移植版**不能在播放页长按改值**，只能去设置页输入（`SettingsPage.ets:89-101`），且系统播控卡片会把任意值映射到 10/15/30（`AvSessionBridge.ets:262-270`）。
6. **睡眠定时器时序**：移植版 `setInterval` 1s 自减，到点若勾选「章节末停止」则先停 interval、置 `pendingChapterEnd`，由页面轮询在章节边界调 `expireNow()`（`SleepTimer.ets:37-53,80-83`；`PlayerPage.ets:747-756`）。上游是服务端计时 + `SleepTimerUpdatedEvent` 广播剩余量（`SleepTimerDialog.java:463-477`），并支持按集数递减。
7. **连播/循环**：移植版在 `COMPLETED` 事件里分三支——单集循环重载当前集、列表循环把当前集移到队尾、否则 `autoAdvance()`（`PlaybackOrchestrator.ets:39-57`）。**无 followQueue 开关**，因此关闭连播不可实现。
8. **队列位置语义**：`QueueEngine.nextItem()` 恒取 `items[0]`（`QueueEngine.ets:91-96`），`autoAdvance()` **先 remove 再 load**（`QueueEngine.ets:168-178`），而手动播放（`QueuePage.ets:480-494`）不 remove——同一队列存在两种「当前项」语义；上游按 `QueueEvent` 增量维护，队首即当前播放项（`QueueFragment.java:146-181`）。
9. **自动删除默认值冲突**：移植版 `getDeleteRemovesFromQueue` 默认 true（`UserPreferences.ets:196-198`），上游 `shouldDeleteRemoveFromQueue()` 默认 false（`UserPreferences.java:451-453`），删除下载时是否出队的行为相反。
10. **AVSession 上报约束**：`duration` 为 0 时不上报（否则原生 `ERR_INVALID_PARAM`），`speed` 必须 >0（`AvSessionBridge.ets:280-290`）——移植版对平台约束的适配，上游无此问题。
11. **蓝牙按键重映射靠「命令来源」而非 keycode**（第 53 轮）：上游在 `onMediaButtonEvent` 里能直接看到 `KEYCODE_MEDIA_NEXT/PREVIOUS`，从而与通知卡片的同名按钮（`notificationButton=true`）区分；鸿蒙侧两条命令完全同源，只能用 AVSession 的 `CommandInfo.callerType`。**实测（模拟器 phone26 / API 26）**：播控中心卡片的上一首/下一首命令到达时 `callerType` 为 **undefined**（打印成 `callerType=unknown`），因此判定条件是「等于 `TYPE_BLUETOOTH`」而不是「不等于 app」；若真机上蓝牙命令也不带 `callerType`，日志会打印 `callerType=unknown fromBluetooth=false`，此时该特性不会生效（需要改走「当前输出设备是不是蓝牙」的兜底判定）。另：`onPlayNext`/`onPlayPrevious` 是 API 22 才有的回调，低于 API 22 的设备在 `registerSkipCommands` 里回落成原来的 `on('playNext')`（行为与改造前一致，日志有 `falling back`）。
12. **设备丢失的判定与回调到达顺序无关**（第 54 轮修）：耳机断开时系统**可能同时**发 `audioInterrupt` 的 `INTERRUPT_HINT_PAUSE` 与设备变更事件，**两者先后不保证**。旧实现只在「设备事件先到」时正确：焦点中断先到时，`handleAudioInterrupt` 已经调用过 `pause()`（`playIntent` 被清成 false）并把原因记成 `INTERRUPT`，设备事件随后到达就会因 `playIntent === false` 直接早退，原因停留在 `INTERRUPT` —— 随后焦点恢复的 `INTERRUPT_HINT_RESUME` 会照 `prefAutoResumeAfterInterrupt`（默认开）把声音从扬声器放出来。现在 `OutputDevicePolicy.wasPlaybackInterrupted(playIntent, pausedByInterrupt)` 把「原因已经是 INTERRUPT」也算作被打断的播放，两种顺序收敛到同一结论（`runtime-pure-test.ps1` 有断言，且已用「旧语义反证」确认断言非空）。**上机 A/B 取证**（模拟器 phone26 / HarmonyOS 7.0.0 / API 26；真实已下载本地单集播放中，按 焦点中断 PAUSE → 设备丢失 LOST/BLUETOOTH → 焦点恢复 RESUME 喂事件 —— 设备丢失是模拟器唯一无法真实产生的一环）：修复后 `cause` 被钉成 `DEVICE`，随后的 RESUME **不触发** `stateChange`，以 `status=PAUSED` 结束；退回旧语义则 `cause` 停在 `INTERRUPT`、RESUME 触发 `stateChange -> playing`，以 `status=PLAYING` 结束（即「声音从扬声器放出来」）。原始 hilog 见 `.dsh-out/r54/hilog-verify.txt`。
13. **「断的是不是蓝牙」要靠应用自己记一份输出设备**（第 55 轮，移植版独有特性）：设备变更事件带回的 `devices` 是**变更之后**的设备列表（SDK：「Audio device descriptors after change」），蓝牙断开时那里只剩扬声器，单看这一次事件答不出「下线的是什么设备」；`preDevices`（变更前列表）是 API 26 才有的字段，本工程 compatibleSdkVersion=14 用不了。因此 `PlayerManager` 在 `play()` 时用 `AudioRoutingManager.getPreferredOutputDeviceForRendererInfoSync(AudioRendererInfo)` 采样一次「本流此刻用的输出设备」，并在每次设备变更事件后更新；设备丢失事件到达时比较「变更前有蓝牙、变更后没有」即认定为蓝牙下线。**采样用的是按 `usage` 的场景级查询，不是全局 `AudioRoutingManager.on('deviceChange')`** —— 官方 FAQ 明确全局事件监听的是所有设备的连接状态、不与音频流绑定，不能作为自动暂停之类判断的依据。判定不出来（历史为空 / 变更后仍是蓝牙）时**不回退**：宁可漏一次，也不要在拔有线耳机或切扬声器时回退几秒。**上机取证**（模拟器，脚手架喂事件）：蓝牙臂 `bluetoothLost=true rewind=5000ms` → 暂停后 `22299 -> 17299`；有线臂 `bluetoothLost=false rewind=0ms` → 位置原样不动；停在暂停态读设备库，`FeedMedia.position` 正是回退目标（`.dsh-out/r55/hilog-verify.txt`）。**真机仍未覆盖**：模拟器无法配对蓝牙耳机，故「系统真的派发 `REASON_OLD_DEVICE_UNAVAILABLE` 且变更后列表里没有蓝牙」仍只有官方文档依据。

## 移植版独有

1. **睡眠定时器「章节末停止」**（`PlayerPage.ets:747-771`；`SleepTimer.ets:40-47`）——上游无此语义。
2. **睡眠定时器渐弱音量**（`SleepTimer.ets:8,121-133`）——最后 30 秒线性降到 0.05 下限。
3. **收听时长累加统计**（`ProgressPersister.ets:43-58`）——排除 seek 回退与 >10 分钟跳变。
4. **音频中断 duck/unduck 音量处理**（`PlayerManager.ets:345-350`）。
5. **播控中心进度上报节流 + 状态串行化**（`AvSessionBridge.ets:29-30,42-44,295-313`）。
6. **播放页改速即写全局默认倍速**（`PlayerPage.ets:818-819`）。
7. **跳片头在 `load()` 内直接抬升起点**（`PlayerManager.ets:93-99`），跳片尾用 `timeUpdate` 一次性触发（`PlayerManager.ets:312-327`）。
8. **自检接口**：`getVolume()`（`PlayerManager.ets:256-258`）、`isListening()`（`ShakeDetector.ets:44-46`）、`isRunning()`（`BackgroundPlaybackGuard.ets:59-61`）。
9. **蓝牙断开后的补偿回退**（第 55 轮，`OutputDevicePolicy.ets:138-164` + `PlayerManager.ets:311-350`）—— 上游没有：蓝牙掉线到系统通知应用之间有延迟，暂停的同时把进度往回拉 5 秒（默认，设置页可改），重连后不漏内容；只对蓝牙生效（靠应用自己记录的输出设备类别判定）。

## 存疑/需进一步核实

1. **暂停后自动回退**（`PlayerManager.ets:22-25,157-177`）自称对齐上游 3s/10s/20s，但 `PlaybackServiceMediaPlayer`/`LocalPSMP` 未检出，**无法核实上游是否真有该特性及常量值**。
2. **进度保存周期**：`PlaybackServiceTaskManager` 未检出，5s 节流是否与上游一致未知。
3. **`shouldSkipKeepEpisode()`（`UserPreferences.java:431-433`）的实际行为**在未检出的 `storage:database`/`playback:service` 中，无法确认差异粒度。
4. **上游跳过静音的引擎侧实现**在 `playback:service`（未检出）；移植版即使补 UI 也需确认 AVPlayer 是否支持静音跳过。
5. **`parser:transcript` 未检出**，无法比对支持的转录格式（VTT/SRT/JSON）与分段模型。
6. **`VideoPlayerControlsView`/`VideoplayerActivity` 未逐行核对**（仅按 grep 命中行给出结论），视频播放器完整能力清单需另行确认。
7. **`BackgroundPlaybackGuard` 是否被间接调用**：已用全工程 grep 确认 `start()` 无调用点，但需真机验证「后台播放能否存活」，以区分代码缺口与系统默认保活。
8. **上游循环模式（repeat）实现位置**未检出，移植版三态循环与 Media3 `LoopMode` 的映射关系待核实。
9. `FeedSettingsPreferenceFragment.java` 仅按 grep 命中行引用，未逐行核对音量适配与速度项的全部交互。
