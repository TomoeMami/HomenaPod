import router from '@ohos.router';
import { Feed } from '../model/Feed';
import { SortOrder, AutoDeleteAction, NewEpisodesAction } from '../model/Enums';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { SubscriptionService } from '../services/SubscriptionService';
import { PlayerManager } from '../player/PlayerManager';
import { EventHub, EventType, FeedUpdateData } from '../events/EventHub';
import { DesignTokens } from '../common/DesignTokens';
import { AppBar } from '../components/AppBar';
import { RowCard } from '../components/RowCard';
import { SectionHeader } from '../components/SectionHeader';
import { FeedCover } from '../components/FeedCover';

interface FeedSettingsParams {
  feedId: number;
}

/** 上游 preference 行最小高度（两行文本 + 上下各 12dp） */
const ROW_MIN_HEIGHT: number = 56;

/**
 * 订阅设置页（对齐上游 feedsettings.xml + FeedSettingsPreferenceFragment）：
 * 顶栏标题为订阅标题，正文首块是 56vp 封面 + 标题的头部卡，随后按上游
 * PreferenceCategory 顺序分组（Episode filter / Sort order / Auto download /
 * Playback / Automation / Display / Advanced），每组 = 24vp 图标 + 标题 16sp
 * + 可选摘要 14sp + 尾部控件，行间 1vp 分隔线，整组在 surface 卡片内；
 * 末尾为 error_container 底 + error 文字的「取消订阅」破坏性行。
 */
@Entry
@Component
struct FeedSettingsPage {
  @State feed: Feed | undefined = undefined;
  @State loading: boolean = true;
  @State message: string = '';
  @State customTitle: string = '';
  @State tags: string = '';
  @State username: string = '';
  @State password: string = '';
  @State skipIntroText: string = '';
  @State skipEndingText: string = '';
  @State showUnsubscribeConfirm: boolean = false;
  private feedId: number = 0;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        AppBar({ title: this.toolbarTitle(), showBack: true }) {
          Button($r('app.string.dialog_save'))
            .height(DesignTokens.HEIGHT_BUTTON_SM)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .backgroundColor($r('app.color.primary_container'))
            .fontColor($r('app.color.primary'))
            .onClick(() => {
              this.save();
            })
        }

