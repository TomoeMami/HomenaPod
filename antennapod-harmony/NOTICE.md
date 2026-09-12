# NOTICE · 来源与许可声明

## 一、项目身份

| 项 | 值 |
|---|---|
| 产品名称 | **HomenaPod** |
| bundleName | `com.homenapod.app` |
| 平台 | HarmonyOS NEXT（ArkTS / ArkUI，API 12 兼容基线） |

## 二、上游来源

本项目是开源播客应用 **AntennaPod** 的 HarmonyOS NEXT 移植实现：

- 上游项目：<https://github.com/AntennaPod/AntennaPod>
- 参考快照：develop 分支（2026-09-07）
- 移植方式：按上游模块语义用 ArkTS/ArkUI 重新实现；源码文件头部以 `// Port of: <上游相对路径>` 标注对应关系，便于逐项比对与回归。

## 三、许可（GPL-3.0）

- 本项目遵循上游 **GNU GPL-3.0**（`entry/oh-package.json5` 已声明 `"license": "GPL-3.0-only"`）。
- 许可全文：<https://www.gnu.org/licenses/gpl-3.0.txt> ；正式发布前需在仓库根目录补充 `LICENSE` 全文（见 `docs/release-checklist.md`）。
- 分发与再发布时必须保留：本声明、上游来源标注、全部 `Port of:` 注释及 GPL 许可声明。

## 四、商标与品牌

- **HomenaPod** 为本项目自有名称；项目不使用 AntennaPod 的名称、图标或品牌标识作为产品标识（应用名、图标、包名、通知、UA 等均已替换为 HomenaPod）。
- AntennaPod 的名称与标识归其项目方所有；本项目仅在"来源与许可"语境中作事实性引用，不暗示上游对本项目的背书。
