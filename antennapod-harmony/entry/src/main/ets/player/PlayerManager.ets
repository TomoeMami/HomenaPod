// Port of: playback/service/internal/{ExoPlayerWrapper,LocalPSMP}.java -> AVPlayer 封装
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import fs from '@ohos.file.fs';
import { Playable } from '../model/Playable';
import { UserPreferences } from '../prefs/UserPreferences';
import { Logger } from '../utils/Logger';
import { BackgroundPlaybackGuard } from './BackgroundPlaybackGuard';
import { DeviceClasses, DeviceChangeReasons, OutputDevicePolicy } from './OutputDevicePolicy';
import { EventHub, EventType, PlaybackPositionData, PlayerErrorData, SpeedChangedData, PlayerStatusData, PlayerTrackData } from '../events/EventHub';

const TAG: string = 'PlayerManager';

export class PlayerStatus {
  static readonly IDLE: string = 'IDLE';
  static readonly INITIALIZING: string = 'INITIALIZING';
  static readonly PREPARING: string = 'PREPARING';
  static readonly PREPARED: string = 'PREPARED';
  static readonly PLAYING: string = 'PLAYING';
  static readonly PAUSED: string = 'PAUSED';
  static readonly COMPLETED: string = 'COMPLETED';
  static readonly ERROR: string = 'ERROR';
}

/** 自动回退阈值（上游：暂停 >1 分钟回退 3s、>1 小时 10s、>1 天 20s，不可配置） */
const REWIND_MINUTE_MS: number = 60 * 1000;
const REWIND_HOUR_MS: number = 60 * 60 * 1000;
const REWIND_DAY_MS: number = 24 * 60 * 60 * 1000;

/**
 * 最近一次「系统侧」暂停的原因。它决定**什么事件**可以把播放重新拉起来：
 * 只有音频焦点恢复走 prefAutoResumeAfterInterrupt，只有设备重连走
 * prefUnpauseOnHeadsetReconnect / prefUnpauseOnBluetoothReconnect；
 * 用户手动暂停（含睡眠定时器、播控中心暂停）不在此列。
 */
const PAUSE_CAUSE_NONE: string = 'NONE';
/** 音频焦点被抢占（来电 / 其它应用开始播放） */
const PAUSE_CAUSE_INTERRUPT: string = 'INTERRUPT';
/** 输出设备丢失（耳机拔出 / 蓝牙断开 / 佩戴检测摘下） */
const PAUSE_CAUSE_DEVICE: string = 'DEVICE';

export class PlayerManager {
  private static player: media.AVPlayer | undefined = undefined;
  private static current: Playable | undefined = undefined;
  private static status: string = PlayerStatus.IDLE;
  private static speed: number = 1.0;
  private static volume: number = 1.0;
  private static pausedAt: number = 0;
  private static skipEndingFired: boolean = false;
  /**
   * 播放意图（对照 ExoPlayer 的 playWhenReady）：true = 用户本意是在播放。
   *
   * 耳机拔出时**底层可能已经自行停顿**（状态先变成 paused，`stateChange` 早于设备变更回调到达），
   * 只看 `status` 就会把「本该恢复」误判成「用户自己停的」，所以意图单独记一份。
   */
  private static playIntent: boolean = false;
  /** 最近一次系统侧暂停的原因（PAUSE_CAUSE_*） */
  private static pauseCause: string = PAUSE_CAUSE_NONE;
  /** 本地文件播放时保持打开的 fd（AVPlayer 走 fdSrc，播放期间不能关闭） */
  private static localFile: fs.File | undefined = undefined;

  /** API 12 可用的倍速档位（3.0x 需 API 13，未纳入） */
  static readonly SPEED_PRESETS: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  private static boundStateChange: (state: media.AVPlayerState, reason: media.StateChangeReason) => void =
    (state: media.AVPlayerState, reason: media.StateChangeReason): void => {
      PlayerManager.handleStateChange(state, reason);
    };
  private static boundTimeUpdate: (time: number) => void = (time: number): void => {
    PlayerManager.handleTimeUpdate(time);
  };
  private static boundError: (error: Error) => void = (error: Error): void => {
    Logger.error(TAG, 'AVPlayer error', error);
    PlayerManager.status = PlayerStatus.ERROR;
    PlayerManager.stopBackgroundTask();
    const errorData: PlayerErrorData = { code: 0, message: error.message };
    EventHub.publish(EventType.PLAYER_ERROR, errorData);
  };
  private static boundInterrupt: (info: audio.InterruptEvent) => void =
    (info: audio.InterruptEvent): void => {
      PlayerManager.handleAudioInterrupt(info);
    };
  private static boundOutputDeviceChange: (info: audio.AudioStreamDeviceChangeInfo) => void =
    (info: audio.AudioStreamDeviceChangeInfo): void => {
      PlayerManager.handleOutputDeviceChange(info);
    };

