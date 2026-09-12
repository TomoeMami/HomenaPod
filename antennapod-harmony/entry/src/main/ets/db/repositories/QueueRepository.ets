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

  /** 插入到指定位置（0=队首），内部用 add + move 完成重编号 */
  static async addAt(feedItemId: number, feedId: number, index: number): Promise<void> {
    await QueueRepository.add(feedItemId, feedId);
    if (index > 0) {
      await QueueRepository.move(feedItemId, index);
    }
  }

  /** 整体替换队列顺序（排序/随机/智能乱序使用） */
  static async replaceOrder(items: QueueItem[]): Promise<void> {
    await QueueRepository.clear();
    for (const item of items) {
      await QueueRepository.add(item.feedItemId, item.feedId);
    }
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
    // 不能就地重写 id：Queue.id 是主键，把 id=2 改成 id=1 会撞上已有行，
    // 整条 update 失败后移动静默失效。改为整体重排（clear + 按序 add，id 重新从 1 递增）。
    await QueueRepository.replaceOrder(items);
  }
}
