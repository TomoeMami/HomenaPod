// Port of: storage/database DownloadLog table row
import relationalStore from '@ohos.data.relationalStore';
import { DownloadLogEntry } from '../../model/DownloadLogEntry';

export class DownloadLogMapper {
  static map(rs: relationalStore.ResultSet): DownloadLogEntry {
    return new DownloadLogEntry(
      rs.getLong(rs.getColumnIndex('id')),
      rs.getLong(rs.getColumnIndex('feedfile')),
      rs.getLong(rs.getColumnIndex('feedfiletype')),
      rs.getLong(rs.getColumnIndex('reason')),
      rs.getLong(rs.getColumnIndex('successful')) !== 0,
      rs.getLong(rs.getColumnIndex('completion_date')),
      DownloadLogMapper.str(rs, 'reason_detailed'),
      DownloadLogMapper.str(rs, 'downloadstatus_title')
    );
  }

  private static str(rs: relationalStore.ResultSet, column: string): string {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return '';
    }
    return rs.getString(index);
  }
}