        if (this.loading) {
          Text($r('app.string.loading'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_tertiary'))
            .layoutWeight(1)
        } else if (this.feed === undefined) {
          Text($r('app.string.subscribe_failed'))
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.error'))
            .layoutWeight(1)
        } else {
          Scroll() {
            Column() {
              if (this.message !== '') {
                Row({ space: DesignTokens.SPACE_XS }) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                    .fontSize(DesignTokens.ICON_S)
                    .fontColor([$r('app.color.primary')])
                  Text(this.message)
                    .fontSize(DesignTokens.FONT_FOOTNOTE)
                    .fontColor($r('app.color.primary'))
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: DesignTokens.SPACE_S })
              }

              // ── 头部：56vp 封面 + 标题（上游 toolbar 的标题/副标题区）──
              Column() {
                RowCard({ pad: DesignTokens.SPACE_M, radius: DesignTokens.RADIUS_CARD }) {
                  Row({ space: DesignTokens.SPACE_M }) {
                    FeedCover({
                      imageUrl: this.feed!.imageUrl,
                      coverSize: DesignTokens.COVER_LIST,
                      fallbackTitle: this.feedTitle()
                    })
                    Column({ space: DesignTokens.SPACE_XS }) {
                      Text(this.feedTitle())
                        .fontSize(DesignTokens.FONT_BODY)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      if (this.feed!.customTitle !== '') {
                        Text(this.feed!.title)
                          .fontSize(DesignTokens.FONT_PARAGRAPH)
                          .fontColor($r('app.color.text_secondary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
              }
              .width('100%')
              .margin({ top: DesignTokens.SPACE_M })

              // ── Episode filter（上游 episodeFilter：单行 + 摘要 + 对话框）──
              SectionHeader({ title: $r('app.string.settings_section_filter') })
              RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
                Column() {
                  this.navRow($r('sys.symbol.funnel'), $r('app.string.feed_filter'), this.filterSummary(), () => {
                    router.back();
                  })
                }
                .width('100%')
              }

              // ── Sort order ──
              SectionHeader({ title: $r('app.string.setting_sort_order') })
              RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
                Column() {
                  this.navRow($r('sys.symbol.sort'), $r('app.string.setting_sort_order'), this.sortOrderLabel(), () => {
                    this.feed!.sortOrder = ((this.feed!.sortOrder + 1) % 6) as SortOrder;
                  })
                }
                .width('100%')
              }

              // ── Auto download（上游 automation 组的下载相关条目）──
              SectionHeader({ title: $r('app.string.setting_auto_download') })
              RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
                Column() {
                  this.switchRow($r('sys.symbol.download_1'), $r('app.string.setting_auto_download'),
                    this.feed!.autoDownloadEnabled, (isOn: boolean) => {
                      this.feed!.autoDownloadEnabled = isOn;
                    })
                  this.rowDivider()
                  this.navRow($r('sys.symbol.trash'), $r('app.string.setting_auto_delete'), this.autoDeleteLabel(),
                    () => {
                      this.feed!.autoDeleteAction = (this.feed!.autoDeleteAction + 1) % 4;
                    })
                  this.rowDivider()
                  this.navRow($r('sys.symbol.inbox'), $r('app.string.setting_new_episodes_action'),
                    this.newEpisodesLabel(), () => {
                      this.cycleNewEpisodesAction();
                    })
                }
                .width('100%')
              }

              // ── Playback（上游 playback_pref：速度 / 跳过片头片尾 / 音量适配）──
              SectionHeader({ title: $r('app.string.settings_section_playback') })
              RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
                Column() {
                  this.navRow($r('sys.symbol.fast'), $r('app.string.setting_playback_speed'), this.speedLabel(),
                    () => {
                      this.cycleSpeed();
                    })
                  this.rowDivider()
                  this.navRow($r('sys.symbol.headphones'), $r('app.string.setting_volume_adaption'),
                    this.volumeLabel(), () => {
                      this.cycleVolume();
                    })
                  this.rowDivider()
                  this.numberRow($r('sys.symbol.arrow_right'), $r('app.string.setting_skip_intro'),
                    this.skipIntroText, 96, (text: string) => {
                      this.skipIntroText = text;
                    })
                  this.rowDivider()
                  this.numberRow($r('sys.symbol.forward_end_fill'), $r('app.string.setting_skip_ending'),
                    this.skipEndingText, 96, (text: string) => {
                      this.skipEndingText = text;
                    })
                  this.rowDivider()
                  this.disabledRow($r('sys.symbol.speaker_minus'), $r('app.string.setting_skip_silence'),
                    $r('app.string.setting_unsupported'))
                }
                .width('100%')
              }

              // ── Automation（上游 keepUpdated / episodeNotification）──
              SectionHeader({ title: $r('app.string.settings_category_automation') })
              RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
                Column() {
                  this.switchRow($r('sys.symbol.arrow_clockwise'), $r('app.string.setting_keep_updated'),
                    this.feed!.keepUpdated, (isOn: boolean) => {
                      this.feed!.keepUpdated = isOn;
                    })
                  this.rowDivider()
                  this.switchRow($r('sys.symbol.bell'), $r('app.string.setting_episode_notification'),
                    this.feed!.episodeNotification, (isOn: boolean) => {
                      this.feed!.episodeNotification = isOn;
                    })
                }
                .width('100%')
              }

              // ── Display（上游 pref_display：重命名 / 标签）──
              SectionHeader({ title: $r('app.string.settings_category_display') })
              RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
                Column() {
                  this.textRow($r('sys.symbol.square_and_pencil'), $r('app.string.setting_custom_title'),
                    this.customTitle, (value: string) => {
                      this.customTitle = value;
                    })
                  this.rowDivider()
                  this.textRow($r('sys.symbol.list_bullet'), $r('app.string.setting_tags'), this.tags,
                    (value: string) => {
                      this.tags = value;
                    })
                }
                .width('100%')
              }

              // ── Advanced（上游 authentication）──
              SectionHeader({ title: $r('app.string.settings_category_advanced') })
              RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
                Column() {
                  this.textRow($r('sys.symbol.key'), $r('app.string.setting_username'), this.username,
                    (value: string) => {
                      this.username = value;
                    })
                  this.rowDivider()
                  this.textRow($r('sys.symbol.lock_fill'), $r('app.string.setting_password'), this.password,
                    (value: string) => {
                      this.password = value;
                    })
                }
                .width('100%')
              }

              // 退订（上游 remove_feed_dialog 的破坏性动作）
              Row({ space: DesignTokens.SPACE_S }) {
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(DesignTokens.ICON_M)
                  .fontColor([$r('app.color.error')])
                Text($r('app.string.feed_unsubscribe'))
                  .fontSize(DesignTokens.FONT_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.error'))
              }
              .width('100%')
              .height(DesignTokens.HEIGHT_BUTTON)
              .justifyContent(FlexAlign.Center)
              .backgroundColor($r('app.color.error_container'))
              .borderRadius(DesignTokens.RADIUS_ROW)
              .margin({ top: DesignTokens.SPACE_XL, bottom: DesignTokens.SPACE_XXL })
              .onClick(() => {
                this.showUnsubscribeConfirm = true;
              })
            }
            .width('100%')
            .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
          }
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')

      if (this.showUnsubscribeConfirm) {
        this.unsubscribeSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 行间分隔线（上游 preference 列表 1dp divider） */
  @Builder
  rowDivider() {
    Divider()
      .color($r('app.color.divider'))
      .strokeWidth(1)
      .width('100%')
  }

  /** 开关行：图标 + 标题 + 尾部开关 */
  @Builder
  switchRow(icon: Resource, title: ResourceStr, value: boolean, onChange: (isOn: boolean) => void) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text(title)
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.primary'))
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
  }

  /** 导航行：图标 + 标题（+ 摘要）+ 当前值 + 箭头 */
  @Builder
  navRow(icon: Resource, title: ResourceStr, value: string, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Column({ space: 2 }) {
        Text(title)
          .fontSize(DesignTokens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (value !== '') {
          Text(value)
            .fontSize(DesignTokens.FONT_PARAGRAPH)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(DesignTokens.ICON_M)
        .fontColor([$r('app.color.text_disabled')])
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      onTap();
    })
  }

  /** 文本输入行：图标 + 标题 + 尾部输入框 */
  @Builder
  textRow(icon: Resource, title: ResourceStr, value: string, onChange: (value: string) => void) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text(title)
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      TextInput({ text: value })
        .width(140)
        .height(DesignTokens.HEIGHT_BUTTON_SM)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .backgroundColor($r('app.color.surface_secondary'))
        .onChange((text: string) => {
          onChange(text);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
  }

  /** 数值输入行：图标 + 标题 + 尾部数字输入框 */
  @Builder
  numberRow(icon: Resource, title: ResourceStr, value: string, inputWidth: number,
            onChange: (text: string) => void) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text(title)
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      TextInput({ text: value })
        .width(inputWidth)
        .height(DesignTokens.HEIGHT_BUTTON_SM)
        .type(InputType.Number)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .backgroundColor($r('app.color.surface_secondary'))
        .onChange((text: string) => {
          onChange(text);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
  }

  /** 不可用行：图标 + 标题 + 右侧说明（上游 android:dependency 置灰的行） */
  @Builder
  disabledRow(icon: Resource, title: ResourceStr, note: ResourceStr) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_disabled')])

      Text(title)
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_disabled'))
        .layoutWeight(1)

      Text(note)
        .fontSize(DesignTokens.FONT_CAPTION)
        .fontColor($r('app.color.text_disabled'))
        .maxLines(1)
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  unsubscribeSheet() {
    Column({ space: DesignTokens.SPACE_L }) {
      Text($r('app.string.feed_unsubscribe_confirm'))
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_primary'))
        .padding({ top: DesignTokens.SPACE_XL, left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN })
      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showUnsubscribeConfirm = false;
          })
        Button($r('app.string.feed_unsubscribe'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .backgroundColor($r('app.color.error'))
          .fontColor(Color.White)
          .onClick(() => {
            this.unsubscribe();
          })
      }
      .width('90%')
      .margin({ bottom: DesignTokens.SPACE_L })
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
  }

  /** 顶栏 / 头部标题：优先自定义标题（上游 custom title 的显示规则） */
  feedTitle(): string {
    if (this.feed === undefined) {
      return '';
    }
    return this.feed.customTitle !== '' ? this.feed.customTitle : this.feed.title;
  }

  toolbarTitle(): ResourceStr {
    if (this.feed === undefined) {
      return $r('app.string.feed_settings');
    }
    return this.feedTitle();
  }

  aboutToAppear(): void {
    const params = router.getParams() as FeedSettingsParams;
    if (params !== undefined && params.feedId !== undefined) {
      this.feedId = params.feedId;
      this.load();
    }
  }

  async load(): Promise<void> {
    try {
      this.feed = await FeedRepository.getById(this.feedId);
      if (this.feed !== undefined) {
        this.customTitle = this.feed.customTitle;
        this.tags = this.feed.feedTags;
        this.username = this.feed.username;
        this.password = this.feed.password;
        this.skipIntroText = this.feed.feedSkipIntro > 0 ? this.feed.feedSkipIntro.toString() : '';
        this.skipEndingText = this.feed.feedSkipEnding > 0 ? this.feed.feedSkipEnding.toString() : '';
      }
    } catch (error) {
      this.feed = undefined;
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  async save(): Promise<void> {
    if (this.feed === undefined) {
      return;
    }
    this.feed.customTitle = this.customTitle.trim();
    this.feed.feedTags = this.tags.trim();
    this.feed.username = this.username.trim();
    this.feed.password = this.password;
    const intro: number = Number(this.skipIntroText.trim());
    const ending: number = Number(this.skipEndingText.trim());
    this.feed.feedSkipIntro = Number.isFinite(intro) && intro > 0 ? Math.floor(intro) : 0;
    this.feed.feedSkipEnding = Number.isFinite(ending) && ending > 0 ? Math.floor(ending) : 0;
    try {
      await FeedRepository.updatePreferences(this.feed);
      const data: FeedUpdateData = { feedId: this.feed.id };
      EventHub.publish(EventType.FEED_UPDATE, data);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.dialog_saved'));
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  async unsubscribe(): Promise<void> {
    if (this.feed === undefined) {
      return;
    }
    this.showUnsubscribeConfirm = false;
    try {
      await SubscriptionService.unsubscribe(this.feed.id);
      const data: FeedUpdateData = { feedId: this.feed.id };
      EventHub.publish(EventType.FEED_UPDATE, data);
      EventHub.publish(EventType.FEED_LIST_UPDATE, data);
      router.back();
    } catch (error) {
      this.message = (error as Error).message;
    }
  }

  cycleSpeed(): void {
    const options: number[] = [0].concat(PlayerManager.SPEED_PRESETS);
    const current: number = this.feed!.feedPlaybackSpeed;
    const index: number = options.indexOf(current);
    this.feed!.feedPlaybackSpeed = options[(index + 1) % options.length];
  }

  cycleVolume(): void {
    const options: number[] = [0, 0.75, 1.25, 1.5];
    const index: number = options.indexOf(this.feed!.feedVolumeAdaption);
    this.feed!.feedVolumeAdaption = options[(index + 1) % options.length];
  }

  speedLabel(): string {
    const value: number = this.feed!.feedPlaybackSpeed;
    return value > 0 ? value.toFixed(2) + 'x' : getContext(this).resourceManager.getStringSync($r('app.string.setting_not_set'));
  }

  volumeLabel(): string {
    const value: number = this.feed!.feedVolumeAdaption;
    if (value === 0) {
      return getContext(this).resourceManager.getStringSync($r('app.string.setting_not_set'));
    }
    return value < 1
      ? getContext(this).resourceManager.getStringSync($r('app.string.volume_reduce')) + ' ' + value.toFixed(2)
      : getContext(this).resourceManager.getStringSync($r('app.string.volume_boost')) + ' ' + value.toFixed(2);
  }

  autoDeleteLabel(): string {
    const action: number = this.feed!.autoDeleteAction;
    if (action === AutoDeleteAction.GLOBAL_DEFAULT) {
      return getContext(this).resourceManager.getStringSync($r('app.string.autodelete_global'));
    }
    if (action === AutoDeleteAction.ALWAYS) {
      return getContext(this).resourceManager.getStringSync($r('app.string.autodelete_always'));
    }
    if (action === AutoDeleteAction.WHEN_PLAYED) {
      return getContext(this).resourceManager.getStringSync($r('app.string.autodelete_when_played'));
    }
    return getContext(this).resourceManager.getStringSync($r('app.string.autodelete_never'));
  }

  newEpisodesLabel(): string {
    const action: number = this.feed!.newEpisodesAction;
    if (action === NewEpisodesAction.ADD_TO_QUEUE) {
      return getContext(this).resourceManager.getStringSync($r('app.string.newepisodes_queue'));
    }
    if (action === NewEpisodesAction.DO_NOTHING) {
      return getContext(this).resourceManager.getStringSync($r('app.string.newepisodes_nothing'));
    }
    if (action === NewEpisodesAction.ADD_TO_INBOX) {
      return getContext(this).resourceManager.getStringSync($r('app.string.newepisodes_inbox'));
    }
    return getContext(this).resourceManager.getStringSync($r('app.string.setting_not_set'));
  }

  /** 新单集动作循环：跟随全局 → 加入收件箱 → 加入队列 → 不处理（对照上游 4 选项） */
  cycleNewEpisodesAction(): void {
    const options: number[] = [
      NewEpisodesAction.GLOBAL,
      NewEpisodesAction.ADD_TO_INBOX,
      NewEpisodesAction.ADD_TO_QUEUE,
      NewEpisodesAction.DO_NOTHING
    ];
    const index: number = options.indexOf(this.feed!.newEpisodesAction);
    this.feed!.newEpisodesAction = options[(index + 1) % options.length];
  }

  sortOrderLabel(): string {
    const order: SortOrder = this.feed!.sortOrder;
    if (order === SortOrder.DATE_OLD_NEW) {
      return getContext(this).resourceManager.getStringSync($r('app.string.sort_date_old_new'));
    }
    if (order === SortOrder.TITLE_A_Z) {
      return getContext(this).resourceManager.getStringSync($r('app.string.sort_title_a_z'));
    }
    if (order === SortOrder.TITLE_Z_A) {
      return getContext(this).resourceManager.getStringSync($r('app.string.sort_title_z_a'));
    }
    if (order === SortOrder.DURATION_SHORT_LONG) {
      return getContext(this).resourceManager.getStringSync($r('app.string.sort_duration_short_long'));
    }
    if (order === SortOrder.DURATION_LONG_SHORT) {
      return getContext(this).resourceManager.getStringSync($r('app.string.sort_duration_long_short'));
    }
    return getContext(this).resourceManager.getStringSync($r('app.string.sort_date_new_old'));
  }

  filterSummary(): string {
    if (this.feed === undefined) {
      return '';
    }
    const parts: string[] = [];
    if (this.feed.includeFilter !== '') {
      parts.push('+' + this.feed.includeFilter);
    }
    if (this.feed.excludeFilter !== '') {
      parts.push('-' + this.feed.excludeFilter);
    }
    if (this.feed.minimalDurationFilter > 0) {
      parts.push('≥' + this.feed.minimalDurationFilter + 's');
    }
    return parts.length === 0 ? getContext(this).resourceManager.getStringSync($r('app.string.setting_not_set'))
      : parts.join(' ');
  }
}
