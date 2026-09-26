// Port of: playback/service/internal/MediaLibrarySessionCallback.java + PlaybackServiceNotificationBuilder.java
//
// 通知栏/锁屏的「音频控件」是系统自带的播控中心卡片（不是应用自绘通知），接入条件
// （官方 FAQ faqs-avsession-24 + 开发指南 using-avsession-developer）：
//   1) createAVSession(context, tag, 'audio') 并 activate()；
//   2) 必须 setAVMetadata()（否则卡片不显示，只是空会话）；
//   3) 至少注册一个**真实执行**的播控命令（空实现会被系统当成有效命令，按钮点了没反应）。
// 播放状态（播放/暂停/进度/倍速/循环）通过 setAVPlaybackState() 上报，暂停后卡片依然保留。
//
// 实测坑（HarmonyOS 6.0 / API 26 模拟器）：setAVPlaybackState 的 duration 传 0 会被原生
// 校验判为 ERR_INVALID_PARAM（"native invalid parameters"），因此 duration 只在 > 0 时上报。
import { avSession } from '@kit.AVSessionKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import common from '@ohos.app.ability.common';
import { Playable } from '../model/Playable';
import { FeedItem } from '../model/FeedItem';
import { PlayerManager, PlayerStatus } from './PlayerManager';
import { QueueEngine } from './QueueEngine';
import { MediaButtonActions, MediaButtonCommands, MediaButtonPolicy } from './MediaButtonPolicy';
import { PlaybackSpeedPolicy } from './PlaybackSpeedPolicy';
import { EpisodeRepository } from '../db/repositories/EpisodeRepository';
import { FavoritesRepository } from '../db/repositories/FavoritesRepository';
import { UserPreferences } from '../prefs/UserPreferences';
import { EventHub, EventType } from '../events/EventHub';
import { ImageCache } from '../services/ImageCache';
import { Logger } from '../utils/Logger';

const TAG: string = 'AvSessionBridge';
/** 与 AppScope/app.json5 保持一致 */
const BUNDLE_NAME: string = 'com.homenapod.app';
const ABILITY_NAME: string = 'EntryAbility';
/** 进度上报节流（ms）：系统按 position.updateTime 自行推进进度，无需每次 timeUpdate 都上报 */
const POSITION_REPORT_INTERVAL_MS: number = 1000;
/** 播控卡封面解码后的最长边（px）：原图常见 1400px+，缩小后再交给播控中心，卡片刷新更快 */
const COVER_MAX_EDGE_PX: number = 512;
/** 重复模式取值（与 UserPreferences.getRepeatMode 约定一致） */
const REPEAT_OFF: number = 0;
const REPEAT_ONE: number = 1;
const REPEAT_ALL: number = 2;

