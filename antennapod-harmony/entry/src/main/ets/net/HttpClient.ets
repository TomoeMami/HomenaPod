// Port of: net/common/src/main/java/de/danoeh/antennapod/net/common/{AntennapodHttpClient,RedirectChecker,BasicAuthorizationInterceptor,UserAgentInterceptor}.java
import http from '@ohos.net.http';

export enum NetworkErrorType {
  TIMEOUT = 0,
  NETWORK = 1,
  HTTP_4XX = 2,
  HTTP_5XX = 3,
  REDIRECT_LOOP = 4,
  PARSE = 5
}

export class NetworkError extends Error {
  type: NetworkErrorType;
  status: number = 0;

  constructor(type: NetworkErrorType, message: string, status: number) {
    super(message);
    this.type = type;
    this.status = status;
  }
}

export interface HttpOptions {
  headers: Record<string, string>;
  timeoutMs: number;
  method: http.RequestMethod;
}

export interface HttpResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
}

const DEFAULT_TIMEOUT: number = 20000;
/** 抓取订阅时上报的 UA：与 AppScope/app.json5 的 versionName 保持一致 */
const DEFAULT_USER_AGENT: string = 'HomenaPod/1.0.2 (HarmonyOS NEXT)';

export class HttpClient {
  static async get(url: string, headers: Record<string, string> = {}): Promise<HttpResponse> {
    return HttpClient.request(url, http.RequestMethod.GET, headers);
  }

  static async head(url: string, headers: Record<string, string> = {}): Promise<HttpResponse> {
    return HttpClient.request(url, http.RequestMethod.HEAD, headers);
  }

  static async getBytes(url: string, headers: Record<string, string> = {}): Promise<ArrayBuffer> {
    const finalHeaders: Record<string, string> = {};
    let hasUserAgent: boolean = false;
    for (const key of Object.keys(headers)) {
      finalHeaders[key] = headers[key];
      if (key === 'User-Agent') {
        hasUserAgent = true;
      }
    }
    if (!hasUserAgent) {
      finalHeaders['User-Agent'] = DEFAULT_USER_AGENT;
    }
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: finalHeaders,
        connectTimeout: DEFAULT_TIMEOUT,
        readTimeout: DEFAULT_TIMEOUT,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };
      const response: http.HttpResponse = await httpRequest.request(url, options);
      if (response.responseCode >= 400) {
        httpRequest.destroy();
        throw new NetworkError(
          response.responseCode >= 500 ? NetworkErrorType.HTTP_5XX : NetworkErrorType.HTTP_4XX,
          'HTTP ' + response.responseCode,
          response.responseCode
        );
      }
      return response.result as ArrayBuffer;
    } catch (error) {
      httpRequest.destroy();
      if (error instanceof NetworkError) {
        throw error;
      }
      const message: string = (error as Error).message;
      throw new NetworkError(message.toLowerCase().indexOf('timeout') >= 0 ? NetworkErrorType.TIMEOUT : NetworkErrorType.NETWORK, message, 0);
    }
  }

  static async request(url: string, method: http.RequestMethod, headers: Record<string, string>): Promise<HttpResponse> {
    const finalHeaders: Record<string, string> = {};
    let hasUserAgent: boolean = false;
    for (const key of Object.keys(headers)) {
      finalHeaders[key] = headers[key];
      if (key === 'User-Agent') {
        hasUserAgent = true;
      }
    }
    if (!hasUserAgent) {
      finalHeaders['User-Agent'] = DEFAULT_USER_AGENT;
    }
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: finalHeaders,
        connectTimeout: DEFAULT_TIMEOUT,
        readTimeout: DEFAULT_TIMEOUT,
        expectDataType: http.HttpDataType.STRING
      };
      const response: http.HttpResponse = await httpRequest.request(url, options);
      if (response.responseCode >= 400) {
        httpRequest.destroy();
        throw new NetworkError(
          response.responseCode >= 500 ? NetworkErrorType.HTTP_5XX : NetworkErrorType.HTTP_4XX,
          'HTTP ' + response.responseCode,
          response.responseCode
        );
      }
      return {
        status: response.responseCode,
        headers: response.header as Record<string, string>,
        body: response.result as string
      };
    } catch (error) {
      httpRequest.destroy();
      if (error instanceof NetworkError) {
        throw error;
      }
      const message: string = (error as Error).message;
      const type: NetworkErrorType = message.toLowerCase().indexOf('timeout') >= 0
        ? NetworkErrorType.TIMEOUT
        : NetworkErrorType.NETWORK;
      throw new NetworkError(type, message, 0);
    }
  }
}
