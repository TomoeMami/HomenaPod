// Port of: storage/database/PodDBAdapter.java -> HarmonyOS relationalStore
import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { DB_NAME, DB_VERSION, DDL } from './Tables';
import { DbMigration } from './DbMigration';

export class DbManager {
  private static store: relationalStore.RdbStore | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    if (DbManager.store !== undefined) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    const oldVersion: number = store.version;
    for (const sql of DDL) {
      await store.executeSql(sql);
    }
    await DbMigration.migrate(store, oldVersion, DB_VERSION);
    store.version = DB_VERSION;
    DbManager.store = store;
  }

  static getStore(): relationalStore.RdbStore {
    if (DbManager.store === undefined) {
      throw new Error('DbManager not initialized');
    }
    return DbManager.store;
  }

  static async insert(table: string, values: relationalStore.ValuesBucket): Promise<number> {
    return await DbManager.getStore().insert(table, values);
  }

  static async querySql(sql: string): Promise<relationalStore.ResultSet> {
    return await DbManager.getStore().querySql(sql);
  }

  static async executeSql(sql: string): Promise<void> {
    await DbManager.getStore().executeSql(sql);
  }
}
