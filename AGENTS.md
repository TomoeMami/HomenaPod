# AGENTS.md — 本仓库执行约定（助手/代理必读）

完整计划与规则见 `PLAN.md`（尤其 **§3 执行者须知**）；逐轮流水见 `STATUS.md`、
`docs/progress-log.md`、`antennapod-harmony/CHANGELOG.md`（后三者是 `.gitignore` 的本地文件）。
本文件只列**最容易踩、且必须优先遵守**的约定。

## 1. 版本号：只在用户明确要求时才改

- `antennapod-harmony/AppScope/app.json5` 里的 `versionName` / `versionCode` **默认保持不动**。
  功能提交、修复提交、重构提交、文档提交都**不要**顺手 bump。
- 只有用户**明确说**要改（例如「版本号 +0.0.1」「版本号更新到 x.y.z」）时才动，并且放在
  **独立提交**里（提交信息沿用既有写法：`版本号更新到 1.0.13`），再按需发 release。
- 背景（为什么写死这条）：1.0.11 之后，助手在修复提交里按「每轮顺带 bump」的旧惯例把版本号
  提到了 1.0.12；用户随后又要求「再加 0.0.1」，于是得到 1.0.13 —— 1.0.12 成了一个
  **没有任何 release/tag 对应的中间版本号**（release 列表是 1.0.11 → 1.0.13）。
  该旧惯例自本次起作废。

## 2. 发版（仅在被要求时执行）

```powershell
# 未签名 release HAP（产物：antennapod-harmony/entry/build/default/outputs/default/entry-default-unsigned.hap）
& "D:\Apps\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p buildMode=release --no-daemon

# 新建 release（附件名保持 entry-default-unsigned.hap，与历次一致）
gh release create vX.Y.Z <hap 路径> --title "vX.Y.Z · <一句话>" --notes-file <说明.md>
```

- 先确认**用户已明确要求**改版本号，并且提交/推送完成（release 的 tag 默认指向当前分支 HEAD）。
- 未签名包在真机安装前需自行签名（见 `docs/signing-guide.md`）；模拟器可直接装（`bm install -p`）。
