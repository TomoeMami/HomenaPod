// Port of: playback/service/internal/MediaLibrarySessionCallback.java + PlaybackServiceNotificationBuilder.java
import { avSession } from '@kit.AVSessionKit';
import common from '@ohos.app.ability.common';
import { Playable } from '../model/Playable';
import { PlayerManager } from './PlayerManager';
import { Logger } from '../utils/Logger';

const TAG: string = 'AvSessionBridge';

export class AvSessionBridge {
  private static session: avSession.AVSession | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    if (AvSessionBridge.session !== undefined) {
      return;
    }
    const session: avSession.AVSession = await avSession.createAVSession(context, 'AntennaPod', 'audio');
    AvSessionBridge.session = session;
    await session.activate();
    session.on('play', () => {
      PlayerManager.play();
    });
    session.on('pause', () => {
      PlayerManager.pause();
    });
    session.on('seek', (time: number) => {
      PlayerManager.seek(time);
    });
    session.on('setSpeed', (speed: number) => {
      PlayerManager.setSpeed(speed);
    });
    session.on('playNext', () => {
      Logger.info(TAG, 'playNext requested by controller');
    });
    session.on('playPrevious', () => {
      Logger.info(TAG, 'playPrevious requested by controller');
    });
  }

  static async updateMetadata(playable: Playable): Promise<void> {
    const session: avSession.AVSession | undefined = AvSessionBridge.session;
    if (session === undefined) {
      return;
    }
    const metadata: avSession.AVMetadata = {
      assetId: String(playable.id),
      title: playable.title,
      artist: playable.feedTitle,
      album: playable.feedTitle,
      duration: playable.duration,
      subtitle: playable.feedTitle,
      description: playable.feedTitle
    };
    await session.setAVMetadata(metadata);
  }

  static async updatePlaybackState(state: string, position: number, speed: number): Promise<void> {
    const session: avSession.AVSession | undefined = AvSessionBridge.session;
    if (session === undefined) {
      return;
    }
    let playbackState: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    if (state === 'PLAYING') {
      playbackState = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    } else if (state === 'COMPLETED') {
      playbackState = avSession.PlaybackState.PLAYBACK_STATE_COMPLETED;
    }
    const stateObj: avSession.AVPlaybackState = {
      state: playbackState,
      speed: speed,
      position: { elapsedTime: position, updateTime: Date.now() },
      bufferedTime: 0,
      loopMode: avSession.LoopMode.LOOP_MODE_SEQUENCE,
      isFavorite: false
    };
    await session.setAVPlaybackState(stateObj);
  }

  static async release(): Promise<void> {
    const session: avSession.AVSession | undefined = AvSessionBridge.session;
    if (session !== undefined) {
      await session.deactivate();
      await session.destroy();
    }
    AvSessionBridge.session = undefined;
  }
}
