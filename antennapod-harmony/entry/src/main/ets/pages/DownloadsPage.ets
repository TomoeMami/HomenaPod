import { DownloadLogEntry } from '../model/DownloadLogEntry';
import { FeedItem } from '../model/FeedItem';
import { DownloadLogRepository } from '../db/repositories/DownloadLogRepository';
import { EpisodeRepository, MediaRef } from '../db/repositories/EpisodeRepository';
import { DownloadManager } from '../download/DownloadManager';
import { DownloadErrorLabel } from '../common/DownloadErrorLabel';
import { openEpisodeDetail } from '../common/EpisodeRoute';
import { EventHub, EventType } from '../events/EventHub';
import { LazyDataSource } from '../components/LazyDataSource';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { SectionHeader } from '../components/SectionHeader';
import { EpisodeRow } from '../components/EpisodeRow';
import { EmptyState } from '../components/EmptyState';

/** 下载页展示用的活动任务行 */
interface ActiveDownloadRow {
  mediaId: number;
  title: string;
  state: string;
  received: number;
  total: number;
}

/**
 * 下载页（对齐上游 `simple_list_fragment.xml` + `download_log_fragment.xml`）：
 * 56vp 标题栏（返回箭头 + 「清除历史」trash 动作），下方为同一列表里的两个区块 ——
 * 「Downloads」进行中任务（进度行：已下载大小 + 4vp 进度条 + 百分比）与「Completed」下载记录，
 * 行均使用共享 `EpisodeRow`（上游 `feeditemlist_item.xml` 几何）。
 */
@Entry
@Component
export struct DownloadsPage {
  private dataSource: LazyDataSource<DownloadLogEntry> = new LazyDataSource<DownloadLogEntry>();
  @State entries: DownloadLogEntry[] = [];
  @State activeRows: ActiveDownloadRow[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State menuRow: ActiveDownloadRow | undefined = undefined;
  @State showRowMenu: boolean = false;
  private token: number = -1;
  private progressReceived: Map<number, number> = new Map<number, number>();
  private progressTotal: Map<number, number> = new Map<number, number>();
  /**
   * media id → 单集（封面 + 单击进详情页）。
   * DownloadLog 表与 DownloadManager 的活动任务都只存 media id 与标题，展示封面得回查单集；
   * 进度事件会频繁重进 `loadActive`，故查到的结果缓存下来，同一 media id 只查一次。
   */
  private mediaRefs: Map<number, MediaRef> = new Map<number, MediaRef>();

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        AppBar({ title: $r('app.string.tab_downloads'), showBack: true }) {
          if (this.entries.length > 0) {
            AppIconButton({
              symbol: $r('sys.symbol.trash'),
              onTap: () => {
                this.clearHistory();
              }
            })
          }
        }

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
        }

