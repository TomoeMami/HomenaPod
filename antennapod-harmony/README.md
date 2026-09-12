# HomenaPod for HarmonyOS NEXT

HomenaPod 的 HarmonyOS NEXT 原生实现（ArkTS/ArkUI，API 12 兼容基线）。
来源与许可：本项目是基于 AntennaPod（GPL-3.0）的鸿蒙移植，保留上游许可与归属声明；参考实现：上游 `AntennaPod/AntennaPod`（仅作为移植参考，不提交其 Android 代码）。详见 `NOTICE.md`。

## 当前状态

- 阶段：MVP+ 功能已实现并在 HarmonyOS 模拟器上逐项上机验收。
- 构建：`hvigor` `Clean → CompileArkTS → PackageHap` 通过，产物为 **未签名 HAP**（`build-profile.json5` 的 `signingConfigs` 留空，模拟器可直接安装；真机需自行配置签名，见 `../docs/signing-guide.md`）。
- 统一入口文档：仓库根 [`README.md`](../README.md)；计划与任务见 `../PLAN.md` 与 `../docs/02-task-list.md`。

## 环境要求

- DevEco Studio 5.x / HarmonyOS 5.0（API 12）
- Node.js 18+（可选，用于检查工具）
- DevEco Command Line Tools：`hvigorw`、`ohpm`

## 构建

```bash
export DEVECO_SDK_HOME=/path/to/command-line-tools/sdk
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
# 产物: entry/build/default/outputs/default/entry-default-unsigned.hap
```

真机安装需在 DevEco Studio 配置自动签名，或回填 `build-profile.json5` 的 `signingConfigs`。

## 模块/目录（单 entry 分层）

```
entry/src/main/ets/
  model/       数据模型（纯 ArkTS，无平台依赖）
  db/          relationalStore 连接、DDL、Mapper、Repository
  prefs/       UserPreferences
  net/         HttpClient / Discovery
  parser/      XmlReader / FeedParser / FeedSanitizer
  player/      PlayerManager / AVSession / BackgroundPlaybackGuard / QueueEngine / SleepTimer
  download/    DownloadManager
  services/    FeedFetcher / RefreshService / SubscriptionService / NotificationService / OpmlService
  events/      类型化 EventHub
  pages/       ArkUI 页面
  components/  ArkUI 复用组件（规划）
  work/        WorkScheduler 定时刷新扩展
```

## 核心能力（已实现代码）

- 订阅管理：URL 添加、iTunes 搜索发现、在线解析、入库
- RSS/Atom 解析：Rss20/Atom/Itunes/Media/PodcastIndex 基础字段
- 播放：AVPlayer 流播放/本地播放、seek、六档倍速、AVSession 锁屏控制、后台长时任务
- 队列：内存队列 + 持久化、上下移动、移除
- 下载：@ohos.request 封装、进度/完成/失败事件、下载日志
- 设置：主题、在线优先、默认倍速
- 后台：workScheduler 定时刷新、新单集通知、睡眠定时器
- OPML 导入导出服务、收藏夹、章节数据层

## 已知限制

- 未在真机/DevEco 工具链编译验证，API 细节待首次构建修复。
- AVPlayer 无“跳过静音”能力，设置项未开放。
- 定时刷新间隔最小 2 小时（系统限制）。
- 下载断点续传依赖系统 DownloadTask，个别 API 版本可能需 Plan B 手写 Range 下载。
- WearOS/投屏/转录/统计/自动清理等仍属 backlog。

## 无 DevEco 工具链时的静态检查

```bash
bash scripts/static-check.sh
```

该脚本将非 ArkUI 文件复制为 TS、移除平台 import，并用 `tools/platform-stubs.d.ts` 桩声明运行 `tsc --noEmit`。当前 52 个 TS 文件通过（pages/components 的 ArkUI 声明式语法需 DevEco 构建验证）。

## 项目完整性校验

```bash
bash scripts/check-project.sh
```

该脚本依次检查：路径一致性、导入路径、三语资源对齐、页面注册、非 UI 层 tsc 静态检查。

## 纯逻辑运行时验证

```bash
bash scripts/runtime-pure-test.sh
```

将纯模型/工具 `.ets` 编译为 JS 并用 Node 执行断言（Duration/Date/MIME/HtmlCleaner/Playable）。当前输出：
`RUNTIME PURE LOGIC TESTS PASSED`。

## 环境与工具链诊断

```bash
bash scripts/env-report.sh
```

输出 node/java/ohpm/hvigor/DEVECO_SDK_HOME、路径残留与 check-project 结果。

## 构建入口

```bash
bash scripts/build.sh
```

未安装 `hvigorw` 时会提示所需环境变量并以非零码退出。
