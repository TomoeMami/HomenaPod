# HomenaPod 移植总计划（源自 AntennaPod → HarmonyOS NEXT）

> **说明**：本计划里提到的执行流水文件（`docs/progress-log.md`、`docs/e2e-report.md`、`STATUS.md`、
> `docs/device-test-report.md`、`antennapod-harmony/CHANGELOG.md` 等）只在本地开发工作区保留，
> **不随公开仓库发布**；仓库中公开的是设计/规格类文档（`docs/01`–`docs/07`、`feature-diff/`、
> `harmony-counterparts.md`、`_ref-spec-*.md`）。

- 文档版本：1.0
- 制定日期：2026-09-08
- 参考源码：`./antenna-repo`（AntennaPod `develop` 分支 @ `80243910fe620217111a60b0054a968f66084382`，2026-09-07，版本 3.12.1，Java 21 / AGP 9.0.1 / Media3 1.10.0，约 8 万行 Java）
- 目标工程目录：`./antennapod-harmony`（尚未创建，由执行者按计划创建）

---

## 1. 目标

在 **HarmonyOS NEXT（纯血鸿蒙，API 12+，建议 DevEco Studio 5.x / HarmonyOS 5.x）** 上用 **ArkTS + ArkUI** 原生重写 AntennaPod，产品定名 **HomenaPod**（bundleName `com.homenapod.app`），第一期交付 **MVP**，随后分期扩展功能对齐。

| 维度 | 决策 |
|---|---|
| 目标平台 | HarmonyOS NEXT，API 12 为兼容基线（不依赖安卓运行时） |
| 开发语言 | ArkTS（严格模式）+ ArkUI 声明式 UI |
| 设备范围 | 手机 + 平板（排除 WearOS/车机） |
| 第一期范围 | MVP：订阅 / RSS 解析 / 播放 / 队列 / 下载 / 设置（详见 §4） |
| 执行方式 | 单执行者（DeepSeek V4 Flash）按 `docs/02-task-list.md` 顺序逐项执行 |
| 工程形态 | 先单 `entry` 模块分层开发；模块化拆分放到 Phase 6（可选） |
| 参考仓库 | `antenna-repo` **只读**，不修改、不提交 |

## 2. 里程碑（M）

| 里程碑 | 内容 | 对应任务 | 验收标志 |
|---|---|---|---|
| M0 | 工程骨架 + 工具链探测 + 参考代码研读 | T0.x | 目录/模板文件齐备，`progress-log.md` 有工具链结论 |
| M1 | 领域层可用：模型、数据库、偏好、HTTP、RSS 解析 | T1.x | 解析器通过 AntennaPod 自带 9 个 XML fixture 的移植测试 |
| M2 | 播放内核可用：AVPlayer 封装、倍速/seek、AVSession、后台持续播放 | T2.x | 冒烟页能播放远程音频；锁屏/后台控制生效 |
| M3 | MVP UI 闭环（v0.1.0 冻结） | T3.x | 验收场景 A1–A7 全部通过 |
| M4 | MVP+（通知、定时刷新、OPML、睡眠定时、收藏、章节、搜索） | T4.x | A8–A10 通过 |
| M5 | 质量与发布准备 | T5.x | 单测、深色模式、错误处理、签名构建文档齐备 |
| M6 | （可选）模块化拆分 + 功能长尾 | T6.x | 见 backlog |

## 3. 执行者须知（DeepSeek V4 Flash 必读）

1. **按顺序执行**：只做 `docs/02-task-list.md` 中当前任务。每个任务做完后，在 `docs/progress-log.md` 追加一行：
   `- [x] T1.5 HttpClient 封装 · 完成时间 · 验证证据（测试/构建结果摘要）`
   未完成或受阻时记录 `- [ ] T1.6 ... 受阻原因` 并继续做下一个**无前置依赖**的任务，不阻塞整体进度。
2. **参考仓库只读**：`antenna-repo` 是参考实现。动手前先 `read` 任务中列出的参考文件；禁止 `cd antenna-repo` 后修改任何文件。
3. **网络与离线**：需要抓取官方文档或依赖时，确保外网可达；离线时改用本地已克隆的 `antenna-repo`（不依赖网络）。
4. **构建现实**：本机已确认有 Node v24 与 JDK 21，但**没有** `ohpm` / `hvigorw` / DevEco SDK。因此：
   - 代码按 HarmonyOS NEXT API 12 规范编写；
   - 若执行环境中仍无 hvigor，则每个任务的验证方式为**静态自检**（对照本计划的 API 清单 + 官方文档链接），并在验收栏注明 `build: deferred`；
   - 一旦环境提供 DevEco Command Line Tools，统一执行：`hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon` 修复全部错误后再进入下一阶段。
   - 不要擅自下载/安装数 GB 的 DevEco 或 SDK；如需安装，先停下向用户确认。