  static async load(playable: Playable, startPosition: number, autoplay: boolean): Promise<void> {
    await PlayerManager.release();
    PlayerManager.current = playable;
    PlayerManager.status = PlayerStatus.INITIALIZING;
    PlayerManager.skipEndingFired = false;
    PlayerManager.pausedAt = 0;
    PlayerManager.playIntent = false;
    PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
    // 通知播控中心换集（AVSession 元数据必须在 prepare 前就更新，否则通知栏卡片还是上一集）
    const trackData: PlayerTrackData = { assetId: playable.id };
    EventHub.publish(EventType.PLAYER_TRACK_CHANGED, trackData);
    const player: media.AVPlayer = await media.createAVPlayer();
    PlayerManager.player = player;
    player.on('timeUpdate', PlayerManager.boundTimeUpdate);
    player.on('error', PlayerManager.boundError);
    player.on('audioInterrupt', PlayerManager.boundInterrupt);
    // 输出设备变更（耳机拔出 / 蓝牙断开 / 重新接入）：官方指引要求
    // REASON_OLD_DEVICE_UNAVAILABLE 时由应用自己暂停 —— 见 OutputDevicePolicy 注释
    player.on('audioOutputDeviceChangeWithInfo', PlayerManager.boundOutputDeviceChange);
    if (playable.localFileUrl !== '') {
      // 已下载：AVPlayer 只接受 fd:// 或网络地址（file:// 与裸路径都会报
      // "The input parameter is not fd:// or network address"），故走 fdSrc。
      const file: fs.File = fs.openSync(playable.localFileUrl, fs.OpenMode.READ_ONLY);
      PlayerManager.localFile = file;
      player.fdSrc = { fd: file.fd };
    } else {
      player.url = playable.downloadUrl;
    }
    const initialized: boolean = await PlayerManager.waitForState(player, 'initialized', 30000);
    if (!initialized) {
      throw new Error('AVPlayer url 初始化超时: ' + playable.getSourceUrl());
    }
    PlayerManager.status = PlayerStatus.PREPARING;
    await player.prepare();
    PlayerManager.status = PlayerStatus.PREPARED;
    // 在 waitForState 之后再注册全局状态监听：
    // waitForState 内部会 off('stateChange', handler)，若提前注册会被一并移除，
    // 导致 status 永远停留在 PREPARED。
    player.on('stateChange', PlayerManager.boundStateChange);
    // 每 Feed 音量适配（0=未设置；AVPlayer 无 >1.0 增益，增强档 clamp 到 1.0）
    if (playable.volumeAdaption > 0) {
      PlayerManager.setVolume(playable.volumeAdaption);
    } else {
      PlayerManager.setVolume(1.0);
    }
    let target: number = startPosition > 0 ? startPosition : 0;
    // 跳片头：起始位置仍在片头区间内则直接跳到片头结束
    if (playable.skipIntro > 0) {
      const introMs: number = playable.skipIntro * 1000;
      if (target < introMs) {
        target = introMs;
        Logger.info(TAG, 'skip intro -> ' + introMs);
      }
    }
    if (target > 0) {
      PlayerManager.seek(target);
    }
    if (playable.speed > 0 && playable.speed !== 1.0) {
      PlayerManager.setSpeed(playable.speed);
    } else {
      // 无 Feed 级倍速时用用户默认倍速：否则播放页设过的倍速会在下次 prepare（如单集循环）被打回 1.0
      PlayerManager.setSpeed(UserPreferences.getDefaultPlaybackSpeed());
    }
    if (autoplay) {
      PlayerManager.play();
    }
  }

