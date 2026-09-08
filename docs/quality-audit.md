# 质量审计与性能记录（T5.3 / T5.4）

> 本表为静态审计结论；真机数据需工具链/设备完成后回填。

## 1. 错误/加载/空状态审计（T5.3）

| 页面 | 加载态 | 错误态 | 空状态 | 待完善 |
|---|---|---|---|---|
| Index 壳 | 无（Tab 切换即时） | 无 | 无 | 迷你条可跳转 PlayerPage（已做） |
| SubscriptionsPage | `loading` 变量存在，列表显示前可占位 | 加载失败静默置空 | 有“暂无订阅 + 添加” | 错误提示可用 MessageEvent 强化 |
| AddFeedPage | `loading` 禁用按钮 | 有 `message` 展示 | 不需要 | URL 校验前缀可更细 |
| FeedDetailPage | 无单独 loading | 无 | 列表空时自然空白 | 补加载/错误态 |
| PlayerPage | 无 | 无 | 有“暂无播放” | 补错误弹窗/重试 |
| QueuePage | `loading` 存在 | 失败静默置空 | 有“队列为空” | 操作失败提示 |
| DownloadsPage | 无 | 失败静默置空 | 有“暂无下载” | 补 loading |
| SettingsPage | 读取偏好即时 | 无 | 不需要 | 设置保存反馈 |
| SearchPage | `loading` 变量存在 | 有 message | 静默空结果 | 补“无结果”提示 |
| OpmlPage | 无 | 有 message | 不需要 | 导入/导出进度提示 |
| FavoritesPage | 无 | 失败静默置空 | 有“暂无收藏” | 补 loading |

整改优先级：FeedDetail/Player/Downloads 补 loading 与错误提示；所有静默 catch 改为 `EventHub` message 或页面 message。

## 2. 高频 SQL 与索引走查（T5.4）

| # | 查询 | 使用索引 | 审计结论 | 优化动作 |
|---|---|---|---|---|
| 1 | `SELECT * FROM Feeds WHERE state=1 ORDER BY custom_title,title` | 无专用索引 | 数据量<100，可接受 | 可加 `Feeds(state)` 索引 |
| 2 | `SELECT * FROM FeedItems WHERE feed=? ORDER BY pubdate DESC` | `FeedItems_feed` + `FeedItems_pubdate` | 已走索引 | 保持 |
| 3 | `SELECT COUNT(*) FROM FeedItems WHERE feed=? AND read=0` | `FeedItems_feed`,`FeedItems_read` | 已走索引 | 保持 |
| 4 | `SELECT * FROM FeedMedia WHERE feeditem=?` | `FeedMedia_feeditem` | 已走索引 | 保持 |
| 5 | `SELECT * FROM Queue ORDER BY id` | 主键 | 已走索引 | 保持 |
| 6 | 收藏联查 `FeedItems INNER JOIN Favorites` | `Favorites(feeditem)` + `FeedItems` 主键 | 可接受 | 可加 Favorites(feed) 组合索引 |

性能验证（设备可用后）：
- 启动时间目标 ≤ 2s
- 列表滚动 60fps（LazyForEach 已用于 Queue/Feed 详情）
- 1h 播放内存无持续增长
- 图片缓存上限 50MB LRU 清理

## 3. 已知待办
- 已用 LazyForEach + LazyDataSource：SubscriptionsPage / FeedDetailPage / QueuePage；其余列表仍为 ForEach（可继续优化）
- 图片磁盘缓存服务 `ImageCache` 尚未实现，当前 `Image` 组件直接网络加载（后续补）
- 数据库升级迁移器只有骨架，version>1 未实现
