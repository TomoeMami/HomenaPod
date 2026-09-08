import router from '@ohos.router';
import { SubscriptionService } from '../services/SubscriptionService';

@Entry
@Component
struct AddFeedPage {
  @State url: string = '';
  @State message: string = '';
  @State loading: boolean = false;

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.add_feed')).fontSize(22).fontWeight(FontWeight.Bold)
      TextInput({ placeholder: 'https://example.com/feed.xml', text: this.url })
        .onChange((value: string) => {
          this.url = value;
        })
        .width('90%')
      Button(this.loading ? $r('app.string.loading') : $r('app.string.subscribe'))
        .enabled(!this.loading)
        .onClick(() => {
          this.subscribe();
        })
      Text(this.message).fontSize(14).fontColor('#CC0000')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  async subscribe(): Promise<void> {
    if (this.url === '') {
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.add_url_empty'));
      return;
    }
    this.loading = true;
    this.message = '';
    try {
      const feed = await SubscriptionService.subscribe(this.url);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.subscribe_success')) + feed.getTitle();
      router.back();
    } catch (error) {
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.subscribe_failed')) + (error as Error).message;
    } finally {
      this.loading = false;
    }
  }
}
