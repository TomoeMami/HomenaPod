// 输出设备变更（耳机拔出 / 蓝牙断开 / 重新接入）的播放策略 —— **纯逻辑，不依赖鸿蒙 SDK**，
// 因此可以在宿主侧用 Node 直接跑断言（scripts/runtime-pure-test.ps1）。
//
// 移植来源（Android 侧）：
//   1) `PlaybackService.BecomingNoisyReceiver` —— 收到系统广播 `ACTION_AUDIO_BECOMING_NOISY`
//      （耳机拔出 / 蓝牙断开）后暂停播放；
//   2) `UserPreferences.isPauseOnHeadsetDisconnect()` / `isUnpauseOnHeadsetReconnect()` /
//      `isUnpauseOnBluetoothReconnect()`（`preferences_playback.xml` 的 interruptions 分类）。
//
// 鸿蒙侧的对应机制：系统不广播、也不代应用暂停，而是通过 AVPlayer 的
// `audioOutputDeviceChangeWithInfo` 事件把「变更原因」交给应用。官方文档
// 《响应输出设备变更时合理暂停》(media/audio/audio-output-device-change.md) 明确：
//   REASON_OLD_DEVICE_UNAVAILABLE（普通蓝牙设备断开 / 佩戴检测摘下一侧或双侧 / 有线设备拔出 /
//   分布式设备下线）→ 「应用程序应考虑暂停音频播放」，且听书、音乐、视频场景的建议都是暂停。
//
// 本文件只回答三个问题：**该不该暂停**、**该不该恢复**、**这次下线的是不是蓝牙（要不要回退几秒）**；
// 枚举归一化与播放器控制留在 PlayerManager（那里才知道 audio.DeviceType /
// audio.AudioStreamDeviceChangeReason 的真实取值，也只有它能采样当前输出设备）。

/** 输出设备类别（由 PlayerManager 从 audio.DeviceType 归一化而来，见那里的一一对应注释） */
export class DeviceClasses {
  /** 有线耳机 / 耳麦 / USB 耳机：重连后按「耳机重连」偏好决定是否恢复 */
  static readonly WIRED: string = 'WIRED';
  /** 蓝牙（SCO / A2DP）：重连后按「蓝牙重连」偏好决定是否恢复 */
  static readonly BLUETOOTH: string = 'BLUETOOTH';
  /** 本机扬声器 / 听筒：不是耳机 */
  static readonly BUILT_IN: string = 'BUILT_IN';
  /** 其它输出（HDMI / 投屏 / 分布式 …）：既不是耳机，也不参与重连恢复 */
  static readonly OTHER: string = 'OTHER';
}

/** 设备变更原因（由 PlayerManager 从 audio.AudioStreamDeviceChangeReason 归一化而来） */
export class DeviceChangeReasons {
  /** 原输出设备不可用 = 耳机拔出 / 蓝牙断开 / 佩戴检测摘下 */
  static readonly LOST: string = 'LOST';
  /** 有新设备接入 */
  static readonly AVAILABLE: string = 'AVAILABLE';
  /** 用户在播控中心强制选择了输出设备 */
  static readonly OVERRODE: string = 'OVERRODE';
  /** 系统未给出原因 */
  static readonly UNKNOWN: string = 'UNKNOWN';
}

export class OutputDevicePolicy {
  /** 是不是「戴在耳朵上的设备」——只有这类设备下线才值得打断播放 */
  static isHeadset(cls: string): boolean {
    return cls === DeviceClasses.WIRED || cls === DeviceClasses.BLUETOOTH;
  }

  /** 是不是蓝牙设备（决定重连后读哪一条偏好） */
  static isBluetooth(cls: string): boolean {
    return cls === DeviceClasses.BLUETOOTH;
  }

  private static containsClass(classes: string[], cls: string): boolean {
    for (const item of classes) {
      if (item === cls) {
        return true;
      }
    }
    return false;
  }

  /**
   * 原输出设备不可用时是否要自动暂停。
   *
   * - `playing`：只有「用户本意是在播放」才需要暂停（对照 ExoPlayer 的 playWhenReady）。
   *   用户自己按过暂停、或播放已结束时不打扰。
   * - `pauseEnabled`：设置里的「耳机或蓝牙断开」开关（上游 prefPauseOnHeadsetDisconnect，默认开）。
   *
   * 不再判断掉线设备是不是耳机：`REASON_OLD_DEVICE_UNAVAILABLE` 已表示**本音频流**当时用的那路
   * 输出没了；走在扬声器上时耳机插拔根本不会改变本流的输出设备，也就不会收到这个事件。
   */
  static shouldPauseOnDeviceLost(playing: boolean, pauseEnabled: boolean): boolean {
    return playing && pauseEnabled;
  }