        List({ space: DesignTokens.SPACE_XS }) {
          // 进行中的下载（上游 download_log_fragment 的列表内容）
          ListItem() {
            SectionHeader({
              title: $r('app.string.tab_downloads'),
              countPill: this.activeRows.length
            })
          }

          if (this.activeRows.length === 0) {
            ListItem() {
              EmptyState({
                icon: $r('sys.symbol.download_1'),
                title: $r('app.string.downloads_empty')
              })
            }
          } else {
            ForEach(this.activeRows, (row: ActiveDownloadRow) => {
              ListItem() {
                this.activeRow(row)
              }
            }, (row: ActiveDownloadRow) => 'a-' + row.mediaId.toString())
          }

          // 已完成的下载记录
          ListItem() {
            SectionHeader({
              title: $r('app.string.downloads_section_completed'),
              countPill: this.entries.length
            })
          }

          if (this.loading) {
            ListItem() {
              Text($r('app.string.loading'))
                .fontSize(DesignTokens.FONT_PARAGRAPH)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .padding({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
            }
          } else if (this.entries.length === 0) {
            ListItem() {
              EmptyState({
                icon: $r('sys.symbol.download_1'),
                title: $r('app.string.placeholder_downloads'),
                sub: $r('app.string.downloads_empty_hint')
              })
            }
          } else {
            LazyForEach(this.dataSource, (entry: DownloadLogEntry) => {
              ListItem() {
                this.logRow(entry)
              }
            }, (entry: DownloadLogEntry) => 'l-' + entry.id.toString())
          }
        }
        .layoutWeight(1)
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_M })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.showRowMenu) {
        this.activeMenu()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 进行中下载行：进度行 = 已下载大小 + 4vp 进度条 + 百分比；长按打开操作菜单 */
  @Builder
  activeRow(row: ActiveDownloadRow) {
    EpisodeRow({
      title: row.title === '' ? '#' + row.mediaId : row.title,
      imageUrl: this.rowImage(row.mediaId),
      coverFallbackTitle: row.title,
      metaText: this.stateText(row),
      positionText: this.sizeText(row),
      durationText: this.progressPercent(row).toString() + '%',
      progress: this.progressPercent(row),
      actionIcon: row.state === 'PAUSED' ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'),
      actionTint: $r('app.color.primary'),
      showAction: true,
      onTap: () => {
        // 单击行 = 打开单集详情页（与收件箱一致）；暂停/继续仍走右侧操作钮
        if (!this.openMediaDetail(row.mediaId)) {
          this.togglePause(row);
        }
      },
      onAction: () => {
        this.togglePause(row);
      },
      onLongPress: () => {
        this.menuRow = row;
        this.showRowMenu = true;
      }
    })
  }

  /** 下载记录行（上游 downloadlog_item.xml）：标题 + 状态 · 时间 · 失败原因，失败行可重试 */
  @Builder
  logRow(entry: DownloadLogEntry) {
    EpisodeRow({
      title: entry.downloadStatusTitle === '' ? '#' + entry.feedFileId : entry.downloadStatusTitle,
      imageUrl: this.rowImage(entry.feedFileId),
      coverFallbackTitle: entry.downloadStatusTitle,
      metaText: this.statusText(entry),
      subtitle: this.reasonText(entry),
      showAction: !entry.successful,
      actionIcon: $r('sys.symbol.arrow_clockwise'),
      actionTint: $r('app.color.primary'),
      onTap: () => {
        // 单击行 = 打开单集详情页（与收件箱一致）；失败行的重试仍走右侧操作钮
        this.openMediaDetail(entry.feedFileId);
      },
      onAction: () => {
        this.retry(entry);
      }
    })
  }

  /** 行封面：DownloadLog / 活动任务只存 media id，封面由 `mediaRefs` 反查得到 */
  private rowImage(mediaId: number): string {
    const ref: MediaRef | undefined = this.mediaRefs.get(mediaId);
    return ref === undefined ? '' : ref.imageUrl;
  }

  /** 单击行 → 单集详情页；返回 false 表示该 media 已查不到对应单集（调用方自行兜底） */
  private openMediaDetail(mediaId: number): boolean {
    const ref: MediaRef | undefined = this.mediaRefs.get(mediaId);
    if (ref === undefined || ref.itemId <= 0) {
      return false;
    }
    openEpisodeDetail(ref.itemId);
    return true;
  }

  /** 补查缺失的 media id → 单集信息（已缓存的 media id 不重复查库） */
  private async ensureMediaRefs(mediaIds: number[]): Promise<void> {
    const missing: number[] = [];
    for (const mediaId of mediaIds) {
      if (mediaId > 0 && !this.mediaRefs.has(mediaId)) {
        missing.push(mediaId);
      }
    }
    if (missing.length === 0) {
      return;
    }
    const refs: Map<number, MediaRef> = await EpisodeRepository.mediaRefs(missing);
    refs.forEach((ref: MediaRef, mediaId: number) => {
      this.mediaRefs.set(mediaId, ref);
    });
  }

  /**
   * 失败原因文案（对照上游 DownloadErrorLabel：22 种错误 → 文案）。
   * 这里按**资源名**取字符串：`$r()` 的资源 id 必须在编译期确定，
   * 用 `$r('app.string.' + name)` 这种运行期拼出来的写法在真机上拿到的是 id 0，
   * `getStringSync(0)` 会抛 `Invalid resource ID: 0` 直接把应用带崩（实测崩溃日志 jscrash 9001001）。
   */
  reasonText(entry: DownloadLogEntry): string {
    if (entry.successful) {
      return '';
    }
    const code: number = DownloadErrorLabel.parseCode(entry.reasonDetailed);
    if (code < 0) {
      return entry.reasonDetailed;
    }
    return getContext(this).resourceManager.getStringByNameSync(DownloadErrorLabel.resourceName(code));
  }

  /** 重试下载（上游 download_log 行内重试按钮） */
  async retry(entry: DownloadLogEntry): Promise<void> {
    try {
      const item: FeedItem | undefined = await EpisodeRepository.getByMediaId(entry.feedFileId);
      if (item === undefined || item.media === undefined || item.media.downloadUrl === '') {
        this.message = getContext(this).resourceManager.getStringSync($r('app.string.download_fail'));
        return;
      }
      await DownloadManager.startDownload(item.media, item.title);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 长按操作菜单（暂停/继续 + 取消下载） */
  @Builder
  activeMenu() {
    Column({ space: 2 }) {
      Text(this.menuTitle())
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding(DesignTokens.SPACE_L)

      this.menuItem(
        this.menuPaused() ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'),
        this.menuPaused() ? $r('app.string.episode_download_resume') : $r('app.string.episode_download_pause'),
        () => {
          this.toggleMenuRow();
        })

      this.menuItem($r('sys.symbol.xmark'), $r('app.string.episode_download_cancel'), () => {
        this.cancelMenuRow();
      })

      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
        .onClick(() => {
          this.showRowMenu = false;
          this.menuRow = undefined;
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
  }

  @Builder
  menuItem(icon: Resource, label: ResourceStr, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_M }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_L)
        .fontColor([$r('app.color.text_secondary')])
      Text(label)
        .fontSize(DesignTokens.FONT_SUBTITLE)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left: DesignTokens.SPACE_S, top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M })
    .onClick(() => {
      onTap();
    })
  }

  aboutToAppear(): void {
    this.load();
    this.token = EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.onDownloadEvent(data as Record<string, Object>);
    });
  }

  aboutToDisappear(): void {
    if (this.token >= 0) {
      EventHub.unsubscribeToken(this.token);
      this.token = -1;
    }
  }

  onDownloadEvent(record: Record<string, Object>): void {
    const mediaId: number = record['mediaId'] as number;
    const state: string = record['state'] as string;
    if (state === 'PROGRESS') {
      this.progressReceived.set(mediaId, record['received'] as number);
      this.progressTotal.set(mediaId, record['total'] as number);
    }
    this.loadActive();
    if (state === 'DONE' || state === 'FAILED') {
      this.loadHistory();
    }
  }

  async load(): Promise<void> {
    await this.loadActive();
    await this.loadHistory();
  }

  /**
   * 刷新进行中的任务行。封面要先补齐再赋给 `activeRows`：
   * 行一旦渲染，`EpisodeRow` 的 `imageUrl` 就定下来了（`mediaRefs` 不是状态变量）。
   */
  async loadActive(): Promise<void> {
    const tasks: Map<number, string> = DownloadManager.getActiveTasks();
    const rows: ActiveDownloadRow[] = [];
    const mediaIds: number[] = [];
    tasks.forEach((state: string, mediaId: number) => {
      if (state === 'DONE' || state === 'REMOVED' || state === 'FAILED') {
        return;
      }
      const received: number | undefined = this.progressReceived.get(mediaId);
      const total: number | undefined = this.progressTotal.get(mediaId);
      mediaIds.push(mediaId);
      rows.push({
        mediaId: mediaId,
        title: DownloadManager.getTitle(mediaId),
        state: state,
        received: received === undefined ? 0 : received,
        total: total === undefined ? 0 : total
      });
    });
    try {
      await this.ensureMediaRefs(mediaIds);
    } catch (error) {
      // 取不到封面不影响进度展示
    }
    this.activeRows = rows;
  }

  async loadHistory(): Promise<void> {
    this.loading = true;
    try {
      const entries: DownloadLogEntry[] = await DownloadLogRepository.list();
      try {
        await this.ensureMediaRefs(entries.map((entry: DownloadLogEntry) => entry.feedFileId));
      } catch (error) {
        // 取不到封面不影响下载记录展示
      }
      this.entries = entries;
      this.dataSource.setData(entries);
    } catch (error) {
      this.entries = [];
      this.dataSource.setData([]);
    } finally {
      this.loading = false;
    }
  }

  /** 清除下载记录（上游 menu/download_log.xml 的 clear_logs_item） */
  async clearHistory(): Promise<void> {
    try {
      await DownloadLogRepository.clear();
      await this.loadHistory();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 活动任务进度百分比 */
  progressPercent(row: ActiveDownloadRow): number {
    if (row.total <= 0) {
      return 0;
    }
    const percent: number = Math.floor(row.received * 100 / row.total);
    return percent > 100 ? 100 : percent;
  }

  /** 活动任务状态文案 */
  stateText(row: ActiveDownloadRow): string {
    if (row.state === 'PAUSED') {
      return getContext(this).resourceManager.getStringSync($r('app.string.episode_download_paused'));
    }
    return getContext(this).resourceManager.getStringSync($r('app.string.episode_downloading'));
  }

  /** 活动任务已下载 / 总大小 */
  sizeText(row: ActiveDownloadRow): string {
    if (row.total <= 0) {
      return '';
    }
    return this.fileSize(row.received) + ' / ' + this.fileSize(row.total);
  }

  fileSize(bytes: number): string {
    if (bytes <= 0) {
      return '0 KB';
    }
    const mb: number = bytes / (1024 * 1024);
    if (mb < 1) {
      return (bytes / 1024).toFixed(0) + ' KB';
    }
    return mb.toFixed(1) + ' MB';
  }

  /** 下载记录状态行：成功/失败 · 完成时间 */
  statusText(entry: DownloadLogEntry): string {
    const status: string = getContext(this).resourceManager.getStringSync(entry.successful
      ? $r('app.string.download_ok') : $r('app.string.download_fail'));
    const time: string = this.timeText(entry);
    return time === '' ? status : status + ' · ' + time;
  }

  timeText(entry: DownloadLogEntry): string {
    if (entry.completionDate <= 0) {
      return '';
    }
    return new Date(entry.completionDate).toLocaleString();
  }

  menuTitle(): string {
    const row: ActiveDownloadRow | undefined = this.menuRow;
    if (row === undefined) {
      return '';
    }
    return row.title === '' ? '#' + row.mediaId : row.title;
  }

  menuPaused(): boolean {
    const row: ActiveDownloadRow | undefined = this.menuRow;
    return row !== undefined && row.state === 'PAUSED';
  }

  togglePause(row: ActiveDownloadRow): void {
    if (row.state === 'PAUSED') {
      DownloadManager.resume(row.mediaId);
    } else {
      DownloadManager.pause(row.mediaId);
    }
  }

  toggleMenuRow(): void {
    const row: ActiveDownloadRow | undefined = this.menuRow;
    this.showRowMenu = false;
    this.menuRow = undefined;
    if (row !== undefined) {
      this.togglePause(row);
    }
  }

  cancelMenuRow(): void {
    const row: ActiveDownloadRow | undefined = this.menuRow;
    this.showRowMenu = false;
    this.menuRow = undefined;
    if (row === undefined) {
      return;
    }
    DownloadManager.remove(row.mediaId).then(() => {
      this.loadActive();
    });
  }
}
