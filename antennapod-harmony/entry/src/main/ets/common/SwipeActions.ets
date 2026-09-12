import { UserPreferences } from '../prefs/UserPreferences';

/**
 * 滑动动作（对照上游 `ui/swipeactions/SwipeAction.java` + `SwipeActions.java` +
 * `SwipeActionsDialog.java`）：
 * 每个「屏幕」左右两个动作，动作 id 与上游同名常量一致；偏好存 'RIGHT,LEFT'，
 * 另有「启用滑动动作」开关（上游 KEY_PREFIX_NO_ACTION，默认 true）。
 *
 * 差异说明（见 docs/07-ui-layout-parity.md）：上游左侧动作固定为「移出队列 + 无」两种状态；
 * 本移植版把「无」显式建模为 `NONE`，未配置的一侧不挂划出项。
 */
export class SwipeActionId {
  static readonly NONE: string = 'NONE';
  static readonly ADD_TO_QUEUE: string = 'ADD_TO_QUEUE';
  static readonly REMOVE_FROM_QUEUE: string = 'REMOVE_FROM_QUEUE';
  static readonly REMOVE_FROM_INBOX: string = 'REMOVE_FROM_INBOX';
  static readonly START_DOWNLOAD: string = 'START_DOWNLOAD';
  static readonly MARK_PLAYED: string = 'MARK_PLAYED';
  static readonly MARK_FAV: string = 'MARK_FAV';
  static readonly REMOVE_FROM_FAVORITES: string = 'REMOVE_FROM_FAVORITES';
  static readonly DELETE: string = 'DELETE';
  static readonly SHARE: string = 'SHARE';
  static readonly MOVE_TO_TOP: string = 'MOVE_TO_TOP';
  static readonly MOVE_TO_BOTTOM: string = 'MOVE_TO_BOTTOM';
}

/** 屏幕标识（与上游 SwipeActions 的 tag 同名） */
export class SwipeScreen {
  static readonly QUEUE: string = 'QueueFragment';
  static readonly INBOX: string = 'InboxFragment';
  static readonly FEED_DETAIL: string = 'FeedItemlistFragment';
  static readonly DOWNLOADS: string = 'CompletedDownloadsFragment';
}

export interface SwipeActionSpec {
  id: string;
  label: ResourceStr;
  icon: Resource;
}

const SWIPE_WIDTH: number = 88;

/** 划出项宽度（vp）：图标 + 文字竖排，宽度固定才能确定「完全划出」的距离 */
export function swipeActionWidth(): number {
  return SWIPE_WIDTH;
}

/** 动作展示样式（图标 + 中文名） */
export function swipeActionSpec(id: string): SwipeActionSpec {
  if (id === SwipeActionId.ADD_TO_QUEUE) {
    return { id: id, label: $r('app.string.episode_add_queue'), icon: $r('sys.symbol.music_note_list') };
  }
  if (id === SwipeActionId.REMOVE_FROM_QUEUE) {
    return { id: id, label: $r('app.string.swipe_action_remove_from_queue'), icon: $r('sys.symbol.xmark_circle') };
  }
  if (id === SwipeActionId.REMOVE_FROM_INBOX) {
    return { id: id, label: $r('app.string.remove_inbox_label'), icon: $r('sys.symbol.inbox') };
  }
  if (id === SwipeActionId.START_DOWNLOAD) {
    return { id: id, label: $r('app.string.episode_download'), icon: $r('sys.symbol.arrow_down_circle') };
  }
  if (id === SwipeActionId.MARK_PLAYED) {
    return { id: id, label: $r('app.string.episode_mark_played'), icon: $r('sys.symbol.checkmark_circle') };
  }
  if (id === SwipeActionId.MARK_FAV) {
    return { id: id, label: $r('app.string.add_to_favorites_label'), icon: $r('sys.symbol.star_fill') };
  }
  if (id === SwipeActionId.REMOVE_FROM_FAVORITES) {
    return { id: id, label: $r('app.string.remove_from_favorites_label'), icon: $r('sys.symbol.star') };
  }
  if (id === SwipeActionId.DELETE) {
    return { id: id, label: $r('app.string.episode_delete_download'), icon: $r('sys.symbol.trash') };
  }
  if (id === SwipeActionId.SHARE) {
    return { id: id, label: $r('app.string.episode_share'), icon: $r('sys.symbol.share') };
  }
  if (id === SwipeActionId.MOVE_TO_TOP) {
    return { id: id, label: $r('app.string.queue_move_top'), icon: $r('sys.symbol.arrow_up') };
  }
  if (id === SwipeActionId.MOVE_TO_BOTTOM) {
    return { id: id, label: $r('app.string.queue_move_bottom'), icon: $r('sys.symbol.arrow_down') };
  }
  return { id: SwipeActionId.NONE, label: $r('app.string.swipe_none_label'), icon: $r('sys.symbol.circle') };
}

