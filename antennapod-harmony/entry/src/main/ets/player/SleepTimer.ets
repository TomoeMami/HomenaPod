// Port of: playback/service/internal/{SleepTimer,EpisodeSleepTimer,ClockSleepTimer}.java
import vibrator from '@ohos.vibrator';
import { EventHub, EventType, SleepTimerData } from '../events/EventHub';
import { Logger } from '../utils/Logger';

const TAG: string = 'SleepTimer';
/** 渐弱音量窗口：最后 30 秒 */
const FADE_WINDOW_MS: number = 30000;

export class SleepTimer {
  private static timerId: number = -1;
  private static remainingMs: number = 0;
  private static durationMs: number = 0;
  private static stopAtChapterEnd: boolean = false;
  private static fadeOut: boolean = false;
  private static pendingChapterEnd: boolean = false;
  private static onExpire: (() => void) | undefined = undefined;
  private static fadeHandler: ((volume: number) => void) | undefined = undefined;

  /**
   * 启动睡眠定时器。
   * @param minutes 时长（分钟）
   * @param onExpire 到点回调（通常是暂停播放）
   * @param stopAtChapterEnd 到点时若仍在章节中，等章节结束再暂停（由页面轮询判定）
   * @param fadeOut 最后 30 秒渐弱音量（通过 setFadeHandler 注入的音量回调实现）
   */
  static start(minutes: number, onExpire: () => void, stopAtChapterEnd: boolean = false,
               fadeOut: boolean = false): void {
    SleepTimer.stop();
    SleepTimer.onExpire = onExpire;
    SleepTimer.stopAtChapterEnd = stopAtChapterEnd;
    SleepTimer.fadeOut = fadeOut;
    SleepTimer.remainingMs = minutes * 60 * 1000;
    SleepTimer.durationMs = SleepTimer.remainingMs;
    SleepTimer.pendingChapterEnd = false;
    const deadline: number = Date.now() + SleepTimer.remainingMs;
    SleepTimer.timerId = setInterval(() => {
      SleepTimer.remainingMs = deadline - Date.now();
      if (SleepTimer.remainingMs <= 0) {
        if (SleepTimer.stopAtChapterEnd) {
          // 交给页面轮询在章节边界触发 expireNow()；先停掉 interval，避免空转
          SleepTimer.remainingMs = 0;
          SleepTimer.pendingChapterEnd = true;
          SleepTimer.clearIntervalOnly();
          SleepTimer.publishTick();
          return;
        }
        SleepTimer.fire();
        return;
      }
      SleepTimer.applyFade();
      SleepTimer.publishTick();
    }, 1000);
    SleepTimer.publishTick();
  }

  /** 到点执行：恢复音量 + 震动 + 回调，然后清理 */
  static fire(): void {
    const callback: (() => void) | undefined = SleepTimer.onExpire;
    SleepTimer.clearTimer();
    SleepTimer.restoreVolume();
    SleepTimer.vibrate();
    if (callback !== undefined) {
      callback();
    }
    SleepTimer.publishTick();
  }

  /** 章节末触发（页面判定章节边界后调用） */
  static expireNow(): void {
    SleepTimer.fire();
  }

  static stop(): void {
    SleepTimer.clearTimer();
    SleepTimer.restoreVolume();
    SleepTimer.publishTick();
  }

  /** 是否在等待章节结束（计时已到但尚未暂停） */
  static isPendingChapterEnd(): boolean {
    return SleepTimer.pendingChapterEnd;
  }

  static isActive(): boolean {
    return SleepTimer.timerId >= 0 || SleepTimer.remainingMs > 0 || SleepTimer.pendingChapterEnd;
  }

  static getRemainingMs(): number {
    return SleepTimer.remainingMs;
  }

  static getStopAtChapterEnd(): boolean {
    return SleepTimer.stopAtChapterEnd;
  }

  static getFadeOut(): boolean {
    return SleepTimer.fadeOut;
  }

  static setFadeHandler(handler: (volume: number) => void): void {
    SleepTimer.fadeHandler = handler;
  }

  private static clearTimer(): void {
    SleepTimer.clearIntervalOnly();
    SleepTimer.remainingMs = 0;
    SleepTimer.durationMs = 0;
    SleepTimer.stopAtChapterEnd = false;
    SleepTimer.fadeOut = false;
    SleepTimer.pendingChapterEnd = false;
  }

  private static clearIntervalOnly(): void {
    if (SleepTimer.timerId >= 0) {
      clearInterval(SleepTimer.timerId);
      SleepTimer.timerId = -1;
    }
  }

  private static applyFade(): void {
    if (!SleepTimer.fadeOut || SleepTimer.fadeHandler === undefined || SleepTimer.remainingMs > FADE_WINDOW_MS) {
      return;
    }
    const ratio: number = Math.max(0.05, SleepTimer.remainingMs / FADE_WINDOW_MS);
    SleepTimer.fadeHandler(ratio);
  }

  private static restoreVolume(): void {
    if (SleepTimer.fadeHandler !== undefined) {
      SleepTimer.fadeHandler(1.0);
    }
  }

  private static vibrate(): void {
    try {
      const effect: vibrator.VibrateTime = { type: 'time', duration: 300 };
      const attribute: vibrator.VibrateAttribute = { id: 0, usage: 'alarm' };
      vibrator.startVibration(effect, attribute).catch((error: Error) => {
        Logger.warn(TAG, 'vibrate failed: ' + error.message);
      });
    } catch (error) {
      Logger.warn(TAG, 'vibrate unavailable: ' + (error as Error).message);
    }
  }

  private static publishTick(): void {
    const data: SleepTimerData = { remainingMs: SleepTimer.remainingMs };
    EventHub.publish(EventType.SLEEP_TIMER_UPDATED, data);
  }
}