  private static waitForState(player: media.AVPlayer, target: media.AVPlayerState, timeoutMs: number): Promise<boolean> {
    if (player.state === target) {
      return new Promise<boolean>((resolve) => resolve(true));
    }
    return new Promise<boolean>((resolve) => {
      let settled: boolean = false;
      let timerId: number = -1;
      const handler = (state: media.AVPlayerState, reason: media.StateChangeReason): void => {
        if (state === target) {
          if (!settled) {
            settled = true;
            player.off('stateChange', handler);
            clearTimeout(timerId);
            resolve(true);
          }
        } else if (state === 'error') {
          if (!settled) {
            settled = true;
            player.off('stateChange', handler);
            clearTimeout(timerId);
            resolve(false);
          }
        }
      };
      player.on('stateChange', handler);
      timerId = setTimeout(() => {
        if (!settled) {
          settled = true;
          player.off('stateChange', handler);
          resolve(false);
        }
      }, timeoutMs);
    });
  }

  static async play(): Promise<void> {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player !== undefined && (player.state === 'prepared' || player.state === 'paused' || player.state === 'completed')) {
      PlayerManager.applyAutoRewind();
      // 主动播放：意图置真，并清掉上一次系统侧暂停的原因（用户接管了播放）
      PlayerManager.playIntent = true;
      PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
      await player.play();
      // 长时任务必须在真正开始播放后启动：否则后台/锁屏会被系统冻结
      PlayerManager.startBackgroundTask();
    }
  }

  /** 启动 AUDIO_PLAYBACK 长时任务（幂等；失败不阻断播放） */
  private static startBackgroundTask(): void {
    if (BackgroundPlaybackGuard.isRunning()) {
      return;
    }
    BackgroundPlaybackGuard.start().catch((error: Error) => {
      Logger.warn(TAG, 'startBackgroundRunning failed: ' + error.message);
    });
  }

  /** 停止长时任务（释放播放器 / 播放错误时调用） */
  private static stopBackgroundTask(): void {
    if (!BackgroundPlaybackGuard.isRunning()) {
      return;
    }
    BackgroundPlaybackGuard.stop().catch((error: Error) => {
      Logger.warn(TAG, 'stopBackgroundRunning failed: ' + error.message);
    });
  }

  /** 暂停后回退：暂停 >1 分钟 3s、>1 小时 10s、>1 天 20s */
  private static applyAutoRewind(): void {
    if (PlayerManager.pausedAt <= 0) {
      return;
    }
    const pausedMs: number = Date.now() - PlayerManager.pausedAt;
    PlayerManager.pausedAt = 0;
    let backMs: number = 0;
    if (pausedMs > REWIND_DAY_MS) {
      backMs = 20000;
    } else if (pausedMs > REWIND_HOUR_MS) {
      backMs = 10000;
    } else if (pausedMs > REWIND_MINUTE_MS) {
      backMs = 3000;
    }
    if (backMs > 0) {
      const target: number = Math.max(0, PlayerManager.getCurrentTime() - backMs);
      Logger.info(TAG, 'auto rewind ' + backMs + 'ms after pause ' + pausedMs + 'ms');
      PlayerManager.seek(target);
    }
  }

  static async pause(): Promise<void> {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    // 不管底层停没停，意图都要清掉：这是一次「用户/系统要求静音」的暂停
    PlayerManager.playIntent = false;
    if (player !== undefined && player.state === 'playing') {
      PlayerManager.pausedAt = Date.now();
      await player.pause();
    }
  }

  /**
   * 设备丢失（耳机拔出 / 蓝牙断开）造成的停顿。
   *
   * 与 `pause()` 的区别：底层可能**已经**因设备下线自行停顿（这时 `player.pause()` 是空操作、
   * `stateChange` 也不会再来），所以这里额外把应用侧状态与播控中心显式收敛成 PAUSED，
   * 避免播放页 / 通知卡片停在「播放中」；同时保留 `pauseCause = DEVICE`，
   * 让设备重新接入时能按偏好恢复。
   */
  private static async pauseForDeviceLoss(): Promise<void> {
    PlayerManager.playIntent = false;
    PlayerManager.pausedAt = Date.now();
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player !== undefined && (player.state === 'playing' || player.state === 'prepared')) {
      try {
        await player.pause();
      } catch (error) {
        Logger.warn(TAG, 'pause on device loss failed: ' + (error as Error).message);
      }
    }
    if (PlayerManager.status === PlayerStatus.PLAYING || PlayerManager.status === PlayerStatus.PREPARED) {
      PlayerManager.status = PlayerStatus.PAUSED;
      const statusData: PlayerStatusData = { status: PlayerManager.status };
      EventHub.publish(EventType.PLAYER_STATUS, statusData);
    }
  }

  static seek(timeMs: number): void {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player !== undefined) {
      player.seek(timeMs, media.SeekMode.SEEK_PREV_SYNC);
    }
  }

  static seekBy(deltaMs: number): void {
    const current: number = PlayerManager.getCurrentTime();
    const target: number = Math.max(0, current + deltaMs);
    PlayerManager.seek(target);
  }

  static setSpeed(speed: number): void {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player === undefined) {
      return;
    }
    player.setSpeed(PlayerManager.toPlaybackSpeed(speed));
    PlayerManager.speed = speed;
    const speedData: SpeedChangedData = { speed: speed };
    EventHub.publish(EventType.SPEED_CHANGED, speedData);
  }

  /** 倍速档位映射（API 12 能力集；非档位值就近取档） */
  static toPlaybackSpeed(speed: number): media.PlaybackSpeed {
    if (speed <= 0.5) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_50_X;
    }
    if (speed <= 0.75) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    }
    if (speed <= 1.0) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    }
    if (speed <= 1.25) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    }
    if (speed <= 1.5) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    }
    if (speed <= 1.75) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    }
    return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
  }

  /** 音量适配：AVPlayer 仅支持 0..1，超过 1 的增强请求被 clamp 并记录 */
  static setVolume(volume: number): void {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player === undefined) {
      return;
    }
    let value: number = volume;
    if (value > 1.0) {
      Logger.info(TAG, 'volume adaption ' + volume + ' clamped to 1.0 (AVPlayer 无增益能力)');
      value = 1.0;
    }
    if (value < 0) {
      value = 0;
    }
    PlayerManager.volume = value;
    try {
      player.setVolume(value);
    } catch (error) {
      Logger.warn(TAG, 'setVolume failed: ' + (error as Error).message);
    }
  }

  static getVolume(): number {
    return PlayerManager.volume;
  }

  static getCurrentTime(): number {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player === undefined) {
      return 0;
    }
    return player.currentTime;
  }

  static getDuration(): number {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player === undefined) {
      return 0;
    }
    const duration: number = player.duration;
    return duration > 0 ? duration : (PlayerManager.current !== undefined ? PlayerManager.current.duration : 0);
  }

  static getStatus(): string {
    return PlayerManager.status;
  }

  static getCurrent(): Playable | undefined {
    return PlayerManager.current;
  }

  static getSpeed(): number {
    return PlayerManager.speed;
  }

  static async release(): Promise<void> {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player !== undefined) {
      player.off('stateChange');
      player.off('timeUpdate');
      player.off('error');
      player.off('audioInterrupt');
      player.off('audioOutputDeviceChangeWithInfo');
      await player.release();
    }
    PlayerManager.player = undefined;
    if (PlayerManager.localFile !== undefined) {
      // 必须在 player.release() 之后再关闭 fd
      try {
        fs.closeSync(PlayerManager.localFile);
      } catch (error) {
        // 已关闭则忽略
      }
      PlayerManager.localFile = undefined;
    }
    PlayerManager.status = PlayerStatus.IDLE;
    PlayerManager.skipEndingFired = false;
    PlayerManager.playIntent = false;
    PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
    PlayerManager.stopBackgroundTask();
    const idleStatus: PlayerStatusData = { status: PlayerManager.status };
    EventHub.publish(EventType.PLAYER_STATUS, idleStatus);
  }

  private static handleTimeUpdate(time: number): void {
    const positionData: PlaybackPositionData = { time: time, duration: PlayerManager.getDuration() };
    EventHub.publish(EventType.PLAYBACK_POSITION, positionData);
    PlayerManager.maybeSkipEnding(time);
  }

  /** 跳片尾：接近结尾时跳到底，由系统走 completed 流程（每集只触发一次） */
  private static maybeSkipEnding(time: number): void {
    const playable: Playable | undefined = PlayerManager.current;
    if (playable === undefined || playable.skipEnding <= 0 || PlayerManager.skipEndingFired) {
      return;
    }
    const duration: number = PlayerManager.getDuration();
    if (duration <= 0) {
      return;
    }
    if (duration - time <= playable.skipEnding * 1000) {
      PlayerManager.skipEndingFired = true;
      Logger.info(TAG, 'skip ending -> ' + duration);
      PlayerManager.seek(duration);
    }
  }

  /**
   * 音频焦点中断（来电、其他应用抢占、部分场景下的耳机断开）：
   * 系统强制暂停时记录原因；恢复提示时按 prefAutoResumeAfterInterrupt 自动继续播放。
   *
   * 注意与 {@link handleOutputDeviceChange} 的配合：耳机断开时系统**可能同时**发这条 PAUSE
   * 中断，而两个回调的先后顺序不保证。设备丢失已经把原因记成 DEVICE 时不再改写，
   * 否则之后蓝牙重连会走 `INTERRUPT_HINT_RESUME` 这条「焦点恢复」路径，
   * 绕过「蓝牙重连默认不恢复」的偏好（默认值见 UserPreferences.isUnpauseOnBluetoothReconnect）。
   */
  private static handleAudioInterrupt(info: audio.InterruptEvent): void {
    Logger.info(TAG, 'audioInterrupt hint=' + info.hintType + ' force=' + info.forceType);
    if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE
      || info.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
      // 只在「本来就在播」且不是设备丢失时，才记成一条「焦点恢复后可自动续播」的暂停：
      // 用户自己按过暂停、或播放已结束时系统同样会发这条中断，此时不该在来电结束后把声音放出来
      //（对照上游 PlaybackService：pausedBecauseOfFocusLoss 只在 isPlaying() 时置真）。
      if (PlayerManager.playIntent && PlayerManager.pauseCause !== PAUSE_CAUSE_DEVICE) {
        PlayerManager.pauseCause = PAUSE_CAUSE_INTERRUPT;
      }
      PlayerManager.pausedAt = Date.now();
      PlayerManager.pause();
    } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
      if (PlayerManager.pauseCause === PAUSE_CAUSE_INTERRUPT && UserPreferences.getAutoResumeAfterInterrupt()) {
        PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
        PlayerManager.play();
      }
    } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_DUCK) {
      PlayerManager.setVolume(0.3);
    } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_UNDUCK) {
      const playable: Playable | undefined = PlayerManager.current;
      PlayerManager.setVolume(playable !== undefined && playable.volumeAdaption > 0 ? playable.volumeAdaption : 1.0);
    }
  }

  /**
   * 输出设备变更：**耳机拔出 / 蓝牙断开时自动暂停播放**的主路径。
   *
   * 为什么不能只靠 `audioInterrupt`：官方《响应输出设备变更时合理暂停》把设备下线的处理
   * 交给应用自己 —— 系统只把「本音频流的输出设备变了、以及为什么变」通过
   * `audioOutputDeviceChangeWithInfo` 交给应用，并不会代应用暂停；只有这条事件
   * 才带得回 **是哪一类设备**（有线 / 蓝牙）下线或接入，从而决定重连后走哪条偏好。
   *
   * 对照上游：`PlaybackService.BecomingNoisyReceiver`（ACTION_AUDIO_BECOMING_NOISY → 暂停）
   * + `prefUnpauseOnHeadsetReconnect` / `prefUnpauseOnBluetoothReconnect`（重连恢复）。
   */
  private static handleOutputDeviceChange(info: audio.AudioStreamDeviceChangeInfo): void {
    if (info === undefined) {
      return;
    }
    const reason: string = PlayerManager.toDeviceChangeReason(info.changeReason);
    const classes: string[] = PlayerManager.toDeviceClasses(info.devices);
    Logger.info(TAG, 'outputDeviceChange reason=' + reason + ' devices=[' + classes.join(',') + ']'
      + ' status=' + PlayerManager.status + ' intent=' + PlayerManager.playIntent
      + ' cause=' + PlayerManager.pauseCause);

    if (reason === DeviceChangeReasons.LOST) {
      const pauseEnabled: boolean = UserPreferences.isPauseOnHeadsetDisconnect();
      // 顺序无关：设备事件与焦点中断谁先到，结论都必须一样。
      // 焦点中断先到时 pause() 已把 playIntent 清成 false，只看它就会漏掉本次设备丢失，
      // 让原因停在 INTERRUPT —— 之后焦点恢复会把声音从扬声器放出来。
      const interrupted: boolean = OutputDevicePolicy.wasPlaybackInterrupted(
        PlayerManager.playIntent, PlayerManager.pauseCause === PAUSE_CAUSE_INTERRUPT);
      if (!OutputDevicePolicy.shouldPauseOnDeviceLost(interrupted, pauseEnabled)) {
        Logger.info(TAG, 'device lost: no pause (intent=' + PlayerManager.playIntent + ' enabled=' + pauseEnabled + ')');
        return;
      }
      PlayerManager.pauseCause = PAUSE_CAUSE_DEVICE;
      PlayerManager.pauseForDeviceLoss().catch((error: Error) => {
        Logger.warn(TAG, 'pauseForDeviceLoss failed: ' + error.message);
      });
      return;
    }

    if (reason === DeviceChangeReasons.AVAILABLE) {
      const resume: boolean = OutputDevicePolicy.shouldResumeOnDeviceAvailable(
        classes, PlayerManager.pauseCause === PAUSE_CAUSE_DEVICE,
        UserPreferences.isUnpauseOnHeadsetReconnect(), UserPreferences.isUnpauseOnBluetoothReconnect());
      if (resume) {
        Logger.info(TAG, 'device available: resume playback');
        // 先清原因再播：play() 若因底层状态不可播而空转，也不该把这个「恢复机会」留给下一次插拔
        PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
        PlayerManager.play();
      }
      return;
    }

    if (reason === DeviceChangeReasons.OVERRODE) {
      // 用户在播控中心强选了输出设备：既不算设备丢失，也不该保留「等重连恢复」的意图
      PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
    }
  }

  /** audio.AudioStreamDeviceChangeReason -> 策略层的抽象原因（见 OutputDevicePolicy） */
  private static toDeviceChangeReason(reason: audio.AudioStreamDeviceChangeReason): string {
    if (reason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
      return DeviceChangeReasons.LOST;
    }
    if (reason === audio.AudioStreamDeviceChangeReason.REASON_NEW_DEVICE_AVAILABLE) {
      return DeviceChangeReasons.AVAILABLE;
    }
    if (reason === audio.AudioStreamDeviceChangeReason.REASON_OVERRODE) {
      return DeviceChangeReasons.OVERRODE;
    }
    return DeviceChangeReasons.UNKNOWN;
  }

  /**
   * audio.DeviceType -> 策略层的设备类别。
   *
   * 只映射本工程最低兼容版本就存在的取值（compatibleSdkVersion = 5.0.2(14)）：
   * 助听器（HEARING_AID）/ NearLink（NEARLINK）是 API 26 才加入的枚举，
   * 这里落到 OTHER —— 它们同样会触发设备丢失暂停（暂停只看原因），只是重连后不走「蓝牙重连」偏好。
   */
  private static toDeviceClasses(devices: audio.AudioDeviceDescriptors): string[] {
    const classes: string[] = [];
    if (devices === undefined) {
      return classes;
    }
    for (const device of devices) {
      classes.push(PlayerManager.toDeviceClass(device.deviceType));
    }
    return classes;
  }

  private static toDeviceClass(deviceType: audio.DeviceType): string {
    if (deviceType === audio.DeviceType.WIRED_HEADSET
      || deviceType === audio.DeviceType.WIRED_HEADPHONES
      || deviceType === audio.DeviceType.USB_HEADSET) {
      return DeviceClasses.WIRED;
    }
    if (deviceType === audio.DeviceType.BLUETOOTH_SCO
      || deviceType === audio.DeviceType.BLUETOOTH_A2DP) {
      return DeviceClasses.BLUETOOTH;
    }
    if (deviceType === audio.DeviceType.SPEAKER || deviceType === audio.DeviceType.EARPIECE) {
      return DeviceClasses.BUILT_IN;
    }
    return DeviceClasses.OTHER;
  }

  private static handleStateChange(state: media.AVPlayerState, reason: media.StateChangeReason): void {
    Logger.info(TAG, 'stateChange -> ' + state + ' reason=' + reason);
    if (state === 'playing') {
      PlayerManager.status = PlayerStatus.PLAYING;
      PlayerManager.pausedAt = 0;
    } else if (state === 'paused') {
      PlayerManager.status = PlayerStatus.PAUSED;
    } else if (state === 'prepared') {
      PlayerManager.status = PlayerStatus.PREPARED;
    } else if (state === 'completed') {
      PlayerManager.status = PlayerStatus.COMPLETED;
      // 播完不再有「稍后恢复」的语义：清掉意图与暂停原因，避免换集后误恢复
      PlayerManager.playIntent = false;
      PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
    } else if (state === 'released') {
      PlayerManager.status = PlayerStatus.IDLE;
    } else if (state === 'error') {
      PlayerManager.status = PlayerStatus.ERROR;
      PlayerManager.playIntent = false;
      PlayerManager.pauseCause = PAUSE_CAUSE_NONE;
    }
    const statusData: PlayerStatusData = { status: PlayerManager.status };
    EventHub.publish(EventType.PLAYER_STATUS, statusData);
  }
}
