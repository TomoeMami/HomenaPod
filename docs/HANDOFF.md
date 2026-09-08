# 移植交接文档

> 给下一任执行者/团队：拿到 DevEco 工具链后如何验证与继续。

## 1. 项目位置

- 工作区：`/home/riko/homennapodcast`
- 目标工程：`/home/riko/homennapodcast/antennapod-harmony`
- 参考源码：`/home/riko/homennapodcast/antenna-repo`（只读）
- 总计划：`PLAN.md`
- 任务清单：`docs/02-task-list.md`
- 进度日志：`docs/progress-log.md`

## 2. 当前完成度

- T0–T4.7 代码主体已完成。
- MVP 与 MVP+ 功能矩阵见 `docs/feature-matrix.md`。
- 非 UI 层静态检查：55 TS files / 0 error。
- 纯逻辑运行时测试：`RUNTIME PURE LOGIC TESTS PASSED`。
- 项目统一校验：`scripts/check-project.sh` 全绿。
- 尚未做：ArkUI 页面编译验证、Hypium 运行、真机 E2E、发布签名。

## 3. 拿到工具链后立即执行

```bash
cd /home/riko/homennapodcast/antennapod-harmony
# 方法一：脚本
bash scripts/build.sh
# 方法二：手动
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

预计首轮会暴露 ArkUI 声明式页面与平台 API 类型/签名问题，集中在：
- `pages/*.ets`（ArkUI 组件、生命周期、组件参数）
- `components/*.ets`（FeedCover / LazyDataSource）
- `player/*`、`download/*`、`work/*`（@ohos/@kit API 签名）

## 4. 测试

```bash
# Hypium 单元测试（工具链可用时）
hvigorw test --mode module -p product=default
```

测试源码：
- `entry/src/test/parser/FeedParser.test.ets`（9 用例）
- `entry/src/test/utils/Utils.test.ets`（5+ 用例）

## 5. 真机验收

按 `docs/e2e-report.md` 执行 A1–A10，并回填实际结果。

## 6. 常用验证命令

```bash
bash scripts/check-project.sh          # 完整性校验
bash scripts/env-report.sh             # 环境报告
bash scripts/runtime-pure-test.sh      # 纯逻辑运行时断言
bash scripts/build.sh                  # 工具链就绪后构建
```

## 7. 已知关注点

- `FeedParser` 的 HTML/扩展 feed 容错需真实 feed 验证。
- `@ohos.request` 断点续传在个别 API 版本可能有缺陷，Plan B 已预留。
- `PlayerManager` 的 AVPlayer 状态机、AVSession/后台长时任务需真机验证。
- `WorkScheduler` 周期任务最小 2 小时。
- 页面 `LazyForEach` 数据源实现需 ArkUI 编译验证。

## 局域网克隆（git+ssh）

Git daemon（9418）已停用。请通过 SSH 克隆：主机 `192.168.3.193`，端口 `22`，用户 `riko`，公钥认证（本机 sshd 已启用并监听局域网）。

- 克隆完整工作区（含文档与项目）：
  ```bash
  git clone ssh://riko@192.168.3.193/home/riko/homennapodcast/remote/antennapod-harmony.git
  cd antennapod-harmony/antennapod-harmony
  ```
- 克隆纯 Harmony 工程（DevEco 直接打开）：
  ```bash
  git clone ssh://riko@192.168.3.193/home/riko/homennapodcast/remote/harmony-project.git
  cd harmony-project
  ```

克隆设备要求：

- 公钥已加入服务端 `~/.ssh/authorized_keys`（Windows 可用 Git Bash 的 `ssh`，首次连接确认主机指纹）。
- 服务端本地仍可直接 `git clone /home/riko/homennapodcast`。
