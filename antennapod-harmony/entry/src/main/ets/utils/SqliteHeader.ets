// 纯逻辑：SQLite 数据库文件头解析（不 import 任何 @kit.*，可进 runtime-pure-test 回归）
//
// 上游 DatabaseExporter 用 `SQLiteDatabase.openDatabase(...).getVersion()` 判断备份文件的库版本，
// 在 HarmonyOS 上不必真的打开这个文件：SQLite 头的 offset 60（big-endian int32）
// 就是 `PRAGMA user_version`，正是 Android 的 `SQLiteDatabase.getVersion()` 读的那个值，
// 而 relationalStore 的 `store.version` 也落在同一处（见官方《数据库备份与恢复》）。
export interface SqliteHeaderInfo {
  /** 前 16 字节是否为 "SQLite format 3\0" */
  isSqlite: boolean;
  /** `PRAGMA user_version`（读不出/不是 SQLite 时为 0） */
  userVersion: number;
}

export class SqliteHeader {
  /** SQLite 文件头固定 100 字节 */
  static readonly HEADER_SIZE: number = 100;
  /** 版本号在头里的偏移（user_version） */
  static readonly VERSION_OFFSET: number = 60;

  private static readonly MAGIC: string = 'SQLite format 3\u0000';

  /** 解析文件头（bytes 至少要有 100 字节，否则一律判为非 SQLite） */
  static parse(bytes: Uint8Array): SqliteHeaderInfo {
    let isSqlite: boolean = bytes.length >= SqliteHeader.HEADER_SIZE;
    if (isSqlite) {
      for (let i: number = 0; i < SqliteHeader.MAGIC.length; i++) {
        if (bytes[i] !== SqliteHeader.MAGIC.charCodeAt(i)) {
          isSqlite = false;
          break;
        }
      }
    }
    return {
      isSqlite: isSqlite,
      userVersion: isSqlite ? SqliteHeader.readInt32Be(bytes, SqliteHeader.VERSION_OFFSET) : 0
    };
  }

  /** 大端 int32（SQLite 头里的整数都是大端） */
  static readInt32Be(bytes: Uint8Array, offset: number): number {
    let value: number = 0;
    for (let i: number = 0; i < 4; i++) {
      value = value * 256 + bytes[offset + i];
    }
    return value;
  }
}
