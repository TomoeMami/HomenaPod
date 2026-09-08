// Stubs for full static check (not used by real app build)
declare namespace common {
  type Context = any;
  type UIAbilityContext = any;
}
declare namespace preferences {
  type Options = any;
  type Preferences = any;
  function getPreferencesSync(ctx: any, opts: any): Preferences;
}
declare namespace relationalStore {
  type ResultSet = any; type RdbStore = any; type ValuesBucket = any;
  type StoreConfig = any; type SecurityLevel = any;
  const SecurityLevel: any;
  function getRdbStore(ctx: any, config: StoreConfig): Promise<RdbStore>;
  class RdbPredicates {
    constructor(table: string);
    equalTo(field: string, value: any): RdbPredicates;
  }
}
declare namespace emitter {
  type InnerEvent = any; type EventData = any; type EventPriority = any;
  const EventPriority: any;
  function emit(evt: InnerEvent, data: any): void;
  function on(id: number, cb: (data: EventData) => void): void;
  function off(id: number): void;
}
declare namespace fs {
  type Stat = any;
  const OpenMode: any;
  function mkdirSync(path: string): void;
  function rmdirSync(path: string): void;
  function listFileSync(path: string): string[];
  function unlinkSync(path: string): void;
  function statSync(path: string | number): Stat;
  function openSync(path: string, mode?: number): any;
  function readSync(fd: number, buffer: ArrayBuffer): number;
  function writeSync(fd: number, buffer: ArrayBuffer | string): number;
  function closeSync(file: any): void;
}
declare namespace http {
  type HttpRequest = any; type HttpRequestOptions = any; type HttpResponse = any; type HttpDataType = any;
  const HttpDataType: any;
  function createHttp(): HttpRequest;
}
declare namespace notificationManager {
  type NotificationRequest = any; type ContentType = any;
  const ContentType: any;
  function publish(req: NotificationRequest): Promise<void>;
}
declare namespace request {
  type DownloadConfig = any; type DownloadTask = any;
  function downloadFile(ctx: any, config: DownloadConfig): Promise<DownloadTask>;
}
declare namespace router {
  function pushUrl(options: any): void;
  function getParams(): any;
  function back(): void;
}
declare namespace media {
  type AVPlayer = any; type AVPlayerState = string; type StateChangeReason = number; type MediaSource = any;
  type PlaybackSpeed = any; type SeekMode = any;
  function createAVPlayer(): Promise<AVPlayer>;
  namespace PlaybackSpeed {
    const SPEED_FORWARD_0_75_X: number;
    const SPEED_FORWARD_1_00_X: number;
    const SPEED_FORWARD_1_25_X: number;
    const SPEED_FORWARD_1_75_X: number;
    const SPEED_FORWARD_2_00_X: number;
    const SPEED_FORWARD_0_50_X: number;
    const SPEED_FORWARD_1_50_X: number;
    const SPEED_FORWARD_3_00_X: number;
  }
  namespace SeekMode {
    const SEEK_PREV_SYNC: number;
    const SEEK_CLOSEST: number;
    const SEEK_CONTINUOUS: number;
  }
}
declare namespace avSession {
  type AVSession = any; type AVMetadata = any; type AVPlaybackState = any; type AVQueueItem = any; type AVMediaDescription = any;
  function createAVSession(ctx: any, tag: string, type: string): Promise<AVSession>;
  enum PlaybackState {
    PLAYBACK_STATE_PLAY = 2,
    PLAYBACK_STATE_PAUSE = 3,
    PLAYBACK_STATE_COMPLETED = 7
  }
  enum LoopMode {
    LOOP_MODE_SEQUENCE = 0,
    LOOP_MODE_SINGLE = 1
  }
}
declare namespace backgroundTaskManager {
  const BackgroundMode: any;
  function startBackgroundRunning(ctx: any, mode: any, agent: any): Promise<void>;
  function stopBackgroundRunning(ctx: any): Promise<void>;
}
declare namespace wantAgent {
  type WantAgentInfo = any;
  const OperationType: any;
  const WantAgentFlags: any;
  function getWantAgent(info: WantAgentInfo): Promise<any>;
}
declare namespace workScheduler {
  type WorkInfo = any;
  const NetworkType: any;
  function startWork(info: WorkInfo): void;
  function stopWork(info: WorkInfo, cancel?: boolean): void;
}
declare class WorkSchedulerExtensionAbility {
  context: any;
  onWorkStart(work: any): void;
  onWorkStop(work: any): void;
}
declare namespace picker {
  class DocumentViewPicker {
    constructor(ctx: any);
    select(opts?: any): Promise<string[]>;
    save(opts?: any): Promise<string[]>;
  }
  class DocumentSelectOptions {}
  class DocumentSaveOptions {
    newFileNames: string[];
  }
}
declare namespace util {
  class TextEncoder {
    encodeInto(s: string): Uint8Array;
  }
  class TextDecoder {
    static create(): TextDecoder;
    decodeToString(u8: Uint8Array): string;
  }
}
declare namespace xml {
  type ParseOptions = any; type ParseInfo = any;
  class XmlPullParser {
    constructor(buffer: ArrayBuffer, encoding?: string);
    parse(opts: ParseOptions): void;
    parseXml(opts: ParseOptions): void;
  }
  enum EventType {
    START_TAG = 2,
    END_TAG = 3,
    TEXT = 4,
    CDSECT = 5,
    END_DOCUMENT = 1
  }
}
declare namespace promptAction {
  function showToast(opts: any): void;
}
declare namespace hilog {
  function debug(d: number, t: string, f: string, ...args: any[]): void;
  function info(d: number, t: string, f: string, ...args: any[]): void;
  function warn(d: number, t: string, f: string, ...args: any[]): void;
  function error(d: number, t: string, f: string, ...args: any[]): void;
}
declare namespace resourceManager {
  function getRawFileContent(p: string): Promise<Uint8Array>;
  function getStringSync(r: any): string;
}
declare class UIAbility {
  context: any;
  onCreate(want: any, launch: any): void;
  onWindowStageCreate(ws: any): void;
}
declare namespace AbilityConstant {
  type LaunchParam = any;
}
type Want = any;
type WantAgent = any;
declare namespace window {
  type WindowStage = any;
}
