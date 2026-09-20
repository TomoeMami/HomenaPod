import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { ConfigurationConstant } from '@kit.AbilityKit';
import i18n from '@ohos.i18n';
import { UserPreferences } from '../prefs/UserPreferences';
import { SortOrder } from '../model/Enums';
import { EventHub, EventType, FeedUpdateData } from '../events/EventHub';
import { WorkSchedulerManager } from '../work/WorkSchedulerManager';
import { ImageCache } from '../services/ImageCache';
import { PlayerManager } from '../player/PlayerManager';
import { DesignTokens } from '../common/DesignTokens';
import { SwipeActions, SwipeActionId, SwipeScreen, SwipeActionSpec, swipeActionSpec } from '../common/SwipeActions';
import { AppBar } from '../components/AppBar';
import { TagChip } from '../components/TagChip';
import { RowCard } from '../components/RowCard';

/** 主题取值：0=跟随系统 1=浅色 2=深色 */
const THEME_SYSTEM: number = 0;
const THEME_LIGHT: number = 1;
const THEME_DARK: number = 2;

/** 上游 preference 行最小高度（两行文本 + 上下各 12dp） */
const ROW_MIN_HEIGHT: number = 56;
/** 前置 24dp 图标 + 16dp 间距：次级内容（胶囊、输入框）的缩进 */
const ROW_INDENT: number = DesignTokens.ICON_XL + DesignTokens.SPACE_L;

/** 滑动动作选择格高度（图标 + 文案，2 列网格单元） */
const SWIPE_CHOICE_HEIGHT: number = 52;
/** 滑动动作选择格最大高度：动作多时由网格内部滚动，避免弹层超出屏幕 */
const SWIPE_CHOICE_MAX_HEIGHT: number = 216;

/** 滑动动作变更事件负载：该事件不带数据，空接口用于满足 EventHub.publish 的 `data: object` 形参 */
interface SwipeActionsChangedData {
}

/**
 * 设置页（对齐上游 PreferenceActivity + preferences*.xml）：
 * 分类标题 14sp 品牌色（上 16vp / 下 8vp），分类内每行 = 24vp 图标 + 标题 16sp
 * + 可选摘要 14sp + 尾部控件（开关 / 当前值 + 箭头 / 数值输入），行间 1vp 分隔线，
 * 整组包在 surface 卡片（圆角 12vp）内。
 */
@Entry
@Component
export struct SettingsPage {
  @State theme: number = THEME_SYSTEM;
  @State streamOverDownload: boolean = false;
  @State streamConfirmMobile: boolean = false;
  @State speedText: string = '1.00x';
  @State forwardText: string = '30';
  @State rewindText: string = '10';
  @State intervalText: string = '360';
  @State autoDownload: boolean = false;
  @State autoDownloadWifiOnly: boolean = true;
  @State autoDownloadOnBattery: boolean = true;
  @State cacheLimitText: string = '50';
  @State autoDelete: boolean = false;
  @State deleteRemovesFromQueue: boolean = true;
  @State episodeNotification: boolean = true;
  @State language: string = 'default';
  /** 下载列表排序（上游 prefDownloadsSortedOrder；影响下载页与首页「管理下载」） */
  @State downloadsSortOrder: SortOrder = SortOrder.DATE_NEW_OLD;
  /** 下载页行内按钮改为播放（上游 prefDownloadsButtonAction，默认关 = 删除文件） */
  @State downloadsButtonPlay: boolean = false;
  @State message: string = '';
  /** 行内时长是否显示「剩余时间」（上游 prefShowRemainingTime，默认关） */
  @State showRemainingTime: boolean = false;
  /** 时间显示是否随播放倍速折算（上游 prefTimeRespectsSpeed，默认开） */
  @State timeRespectsSpeed: boolean = true;
  /** 滑动动作设置弹层开关（上游 SwipeActionsDialog） */
  @State showSwipeSheet: boolean = false;
  /** 耳机/蓝牙断开时自动暂停（上游 prefPauseOnHeadsetDisconnect，默认开） */
  @State pauseOnDisconnect: boolean = true;
  /** 耳机重新接入时恢复播放（上游 prefUnpauseOnHeadsetReconnect，默认开） */
  @State unpauseOnHeadsetReconnect: boolean = true;
  /** 蓝牙重新接入时恢复播放（上游 prefUnpauseOnBluetoothReconnect，默认关） */
  @State unpauseOnBluetoothReconnect: boolean = false;
  /** 蓝牙断开后把进度往回拉几秒（移植版独有，默认开；见 UserPreferences.isRewindOnBluetoothDisconnect） */
  @State rewindOnBluetoothDisconnect: boolean = true;
  /** 蓝牙断开回退秒数（内存值，点「保存」才落盘） */
  @State bluetoothRewindText: string = '5';
  /** 弹层当前选中的屏幕（SwipeScreen.*） */
  @State swipeScreen: string = SwipeScreen.QUEUE;
  /** 该屏幕是否启用滑动动作（上游 KEY_PREFIX_NO_ACTION） */
  @State swipeEnabled: boolean = true;
  /** 展开中的动作选择器：0=都收起 1=右滑 2=左滑 */
  @State pickerOpen: number = 0;
  /** 内存中的右滑 / 左滑动作 id（点「确定」才落盘） */
  @State rightAction: string = SwipeActionId.NONE;
  @State leftAction: string = SwipeActionId.NONE;

