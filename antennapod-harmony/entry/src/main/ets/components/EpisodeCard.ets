import { DesignTokens } from '../common/DesignTokens';
import { FeedCover } from './FeedCover';

/**
 * 首页横滑卡片（对齐上游 `horizontal_itemlist_item.xml`）：
 * 128vp 方形封面 + 右下角 48vp 播放圆钮 + 封面底部 4vp 进度条 + 两行标题 + 日期。
 * 卡片 128vp 宽、圆角 12vp、底色 `surface_container`（播放中为 `surface_container_playing`），四周 4vp 外边距。
 */
@Component
export struct EpisodeCard {
  @Prop title: string = '';
  @Prop dateText: string = '';
  @Prop imageUrl: string = '';
  @Prop progress: number = 0;
  @Prop playing: boolean = false;
  @Prop actionIcon: Resource = $r('sys.symbol.play_fill');
  /**
   * 下载进度百分比（0–100）；-1 表示当前没有下载任务，不画进度环。
   * 对照上游 `horizontal_itemlist_item.xml` 的 `circularProgressBar`
   * （48dp、`foregroundColor=?attr/colorOnPrimary`，叠在 48dp 播放圆钮上）：
   * `HorizontalItemViewHolder.bind` 在下载中画进度、已下载画满、未下载清零。
   */
  @Prop downloadProgress: number = -1;
  /** 总大小未知（服务端没给 Content-Length）时的等待态：环走旋转动画 */
  @Prop downloadIndeterminate: boolean = false;
  onTap: () => void = () => {
  };
  onAction: () => void = () => {
  };
  /** 长按打开单集操作菜单（上游 HorizontalItemListAdapter 也注册了上下文菜单） */
  onLongPress: () => void = () => {
  };

  build() {
    Column() {
      // 封面 + 播放钮 + 进度条（上游把进度条放在封面卡片内部底边）
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          FeedCover({
            imageUrl: this.imageUrl,
            coverSize: DesignTokens.COVER_HOME_CARD,
            radius: 0,
            fallbackTitle: this.title,
            placeholderColor: $r('app.color.cover_placeholder')
          })

          Stack() {
            SymbolGlyph(this.actionIcon)
              .fontSize(DesignTokens.ICON_XL)
              .fontColor([$r('app.color.on_primary')])
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor($r('app.color.primary'))
          .alignContent(Alignment.Center)
          .margin(DesignTokens.SPACE_XS)
          .onClick(() => {
            this.onAction();
          })

          // 下载进度环：与播放圆钮同尺寸同位置，画在圆钮边缘（上游 circularProgressBar）
          if (this.downloadProgress >= 0) {
            Progress({ value: this.downloadProgress, total: 100, type: ProgressType.Ring })
              .width(48)
              .height(48)
              .color($r('app.color.on_primary'))
              .backgroundColor($r('app.color.primary'))
              .style({
                strokeWidth: 3,
                status: this.downloadIndeterminate ? ProgressStatus.LOADING : ProgressStatus.PROGRESSING,
                enableSmoothEffect: !this.downloadIndeterminate
              })
              .margin(DesignTokens.SPACE_XS)
          }
        }
        .width(DesignTokens.COVER_HOME_CARD)
        .height(DesignTokens.COVER_HOME_CARD)

        if (this.progress > 0) {
          Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
            .width(DesignTokens.COVER_HOME_CARD)
            .height(4)
            .color($r('app.color.primary'))
            .backgroundColor($r('app.color.scrubber_track'))
        } else {
          // 无进度时保留 4vp 占位，保证卡片等高（上游 progressBarReplacementSpacer）
          Row()
            .width(DesignTokens.COVER_HOME_CARD)
            .height(4)
        }
      }
      .borderRadius(DesignTokens.RADIUS_ROW)
      .clip(true)

      Text(this.title)
        .width('100%')
        .fontSize(DesignTokens.FONT_SUBTITLE)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: DesignTokens.SPACE_XS, right: DesignTokens.SPACE_XS })
        .margin({ top: DesignTokens.SPACE_XS })

      Text(this.dateText)
        .width('100%')
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: DesignTokens.SPACE_XS, right: DesignTokens.SPACE_XS })
        .margin({ bottom: DesignTokens.SPACE_XS })
    }
    .width(DesignTokens.COVER_HOME_CARD)
    .backgroundColor(this.playing ? $r('app.color.surface_container_playing') : $r('app.color.surface_container'))
    .borderRadius(DesignTokens.RADIUS_ROW)
    .margin(DesignTokens.SPACE_XS)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onTap();
    })
    // 与 EpisodeRow 一致：必须用 parallelGesture，否则普通 tap 会被手势竞争吞掉
    .parallelGesture(LongPressGesture().onAction(() => {
      this.onLongPress();
    }))
  }
}
