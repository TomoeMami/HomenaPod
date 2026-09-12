import router from '@ohos.router';
import { FeedItem } from '../model/FeedItem';
import { MediaType } from '../model/Enums';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { QueueEngine } from '../player/QueueEngine';
import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { LazyDataSource } from '../components/LazyDataSource';
import { DurationUtils } from '../utils/DurationUtils';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { EpisodeRow } from '../components/EpisodeRow';
import { EmptyState } from '../components/EmptyState';

/**
 * 收藏页（对齐上游 `episodes_list_fragment.xml` + `FavoritesFragment`）：
 * 56vp 标题栏（返回箭头 + 搜索动作），下方为共享 `EpisodeRow` 剧集列表
 * （上游 `feeditemlist_item.xml`：56vp 封面 + 状态行（含收藏星标）+ 两行标题 + 位置/时长进度行），
 * 右侧次级操作沿用原页面的「取消收藏」星标按钮。
 */
@Entry
@Component
struct FavoritesPage {
  private dataSource: LazyDataSource<FeedItem> = new LazyDataSource<FeedItem>();
  @State items: FeedItem[] = [];
  @State loading: boolean = false;
  @State message: string = '';

  build() {
    Column() {
      AppBar({ title: $r('app.string.favorites_title'), showBack: true }) {
        AppIconButton({
          symbol: $r('sys.symbol.magnifyingglass'),
          onTap: () => {
            router.pushUrl({ url: 'pages/SearchPage', params: { term: '' } });
          }
        })
      }

      if (this.message !== '') {
        Text(this.message)
          .fontSize(DesignTokens.FONT_FOOTNOTE)
          .fontColor($r('app.color.primary'))
          .width('100%')
          .padding({ left: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_S })
      }

      if (this.loading) {
        Text($r('app.string.loading'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
      } else if (this.items.length === 0) {
        Column() {
          EmptyState({
            icon: $r('sys.symbol.star'),
            title: $r('app.string.favorites_empty'),
            sub: $r('app.string.favorites_empty_hint')
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: DesignTokens.SPACE_XS }) {
          LazyForEach(this.dataSource, (item: FeedItem) => {
            ListItem() {
              this.favoriteRow(item)
            }
          }, (item: FeedItem) => item.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_M })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  favoriteRow(item: FeedItem) {
    EpisodeRow({
      title: item.title,
      imageUrl: item.imageUrl,
      metaText: this.metaText(item),
      positionText: this.positionText(item),
      durationText: this.durationText(item),
      progress: this.progress(item),
      isPlayed: item.isPlayed,
      isNew: item.isNew(),
      isFavorite: true,
      isVideo: item.media !== undefined && item.media.getMediaType() === MediaType.VIDEO,
      actionIcon: $r('sys.symbol.star_fill'),
      actionTint: $r('app.color.star'),
      onTap: () => {
        this.play(item);
      },
      onAction: () => {
        this.remove(item);
      }
    })
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const items: FeedItem[] = await FavoritesRepository.list();
      this.items = items;
      this.dataSource.setData(items);
    } catch (error) {
      this.items = [];
      this.dataSource.setData([]);
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  async remove(item: FeedItem): Promise<void> {
    try {
      await FavoritesRepository.remove(item.id);
      await this.load();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  async play(item: FeedItem): Promise<void> {
    if (item.media === undefined) {
      return;
    }
    const playable: Playable = new Playable(
      item.media.id,
      item.id,
      item.title,
      'Favorites',
      item.media.downloadUrl,
      item.media.fileUrl,
      item.media.duration,
      item.media.position,
      item.media.getMediaType(),
      1.0,
      0,
      0,
      0,
      item.imageUrl
    );
    await QueueEngine.ensureQueued(item);
    await PlayerManager.load(playable, item.media.position, true);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  /** 状态行：发布日期 · 文件大小（上游 feeditemlist_item.xml 的 txtvPubDate + size） */
  metaText(item: FeedItem): string {
    const parts: string[] = [];
    if (item.pubDate > 0) {
      parts.push(new Date(item.pubDate).toLocaleDateString());
    }
    if (item.media !== undefined && item.media.size > 0) {
      const mb: number = item.media.size / (1024 * 1024);
      parts.push(mb < 1 ? (item.media.size / 1024).toFixed(0) + ' KB' : mb.toFixed(1) + ' MB');
    }
    return parts.join(' · ');
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
}
