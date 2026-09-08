// Port of: parser/feed/util/MimeTypeUtils.java + TypeGetter.java
import { MediaType } from '../model/Enums';

export class MimeTypeUtils {
  static mediaTypeFromMime(mimeType: string): MediaType {
    if (mimeType === null || mimeType === undefined) {
      return MediaType.UNKNOWN;
    }
    if (mimeType.indexOf('video') >= 0) {
      return MediaType.VIDEO;
    }
    if (mimeType.indexOf('audio') >= 0) {
      return MediaType.AUDIO;
    }
    return MediaType.UNKNOWN;
  }

  static guessExtension(url: string, mimeType: string): string {
    if (mimeType !== '') {
      if (mimeType.indexOf('mp4') >= 0 || mimeType.indexOf('m4a') >= 0 || mimeType.indexOf('mp4a') >= 0) {
        return '.m4a';
      }
      if (mimeType.indexOf('mp3') >= 0) {
        return '.mp3';
      }
      if (mimeType.indexOf('ogg') >= 0) {
        return '.ogg';
      }
      if (mimeType.indexOf('wav') >= 0) {
        return '.wav';
      }
      if (mimeType.indexOf('mpeg') >= 0) {
        return '.mp3';
      }
      if (mimeType.indexOf('aac') >= 0) {
        return '.aac';
      }
    }
    const lower: string = url.toLowerCase();
    const dotIndex: number = lower.lastIndexOf('.');
    if (dotIndex >= 0 && lower.length - dotIndex <= 6) {
      return lower.substring(dotIndex);
    }
    return '.mp3';
  }

  static guessMimeType(url: string, declared: string): string {
    if (declared !== '') {
      return declared;
    }
    const lower: string = url.toLowerCase();
    const queryIndex: number = lower.indexOf('?');
    const clean: string = queryIndex >= 0 ? lower.substring(0, queryIndex) : lower;
    const dotIndex: number = clean.lastIndexOf('.');
    if (dotIndex < 0) {
      return declared;
    }
    const ext: string = clean.substring(dotIndex + 1);
    if (ext === 'mp3') {
      return 'audio/mpeg';
    }
    if (ext === 'mp4' || ext === 'm4v') {
      return 'video/mp4';
    }
    if (ext === 'm4a' || ext === 'm4b' || ext === 'mp4a') {
      return 'audio/mp4';
    }
    if (ext === 'ogg' || ext === 'oga') {
      return 'audio/ogg';
    }
    if (ext === 'wav') {
      return 'audio/wav';
    }
    if (ext === 'aac' || ext === 'm4r') {
      return 'audio/aac';
    }
    if (ext === 'flac') {
      return 'audio/flac';
    }
    if (ext === 'opus') {
      return 'audio/opus';
    }
    if (ext === 'webm') {
      return 'audio/webm';
    }
    return declared;
  }
}