  /**
   * 设备丢失事件到达时，这次丢失是否打断了「用户本意要播」的播放。
   *
   * 不能只看 `playIntent`：耳机断开时系统常常**先**补发一条 `INTERRUPT_HINT_PAUSE`，
   * 那条路径已经调用过 `pause()`（`playIntent` 被清成 false）并把暂停原因记成 INTERRUPT；
   * 等设备变更事件到达时 `playIntent` 已是 false。此时若直接放行「不处理」，
   * 原因就停留在 INTERRUPT，随后焦点恢复的 `INTERRUPT_HINT_RESUME` 会照
   * `prefAutoResumeAfterInterrupt`（默认开）把声音从扬声器放出来 —— 正是本策略要防的事。
   *
   * 因此把「暂停原因已经是 INTERRUPT」也算作被打断的播放。两条回调的到达顺序不保证
   * （见 PlayerManager.handleAudioInterrupt 注释），两种顺序必须收敛到同一结果。
   *
   * `pausedByInterrupt` 为真而「本次丢失」确实已经不需要再动手暂停时，调用方仍应把原因改写成
   * DEVICE（见 `shouldPauseOnDeviceLost` 的用法）：这样焦点恢复不会越权续播，
   * 而设备重新接入仍能按重连偏好恢复。
   */
  static wasPlaybackInterrupted(playIntent: boolean, pausedByInterrupt: boolean): boolean {
    return playIntent || pausedByInterrupt;
  }

  /**
   * 新输出设备接入时是否要恢复播放。
   *
   * 只有「本次暂停确实是设备丢失造成的」（`pausedByDeviceLoss`）才谈得上自动恢复 ——
   * 用户手动暂停、睡眠定时器暂停、播放结束都不在此列。
   *
   * 恢复与否分设备类别取偏好（上游同款三条：
   * `prefUnpauseOnHeadsetReconnect` 默认开，`prefUnpauseOnBluetoothReconnect` 默认关）：
   * 插回有线耳机就接着放，蓝牙重连默认不动 —— 因为蓝牙可能在口袋里连上了却没人听。
   * 只接入了扬声器 / HDMI 等非耳机设备时一律不恢复。
   */
  static shouldResumeOnDeviceAvailable(addedClasses: string[], pausedByDeviceLoss: boolean,
                                       unpauseOnWired: boolean, unpauseOnBluetooth: boolean): boolean {
    if (!pausedByDeviceLoss) {
      return false;
    }
    for (const cls of addedClasses) {
      if (cls === DeviceClasses.WIRED && unpauseOnWired) {
        return true;
      }
      if (cls === DeviceClasses.BLUETOOTH && unpauseOnBluetooth) {
        return true;
      }
    }
    return false;
  }

  /**
   * 本次设备丢失事件里，下线的**是不是蓝牙设备** —— 「蓝牙断开后回退几秒」的判定入口
   * （移植版独有特性，上游没有；为什么只对蓝牙回退见 UserPreferences.isRewindOnBluetoothDisconnect）。
   *
   * 为什么不能直接读事件：`AudioStreamDeviceChangeInfo.devices` 是**变更之后**的设备列表
   * （SDK 原文「Audio device descriptors after change」），蓝牙断开时那里只剩扬声器，
   * 光看这一次事件答不出「下线的是什么设备」。所以调用方（PlayerManager）在**播放开始时**
   * 先采样一份「本流当时的输出设备」，并记住每次变更之后的设备列表；
   * 这里只回答一件事：上一次已知的设备里有蓝牙、而这次变更之后没有了 → 下线的就是蓝牙。
   *
   * 判定不出（历史为空、或变更后仍是蓝牙）时返回 false：宁可漏一次回退，
   * 也不要在拔有线耳机 / 切扬声器时莫名其妙回退几秒。
   */
  static isBluetoothLoss(previousClasses: string[], currentClasses: string[]): boolean {
    if (!OutputDevicePolicy.containsClass(previousClasses, DeviceClasses.BLUETOOTH)) {
      return false;
    }
    return !OutputDevicePolicy.containsClass(currentClasses, DeviceClasses.BLUETOOTH);
  }

  /**
   * 蓝牙断开造成的暂停之后要往回拉多少毫秒（0 = 不回退）。
   *
   * 三个条件缺一不可：确实下线的是蓝牙、用户开着这条偏好、秒数有效。
   */
  static rewindMillisOnBluetoothLoss(bluetoothLost: boolean, rewindEnabled: boolean, seconds: number): number {
    if (!bluetoothLost || !rewindEnabled || !Number.isFinite(seconds) || seconds <= 0) {
      return 0;
    }
    return Math.round(seconds * 1000);
  }

  /** 回退后的目标位置：不越过开头（回退量大于当前位置时落到 0） */
  static rewindPositionMs(positionMs: number, backMs: number): number {
    if (backMs <= 0) {
      return positionMs;
    }
    const target: number = positionMs - backMs;
    return target > 0 ? target : 0;
  }
}
