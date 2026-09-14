import { DesignTokens } from '../common/DesignTokens';
import { ShownotesSegment } from '../utils/ShownotesText';

/**
 * 节目详情正文（上游 `feeditem_fragment.xml` 的 `ShownotesWebView` / `ItemDescriptionFragment`）。
 *
 * 本移植版无 Web 组件依赖，用纯文本渲染，但**保留换行**：
 * 正文 HTML 里的 `<br>`/`<p>` 与真实换行都会成为换行（`ShownotesText.plainText`），
 * 落在单集时长内的时间码渲染成可点的品牌色下划线段（上游 `ShownotesCleaner` 的时码链接，
 * 点按跳到该播放位置）。调用方负责把正文切成 `segments` 与处理点按。
 */
@Component
export struct ShownotesBody {
  @Prop segments: ShownotesSegment[] = [];
  /** 点按时间码：`timeMs` 已是毫秒 */
  onTimecode: (timeMs: number) => void = () => {
  };

  build() {
    Text() {
      // 键值带上序号 + 正文 + 时码：ForEach 只在键变化时重建，正文换了一集而键不变会留下旧文本
      ForEach(this.segments, (segment: ShownotesSegment, index: number) => {
        if (segment.timeMs >= 0) {
          Span(segment.text)
            .fontColor($r('app.color.primary'))
            .decoration({ type: TextDecorationType.Underline })
            .onClick(() => {
              this.onTimecode(segment.timeMs);
            })
        } else {
          Span(segment.text)
            .fontColor($r('app.color.text_primary'))
        }
      }, (segment: ShownotesSegment, index: number) =>
      index.toString() + '|' + segment.timeMs.toString() + '|' + segment.text)
    }
    .width('100%')
    .fontSize(DesignTokens.FONT_PARAGRAPH)
    .lineHeight(22)
    .textAlign(TextAlign.Start)
  }
}
