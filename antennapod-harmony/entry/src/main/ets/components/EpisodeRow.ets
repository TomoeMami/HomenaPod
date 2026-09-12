import { DesignTokens } from '../common/DesignTokens';
import { FeedCover } from './FeedCover';

/**
 * 剧集列表行（对齐上游 `feeditemlist_item.xml`）：
 * 可选拖拽手柄 + 56vp 封面 + 状态图标行（收件箱/视频/收藏/已在队列）+ 两行标题 +
 * 进度行（已播位置 · 进度条 · 时长）+ 右侧 48vp 次级操作。
 * 已播状态用整行 0.5 透明度表示（上游做法），选中态用 `primary_container` 底色。
 */
@Component
export struct EpisodeRow {
  @Prop title: string = '';
  /** 副标题（订阅名），仅全库列表（Episodes 总表）使用，为空则不显示 */
  @Prop subtitle: string = '';
  @Prop imageUrl: string = '';
  /**
   * 无封面时画在封面位置上的文字（上游 `feeditemlist_item.xml` 的 `txtvPlaceholder`，
   * 内容是订阅名，最多 3 行）。为空则退回品牌色底 + 音符图标。
   */
  @Prop coverFallbackTitle: string = '';
  /** 状态行文本，形如 `2026-09-01 · 12 MB`，为空则不显示状态行 */
  @Prop metaText: string = '';
  @Prop positionText: string = '';
  @Prop durationText: string = '';
  @Prop progress: number = 0;
  /**
   * 当前播放项（上游 `PlaybackStatus.isPlaying(media)`，与播放/暂停状态无关）。
   * 上游 `EpisodeItemViewHolder`：`isPlaying(media) || item.isInProgress()` 时
   * 进度行显示位置文本与进度条——位置为 0 的当前播放项也要显示进度条轨道。
   */
  @Prop playing: boolean = false;
  @Prop isPlayed: boolean = false;
  /**
   * 是否在收件箱（上游 `FeedItem.isNew()`，read = -1）。
   * 上游 `EpisodeItemViewHolder.bind` 是 `isInbox.setVisibility(item.isNew() ? VISIBLE : GONE)`
   * ——「未播放」不等于「在收件箱」，用 isPlayed 反推会把下载段里没听过的单集也画上收件箱图标。
   */
  @Prop isNew: boolean = false;
  @Prop isFavorite: boolean = false;
  @Prop inQueue: boolean = false;
  @Prop isVideo: boolean = false;
  @Prop showDragHandle: boolean = false;
  @Prop selected: boolean = false;
  @Prop actionIcon: Resource = $r('sys.symbol.play_fill');
  @Prop actionTint: ResourceColor = $r('app.color.primary');
  @Prop showAction: boolean = true;
  /**
   * 下载进度百分比（0–100）；-1 表示当前没有下载任务，不显示进度环。
   * 对照上游 `feeditemlist_item.xml` 的 `secondaryActionProgress`
   * （`CircularProgressBar`，40dp，套在 48dp 次级操作按钮的 24dp 图标外圈）：
   * 上游 `EpisodeItemViewHolder.bind(FeedMedia)` 在 `isDownloadingEpisode(url)` 时
   * 用下载进度画弧，已下载时画满、未下载时清零。
   */
  @Prop downloadProgress: number = -1;
  /** 总大小未知（进度不可确定）时的等待态：环做旋转动画，对照上游 CircularProgressBar 的虚线环 */
  @Prop downloadIndeterminate: boolean = false;
  /**
   * 手柄拖拽期间本行隐藏：真实视觉由调用方的拖拽浮层承担（浮层跟手，
   * 本行仍留在列表里占住「将要落位」的槽位并负责接收手势）。
   */
  @State handleDragging: boolean = false;
  /**
   * 刚触发过长按：紧随其后的 onClick 要忽略。
   * `parallelGesture(LongPressGesture())` 与 `onClick` 同节点绑定时，同一次「按下—长按—抬起」
   * 会先触发长按、再在抬起时触发 click，表现为「长按进多选后那一项又被取消选中」
   * （实测队列页与单集总表都出现「已选：0」）；每次按下时复位，避免吞掉下一次正常点击。
   */
  private longPressHandled: boolean = false;
  onTap: () => void = () => {
  };
  onAction: () => void = () => {
  };
  onLongPress: () => void = () => {
  };
  /** 左侧三横线（拖拽手柄）的竖直拖动回调，由调用方实现排序（队列页）；返回 false 表示不接管 */
  onHandleDragStart: () => boolean = () => false;
  /** offsetY 是手势开始以来的累计位移（vp） */
  onHandleDragMove: (offsetY: number) => void = () => {
  };
  onHandleDragEnd: (offsetY: number) => void = () => {
  };
  /**
   * 行实测高度（vp）：队列拖拽的换位阈值与位移都要按真实行高计算。
   * 行高随标题行数变化（1 行 / 2 行），用固定节距会在行高不一致时让被拖行漂移。
   */
  onHeightChange: (height: number) => void = () => {
  };

