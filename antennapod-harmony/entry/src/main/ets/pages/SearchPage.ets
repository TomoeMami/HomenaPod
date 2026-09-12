import router from '@ohos.router';
import { Discovery, PodcastSearchResult } from '../net/Discovery';
import { SubscriptionService } from '../services/SubscriptionService';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { Feed } from '../model/Feed';
import { FeedItem } from '../model/FeedItem';
import { FeedMedia } from '../model/FeedMedia';
import { MediaType } from '../model/Enums';
import { Playable } from '../model/Playable';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { DurationUtils } from '../utils/DurationUtils';
import { LazyDataSource } from '../components/LazyDataSource';
import { FeedCover } from '../components/FeedCover';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { EpisodeRow } from '../components/EpisodeRow';

interface SearchParams {
  term: string;
  /** true = 队列内搜索（上游 QueueFragment 的搜索动作传 FeedItemFilter(QUEUED)） */
  queuedOnly?: boolean;
}

/** 本地剧集搜索结果上限（对齐上游列表按发布时间倒序的展示方式） */
const MAX_EPISODE_RESULTS: number = 50;

/**
 * Search（对齐上游 `search_fragment.xml` + SearchFragment）：
 * 56vp 标题栏 + 1 个搜索动作；加载中居中进度圈；结果区为两组堆叠列表
 * （先 Feed 结果：左右 12vp 内边距、56vp 封面 + 标题 + 作者；后剧集结果：共享 EpisodeRow）。
 */
