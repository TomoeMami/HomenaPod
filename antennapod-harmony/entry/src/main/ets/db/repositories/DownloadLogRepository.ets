// Port of: storage/database DownloadLog table + DBWriter.java
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_DOWNLOAD_LOG } from '../Tables';
import { DownloadLogEntry } from '../../model/DownloadLogEntry';
import { DownloadLogMapper } from '../mappers/DownloadLogMapper';

export class DownloadLogRepository {
  static async list(): Promise<DownloadLogEntry[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_DOWNLOAD_LOG} ORDER BY completion_date DESC`
    );
    const entries: DownloadLogEntry[] = [];
    if (rs.goToFirstRow()) {
      do {
        entries.push(DownloadLogMapper.map(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    return entries;
  }

  static async add(entry: DownloadLogEntry): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      feedfile: entry.feedFileId,
      feedfiletype: entry.feedFileType,
      reason: entry.reason,
      successful: entry.successful ? 1 : 0,
      completion_date: entry.completionDate,
      reason_detailed: entry.reasonDetailed,
      downloadstatus_title: entry.downloadStatusTitle
    };
    return await DbManager.insert(TABLE_DOWNLOAD_LOG, values);
  }

  static async clear(): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_DOWNLOAD_LOG);
    await DbManager.getStore().delete(predicates);
  }
}
