# 05 · 风险登记、验收场景与官方 API 依据

## 1. 风险登记表（执行中持续更新）

| # | 风险 | 概率 | 影响 | 缓解措施 | 触发信号 | 负责人动作 |
|---|---|---|---|---|---|---|
| R1 | 本机无 DevEco/hvigor/ohpm，无法本地编译验证 | 高 | 高 | 骨架模板化；每个任务做静态自检并标 `build: deferred`；工具链就绪后集中构建修复 | `which hvigorw` 为空 | T0.4 记录结论；不擅自下载 SDK |
| R2 | AVPlayer 能力边界：无跳过静音、变速档位离散、个别 codec 不支持 | 高 | 中 | 设置项隐藏不支持项；播放器抽象；错误码映射与重试提示 | 播放失败/设置项不可用 | 在 PlayerManager 增加能力探测注释与降级路径 |
| R3 | `@ohos.request` 高版本 API 断点续传缺陷（社区有 API18 个案） | 中 | 中 | DownloadManager 接口隔离；Plan B=HttpClient+Range+fs 手写 | 恢复下载后文件损坏/从头下载 | 真机专项验证；失败切 Plan B |
| R4 | 真实 feed 格式脏（缺 enclosure、非法日期、HTML 嵌套） | 高 | 中 | 移植 AntennaPod 容错逻辑；9 fixture 回归 + 每阶段至少 5 个真实 feed 冒烟 | 解析异常 | 记录失败样本，增强 sanitizer |
| R5 | 后台播放被系统回收/长时任务被取消 | 中 | 高 | AVSession+AUDIO_PLAYBACK+wantAgent 标准链路；不在长时任务外做网络播放 | 锁屏几分钟后停止 | 对照官方 FAQ：应用进入后台播放停止的排查清单 |
| R6 | ArkTS 严格模式限制（no any、字面量必须显式类型、无解构等） | 中 | 中 | docs/04 预定义全部接口；先接口后实现；每个文件自查 ArkTS 规则 | 编译报 arkts 错误 | 按报错改造为显式 class/interface |
| R7 | 执行模型单线程顺序，任务间上下文丢失 | 高 | 中 | 任务粒度 ≤ 半天；progress-log 每任务记录产出文件；docs/01 为持久设计约束 | 命名/目录漂移 | 每个 UI 任务开始前重读 docs/01 §7 与对应任务 |
| R8 | 真实设备不可用，手工验收无法执行 | 中 | 中 | 推演式验收记录（代码路径逐条走查）+ deferred 标注；DevEco Previewer 可验证静态 UI | 无设备 | e2e-report 区分 PASS/deferred |
| R9 | 版权与商标：直接复用 AntennaPod 资源可能违反 GPL/商标 | 低 | 中 | 代码移植遵守 GPL-3.0（保留许可声明）；图标先用占位图，正式图标经项目方确认 | 上架审核 | T5.5 检查 LICENSE 与图标来源 |
| R10 | 订阅源需要 Basic Auth/自签名证书/特殊重定向 | 中 | 低 | HttpClient 保留 Authorization header 与重定向策略；MVP 不强制支持自签名 | 订阅失败 | 错误信息提示原因，日志留证 |

## 2. 验收场景（Definition of Done 的总闸门）

### M3 场景（A1–A7）

**A1 订阅闭环**
1. 打开“添加订阅”，输入 `https://feeds.megaphone.fm/vergecast`（或其他稳定 feed，日志记录实际 URL）。
2. 预览页显示节目名、简介、封面与单集数。
3. 点“订阅”后回到订阅列表：出现该节目、封面与未播计数。
4. 退订后列表消失；重新订阅成功。
- 通过标准：全程无崩溃；计数与实际单集数一致（允许 ±0）；失败提示可读。

**A2 浏览与在线播放**
1. 进入 feed 详情：单集列表按日期倒序；显示时长与日期。
2. 切换筛选“未播放/全部/已下载”，结果正确。
3. 点任一单集：播放页打开，在线流开始播放，进度条走动，时间标签更新。
4. 拖动进度条 seek 后从新位置继续；±30s 跳过生效。
- 通过标准：无崩溃；seek 误差 ≤ 3s；状态图标正确。

**A3 后台与锁屏播放**
1. 播放中按 Home 键退到桌面：音频继续。
2. 锁屏：控制中心显示标题/节目名/封面；可暂停、继续。
3. 播放页回到前台时，界面状态与实际一致。
- 通过标准：≥ 5 分钟持续播放；控制指令 2s 内生效。

**A4 倍速**
1. 播放页设置 1.5x：声音变速生效，重启应用后再播放仍为 1.5x。
2. 六个档位（0.75/1.0/1.25/1.5/1.75/2.0）逐一可设，状态显示正确。
- 通过标准：档位持久化；无崩溃。

**A5 队列与连播**
1. 加入 3 个单集到队列，调整顺序（上移/下移）。
2. 播放第 1 集，播完后自动播放队列中的下一集。
3. 移除一个条目后顺序正确；清空队列后播放停止。
- 通过标准：自动连播成功 ≥ 1 次；队列与页面一致。

**A6 下载**
1. 对单集点下载：进度条前进，完成后本地可离线播放。
2. 下载中点暂停：进度停；点继续：从断点继续。
3. 删除已下载文件：FeedMedia.file_url 清空，再播放走在线。
4. 下载日志页能查到成功/失败记录与原因。
- 通过标准：离线播放（开飞行模式）成功；日志完整。

