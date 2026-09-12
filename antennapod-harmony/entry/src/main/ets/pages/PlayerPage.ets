import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';
import display from '@ohos.display';
import { PlayerManager } from '../player/PlayerManager';
import { ProgressPersister } from '../player/ProgressPersister';
import { Playable } from '../model/Playable';
import { SleepTimer } from '../player/SleepTimer';
import { ShakeDetector } from '../player/ShakeDetector';
import { ChapterRepository } from '../db/repositories/ChapterRepository';
import { Chapter } from '../model/Chapter';
import { QueueEngine } from '../player/QueueEngine';
import { FeedItem } from '../model/FeedItem';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { UserPreferences } from '../prefs/UserPreferences';
import { EventHub, EventType, SleepTimerData } from '../events/EventHub';
import { DurationUtils } from '../utils/DurationUtils';
import { DesignTokens } from '../common/DesignTokens';
import { FeedCover } from '../components/FeedCover';

/**
 * 播放页（对齐上游 audioplayer_fragment.xml + cover_fragment.xml）：
 * 顶部下箭头工具栏（收藏 / 睡眠定时 / 分享）→ 方形封面 → 订阅名 + 单集标题 →
 * 「节目详情 / 章节」描边按钮 → 进度条（左右时间）→ 五个控件的播放控制行（倍速·快退·播放·快进·下一集）。
 */