5. **代码规范**：
   - ArkTS 严格模式：禁止 `any`；对象字面量必须显式声明 interface/class；不用 `Function` 类型；遵循官方 ArkTS 限制。
   - 新增用户可见字符串一律放 `resources/base/element/string.json`，并同步 `en_US` 与 `zh_CN`。
   - 目录、命名、分层严格遵守 `docs/01-architecture.md` §2。
   - 注释写清“移植自哪个参考类”（如 `Port of: model/Feed.java`），便于回溯。
6. **官方 API 依据**：写任何 `@ohos.*` 调用前，先查 `docs/05-risks-and-verification.md` 附录里的官方文档链接；链接失效时抓取 `openharmony/docs` master 分支对应文档，不要把记忆中的 API 当事实。
7. **不允许的捷径**：不做“把 APK 塞进鸿蒙”的兼容方案；不引入未经 ohpm 验证的第三方库（计划列出的除外）；不跳过 DoD。

## 4. 范围定义

### 4.1 MVP（M3 必须完成）

| 能力 | 用户可见功能 | 数据/技术要点 |
|---|---|---|
| 订阅管理 | 添加订阅（输入 URL）、在线预览、订阅/退订、重命名、封面与未播计数 | Feeds 表；RSS/Atom 解析；图片缓存 |
| 单集浏览 | Feed 详情页：全部/未播放/已下载筛选；单集状态、时长、发布日期 | FeedItems/FeedMedia 表 |
| 播放 | 在线流播放与本地文件播放、播放/暂停、seek、±跳过、倍速 0.75–2.0（API12 档位）、进度记忆、自动连播 | AVPlayer + AVSession + AUDIO_PLAYBACK 长时任务 |
| 队列 | 加入/移除队列、上下移动、播完自动出队进历史 | Queue 表 + 队列引擎 |
| 下载 | 单集下载、暂停/继续、删除、下载进度、下载日志 | @ohos.request.downloadFile + DownloadLog 表 |
| 设置 | 浅色/深色/跟随系统、默认倍速、跳过静音（UI 占位，能力不支持则隐藏）、在线优先/下载优先、移动数据限制、刷新间隔、缓存清理 | preferences |

### 4.2 MVP+（M4，视进度逐项做）

新单集通知、定时自动刷新（workScheduler）、OPML 导入/导出、睡眠定时器、收藏夹、章节列表（来自 feed）、搜索/发现页（iTunes Search API）。

### 4.3 明确排除（本期不做，列入 backlog）

WearOS、Chromecast/投屏、gpodder.net 同步、转录/字幕、统计页、Android Auto、桌面小组件/卡片、视频播客、自动化下载清理算法、家长控制、本地代理下载（ProxyConfig）。

## 5. 目录

| 文件 | 用途 |
|---|---|
| `PLAN.md` | 本总计划 |
| `docs/01-architecture.md` | 架构决策、目录结构、Android→鸿蒙 API 映射、播放器状态机 |
| `docs/02-task-list.md` | **执行主清单**：T0–T6 全部任务（目标/参考/产出/步骤/DoD/验证） |
| `docs/03-project-templates.md` | DevEco 工程关键文件模板（手写工程骨架用） |
| `docs/04-data-schema.md` | SQLite 表结构与 ArkTS 接口定义（可直接抄） |
| `docs/05-risks-and-verification.md` | 风险登记表、验收场景 A1–A10、测试计划、官方文档链接 |
| `docs/progress-log.md` | 执行进度日志（由执行者创建和追加） |

## 6. 关键风险摘要（详见 docs/05）

| # | 风险 | 等级 | 对策 |
|---|---|---|---|
| R1 | 本机无 DevEco/hvigor，编译无法本地闭环 | 高 | 模板化骨架 + 静态自检 + `build: deferred` 标记；提供 SDK 后集中修复 |
| R2 | AVPlayer 能力边界（无跳过静音、变速档位有限、部分 feed 的音频格式不支持） | 高 | 播放器接口抽象；不支持项在设置中隐藏；错误上报与降级提示 |
| R3 | @ohos.request 下载在部分 API 版本的断点续传缺陷 | 中 | Downloader 接口抽象，MVP 用 request.downloadFile；预留手写 HTTP Range + fs 实现为 Plan B |
| R4 | 播客 feed 格式混乱，解析健壮性不足 | 中 | 移植 AntennaPod 容错逻辑 + 9 个 fixture 回归 + 10 个真实 feed 冒烟 |
| R5 | 后台播放被系统杀死 / 长时任务权限 | 中 | AVSession + BackgroundMode.AUDIO_PLAYBACK + wantAgent 标准链路；真机验证锁屏 |
| R6 | ArkTS 限制（无 any、对象字面量、异步约束）导致照搬 Java 逻辑困难 | 中 | 先写接口再写实现；任务里给出 ArkTS 数据接口模板 |
| R7 | DeepSeek V4 Flash 单任务上下文有限，跨文件漂移 | 中 | 任务粒度 ≤ 半天；每个任务列死参考文件与产出文件；进度日志防漂移 |

## 7. 立即开始

执行者从 `docs/02-task-list.md` 的 **T0.1** 开始，先完成 §3 的阅读与 `docs/progress-log.md` 创建。
