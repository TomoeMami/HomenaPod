import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { DownloadManager } from '../download/DownloadManager';
import { PlayerManager } from '../player/PlayerManager';
import { QueueEngine } from '../player/QueueEngine';
import { Playable } from '../model/Playable';
import { EventHub, EventType, EpisodeDownloadData, FeedItemUpdateData } from '../events/EventHub';
import { DurationUtils } from '../utils/DurationUtils';
import { ShownotesSegment, ShownotesText } from '../utils/ShownotesText';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { FeedCover } from '../components/FeedCover';
import { ShownotesBody } from '../components/ShownotesBody';

interface EpisodeDetailParams {
  itemId: number;
}

/**
 * 单集详情页（对照上游 `feeditem_fragment.xml` + `ui/screen/episode/ItemFragment.java`）：
 *
 * 头部 = 56vp 封面 + 订阅名（点击进订阅详情）+ 单集标题（最多 5 行）+ 「时长 · 发布日期」；
 * 动作行 = 主操作（播放 / 暂停 / 在线播放）+ 次操作（下载 / 取消下载 / 删除文件，带下载进度环）；
 * 正文 = 节目详情（shownotes，纯文本但保留换行，落在时长内的时间码可点跳转）。
 *
 * 上游没有媒体时主操作是「标记为已播」、次操作是「访问网站」；本移植版把次操作换成分享
 * （无系统分享面板，与其它页面一致：复制链接到剪贴板）。
 *
 * 入口：收件箱列表单击（上游 `EpisodeItemListAdapter` 同样把单击接到单集详情页）；
 * 其它列表仍是「单击直接播放」（第 41 轮 parity 文档第 35 条的选择），故播放页仍保留同一个
 * 「节目详情」弹层。
 *
 * 开始播放后**留在本页**（与上游 ItemFragment 一致，正文可以边听边看）：上游靠常驻的迷你播放条
 * 回播放页，本移植版的详情页是路由页、没有迷你播放条，故在本集成为当前播放项后由标题栏给一个
 *「打开播放页」按钮。
 */
@Entry
@Component
struct EpisodeDetailPage {
  @State item: FeedItem | undefined = undefined;
  @State feed: Feed | undefined = undefined;
  @State segments: ShownotesSegment[] = [];
  @State status: string = 'IDLE';
  /**
   * 当前播放项的 media id（-1 = 无）。
   * `PlayerManager` 的内部状态不是 @State，标题栏「打开播放页」按钮的显隐必须依赖一个
   * @State 才会随播放状态刷新，故把当前播放项 id 也镜像到页面状态里。
   */
  @State currentMediaId: number = -1;
  @State message: string = '';
  /** 下载进度百分比；-1 = 不显示进度环（对照上游 `circularProgressBar`） */
  @State downloadProgress: number = -1;
  @State downloadIndeterminate: boolean = false;
  private itemId: number = 0;
  private messageTimerId: number = -1;
  private itemToken: number = -1;
  private playerToken: number = -1;
  private downloadToken: number = -1;