@Entry
@Component
struct PlayerPage {
  @State title: string = '';
  @State feedTitle: string = '';
  @State description: string = '';
  @State status: string = 'IDLE';
  @State playPosition: number = 0;
  @State duration: number = 0;
  @State chapters: Chapter[] = [];
  @State sleepRemainingText: string = '';
  @State speed: number = 1.0;
  @State repeatMode: number = 0;
  @State showSleepSheet: boolean = false;
  @State showChaptersSheet: boolean = false;
  @State showNotesSheet: boolean = false;
  @State customMinutes: string = '';
  @State chapterEndToggle: boolean = false;
  @State fadeToggle: boolean = false;
  @State favorite: boolean = false;
  @State coverSize: number = 240;
  /** 封面地址（单集封面 / 播客封面，来自当前播放对象） */
  @State coverUrl: string = '';
  @State message: string = '';
  private timerId: number = -1;
  private sleepToken: number = -1;
  private feedItemId: number = 0;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 顶部工具栏（上游 navigationIcon = ic_arrow_down）
        Row({ space: DesignTokens.SPACE_XS }) {
          Stack() {
            SymbolGlyph($r('sys.symbol.arrow_down'))
              .fontSize(DesignTokens.ICON_XL)
              .fontColor([$r('app.color.text_primary')])
          }
          .width(DesignTokens.HIT_MIN)
          .height(DesignTokens.HIT_MIN)
          .alignContent(Alignment.Center)
          .onClick(() => {
            ProgressPersister.save(true);
            router.back();
          })

          Blank()

          Stack() {
            SymbolGlyph(this.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
              .fontSize(DesignTokens.ICON_L)
              .fontColor([this.favorite ? $r('app.color.star') : $r('app.color.text_secondary')])
          }
          .width(DesignTokens.HIT_MIN)
          .height(DesignTokens.HIT_MIN)
          .alignContent(Alignment.Center)
          .onClick(() => {
            this.toggleFavorite();
          })

          Stack() {
            SymbolGlyph(SleepTimer.isActive() ? $r('sys.symbol.moon_fill') : $r('sys.symbol.moon'))
              .fontSize(DesignTokens.ICON_L)
              .fontColor([SleepTimer.isActive() ? $r('app.color.primary') : $r('app.color.text_secondary')])
          }
          .width(DesignTokens.HIT_MIN)
          .height(DesignTokens.HIT_MIN)
          .alignContent(Alignment.Center)
          .onClick(() => {
            this.openSleepSheet();
          })

          Stack() {
            SymbolGlyph($r('sys.symbol.share'))
              .fontSize(DesignTokens.ICON_L)
              .fontColor([$r('app.color.text_secondary')])
          }
          .width(DesignTokens.HIT_MIN)
          .height(DesignTokens.HIT_MIN)
          .alignContent(Alignment.Center)
          .onClick(() => {
            this.share();
          })
        }
        .width('100%')
        .height(DesignTokens.HEIGHT_APP_BAR)
        .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S })

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
        }

        Scroll() {
          Column({ space: DesignTokens.SPACE_M }) {
            // 封面：上游 cover_fragment 的 1:1 方形（min(宽-64dp, 高)）；无图时回落品牌色底 + 音符占位
            FeedCover({
              imageUrl: this.coverUrl,
              coverSize: this.coverSize,
              radius: DesignTokens.RADIUS_CARD,
              placeholderColor: $r('app.color.primary_container')
            })
              .margin({ top: DesignTokens.SPACE_S })

            // 订阅名 + 单集标题（上游均为 14sp，此处标题用 16fp 保证中文可读性）
            Column({ space: 2 }) {
              if (this.feedTitle !== '') {
                Text(this.feedTitle)
                  .fontSize(DesignTokens.FONT_PARAGRAPH)
                  .fontColor($r('app.color.text_secondary'))
                  .textAlign(TextAlign.Center)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              Text(this.title === '' ? $r('app.string.player_no_playback') : this.title)
                .fontSize(DesignTokens.FONT_TITLE3)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .textAlign(TextAlign.Center)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ left: 32, right: 32 })

            // 「节目详情 / 章节」描边按钮行（上游 episode_details）
            Row({ space: DesignTokens.SPACE_S }) {
              this.detailButton($r('sys.symbol.info_circle'), $r('app.string.player_show_notes'), () => {
                this.showNotesSheet = true;
              })
              if (this.chapters.length > 0) {
                this.detailButton($r('sys.symbol.list_bullet'), $r('app.string.player_chapters'), () => {
                  this.showChaptersSheet = true;
                })
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: DesignTokens.SPACE_XXL })

            // 进度：滑杆 + 左右时间（上游 sbPosition + txtvPosition/txtvLength）
            Column({ space: DesignTokens.SPACE_XS }) {
              Slider({
                value: this.playPosition,
                min: 0,
                max: this.duration > 0 ? this.duration : 1
              })
                .width('100%')
                .trackColor($r('app.color.scrubber_track'))
                .selectedColor($r('app.color.primary'))
                .blockColor($r('app.color.primary'))
                .onChange((value: number) => {
                  PlayerManager.seek(value);
                })
              Row() {
                Text(this.positionText())
                  .fontSize(DesignTokens.FONT_FOOTNOTE)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(DurationUtils.format(this.duration))
                  .fontSize(DesignTokens.FONT_FOOTNOTE)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding({ left: DesignTokens.SPACE_L, right: DesignTokens.SPACE_L })
            }
            .width('100%')
            .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S })

            // 播放控制行：倍速 · 快退 · 播放 · 快进 · 下一集（上游顺序）
            Row() {
              this.controlButton($r('sys.symbol.fast'), this.speed.toFixed(2), () => {
                this.cycleSpeed();
              })
              this.controlButton($r('sys.symbol.arrow_left'), UserPreferences.getRewindSecs().toString(), () => {
                PlayerManager.seekBy(-UserPreferences.getRewindSecs() * 1000);
              })

              Stack() {
                SymbolGlyph(this.status === 'PLAYING'
                  ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                  .fontSize(36)
                  .fontColor([$r('app.color.on_primary')])
              }
              .width(64)
              .height(64)
              .borderRadius(32)
              .backgroundColor($r('app.color.primary'))
              .shadow({ radius: 20, color: '#330A59F7', offsetY: 6 })
              .alignContent(Alignment.Center)
              .margin({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
              .onClick(() => {
                if (this.status === 'PLAYING') {
                  PlayerManager.pause();
                } else {
                  PlayerManager.play();
                }
              })

              this.controlButton($r('sys.symbol.arrow_right'), UserPreferences.getFastForwardSecs().toString(), () => {
                PlayerManager.seekBy(UserPreferences.getFastForwardSecs() * 1000);
              })
              this.controlButton($r('sys.symbol.forward_end_fill'), '', () => {
                this.skipToNext();
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: DesignTokens.SPACE_XXL })

            // 循环 / 睡眠定时状态
            Row({ space: DesignTokens.SPACE_S }) {
              this.secondaryAction($r('sys.symbol.repeat'), this.repeatLabel(), () => {
                this.cycleRepeat();
              })
              if (this.sleepRemainingText !== '') {
                Row({ space: DesignTokens.SPACE_XS }) {
                  SymbolGlyph($r('sys.symbol.moon_fill'))
                    .fontSize(DesignTokens.ICON_S)
                    .fontColor([$r('app.color.primary')])
                  Text(this.sleepRemainingText)
                    .fontSize(DesignTokens.FONT_FOOTNOTE)
                    .fontColor($r('app.color.primary'))
                }
                .height(DesignTokens.HEIGHT_BUTTON_SM)
                .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
                .backgroundColor($r('app.color.primary_container'))
                .borderRadius(DesignTokens.RADIUS_CHIP)
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .padding({ bottom: DesignTokens.SPACE_XXL })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.showSleepSheet) {
        this.sleepSheet()
      }
      if (this.showChaptersSheet) {
        this.chaptersSheet()
      }
      if (this.showNotesSheet) {
        this.notesSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  /** 播放控制行的单个按钮：48vp 图标按钮 + 下方 12fp 数值标签 */
  @Builder
  controlButton(icon: Resource, label: string, onTap: () => void) {
    Column() {
      Stack() {
        SymbolGlyph(icon)
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(48)
      .height(48)
      .alignContent(Alignment.Center)
      .onClick(() => {
        onTap();
      })

      Text(label)
        .fontSize(DesignTokens.FONT_FOOTNOTE)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .height(16)
    }
    .alignItems(HorizontalAlign.Center)
  }

  /** 描边胶囊按钮（上游 grey_border：8vp 圆角 + 1vp 描边，minWidth 150dp） */
  @Builder
  detailButton(icon: Resource, label: ResourceStr, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_XS }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_M)
        .fontColor([$r('app.color.text_secondary')])
      Text(label)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
    }
    .height(36)
    .constraintSize({ minWidth: 130 })
    .justifyContent(FlexAlign.Center)
    .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S })
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.divider') })
    .onClick(() => {
      onTap();
    })
  }

  /** 次级操作：图标 + 文本的胶囊按钮 */
  @Builder
  secondaryAction(icon: Resource, label: ResourceStr, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_XS }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_S)
        .fontColor([$r('app.color.primary')])
      Text(label)
        .fontSize(DesignTokens.FONT_CAPTION)
        .fontColor($r('app.color.primary'))
    }
    .height(DesignTokens.HEIGHT_BUTTON_SM)
    .padding({ left: DesignTokens.SPACE_M, right: DesignTokens.SPACE_M })
    .backgroundColor($r('app.color.primary_container'))
    .borderRadius(DesignTokens.RADIUS_CHIP)
    .onClick(() => {
      onTap();
    })
  }

  /** 章节弹层（上游 chapters 对话框） */
  @Builder
  chaptersSheet() {
    Column({ space: DesignTokens.SPACE_S }) {
      Text($r('app.string.player_chapters'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: DesignTokens.SPACE_L })

      List({ space: DesignTokens.SPACE_XS }) {
        ForEach(this.chapters, (chapter: Chapter) => {
          ListItem() {
            Row({ space: DesignTokens.SPACE_M }) {
              SymbolGlyph($r('sys.symbol.list_bullet'))
                .fontSize(DesignTokens.ICON_M)
                .fontColor([$r('app.color.text_tertiary')])
              Text(chapter.title)
                .fontSize(DesignTokens.FONT_PARAGRAPH)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(DurationUtils.format(chapter.start))
                .fontSize(DesignTokens.FONT_CAPTION)
                .fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            .padding(DesignTokens.SPACE_M)
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(DesignTokens.RADIUS_ROW)
            .onClick(() => {
              PlayerManager.seek(chapter.start);
              this.showChaptersSheet = false;
            })
          }
        }, (chapter: Chapter) => chapter.id.toString())
      }
      .height(320)
      .width('100%')
      .scrollBar(BarState.Off)

      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: DesignTokens.SPACE_L })
        .onClick(() => {
          this.showChaptersSheet = false;
        })
    }
    .width('100%')
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  /** 节目详情弹层（上游 ItemDescriptionFragment） */
  @Builder
  notesSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      Text($r('app.string.player_show_notes'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: DesignTokens.SPACE_L })

      Scroll() {
        Text(this.description === '' ? $r('app.string.setting_not_set') : this.description)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }
      .height(320)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      Button($r('app.string.dialog_cancel'))
        .width('100%')
        .height(DesignTokens.HEIGHT_BUTTON)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .backgroundColor($r('app.color.surface_secondary'))
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: DesignTokens.SPACE_L })
        .onClick(() => {
          this.showNotesSheet = false;
        })
    }
    .width('100%')
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  @Builder
  sleepSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      Row({ space: DesignTokens.SPACE_S }) {
        SymbolGlyph($r('sys.symbol.moon_fill'))
          .fontSize(DesignTokens.ICON_L)
          .fontColor([$r('app.color.primary')])
        Text($r('app.string.sleep_timer_title'))
          .fontSize(DesignTokens.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: DesignTokens.SPACE_L })

      Row({ space: DesignTokens.SPACE_S }) {
        this.sleepPreset(5)
        this.sleepPreset(10)
        this.sleepPreset(15)
        this.sleepPreset(30)
      }
      .width('100%')
      Row({ space: DesignTokens.SPACE_S }) {
        this.sleepPreset(45)
        this.sleepPreset(60)
      }
      .width('100%')

      Row({ space: DesignTokens.SPACE_S }) {
        TextInput({ text: this.customMinutes, placeholder: $r('app.string.sleep_timer_custom_hint') })
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .type(InputType.Number)
          .backgroundColor($r('app.color.surface_secondary'))
          .onChange((value: string) => {
            this.customMinutes = value;
          })
        Button($r('app.string.sleep_timer_start'))
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            const minutes: number = Number(this.customMinutes.trim());
            if (Number.isFinite(minutes) && minutes > 0) {
              this.startSleepTimer(minutes);
            }
          })
      }
      .width('100%')

      Row({ space: DesignTokens.SPACE_S }) {
        Text($r('app.string.sleep_timer_chapter_end'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.chapterEndToggle })
          .selectedColor($r('app.color.primary'))
          .onChange((isOn: boolean) => {
            this.chapterEndToggle = isOn;
          })
      }
      .width('100%')

      Row({ space: DesignTokens.SPACE_S }) {
        Text($r('app.string.sleep_timer_fade'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.fadeToggle })
          .selectedColor($r('app.color.primary'))
          .onChange((isOn: boolean) => {
            this.fadeToggle = isOn;
          })
      }
      .width('100%')

      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.sleep_timer_stop'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.error_container'))
          .fontColor($r('app.color.error'))
          .onClick(() => {
            SleepTimer.stop();
            ShakeDetector.stop();
            this.showSleepSheet = false;
          })
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showSleepSheet = false;
          })
      }
      .width('100%')
      .margin({ bottom: DesignTokens.SPACE_L })
    }
    .width('100%')
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  @Builder
  sleepPreset(minutes: number) {
    Text(minutes.toString() + 'm')
      .fontSize(DesignTokens.FONT_FOOTNOTE)
      .fontColor($r('app.color.text_primary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(DesignTokens.HEIGHT_BUTTON)
      .backgroundColor($r('app.color.surface_secondary'))
      .borderRadius(DesignTokens.RADIUS_CHIP)
      .onClick(() => {
        this.startSleepTimer(minutes);
      })
  }

  aboutToAppear(): void {
    this.speed = PlayerManager.getSpeed();
    this.repeatMode = UserPreferences.getRepeatMode();
    this.chapterEndToggle = UserPreferences.getSleepStopAtChapterEnd();
    this.fadeToggle = UserPreferences.getSleepFadeOut();
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      const width: number = px2vp(info.width) - 64;
      this.coverSize = width > 280 ? 280 : (width < 160 ? 160 : width);
    } catch (error) {
      this.coverSize = 240;
    }
    this.refresh();
    // 订阅睡眠定时器剩余时间，给用户可见反馈
    this.sleepToken = EventHub.subscribe(EventType.SLEEP_TIMER_UPDATED, (data: object) => {
      const remaining: number | undefined = (data as Record<string, number>)['remainingMs'];
      if (remaining === undefined || remaining <= 0) {
        this.sleepRemainingText = SleepTimer.isPendingChapterEnd()
          ? getContext(this).resourceManager.getStringSync($r('app.string.sleep_timer_waiting_chapter'))
          : '';
        return;
      }
      const minutes: number = Math.floor(remaining / 60000);
      const seconds: number = Math.floor((remaining % 60000) / 1000);
      this.sleepRemainingText = getContext(this).resourceManager.getStringSync($r('app.string.sleep_timer_remaining'))
        + ' ' + minutes + 'm ' + seconds + 's';
    });
    if (this.timerId < 0) {
      this.timerId = setInterval(() => {
        this.refresh();
        // 进度落盘（内部 5s 节流），支持强杀后恢复播放位置
        ProgressPersister.save();
        this.checkChapterEndSleep();
      }, 1000);
    }
    if (SleepTimer.isActive()) {
      ShakeDetector.start(() => {
        this.restartSleepTimer();
      });
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.sleepToken >= 0) {
      EventHub.unsubscribeToken(this.sleepToken);
      this.sleepToken = -1;
    }
    ShakeDetector.stop();
    // 离开播放页时强制保存一次进度
    ProgressPersister.save(true);
  }

  async refresh(): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable !== undefined) {
      this.title = playable.title;
      this.feedTitle = playable.feedTitle;
      this.coverUrl = playable.imageUrl;
      if (playable.feedItemId > 0) {
        try {
          this.chapters = await ChapterRepository.listByFeedItem(playable.feedItemId);
        } catch (error) {
          this.chapters = [];
        }
        if (this.feedItemId !== playable.feedItemId) {
          this.feedItemId = playable.feedItemId;
          await this.loadItem(playable.feedItemId);
        }
      } else {
        this.chapters = [];
      }
    }
    this.status = PlayerManager.getStatus();
    this.playPosition = PlayerManager.getCurrentTime();
    this.duration = PlayerManager.getDuration();
    this.speed = PlayerManager.getSpeed();
  }

  /** 载入单集描述与收藏状态（节目详情弹层 / 工具栏星标） */
  async loadItem(feedItemId: number): Promise<void> {
    try {
      const item: FeedItem | undefined = await EpisodeRepository.getById(feedItemId);
      this.description = item === undefined ? '' : PlayerPage.plainText(item.description);
      this.favorite = await FavoritesRepository.isFavorite(feedItemId);
      // 兜底：播放对象未带封面时（旧播放路径）用库里的单集封面
      if (this.coverUrl === '' && item !== undefined && item.imageUrl !== '') {
        this.coverUrl = item.imageUrl;
      }
    } catch (error) {
      this.description = '';
      this.favorite = false;
    }
  }

  async toggleFavorite(): Promise<void> {
    if (this.feedItemId <= 0) {
      return;
    }
    try {
      if (this.favorite) {
        await FavoritesRepository.remove(this.feedItemId);
      } else {
        const item: FeedItem | undefined = await EpisodeRepository.getById(this.feedItemId);
        await FavoritesRepository.add(this.feedItemId, item === undefined ? 0 : item.feedId);
      }
      this.favorite = !this.favorite;
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.dialog_saved'));
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 分享：复制单集链接到剪贴板（与订阅详情页一致） */
  async share(): Promise<void> {
    let link: string = '';
    try {
      if (this.feedItemId > 0) {
        const item: FeedItem | undefined = await EpisodeRepository.getById(this.feedItemId);
        if (item !== undefined) {
          link = item.link;
          if (link === '' && item.media !== undefined) {
            link = item.media.downloadUrl;
          }
        }
      }
      if (link === '') {
        const playable: Playable | undefined = PlayerManager.getCurrent();
        link = playable === undefined ? '' : playable.downloadUrl;
      }
      if (link === '') {
        this.message = getContext(this).resourceManager.getStringSync($r('app.string.share_no_link'));
        return;
      }
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link);
      await pasteboard.getSystemPasteboard().setData(data);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.share_copied'));
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 下一集：从队列取当前项之后的条目（上游 butSkip） */
  async skipToNext(): Promise<void> {
    try {
      await QueueEngine.load();
      const next: FeedItem | undefined = QueueEngine.nextItem();
      if (next === undefined || next.media === undefined) {
        this.message = getContext(this).resourceManager.getStringSync($r('app.string.placeholder_queue'));
        return;
      }
      const playable: Playable | undefined = await QueueEngine.toPlayable(next);
      if (playable === undefined) {
        return;
      }
      await PlayerManager.load(playable, next.media.position, true);
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  /** 描述文本去标签（上游用 WebView 渲染 HTML，这里做纯文本降级） */
  static plainText(html: string): string {
    if (html === '') {
      return '';
    }
    return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  }

  /** 计时到点且勾选"本章结束停止"时，在章节边界暂停 */
  checkChapterEndSleep(): void {
    if (!SleepTimer.isPendingChapterEnd()) {
      return;
    }
    const end: number = this.currentChapterEnd();
    if (end < 0 || this.playPosition >= end) {
      SleepTimer.expireNow();
    }
  }

  /** 当前所在章节的结束时间；无章节返回 -1，最后一章返回音频结尾 */
  currentChapterEnd(): number {
    if (this.chapters.length === 0) {
      return -1;
    }
    for (let i: number = 0; i < this.chapters.length; i++) {
      const start: number = this.chapters[i].start;
      const nextStart: number = i + 1 < this.chapters.length ? this.chapters[i + 1].start : this.duration;
      if (this.playPosition >= start && this.playPosition < nextStart) {
        return nextStart;
      }
    }
    return this.duration;
  }

  openSleepSheet(): void {
    this.customMinutes = UserPreferences.getSleepTimerMinutes().toString();
    this.showSleepSheet = true;
  }

  startSleepTimer(minutes: number): void {
    if (minutes <= 0) {
      return;
    }
    UserPreferences.setSleepTimerMinutes(minutes);
    UserPreferences.setSleepStopAtChapterEnd(this.chapterEndToggle);
    UserPreferences.setSleepFadeOut(this.fadeToggle);
    this.showSleepSheet = false;
    SleepTimer.start(minutes, () => {
      PlayerManager.pause();
    }, this.chapterEndToggle, this.fadeToggle);
    // 摇一摇重置倒计时（仅在定时器活跃期间监听加速度计）
    ShakeDetector.start(() => {
      this.restartSleepTimer();
    });
  }

  /** 摇一摇：按上次选择的时长重新计时 */
  restartSleepTimer(): void {
    const minutes: number = UserPreferences.getSleepTimerMinutes();
    SleepTimer.start(minutes, () => {
      PlayerManager.pause();
    }, this.chapterEndToggle, this.fadeToggle);
    this.sleepRemainingText = getContext(this).resourceManager.getStringSync($r('app.string.sleep_timer_reset'));
  }

  /** 播放位置文本：DurationUtils.format 对 0 返回空串，这里补成 0:00，避免出现 "PAUSED   / 0:05" */
  positionText(): string {
    const text: string = DurationUtils.format(this.playPosition);
    return text === '' ? '0:00' : text;
  }

  cycleSpeed(): void {
    const presets: number[] = PlayerManager.SPEED_PRESETS;
    let index: number = presets.indexOf(this.speed);
    if (index < 0) {
      index = presets.indexOf(1.0);
    }
    const next: number = presets[(index + 1) % presets.length];
    PlayerManager.setSpeed(next);
    // 与上游一致：播放页改的倍速同时作为后续播放的默认倍速
    UserPreferences.setDefaultPlaybackSpeed(next);
    this.speed = next;
  }

  cycleRepeat(): void {
    this.repeatMode = (this.repeatMode + 1) % 3;
    UserPreferences.setRepeatMode(this.repeatMode);
  }

  repeatLabel(): ResourceStr {
    if (this.repeatMode === 1) {
      return $r('app.string.repeat_one');
    }
    if (this.repeatMode === 2) {
      return $r('app.string.repeat_all');
    }
    return $r('app.string.repeat_off');
  }
}
