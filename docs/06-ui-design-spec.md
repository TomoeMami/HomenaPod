# 06 · UI 设计规范（HarmonyOS 官方设计规范落地）

- 版本：1.1
- 制定日期：2026-09-09（第 24 轮 UI 改版；第 27 轮按上游 AntennaPod 布局对齐后更新）
- 适用：`antennapod-harmony/entry/src/main/ets` 全部页面与组件
- 目标 API：compatibleSdkVersion `5.0.2(14)`（基线 API 14，本机 SDK 26 编译）
- 布局基线：上游 AntennaPod 3.12.1（对齐明细与跳过项见 `07-ui-layout-parity.md`）

本规范是**唯一视觉事实来源**：新增页面/组件一律复用本规范的设计令牌与公共组件，
不允许再出现硬编码色值（`#RRGGBB`）或自成一套的圆角/间距。

---

## 1. 设计令牌

### 1.1 颜色（资源限定符自适应深浅色，代码里只写 `$r('app.color.*')`）

| 令牌 | 浅色 | 深色 | 用途 |
|---|---|---|---|
| `page_bg` | `#F1F3F5` | `#000000` | 页面底色 |
| `surface` | `#FFFFFF` | `#1C1C1E` | 卡片/列表行/弹层 |
| `surface_secondary` | `#F7F8FA` | `#2C2C2E` | 输入框、未选中胶囊、次级容器 |
| `surface_container` | `#EBEEF3` | `#1C2024` | 首页横滑卡片底、订阅瓦片外卡、迷你播放条（上游 `colorSurfaceContainer`） |
| `surface_container_playing` | `#C8D8DE` | `#3C4E68` | 正在播放的卡片底（上游 `colorSecondaryContainer`） |
| `cover_placeholder` | `#22777777` | `#22777777` | 无封面时的占位底（上游 `non_square_icon_background`） |
| `cover_text_bg` | `#55333333` | `#55333333` | 无封面时盖在占位底上的标题底（上游 `feed_text_bg`） |
| `pill_on_cover` | `#D2404040` | `#D2404040` | 封面右上角计数胶囊（上游 `bg_pill_translucent`） |
| `divider` | `#0D000000` | `#14FFFFFF` | 分割线 |
| `primary` | `#0A59F7` | `#4C8DFF` | 品牌色、选中态、主操作 |
| `primary_container` | `#EAF1FF` | `#22355C` | 次级/强调底（图标底、tonal 按钮、底部页签选中底） |
| `on_primary` | `#FFFFFF` | `#FFFFFF` | 品牌色上的文字/图标 |
| `text_primary` | `#DD000000` | `#E5FFFFFF` | 主文字 |
| `text_secondary` | `#99000000` | `#99FFFFFF` | 次文字 |
| `text_tertiary` | `#66000000` | `#66FFFFFF` | 辅助文字、未选中图标 |
| `text_disabled` | `#33000000` | `#33FFFFFF` | 禁用 |
| `success` | `#00A878` | `#3DD68C` | 成功/已播 |
| `error` | `#E84026` | `#FF6B5F` | 错误/危险操作 |
| `error_container` | `#FDECE8` | `#35201B` | 危险操作底（tonal 红） |
| `star` | `#FFB300` | `#FFC53D` | 收藏星标 |
| `badge_bg` | `#E84026` | `#FF6B5F` | 数字角标 |
| `scrubber_track` | `#26000000` | `#2EFFFFFF` | 进度条轨道 |

深浅色由 `resources/base/element/color.json` 与 `resources/dark/element/color.json`
两个限定符目录自动切换，**不需要任何运行时代码**；主题三态（跟随系统/浅色/深色）
由 `UserPreferences.setThemeMode` + `setColorMode` 驱动。

### 1.2 尺寸与字阶（`common/DesignTokens.ets`，单位 vp/fp）

- 栅格：8vp 基准；页面左右边距 `PAGE_MARGIN=16`；间距 `4/8/12/16/20/24`
- 圆角：列表行 `12`、卡片 `16`、底部弹层顶角 `24`、按钮/胶囊 `22`、筛选胶囊 `16`
- 高度：标题栏 `56`、底部导航 `64`（上游 `main.xml`）、按钮 `40`（紧凑 `32`）
- 封面尺寸：首页横滑卡片 `128`（`COVER_HOME_CARD`）、订阅瓦片 `96`（`COVER_FEED_TILE`）、
  列表行 `56`（`COVER_LIST`）、订阅详情头图 `124`（`COVER_DETAIL`）
