// Port of: system 模块日志策略（上游普通日志使用 android.util.Log）
import { hilog } from '@kit.PerformanceAnalysisKit';

export class Logger {
  private static readonly DOMAIN: number = 0x0000;
  private static readonly PREFIX: string = 'APod/';

  static debug(tag: string, message: string): void {
    hilog.debug(Logger.DOMAIN, Logger.PREFIX + tag, '%{public}s', message);
  }

  static info(tag: string, message: string): void {
    hilog.info(Logger.DOMAIN, Logger.PREFIX + tag, '%{public}s', message);
  }

  static warn(tag: string, message: string): void {
    hilog.warn(Logger.DOMAIN, Logger.PREFIX + tag, '%{public}s', message);
  }

  static error(tag: string, message: string, err?: Error): void {
    if (err !== undefined) {
      hilog.error(Logger.DOMAIN, Logger.PREFIX + tag, '%{public}s: %{public}s', message, err.message);
    } else {
      hilog.error(Logger.DOMAIN, Logger.PREFIX + tag, '%{public}s', message);
    }
  }
}
