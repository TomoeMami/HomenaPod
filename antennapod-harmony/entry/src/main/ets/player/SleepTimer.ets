// Port of: playback/service/internal/{SleepTimer,EpisodeSleepTimer,ClockSleepTimer}.java
import { EventHub, EventType, SleepTimerData } from '../events/EventHub';

export class SleepTimer {
  private static timerId: number = -1;
  private static remainingMs: number = 0;
  private static onExpire: (() => void) | undefined = undefined;

  static start(minutes: number, onExpire: () => void): void {
    SleepTimer.stop();
    SleepTimer.onExpire = onExpire;
    SleepTimer.remainingMs = minutes * 60 * 1000;
    const deadline: number = Date.now() + SleepTimer.remainingMs;
    SleepTimer.timerId = setInterval(() => {
      SleepTimer.remainingMs = deadline - Date.now();
      if (SleepTimer.remainingMs <= 0) {
        SleepTimer.stop();
        if (SleepTimer.onExpire !== undefined) {
          SleepTimer.onExpire();
        }
        return;
      }
      const tickData: SleepTimerData = { remainingMs: SleepTimer.remainingMs };
      EventHub.publish(EventType.SLEEP_TIMER_UPDATED, tickData);
    }, 1000);
    const startData: SleepTimerData = { remainingMs: SleepTimer.remainingMs };
    EventHub.publish(EventType.SLEEP_TIMER_UPDATED, startData);
  }

  static stop(): void {
    if (SleepTimer.timerId >= 0) {
      clearInterval(SleepTimer.timerId);
      SleepTimer.timerId = -1;
    }
    SleepTimer.remainingMs = 0;
  }

  static getRemainingMs(): number {
    return SleepTimer.remainingMs;
  }

  static isActive(): boolean {
    return SleepTimer.timerId >= 0;
  }
}
