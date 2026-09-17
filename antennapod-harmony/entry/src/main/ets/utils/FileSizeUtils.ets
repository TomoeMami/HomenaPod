// Port of: android.text.format.Formatter.formatShortFileSize 的等价实现
/**
 * 文件大小格式化（自动 B/KB/MB/GB/TB）。
 * 上游下载列表与存储统计都用 `Formatter.formatShortFileSize`，它会在 B/KB/MB/GB 之间自动选档；
 * 移植版此前只做了 KB/MB 两档，下载了几百 MB 的播客时会一直显示「600.0 MB」。
 */
export class FileSizeUtils {
  static format(bytes: number): string {
    if (!Number.isFinite(bytes) || bytes <= 0) {
      return '0 B';
    }
    if (bytes < 1024) {
      return Math.round(bytes).toString() + ' B';
    }
    const kb: number = bytes / 1024;
    if (kb < 1024) {
      return Math.round(kb).toString() + ' KB';
    }
    const mb: number = kb / 1024;
    if (mb < 1024) {
      return mb.toFixed(1) + ' MB';
    }
    const gb: number = mb / 1024;
    if (gb < 1024) {
      return gb.toFixed(1) + ' GB';
    }
    return (gb / 1024).toFixed(1) + ' TB';
  }
}
