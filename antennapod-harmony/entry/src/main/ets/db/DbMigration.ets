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
    // v1 -> v2 预留：后续如需新增列/索引，在此追加 ALTER TABLE / CREATE INDEX。
    void store;
  }
}