  build() {
    Column() {
      AppBar({
        title: this.feed === undefined ? $r('app.string.episode_detail_title') : this.feedTitle(),
        showBack: true
      }) {
        // 上游靠常驻迷你播放条回播放页；本移植版的详情页是路由页、没有迷你播放条，
        // 因此在本集就是当前播放项时给一个标题栏入口
        if (this.isCurrentItem()) {
          AppIconButton({
            symbol: $r('sys.symbol.play_circle'),
            onTap: () => {
              router.pushUrl({ url: 'pages/PlayerPage' });
            }
          })
        }
      }

      if (this.message !== '') {
        Text(this.message)
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.primary'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
      }

      if (this.item === undefined) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('app.color.primary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        this.content()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  content() {
    Scroll() {
      Column({ space: DesignTokens.SPACE_L }) {
        this.header()
        this.actionRow()

        if (this.media() === undefined) {
          Text($r('app.string.no_media_label'))
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }

        Divider()
          .color($r('app.color.divider'))
          .strokeWidth(1)

        if (this.segments.length === 0) {
          Text($r('app.string.no_shownotes_label'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else {
          ShownotesBody({
            segments: this.segments,
            onTimecode: (timeMs: number) => {
              this.seekToTimecode(timeMs);
            }
          })
        }
      }
      .width('100%')
      .padding({
        left: DesignTokens.PAGE_MARGIN,
        right: DesignTokens.PAGE_MARGIN,
        top: DesignTokens.SPACE_M,
        bottom: DesignTokens.SPACE_XXL
      })
    }
    .layoutWeight(1)
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  /** 头部：封面 + 订阅名 + 标题 + 「时长 · 发布日期」（对照 feeditem_fragment.xml 的 header 首行） */
  @Builder
  header() {
    Row() {
      Row() {
        FeedCover({
          imageUrl: this.itemImage(),
          coverSize: DesignTokens.COVER_LIST,
          radius: 8,
          fallbackTitle: this.feedTitle(),
          placeholderColor: $r('app.color.cover_placeholder')
        })
      }
      .onClick(() => {
        this.openFeed();
      })

      Column({ space: DesignTokens.SPACE_XS }) {
        Text(this.feedTitle())
          .fontSize(DesignTokens.FONT_CAPTION)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .onClick(() => {
            this.openFeed();
          })

        Text(this.itemTitle())
          .fontSize(DesignTokens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: DesignTokens.SPACE_XS }) {
          Text(this.durationText())
            .fontSize(DesignTokens.FONT_CAPTION)
            .fontColor($r('app.color.text_secondary'))
          if (this.durationText() !== '' && this.pubDateText() !== '') {
            Text('·')
              .fontSize(DesignTokens.FONT_CAPTION)
              .fontColor($r('app.color.text_secondary'))
          }
          Text(this.pubDateText())
            .fontSize(DesignTokens.FONT_CAPTION)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: DesignTokens.SPACE_L })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 动作行：主操作 + 次操作（各占一半，对照 feeditem_fragment.xml 的 butAction1 / butAction2）。
   *
   * 注意：两个按钮各自是**无参** @Builder，图标与文案在 builder 内部读 `@State`——
   * `@Builder` 的**参数是值传递**，把 `this.primaryLabel()` 当参数传进去，
   * 播放状态变化后按钮文案不会刷新（第 40 轮设置页「排序方式」行踩过同一个坑）。
   */
  @Builder
  actionRow() {
    Row() {
      this.primaryButton()
      this.secondaryButton()
    }
    .width('100%')
  }

  /** 主操作按钮：24vp 图标 + 文案（图标/文案都在内部求值，随播放状态刷新） */
  @Builder
  primaryButton() {
    Row({ space: DesignTokens.SPACE_S }) {
      Stack() {
        SymbolGlyph(this.primaryIcon())
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .alignContent(Alignment.Center)

      Text(this.primaryLabel())
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(DesignTokens.HIT_MIN)
    .justifyContent(FlexAlign.Center)
    .borderRadius(DesignTokens.RADIUS_ROW)
    .onClick(() => {
      this.primaryAction();
    })
  }

  /** 次操作按钮：图标外圈带下载进度环（`downloadProgress < 0` 时不画） */
  @Builder
  secondaryButton() {
    Row({ space: DesignTokens.SPACE_S }) {
      Stack() {
        if (this.downloadProgress >= 0) {
          Progress({ value: this.downloadProgress, total: 100, type: ProgressType.Ring })
            .width(40)
            .height(40)
            .color($r('app.color.primary'))
            .backgroundColor($r('app.color.scrubber_track'))
            .style({
              strokeWidth: 3,
              status: this.downloadIndeterminate ? ProgressStatus.LOADING : ProgressStatus.PROGRESSING,
              enableSmoothEffect: !this.downloadIndeterminate
            })
        }
        SymbolGlyph(this.secondaryIcon())
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .alignContent(Alignment.Center)

      Text(this.secondaryLabel())
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(DesignTokens.HIT_MIN)
    .justifyContent(FlexAlign.Center)
    .borderRadius(DesignTokens.RADIUS_ROW)
    .onClick(() => {
      this.secondaryAction();
    })
  }

  // ---------------------------------------------------------------- 生命周期

  aboutToAppear(): void {
    const params: EpisodeDetailParams = router.getParams() as EpisodeDetailParams;
    this.itemId = params === undefined || params === null ? 0 : params.itemId;
    this.load();
    // 别处改了这一集（播放页听完自动标已播、订阅详情移出收件箱…）→ 本页同步
    this.itemToken = EventHub.subscribe(EventType.FEED_ITEM_UPDATE, (data: object) => {
      this.onFeedItemUpdate(data);
    });
    // 播放状态变化：主操作在「播放 / 暂停」之间切换
    this.playerToken = EventHub.subscribe(EventType.PLAYER_STATUS, (data: object) => {
      this.syncPlayerState();
    });
    // 下载进度：只改本页的进度环与次操作
    this.downloadToken = EventHub.subscribe(EventType.EPISODE_DOWNLOAD, (data: object) => {
      this.onDownloadEvent(data);
    });
  }

  /** 从播放页返回时重读一次（上游 ItemFragment.onResume → updateAppearance） */
  onPageShow(): void {
    this.refreshState();
  }

  aboutToDisappear(): void {
    const tokens: number[] = [this.itemToken, this.playerToken, this.downloadToken];
    for (const token of tokens) {
      if (token >= 0) {
        EventHub.unsubscribeToken(token);
      }
    }
    this.itemToken = -1;
    this.playerToken = -1;
    this.downloadToken = -1;
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
      this.messageTimerId = -1;
    }
  }

  // ---------------------------------------------------------------- 数据

  async load(): Promise<void> {
    try {
      const fresh: FeedItem | undefined = await EpisodeRepository.getById(this.itemId);
      if (fresh === undefined) {
        this.item = undefined;
        return;
      }
      this.item = fresh;
      this.feed = await FeedRepository.getById(fresh.feedId);
      // 正文只在换集时重算，返回本页不重排（避免阅读位置跳动）
      this.segments = ShownotesText.segments(fresh.description, EpisodeDetailPage.durationOf(fresh));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
    this.refreshState();
  }

  /** 重读单集与播放/下载状态（返回本页 / 下载完成 / 播放状态变化时用） */
  async refreshState(): Promise<void> {
    if (this.itemId > 0) {
      try {
        const fresh: FeedItem | undefined = await EpisodeRepository.getById(this.itemId);
        if (fresh !== undefined) {
          this.item = fresh;
        }
      } catch (error) {
        this.message = (error as Error).message;
      }
    }
    this.syncPlayerState();
    // getProgressPercent / isProgressIndeterminate 只在 RUNNING / PAUSED 时给有效值，其余返回 -1 / false
    const media: FeedMedia | undefined = this.media();
    this.downloadProgress = media === undefined ? -1 : DownloadManager.getProgressPercent(media.id);
    this.downloadIndeterminate = media !== undefined && DownloadManager.isProgressIndeterminate(media.id);
  }

  /** 把播放器状态镜像到页面 @State（播放状态 / 当前播放项都要，见 `currentMediaId` 的说明） */
  private syncPlayerState(): void {
    this.status = PlayerManager.getStatus();
    const current: Playable | undefined = PlayerManager.getCurrent();
    this.currentMediaId = current === undefined ? -1 : current.id;
  }

  private onFeedItemUpdate(data: object): void {
    const payload: FeedItemUpdateData = data as FeedItemUpdateData;
    if (payload.itemId === 0 || payload.itemId === this.itemId) {
      this.refreshState();
    }
  }

  private onDownloadEvent(data: object): void {
    const payload: EpisodeDownloadData = data as EpisodeDownloadData;
    const media: FeedMedia | undefined = this.media();
    if (media === undefined || payload.mediaId !== media.id) {
      return;
    }
    if (payload.state === 'DONE' || payload.state === 'REMOVED') {
      // file_url 变了：重查库让主/次操作切到「播放 / 删除文件」
      this.refreshState();
      return;
    }
    this.downloadProgress = DownloadManager.getProgressPercent(media.id);
    this.downloadIndeterminate = DownloadManager.isProgressIndeterminate(media.id);
  }

  // ---------------------------------------------------------------- 动作

  /**
   * 主操作（对照上游 `updateButtons` 的 actionButton1）：
   * 无媒体 → 标记已播 / 未播；正在播放 → 暂停；其余 → 播放（未下载时即在线播放）。
   */
  async primaryAction(): Promise<void> {
    const item: FeedItem | undefined = this.item;
    if (item === undefined) {
      return;
    }
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      await this.togglePlayed(item);
      return;
    }
    if (this.isCurrentPlaying()) {
      PlayerManager.pause();
      return;
    }
    try {
      const playable: Playable | undefined = await QueueEngine.toPlayable(item);
      if (playable === undefined) {
        return;
      }
      await QueueEngine.ensureQueued(item);
      await PlayerManager.load(playable, media.position, true);
      // 与上游 ItemFragment 一致：留在本页（正文可以边听边看），由标题栏的
      //「打开播放页」按钮进播放页；播放页里同样有「节目详情」弹层
      this.syncPlayerState();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 次操作（对照上游 `updateButtons` 的 actionButton2）：下载中 → 取消；已下载 → 删除文件；否则 → 下载 */
  async secondaryAction(): Promise<void> {
    const item: FeedItem | undefined = this.item;
    if (item === undefined) {
      return;
    }
    const media: FeedMedia | undefined = item.media;
    if (media === undefined) {
      await this.share(item);
      return;
    }
    const state: string = this.downloadState(media);
    if (state === 'RUNNING' || state === 'PAUSED') {
      await this.cancelDownload(media);
      return;
    }
    if (media.fileUrl !== '') {
      await this.deleteFile(media);
      return;
    }
    await this.startDownload(item, media);
  }

  private async startDownload(item: FeedItem, media: FeedMedia): Promise<void> {
    if (media.downloadUrl === '') {
      return;
    }
    try {
      await DownloadManager.startDownload(media, item.title);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.episode_downloading')));
      await this.refreshState();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  private async cancelDownload(media: FeedMedia): Promise<void> {
    try {
      await DownloadManager.remove(media.id);
      await this.refreshState();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  private async deleteFile(media: FeedMedia): Promise<void> {
    try {
      await DownloadManager.deleteFile(media);
      await this.refreshState();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 无媒体的单集：标记已播 / 未播（上游 MarkAsPlayedActionButton） */
  private async togglePlayed(item: FeedItem): Promise<void> {
    try {
      await EpisodeRepository.markPlayed(item.id, !item.isPlayed);
      const data: FeedItemUpdateData = { feedId: item.feedId, itemId: item.id };
      EventHub.publish(EventType.FEED_ITEM_UPDATE, data);
      this.showMessage(getContext(this).resourceManager.getStringSync(
        item.isPlayed ? $r('app.string.marked_unplayed_message') : $r('app.string.marked_played_message')));
      await this.refreshState();
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /** 无媒体单集的次操作 / 分享：复制单集链接到剪贴板（与其它页面口径一致） */
  private async share(item: FeedItem): Promise<void> {
    let link: string = item.link;
    if (link === '' && item.media !== undefined) {
      link = item.media.downloadUrl;
    }
    if (link === '') {
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.share_no_link')));
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showMessage(getContext(this).resourceManager.getStringSync($r('app.string.share_copied')));
    } catch (error) {
      this.showMessage((error as Error).message);
    }
  }

  /**
   * 点按正文里的时间码（上游 `ShownotesWebView.setTimecodeSelectedListener`）：
   * 只有这一集就是当前播放项时才跳转，否则提示先播放这一集。
   */
  private seekToTimecode(timeMs: number): void {
    const media: FeedMedia | undefined = this.media();
    const current: Playable | undefined = PlayerManager.getCurrent();
    if (media === undefined || current === undefined || current.id !== media.id) {
      this.showMessage(getContext(this).resourceManager
        .getStringSync($r('app.string.play_this_to_seek_position_message')));
      return;
    }
    PlayerManager.seek(timeMs);
  }

  private openFeed(): void {
    const feedId: number = this.item === undefined ? 0 : this.item.feedId;
    if (feedId <= 0) {
      return;
    }
    router.pushUrl({ url: 'pages/FeedDetailPage', params: { feedId: feedId } });
  }

  // ---------------------------------------------------------------- 展示

  private media(): FeedMedia | undefined {
    return this.item === undefined ? undefined : this.item.media;
  }

  private downloadState(media: FeedMedia): string {
    if (media.fileUrl !== '') {
      return 'DONE';
    }
    return DownloadManager.getStatus(media.id);
  }

  /** 当前播放项就是这一集且正在播放（上游 `PlaybackStatus.isPlaying`） */
  isCurrentPlaying(): boolean {
    return this.isCurrentItem() && this.status === 'PLAYING';
  }

  /** 当前播放项就是这一集（不要求正在播放；上游 `PlaybackStatus.isCurrentlyPlaying(media)`） */
  isCurrentItem(): boolean {
    const media: FeedMedia | undefined = this.media();
    return media !== undefined && this.currentMediaId === media.id;
  }

  /** 主操作的图标与文案（与 `primaryAction` 一一对应） */
  primaryIcon(): Resource {
    const media: FeedMedia | undefined = this.media();
    if (media === undefined) {
      const played: boolean = this.item !== undefined && this.item.isPlayed;
      return played ? $r('sys.symbol.circle') : $r('sys.symbol.checkmark_circle');
    }
    return this.isCurrentPlaying() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill');
  }

  primaryLabel(): ResourceStr {
    const media: FeedMedia | undefined = this.media();
    if (media === undefined) {
      const played: boolean = this.item !== undefined && this.item.isPlayed;
      return played ? $r('app.string.episode_mark_unplayed') : $r('app.string.episode_mark_played');
    }
    if (this.isCurrentPlaying()) {
      return $r('app.string.player_pause');
    }
    // 未下载 = 在线播放（上游 StreamActionButton）
    return media.fileUrl === '' && media.downloadUrl !== ''
      ? $r('app.string.episode_stream')
      : $r('app.string.episode_play');
  }

  secondaryIcon(): Resource {
    const media: FeedMedia | undefined = this.media();
    if (media === undefined) {
      return $r('sys.symbol.share');
    }
    const state: string = this.downloadState(media);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return $r('sys.symbol.xmark_circle');
    }
    return media.fileUrl !== '' ? $r('sys.symbol.trash') : $r('sys.symbol.arrow_down_circle');
  }

  secondaryLabel(): ResourceStr {
    const media: FeedMedia | undefined = this.media();
    if (media === undefined) {
      return $r('app.string.episode_share');
    }
    const state: string = this.downloadState(media);
    if (state === 'RUNNING' || state === 'PAUSED') {
      return $r('app.string.episode_download_cancel');
    }
    return media.fileUrl !== '' ? $r('app.string.episode_delete_download') : $r('app.string.episode_download');
  }

  private itemImage(): string {
    if (this.item === undefined) {
      return '';
    }
    return this.item.imageUrl !== '' ? this.item.imageUrl : this.feedImage();
  }

  private itemTitle(): string {
    return this.item === undefined ? '' : this.item.title;
  }

  private feedImage(): string {
    return this.feed === undefined ? '' : this.feed.imageUrl;
  }

  private feedTitle(): string {
    return this.feed === undefined ? '' : this.feed.getTitle();
  }

  private durationText(): string {
    const media: FeedMedia | undefined = this.media();
    return media === undefined ? '' : DurationUtils.format(media.duration);
  }

  private pubDateText(): string {
    const pubDate: number = this.item === undefined ? 0 : this.item.pubDate;
    return pubDate > 0 ? new Date(pubDate).toLocaleDateString() : '';
  }

  private showMessage(text: string): void {
    this.message = text;
    if (this.messageTimerId >= 0) {
      clearTimeout(this.messageTimerId);
    }
    this.messageTimerId = setTimeout(() => {
      this.message = '';
      this.messageTimerId = -1;
    }, 4000);
  }

  /** 时间码判定的时长口径：无媒体时按「未知」处理（上游传 `Integer.MAX_VALUE`） */
  private static durationOf(item: FeedItem): number {
    return item.media === undefined ? 0 : item.media.duration;
  }
}
