import { DownloadLogEntry } from '../model/DownloadLogEntry';
import { DownloadLogRepository } from '../db/repositories/DownloadLogRepository';
import { LazyDataSource } from '../components/LazyDataSource';

@Component
export struct DownloadsPage {
  private dataSource: LazyDataSource<DownloadLogEntry> = new LazyDataSource<DownloadLogEntry>();
  @State entries: DownloadLogEntry[] = [];
  @State loading: boolean = false;

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.tab_downloads')).fontSize(22).fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 16, top: 8 })
      if (this.loading) {
        Text($r('app.string.loading')).fontSize(14).fontColor($r('app.color.text_secondary')).layoutWeight(1)
      } else if (this.entries.length === 0) {
        Column({ space: 8 }) {
          Text($r('app.string.placeholder_downloads')).fontSize(14).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          LazyForEach(this.dataSource, (entry: DownloadLogEntry) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(entry.downloadStatusTitle).fontSize(15).layoutWeight(1)
                Text(entry.successful ? $r('app.string.download_ok') : $r('app.string.download_fail'))
                  .fontSize(12)
                  .fontColor(entry.successful ? '#00AA00' : '#CC0000')
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(8)
            }
          }, (entry: DownloadLogEntry) => entry.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  onAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const entries: DownloadLogEntry[] = await DownloadLogRepository.list();
      this.entries = entries;
      this.dataSource.setData(entries);
    } catch (error) {
      this.entries = [];
      this.dataSource.setData([]);
    } finally {
      this.loading = false;
    }
  }
}