**A7 持久化**
1. 订阅 2 个 feed、入队 2 集、播放到 30% 位置后强杀应用。
2. 重启：订阅、队列、播放位置、设置全部保留；点该集从记录位置附近继续。
- 通过标准：数据无丢失；进度误差 ≤ 10s。

### M4 场景（A8–A10）

**A8 刷新与通知**：订阅一个有更新的 feed → 手动全量刷新 → 新单集出现在列表并收到通知；定时任务在设定间隔后触发（允许手动等待或缩短测试间隔）。
**A9 OPML 往返**：导出当前订阅为 OPML → 清空订阅 → 导入该文件 → 订阅集合与导出前一致（标题、URL 逐项比对）。
**A10 主题与语言**：系统切深色 → 应用跟随；设置固定浅色/深色生效；系统语言切中/英 → 主要页面文案切换。

## 3. 测试策略

| 层级 | 框架/方式 | 范围 | 门槛 |
|---|---|---|---|
| 逻辑单测 | Hypium（`@ohos/hypium`，hvigor test） | model/utils/parser/queue/下载状态机 | ≥ 40 用例，core 逻辑行覆盖 ≥ 60%（工具链可用时） |
| 解析回归 | 9 个上游 XML fixture | FeedParser | 100% 通过（T1.8） |
| 真机手工 | docs/02 各任务 DoD + A1–A10 | 全链路 | M3/M4 全 PASS 或明确 deferred |
| 性能 | 启动计时、内存监控、EXPLAIN | 启动/列表/播放 1h | 启动 ≤ 2s；无持续内存增长；5 条高频 SQL 走索引 |
| 静态 | ArkTS 规范自查清单 + 资源审计 | 每任务 | 无 `any`；字符串无硬编码；依赖方向不反向 |

## 4. 官方 API 依据（写代码前查证，链接已在本机验证可访问）

| 用途 | 文档 |
|---|---|
| AVPlayer（创建/状态机/seek/setSpeed/事件） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-media-kit/arkts-apis-media-AVPlayer.md |
| PlaybackSpeed 枚举（0.75–2.0 档位值） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-media-kit/arkts-apis-media-e.md |
| AVSession（activate/setAVMetaData/setAVPlaybackState/setAVQueueItems/控件事件） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-avsession-kit/arkts-apis-avsession-AVSession.md |
| 长时任务 backgroundTaskManager（AUDIO_PLAYBACK） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-backgroundtasks-kit/js-apis-resourceschedule-backgroundTaskManager.md |
| 后台播放官方指引（含进入后台停止的排查） | https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-audio-24 |
| @ohos.request（downloadFile/DownloadTask/pause/resume） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-basic-services-kit/js-apis-request.md |
| @ohos.xml（XmlPullParser/parseXml/ParseInfo） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-arkts/js-apis-xml.md |
| relationalStore（getRdbStore/RdbStore/ResultSet） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-arkdata/arkts-apis-data-relationalStore.md |
| preferences | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-arkdata/js-apis-data-preferences.md |
| @ohos.net.http（HttpRequest/header/重定向） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-network-kit/js-apis-http.md |
| workScheduler（周期任务） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-backgroundtasks-kit/js-apis-resourceschedule-workScheduler.md |
| notificationManager | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-notification-kit/js-apis-notificationManager.md |
| file picker（OPML 导入导出） | https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-core-file-kit/js-apis-file-picker.md |
| 命令行构建 FAQ | https://developer.huawei.com/consumer/cn/doc/doccenter-tools-faq/faqs-command-line-tool-35 |

> 抓取官方文档时代理设置：
> ```bash
> export http_proxy=http://127.0.0.1:7893 https_proxy=http://127.0.0.1:7893
> curl -sS <url>
> ```

## 5. 已核实的平台事实（避免执行者踩坑）

1. **AVPlayer.setSpeed**：仅 prepared/playing/paused/completed 状态可调；API12 枚举为 0.75/1.00/1.25/1.75/2.00 + 0.50/1.50/0.25/0.125；3.00 是 API13+。MVP 只暴露 0.75–2.0 六个常用档。
2. **AVPlayer.currentTime/duration**：单位为 ms；无效值 -1；prepared 后才可信。
3. **下载**：`request.downloadFile(context, {url, filePath})` 返回 DownloadTask；`on('complete'|'pause'|'remove')` 与 `on('fail')`、`on('progress')` 可用；`pause()/resume()` 在当前 master 文档标 deprecated（高版本有 request.agent 替代），MVP 仍用旧接口并在接口层隔离。
4. **XML**：`XmlPullParser.parse(option)` API14 起 deprecated，`parseXml(option)` 为 14+；封装层须兼容两者（try parseXml，失败回退 parse）。
5. **后台播放**：`startBackgroundRunning` 需要 `ohos.permission.KEEP_BACKGROUND_RUNNING`（normal 级）+ `BackgroundMode.AUDIO_PLAYBACK` + wantAgent；API20+ 未接 AVSession 会在通知栏出现额外通知，因此 MVP 直接同时接 AVSession 是正确路线。
6. **workScheduler**：`startWork(WorkInfo)`，任务由 `WorkSchedulerExtensionAbility` 执行，WorkInfo 需要 `workId/bundleName/abilityName/isRepeat/isPersisted` 与触发条件（网络/充电/周期）。
7. **relationalStore**：单条记录共享内存限制 2MB，字符串字段上限 8MB——描述类字段写入前截断（AntennaPod 描述约 4KB，安全）。
