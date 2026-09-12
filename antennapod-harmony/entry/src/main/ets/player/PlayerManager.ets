// Port of: playback/service/internal/{ExoPlayerWrapper,LocalPSMP}.java -> AVPlayer 封装
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import fs from '@ohos.file.fs';
import { Playable } from '../model/Playable';
import { UserPreferences } from '../prefs/UserPreferences';
import { Logger } from '../utils/Logger';
import { BackgroundPlaybackGuard } from './BackgroundPlaybackGuard';
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

export class PlayerManager {
  private static player: media.AVPlayer | undefined = undefined;
  private static current: Playable | undefined = undefined;
  private static status: string = PlayerStatus.IDLE;
  private static speed: number = 1.0;
  private static volume: number = 1.0;
  private static pausedAt: number = 0;
  private static skipEndingFired: boolean = false;
  private static interruptPaused: boolean = false;
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

  static async load(playable: Playable, startPosition: number, autoplay: boolean): Promise<void> {
    await PlayerManager.release();
    PlayerManager.current = playable;
    PlayerManager.status = PlayerStatus.INITIALIZING;
    PlayerManager.skipEndingFired = false;
    PlayerManager.pausedAt = 0;
    PlayerManager.interruptPaused = false;
    // 通知播控中心换集（AVSession 元数据必须在 prepare 前就更新，否则通知栏卡片还是上一集）
    const trackData: PlayerTrackData = { assetId: playable.id };
    EventHub.publish(EventType.PLAYER_TRACK_CHANGED, trackData);
    const player: media.AVPlayer = await media.createAVPlayer();
    PlayerManager.player = player;
    player.on('timeUpdate', PlayerManager.boundTimeUpdate);
    player.on('error', PlayerManager.boundError);
    player.on('audioInterrupt', PlayerManager.boundInterrupt);
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
    if (player !== undefined && player.state === 'playing') {
      PlayerManager.pausedAt = Date.now();
      await player.pause();
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
    PlayerManager.interruptPaused = false;
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
   * 音频焦点中断（耳机/蓝牙断开、其他应用抢占）：
   * 系统强制暂停时记录状态；恢复提示时按用户偏好自动继续播放。
   */
  private static handleAudioInterrupt(info: audio.InterruptEvent): void {
    Logger.info(TAG, 'audioInterrupt hint=' + info.hintType + ' force=' + info.forceType);
    if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE
      || info.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
      PlayerManager.interruptPaused = true;
      PlayerManager.pausedAt = Date.now();
      PlayerManager.pause();
    } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
      if (PlayerManager.interruptPaused && UserPreferences.getAutoResumeAfterInterrupt()) {
        PlayerManager.interruptPaused = false;
        PlayerManager.play();
      }
    } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_DUCK) {
      PlayerManager.setVolume(0.3);
    } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_UNDUCK) {
      const playable: Playable | undefined = PlayerManager.current;
      PlayerManager.setVolume(playable !== undefined && playable.volumeAdaption > 0 ? playable.volumeAdaption : 1.0);
    }
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
    } else if (state === 'released') {
      PlayerManager.status = PlayerStatus.IDLE;
    } else if (state === 'error') {
      PlayerManager.status = PlayerStatus.ERROR;
    }
    const statusData: PlayerStatusData = { status: PlayerManager.status };
    EventHub.publish(EventType.PLAYER_STATUS, statusData);
  }
}