  /** 状态行里是否有任一状态图标（上游 `hideSeparatorIfNecessary` 的判断依据） */
  hasStatusIcons(): boolean {
    return this.isNew || this.isVideo || this.isFavorite || this.inQueue;
  }

  build() {
    Row() {
      if (this.showDragHandle) {
        // 手柄包一层 Row：SymbolGlyph 自身不易命中，用 Row 提供 20×56vp 的稳定热区
        Row() {
          SymbolGlyph($r('sys.symbol.line_3_horizontal'))
            .fontSize(DesignTokens.ICON_S)
            .fontColor([$r('app.color.text_tertiary')])
        }
        .width(20)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .margin({ right: DesignTokens.SPACE_XS })
        // 按住三横线直接上下拖动排序：用 PanGesture 而非长按——
        // 长按已被整行的多选占用，原生 List 长按拖拽会与它冲突
        .gesture(
          PanGesture({ direction: PanDirection.Vertical, distance: 1 })
            .onActionStart(() => {
              // 调用方可能拒绝（锁定 / 多选态），拒绝时本行不能进入隐藏态
              this.handleDragging = this.onHandleDragStart();
            })
            .onActionUpdate((event: GestureEvent) => {
              this.onHandleDragMove(event.offsetY);
            })
            .onActionEnd((event: GestureEvent) => {
              this.handleDragging = false;
              this.onHandleDragEnd(event.offsetY);
            })
            .onActionCancel(() => {
              this.handleDragging = false;
              this.onHandleDragEnd(0);
            })
        )
      }

      // 封面左半区也可起拖（上游 QueueRecyclerAdapter：封面左半边按下 = 开始拖拽，
      // 右半边不接管，避免与点击/其它手势打架）；拖拽仅在队列页启用（showDragHandle）
      Row() {
        FeedCover({
          imageUrl: this.imageUrl,
          coverSize: DesignTokens.COVER_LIST,
          radius: 8,
          fallbackTitle: this.coverFallbackTitle,
          placeholderColor: $r('app.color.cover_placeholder')
        })
      }
      .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M, right: DesignTokens.SPACE_L })
      .gesture(
        PanGesture({ direction: PanDirection.Vertical, distance: 5 })
          .onActionStart((event: GestureEvent) => {
            if (!this.showDragHandle) {
              return;
            }
            // 触点落在封面右半区时不接管拖拽
            if (event.fingerList.length > 0
              && event.fingerList[0].localX > DesignTokens.COVER_LIST / 2) {
              return;
            }
            this.handleDragging = this.onHandleDragStart();
          })
          .onActionUpdate((event: GestureEvent) => {
            if (!this.handleDragging) {
              return;
            }
            this.onHandleDragMove(event.offsetY);
          })
          .onActionEnd((event: GestureEvent) => {
            if (!this.handleDragging) {
              return;
            }
            this.handleDragging = false;
            this.onHandleDragEnd(event.offsetY);
          })
          .onActionCancel(() => {
            if (!this.handleDragging) {
              return;
            }
            this.handleDragging = false;
            this.onHandleDragEnd(0);
          })
      )

