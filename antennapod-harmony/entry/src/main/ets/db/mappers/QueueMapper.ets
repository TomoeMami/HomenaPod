// Port of: storage/database Queue table row
import relationalStore from '@ohos.data.relationalStore';
import { QueueItem } from '../../model/QueueItem';

export class QueueMapper {
  static map(rs: relationalStore.ResultSet): QueueItem {
    return new QueueItem(
      rs.getLong(rs.getColumnIndex('id')),
      rs.getLong(rs.getColumnIndex('feeditem')),
      rs.getLong(rs.getColumnIndex('feed'))
    );
  }
}
