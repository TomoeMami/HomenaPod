import router from '@ohos.router';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { util } from '@kit.ArkTS';
import { Feed } from '../model/Feed';
import { FeedRepository } from '../db/repositories/FeedRepository';
import { OpmlService } from '../services/OpmlService';
import { SubscriptionService } from '../services/SubscriptionService';
import { RefreshService } from '../services/RefreshService';
import { XmlReader, XmlTag } from '../parser/XmlReader';
import { EventHub, EventType, FeedUpdateData } from '../events/EventHub';
import { Logger } from '../utils/Logger';
import { MessageHelper } from '../utils/MessageHelper';
import { DesignTokens } from '../common/DesignTokens';
import { menuIcon } from '../common/MenuIcons';
import { AppBar } from '../components/AppBar';
import { AppIconButton } from '../components/AppIconButton';
import { OverflowButton } from '../components/OverflowButton';

const TAG: string = 'OpmlPage';

/** OPML 条目（对齐上游 OpmlElement：text / xmlUrl / htmlUrl） */
interface OpmlSelectionItem {
  text: string;
  xmlUrl: string;
  htmlUrl: string;
  selected: boolean;
}

/**
 * OPML 导入/导出（对齐上游 `opml_selection.xml` + OpmlImportActivity）：
 * 56vp 标题栏（溢出菜单「Select all / Deselect all」+ 导出动作）+
 * 多选列表（每行 48vp 起、左右 16vp、起始侧勾选圈）+ 底部「Cancel / Confirm」双按钮（各 40vp、间距 8vp、左右 16vp）。
 */
@Entry
@Component
struct OpmlPage {
  @State items: OpmlSelectionItem[] = [];
  @State message: string = '';
  @State loading: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppBar({ title: $r('app.string.opml_title'), showBack: true }) {
          Row({ space: DesignTokens.SPACE_XS }) {
            if (this.items.length > 0) {
              OverflowButton({ symbol: $r('sys.symbol.ellipsis_circle') }) {
                this.selectionMenu()
              }
            }
            AppIconButton({
              symbol: $r('sys.symbol.upload'),
              tint: $r('app.color.primary'),
              onTap: () => {
                this.exportOpml();
              }
            })
          }
        }

        if (this.message !== '') {
          Text(this.message)
            .fontSize(DesignTokens.FONT_FOOTNOTE)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({
              left: DesignTokens.PAGE_MARGIN,
              right: DesignTokens.PAGE_MARGIN,
              bottom: DesignTokens.SPACE_S
            })
        }