      Column({ space: 2 }) {
        if (this.metaText !== '' || this.isNew || this.isPlayed || this.isFavorite || this.inQueue
          || this.isVideo) {
          Row({ space: DesignTokens.SPACE_XS }) {
            if (this.isNew) {
              SymbolGlyph($r('sys.symbol.inbox'))
                .fontSize(DesignTokens.FONT_FOOTNOTE)
                .fontColor([$r('app.color.text_secondary')])
            }
            if (this.isVideo) {
              SymbolGlyph($r('sys.symbol.video'))
                .fontSize(DesignTokens.FONT_FOOTNOTE)
                .fontColor([$r('app.color.text_secondary')])
            }
            if (this.isFavorite) {
              SymbolGlyph($r('sys.symbol.star_fill'))
                .fontSize(DesignTokens.FONT_FOOTNOTE)
                .fontColor([$r('app.color.text_secondary')])
            }
            if (this.inQueue) {
              SymbolGlyph($r('sys.symbol.music_note_list'))
                .fontSize(DesignTokens.FONT_FOOTNOTE)
                .fontColor([$r('app.color.text_secondary')])
            }
            // 图标与日期之间的分隔点（上游 separatorIcons）：没有图标时不显示
            if (this.hasStatusIcons() && this.metaText !== '') {
              Text('·')
                .fontSize(DesignTokens.FONT_CAPTION)
                .fontColor($r('app.color.text_secondary'))
            }
            if (this.metaText !== '') {
              Text(this.metaText)
                .fontSize(DesignTokens.FONT_CAPTION)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
          }
          .width('100%')
        }

        Text(this.title)
          .width('100%')
          .fontSize(DesignTokens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle !== '') {
          Text(this.subtitle)
            .width('100%')
            .fontSize(DesignTokens.FONT_CAPTION)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        if (this.positionText !== '' || this.durationText !== '' || this.progress > 0) {
          Row({ space: DesignTokens.SPACE_XS }) {
            Text(this.positionText)
              .fontSize(DesignTokens.FONT_CAPTION)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)

            if (this.progress > 0 || this.playing) {
              Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
                .layoutWeight(1)
                .height(4)
                .color($r('app.color.primary'))
                .backgroundColor($r('app.color.scrubber_track'))
            } else {
              Blank().layoutWeight(1)
            }

            Text(this.durationText)
              .fontSize(DesignTokens.FONT_CAPTION)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
          }
          .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ top: DesignTokens.SPACE_M, bottom: DesignTokens.SPACE_M, right: DesignTokens.SPACE_S })

      if (this.showAction) {
        Stack() {
          // 下载进度环：套在操作图标外圈（上游 secondary_action.xml 的 secondaryActionProgress）
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
          SymbolGlyph(this.actionIcon)
            .fontSize(DesignTokens.ICON_XL)
            .fontColor([this.actionTint])
        }
        .width(48)
        .height(48)
        .alignContent(Alignment.Center)
        .margin({ right: DesignTokens.SPACE_M })
        .onClick(() => {
          this.onAction();
        })
      }
    }
    .width('100%')
    .padding({ left: DesignTokens.SPACE_M })
    // 选中态（多选）与播放中态都来自上游的 colorSecondaryContainer 圆角底：
    // 选中 = itemView.setSelected(true)，播放中 = setActivated(PlaybackStatus.isCurrentlyPlaying)
    .backgroundColor(this.selected
      ? $r('app.color.primary_container')
      : (this.playing ? $r('app.color.surface_container_playing') : $r('app.color.surface')))
    .borderRadius(DesignTokens.RADIUS_ROW)
    // 拖拽中本行隐藏（视觉由调用方浮层承担），否则按已播状态半透明
    .opacity(this.handleDragging ? 0 : (this.isPlayed ? 0.5 : 1))
    .alignItems(VerticalAlign.Center)
    .zIndex(this.handleDragging ? 2 : 0)
    // 上报实测高度，供队列拖拽计算槽位偏移（浮层定位与换位阈值都按真实行高算）
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const height: Length = newArea.height;
      if (typeof height === 'number' && height > 0) {
        this.onHeightChange(height);
      }
    })
    .onClick(() => {
      if (this.longPressHandled) {
        this.longPressHandled = false;
        return;
      }
      this.onTap();
    })
    // 每次按下先复位长按标记：长按抬起后若没有再产生 click，也不会吞掉下一次点击
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.longPressHandled = false;
      }
    })
    // 必须用 parallelGesture：与 onClick 同节点绑定时，普通 tap 会被手势竞争吞掉
    .parallelGesture(LongPressGesture().onAction(() => {
      this.longPressHandled = true;
      this.onLongPress();
    }))
  }
}