- 图标：`16/18/20/22/24/28`；触控热区最小 `44`
- 字阶：`28/24/22/20/17/16/15/14/12/11/10`，字重仅用 Bold/Medium/Regular
- 底部导航文字 `11fp`（`FONT_NAV`，上游 `TextBottomNav` = 11sp）
- 图标体系：全部使用系统 Symbol 资源 `$r('sys.symbol.*')`（`SymbolGlyph`），
  `fontColor` 必须传数组：`.fontColor([$r('app.color.primary')])`

## 2. 公共组件（`entry/src/main/ets/components/`）

| 组件 | 职责 | 关键约定 |
|---|---|---|
| `AppBar` | 子页面标题栏 | 高 56，返回箭头 `chevron_backward`，`@BuilderParam trailing` 挂右侧动作 |
| `BottomTabItem` | 底部页签项 | 栏高 64、图标 24 + 文字 11，选中＝品牌色 + 填充图标 + `primary_container` 图标底胶囊 |
| `MiniPlayer` | 迷你播放条 | 整行 64vp（上游 `external_player_height`）：56vp 封面 + 标题/订阅名 16fp 单行 + 52vp 播放键 + 底部 4vp 进度条，底色 `surface_container` |
| `EpisodeCard` | 首页横滑卡片 | 128vp 封面 + 右下 48vp 播放圆钮 + 封面底 4vp 进度条 + 两行 14fp 标题 + 14fp 日期；底 `surface_container`（播放中 `surface_container_playing`） |
| `EpisodeRow` | 剧集列表行 | 可选拖拽手柄 + 56vp 封面（圆角 8）+ 状态图标行 + 两行 16fp 标题 + 进度行 + 48vp 次级操作；已播整行 0.5 透明度，选中 `primary_container` |
| `OverflowButton` | 溢出菜单按钮 | 44vp 热区 + `bindMenu`；**`bindMenu` 不能挂在带 `onClick` 的组件上**（会被吞掉），故单独封装 |
| `RowCard` | 通用卡片容器 | `pad/radius/chevron/onTap`，内容用尾随闭包注入；**尾随闭包后不能再挂通用属性**（ArkTS 报错），需要外边距时用外层容器包一层 |
| `SectionHeader` | 区块标题 | 16fp Medium + 可选乱序图标 + 可选数字胶囊（1vp 品牌色描边）+ 可选「更多」链接（文案 + 尾随箭头） |
| `TagChip` | 筛选/选择胶囊 | 选中=品牌色填充，未选中=`surface_secondary` |
| `EmptyState` | 空状态 | 96vp 圆形底 + 图标 + 主/副文案 |
| `AppIconButton` | 图标按钮 | 44vp 热区、图标 22、可选角标 |
| `FeedCover` | 订阅/剧集封面 | `coverSize/radius/fallbackTitle/placeholderColor/fill`；无图且有 `fallbackTitle` 时按上游 `fallbackTitleLabel` 画深色底白字，否则品牌色底 + 音乐图标 |

> 布局陷阱：**不要对 `width('100%')` 的元素加左右 `margin`**（会向右溢出）。
> 正确写法：外层 `Row().width('100%').padding({left:16,right:16})`，内层再 `width('100%')`。
> 已按此修正 `MiniPlayer`、`SubscriptionsPage` 搜索框。

> 布局陷阱 2：**`Scroll` 的子内容在滚动方向上默认居中**（子内容比视口短时上下出现大留白）。
> 所有 `Scroll` 容器统一加 `.align(Alignment.Top)`。已修正 6 处：`AddFeedPage`、
> `FeedSettingsPage`、`HomePage`、`PlayerPage`、`SettingsPage`、`StatsPage`。

> 布局陷阱 3：**`bindMenu` 不能挂在自身带 `onClick` 的组件上**（点击被 `onClick` 吞掉，菜单弹不出）。
> 实测 `AppIconButton(...).bindMenu(...)` 无效 → 统一改用 `components/OverflowButton.ets`
> （根容器是无 `onClick` 的 `Stack`）。

