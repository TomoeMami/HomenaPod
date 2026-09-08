// Port of: model/playback/Playable.java + model/playback/RemoteMedia.java
import { MediaType } from './Enums';

export class Playable {
  id: number = 0;
  feedItemId: number = 0;
  title: string = '';
  feedTitle: string = '';
  downloadUrl: string = '';
  localFileUrl: string = '';
  duration: number = 0;
  position: number = 0;
  mediaType: MediaType = MediaType.AUDIO;

  constructor(id: number, feedItemId: number, title: string, feedTitle: string, downloadUrl: string,
              localFileUrl: string, duration: number, position: number, mediaType: MediaType) {
    this.id = id;
    this.feedItemId = feedItemId;
    this.title = title;
    this.feedTitle = feedTitle;
    this.downloadUrl = downloadUrl;
    this.localFileUrl = localFileUrl;
    this.duration = duration;
    this.position = position;
    this.mediaType = mediaType;
  }

  getSourceUrl(): string {
    if (this.localFileUrl !== '') {
      return this.localFileUrl;
    }
    return this.downloadUrl;
  }

  isLocalFile(): boolean {
    return this.localFileUrl !== '';
  }
}
