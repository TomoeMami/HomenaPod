import { ImageCache } from '../services/ImageCache';
import common from '@ohos.app.ability.common';

@Component
export struct FeedCover {
  @Prop imageUrl: string = '';
  @State src: string = '';

  build() {
    Image(this.src !== '' ? this.src : this.imageUrl)
      .width(48)
      .height(48)
      .borderRadius(6)
      .objectFit(ImageFit.Cover)
      .onAppear(() => {
        this.load();
      })
  }

  async load(): Promise<void> {
    if (this.imageUrl === '') {
      return;
    }
    try {
      const context = getContext(this) as common.Context;
      const cached: string = await ImageCache.getImage(this.imageUrl, context);
      if (cached !== '') {
        this.src = cached;
      }
    } catch (error) {
      this.src = this.imageUrl;
    }
  }
}