  build() {
    // 滑动动作弹层要盖住整个设置列表：对齐 InboxView / EpisodesPage，Stack 底部对齐，
    // 弹层与半透明遮罩叠在列表之上。
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        AppBar({ title: $r('app.string.tab_settings'), showBack: true })

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
            .padding({ bottom: DesignTokens.SPACE_S })
          }

          // ── User interface（上游 preferences_user_interface.xml）──
          this.categoryTitle($r('app.string.settings_category_interface'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.themeRow()
              this.rowDivider()
              this.languageRow()
              this.rowDivider()
              // 行内时长显示剩余时间（上游 prefShowRemainingTime）
              this.switchRow($r('sys.symbol.clock'), $r('app.string.setting_show_remaining_time'),
                this.showRemainingTime, (isOn: boolean) => {
                  this.showRemainingTime = isOn;
                  UserPreferences.setShowRemainingTime(isOn);
                  this.notifyPrefsChanged();
                })
              this.rowDivider()
              // 滑动动作（上游 SwipeActionsDialog）：本移植版用底部弹层承载，入口行无当前值
              this.navRow($r('sys.symbol.rectangle_stack'), $r('app.string.setting_swipe_actions'), '', () => {
                this.openSwipeSheet();
              })
              this.rowDivider()
              // 下载页行内按钮动作（上游 preferences_user_interface.xml 的 prefDownloadsButtonAction）
              this.switchRow($r('sys.symbol.trash'), $r('app.string.setting_downloads_button_play'),
                this.downloadsButtonPlay, (isOn: boolean) => {
                  this.downloadsButtonPlay = isOn;
                  UserPreferences.setDownloadsButtonPlay(isOn);
                  this.notifyPrefsChanged();
                })
            }
            .width('100%')
          }

          // ── Playback（上游 preferences_playback.xml：Playback control + Queue）──
          this.categoryTitle($r('app.string.settings_section_playback'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.navRow($r('sys.symbol.fast'), $r('app.string.setting_speed'), this.speedText, () => {
                this.cycleDefaultSpeed();
              })
              this.rowDivider()
              this.numberRow($r('sys.symbol.arrow_left'), $r('app.string.setting_rewind'), this.rewindText, 72,
                (text: string) => {
                  this.rewindText = text;
                })
              this.rowDivider()
              this.numberRow($r('sys.symbol.arrow_right'), $r('app.string.setting_forward'), this.forwardText, 72,
                (text: string) => {
                  this.forwardText = text;
                })
              this.rowDivider()
              this.footerAction($r('app.string.dialog_save'), () => {
                this.saveSkipSteps();
              })
              this.rowDivider()
              this.switchRow($r('sys.symbol.music_note_list'), $r('app.string.setting_stream_first'),
                this.streamOverDownload, (isOn: boolean) => {
                  this.streamOverDownload = isOn;
                  UserPreferences.setStreamOverDownload(isOn);
                })
              this.rowDivider()
              this.switchRow($r('sys.symbol.exclamationmark_circle'), $r('app.string.setting_stream_confirm_mobile'),
                this.streamConfirmMobile, (isOn: boolean) => {
                  this.streamConfirmMobile = isOn;
                  UserPreferences.setStreamConfirmMobile(isOn);
                })
              this.rowDivider()
              // 时长显示随倍速折算（上游 prefTimeRespectsSpeed）
              this.switchRow($r('sys.symbol.timer'), $r('app.string.setting_time_respects_speed'),
                this.timeRespectsSpeed, (isOn: boolean) => {
                  this.timeRespectsSpeed = isOn;
                  UserPreferences.setTimeRespectsSpeed(isOn);
                  this.notifyPrefsChanged();
                })
            }
            .width('100%')
          }

