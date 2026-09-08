// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/FeedPreferences.java
export class FeedPreferences {
  autoDownload: boolean = true;
  autoDeleteAction: number = 0;
  feedPlaybackSpeed: number = 0;
  feedSkipSilence: number = 0;
  feedVolumeAdaption: number = 0;
  feedSkipIntro: number = 0;
  feedSkipEnding: number = 0;
  episodeNotification: boolean = false;
  newEpisodesAction: number = 0;
}
