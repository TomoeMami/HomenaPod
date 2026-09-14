// Port of: ui/cleaner/HtmlToPlainText.java + parser/feed/util/SyndStringUtils.java
export class HtmlCleaner {
  /**
   * HTML → 纯文本（上游 `HtmlToPlainText.FormattingVisitor` 的 head/tail 规则）。
   *
   * 换行来源：`p` / `h1`~`h5` / `tr` 在开闭标签处各补一个 `\n`（上游 head 与 tail 都 append，
   * 所以相邻两个 `<p>` 之间是空行），`br` / `</dd>` / `</dt>` 补 `\n`，`li` 补换行 + `* `
   * （上游是 `\n * `；本实现随后统一裁掉行首行尾空格，故写成 `\n* `，视觉一致）。
   *
   * 两处有意的偏离，都是为了「纯文本降级」这一形态：
   * 1. `div` 也按块级处理 —— 上游用 WebView 渲染 HTML，`div` 天然换行；不补这一条会出现「整篇挤成一段」。
   * 2. 不重建 `<a>` 的裸链接（上游会在链接后补 `<url>`）—— 本移植版的列表与正文都不展示裸链接。
   *
   * 关键：**只压缩空格与制表符，不压缩换行**。旧实现（`PlayerPage.plainText`）把标签换成空格后
   * `\s+` → ' '，把 `<br>`/`<p>` 与原文里的真实换行一起吃掉了 —— 那是「节目详情没有换行」的根因。
   */
  static stripHtml(html: string): string {
    if (html === null || html === undefined) {
      return '';
    }
    let text: string = html;
    // 段落 / 标题 / 表格行 / div：开闭标签都换行（相邻两段之间会留一个空行，与上游一致）
    text = text.replace(/<\/?(p|h[1-5]|tr|div)\b[^>]*>/gi, '\n');
    // 定义列表：上游只在 tail 补换行
    text = text.replace(/<\/(dd|dt)\b[^>]*>/gi, '\n');
    // 列表项：上游只在 head 补「换行 + 项目符号」
    text = text.replace(/<li\b[^>]*>/gi, '\n* ');
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<[^>]+>/g, '');
    text = text.replace(/&nbsp;/gi, ' ');
    text = text.replace(/&amp;/gi, '&');
    text = text.replace(/&lt;/gi, '<');
    text = text.replace(/&gt;/gi, '>');
    text = text.replace(/&quot;/gi, '"');
    text = text.replace(/&#39;/gi, "'");
    text = text.replace(/[ \t]+/g, ' ');
    // 行首行尾的空格没有意义（HTML 里换行后的缩进很常见），裁掉后再收敛空行
    text = text.replace(/ *\n */g, '\n');
    text = text.replace(/\n{3,}/g, '\n\n');
    return text.trim();
  }

  static shorten(html: string, maxLength: number): string {
    const plain: string = HtmlCleaner.stripHtml(html);
    if (plain.length <= maxLength) {
      return plain;
    }
    return plain.substring(0, maxLength) + '…';
  }
}
