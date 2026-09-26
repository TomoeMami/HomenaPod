// 纯逻辑：播控中心/系统下发的倍速要不要接受（不 import 任何 @kit.*，可进 scripts/runtime-pure-test.ps1）
//
// 背景：官方文档写明 `AVSession.on('setSpeed')` 的回调参数是**倍率数值**
//（"The setSpeed command must carry a number parameter"），但实际链路上出现过
// 0 / 负数 / 参数缺失（undefined）/ 以及按 `media.PlaybackSpeed` 枚举值下发的写法。
// 而 `PlayerManager.toPlaybackSpeed()` 用 `<=` 分档，**任何 ≤0.5 的输入都会落到 0.5x** ——
// 用户侧看到的就是「自己变成慢速播放」。所以这里先卡一道：不是有限数值、或不在应用支持的
// 档位区间内的，一律不接受（调用方记日志并忽略）。
export class PlaybackSpeedPolicy {
  /**
   * 该倍速是否可以下发到播放器。
   *
   * @param speed 系统下发的原始倍率
   * @param min 应用支持的最小档位（PlayerManager.SPEED_PRESETS[0]）
   * @param max 应用支持的最大档位（PlayerManager.SPEED_PRESETS[last]）
   */
  static isAcceptable(speed: number, min: number, max: number): boolean {
    if (!Number.isFinite(speed)) {
      return false;
    }
    if (!Number.isFinite(min) || !Number.isFinite(max) || min > max) {
      return false;
    }
    return speed >= min && speed <= max;
  }

  /** 拒绝原因（仅用于日志归因，不做判定；可接受时返回空串） */
  static rejectReason(speed: number, min: number, max: number): string {
    if (!Number.isFinite(speed)) {
      return 'not-a-finite-number';
    }
    if (speed < min) {
      return 'below-min(' + min + ')';
    }
    if (speed > max) {
      return 'above-max(' + max + ')';
    }
    return '';
  }
}
