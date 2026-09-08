// Port of: ui/glide 图片加载 + 磁盘缓存（替换 Glide）
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { HttpClient } from '../net/HttpClient';
import { Logger } from '../utils/Logger';

const TAG: string = 'ImageCache';
const MAX_CACHE_MB: number = 50;

export class ImageCache {
  static async getImage(url: string, context: common.Context): Promise<string> {
    if (url === '') {
      return '';
    }
    const fileName: string = ImageCache.hash(url) + '.img';
    const dir: string = context.filesDir + '/image_cache';
    if (!ImageCache.exists(dir)) {
      fs.mkdirSync(dir);
    }
    const filePath: string = dir + '/' + fileName;
    if (ImageCache.exists(filePath)) {
      return filePath;
    }
    try {
      const bytes: ArrayBuffer = await HttpClient.getBytes(url);
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, bytes);
      fs.closeSync(file.fd);
      ImageCache.cleanupIfNeeded(context);
      return 'file://' + filePath;
    } catch (error) {
      Logger.warn(TAG, 'download image failed: ' + (error as Error).message);
      return '';
    }
  }

  static clearCache(context: common.Context): void {
    const dir: string = context.filesDir + '/image_cache';
    if (ImageCache.exists(dir)) {
      fs.rmdirSync(dir);
    }
  }

  static cacheSizeMb(context: common.Context): number {
    const dir: string = context.filesDir + '/image_cache';
    if (!ImageCache.exists(dir)) {
      return 0;
    }
    const files = fs.listFileSync(dir);
    let size = 0;
    for (const name of files) {
      try {
        const stat = fs.statSync(dir + '/' + name);
        size += stat.size;
      } catch (error) {
        // ignore
      }
    }
    return Math.round(size / 1024 / 1024);
  }

  private static cleanupIfNeeded(context: common.Context): void {
    if (ImageCache.cacheSizeMb(context) > MAX_CACHE_MB) {
      const dir: string = context.filesDir + '/image_cache';
      const files = fs.listFileSync(dir);
      for (const name of files) {
        try {
          fs.unlinkSync(dir + '/' + name);
        } catch (error) {
          // ignore
        }
      }
    }
  }

  private static exists(path: string): boolean {
    try {
      fs.statSync(path);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static hash(value: string): string {
    let h: number = 0;
    for (let i: number = 0; i < value.length; i++) {
      h = ((h << 5) - h + value.charCodeAt(i)) | 0;
    }
    return String(h >>> 0);
  }
}
