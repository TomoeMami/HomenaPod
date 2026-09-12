// Port of: model/src/main/java/de/danoeh/antennapod/model/... (enums)
export enum FeedState {
  STATE_NOT_SUBSCRIBED = 0,
  STATE_SUBSCRIBED = 1,
  STATE_SUBSCRIBING = 2
}

export enum MediaType {
  AUDIO = 0,
  VIDEO = 1,
  UNKNOWN = 2
}

export enum DownloadStatus {
  DOWNLOADING = 0,
  COMPLETED = 1,
  PAUSED = 2,
  FAILED = 3,
  REMOVED = 4
}

/**
 * 排序方式。0–5 为全库/订阅详情共用的基础六项（与 Feeds.sort_order 落库值一一对应，不可改动）；
 * 6 起是队列页排序对话框新增的项（对照上游 SortOrder：播客标题、随机、智能乱序）。
 */
export enum SortOrder {
  DATE_NEW_OLD = 0,
  DATE_OLD_NEW = 1,
  TITLE_A_Z = 2,
  TITLE_Z_A = 3,
  DURATION_SHORT_LONG = 4,
  DURATION_LONG_SHORT = 5,
  FEED_TITLE_A_Z = 6,
  FEED_TITLE_Z_A = 7,
  RANDOM = 8,
  SMART_SHUFFLE_OLD_NEW = 9,
  SMART_SHUFFLE_NEW_OLD = 10
}

export enum EnqueueLocation {
  BACK = 0,
  FRONT = 1,
  AFTER_CURRENTLY_PLAYING = 2
}

/** 每 Feed 自动删除策略（对应 Feeds.auto_delete_action） */
export enum AutoDeleteAction {
  NEVER = 0,
  GLOBAL_DEFAULT = 1,
  ALWAYS = 2,
  WHEN_PLAYED = 3
}

/**
 * 每 Feed 新剧集处理动作（对应 Feeds.new_episodes_action）。
 * 取值与上游 FeedPreferences.NewEpisodesAction 一致：GLOBAL(0) / ADD_TO_INBOX(1) / NOTHING(2) / ADD_TO_QUEUE(3)。
 */
export enum NewEpisodesAction {
  GLOBAL = 0,
  ADD_TO_INBOX = 1,
  DO_NOTHING = 2,
  ADD_TO_QUEUE = 3
}
