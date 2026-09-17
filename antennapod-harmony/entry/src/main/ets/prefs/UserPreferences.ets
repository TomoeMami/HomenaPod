// Port of: storage/preferences/src/main/java/de/danoeh/antennapod/storage/preferences/UserPreferences.java
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { SortOrder } from '../model/Enums';

const PREF_NAME: string = 'UserPreferences';

export class UserPreferences {
  private static instance: preferences.Preferences | undefined = undefined;

  static init(context: common.Context): void {
    if (UserPreferences.instance !== undefined) {
      return;
    }
    const options: preferences.Options = { name: PREF_NAME };
    UserPreferences.instance = preferences.getPreferencesSync(context, options);
  }

  private static getPrefs(): preferences.Preferences {
    if (UserPreferences.instance === undefined) {
      throw new Error('UserPreferences not initialized');
    }
    return UserPreferences.instance;
  }

  static getTheme(): number {
    return UserPreferences.getPrefs().getSync('prefTheme', 0) as number;
  }

  static setTheme(value: number): void {
    UserPreferences.getPrefs().putSync('prefTheme', value);
    UserPreferences.getPrefs().flush();
  }

  static getDefaultPlaybackSpeed(): number {
    return UserPreferences.getPrefs().getSync('prefPlaybackSpeed', 1.0) as number;
  }

  static setDefaultPlaybackSpeed(value: number): void {
    UserPreferences.getPrefs().putSync('prefPlaybackSpeed', value);
    UserPreferences.getPrefs().flush();
  }

  static getSkipSilence(): boolean {
    return UserPreferences.getPrefs().getSync('prefSkipSilence', false) as boolean;
  }

  static getStreamOverDownload(): boolean {
    return UserPreferences.getPrefs().getSync('prefStreamOverDownload', false) as boolean;
  }

