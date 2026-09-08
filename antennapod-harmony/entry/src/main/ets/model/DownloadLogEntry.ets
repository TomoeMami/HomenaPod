// Port of: model/download/DownloadResult.java + storage/database DownloadLog row
export class DownloadLogEntry {
  id: number = 0;
  feedFileId: number = 0;
  feedFileType: number = 0;
  reason: number = 0;
  successful: boolean = false;
  completionDate: number = 0;
  reasonDetailed: string = '';
  downloadStatusTitle: string = '';

  constructor(id: number, feedFileId: number, feedFileType: number, reason: number,
              successful: boolean, completionDate: number, reasonDetailed: string,
              downloadStatusTitle: string) {
    this.id = id;
    this.feedFileId = feedFileId;
    this.feedFileType = feedFileType;
    this.reason = reason;
    this.successful = successful;
    this.completionDate = completionDate;
    this.reasonDetailed = reasonDetailed;
    this.downloadStatusTitle = downloadStatusTitle;
  }
}
