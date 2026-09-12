import router from '@ohos.router';
import { DesignTokens } from '../common/DesignTokens';
import { FeedCover } from './FeedCover';

/**
 * 迷你播放条（对齐上游 external_player_fragment.xml）：
 * 整行高 64vp（`external_player_height`），封面 + 标题/订阅名（各 16fp 单行）+ 52vp 播放键，
 * 底部 4vp 进度条贯穿整行；底色 `surface_container`。
 */
@Component
export struct MiniPlayer {
  @Prop title: string = '';
  @Prop feedTitle: string = '';
  /** 当前播放单集封面（单集封面 / 播客封面，来自 Playable.imageUrl） */
  @Prop imageUrl: string = '';
  @Prop playing: boolean = false;
  @Prop show: boolean = false;
  @Prop progress: number = 0;
  onToggle: () => void = () => {
  };

  build() {
    if (this.show) {
      Column() {
        Row({ space: DesignTokens.SPACE_L }) {
          FeedCover({
            imageUrl: this.imageUrl,
            coverSize: DesignTokens.COVER_LIST,
            radius: DesignTokens.RADIUS_ROW,
            placeholderColor: $r('app.color.cover_placeholder')
          })

          Column({ space: 2 }) {
            Text(this.title)
              .fontSize(DesignTokens.FONT_BODY)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.feedTitle)
              .fontSize(DesignTokens.FONT_BODY)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Stack() {
            SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(DesignTokens.ICON_XXL)
              .fontColor([$r('app.color.primary')])
          }
          .width(52)
          .height('100%')
          .alignContent(Alignment.Center)
          .onClick(() => {
            this.onToggle();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_S })
        .alignItems(VerticalAlign.Center)

        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color($r('app.color.primary'))
          .backgroundColor($r('app.color.scrubber_track'))
      }
      .width('100%')
      .height(64)
      .backgroundColor($r('app.color.surface_container'))
      .onClick(() => {
        router.pushUrl({ url: 'pages/PlayerPage' });
      })
    }
  }
}
