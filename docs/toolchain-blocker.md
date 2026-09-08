# 构建工具链阻塞说明

更新时间：2026-09-08

## 当前阻塞

无法执行 HarmonyOS NEXT 的真实构建与设备验证，原因是本机工具链缺失：

| 工具 | 状态 |
|---|---|
| node | ✅ v24.19.0 |
| npm | ✅ 11.17.0 |
| java | ✅ OpenJDK 21.0.11 |
| ohpm | ❌ missing |
| hvigorw | ❌ missing |
| DEVECO_SDK_HOME | ❌ unset |
| DevEco Studio / Command Line Tools | ❌ 未安装 |

## 缺失影响

1. **无法编译 ArkTS/ArkUI 页面**：`pages/*.ets`、`components/*.ets` 中的声明式语法需要 DevEco/ArkTS 编译链验证。
2. **无法运行 Hypium 测试**：`FeedParser.test.ets`、`Utils.test.ets` 需要 `hvigorw test`。
3. **无法打包 HAP**、真机安装、A1–A10 E2E 验收。
4. **无法验证平台 API 签名**：AVPlayer/AVSession/request/relationalStore 等调用是否完全匹配 SDK。

## 当前已完成的替代验证

- `scripts/check-project.sh`：路径、导入、资源、页面注册、非 UI 类型检查、纯逻辑运行时断言。
- 当前结果：全部通过。
  - 静态类型：55 个非 UI TS 文件 0 error
  - 纯逻辑运行时：`RUNTIME PURE LOGIC TESTS PASSED`
  - 资源三方对齐：66/66/66

## 解除阻塞需要

提供以下任一：

1. **DevEco Studio + Command Line Tools**（含 `ohpm`、`hvigorw`、SDK）
2. 或已安装的 HarmonyOS SDK + 手动配置：
   ```bash
   export DEVECO_SDK_HOME=/path/to/sdk
   export PATH=$PATH:/path/to/command-line-tools/bin
   ```
3. 或真机/模拟器用于 E2E。

## 解除后的第一步

```bash
cd /home/riko/homennapodcast/antennapod-harmony
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
hvigorw test --mode module -p product=default
```

然后按 `docs/e2e-report.md` 执行 A1–A10 验收并修复。
