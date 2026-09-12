// 摇一摇检测：睡眠定时器活跃时重置倒计时（对应上游 SleepTimer 的 shake to reset）
import sensor from '@ohos.sensor';
import { Logger } from '../utils/Logger';

const TAG: string = 'ShakeDetector';
/** 加速度模长阈值（m/s²），超过视为摇动 */
const SHAKE_THRESHOLD: number = 25;
/** 两次触发的最小间隔，避免连续触发 */
const MIN_INTERVAL_MS: number = 2000;

export class ShakeDetector {
  private static listening: boolean = false;
  private static lastTriggeredAt: number = 0;
  private static onShake: (() => void) | undefined = undefined;

  static start(onShake: () => void): void {
    ShakeDetector.onShake = onShake;
    if (ShakeDetector.listening) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        ShakeDetector.handle(data);
      }, { interval: 200000000 });
      ShakeDetector.listening = true;
    } catch (error) {
      Logger.warn(TAG, 'accelerometer unavailable: ' + (error as Error).message);
    }
  }

  static stop(): void {
    ShakeDetector.onShake = undefined;
    if (!ShakeDetector.listening) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (error) {
      Logger.warn(TAG, 'off failed: ' + (error as Error).message);
    }
    ShakeDetector.listening = false;
  }

  static isListening(): boolean {
    return ShakeDetector.listening;
  }

  private static handle(data: sensor.AccelerometerResponse): void {
    const magnitude: number = Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
    if (magnitude < SHAKE_THRESHOLD) {
      return;
    }
    const now: number = Date.now();
    if (now - ShakeDetector.lastTriggeredAt < MIN_INTERVAL_MS) {
      return;
    }
    ShakeDetector.lastTriggeredAt = now;
    if (ShakeDetector.onShake !== undefined) {
      ShakeDetector.onShake();
    }
  }
}
