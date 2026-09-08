// Port of: parser/feed/util/DateUtils.java
export class DateUtils {
  static parseToEpochMillis(value: string): number {
    if (value === null || value === undefined) {
      return 0;
    }
    const trimmed: string = value.trim();
    if (trimmed === '') {
      return 0;
    }
    const parsed: number = Date.parse(trimmed);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
    // RFC822 without timezone fallback: "Wed, 02 Oct 2002 13:00:00"
    const normalized: string = trimmed.replace(/^[A-Za-z]{3},\s*/, '');
    const parsed2: number = Date.parse(normalized + ' GMT');
    if (Number.isFinite(parsed2)) {
      return parsed2;
    }
    return 0;
  }

  static formatRelative(epochMillis: number, nowMillis: number): string {
    const diffSeconds: number = Math.floor((nowMillis - epochMillis) / 1000);
    if (diffSeconds < 60) {
      return '刚刚';
    }
    if (diffSeconds < 3600) {
      return Math.floor(diffSeconds / 60) + ' 分钟前';
    }
    if (diffSeconds < 86400) {
      return Math.floor(diffSeconds / 3600) + ' 小时前';
    }
    if (diffSeconds < 86400 * 7) {
      return Math.floor(diffSeconds / 86400) + ' 天前';
    }
    const d: Date = new Date(epochMillis);
    return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
  }
}
