// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/FeedMedia.java
import { MediaType } from './Enums';

export interface FeedMediaOptions {
  id: number;
  duration: number;
  fileUrl: string;
  downloadUrl: string;
  downloadDate: number;
  position: number;
  size: number;
  mimeType: string;
  lastPlayedTimeHistory: number;
  feedItemId: number;
  playedDuration: number;
  hasEmbeddedPicture: boolean;
  lastPlayedTimeStatistics: number;
}

export class FeedMedia {
  id: number = 0;
  duration: number = 0;
  fileUrl: string = '';
  downloadUrl: string = '';
  downloadDate: number = 0;
  position: number = 0;
  size: number = 0;
  mimeType: string = '';
  lastPlayedTimeHistory: number = 0;
  feedItemId: number = 0;
  playedDuration: number = 0;
  hasEmbeddedPicture: boolean = false;
  lastPlayedTimeStatistics: number = 0;

  constructor(options: FeedMediaOptions) {
    this.id = options.id;
    this.duration = options.duration;
    this.fileUrl = options.fileUrl;
    this.downloadUrl = options.downloadUrl;
    this.downloadDate = options.downloadDate;
    this.position = options.position;
    this.size = options.size;
    this.mimeType = options.mimeType;
    this.lastPlayedTimeHistory = options.lastPlayedTimeHistory;
    this.feedItemId = options.feedItemId;
    this.playedDuration = options.playedDuration;
    this.hasEmbeddedPicture = options.hasEmbeddedPicture;
    this.lastPlayedTimeStatistics = options.lastPlayedTimeStatistics;
  }

  isDownloaded(): boolean {
    return this.fileUrl !== '';
  }

  getMediaType(): MediaType {
    if (this.mimeType.indexOf('video') >= 0) {
      return MediaType.VIDEO;
    }
    if (this.mimeType.indexOf('audio') >= 0) {
      return MediaType.AUDIO;
    }
    return MediaType.UNKNOWN;
  }

  getDuration(): number {
    return this.duration;
  }

  getPosition(): number {
    return this.position;
  }

  saveCurrentPosition(newPosition: number): void {
    this.position = newPosition;
  }
}
