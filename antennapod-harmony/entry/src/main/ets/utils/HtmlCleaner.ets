// Port of: ui/cleaner/HtmlToPlainText.java + parser/feed/util/SyndStringUtils.java
export class HtmlCleaner {
  static stripHtml(html: string): string {
    if (html === null || html === undefined) {
      return '';
    }
    let text: string = html;
    text = text.replace(/<(br\s*\/?|p)>/gi, '\n');
    text = text.replace(/<[^>]+>/g, '');
    text = text.replace(/&nbsp;/gi, ' ');
    text = text.replace(/&amp;/gi, '&');
    text = text.replace(/&lt;/gi, '<');
    text = text.replace(/&gt;/gi, '>');
    text = text.replace(/&quot;/gi, '"');
    text = text.replace(/&#39;/gi, "'");
    text = text.replace(/[ \t]+/g, ' ');
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
