// Port of: storage/database/DBUpgrader.java -> HarmonyOS relationalStore migration skeleton
import relationalStore from '@ohos.data.relationalStore';
import { Logger } from '../utils/Logger';

const TAG: string = 'DbMigration';

export class DbMigration {
  static async migrate(store: relationalStore.RdbStore, fromVersion: number, toVersion: number): Promise<void> {
    if (fromVersion >= toVersion) {
      return;
    }
    Logger.info(TAG, 'migrate db from ' + fromVersion + ' to ' + toVersion);
    if (fromVersion < 2) {
      await DbMigration.migrateTo2(store);
    }
    store.version = toVersion;
    Logger.info(TAG, 'migration done');
  }

  private static async migrateTo2(store: relationalStore.RdbStore): Promise<void> {
    // v1 -> v2：Feeds 新增「收件箱基线」列（= 订阅 / 批量导入时刻）。
    // 早于基线发布的单集落库为「未播放」而非「新」，因此不会灌进收件箱。
    if (!await DbMigration.columnExists(store, 'Feeds', 'inbox_baseline')) {
      await store.executeSql('ALTER TABLE Feeds ADD COLUMN inbox_baseline INTEGER DEFAULT 0');
    }
    // 存量订阅回填：以「最近一次刷新时刻」作为基线，避免继续把历史剧集当新单集收进收件箱。
    // 不回写已入库单集的 read 值（不动用户已有的收件箱内容）。
    await store.executeSql(
      'UPDATE Feeds SET inbox_baseline = last_refresh_attempt '
      + 'WHERE (inbox_baseline IS NULL OR inbox_baseline = 0) AND last_refresh_attempt > 0'
    );
  }

  /** 列是否已存在：新库由 DDL 直接建出该列，只有旧库才需要 ALTER TABLE */
  private static async columnExists(store: relationalStore.RdbStore, table: string,
                                    column: string): Promise<boolean> {
    try {
      const rs: relationalStore.ResultSet = await store.querySql('PRAGMA table_info(' + table + ')');
      let found: boolean = false;
      if (rs.goToFirstRow()) {
        do {
          const nameIndex: number = rs.getColumnIndex('name');
          if (nameIndex >= 0 && rs.getString(nameIndex) === column) {
            found = true;
            break;
          }
        } while (rs.goToNextRow());
      }
      rs.close();
      return found;
    } catch (error) {
      Logger.warn(TAG, 'PRAGMA table_info(' + table + ') failed: ' + (error as Error).message);
      return false;
    }
  }
}
