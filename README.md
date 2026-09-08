# AntennaPod HarmonyOS NEXT 移植工作区

本工作区用于把开源播客应用 [AntennaPod](https://github.com/AntennaPod/AntennaPod) 移植到鸿蒙（HarmonyOS NEXT，ArkTS/ArkUI 原生）。

## 目录说明

| 路径 | 内容 |
|---|---|
| `PLAN.md` | **移植总计划**（目标、范围、里程碑、执行规则）——入口文档 |
| `docs/01-architecture.md` | 架构设计、目录结构、Android→鸿蒙 API 映射、播放器状态机 |
| `docs/02-task-list.md` | **顺序任务清单**（T0–T6，执行者按此逐项执行） |
| `docs/03-project-templates.md` | DevEco 工程骨架模板（手写工程配置用） |
| `docs/04-data-schema.md` | 数据库 DDL 与 ArkTS 数据模型接口 |
| `docs/05-risks-and-verification.md` | 风险登记、验收场景 A1–A10、官方 API 文档链接 |
| `antenna-repo/` | AntennaPod 源码浅克隆（**只读参考**，develop @ 8024391，2026-09-07） |
| `antennapod-harmony/` | 目标工程（执行者创建） |
| `docs/progress-log.md` | 执行进度日志（执行者创建并追加） |

## 快速开始（执行者）

1. 读 `PLAN.md` 的“执行者须知”。
2. 从 `docs/02-task-list.md` 的 **T0.1** 开始顺序执行。
3. 网络访问前设置代理：`export http_proxy=http://127.0.0.1:7893 https_proxy=http://127.0.0.1:7893`。

## 关键决策摘要

- 平台：HarmonyOS NEXT，API 12 兼容基线
- 语言：ArkTS + ArkUI（严格模式）
- 范围：MVP 优先（订阅 / RSS / 播放 / 队列 / 下载 / 设置），分期扩展
- 播放：AVPlayer + AVSession + AUDIO_PLAYBACK 长时任务
- 存储：relationalStore（复用 AntennaPod 表结构）+ preferences
- 执行：单执行者顺序执行任务清单
