// Basic 认证头所需的 Base64 编码（移植自 BasicAuthorizationInterceptor 的凭据编码）
import util from '@ohos.util';

export class Base64Utils {
  static encode(value: string): string {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const helper: util.Base64Helper = new util.Base64Helper();
    return helper.encodeToStringSync(encoder.encodeInto(value));
  }

  /** HTTP Basic 认证头值：Basic base64(user:pass) */
  static basicAuth(username: string, password: string): string {
    return 'Basic ' + Base64Utils.encode(username + ':' + password);
  }
}