          // ── Interruptions（上游 preferences_playback.xml 的 interruptions 分类）──
          //
          // 耳机拔出 / 蓝牙断开时暂停播放：鸿蒙不会代应用暂停，靠 AVPlayer 的
          // audioOutputDeviceChangeWithInfo（REASON_OLD_DEVICE_UNAVAILABLE）由应用自己处理，
          // 判定逻辑在 OutputDevicePolicy / PlayerManager.handleOutputDeviceChange。
          this.categoryTitle($r('app.string.settings_category_interruptions'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.switchRow($r('sys.symbol.headphones'), $r('app.string.setting_pause_on_disconnect'),
                this.pauseOnDisconnect, (isOn: boolean) => {
                  this.pauseOnDisconnect = isOn;
                  UserPreferences.setPauseOnHeadsetDisconnect(isOn);
                })
              // 上游用 android:dependency 把两条「重连恢复」挂在「断开暂停」之下：
              // 断开都不暂停了，恢复自然无从谈起，直接隐藏（值仍保留）
              if (this.pauseOnDisconnect) {
                this.rowDivider()
                this.switchRow($r('sys.symbol.earphone'), $r('app.string.setting_unpause_on_headset_reconnect'),
                  this.unpauseOnHeadsetReconnect, (isOn: boolean) => {
                    this.unpauseOnHeadsetReconnect = isOn;
                    UserPreferences.setUnpauseOnHeadsetReconnect(isOn);
                  })
                this.rowDivider()
                this.switchRow($r('sys.symbol.bluetooth'), $r('app.string.setting_unpause_on_bluetooth_reconnect'),
                  this.unpauseOnBluetoothReconnect, (isOn: boolean) => {
                    this.unpauseOnBluetoothReconnect = isOn;
                    UserPreferences.setUnpauseOnBluetoothReconnect(isOn);
                  })
                // 蓝牙断开后的补偿回退（移植版独有）：蓝牙掉线到系统通知应用之间有延迟，
                // 暂停的同时把进度往回拉几秒，重连后不会漏掉这段内容。
                this.rowDivider()
                this.switchRow($r('sys.symbol.bluetooth'), $r('app.string.setting_rewind_on_bluetooth_disconnect'),
                  this.rewindOnBluetoothDisconnect, (isOn: boolean) => {
                    this.rewindOnBluetoothDisconnect = isOn;
                    UserPreferences.setRewindOnBluetoothDisconnect(isOn);
                  })
                // 与「快退秒数」同款：输入框 + 保存动作（关掉回退后整行收起）
                if (this.rewindOnBluetoothDisconnect) {
                  this.rowDivider()
                  this.numberRow($r('sys.symbol.timer'), $r('app.string.setting_rewind_on_bluetooth_disconnect_secs'),
                    this.bluetoothRewindText, 72, (text: string) => {
                      this.bluetoothRewindText = text;
                    })
                  this.rowDivider()
                  this.footerAction($r('app.string.dialog_save'), () => {
                    this.saveBluetoothRewind();
                  })
                }
              }
            }
            .width('100%')
          }

          // ── Network（上游 Downloads → Automation「Refresh podcasts」+ Details「Mobile updates」）──
          this.categoryTitle($r('app.string.settings_category_network'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.numberRow($r('sys.symbol.arrow_clockwise'), $r('app.string.setting_schedule_refresh'),
                this.intervalText, 72, (text: string) => {
                  this.intervalText = text;
                })
              this.rowDivider()
              this.footerActions($r('app.string.setting_schedule_apply'), () => {
                this.applySchedule();
              }, $r('app.string.setting_schedule_cancel'), () => {
                this.cancelSchedule();
              })
              this.rowDivider()
              this.switchRow($r('sys.symbol.wifi'), $r('app.string.setting_auto_download_wifi'),
                this.autoDownloadWifiOnly, (isOn: boolean) => {
                  this.autoDownloadWifiOnly = isOn;
                  UserPreferences.setAutoDownloadWifiOnly(isOn);
                })
            }
            .width('100%')
          }

          // ── Automatic download（上游 preferences_autodownload.xml）──
          this.categoryTitle($r('app.string.settings_category_autodownload'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.switchRow($r('sys.symbol.download_1'), $r('app.string.setting_auto_download'), this.autoDownload,
                (isOn: boolean) => {
                  this.autoDownload = isOn;
                  UserPreferences.setAutoDownload(isOn);
                })
              this.rowDivider()
              this.switchRow($r('sys.symbol.battery'), $r('app.string.setting_auto_download_battery'),
                this.autoDownloadOnBattery, (isOn: boolean) => {
                  this.autoDownloadOnBattery = isOn;
                  UserPreferences.setAutoDownloadOnBattery(isOn);
                })
              this.rowDivider()
              this.numberRow($r('sys.symbol.rectangle_stack'), $r('app.string.setting_cache_limit'),
                this.cacheLimitText, 64, (text: string) => {
                  this.cacheLimitText = text;
                })
              this.rowDivider()
              this.footerAction($r('app.string.dialog_save'), () => {
                this.saveCacheLimit();
              })
            }
            .width('100%')
          }

          // ── Storage（上游 preferences_auto_deletion.xml + Downloads「Choose data folder」）──
          this.categoryTitle($r('app.string.settings_category_storage'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.switchRow($r('sys.symbol.trash'), $r('app.string.setting_auto_delete'), this.autoDelete,
                (isOn: boolean) => {
                  this.autoDelete = isOn;
                  UserPreferences.setAutoDelete(isOn);
                })
              this.rowDivider()
              this.switchRow($r('sys.symbol.list_bullet'), $r('app.string.setting_delete_removes_queue'),
                this.deleteRemovesFromQueue, (isOn: boolean) => {
                  this.deleteRemovesFromQueue = isOn;
                  UserPreferences.setDeleteRemovesFromQueue(isOn);
                })
              this.rowDivider()
              // 下载排序（上游由下载页的排序动作设置；本移植版放在设置里，点击循环切换）
              this.downloadsSortNav()
              this.rowDivider()
              this.navRow($r('sys.symbol.sdcard_fill'), $r('app.string.setting_storage'), '', () => {
                router.pushUrl({ url: 'pages/StoragePage' });
              })
            }
            .width('100%')
          }

