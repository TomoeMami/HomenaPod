// Port of: playback/service/internal/{ExoPlayerWrapper,LocalPSMP}.java -> AVPlayer 封装
import { media } from '@kit.MediaKit';
import { Playable } from '../model/Playable';
import { Logger } from '../utils/Logger';
import { EventHub, EventType } from '../events/EventHub';

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

export class PlayerManager {
  private static player: media.AVPlayer | undefined = undefined;
  private static current: Playable | undefined = undefined;
  private static status: string = PlayerStatus.IDLE;
  private static speed: number = 1.0;
  private static boundStateChange: (state: media.AVPlayerState, reason: media.StateChangeReason) => void =
    (state: media.AVPlayerState, reason: media.StateChangeReason): void => {
      PlayerManager.handleStateChange(state, reason);
    };
  private static boundTimeUpdate: (time: number) => void = (time: number): void => {
    EventHub.publish(EventType.PLAYBACK_POSITION, { time: time, duration: PlayerManager.getDuration() });
  };
  private static boundError: (error: Error) => void = (error: Error): void => {
    Logger.error(TAG, 'AVPlayer error', error);
    PlayerManager.status = PlayerStatus.ERROR;
    EventHub.publish(EventType.PLAYER_ERROR, { code: 0, message: error.message });
  };

  static async load(playable: Playable, startPosition: number, autoplay: boolean): Promise<void> {
    await PlayerManager.release();
    PlayerManager.current = playable;
    PlayerManager.status = PlayerStatus.INITIALIZING;
    const player: media.AVPlayer = await media.createAVPlayer();
    PlayerManager.player = player;
    player.on('stateChange', PlayerManager.boundStateChange);
    player.on('timeUpdate', PlayerManager.boundTimeUpdate);
    player.on('error', PlayerManager.boundError);
    player.url = playable.getSourceUrl();
    PlayerManager.status = PlayerStatus.PREPARING;
    await player.prepare();
    PlayerManager.status = PlayerStatus.PREPARED;
    if (startPosition > 0) {
      PlayerManager.seek(startPosition);
    }
    if (autoplay) {
      PlayerManager.play();
    }
  }

  static async play(): Promise<void> {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player !== undefined && (player.state === 'prepared' || player.state === 'paused' || player.state === 'completed')) {
      await player.play();
    }
  }

  static async pause(): Promise<void> {
    const player: media.AVPlayer | undefined = PlayerManager.player;
    if (player !== undefined && player.state === 'playing') {
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
    let playbackSpeed: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    if (speed <= 0.75) {
      playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    } else if (speed <= 1.0) {
      playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    } else if (speed <= 1.25) {
      playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    } else if (speed <= 1.4) {
      playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    } else if (speed <= 1.6) {
      playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    } else if (speed <= 1.75) {
      playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    } else {
      playbackSpeed = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
    player.setSpeed(playbackSpeed);
    PlayerManager.speed = speed;
    EventHub.publish(EventType.SPEED_CHANGED, { speed: speed });
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
      await player.release();
    }
    PlayerManager.player = undefined;
    PlayerManager.status = PlayerStatus.IDLE;
    EventHub.publish(EventType.PLAYER_STATUS, { status: PlayerManager.status });
  }

  private static handleStateChange(state: media.AVPlayerState, reason: media.StateChangeReason): void {
    Logger.info(TAG, 'stateChange -> ' + state + ' reason=' + reason);
    if (state === 'playing') {
      PlayerManager.status = PlayerStatus.PLAYING;
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
    EventHub.publish(EventType.PLAYER_STATUS, { status: PlayerManager.status });
  }
}
