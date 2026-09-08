// 全局轻提示工具
import { promptAction } from '@kit.ArkUI';

export class MessageHelper {
  static show(message: string): void {
    promptAction.showToast({ message: message });
  }
}
