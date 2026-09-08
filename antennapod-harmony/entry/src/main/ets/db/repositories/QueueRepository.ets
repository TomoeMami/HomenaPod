// Port of: storage/database Queue table + ItemEnqueuePositionCalculator.java
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_QUEUE } from '../Tables';
import { QueueItem } from '../../model/QueueItem';
import { QueueMapper } from '../mappers/QueueMapper';

export class QueueRepository {
  static async list(): Promise<QueueItem[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_QUEUE} ORDER BY id`
    );
    const items: QueueItem[] = [];
    if (rs.goToFirstRow()) {
      do {
        items.push(QueueMapper.map(rs));
      } while (rs.goToNextRow());
    }
    rs.close();
    return items;
  }

  static async add(feedItemId: number, feedId: number): Promise<void> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT COALESCE(MAX(id), 0) AS maxId FROM ${TABLE_QUEUE}`
    );
    let nextId: number = 1;
    if (rs.goToFirstRow()) {
      nextId = rs.getLong(rs.getColumnIndex('maxId')) + 1;
    }
    rs.close();
    const values: relationalStore.ValuesBucket = {
      id: nextId,
      feeditem: feedItemId,
      feed: feedId
    };
    await DbManager.insert(TABLE_QUEUE, values);
  }

  static async remove(feedItemId: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_QUEUE);
    predicates.equalTo('feeditem', feedItemId);
    await DbManager.getStore().delete(predicates);
  }

  static async clear(): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_QUEUE);
    await DbManager.getStore().delete(predicates);
  }

  static async move(feedItemId: number, targetIndex: number): Promise<void> {
    const items: QueueItem[] = await QueueRepository.list();
    const currentIndex: number = items.findIndex((item: QueueItem) => item.feedItemId === feedItemId);
    if (currentIndex < 0) {
      return;
    }
    const moved: QueueItem = items[currentIndex];
    items.splice(currentIndex, 1);
    items.splice(targetIndex, 0, moved);
    for (let i: number = 0; i < items.length; i++) {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_QUEUE);
      predicates.equalTo('id', items[i].id);
      const values: relationalStore.ValuesBucket = { id: i + 1, feeditem: items[i].feedItemId, feed: items[i].feedId };
      await DbManager.getStore().update(values, predicates);
    }
  }
}
