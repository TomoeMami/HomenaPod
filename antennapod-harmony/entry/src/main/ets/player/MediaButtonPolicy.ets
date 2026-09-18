// 蓝牙耳机「下一首 / 上一首」按键的重映射 —— **纯逻辑，不依赖鸿蒙 SDK**，
// 因此可以在宿主侧用 Node 直接跑断言（scripts/runtime-pure-test.ps1）。
//
// 移植来源（Android 侧 `PlaybackService.handleKeycode`）：
//   case KeyEvent.KEYCODE_MEDIA_NEXT:
//       if (!notificationButton) return handleKeycode(UserPreferences.getHardwareForwardButton(), true);
//   case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
//       if (!notificationButton) return handleKeycode(UserPreferences.getHardwarePreviousButton(), true);
// 两个「硬件按键」偏好的默认值就是 KEYCODE_MEDIA_FAST_FORWARD / KEYCODE_MEDIA_REWIND
// （UserPreferences.getHardwareForwardButton / getHardwarePreviousButton），也就是说：
//   **耳机上的「下一首」= 快进，耳机上的「上一首」= 快退**；
// 而通知卡片上的同名按钮（notificationButton = true）保持「切下一集 / 回到开头」。
//
// 鸿蒙侧没有 keycode，但 AVSession 从 API 22 起在命令回调里带回 `CommandInfo.callerType`：
// `TYPE_BLUETOOTH` 表示这条命令来自蓝牙设备，于是同一套重映射可以照搬（见 AvSessionBridge）。
//
// 两处边界（本工程在上游语义上补的，见 docs/feature-diff/02-playback-audio.md）：
//   - **结尾前 10 秒内**按「下一首」：快进已经快到头了，这时按用户的本意就是「这一集听完了」，
//     直接切下一集；
//   - **开头 2 秒内**按「上一首」：快退同样退无可退，走原本的「上一首」语义（回到开头）。
//
// 本文件只回答「这条命令该做什么」，播放器控制与秒数取值留在 AvSessionBridge / PlayerManager。

/** 播控命令（与 AVSession 的 'playNext' / 'playPrevious' 一一对应） */
export class MediaButtonCommands {
  static readonly NEXT: string = 'NEXT';
  static readonly PREVIOUS: string = 'PREVIOUS';
}

/** 命令要执行的动作 */
export class MediaButtonActions {
  /** 快进（秒数取设置里的快进时长，默认 30s） */
  static readonly SEEK_FORWARD: string = 'SEEK_FORWARD';
  /** 快退（秒数取设置里的快退时长，默认 10s） */
  static readonly SEEK_BACK: string = 'SEEK_BACK';
  /** 切下一集（队列中的下一项） */
  static readonly NEXT_EPISODE: string = 'NEXT_EPISODE';
  /** 回到开头（上游 skipToPrevious 的 restart 语义 / 卡片「上一首」的既有行为） */
  static readonly RESTART: string = 'RESTART';
}

export class MediaButtonPolicy {
  /** 结尾前 10 秒内的「下一首」不再快进，按下一集处理 */
  static readonly NEXT_EPISODE_WINDOW_MS: number = 10000;
  /** 开头 2 秒内的「上一首」仍是「回到开头」，不快退 */
  static readonly RESTART_WINDOW_MS: number = 2000;

  /**
   * 决定一条「下一首 / 上一首」命令该做什么。
   *
   * @param command  MediaButtonCommands.NEXT / PREVIOUS
   * @param fromBluetooth 命令来自蓝牙设备（CommandInfo.callerType === TYPE_BLUETOOTH）
   * @param positionMs 当前位置
   * @param durationMs 总时长（未知时为 0，例如还没 prepare）
   *
   * 非蓝牙来源（播控中心卡片、锁屏、车机、其它应用）一律保持改造前的语义。
   */
  static resolve(command: string, fromBluetooth: boolean, positionMs: number, durationMs: number): string {
    if (command === MediaButtonCommands.NEXT) {
      if (fromBluetooth && !MediaButtonPolicy.isNearEnd(positionMs, durationMs)) {
        return MediaButtonActions.SEEK_FORWARD;
      }
      return MediaButtonActions.NEXT_EPISODE;
    }
    if (fromBluetooth && positionMs > MediaButtonPolicy.RESTART_WINDOW_MS) {
      return MediaButtonActions.SEEK_BACK;
    }
    return MediaButtonActions.RESTART;
  }

  /** 是否已经进入「结尾前 10 秒」；时长未知时一律按「不在结尾」处理（快进由播放器自行 clamp） */
  static isNearEnd(positionMs: number, durationMs: number): boolean {
    return durationMs > 0 && durationMs - positionMs <= MediaButtonPolicy.NEXT_EPISODE_WINDOW_MS;
  }
}
