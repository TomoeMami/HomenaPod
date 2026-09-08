import router from '@ohos.router';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { util } from '@kit.ArkTS';
import { Feed } from '../model/Feed';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { OpmlService } from '../services/OpmlService';

@Entry
@Component
struct OpmlPage {
  @State message: string = '';
  @State loading: boolean = false;

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.opml_title')).fontSize(22).fontWeight(FontWeight.Bold)
      Button($r('app.string.opml_import'))
        .enabled(!this.loading)
        .onClick(() => {
          this.importOpml();
        })
      Button($r('app.string.opml_export'))
        .enabled(!this.loading)
        .onClick(() => {
          this.exportOpml();
        })
      if (this.loading) {
        Text($r('app.string.loading')).fontSize(14).fontColor($r('app.color.text_secondary'))
      }
      Text(this.message).fontSize(14).fontColor('#2962FF')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  async importOpml(): Promise<void> {
    this.loading = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const documentPicker = new picker.DocumentViewPicker(context);
      const result: string[] = await documentPicker.select();
      if (result.length === 0) {
        return;
      }
      const file = fs.openSync(result[0], fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file.fd);
      const decoder: util.TextDecoder = util.TextDecoder.create();
      const xml: string = decoder.decodeToString(new Uint8Array(buffer));
      const feeds: Feed[] = await OpmlService.importOpml(xml);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.opml_imported')) + feeds.length;
    } catch (error) {
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  async exportOpml(): Promise<void> {
    this.loading = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const feeds: Feed[] = await FeedRepository.listSubscribed();
      const xml: string = OpmlService.exportOpml(feeds);
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = ['antennapod-opml.xml'];
      const documentPicker = new picker.DocumentViewPicker(context);
      const result: string[] = await documentPicker.save(options);
      if (result.length === 0) {
        return;
      }
      const file = fs.openSync(result[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, xml);
      fs.closeSync(file.fd);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.opml_exported')) + feeds.length;
    } catch (error) {
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }
}
