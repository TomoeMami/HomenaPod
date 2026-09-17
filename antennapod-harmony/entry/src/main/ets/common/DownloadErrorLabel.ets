// Port of: ui/screen/download/DownloadErrorLabel.java -> @ohos.request 错误码映射
import request from '@ohos.request';

/**
 * 下载失败原因的用户可读文案。
 *
 * 上游 DownloadErrorLabel 有 22 种 DownloadError 映射；鸿蒙侧 `@ohos.request` 的
 * `DownloadTask.on('fail')` 回调给的是 **Download Error Codes 常量**（`request.ERROR_*`），
 * 共 11 种，因此这里按这些常量建表，并保留"未知"兜底。
 *
 * 注意：**必须用运行期常量比对**，不能按 Android DownloadManager 的枚举顺序写死数值
 * （真机验收实测：HTTP 404 失败回调给的是 `ERROR_UNKNOWN`，写死数值时会误标成"存储空间不足"）。
 */
export class DownloadErrorLabel {
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

  /** 该错误码是否属于「文件已存在」（上游对这类失败用 info 图标，而不是 error） */
  static isFileAlreadyExists(code: number): boolean {
    return code === request.ERROR_FILE_ALREADY_EXISTS;
  }

  /** 错误码 → 文案资源名（调用方用 `resourceManager.getStringByNameSync` 取文案） */
  static resourceName(code: number): string {
    if (code === request.ERROR_OFFLINE) {
      return 'download_error_offline';
    }
    if (code === request.ERROR_UNSUPPORTED_NETWORK_TYPE) {
      return 'download_error_unsupported_network';
    }
    if (code === request.ERROR_CANNOT_RESUME) {
      return 'download_error_cannot_resume';
    }
    if (code === request.ERROR_DEVICE_NOT_FOUND) {
      return 'download_error_device_not_found';
    }
    if (code === request.ERROR_FILE_ALREADY_EXISTS) {
      return 'download_error_file_exists';
    }
    if (code === request.ERROR_FILE_ERROR) {
      return 'download_error_io';
    }
    if (code === request.ERROR_HTTP_DATA_ERROR) {
      return 'download_error_http_data';
    }
    if (code === request.ERROR_INSUFFICIENT_SPACE) {
      return 'download_error_insufficient_space';
    }
    if (code === request.ERROR_TOO_MANY_REDIRECTS) {
      return 'download_error_too_many_redirects';
    }
    if (code === request.ERROR_UNHANDLED_HTTP_CODE) {
      return 'download_error_http_code';
    }
    // ERROR_UNKNOWN 及其它：按「连接失败」兜底（上游发布版同样回退到 unknown）
    return 'download_error_connection';
  }
}