        if (this.items.length === 0) {
          // 未选择文件：给出导入入口（对齐 addfeed.xml 的 opmlImportButton 行）
          Column() {
            Row({ space: DesignTokens.SPACE_S }) {
              SymbolGlyph($r('sys.symbol.download_1'))
                .fontSize(DesignTokens.ICON_XL)
                .fontColor([$r('app.color.text_primary')])
              Text($r('app.string.opml_import'))
                .fontSize(DesignTokens.FONT_BODY)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .constraintSize({ minHeight: 48 })
            .padding({
              left: DesignTokens.PAGE_MARGIN,
              right: DesignTokens.PAGE_MARGIN,
              top: DesignTokens.SPACE_S,
              bottom: DesignTokens.SPACE_S
            })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.importOpml();
            })

            Divider().color($r('app.color.divider'))
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          List() {
            ForEach(this.items, (item: OpmlSelectionItem, index: number) => {
              ListItem() {
                Column() {
                  Row({ space: DesignTokens.SPACE_M }) {
                    SymbolGlyph(item.selected ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
                      .fontSize(DesignTokens.ICON_L)
                      .fontColor([item.selected ? $r('app.color.primary') : $r('app.color.text_tertiary')])
                    Text(item.text)
                      .fontSize(DesignTokens.FONT_BODY)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .constraintSize({ minHeight: 48 })
                  .padding({
                    left: DesignTokens.PAGE_MARGIN,
                    right: DesignTokens.PAGE_MARGIN,
                    top: DesignTokens.SPACE_S,
                    bottom: DesignTokens.SPACE_S
                  })
                  .alignItems(VerticalAlign.Center)
                  .onClick(() => {
                    this.toggle(index);
                  })

                  if (index < this.items.length - 1) {
                    Divider().color($r('app.color.divider'))
                  }
                }
                .width('100%')
              }
            }, (item: OpmlSelectionItem, index: number) =>
              // 键值必须带上 selected：ForEach 非首次渲染时「键值已存在 → 不创建新组件，直接复用旧的」，
              // 只按 xmlUrl+index 生成键值时全选后每一项的键值都没变，勾选圈会一直停在空心圆。
              item.xmlUrl + '-' + index + '-' + item.selected)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }

        // 底部操作区（上游 opml_selection.xml：Cancel 在左、Confirm 在右，各 40vp、间距 8vp）
        if (this.items.length > 0) {
          Row({ space: DesignTokens.SPACE_S }) {
            Button($r('app.string.cancel_label'))
              .layoutWeight(1)
              .height(DesignTokens.HEIGHT_BUTTON)
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .backgroundColor($r('app.color.surface_secondary'))
              .fontColor($r('app.color.text_primary'))
              .onClick(() => {
                router.back();
              })
            Button($r('app.string.confirm_label'))
              .layoutWeight(1)
              .height(DesignTokens.HEIGHT_BUTTON)
              .fontSize(DesignTokens.FONT_PARAGRAPH)
              .backgroundColor($r('app.color.primary'))
              .fontColor($r('app.color.on_primary'))
              .enabled(!this.loading && this.selectedCount() > 0)
              .onClick(() => {
                this.importSelected();
              })
          }
          .width('100%')
          .padding({
            left: DesignTokens.PAGE_MARGIN,
            right: DesignTokens.PAGE_MARGIN,
            top: DesignTokens.SPACE_S,
            bottom: DesignTokens.SPACE_S
          })
        }
      }
      .width('100%')
      .height('100%')

      if (this.loading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color($r('app.color.primary'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    // 沉浸式状态栏：把页面背景的绘制区延伸到状态栏下（不改布局，内容仍避开状态栏）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 溢出菜单：上游两项互斥显示（全选后只剩「Deselect all」） */
  @Builder
  selectionMenu() {
    Menu() {
      if (this.allSelected()) {
        MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.circle')), content: $r('app.string.deselect_all_label') })
          .onClick(() => {
            this.toggleSelectAll();
          })
      } else {
        MenuItem({ symbolStartIcon: menuIcon($r('sys.symbol.checkmark_circle')), content: $r('app.string.select_all_label') })
          .onClick(() => {
            this.toggleSelectAll();
          })
      }
    }
  }

  allSelected(): boolean {
    if (this.items.length === 0) {
      return false;
    }
    for (const item of this.items) {
      if (!item.selected) {
        return false;
      }
    }
    return true;
  }

  selectedCount(): number {
    let count: number = 0;
    for (const item of this.items) {
      if (item.selected) {
        count++;
      }
    }
    return count;
  }

  toggle(index: number): void {
    const next: OpmlSelectionItem[] = [];
    for (let i: number = 0; i < this.items.length; i++) {
      const item: OpmlSelectionItem = this.items[i];
      next.push({
        text: item.text,
        xmlUrl: item.xmlUrl,
        htmlUrl: item.htmlUrl,
        selected: i === index ? !item.selected : item.selected
      });
    }
    this.items = next;
  }

  toggleSelectAll(): void {
    const target: boolean = !this.allSelected();
    const next: OpmlSelectionItem[] = [];
    for (const item of this.items) {
      next.push({ text: item.text, xmlUrl: item.xmlUrl, htmlUrl: item.htmlUrl, selected: target });
    }
    this.items = next;
  }

  /** 选择 OPML 文件并解析出可勾选条目（对齐上游 OpmlReader + OpmlElement） */
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
      this.items = OpmlPage.parseOutlines(xml);
      this.message = getContext(this).resourceManager.getStringSync($r('app.string.opml_imported')) + this.items.length;
    } catch (error) {
      this.message = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  /**
   * 确认导入：只把勾选的条目**登记**为订阅（不抓取），随后交给后台整库刷新补齐剧集与封面
   * —— 对齐上游 `OpmlImportActivity.doImport`（写库 + `FeedUpdateManager.runOnce()`）。
   *
   * 旧实现逐条 `await SubscriptionService.subscribe()`（抓源 + 解析 + 落库整源单集）：
   * 86 个订阅要让用户在导入页对着转圈等好几分钟，而订阅其实早就写进库里了。现在导入是瞬时的，
   * 抓取在后台跑，用户可以立刻离开本页。
   *
   * 导入时刻在循环外取一次，整批订阅共用同一条收件箱基线——源里早于该时刻发布的剧集
   * 都是导入时既已存在的内容，落「未播放」不进收件箱；以后新发布的单集才会进收件箱。
   */
  async importSelected(): Promise<void> {
    this.loading = true;
    let added: number = 0;
    const importBaseline: number = Date.now();
    try {
      for (const item of this.items) {
        if (!item.selected) {
          continue;
        }
        try {
          const feed: Feed | undefined = await SubscriptionService.subscribeDeferred(
            item.text, item.xmlUrl, item.htmlUrl, importBaseline);
          if (feed !== undefined) {
            added++;
          }
        } catch (error) {
          Logger.warn(TAG, 'import failed for ' + item.xmlUrl + ': ' + (error as Error).message);
        }
      }
      if (added === 0) {
        // 全部已订阅过：留在本页给出提示，不跳走
        this.message = getContext(this).resourceManager.getStringSync($r('app.string.opml_imported')) + added;
        return;
      }
      this.items = [];
      const data: FeedUpdateData = { feedId: 0 };
      EventHub.publish(EventType.FEED_LIST_UPDATE, data);
      MessageHelper.show(getContext(this).resourceManager
        .getStringSync($r('app.string.opml_import_queued'), added.toString()));
      // 后台刷新：不 await（用户不必在导入页等），订阅页的刷新指示与完成后的列表刷新都走既有 REFRESH_STATE / FEED_LIST_UPDATE
      RefreshService.refreshAll().catch((error: Error) => {
        Logger.warn(TAG, 'background refresh failed: ' + error.message);
      });
      // 回到订阅页（上游 doImport 成功后 startActivity(MainActivity) + finish）
      router.back({ url: 'pages/Index' });
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
      options.newFileNames = ['homenapod-opml.xml'];
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

  static parseOutlines(xml: string): OpmlSelectionItem[] {
    const outlines: OpmlSelectionItem[] = [];
    let current: OpmlSelectionItem | undefined = undefined;
    XmlReader.parse(xml, {
      onStart: (tag: XmlTag): void => {
        if (tag.name.toLowerCase() === 'outline') {
          const xmlUrl: string = tag.getAttribute('xmlUrl');
          if (xmlUrl !== '') {
            const text: string = tag.getAttribute('text') !== '' ? tag.getAttribute('text') : tag.getAttribute('title');
            current = {
              text: text !== '' ? text : xmlUrl,
              xmlUrl: xmlUrl,
              htmlUrl: tag.getAttribute('htmlUrl'),
              selected: false
            };
          }
        }
      },
      onEnd: (name: string): void => {
        if (name.toLowerCase() === 'outline' && current !== undefined) {
          outlines.push(current);
          current = undefined;
        }
      },
      onText: (text: string): void => undefined,
      onAttribute: (name: string, value: string): void => undefined
    });
    return outlines;
  }
}
