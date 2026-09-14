// Port of: ui/cleaner/HtmlToPlainText.java（去标签）
//        + ui/cleaner/ShownotesCleaner.java（时码识别 addTimecodes / Converter.durationString*ToMs）
import { HtmlCleaner } from './HtmlCleaner';

/**
 * 节目详情（shownotes）的一段：
 * `timeMs < 0` 是普通文本；`timeMs >= 0` 表示这一段是时间码，点按可跳到该播放位置
 * （上游 `ShownotesCleaner.addTimecodes` 把时码包成 `antennapod://timecode/<ms>` 链接）。
 */
export interface ShownotesSegment {
  text: string;
  timeMs: number;
}

/** 一次时码匹配（上游 `TIMECODE_REGEX` 的一个结果） */
interface TimecodeMatch {
  start: number;
  end: number;
  text: string;
  /** 是否带小时段（`\d+:\d+:\d{2}`，上游正则的 group(1)） */
  hasHours: boolean;
}

/**
 * 节目详情正文处理（纯逻辑，不 import 任何 `@kit.*`，可在宿主侧跑断言）。
 *
 * 两件事，对齐上游：
 * 1. **HTML → 纯文本但保留换行**：上游用 WebView 渲染 `ShownotesCleaner` 处理过的 HTML；
 *    本移植版没有 Web 组件依赖，用 `HtmlCleaner.stripHtml`（`HtmlToPlainText.java` 的移植）
 *    降级成纯文本——它把 `<br>`/`<p>` 转成 `\n` 并保留原文里的真实换行。
 *    旧实现（`PlayerPage.plainText`）把标签替换成空格后 `\s+` → ' '，**换行被整体吃掉**。
 * 2. **时间码识别**：短时码（`mm:ss`）先按 `HH:MM` 解析，若超过单集时长则整篇改按 `MM:SS`
 *    （上游 `useHourFormat` 的推断方式），只有落在时长之内的时间码才变成可点段。
 */
export class ShownotesText {
  /** 「不是时间码」的哨兵值 */
  static readonly NO_TIME: number = -1;
  /** 上游 `TIMECODE_REGEX = \b((\d+):)?(\d+):(\d{2})\b` */
  private static readonly TIMECODE_SOURCE: string = '\\b(?:(\\d+):)?(\\d+):(\\d{2})\\b';

  /** 正文 HTML → 纯文本（`<br>`/`<p>` 变成换行，其余标签删除，实体反转义） */
  static plainText(html: string): string {
    return HtmlCleaner.stripHtml(html);
  }

  /**
   * 正文 HTML → 分段列表（普通文本段 + 可点时间码段）。
   *
   * @param durationMs 单集时长；`<= 0`（未知）时与上游传 `Integer.MAX_VALUE` 等价：
   *                   所有时码按 `HH:MM` 解析且全部可点。
   */
  static segments(html: string, durationMs: number): ShownotesSegment[] {
    const text: string = ShownotesText.plainText(html);
    if (text === '') {
      return [];
    }
    const matches: TimecodeMatch[] = ShownotesText.findTimecodes(text);
    if (matches.length === 0) {
      return [{ text: text, timeMs: ShownotesText.NO_TIME }];
    }
    const duration: number = durationMs > 0 ? durationMs : Number.MAX_SAFE_INTEGER;
    const useHourFormat: boolean = ShownotesText.usesHourFormat(matches, duration);
    const segments: ShownotesSegment[] = [];
    let cursor: number = 0;
    for (const match of matches) {
      const time: number = match.hasHours
        ? ShownotesText.longToMs(match.text)
        : ShownotesText.shortToMs(match.text, useHourFormat);
      // 上游只在 `time < playableDuration` 时链接化：超过整集长度的「时码」多半是
      // 比分/日期/统计数字，点了也没意义，保持纯文本
      if (time >= duration) {
        continue;
      }
      if (match.start > cursor) {
        segments.push({ text: text.substring(cursor, match.start), timeMs: ShownotesText.NO_TIME });
      }
      segments.push({ text: match.text, timeMs: time });
      cursor = match.end;
    }
    if (cursor < text.length) {
      segments.push({ text: text.substring(cursor), timeMs: ShownotesText.NO_TIME });
    }
    return segments;
  }

  /** 分段拼回纯文本（复制 / 无障碍文本 / 断言用） */
  static toPlainText(segments: ShownotesSegment[]): string {
    let out: string = '';
    for (const segment of segments) {
      out += segment.text;
    }
    return out;
  }

  private static findTimecodes(text: string): TimecodeMatch[] {
    // 每次新建 RegExp：静态带 g 的正则会把 lastIndex 状态留给下一次调用
    const pattern: RegExp = new RegExp(ShownotesText.TIMECODE_SOURCE, 'g');
    const matches: TimecodeMatch[] = [];
    let found: RegExpExecArray | null = pattern.exec(text);
    while (found !== null) {
      matches.push({
        start: found.index,
        end: found.index + found[0].length,
        text: found[0],
        hasHours: found[1] !== undefined
      });
      found = pattern.exec(text);
    }
    return matches;
  }

  /**
   * 短时码按 `HH:MM` 还是 `MM:SS` 解析（上游 `addTimecodes` 的 `useHourFormat` 推断）：
   * 只要有一个短时码按 `HH:MM` 解析后超过整集时长，就改用 `MM:SS`。
   */
  private static usesHourFormat(matches: TimecodeMatch[], durationMs: number): boolean {
    for (const match of matches) {
      if (match.hasHours) {
        continue;
      }
      if (ShownotesText.shortToMs(match.text, true) > durationMs) {
        return false;
      }
    }
    return true;
  }

  /** 上游 `Converter.durationStringLongToMs`：`h:mm:ss` → ms */
  private static longToMs(value: string): number {
    const parts: string[] = value.split(':');
    if (parts.length !== 3) {
      return 0;
    }
    return Number(parts[0]) * 3600000 + Number(parts[1]) * 60000 + Number(parts[2]) * 1000;
  }

  /** 上游 `Converter.durationStringShortToMs`：`modifier = 60` 时按 `HH:MM`，否则按 `MM:SS` */
  private static shortToMs(value: string, assumeHours: boolean): number {
    const parts: string[] = value.split(':');
    if (parts.length !== 2) {
      return 0;
    }
    const modifier: number = assumeHours ? 60 : 1;
    return Number(parts[0]) * 60 * 1000 * modifier + Number(parts[1]) * 1000 * modifier;
  }
}