  static setStreamOverDownload(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefStreamOverDownload', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 移动网络允许的更新类型（对照上游 prefMobileUpdateTypes 的 6 项多选）。
   * 取值：feed_refresh / episode_download / auto_download / streaming / images / sync；
   * 上游默认值为 images,sync（见 arrays.xml mobile_update_default_value）。
   */
  static getMobileUpdateTypes(): string[] {
    const value: string = UserPreferences.getPrefs().getSync('prefMobileUpdateTypes', 'images,sync') as string;
    if (value === '') {
      return [];
    }
    return value.split(',');
  }

  static setMobileUpdateTypes(values: string[]): void {
    UserPreferences.getPrefs().putSync('prefMobileUpdateTypes', values.join(','));
    UserPreferences.getPrefs().flush();
  }

  /** 某类更新是否允许走移动网络（如 'feed_refresh'） */
  static isMobileUpdateAllowed(type: string): boolean {
    return UserPreferences.getMobileUpdateTypes().includes(type);
  }

  static getUpdateIntervalMinutes(): number {
    return UserPreferences.getPrefs().getSync('prefAutoUpdateInterval', 360) as number;
  }

  static setUpdateIntervalMinutes(value: number): void {
    UserPreferences.getPrefs().putSync('prefAutoUpdateInterval', value);
    UserPreferences.getPrefs().flush();
  }

  static getEnqueueLocation(): number {
    return UserPreferences.getPrefs().getSync('prefEnqueueLocation', 0) as number;
  }

  static setEnqueueLocation(value: number): void {
    UserPreferences.getPrefs().putSync('prefEnqueueLocation', value);
    UserPreferences.getPrefs().flush();
  }

  static getEpisodeCacheSizeMb(): number {
    return UserPreferences.getPrefs().getSync('prefEpisodeCacheSize', 20) as number;
  }

  static getLastPlayedFeedMediaId(): number {
    return UserPreferences.getPrefs().getSync('prefLastPlayedFeedMediaId', -1) as number;
  }

  static setLastPlayedFeedMediaId(value: number): void {
    UserPreferences.getPrefs().putSync('prefLastPlayedFeedMediaId', value);
    UserPreferences.getPrefs().flush();
  }

  static getDefaultPage(): string {
    return UserPreferences.getPrefs().getSync('prefDefaultPage', 'subscriptions') as string;
  }

  // ---- 功能补齐新增偏好（命名对齐上游 UserPreferences）----

  static getEpisodeNotification(): boolean {
    return UserPreferences.getPrefs().getSync('prefEpisodeNotification', true) as boolean;
  }

  static setEpisodeNotification(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefEpisodeNotification', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 全局新单集动作（上游 prefNewEpisodesAction，默认 1 = ADD_TO_INBOX）。
   * 取值见 model/Enums.ets NewEpisodesAction：0=跟随全局 1=加入收件箱 2=不处理 3=加入队列。
   */
  static getNewEpisodesAction(): number {
    return UserPreferences.getPrefs().getSync('prefNewEpisodesAction', 1) as number;
  }

  static setNewEpisodesAction(value: number): void {
    UserPreferences.getPrefs().putSync('prefNewEpisodesAction', value);
    UserPreferences.getPrefs().flush();
  }

  static getQueueLocked(): boolean {
    return UserPreferences.getPrefs().getSync('prefQueueLocked', false) as boolean;
  }

  static setQueueLocked(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefQueueLocked', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 「保持排序」：队列始终按 prefQueueKeepSortedOrder 自动排序
   * （对照上游 UserPreferences.isQueueKeepSorted / prefQueueKeepSorted）。
   * 开启后入队即插入到排序位置，且禁用拖拽、隐藏「锁定队列」。
   */
  static getQueueKeepSorted(): boolean {
    return UserPreferences.getPrefs().getSync('prefQueueKeepSorted', false) as boolean;
  }

  static setQueueKeepSorted(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefQueueKeepSorted', value);
    UserPreferences.getPrefs().flush();
  }

  static getQueueKeepSortedOrder(): number {
    return UserPreferences.getPrefs().getSync('prefQueueKeepSortedOrder', SortOrder.DATE_NEW_OLD) as number;
  }

  static setQueueKeepSortedOrder(value: number): void {
    UserPreferences.getPrefs().putSync('prefQueueKeepSortedOrder', value);
    UserPreferences.getPrefs().flush();
  }

  /** 首次锁定队列的警告是否还要弹（上游 QueueFragment PREF_SHOW_LOCK_WARNING，默认 true） */
  static getShowQueueLockWarning(): boolean {
    return UserPreferences.getPrefs().getSync('prefShowQueueLockWarning', true) as boolean;
  }

  static setShowQueueLockWarning(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefShowQueueLockWarning', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 队列滚动位置（上游 QueueFragment 的 SCROLL_POSITION_KEY / SCROLL_OFFSET_KEY，
   * 存于独立的 QueueFragment 偏好文件；这里并入同一偏好存储）。
   */
  static getQueueScrollIndex(): number {
    return UserPreferences.getPrefs().getSync('prefQueueScrollIndex', 0) as number;
  }

  static getQueueScrollOffset(): number {
    return UserPreferences.getPrefs().getSync('prefQueueScrollOffset', 0) as number;
  }

  static setQueueScrollPosition(index: number, offset: number): void {
    UserPreferences.getPrefs().putSync('prefQueueScrollIndex', index);
    UserPreferences.getPrefs().putSync('prefQueueScrollOffset', offset);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 收件箱排序（上游 UserPreferences.getInboxSortedOrder / prefInboxSortedOrder，
   * 默认 DATE_NEW_OLD）。收件箱排序面板只提供「日期 / 时长」两类，见 InboxView.sortSheet。
   */
  static getInboxSortedOrder(): number {
    return UserPreferences.getPrefs().getSync('prefInboxSortedOrder', SortOrder.DATE_NEW_OLD) as number;
  }

  static setInboxSortedOrder(value: number): void {
    UserPreferences.getPrefs().putSync('prefInboxSortedOrder', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 收件箱滚动位置（上游 InboxFragment 的静态 scrollPosition，这里持久化以便跨页面重建恢复）。
   * 首页「看新内容」用 InboxFragment.TAG 的滑动配置，但滚动位置只属于收件箱页。
   */
  static getInboxScrollOffset(): number {
    return UserPreferences.getPrefs().getSync('prefInboxScrollOffset', 0) as number;
  }

  static setInboxScrollOffset(offset: number): void {
    UserPreferences.getPrefs().putSync('prefInboxScrollOffset', offset);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 「全部移出收件箱」是否不再询问（上游 InboxFragment 的
   * PREF_DO_NOT_PROMPT_REMOVE_ALL_FROM_INBOX，存在独立的 PrefNewEpisodesFragment 偏好文件；
   * 这里并入同一偏好存储，与队列滚动位置的处理一致）。
   */
  static getRemoveAllInboxDoNotPrompt(): boolean {
    return UserPreferences.getPrefs().getSync('prefDoNotPromptRemovalAllFromInbox', false) as boolean;
  }

  static setRemoveAllInboxDoNotPrompt(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefDoNotPromptRemovalAllFromInbox', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 是否把剩余时长按播放倍速折算（上游 UserPreferences.timeRespectsSpeed / prefPlaybackTimeRespectsSpeed，
   * 默认 true）。队列信息条的「剩余 X」与上游一致受它影响。
   */
  static getTimeRespectsSpeed(): boolean {
    return UserPreferences.getPrefs().getSync('prefTimeRespectsSpeed', true) as boolean;
  }

  static setTimeRespectsSpeed(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefTimeRespectsSpeed', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 行内时长是否显示「剩余时间」（上游 UserPreferences.shouldShowRemainingTime /
   * prefShowRemainingTime，默认 false）。开启后正在播放/有进度的行显示「-12:30」。
   */
  static getShowRemainingTime(): boolean {
    return UserPreferences.getPrefs().getSync('prefShowRemainingTime', false) as boolean;
  }

  static setShowRemainingTime(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefShowRemainingTime', value);
    UserPreferences.getPrefs().flush();
  }

  // ---- 滑动动作（对照上游 SwipeActions.PREF_NAME = SwipeActionsPrefs）----
  // 存 'RIGHT,LEFT' 两个动作 id；noAction = 「启用滑动动作」开关（上游 KEY_PREFIX_NO_ACTION，默认 true）。

  static getSwipeActions(screen: string, fallback: string): string {
    return UserPreferences.getPrefs().getSync('prefSwipeActions_' + screen, fallback) as string;
  }

  static setSwipeActions(screen: string, value: string): void {
    UserPreferences.getPrefs().putSync('prefSwipeActions_' + screen, value);
    UserPreferences.getPrefs().flush();
  }

  static getSwipeActionsEnabled(screen: string): boolean {
    return UserPreferences.getPrefs().getSync('prefNoSwipeAction_' + screen, true) as boolean;
  }

  static setSwipeActionsEnabled(screen: string, value: boolean): void {
    UserPreferences.getPrefs().putSync('prefNoSwipeAction_' + screen, value);
    UserPreferences.getPrefs().flush();
  }

  /** 0=关闭 1=单集循环 2=列表循环 */
  static getRepeatMode(): number {
    return UserPreferences.getPrefs().getSync('prefRepeatMode', 0) as number;
  }

  static setRepeatMode(value: number): void {
    UserPreferences.getPrefs().putSync('prefRepeatMode', value);
    UserPreferences.getPrefs().flush();
  }

  static getFastForwardSecs(): number {
    return UserPreferences.getPrefs().getSync('prefFastForwardSecs', 30) as number;
  }

  static setFastForwardSecs(value: number): void {
    UserPreferences.getPrefs().putSync('prefFastForwardSecs', value);
    UserPreferences.getPrefs().flush();
  }

  static getRewindSecs(): number {
    return UserPreferences.getPrefs().getSync('prefRewindSecs', 10) as number;
  }

  static setRewindSecs(value: number): void {
    UserPreferences.getPrefs().putSync('prefRewindSecs', value);
    UserPreferences.getPrefs().flush();
  }

  static getAutoDownload(): boolean {
    return UserPreferences.getPrefs().getSync('prefAutoDownload', false) as boolean;
  }

  static setAutoDownload(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefAutoDownload', value);
    UserPreferences.getPrefs().flush();
  }

  static getAutoDownloadWifiOnly(): boolean {
    return UserPreferences.getPrefs().getSync('prefAutoDownloadWifiOnly', true) as boolean;
  }

  static setAutoDownloadWifiOnly(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefAutoDownloadWifiOnly', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 是否允许在电池供电（未充电）时自动下载。
   * 对照上游 prefEnableAutoDownloadOnBattery（默认 true = 允许），语义为「允许」而非「仅充电」。
   */
  static getAutoDownloadOnBattery(): boolean {
    return UserPreferences.getPrefs().getSync('prefAutoDownloadOnBattery', true) as boolean;
  }

  static setAutoDownloadOnBattery(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefAutoDownloadOnBattery', value);
    UserPreferences.getPrefs().flush();
  }

  /** 自动下载/缓存上限（集数）；上游 prefEpisodeCacheSize 默认 25 */
  static getEpisodeCacheCount(): number {
    return UserPreferences.getPrefs().getSync('prefEpisodeCacheCount', 25) as number;
  }

  static setEpisodeCacheCount(value: number): void {
    UserPreferences.getPrefs().putSync('prefEpisodeCacheCount', value);
    UserPreferences.getPrefs().flush();
  }

  static getAutoDelete(): boolean {
    return UserPreferences.getPrefs().getSync('prefAutoDelete', false) as boolean;
  }

  static setAutoDelete(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefAutoDelete', value);
    UserPreferences.getPrefs().flush();
  }

  /** 删除本地文件时是否同时移出队列；上游 prefDeleteRemovesFromQueue 默认 false */
  static getDeleteRemovesFromQueue(): boolean {
    return UserPreferences.getPrefs().getSync('prefDeleteRemovesFromQueue', false) as boolean;
  }

  static setDeleteRemovesFromQueue(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefDeleteRemovesFromQueue', value);
    UserPreferences.getPrefs().flush();
  }

  static getStreamConfirmMobile(): boolean {
    return UserPreferences.getPrefs().getSync('prefStreamConfirmMobile', false) as boolean;
  }

  static setStreamConfirmMobile(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefStreamConfirmMobile', value);
    UserPreferences.getPrefs().flush();
  }

  static getAutoResumeAfterInterrupt(): boolean {
    return UserPreferences.getPrefs().getSync('prefAutoResumeAfterInterrupt', true) as boolean;
  }

  static setAutoResumeAfterInterrupt(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefAutoResumeAfterInterrupt', value);
    UserPreferences.getPrefs().flush();
  }

  // ── 耳机 / 蓝牙断开（对照上游 preferences_playback.xml 的 interruptions 分类）──

  /**
   * 耳机或蓝牙设备断开时自动暂停播放；上游 `prefPauseOnHeadsetDisconnect` 默认 **true**
   * （Android 侧由 Media3 的 `handleAudioBecomingNoisy` 承担，鸿蒙侧由 OutputDeviceGuard 承担）。
   */
  static isPauseOnHeadsetDisconnect(): boolean {
    return UserPreferences.getPrefs().getSync('prefPauseOnHeadsetDisconnect', true) as boolean;
  }

  static setPauseOnHeadsetDisconnect(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefPauseOnHeadsetDisconnect', value);
    UserPreferences.getPrefs().flush();
  }

  /** 有线耳机/耳麦重新接入时恢复播放；上游 `prefUnpauseOnHeadsetReconnect` 默认 **true** */
  static isUnpauseOnHeadsetReconnect(): boolean {
    return UserPreferences.getPrefs().getSync('prefUnpauseOnHeadsetReconnect', true) as boolean;
  }

  static setUnpauseOnHeadsetReconnect(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefUnpauseOnHeadsetReconnect', value);
    UserPreferences.getPrefs().flush();
  }

  /** 蓝牙设备重新接入时恢复播放；上游 `prefUnpauseOnBluetoothReconnect` 默认 **false** */
  static isUnpauseOnBluetoothReconnect(): boolean {
    return UserPreferences.getPrefs().getSync('prefUnpauseOnBluetoothReconnect', false) as boolean;
  }

  static setUnpauseOnBluetoothReconnect(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefUnpauseOnBluetoothReconnect', value);
    UserPreferences.getPrefs().flush();
  }

  static getSleepTimerMinutes(): number {
    return UserPreferences.getPrefs().getSync('prefSleepTimerMinutes', 15) as number;
  }

  static setSleepTimerMinutes(value: number): void {
    UserPreferences.getPrefs().putSync('prefSleepTimerMinutes', value);
    UserPreferences.getPrefs().flush();
  }

  static getSleepFadeOut(): boolean {
    return UserPreferences.getPrefs().getSync('prefSleepFadeOut', false) as boolean;
  }

  static setSleepFadeOut(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefSleepFadeOut', value);
    UserPreferences.getPrefs().flush();
  }

  static getSleepStopAtChapterEnd(): boolean {
    return UserPreferences.getPrefs().getSync('prefSleepStopAtChapterEnd', false) as boolean;
  }

  static setSleepStopAtChapterEnd(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefSleepStopAtChapterEnd', value);
    UserPreferences.getPrefs().flush();
  }

  /** 主题：0=跟随系统 1=浅色 2=深色 */
  static setThemeMode(value: number): void {
    UserPreferences.setTheme(value);
  }

  static getThemeMode(): number {
    return UserPreferences.getTheme();
  }

  /** 应用内语言：'default' 表示跟随系统（对应 i18n.setAppPreferredLanguage 语义） */
  static getAppLanguage(): string {
    return UserPreferences.getPrefs().getSync('prefAppLanguage', 'default') as string;
  }

  static setAppLanguage(value: string): void {
    UserPreferences.getPrefs().putSync('prefAppLanguage', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 首页区块顺序（对照上游 `HomePreferences.PREF_SECTION_ORDER`，存逗号分隔的区块 tag）。
   * 空数组 = 用默认顺序（继续收听/看新内容/随机惊喜/常听经典/管理下载）。
   */
  static getHomeSectionOrder(): string[] {
    return UserPreferences.splitList(
      UserPreferences.getPrefs().getSync('prefHomeSectionOrder', '') as string);
  }

  static setHomeSectionOrder(order: string[]): void {
    UserPreferences.getPrefs().putSync('prefHomeSectionOrder', order.join(','));
    UserPreferences.getPrefs().flush();
  }

  /**
   * 首页被隐藏的区块（对照上游 `HomePreferences.PREF_HIDDEN_SECTIONS`，逗号分隔的区块 tag）。
   * 「显示/隐藏」与顺序是两个独立偏好，与上游一致。
   */
  static getHiddenHomeSections(): string[] {
    return UserPreferences.splitList(
      UserPreferences.getPrefs().getSync('prefHomeHiddenSections', '') as string);
  }

  static setHiddenHomeSections(hidden: string[]): void {
    UserPreferences.getPrefs().putSync('prefHomeHiddenSections', hidden.join(','));
    UserPreferences.getPrefs().flush();
  }

  private static splitList(raw: string): string[] {
    if (raw === '') {
      return [];
    }
    const parts: string[] = raw.split(',');
    const result: string[] = [];
    for (const part of parts) {
      const trimmed: string = part.trim();
      if (trimmed !== '') {
        result.push(trimmed);
      }
    }
    return result;
  }

  /**
   * 下载列表排序（上游 `UserPreferences.getDownloadsSortedOrder` / `prefDownloadsSortedOrder`，
   * 默认新→旧）。首页「管理下载」区块与下载页共用。
   */
  static getDownloadsSortedOrder(): number {
    return UserPreferences.getPrefs().getSync('prefDownloadsSortedOrder', SortOrder.DATE_NEW_OLD) as number;
  }

  static setDownloadsSortedOrder(value: number): void {
    UserPreferences.getPrefs().putSync('prefDownloadsSortedOrder', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 下载页行内按钮的动作（上游 `UserPreferences.shouldDownloadsButtonActionPlay` /
   * `prefDownloadsButtonAction`，默认 false）：
   * false = 删除本地文件（DeleteActionButton），true = 播放（PlayActionButton）。
   */
  static getDownloadsButtonPlay(): boolean {
    return UserPreferences.getPrefs().getSync('prefDownloadsButtonAction', false) as boolean;
  }

  static setDownloadsButtonPlay(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefDownloadsButtonAction', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 统计口径：是否把「仅标记为已播」的单集时长计入统计
   * （上游 `StatisticsFragment.PREF_INCLUDE_MARKED_PLAYED`，默认关闭）。
   * 影响统计页「Subscriptions」汇总与首页「常听经典」的排序。
   */
  static getStatisticsIncludeMarked(): boolean {
    return UserPreferences.getPrefs().getSync('prefStatisticsIncludeMarked', false) as boolean;
  }

  static setStatisticsIncludeMarked(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefStatisticsIncludeMarked', value);
    UserPreferences.getPrefs().flush();
  }

  /** 订阅页列数（上游 SubscriptionFragment 的 columns，默认 3；1 = 列表） */
  static getSubscriptionColumns(): number {
    return UserPreferences.getPrefs().getSync('prefSubscriptionColumns', 3) as number;
  }

  static setSubscriptionColumns(value: number): void {
    UserPreferences.getPrefs().putSync('prefSubscriptionColumns', value);
    UserPreferences.getPrefs().flush();
  }

  /** 订阅页是否在瓦片下方显示标题（上游 prefSubscriptionTitle，默认 false：标题画在封面占位底上） */
  static getSubscriptionShowTitles(): boolean {
    return UserPreferences.getPrefs().getSync('prefSubscriptionShowTitles', false) as boolean;
  }

  static setSubscriptionShowTitles(value: boolean): void {
    UserPreferences.getPrefs().putSync('prefSubscriptionShowTitles', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 订阅列表排序（上游 FeedOrder + prefFeedOrder，默认 0=未播放数）。
   * 0=未播放数 1=字母 2=最近更新 3=最多播放
   */
  static getFeedOrder(): number {
    return UserPreferences.getPrefs().getSync('prefFeedOrder', 0) as number;
  }

  static setFeedOrder(value: number): void {
    UserPreferences.getPrefs().putSync('prefFeedOrder', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 订阅列表过滤器（上游 SubscriptionsFilter + prefSubscriptionsFilter）。
   * 逗号分隔的 filterId 集合，空串表示不过滤；每个组最多取一个值，跨组之间为"与"。
   */
  static getSubscriptionsFilter(): string {
    return UserPreferences.getPrefs().getSync('prefSubscriptionsFilter', '') as string;
  }

  static setSubscriptionsFilter(value: string): void {
    UserPreferences.getPrefs().putSync('prefSubscriptionsFilter', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 订阅瓦片计数口径（上游 FeedCounterDialog + prefDrawerFeedIndicator）。
   * 取值与上游 FeedCounter 的 id 一一对应：
   * 1=收件箱新单集 2=未播放 3=不显示 4=已下载 5=已下载且未播放。
   * 默认 1（上游 SHOW_NEW）；用新键名 `prefSubscriptionCounterSetting`，
   * 避免旧键（0=总数 1=未播放 2=已下载 3=已下载未播放 4=不显示）的存量值被误读。
   */
  static getSubscriptionCounter(): number {
    return UserPreferences.getPrefs().getSync('prefSubscriptionCounterSetting', 1) as number;
  }

  static setSubscriptionCounter(value: number): void {
    UserPreferences.getPrefs().putSync('prefSubscriptionCounterSetting', value);
    UserPreferences.getPrefs().flush();
  }

  /**
   * 订阅页上次选中的标签（上游 SubscriptionFragment 的 `last_tag`，
   * 每次进入恢复上次标签；标签不存在时回落「全部」）。
   */
  static getSubscriptionLastTag(): string {
    return UserPreferences.getPrefs().getSync('prefSubscriptionLastTag', '') as string;
  }

  static setSubscriptionLastTag(value: string): void {
    UserPreferences.getPrefs().putSync('prefSubscriptionLastTag', value);
    UserPreferences.getPrefs().flush();
  }
}