> 布局陷阱 4：**自定义组件用尾随闭包注入内容后，不能再挂通用属性**
> （`RowCard({...}) { ... }.margin(...)` 报 `Declaration or statement expected`）。
> 需要外边距时用外层 `Column`/`Row` 包一层再挂属性。

> 布局陷阱 5：**同一节点上 `onClick` 与 `gesture(...)` 不能共存**——普通点击会被手势竞争吞掉
> （实测 `EpisodeRow` 点行体无效、点行内图标有效）。长按与点击要并存时用 **`parallelGesture`**。
> 若长按挂在父级 `ListItem`、点击挂在子组件上，则不冲突。

> 布局陷阱 6：**`MenuItemOptions.startIcon` 只接受图片资源**，传 `$r('sys.symbol.*')` 会静默不显示图标；
> 符号图标必须用 `symbolStartIcon`（API 12 起，类型 `SymbolGlyphModifier`），见 `common/MenuIcons.ets`。

### 2.1 启动窗口（startWindowBackground）

`module.json5` 的 `startWindowBackground: "$color:start_window_background"`，
浅色 `#F1F3F5` / 深色 `#000000`，与 `page_bg` 保持一致。

**已知平台行为**：启动窗口由系统在应用代码执行前创建，因此遵循**系统**主题而非应用内
`setColorMode` 设定的主题。当系统为浅色、用户在应用内强制深色时，启动瞬间会有一次浅色
闪屏（模拟器实测已捕获到该启动窗口）。要彻底消除只能把 `startWindowBackground` 改为
中性色（会牺牲另一主题下的一致性），当前选择是「各自主题保持一致」，接受该平台行为。

## 3. 页面结构范式

1. **Tab 页**（首页/订阅/队列/下载/设置）：`Column` 顶栏为大标题（24fp Bold）+ 右侧图标动作，
   下方为内容区（`Scroll`/`List`），左右边距 16，底部由 `Index` 的导航栏承接。
2. **子页面**（详情/设置/播放等）：`AppBar` + 内容区，危险操作使用 `error_container` 底 + `error` 文字。
3. **弹层**：底部 sheet，`surface` 底 + 顶部圆角 24，选项行「图标 + 文案」，
   取消按钮 `surface_secondary` 底、确认按钮品牌色底。
4. **列表行**：卡片 `surface` + 圆角 12 + 内边距 12；主文案 15fp、辅助 12fp `text_tertiary`；
   尾部动作最多 3 个图标按钮，主操作（播放）用 36vp 品牌色圆形按钮。

## 4. 图标对照表（已在本机系统符号库中逐名核验）

| 场景 | 图标 |
|---|---|
| 首页 / 订阅 / 队列 / 下载 / 设置 | `house`,`house_fill` / `folder`,`folder_fill` / `list_bullet` / `download_1` / `gearshape`,`gearshape_fill` |
| 返回 / 前进 | `chevron_backward` / `chevron_forward` |
| 播放 / 暂停 | `play_fill` / `pause_fill`（圆形主按钮），`play_circle`（列表提示） |
| 快退 / 快进 | `arrow_left` / `arrow_right` |
| 倍速 / 循环 / 睡眠 | `fast` / `repeat` / `moon`,`moon_fill` |
| 收藏 / 已播 / 未播 | `star`,`star_fill` / `checkmark_circle_fill` / `circle` |
| 下载 / 删除 / 完成 / 失败 | `arrow_down_circle`,`download_1` / `trash` / `checkmark_circle_fill` / `xmark_circle_fill` |
| 刷新 / 搜索 / 编辑 / 更多 | `arrow_clockwise` / `magnifyingglass` / `square_and_pencil` / `ellipsis_circle` |
| 排序 / 过滤 / 锁定 | `sort` / `funnel` / `lock_open`,`lock_fill` |
| 历史 / 统计 / 存储 / 文档 | `clock` / `histogram` / `sdcard_fill` / `doc_text` |
| 警告 / 加号 / 关闭 | `warning` / `plus` / `xmark` |
| 拖拽手柄 / 下一集 / 更多页签 | `line_3_horizontal` / `forward_end_fill` / `more`,`more_fill` |
| 下箭头（播放页工具栏）/ 刷新失败 / 列数 / 显示标题 | `arrow_down` / `exclamationmark_circle` / `grid` / `textformat` |
| 添加播客 / 本地文件夹 / OPML 导入导出 | `link`,`rss` / `folder` / `download_1`,`upload` |

