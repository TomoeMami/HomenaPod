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
  /** 每 Feed 播放倍速（0/1.0 表示未设置） */
  speed: number = 1.0;
  /** 每 Feed 跳片头秒数（0 表示关闭） */
  skipIntro: number = 0;
  /** 每 Feed 跳片尾秒数（0 表示关闭） */
  skipEnding: number = 0;
  /** 每 Feed 音量适配（0 表示未设置；>1 会被 AVPlayer clamp 到 1.0） */
  volumeAdaption: number = 0;
  /** 封面地址（单集封面优先，回落到播客封面；空串表示无封面） */
  imageUrl: string = '';

  constructor(id: number, feedItemId: number, title: string, feedTitle: string, downloadUrl: string,
              localFileUrl: string, duration: number, position: number, mediaType: MediaType,
              speed: number = 1.0, skipIntro: number = 0, skipEnding: number = 0,
              volumeAdaption: number = 0, imageUrl: string = '') {
    this.id = id;
    this.feedItemId = feedItemId;
    this.title = title;
    this.feedTitle = feedTitle;
    this.downloadUrl = downloadUrl;
    this.localFileUrl = localFileUrl;
    this.duration = duration;
    this.position = position;
    this.mediaType = mediaType;
    this.speed = speed;
    this.skipIntro = skipIntro;
    this.skipEnding = skipEnding;
    this.volumeAdaption = volumeAdaption;
    this.imageUrl = imageUrl;
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

  /** 是否需要在 load 前做移动流量确认（无本地文件且开启确认） */
  isStreaming(): boolean {
    return this.localFileUrl === '';
  }
}
