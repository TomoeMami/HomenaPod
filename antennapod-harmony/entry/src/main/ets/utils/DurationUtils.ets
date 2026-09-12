// Port of: parser/feed/util/DurationParser.java
export class DurationUtils {
  /** 毫秒 -> 时长文本（H:MM:SS 或 M:SS），用于列表展示 */
  static format(ms: number): string {
    if (ms === undefined || ms === null || ms <= 0 || !Number.isFinite(ms)) {
      return '';
    }
    const totalSeconds: number = Math.floor(ms / 1000);
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const seconds: number = totalSeconds % 60;
    const pad = (value: number): string => value < 10 ? '0' + value : value.toString();
    if (hours > 0) {
      return hours + ':' + pad(minutes) + ':' + pad(seconds);
    }
    return minutes + ':' + pad(seconds);
  }

  static parseToMillis(value: string): number {
    if (value === null || value === undefined) {
      return 0;
    }
    const trimmed: string = value.trim();
    if (trimmed === '') {
      return 0;
    }
    if (trimmed.startsWith('P') || trimmed.startsWith('p')) {
      return DurationUtils.parseIso8601(trimmed);
    }
    if (trimmed.indexOf(':') >= 0) {
      return DurationUtils.parseClock(trimmed);
    }
    const seconds: number = Number(trimmed);
    if (!Number.isFinite(seconds)) {
      return 0;
    }
    return Math.round(seconds * 1000);
  }

  private static parseClock(value: string): number {
    const parts: string[] = value.split(':');
    let hours: number = 0;
    let minutes: number = 0;
    let seconds: number = 0;
    if (parts.length === 3) {
      hours = Number(parts[0]);
      minutes = Number(parts[1]);
      seconds = Number(parts[2]);
    } else if (parts.length === 2) {
      minutes = Number(parts[0]);
      seconds = Number(parts[1]);
    } else {
      return 0;
    }
    if (!Number.isFinite(hours) || !Number.isFinite(minutes) || !Number.isFinite(seconds)) {
      return 0;
    }
    return Math.round((hours * 3600 + minutes * 60 + seconds) * 1000);
  }

  private static parseIso8601(value: string): number {
    let ms: number = 0;
    const pattern: RegExp = /^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/i;
    const match: RegExpMatchArray | null = value.match(pattern);
    if (match === null) {
      return 0;
    }
    const days: number = match[1] !== undefined ? Number(match[1]) : 0;
    const hours: number = match[2] !== undefined ? Number(match[2]) : 0;
    const minutes: number = match[3] !== undefined ? Number(match[3]) : 0;
    const seconds: number = match[4] !== undefined ? Number(match[4]) : 0;
    ms += days * 86400000;
    ms += hours * 3600000;
    ms += minutes * 60000;
    ms += seconds * 1000;
    return ms;
  }
}