          // ── Notifications（上游 preferences_notifications.xml）──
          this.categoryTitle($r('app.string.settings_category_notifications'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.switchRow($r('sys.symbol.bell'), $r('app.string.setting_episode_notification'),
                this.episodeNotification, (isOn: boolean) => {
                  this.episodeNotification = isOn;
                  UserPreferences.setEpisodeNotification(isOn);
                })
            }
            .width('100%')
          }

          // ── Library（历史 / 统计 / OPML / 缓存）──
          this.categoryTitle($r('app.string.settings_section_library'))
          RowCard({ pad: 0, radius: DesignTokens.RADIUS_ROW }) {
            Column() {
              this.navRow($r('sys.symbol.clock'), $r('app.string.setting_history'), '', () => {
                router.pushUrl({ url: 'pages/HistoryPage' });
              })
              this.rowDivider()
              this.navRow($r('sys.symbol.histogram'), $r('app.string.setting_stats'), '', () => {
                router.pushUrl({ url: 'pages/StatsPage' });
              })
              this.rowDivider()
              this.navRow($r('sys.symbol.doc_text'), $r('app.string.setting_opml'), '', () => {
                router.pushUrl({ url: 'pages/OpmlPage' });
              })
              this.rowDivider()
              this.tapRow($r('sys.symbol.trash'), $r('app.string.setting_clear_cache'), () => {
                this.clearCache();
              })
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.SPACE_XXL })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.page_bg'))
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))

      // 底部弹层（对照 InboxView.removeAllSheet）：全屏遮罩点击关闭，弹层贴底
      if (this.showSwipeSheet) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.showSwipeSheet = false;
          })
        this.swipeActionsSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 分类标题（对齐上游 PreferenceCategory：14sp 品牌色，paddingTop 16dp / paddingBottom 8dp） */
  @Builder
  categoryTitle(label: ResourceStr) {
    Text(label)
      .fontSize(DesignTokens.FONT_PARAGRAPH)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.primary'))
      .width('100%')
      .padding({ top: DesignTokens.SPACE_L, bottom: DesignTokens.SPACE_S })
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

  /**
   * 下载排序行：图标 + 标题 + 当前排序 + 箭头，点击循环切换并持久化。
   *
   * 单独写一个 builder 而不是调 `navRow(...)`：`@Builder` 的参数是**按值传递**，
   * 把 `this.downloadsSortLabel()` 当参数传进去，切换后文案不会刷新
   * （第 40 轮验收实测：设置里点了排序，右侧仍显示「最新优先」）。这里在 builder
   * 内部直接读 `@State`，切换后标签才会跟着变。
   *
   * 切换后广播 `FEED_LIST_UPDATE`：首页 / 订阅页订阅了它，会重新读偏好并重排
   * （否则要手动下拉刷新一次才看到新顺序）。
   */
  @Builder
  downloadsSortNav() {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph($r('sys.symbol.sort'))
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text($r('app.string.setting_sort_order'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text(this.downloadsSortLabel())
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)

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
      this.downloadsSortOrder = ((this.downloadsSortOrder + 1) % 6) as SortOrder;
      UserPreferences.setDownloadsSortedOrder(this.downloadsSortOrder);
      // feedId 0 = 与 RefreshService.publishFeedListUpdate 一致：不针对某个订阅的「列表已变」通知
      const data: FeedUpdateData = { feedId: 0 };
      EventHub.publish(EventType.FEED_LIST_UPDATE, data);
    })
  }

  /** 导航行：图标 + 标题 + 当前值 + 箭头 */
  @Builder
  navRow(icon: Resource, title: ResourceStr, value: string, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text(title)
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      if (value !== '') {
        Text(value)
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }

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

  /** 纯动作行：图标 + 标题（无尾部控件） */
  @Builder
  tapRow(icon: Resource, title: ResourceStr, onTap: () => void) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text(title)
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
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

  /** 卡片底部文字动作（对齐上游对话框右下角的文本按钮） */
  @Builder
  footerAction(label: ResourceStr, onTap: () => void) {
    Row() {
      Blank()
      Text(label)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary'))
        .padding({
          left: DesignTokens.SPACE_L,
          right: DesignTokens.SPACE_L,
          top: DesignTokens.SPACE_S,
          bottom: DesignTokens.SPACE_S
        })
        .onClick(() => {
          onTap();
        })
    }
    .width('100%')
    .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_XS })
    .justifyContent(FlexAlign.End)
  }

  /** 卡片底部双动作（主 / 次，对齐上游对话框 OK / Cancel） */
  @Builder
  footerActions(primaryLabel: ResourceStr, onPrimary: () => void,
                secondaryLabel: ResourceStr, onSecondary: () => void) {
    Row({ space: DesignTokens.SPACE_S }) {
      Blank()
      Text(secondaryLabel)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .padding({
          left: DesignTokens.SPACE_L,
          right: DesignTokens.SPACE_L,
          top: DesignTokens.SPACE_S,
          bottom: DesignTokens.SPACE_S
        })
        .onClick(() => {
          onSecondary();
        })
      Text(primaryLabel)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary'))
        .padding({
          left: DesignTokens.SPACE_L,
          right: DesignTokens.SPACE_L,
          top: DesignTokens.SPACE_S,
          bottom: DesignTokens.SPACE_S
        })
        .onClick(() => {
          onPrimary();
        })
    }
    .width('100%')
    .padding({ left: DesignTokens.SPACE_S, right: DesignTokens.SPACE_S, bottom: DesignTokens.SPACE_XS })
    .justifyContent(FlexAlign.End)
  }

  /** 主题行（上游 ThemePreference 的自定义布局：标题 + 三张卡片，这里用胶囊） */
  @Builder
  themeRow() {
    Column({ space: DesignTokens.SPACE_S }) {
      Row({ space: DesignTokens.SPACE_L }) {
        SymbolGlyph($r('sys.symbol.paintpalette'))
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([$r('app.color.text_secondary')])
        Text($r('app.string.setting_theme'))
          .fontSize(DesignTokens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: DesignTokens.SPACE_S }) {
        TagChip({
          label: $r('app.string.setting_theme_system'),
          selected: this.theme === THEME_SYSTEM,
          onTap: () => {
            this.applyTheme(THEME_SYSTEM);
          }
        })
        TagChip({
          label: $r('app.string.setting_theme_light'),
          selected: this.theme === THEME_LIGHT,
          onTap: () => {
            this.applyTheme(THEME_LIGHT);
          }
        })
        TagChip({
          label: $r('app.string.setting_theme_dark'),
          selected: this.theme === THEME_DARK,
          onTap: () => {
            this.applyTheme(THEME_DARK);
          }
        })
      }
      .width('100%')
      .padding({ left: ROW_INDENT })
    }
    .width('100%')
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(HorizontalAlign.Start)
  }

  /** 语言行（同上：标题 + 三张胶囊） */
  @Builder
  languageRow() {
    Column({ space: DesignTokens.SPACE_S }) {
      Row({ space: DesignTokens.SPACE_L }) {
        SymbolGlyph($r('sys.symbol.textformat'))
          .fontSize(DesignTokens.ICON_XL)
          .fontColor([$r('app.color.text_secondary')])
        Text($r('app.string.setting_language'))
          .fontSize(DesignTokens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: DesignTokens.SPACE_S }) {
        TagChip({
          label: $r('app.string.setting_language_system'),
          selected: this.language === 'default',
          onTap: () => {
            this.applyLanguage('default');
          }
        })
        TagChip({
          label: $r('app.string.setting_language_zh'),
          selected: this.language === 'zh-Hans',
          onTap: () => {
            this.applyLanguage('zh-Hans');
          }
        })
        TagChip({
          label: $r('app.string.setting_language_en'),
          selected: this.language === 'en-US',
          onTap: () => {
            this.applyLanguage('en-US');
          }
        })
      }
      .width('100%')
      .padding({ left: ROW_INDENT })
    }
    .width('100%')
    .padding({
      left: DesignTokens.SPACE_L,
      right: DesignTokens.SPACE_L,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 滑动动作设置弹层（对照上游 SwipeActionsDialog）：
   * 屏幕胶囊 → 启用开关 → 右滑 / 左滑动作选择 → 取消 / 确定。
   *
   * 弹层内的取值都在 builder 内部直接读 `@State`，不通过参数传入：`@Builder` 参数是
   * **按值传递**，换屏幕或换动作后传进来的旧值不会刷新（同 `downloadsSortNav()` 的说明）。
   */
  @Builder
  swipeActionsSheet() {
    Column({ space: DesignTokens.SPACE_M }) {
      Text($r('app.string.setting_swipe_actions'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: DesignTokens.SPACE_L })

      // 屏幕选择：切换后重新读取该屏幕的左右滑动作与启用开关
      Scroll() {
        Row({ space: DesignTokens.SPACE_S }) {
          this.swipeScreenChip($r('app.string.swipe_screen_queue'), SwipeScreen.QUEUE)
          this.swipeScreenChip($r('app.string.swipe_screen_inbox'), SwipeScreen.INBOX)
          this.swipeScreenChip($r('app.string.swipe_screen_feed_detail'), SwipeScreen.FEED_DETAIL)
          this.swipeScreenChip($r('app.string.swipe_screen_downloads'), SwipeScreen.DOWNLOADS)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      this.swipeEnableRow()

      this.swipePickerRow(1)
      if (this.pickerOpen === 1) {
        this.swipeChoiceGrid(1)
      }
      this.rowDivider()
      this.swipePickerRow(2)
      if (this.pickerOpen === 2) {
        this.swipeChoiceGrid(2)
      }

      Row({ space: DesignTokens.SPACE_M }) {
        Button($r('app.string.dialog_cancel'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .onClick(() => {
            this.showSwipeSheet = false;
          })
        Button($r('app.string.confirm_label'))
          .layoutWeight(1)
          .height(DesignTokens.HEIGHT_BUTTON)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .fontSize(DesignTokens.FONT_PARAGRAPH)
          .onClick(() => {
            this.saveSwipeActions();
          })
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius({ topLeft: DesignTokens.RADIUS_SHEET, topRight: DesignTokens.RADIUS_SHEET })
    .padding({ left: DesignTokens.PAGE_MARGIN, right: DesignTokens.PAGE_MARGIN, bottom: DesignTokens.PAGE_MARGIN })
  }

  /** 屏幕胶囊（对照 EpisodesPage.filterChip：选中态由 `@State swipeScreen` 决定） */
  @Builder
  swipeScreenChip(label: ResourceStr, screen: string) {
    TagChip({
      label: label,
      selected: this.swipeScreen === screen,
      onTap: () => {
        this.selectSwipeScreen(screen);
      }
    })
  }

  /** 「启用滑动动作」开关行：读 `@State swipeEnabled`，换屏幕后开关状态跟着刷新 */
  @Builder
  swipeEnableRow() {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph($r('sys.symbol.hand_draw'))
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text($r('app.string.swipe_enable_label'))
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.swipeEnabled })
        .selectedColor($r('app.color.primary'))
        .onChange((isOn: boolean) => {
          this.swipeEnabled = isOn;
        })
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_S,
      right: DesignTokens.SPACE_S,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
  }

  /** 动作选择行（slot：1=右滑 2=左滑）：当前动作 + 箭头，点击展开 / 收起下面的网格 */
  @Builder
  swipePickerRow(slot: number) {
    Row({ space: DesignTokens.SPACE_L }) {
      SymbolGlyph(swipeActionSpec(this.swipePickerAction(slot)).icon)
        .fontSize(DesignTokens.ICON_XL)
        .fontColor([$r('app.color.text_secondary')])

      Text(this.swipePickerTitle(slot))
        .fontSize(DesignTokens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text(swipeActionSpec(this.swipePickerAction(slot)).label)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)

      SymbolGlyph(this.pickerOpen === slot ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
        .fontSize(DesignTokens.ICON_M)
        .fontColor([$r('app.color.text_disabled')])
    }
    .width('100%')
    .constraintSize({ minHeight: ROW_MIN_HEIGHT })
    .padding({
      left: DesignTokens.SPACE_S,
      right: DesignTokens.SPACE_S,
      top: DesignTokens.SPACE_M,
      bottom: DesignTokens.SPACE_M
    })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.pickerOpen = this.pickerOpen === slot ? 0 : slot;
    })
  }

  /** 动作网格（2 列）：该屏幕的所有可选动作，当前选中的用品牌色 */
  @Builder
  swipeChoiceGrid(slot: number) {
    Grid() {
      ForEach(SwipeActions.available(this.swipeScreen), (spec: SwipeActionSpec) => {
        GridItem() {
          this.swipeChoice(slot, spec)
        }
      }, (spec: SwipeActionSpec) => spec.id)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(DesignTokens.SPACE_S)
    .rowsGap(DesignTokens.SPACE_S)
    .width('100%')
    .height(this.swipeChoiceGridHeight())
    .scrollBar(BarState.Off)
  }

  /** 单个动作选择格：图标 + 文案，选中态品牌色 */
  @Builder
  swipeChoice(slot: number, spec: SwipeActionSpec) {
    Row({ space: DesignTokens.SPACE_XS }) {
      SymbolGlyph(spec.icon)
        .fontSize(DesignTokens.ICON_M)
        .fontColor([this.swipeChoiceColor(slot, spec.id)])

      Text(spec.label)
        .fontSize(DesignTokens.FONT_PARAGRAPH)
        .fontColor(this.swipeChoiceColor(slot, spec.id))
        .maxLines(1)
    }
    .width('100%')
    .height(SWIPE_CHOICE_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface_secondary'))
    .borderRadius(DesignTokens.RADIUS_CHIP)
    .onClick(() => {
      this.pickSwipeAction(slot, spec.id);
    })
  }

  aboutToAppear(): void {
    this.theme = UserPreferences.getThemeMode();
    this.streamOverDownload = UserPreferences.getStreamOverDownload();
    this.streamConfirmMobile = UserPreferences.getStreamConfirmMobile();
    this.speedText = UserPreferences.getDefaultPlaybackSpeed().toFixed(2) + 'x';
    this.forwardText = UserPreferences.getFastForwardSecs().toString();
    this.rewindText = UserPreferences.getRewindSecs().toString();
    this.intervalText = String(UserPreferences.getUpdateIntervalMinutes());
    this.autoDownload = UserPreferences.getAutoDownload();
    this.autoDownloadWifiOnly = UserPreferences.getAutoDownloadWifiOnly();
    this.autoDownloadOnBattery = UserPreferences.getAutoDownloadOnBattery();
    this.cacheLimitText = UserPreferences.getEpisodeCacheCount().toString();
    this.autoDelete = UserPreferences.getAutoDelete();
    this.deleteRemovesFromQueue = UserPreferences.getDeleteRemovesFromQueue();
    this.episodeNotification = UserPreferences.getEpisodeNotification();
    this.language = UserPreferences.getAppLanguage();
    this.downloadsSortOrder = UserPreferences.getDownloadsSortedOrder() as SortOrder;
    this.downloadsButtonPlay = UserPreferences.getDownloadsButtonPlay();
    this.showRemainingTime = UserPreferences.getShowRemainingTime();
    this.timeRespectsSpeed = UserPreferences.getTimeRespectsSpeed();
    this.pauseOnDisconnect = UserPreferences.isPauseOnHeadsetDisconnect();
    this.unpauseOnHeadsetReconnect = UserPreferences.isUnpauseOnHeadsetReconnect();
    this.unpauseOnBluetoothReconnect = UserPreferences.isUnpauseOnBluetoothReconnect();
    this.rewindOnBluetoothDisconnect = UserPreferences.isRewindOnBluetoothDisconnect();
    this.bluetoothRewindText = UserPreferences.getBluetoothDisconnectRewindSecs().toString();
  }

  /** 下载排序当前值文案（与订阅详情页的排序文案一致） */
  downloadsSortLabel(): string {
    const order: SortOrder = this.downloadsSortOrder;
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

  applyTheme(value: number): void {
    this.theme = value;
    UserPreferences.setThemeMode(value);
    SettingsPage.applyColorMode(getContext(this) as common.UIAbilityContext, value);
  }

  applyLanguage(value: string): void {
    this.language = value;
    UserPreferences.setAppLanguage(value);
    SettingsPage.applyAppLanguage(value);
    this.message = getContext(this).resourceManager.getStringSync($r('app.string.language_restart'));
  }

  cycleDefaultSpeed(): void {
    const presets: number[] = PlayerManager.SPEED_PRESETS;
    const current: number = UserPreferences.getDefaultPlaybackSpeed();
    let index: number = presets.indexOf(current);
    if (index < 0) {
      index = presets.indexOf(1.0);
    }
    const next: number = presets[(index + 1) % presets.length];
    UserPreferences.setDefaultPlaybackSpeed(next);
    this.speedText = next.toFixed(2) + 'x';
  }

  saveSkipSteps(): void {
    const forward: number = Number(this.forwardText.trim());
    const rewind: number = Number(this.rewindText.trim());
    if (Number.isFinite(forward) && forward > 0 && forward <= 300) {
      UserPreferences.setFastForwardSecs(Math.floor(forward));
    }
    if (Number.isFinite(rewind) && rewind > 0 && rewind <= 300) {
      UserPreferences.setRewindSecs(Math.floor(rewind));
    }
    this.message = getContext(this).resourceManager.getStringSync($r('app.string.dialog_saved'));
  }

  /** 蓝牙断开回退秒数（边界与「快退秒数」一致：1–300 秒，越界不落盘） */
  saveBluetoothRewind(): void {
    const secs: number = Number(this.bluetoothRewindText.trim());
    if (Number.isFinite(secs) && secs > 0 && secs <= 300) {
      UserPreferences.setBluetoothDisconnectRewindSecs(Math.floor(secs));
      this.bluetoothRewindText = Math.floor(secs).toString();
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.dialog_saved'));
    }
  }

  /** 定时刷新：保存间隔并登记 WorkScheduler 任务（0 = 从不，等价上游 feed_refresh_never） */
  applySchedule(): void {
    const interval: number = Number(this.intervalText);
    if (Number.isFinite(interval) && interval === 0) {
      UserPreferences.setUpdateIntervalMinutes(0);
      WorkSchedulerManager.cancel();
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.schedule_cancelled'));
      return;
    }
    if (Number.isFinite(interval) && interval >= 120) {
      UserPreferences.setUpdateIntervalMinutes(interval);
      const context = getContext(this) as common.Context;
      WorkSchedulerManager.schedule(context, interval);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.schedule_set')) + interval;
    } else {
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.schedule_invalid'));
    }
  }

  /** 取消定时刷新：停任务并持久化「从不」，否则冷启动会被 restore() 重新登记 */
  cancelSchedule(): void {
    WorkSchedulerManager.cancel();
    UserPreferences.setUpdateIntervalMinutes(0);
    this.message = getContext(this).resourceManager.getStringSync($r('app.string.schedule_cancelled'));
  }

  /** 自动下载集数上限（上游「Episode limit」） */
  saveCacheLimit(): void {
    const limit: number = Number(this.cacheLimitText.trim());
    if (Number.isFinite(limit) && limit > 0) {
      UserPreferences.setEpisodeCacheCount(Math.floor(limit));
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.dialog_saved'));
    }
  }

  clearCache(): void {
    ImageCache.clearCache(getContext(this));
    this.message = getContext(this).resourceManager.getStringSync($r('app.string.cache_cleared'));
  }

  /** 打开滑动动作弹层：每次从队列屏开始（对齐上游 SwipeActionsDialog 的默认 tag），并载入该屏配置 */
  openSwipeSheet(): void {
    this.swipeScreen = SwipeScreen.QUEUE;
    this.pickerOpen = 0;
    this.loadSwipeActions();
    this.showSwipeSheet = true;
  }

  /** 切换屏幕胶囊：重新读取该屏幕的左右滑动作与启用开关 */
  selectSwipeScreen(screen: string): void {
    this.swipeScreen = screen;
    this.pickerOpen = 0;
    this.loadSwipeActions();
  }

  /** 读取当前屏幕的 [右滑, 左滑] 动作与启用开关（对照上游 SwipeActions.getPrefsWithDefaults） */
  loadSwipeActions(): void {
    const resolved: string[] = SwipeActions.resolve(this.swipeScreen);
    this.rightAction = resolved[0];
    this.leftAction = resolved[1];
    this.swipeEnabled = SwipeActions.isEnabled(this.swipeScreen);
  }

  /** 选择行标题（slot：1=右滑 2=左滑） */
  swipePickerTitle(slot: number): ResourceStr {
    return slot === 1 ? $r('app.string.swipe_right_label') : $r('app.string.swipe_left_label');
  }

  /** 选择行当前动作 id（slot：1=右滑 2=左滑） */
  swipePickerAction(slot: number): string {
    return slot === 1 ? this.rightAction : this.leftAction;
  }

  /** 该侧是否选中了此动作 */
  isSwipeChoiceSelected(slot: number, actionId: string): boolean {
    return this.swipePickerAction(slot) === actionId;
  }

  /** 选择格配色：选中项品牌色，其余次级色 */
  swipeChoiceColor(slot: number, actionId: string): Resource {
    return this.isSwipeChoiceSelected(slot, actionId)
      ? $r('app.color.primary')
      : $r('app.color.text_secondary');
  }

  /** 选择网格高度：按 2 列估行数，超过上限后由网格内部滚动 */
  swipeChoiceGridHeight(): number {
    const count: number = SwipeActions.available(this.swipeScreen).length;
    const rows: number = Math.ceil(count / 2);
    const needed: number = rows * SWIPE_CHOICE_HEIGHT + (rows - 1) * DesignTokens.SPACE_S;
    return needed > SWIPE_CHOICE_MAX_HEIGHT ? SWIPE_CHOICE_MAX_HEIGHT : needed;
  }

  /** 选中动作：只改内存里的选择（点「确定」才落盘），随后收起网格 */
  pickSwipeAction(slot: number, actionId: string): void {
    if (slot === 1) {
      this.rightAction = actionId;
    } else {
      this.leftAction = actionId;
    }
    this.pickerOpen = 0;
  }

  /**
   * 确定：写入该屏幕的左右滑动作与启用开关，广播 SWIPE_ACTIONS_CHANGED 让队列 / 收件箱 /
   * 订阅详情 / 下载页重新读取配置，并复用其它设置的「已保存」提示。
   */
  saveSwipeActions(): void {
    SwipeActions.set(this.swipeScreen, this.rightAction, this.leftAction);
    SwipeActions.setEnabled(this.swipeScreen, this.swipeEnabled);
    // 该事件不带数据；显式声明负载类型，避免 ArkTS 的无类型对象字面量错误
    const data: SwipeActionsChangedData = {};
    EventHub.publish(EventType.SWIPE_ACTIONS_CHANGED, data);
    this.pickerOpen = 0;
    this.showSwipeSheet = false;
    this.message = getContext(this).resourceManager.getStringSync($r('app.string.dialog_saved'));
  }

  /**
   * 影响列表显示的偏好（显示剩余时间 / 时长按倍速折算）变化后广播，
   * 队列页据此重新读取偏好并重绘（页签常驻，不会重新走 aboutToAppear）。
   */
  private notifyPrefsChanged(): void {
    const data: SwipeActionsChangedData = {};
    EventHub.publish(EventType.PREFS_CHANGED, data);
  }

  /** 设置应用语言（'default' = 跟随系统）；需冷启动生效 */
  static applyAppLanguage(language: string): void {
    try {
      i18n.System.setAppPreferredLanguage(language);
    } catch (error) {
      // 语言设置失败不阻断其他设置
    }
  }

  /** 切换应用级深浅色模式；0=跟随系统 */
  static applyColorMode(context: common.UIAbilityContext, mode: number): void {
    try {
      let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      if (mode === THEME_DARK) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      } else if (mode === THEME_LIGHT) {
        colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      }
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      // 主题切换失败不影响设置保存
    }
  }
}
