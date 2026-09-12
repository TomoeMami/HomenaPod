# 鸿蒙平台对应物评估（阶段 9）

> 生成日期：2026-09-08 · 对应 `docs/feature-gap.md` §3「⛔ 平台不适用」清单
> 结论依据：本机 DevEco SDK（API 26 d.ts，`compatibleSdkVersion 5.0.0(12)`）与官方文档检索结果。
> 说明：本文件只做**可行性判定**，不含实现；每项给出「对应物 / 结论 / 若 go 的后续任务」。

## 0. 总览

| 上游（Android）能力 | 鸿蒙对应物 | 结论 | 依据 |
|---|---|---|---|
| Android Auto（含 For You） | HiCar / 车机应用（Car Kit） | ⛔ 暂不实现 | 车机能力需厂商合作与独立资质，个人开发者分发路径不明 |
| Wear OS 应用/表盘控制 | 鸿蒙手表应用（Wear Engine / 独立手表应用） | ⛔ 暂不实现 | 需独立设备与手表应用工程；当前工程 deviceTypes 仅 phone/tablet |
| Chromecast（仅 Play 版） | Cast+ / 分布式 AVSession 投屏 | 🟡 待评估（API 支持面不确定） | 需真机 + 接收端设备验证，且依赖系统投屏服务 |
| Android AppWidget（桌面小部件） | 服务卡片（form / ArkTS 卡片） | 🟡 可行但非本期 | 静态卡片（显示队列/最新单集）技术可行，需新增 form 扩展与卡片资源 |
| SAF 外置存储选择（数据文件夹） | 应用沙箱 / 分布式文件 | ⛔ 无等价物 | 鸿蒙应用只能访问自身沙箱与用户经 Picker 授权的文件；无法像 SAF 那样把应用数据目录放到 SD 卡 |
| 硬件键盘快捷键（含 0–9 定位） | 平板外接键盘（焦点/按键事件） | 🟡 平板可做 | `onKeyEvent` 在平板 + 键盘形态可用；手机形态无需求 |
| 第三方自动化（Tasker/Home Assistant 触发刷新） | 显式 Want 启动（startAbility + skills action） | ✅ 可行 | 见 §1 |
| 本地文件夹导入（播放本地文件） | DocumentViewPicker + 沙箱内文件 | ✅ 可行（v1 单文件） | 见 §1 |
| 深链（antennapod.org/deeplink） | module.json5 skills + uris | ✅ 可行 | 见 §1 |

## 1. 本期已实现或已具备落地路径的对应物

### 1.1 应用内语言切换（替代 Android 多语言 + 系统设置）
- 对应物：`@ohos.i18n` 的 `System.setAppPreferredLanguage(language)`，`'default'` 表示跟随系统，冷启动生效。
- 状态：**已实现**（`pages/SettingsPage.ets` 语言三选 + `EntryAbility.applySavedLanguage()`），三语资源 base/en_US/zh_CN 齐备。

### 1.2 摇一摇重置睡眠定时（替代上游 shake to reset）
- 对应物：`@ohos.sensor` `SensorId.ACCELEROMETER`（权限 `ohos.permission.ACCELEROMETER`）。
- 状态：**已实现**（`player/ShakeDetector.ets` + `PlayerPage` 挂钩；定时器活跃期间才监听）。

### 1.3 震动提示（替代 Android Vibrator）
- 对应物：`@ohos.vibrator.startVibration({type:'time',duration},{usage:'alarm'})`（权限 `ohos.permission.VIBRATE`）。
- 状态：**已实现**（睡眠定时到点震动）。

### 1.4 分享（替代 Android ACTION_SEND）
- 本机 SDK（API 26 d.ts）**没有** `@ohos.systemShare`（`ShareController` 零命中），系统分享面板不可用。
- 状态：**已实现为复制链接到剪贴板**（`@ohos.pasteboard`）+ Toast 提示；若后续 SDK 提供 systemShare，可平滑升级为分享面板。

### 1.5 第三方自动化触发刷新（替代 FeedUpdateReceiver Broadcast）
- 对应物：给 `EntryAbility` 增加自定义 `skills.actions`（如 `com.homenapod.action.REFRESH_FEEDS`），自动化应用用 `startAbility` 显式启动即可触发后台刷新。
- 状态：**待实现**（方案已定，风险低：无敏感参数、幂等；需注意 `exported` 安全评估）。后续任务：T8.11。

### 1.6 本地文件导入（替代 Android 本地文件夹）
- 对应物：`@ohos.file.picker.DocumentViewPicker` 选择音频文件 → 复制到应用沙箱 → 建「本地单集」内部订阅 → 播放走现有 `Playable.localFileUrl` 链路。
- 状态：**待实现**（v1 单文件；目录递归扫描留 v2）。后续任务：T8.12。

### 1.7 深链（替代 antennapod.org/deeplink）
- 对应物：`module.json5` 的 `abilities[].skills[].uris`（scheme=https + host）+ `EntryAbility.onNewWant` 解析。
- 状态：**待实现**（只做 subscribe / feed 两类）。后续任务：T8.6。

## 2. 结论为 ⛔ 或延后的项及理由

| 项 | 结论 | 理由 |
|---|---|---|
| 车机 / HiCar | ⛔ | 需要车机侧合作与上架资质，超出个人项目范围；`docs/feature-gap.md` 保持 ⛔ |
| 手表 | ⛔ | 需独立手表工程与设备；当前 `deviceTypes` 只有 phone/tablet |
| Cast+ 投屏 | 🟡 延后 | 依赖接收端设备与系统投屏服务，无法在无设备条件下验收 |
| 服务卡片 | 🟡 延后 | 技术可行，但需新增 form 扩展 + 卡片资源 + 数据共享通道；收益低于 P1/P2 其余项 |
| SAF 外置存储 | ⛔ | 平台无等价物：应用数据只能位于沙箱或经 Picker 授权的用户目录，无法指定 SD 卡为数据文件夹 |
| 平板外接键盘快捷键 | 🟡 延后 | 平板 + 键盘形态可用 `onKeyEvent` 实现；手机无需求，列入 backlog |

## 3. 与上游许可/商标的边界（复核）

- 上游 AntennaPod 为 **GPL-3.0**：本项目保留全部 `Port of:` 来源注释与 GPL 声明（见 `antennapod-harmony/NOTICE.md`）。
- Media Kit 限制 logo 使用与官方背书暗示：本项目使用自有标识 **HomenaPod**，仅在「来源与许可」语境引用 AntennaPod 名称。
- 结论：**无新增合规风险**；不引入任何上游 logo/图标资源。