> `speed_multiple` 字形自带「1.75x」字样，与倍速标签重复，**已改用 `fast`**。
> 符号名必须在本机符号表核验：`$r('sys.symbol.x')` 中不存在的名字会在 `CompileArkTS`
> 阶段报 `Unknown resource name`（例如 `general_next_step` 并不在符号表中，已换成 `forward_end_fill`）。

## 5. 应用图标（`$media:app_icon`，SVG）

文件（两处必须保持一致）：
- `entry/src/main/resources/base/media/app_icon.svg`
- `AppScope/resources/base/media/app_icon.svg`

构图（1024×1024，用户提供图稿，等比 2× 放大后做鸿蒙兼容化改造）：

| 层 | 元素 | 参数 |
|---|---|---|
| 底 | 圆角方形 + 蓝→紫对角渐变（**满幅贴边**） | `rect (0,0) 1024×1024 rx=220`，渐变 `#3498DB → #0056B3 → #4A00E0`（offset 0%/50%/100%，左上→右下） |
| 2 | 声波三环 | 圆心 `(512,480)`，`r=200/300/400`、`stroke=56`；描边用横向白渐变 `#FFFFFF` 0.4→0.9→0.4，整环 `opacity` 0.9/0.7/0.4 |
| 3 | 人物柔影 | 同形黑色 20% + `feOffset dy=8` + `feGaussianBlur std=12` |
| 4 | 人物主体（读作字母 **A** / 播客者） | 头 `circle (512,420) r=64`；身体 `M340 870 L512 420 L684 870`；双臂 `M390 660 Q512 780 634 660`；均 `stroke=68`、`linecap/linejoin=round`、纯白 |

兼容化改造（相对用户原始图稿）：

- **去掉卡片外投影与 2% 内缩**：原图稿是「`rect (10,10) 492×492` + `feDropShadow`」的浮起卡片，
  栅格化后圆角方形四周留出透明边距、且投影在画布上下边缘被**硬裁切**——桌面图标上表现为
  **上下各漏一条黑色横带**（实测底边 `y=505…511` 为 `#000000`、alpha 28–41；顶边 alpha 4–9）。
  现改为 `rect (0,0) 1024×1024` 满幅贴边、**不再绘制外投影**；人物内侧柔影保留。
- `feDropShadow` → `feOffset + feGaussianBlur`：官方《SVG标签说明》的滤镜支持列表只有
  `feOffset / feGaussianBlur / feBlend / feComposite / feColorMatrix / feFlood`，**不含 `feDropShadow`**；
  未知滤镜可能导致整层不渲染，故拆成「一层半透明黑影 + 主图形」实现。
- 删除 `mask`：遮罩挖空区域（头 + 身体 + 双臂）与随后绘制的白色人物几何**完全重合**，
  去掉后像素级等价；且 `mask` 引用不在基础形状的通用属性列表中。
- 坐标整体 ×2（512 → 1024），比例不变。

渲染链路（本轮实测）：

- `CompileResource` 会把 `app_icon.svg` **栅格化为 512×512 PNG** 再打包（HAP 内为
  `resources/base/media/app_icon.png`，中间产物同名）；桌面图标与启动窗口用的都是这张位图。
- 渐变 `stop-opacity` 与 `feGaussianBlur` 在栅格化阶段均正常生效（导出该 PNG 可见投影与声波渐隐）。
- 两处 SVG 内容必须一致（内容相同，资源编译后合成同一个 `app_icon` 资源）。

> 遗留：模拟器上仍装着改名前的旧包 `de.danoeh.antennapod`（旧 X 图标），
> 与本项目包 `com.homenapod.app` 并存于桌面；未卸载，需用户确认后处理。

## 6. 验收方式（本轮采用）

1. `arkts_check`（ArkTS 严格模式静态检查）全绿
2. hvigor `assembleHap` 编译通过（`SignHap` 因既有签名配置失败，与 UI 无关）
3. 模拟器 `127.0.0.1:5555` 安装未签名 HAP → 启动 → 逐页截图 + UI dump 取证
4. 浅色 / 深色两种主题各验一轮
5. 图标验证：`aa start` 后 0.2s `snapshot_display` 抓启动窗口（大尺寸显示图标）+ 桌面截图