@Entry
@Component
struct SearchPage {
  private dataSource: LazyDataSource<PodcastSearchResult> = new LazyDataSource<PodcastSearchResult>();
  @State term: string = '';
  @State results: PodcastSearchResult[] = [];
  @State episodes: FeedItem[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State searched: boolean = false;
  /** 队列内搜索：不查在线播客目录，只在队列里找单集 */
  @State queuedOnly: boolean = false;
  /** 防止行点击与行内按钮同时触发导致重复订阅 */
  private subscribing: boolean = false;
  private feedTitles: Map<number, string> = new Map<number, string>();
  private feedImages: Map<number, string> = new Map<number, string>();

  build() {
    Column() {
      AppBar({ title: this.queuedOnly ? $r('app.string.search_in_queue') : $r('app.string.discover_search'), showBack: true }) {
        AppIconButton({
          symbol: $r('sys.symbol.magnifyingglass'),
          onTap: () => {
            this.search();
          }
        })
      }

      Row() {
        TextInput({ placeholder: this.queuedOnly ? $r('app.string.search_in_queue_hint') : $r('app.string.discover_hint'), text: this.term })
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.surface_secondary'))
          .onChange((value: string) => {
            this.term = value;
          })
          .onSubmit(() => {
            this.search();
          })
      }
      .width('100%')
      .padding({
        left: DesignTokens.PAGE_MARGIN,
        right: DesignTokens.PAGE_MARGIN,
        top: DesignTokens.SPACE_S,
        bottom: DesignTokens.SPACE_S
      })

      if (this.message !== '') {
        Text(this.message)
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.error'))
          .width('100%')
          .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
      }

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('app.color.primary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.results.length === 0 && this.episodes.length === 0) {
        // 空状态（对齐 empty_view_layout.xml）：图标 32vp + 标题 16sp，左右 40vp 内边距
        Column({ space: DesignTokens.SPACE_M }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(32)
            .fontColor([$r('app.color.text_tertiary')])
          Text(this.searched ? $r('app.string.discover_empty') : $r('app.string.type_to_search'))
            .fontSize(DesignTokens.FONT_SECTION)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 40, right: 40 })
      } else {
        List({ space: DesignTokens.SPACE_XS }) {
          // Feed 结果（上游 recyclerViewFeeds：左右各 12dp 内边距）
          LazyForEach(this.dataSource, (item: PodcastSearchResult, index: number) => {
            ListItem() {
              Row({ space: DesignTokens.SPACE_L }) {
                FeedCover({ imageUrl: item.imageUrl, coverSize: 56 })
                Column({ space: DesignTokens.SPACE_XS }) {
                  Text(item.title)
                    .fontSize(DesignTokens.FONT_BODY)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.author)
                    .fontSize(DesignTokens.FONT_PARAGRAPH)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button($r('app.string.discover_subscribe'))
                  .height(DesignTokens.HEIGHT_BUTTON_SM)
                  .fontSize(DesignTokens.FONT_CAPTION)
                  .backgroundColor($r('app.color.primary_container'))
                  .fontColor($r('app.color.primary'))
                  .onClick(() => {
                    this.subscribe(item.feedUrl);
                  })
              }
              .width('100%')
              .padding({ top: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_S })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.subscribe(item.feedUrl);
              })
            }
            .width('100%')
            .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
          }, (item: PodcastSearchResult, index: number) => item.feedUrl + '-' + index)

          // 剧集结果（共享 EpisodeRow：56vp 封面 + 状态行 + 标题 + 进度行 + 48vp 操作）
          ForEach(this.episodes, (item: FeedItem) => {
            ListItem() {
              EpisodeRow({
                title: item.title,
                imageUrl: item.imageUrl !== '' ? item.imageUrl : this.feedImage(item.feedId),
                metaText: this.metaText(item),
                positionText: this.positionText(item),
                durationText: this.durationText(item),
                progress: this.progress(item),
                isPlayed: item.isPlayed,
                isNew: item.isNew(),
                isFavorite: false,
                inQueue: false,
                isVideo: this.isVideo(item),
                actionIcon: $r('sys.symbol.play_fill'),
                onTap: () => {
                  this.play(item);
                },
                onAction: () => {
                  this.play(item);
                }
              })
            }
          }, (item: FeedItem) => item.id.toString())
        }
        .layoutWeight(1)
        .padding({ top: DesignTokens.SPACE_M })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  aboutToAppear(): void {
    const params = router.getParams() as SearchParams;
    if (params !== undefined && params.queuedOnly === true) {
      this.queuedOnly = true;
    }
    if (params !== undefined && params.term !== undefined) {
      this.term = params.term;
      this.search();
    }
  }

  async search(): Promise<void> {
    const query: string = this.term.trim();
    if (query === '') {
      return;
    }
    this.loading = true;
    this.message = '';
    this.searched = true;
    if (!this.queuedOnly) {
      try {
        const results: PodcastSearchResult[] = await Discovery.searchPodcasts(query);
        this.results = results;
        this.dataSource.setData(results);
      } catch (error) {
        this.results = [];
        this.dataSource.setData([]);
        this.message = getContext(this).resourceManager.getStringSync($r('app.string.search_failed')) + (error as Error).message;
      }
    } else {
      this.results = [];
      this.dataSource.setData([]);
    }
    try {
      await this.searchEpisodes(query);
    } catch (error) {
      this.episodes = [];
    }
    this.loading = false;
  }

  /**
   * 本地剧集搜索：遍历已订阅 Feed（复用 EpisodeRepository.searchByFeed），按发布时间倒序。
   * 队列内搜索（上游 FeedItemFilter(QUEUED)）只保留队列里命中的单集，且不查在线目录。
   */
  async searchEpisodes(query: string): Promise<void> {
    if (this.queuedOnly) {
      await this.searchQueue(query);
      return;
    }
    const feeds: Feed[] = await FeedRepository.listSubscribed();
    const titles: Map<number, string> = new Map<number, string>();
    const images: Map<number, string> = new Map<number, string>();
    for (const feed of feeds) {
      titles.set(feed.id, feed.getTitle());
      images.set(feed.id, feed.imageUrl);
    }
    this.feedTitles = titles;
    this.feedImages = images;

    const merged: FeedItem[] = [];
    for (const feed of feeds) {
      const items: FeedItem[] = await EpisodeRepository.searchByFeed(feed.id, query);
      for (const item of items) {
        merged.push(item);
      }
      if (merged.length >= MAX_EPISODE_RESULTS) {
        break;
      }
    }
    merged.sort((a: FeedItem, b: FeedItem) => b.pubDate - a.pubDate);
    this.episodes = merged.slice(0, MAX_EPISODE_RESULTS);
  }

  /** 队列内搜索：只在当前队列里按标题匹配（上游 FeedItemFilter(QUEUED) + 关键词） */
  async searchQueue(query: string): Promise<void> {
    await QueueEngine.load();
    const queued: FeedItem[] = QueueEngine.getItems();
    const titles: Map<number, string> = new Map<number, string>();
    const images: Map<number, string> = new Map<number, string>();
    const feeds: Feed[] = await FeedRepository.listByIds(queued.map((item: FeedItem) => item.feedId));
    for (const feed of feeds) {
      titles.set(feed.id, feed.getTitle());
      images.set(feed.id, feed.imageUrl);
    }
    this.feedTitles = titles;
    this.feedImages = images;

    const keyword: string = query.toLowerCase();
    const matched: FeedItem[] = [];
    for (const item of queued) {
      const feedTitle: string | undefined = titles.get(item.feedId);
      const haystack: string = (item.title + ' ' + (feedTitle === undefined ? '' : feedTitle)).toLowerCase();
      if (haystack.includes(keyword)) {
        matched.push(item);
      }
      if (matched.length >= MAX_EPISODE_RESULTS) {
        break;
      }
    }
    this.episodes = matched;
  }

  async subscribe(feedUrl: string): Promise<void> {
    if (feedUrl === '' || this.subscribing) {
      return;
    }
    this.subscribing = true;
    try {
      await SubscriptionService.subscribe(feedUrl);
      router.back();
    } catch (error) {
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.subscribe_failed')) + (error as Error).message;
    } finally {
      this.subscribing = false;
    }
  }

  feedImage(feedId: number): string {
    return this.feedImages.get(feedId) ?? '';
  }

  isVideo(item: FeedItem): boolean {
    const media: FeedMedia | undefined = item.media;
    return media !== undefined && media.getMediaType() === MediaType.VIDEO;
  }

  positionText(item: FeedItem): string {
    if (item.media === undefined || item.media.position <= 0) {
      return '';
    }
    return DurationUtils.format(item.media.position);
  }

  durationText(item: FeedItem): string {
    if (item.media === undefined || item.media.duration <= 0) {
      return '';
    }
    return DurationUtils.format(item.media.duration);
  }

  progress(item: FeedItem): number {
    if (item.media === undefined || item.media.duration <= 0 || item.media.position <= 0) {
      return 0;
    }
    const percent: number = Math.floor(item.media.position * 100 / item.media.duration);
    return percent > 100 ? 100 : (percent < 5 ? 5 : percent);
  }

  metaText(item: FeedItem): string {
    const title: string | undefined = this.feedTitles.get(item.feedId);
    const parts: string[] = [];
    if (title !== undefined) {
      parts.push(title);
    }
    if (item.pubDate > 0) {
      parts.push(new Date(item.pubDate).toLocaleDateString());
    }
    return parts.join(' · ');
  }

  async play(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    try {
      const playable: Playable | undefined = await QueueEngine.toPlayable(item);
      if (playable === undefined) {
        return;
      }
      await QueueEngine.ensureQueued(item);
      await PlayerManager.load(playable, item.media.position, true);
      router.pushUrl({ url: 'pages/PlayerPage' });
    } catch (error) {
      this.message = (error as Error).message;
    }
  }
}