export class AvSessionBridge {
  private static session: avSession.AVSession | undefined = undefined;
  /** 已上报的 Playable.id，用于判断是否换集 */
  private static assetId: number = -1;
  private static favorite: boolean = false;
  private static lastPositionReportAt: number = 0;
  /** 应用上下文（解码封面图用，init 时保存） */
  private static context: common.Context | undefined = undefined;
  /**
   * 已解码的封面（单条缓存）。PixelMap 内存占用大，只保留当前这一集；
   * 换集后旧对象失去引用，由 GC 回收。
   */
  private static coverUrl: string = '';
  private static cover: image.PixelMap | undefined = undefined;
  /** 已经上报过封面的 Playable.id（避免同一集被重复解码 / 重复上报） */
  private static coverAssetId: number = -1;
  /** 状态上报串行化：底层接口的返回值是共享的，并发调用会互相串扰出假失败 */
  private static reporting: boolean = false;
  private static pendingState: avSession.AVPlaybackState | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    if (AvSessionBridge.session !== undefined) {
      return;
    }
    AvSessionBridge.context = context;
    try {
      const session: avSession.AVSession = await avSession.createAVSession(context, 'HomenaPod', 'audio');
      AvSessionBridge.session = session;
      await AvSessionBridge.bindLaunchAbility();
      AvSessionBridge.registerCommands(session);
      await session.activate();
      AvSessionBridge.subscribePlayerEvents();
      // onWindowStageCreate 是异步的，init 可能晚于第一次播放：补齐当前播放信息
      await AvSessionBridge.syncCurrent();
      Logger.info(TAG, 'avsession ready');
    } catch (error) {
      Logger.error(TAG, 'init failed', new Error((error as Error).message));
    }
  }

  /** 点击播控中心卡片进入应用 */
  private static async bindLaunchAbility(): Promise<void> {
    const session: avSession.AVSession | undefined = AvSessionBridge.session;
    if (session === undefined) {
      return;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      await session.setLaunchAbility(agent);
    } catch (error) {
      Logger.warn(TAG, 'setLaunchAbility failed: ' + (error as Error).message);
    }
  }

  /** 播控命令：只注册真正实现的能力，避免卡片出现点了没反应的按钮 */
  private static registerCommands(session: avSession.AVSession): void {
    session.on('play', (): void => {
      PlayerManager.play();
    });
    session.on('pause', (): void => {
      PlayerManager.pause();
    });
    session.on('stop', (): void => {
      PlayerManager.pause();
    });
    AvSessionBridge.registerSkipCommands(session);
    session.on('fastForward', (time?: number): void => {
      AvSessionBridge.skipBy(true, time);
    });
    session.on('rewind', (time?: number): void => {
      AvSessionBridge.skipBy(false, time);
    });
    session.on('seek', (time: number): void => {
      PlayerManager.seek(time);
    });
    session.on('setSpeed', (speed: number): void => {
      AvSessionBridge.applySystemSpeed(speed);
    });
    session.on('setLoopMode', (mode: avSession.LoopMode): void => {
      AvSessionBridge.applyLoopMode(mode);
    });
    session.on('toggleFavorite', (assetId: string): void => {
      AvSessionBridge.toggleFavorite(assetId).catch((error: Error) => {
        Logger.warn(TAG, 'toggleFavorite failed: ' + error.message);
      });
    });
  }

  /**
   * 注册「下一首 / 上一首」命令。
   *
   * 蓝牙耳机的按键重映射（下一首 = 快进、上一首 = 快退，见 MediaButtonPolicy）需要知道
   * **命令来源**：`onPlayNext` / `onPlayPrevious`（API 22+）会把 `CommandInfo` 一并带回，
   * 其中 `callerType === TYPE_BLUETOOTH` 即「这条命令来自蓝牙设备」。
   *
   * 低于 API 22 的设备没有这组回调，调用会抛错：这时回落到原来的
   * `on('playNext')` / `on('playPrevious')`，行为与改造前完全一致（蓝牙按键不重映射）。
   * 注意每条命令只能注册一个回调（新的会替换旧的），所以两条路径必须二选一。
   */
  private static registerSkipCommands(session: avSession.AVSession): void {
    try {
      session.onPlayNext((info: avSession.CommandInfo): void => {
        AvSessionBridge.handleSkipCommand(MediaButtonCommands.NEXT, info);
      });
      session.onPlayPrevious((info: avSession.CommandInfo): void => {
        AvSessionBridge.handleSkipCommand(MediaButtonCommands.PREVIOUS, info);
      });
      Logger.info(TAG, 'skip commands registered with CommandInfo (bluetooth remap active)');
    } catch (error) {
      Logger.warn(TAG, 'onPlayNext/onPlayPrevious unavailable, falling back: ' + (error as Error).message);
      session.on('playNext', (): void => {
        AvSessionBridge.skipToNextEpisode();
      });
      session.on('playPrevious', (): void => {
        AvSessionBridge.restartEpisode();
      });
    }
  }

  /** 按 MediaButtonPolicy 的判定执行一条「下一首 / 上一首」命令 */
  private static handleSkipCommand(command: string, info: avSession.CommandInfo | undefined): void {
    const caller: string = AvSessionBridge.callerTypeName(info);
    const fromBluetooth: boolean = caller === avSession.CallerType.TYPE_BLUETOOTH;
    const position: number = PlayerManager.getCurrentTime();
    const duration: number = PlayerManager.getDuration();
    const action: string = MediaButtonPolicy.resolve(command, fromBluetooth, position, duration);
    // 判定依据全部打出来（来源 + 位置 + 时长）：真机上排查「蓝牙按键为什么没走进快进/快退」全靠这一行
    Logger.info(TAG, command + ' callerType=' + (caller !== '' ? caller : 'unknown')
      + ' fromBluetooth=' + fromBluetooth + ' position=' + position + ' duration=' + duration
      + ' -> ' + action);
    if (action === MediaButtonActions.SEEK_FORWARD) {
      AvSessionBridge.skipBy(true);
    } else if (action === MediaButtonActions.SEEK_BACK) {
      AvSessionBridge.skipBy(false);
    } else if (action === MediaButtonActions.NEXT_EPISODE) {
      AvSessionBridge.skipToNextEpisode();
    } else {
      AvSessionBridge.restartEpisode();
    }
  }

  /** 命令来源（CallerType 是字符串枚举，可直接当字符串比较/打印）；未知时返回空串 */
  private static callerTypeName(info: avSession.CommandInfo | undefined): string {
    if (info === undefined || info.callerType === undefined) {
      return '';
    }
    return info.callerType;
  }

  private static skipToNextEpisode(): void {
    QueueEngine.autoAdvance().catch((error: Error) => {
      Logger.warn(TAG, 'playNext failed: ' + error.message);
    });
  }

  /** 播客没有「上一集」历史栈：重播当前单集（与上游 skipToPrevious 的 restart 语义一致） */
  private static restartEpisode(): void {
    PlayerManager.seek(0);
  }

  /** 快进/快退：系统给了跳过时长就用它，否则用用户在设置里的快进/快退秒数 */
  private static skipBy(forward: boolean, time?: number): void {
    const prefMs: number = (forward ? UserPreferences.getFastForwardSecs() : UserPreferences.getRewindSecs()) * 1000;
    const delta: number = time !== undefined && time > 0 ? time : prefMs;
    PlayerManager.seekBy(forward ? delta : -delta);
  }

  /**
   * 系统播控下发的倍速（官方：`setSpeed` 指令携带 number 参数）。
   *
   * **必须先校验再下发**：`PlayerManager.toPlaybackSpeed()` 用 `<=` 分档，任何 ≤0.5 的输入
   * （0、负数、参数缺失变 undefined、或系统按 `media.PlaybackSpeed` 枚举值下发时的 0=0.75x）
   * 都会静默落到 **0.5x** —— 用户侧看到的就是「自己变成慢速播放」。越界一律忽略并留日志，
   * 归一化交给 `setSpeed` 的就近取档。
   */
  private static applySystemSpeed(speed: number): void {
    const min: number = PlayerManager.SPEED_PRESETS[0];
    const max: number = PlayerManager.SPEED_PRESETS[PlayerManager.SPEED_PRESETS.length - 1];
    if (!PlaybackSpeedPolicy.isAcceptable(speed, min, max)) {
      Logger.warn(TAG, 'avsession setSpeed ignored: ' + speed
        + ' (' + PlaybackSpeedPolicy.rejectReason(speed, min, max) + ')');
      return;
    }
    Logger.info(TAG, 'avsession setSpeed ' + speed);
    PlayerManager.setSpeed(speed, 'avsession');
  }

  private static applyLoopMode(mode: avSession.LoopMode): void {
    if (mode === avSession.LoopMode.LOOP_MODE_SINGLE) {
      UserPreferences.setRepeatMode(REPEAT_ONE);
    } else if (mode === avSession.LoopMode.LOOP_MODE_LIST) {
      UserPreferences.setRepeatMode(REPEAT_ALL);
    } else if (mode === avSession.LoopMode.LOOP_MODE_SEQUENCE) {
      UserPreferences.setRepeatMode(REPEAT_OFF);
    } else {
      // 播客无随机播放语义：保持当前模式，下面的状态回报会把真实模式纠正回卡片
      Logger.info(TAG, 'unsupported loop mode ' + mode);
    }
    AvSessionBridge.reportState(PlayerManager.getStatus(), PlayerManager.getCurrentTime());
  }

  private static async toggleFavorite(assetId: string): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable === undefined || playable.feedItemId <= 0) {
      return;
    }
    const item: FeedItem | undefined = await EpisodeRepository.getById(playable.feedItemId);
    if (item === undefined) {
      return;
    }
    const favorite: boolean = await FavoritesRepository.isFavorite(item.id);
    if (favorite) {
      await FavoritesRepository.remove(item.id);
    } else {
      await FavoritesRepository.add(item.id, item.feedId);
    }
    AvSessionBridge.favorite = !favorite;
    Logger.info(TAG, 'toggleFavorite assetId=' + assetId + ' -> ' + AvSessionBridge.favorite);
    AvSessionBridge.reportState(PlayerManager.getStatus(), PlayerManager.getCurrentTime());
  }

  private static subscribePlayerEvents(): void {
    EventHub.subscribe(EventType.PLAYER_TRACK_CHANGED, (data: object) => {
      AvSessionBridge.onTrackChanged();
    });
    EventHub.subscribe(EventType.PLAYER_STATUS, (data: object) => {
      const record: Record<string, string> = data as Record<string, string>;
      const status: string | undefined = record['status'];
      AvSessionBridge.onStatusChanged(status !== undefined ? status : PlayerManager.getStatus());
    });
    EventHub.subscribe(EventType.PLAYBACK_POSITION, (data: object) => {
      AvSessionBridge.onPosition();
    });
    EventHub.subscribe(EventType.SPEED_CHANGED, (data: object) => {
      AvSessionBridge.reportState(PlayerManager.getStatus(), PlayerManager.getCurrentTime());
    });
  }

  /** 换集：立刻更新元数据（标题/时长），并刷新收藏态 */
  private static onTrackChanged(): void {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable === undefined) {
      return;
    }
    AvSessionBridge.assetId = playable.id;
    AvSessionBridge.favorite = false;
    AvSessionBridge.applyMetadata(playable);
    AvSessionBridge.refreshFavorite(playable);
    AvSessionBridge.reportState(PlayerStatus.PREPARING, 0);
  }

  private static onStatusChanged(status: string): void {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable !== undefined && playable.id !== AvSessionBridge.assetId) {
      AvSessionBridge.assetId = playable.id;
      AvSessionBridge.applyMetadata(playable);
      AvSessionBridge.refreshFavorite(playable);
    }
    AvSessionBridge.reportState(status, PlayerManager.getCurrentTime());
  }

  private static onPosition(): void {
    if (PlayerManager.getStatus() !== PlayerStatus.PLAYING) {
      return;
    }
    const now: number = Date.now();
    if (now - AvSessionBridge.lastPositionReportAt < POSITION_REPORT_INTERVAL_MS) {
      return;
    }
    AvSessionBridge.lastPositionReportAt = now;
    AvSessionBridge.reportState(PlayerStatus.PLAYING, PlayerManager.getCurrentTime());
  }

  private static async refreshFavorite(playable: Playable): Promise<void> {
    if (playable.feedItemId <= 0) {
      return;
    }
    try {
      AvSessionBridge.favorite = await FavoritesRepository.isFavorite(playable.feedItemId);
    } catch (error) {
      AvSessionBridge.favorite = false;
    }
  }

  private static applyMetadata(playable: Playable): void {
    const session: avSession.AVSession | undefined = AvSessionBridge.session;
    if (session === undefined) {
      return;
    }
    const rewind: avSession.SkipIntervals = AvSessionBridge.toSkipIntervals(UserPreferences.getRewindSecs());
    const forward: avSession.SkipIntervals = AvSessionBridge.toSkipIntervals(UserPreferences.getFastForwardSecs());
    const metadata: avSession.AVMetadata = {
      assetId: String(playable.id),
      title: playable.title,
      artist: playable.feedTitle,
      album: playable.feedTitle,
      subtitle: playable.feedTitle,
      description: playable.feedTitle,
      duration: playable.duration,
      // 系统卡片的快进/快退按钮按这里的档位跳（仅支持 10/15/30 秒）
      skipIntervals: forward,
      fastForwardSkipIntervals: forward,
      rewindSkipIntervals: rewind
    };
    session.setAVMetadata(metadata).then(() => {
      Logger.info(TAG, 'metadata -> ' + playable.title);
    }).catch((error: Error) => {
      Logger.warn(TAG, 'setAVMetadata failed: ' + error.message);
    });
    // 封面单独补：取图/解码是异步的，不能阻塞标题与播控按钮的上报
    AvSessionBridge.attachCover(session, metadata, playable);
  }

  /**
   * 播控中心卡片的封面 = `AVMetadata.mediaImage`。
   *
   * 必须是 **PixelMap**：卡片由系统 UI 进程渲染，拿不到应用沙箱里的 `file://` 路径
   * （传网络 URL 也依赖系统侧自行下载，实测卡片只显示默认音符占位图）。
   * 这里复用 ImageCache 的磁盘缓存（命中即同步可用）解码成 PixelMap 再上报。
   */
  private static attachCover(session: avSession.AVSession, metadata: avSession.AVMetadata,
                             playable: Playable): void {
    if (playable.imageUrl === '' || AvSessionBridge.coverAssetId === playable.id) {
      return;
    }
    AvSessionBridge.loadCover(playable.imageUrl).then((cover: image.PixelMap | undefined) => {
      if (cover === undefined) {
        return;
      }
      // 解码期间可能已经换集：只给仍在播的这一集补封面
      const current: Playable | undefined = PlayerManager.getCurrent();
      if (current === undefined || current.id !== playable.id) {
        return;
      }
      metadata.mediaImage = cover;
      session.setAVMetadata(metadata).then(() => {
        AvSessionBridge.coverAssetId = playable.id;
        Logger.info(TAG, 'metadata cover -> ' + playable.title);
      }).catch((error: Error) => {
        Logger.warn(TAG, 'setAVMetadata(cover) failed: ' + error.message);
      });
    }).catch((error: Error) => {
      Logger.warn(TAG, 'attachCover failed: ' + error.message);
    });
  }

  /** 取封面 PixelMap：磁盘缓存命中就同步用，未命中先下载；超过最长边则按比例缩小解码 */
  private static async loadCover(url: string): Promise<image.PixelMap | undefined> {
    const context: common.Context | undefined = AvSessionBridge.context;
    if (url === '' || context === undefined) {
      return undefined;
    }
    if (AvSessionBridge.coverUrl === url && AvSessionBridge.cover !== undefined) {
      return AvSessionBridge.cover;
    }
    let src: string = ImageCache.peek(url, context);
    if (src === '') {
      src = await ImageCache.getImage(url, context);
    }
    if (src === '') {
      return undefined;
    }
    const path: string = src.startsWith('file://') ? src.substring('file://'.length) : src;
    const source: image.ImageSource = image.createImageSource(path);
    try {
      const info: image.ImageInfo = await source.getImageInfo();
      const longest: number = Math.max(info.size.width, info.size.height);
      let options: image.DecodingOptions | undefined = undefined;
      if (longest > COVER_MAX_EDGE_PX) {
        const scale: number = COVER_MAX_EDGE_PX / longest;
        options = {
          desiredSize: {
            width: Math.max(1, Math.round(info.size.width * scale)),
            height: Math.max(1, Math.round(info.size.height * scale))
          }
        };
      }
      const cover: image.PixelMap = await source.createPixelMap(options);
      AvSessionBridge.coverUrl = url;
      AvSessionBridge.cover = cover;
      return cover;
    } finally {
      source.release();
    }
  }

  /** 用户设置的快进/快退秒数映射到系统支持的档位 */
  private static toSkipIntervals(seconds: number): avSession.SkipIntervals {
    if (seconds <= 10) {
      return avSession.SkipIntervals.SECONDS_10;
    }
    if (seconds <= 15) {
      return avSession.SkipIntervals.SECONDS_15;
    }
    return avSession.SkipIntervals.SECONDS_30;
  }

  private static reportState(status: string, position: number): void {
    if (AvSessionBridge.session === undefined) {
      return;
    }
    const speed: number = PlayerManager.getSpeed();
    const duration: number = PlayerManager.getDuration();
    const stateObj: avSession.AVPlaybackState = {
      state: AvSessionBridge.toPlaybackState(status),
      // 原生校验要求 speed > 0
      speed: speed > 0 ? speed : 1.0,
      position: { elapsedTime: position > 0 ? position : 0, updateTime: Date.now() },
      bufferedTime: 0,
      loopMode: AvSessionBridge.toLoopMode(),
      isFavorite: AvSessionBridge.favorite
    };
    // duration=0 会被原生校验拒绝（ERR_INVALID_PARAM），仅在已知时长时上报
    if (duration > 0) {
      stateObj.duration = duration;
    }
    AvSessionBridge.pendingState = stateObj;
    AvSessionBridge.flushState();
  }

  private static flushState(): void {
    const session: avSession.AVSession | undefined = AvSessionBridge.session;
    const stateObj: avSession.AVPlaybackState | undefined = AvSessionBridge.pendingState;
    if (session === undefined || stateObj === undefined || AvSessionBridge.reporting) {
      return;
    }
    AvSessionBridge.reporting = true;
    AvSessionBridge.pendingState = undefined;
    const next = (): void => {
      AvSessionBridge.reporting = false;
      AvSessionBridge.flushState();
    };
    session.setAVPlaybackState(stateObj).then(() => {
      next();
    }).catch((error: Error) => {
      Logger.warn(TAG, 'setAVPlaybackState failed: ' + error.message);
      next();
    });
  }

  private static toPlaybackState(status: string): avSession.PlaybackState {
    if (status === PlayerStatus.PLAYING) {
      return avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    }
    if (status === PlayerStatus.PAUSED) {
      return avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    }
    if (status === PlayerStatus.COMPLETED) {
      return avSession.PlaybackState.PLAYBACK_STATE_COMPLETED;
    }
    if (status === PlayerStatus.ERROR) {
      return avSession.PlaybackState.PLAYBACK_STATE_ERROR;
    }
    if (status === PlayerStatus.IDLE) {
      return avSession.PlaybackState.PLAYBACK_STATE_IDLE;
    }
    if (status === PlayerStatus.PREPARED) {
      return avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
    }
    return avSession.PlaybackState.PLAYBACK_STATE_BUFFERING;
  }

  private static toLoopMode(): avSession.LoopMode {
    const repeat: number = UserPreferences.getRepeatMode();
    if (repeat === REPEAT_ONE) {
      return avSession.LoopMode.LOOP_MODE_SINGLE;
    }
    if (repeat === REPEAT_ALL) {
      return avSession.LoopMode.LOOP_MODE_LIST;
    }
    return avSession.LoopMode.LOOP_MODE_SEQUENCE;
  }

  /** 补齐「会话就绪时已经在播放」的竞态：把当前单集与状态一次性推给播控中心 */
  private static async syncCurrent(): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable === undefined) {
      return;
    }
    AvSessionBridge.assetId = playable.id;
    AvSessionBridge.applyMetadata(playable);
    await AvSessionBridge.refreshFavorite(playable);
    AvSessionBridge.reportState(PlayerManager.getStatus(), PlayerManager.getCurrentTime());
  }

  static async release(): Promise<void> {
    const session: avSession.AVSession | undefined = AvSessionBridge.session;
    if (session !== undefined) {
      await session.deactivate();
      await session.destroy();
    }
    AvSessionBridge.session = undefined;
    AvSessionBridge.assetId = -1;
    AvSessionBridge.favorite = false;
    AvSessionBridge.pendingState = undefined;
    AvSessionBridge.coverUrl = '';
    AvSessionBridge.cover = undefined;
    AvSessionBridge.coverAssetId = -1;
  }
}
