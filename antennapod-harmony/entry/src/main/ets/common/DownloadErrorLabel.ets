// Port of: ui/screen/download/DownloadErrorLabel.java -> @ohos.request 错误码映射
/**
 * 下载失败原因的用户可读文案。
 * 上游 DownloadErrorLabel 有 22 种 DownloadError 映射；鸿蒙侧 @ohos.request 暴露 11 种错误码，
 * 因此这里按 request 错误码建表，并保留"未知"兜底（上游 DEBUG 下直接抛异常，发布版回退 unknown）。
 */
export class DownloadErrorLabel {
  /** request 错误码 → 字符串资源名（对应 resources/base/element/string.json） */
  private static readonly LABELS: string[] = [
    'download_error_connection',          // 0 ERROR_UNKNOWN
    'download_error_offline',             // 1 ERROR_OFFLINE
    'download_error_unsupported_network', // 2 ERROR_UNSUPPORTED_NETWORK_TYPE
    'download_error_cannot_resume',       // 3 ERROR_CANNOT_RESUME
    'download_error_device_not_found',    // 4 ERROR_DEVICE_NOT_FOUND
    'download_error_file_exists',         // 5 ERROR_FILE_ALREADY_EXISTS
    'download_error_io',                  // 6 ERROR_FILE_ERROR
    'download_error_http_data',           // 7 ERROR_HTTP_DATA_ERROR
    'download_error_insufficient_space',  // 8 ERROR_INSUFFICIENT_SPACE
    'download_error_too_many_redirects',  // 9 ERROR_TOO_MANY_REDIRECTS
    'download_error_http_code'            // 10 ERROR_UNHANDLED_HTTP_CODE
  ];

  /** 失败原因写入 DownloadLog.reason_detailed 的前缀（保持库结构不变） */
  static readonly CODE_PREFIX: string = 'code=';

  /** 组装失败详情：`code=N`，UI 侧再解析成可读文案 */
  static detail(code: number): string {
    return DownloadErrorLabel.CODE_PREFIX + code;
  }

  /** 从 DownloadLog.reason_detailed 解析错误码；非本格式返回 -1 */
  static parseCode(detail: string): number {
    if (!detail.startsWith(DownloadErrorLabel.CODE_PREFIX)) {
      return -1;
    }
    const value: number = Number(detail.substring(DownloadErrorLabel.CODE_PREFIX.length));
    return Number.isFinite(value) ? value : -1;
  }

  /** 错误码 → 文案资源名（调用方用 resourceManager.getStringSync 或 $r 字面量解析） */
  static resourceName(code: number): string {
    return code >= 0 && code < DownloadErrorLabel.LABELS.length
      ? DownloadErrorLabel.LABELS[code] : DownloadErrorLabel.LABELS[0];
  }

  /** 错误码 → 完整资源标识 `app.string.<name>` */
  static resourceId(code: number): string {
    return 'app.string.' + DownloadErrorLabel.resourceName(code);
  }

  /** 错误码 → 文案资源（ArkUI 全局 Resource 类型，无需 import） */
  static resource(code: number): Resource {
    return $r(DownloadErrorLabel.resourceId(code));
  }
}