/** 破坏性动作（移出/删除）用 error 配色，其余用品牌色 */
export function isDestructiveSwipeAction(id: string): boolean {
  return id === SwipeActionId.DELETE || id === SwipeActionId.REMOVE_FROM_QUEUE
    || id === SwipeActionId.REMOVE_FROM_INBOX || id === SwipeActionId.REMOVE_FROM_FAVORITES;
}

export class SwipeActions {
  /** 该屏幕可选的动作（只列出本移植版真正实现的动作） */
  static available(screen: string): SwipeActionSpec[] {
    const ids: string[] = SwipeActions.availableIds(screen);
    const specs: SwipeActionSpec[] = [];
    for (const id of ids) {
      specs.push(swipeActionSpec(id));
    }
    return specs;
  }

  private static availableIds(screen: string): string[] {
    if (screen === SwipeScreen.QUEUE) {
      return [SwipeActionId.REMOVE_FROM_QUEUE, SwipeActionId.START_DOWNLOAD, SwipeActionId.MARK_PLAYED,
        SwipeActionId.MARK_FAV, SwipeActionId.DELETE, SwipeActionId.SHARE, SwipeActionId.MOVE_TO_TOP,
        SwipeActionId.MOVE_TO_BOTTOM, SwipeActionId.NONE];
    }
    if (screen === SwipeScreen.INBOX) {
      // 上游 SwipeActionsDialog：收件箱刻意不提供「标记已播放」（TogglePlaybackState）与「删除文件」
      return [SwipeActionId.ADD_TO_QUEUE, SwipeActionId.START_DOWNLOAD,
        SwipeActionId.REMOVE_FROM_INBOX, SwipeActionId.MARK_FAV, SwipeActionId.SHARE,
        SwipeActionId.NONE];
    }
    if (screen === SwipeScreen.FEED_DETAIL) {
      return [SwipeActionId.MARK_PLAYED, SwipeActionId.ADD_TO_QUEUE, SwipeActionId.START_DOWNLOAD,
        SwipeActionId.DELETE, SwipeActionId.MARK_FAV, SwipeActionId.REMOVE_FROM_FAVORITES,
        SwipeActionId.REMOVE_FROM_INBOX, SwipeActionId.SHARE, SwipeActionId.NONE];
    }
    return [SwipeActionId.DELETE, SwipeActionId.ADD_TO_QUEUE, SwipeActionId.MARK_PLAYED,
      SwipeActionId.START_DOWNLOAD, SwipeActionId.NONE];
  }

  /**
   * 默认动作（上游 `SwipeActions.getPrefsWithDefaults` 的每屏默认值）。
   * 队列按 I5 对齐上游（左右都是「移出队列」）；其余屏幕沿用本移植版既有行为，
   * 避免在队列改造里顺带改掉别的页面的手势习惯。
   */
  static defaults(screen: string): string[] {
    if (screen === SwipeScreen.QUEUE) {
      return [SwipeActionId.REMOVE_FROM_QUEUE, SwipeActionId.REMOVE_FROM_QUEUE];
    }
    if (screen === SwipeScreen.INBOX) {
      // 上游 SwipeActions.getPrefsWithDefaults：收件箱默认 [右滑=加入队列, 左滑=移出收件箱]
      return [SwipeActionId.ADD_TO_QUEUE, SwipeActionId.REMOVE_FROM_INBOX];
    }
    if (screen === SwipeScreen.FEED_DETAIL) {
      return [SwipeActionId.NONE, SwipeActionId.MARK_PLAYED];
    }
    return [SwipeActionId.ADD_TO_QUEUE, SwipeActionId.DELETE];
  }

  /** 读取该屏幕的 [右滑, 左滑] 动作 id */
  static resolve(screen: string): string[] {
    const fallback: string[] = SwipeActions.defaults(screen);
    const raw: string = UserPreferences.getSwipeActions(screen, fallback[0] + ',' + fallback[1]);
    const parts: string[] = raw.split(',');
    if (parts.length !== 2) {
      return fallback;
    }
    return [parts[0], parts[1]];
  }

  static set(screen: string, right: string, left: string): void {
    UserPreferences.setSwipeActions(screen, right + ',' + left);
  }

  static isEnabled(screen: string): boolean {
    return UserPreferences.getSwipeActionsEnabled(screen);
  }

  static setEnabled(screen: string, enabled: boolean): void {
    UserPreferences.setSwipeActionsEnabled(screen, enabled);
  }
}
