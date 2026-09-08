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

export enum SortOrder {
  DATE_NEW_OLD = 0,
  DATE_OLD_NEW = 1,
  TITLE_A_Z = 2,
  TITLE_Z_A = 3,
  DURATION_SHORT_LONG = 4,
  DURATION_LONG_SHORT = 5
}

export enum EnqueueLocation {
  BACK = 0,
  FRONT = 1,
  AFTER_CURRENTLY_PLAYING = 2
}
