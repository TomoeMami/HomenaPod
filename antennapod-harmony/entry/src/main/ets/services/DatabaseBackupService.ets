// Port of: storage/importexport/DatabaseExporter.java（AntennaPod 的整库备份/恢复）
//
// 上游把 SQLite 库文件整份拷出来/拷回去（备份时先 wal checkpoint，恢复时校验
// `db.getVersion() > PodDBAdapter.VERSION` 就拒绝降级）。HarmonyOS 的对应物是
// relationalStore 自带的 `backup()` / `restore()`（官方《数据库备份与恢复》：
// 备份文件默认与数据库同目录，即 `context.databaseDir + '/rdb/'`，也可给绝对路径）。
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../db/DbManager';
import { DB_VERSION } from '../db/Tables';
import { SqliteHeader, SqliteHeaderInfo } from '../utils/SqliteHeader';
import { Logger } from '../utils/Logger';

const TAG: string = 'DatabaseBackup';

/** RDB 目录（= 数据库文件所在目录；`backup()`/`restore()` 的相对名都相对它解析） */
const RDB_DIR: string = '/rdb';
/** 导出用的临时备份名（库目录内，导出完即删） */
const EXPORT_TEMP_NAME: string = 'homenapod-export-tmp.db';
/** 导入用的临时库文件名（拷进来交给 restore()，恢复完即删） */
const IMPORT_TEMP_NAME: string = 'homenapod-import-tmp.db';
/** SQLite 文件头长度（前 100 字节，也足够读出 user_version） */
const HEADER_SIZE: number = 100;

/** 上游 DatabaseExporter.importBackup 的版本闸门所需的文件信息 */
export interface DatabaseHeaderInfo {
  /** 前 16 字节是否为 "SQLite format 3\0" */
  isSqlite: boolean;
  /** SQLite 头的 offset 60（big-endian int32）= `PRAGMA user_version`，即上游的 db.getVersion() */
  userVersion: number;
  /** 是否由更新版本的 HomenaPod 导出（上游 import_no_downgrade 的判据） */
  tooNew: boolean;
  /** 文件字节数 */
  size: number;
}

/**
 * 整库导入导出（对照上游设置里的「Database export / Database import」）：
 * 导出 = 把当前 RDB 的一致性快照写成单个 .db 文件；导入 = 用用户选的文件整体替换当前库。
 * 覆盖范围与上游一致：订阅、单集、播放进度、队列、收藏、收听历史（下载的音频文件不在备份里）。
 */
export class DatabaseBackupService {
  /** 默认导出文件名：上游 `AntennaPodBackup-%s.db`（%s = yyyy-MM-dd）的同款 */
  static defaultFileName(date: Date): string {
    return 'homenapod-backup-' + DatabaseBackupService.dateStamp(date) + '.db';
  }

  /** `yyyy-MM-dd`（本地时区） */
  static dateStamp(date: Date): string {
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    return date.getFullYear().toString() + '-' + DatabaseBackupService.pad2(month)
      + '-' + DatabaseBackupService.pad2(day);
  }

  /** 判定一个 .db 文件是不是 SQLite 库、由哪个库版本写出（纯逻辑在 SqliteHeader 里，可单测） */
  static inspectHeader(bytes: Uint8Array, size: number = -1): DatabaseHeaderInfo {
    const header: SqliteHeaderInfo = SqliteHeader.parse(bytes);
    return {
      isSqlite: header.isSqlite,
      userVersion: header.userVersion,
      tooNew: header.isSqlite && header.userVersion > DB_VERSION,
      size: size
    };
  }

  /** 只读文件头，拿到 SQLite 判定与库版本（不把整个备份读进内存） */
  static async describeFile(uri: string): Promise<DatabaseHeaderInfo> {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const size: number = fs.statSync(file.fd).size;
      const buffer: ArrayBuffer = new ArrayBuffer(Math.min(HEADER_SIZE, size));
      if (size > 0) {
        fs.readSync(file.fd, buffer);
      }
      return DatabaseBackupService.inspectHeader(new Uint8Array(buffer), size);
    } finally {
      fs.closeSync(file);
    }
  }

  /**
   * 导出整库到用户选择的目标（对照上游 `DatabaseExporter.exportToDocument`）：
   * 先 `backup()` 出与库同目录的临时快照（这一步保证 WAL 里的数据也在快照里），
   * 再整体拷到目标 uri，最后按字节数核对（上游同样核对写入量），并删掉临时快照。
   *
   * @returns 写出的字节数
   */
  static async exportTo(uri: string, context: common.Context): Promise<number> {
    const store: relationalStore.RdbStore = DbManager.getStore();
    const dir: string = context.databaseDir + RDB_DIR;
    const tempPath: string = dir + '/' + EXPORT_TEMP_NAME;
    DatabaseBackupService.deleteIfExists(tempPath);
    try {
      await store.backup(tempPath);
      const expected: number = fs.statSync(tempPath).size;
      if (expected <= 0) {
        throw new Error('backup produced an empty file');
      }
      const dest: fs.File = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      let written: number = 0;
      try {
        fs.copyFileSync(tempPath, dest.fd);
        written = fs.statSync(dest.fd).size;
      } finally {
        fs.closeSync(dest);
      }
      if (written !== expected) {
        throw new Error('wrote ' + written + ' bytes, expected ' + expected);
      }
      Logger.info(TAG, 'exported database: ' + written + ' bytes');
      return written;
    } finally {
      DatabaseBackupService.deleteIfExists(tempPath);
    }
  }

  /**
   * 用备份文件整体替换当前库（对照上游 `DatabaseExporter.importBackup`）：
   * 先按 SQLite 头校验「是不是库」「是不是更新版本导出的（拒绝降级）」，
   * 再把文件拷进库目录交给 `store.restore()`，最后删掉临时文件。
   *
   * 恢复后当前进程里的 store 已指向新数据，但各页面的内存缓存（订阅列表、队列、首页）仍是旧的，
   * 因此调用方必须重启应用（上游 `forceRestart()` 同理）。
   */
  static async importFrom(uri: string, context: common.Context): Promise<void> {
    const info: DatabaseHeaderInfo = await DatabaseBackupService.describeFile(uri);
    if (!info.isSqlite) {
      throw new Error('not a SQLite database');
    }
    if (info.tooNew) {
      throw new Error('database version ' + info.userVersion + ' is newer than ' + DB_VERSION);
    }
    const store: relationalStore.RdbStore = DbManager.getStore();
    const dir: string = context.databaseDir + RDB_DIR;
    const tempPath: string = dir + '/' + IMPORT_TEMP_NAME;
    DatabaseBackupService.deleteIfExists(tempPath);
    try {
      const src: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const dest: fs.File = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.copyFileSync(src.fd, dest.fd);
      } finally {
        fs.closeSync(src);
        fs.closeSync(dest);
      }
      const copied: number = fs.statSync(tempPath).size;
      if (copied !== info.size) {
        throw new Error('copied ' + copied + ' bytes, expected ' + info.size);
      }
      await store.restore(tempPath);
      Logger.info(TAG, 'restored database from backup: ' + copied + ' bytes');
    } finally {
      DatabaseBackupService.deleteIfExists(tempPath);
    }
  }

  private static deleteIfExists(path: string): void {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (error) {
      Logger.warn(TAG, 'delete ' + path + ' failed: ' + (error as Error).message);
    }
  }

  private static pad2(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }
}
