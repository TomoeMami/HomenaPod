// Port of: storage/database SimpleChapters table operations
import relationalStore from '@ohos.data.relationalStore';
import { DbManager } from '../DbManager';
import { TABLE_SIMPLECHAPTERS } from '../Tables';
import { Chapter } from '../../model/Chapter';

export class ChapterRepository {
  static async listByFeedItem(feedItemId: number): Promise<Chapter[]> {
    const rs: relationalStore.ResultSet = await DbManager.querySql(
      `SELECT * FROM ${TABLE_SIMPLECHAPTERS} WHERE feeditem = ${feedItemId} ORDER BY start`
    );
    const chapters: Chapter[] = [];
    if (rs.goToFirstRow()) {
      do {
        const id: number = rs.getLong(rs.getColumnIndex('id'));
        const title: string = rs.getString(rs.getColumnIndex('title'));
        const start: number = rs.getLong(rs.getColumnIndex('start'));
        const link: string = ChapterRepository.str(rs, 'link');
        const imageUrl: string = ChapterRepository.str(rs, 'image_url');
        chapters.push(new Chapter(id, title, start, feedItemId, link, imageUrl));
      } while (rs.goToNextRow());
    }
    rs.close();
    return chapters;
  }

  static async add(chapter: Chapter): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      title: chapter.title,
      start: chapter.start,
      feeditem: chapter.feedItemId,
      link: chapter.link,
      image_url: chapter.imageUrl
    };
    return await DbManager.insert(TABLE_SIMPLECHAPTERS, values);
  }

  static async clearByFeedItem(feedItemId: number): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_SIMPLECHAPTERS);
    predicates.equalTo('feeditem', feedItemId);
    await DbManager.getStore().delete(predicates);
  }

  private static str(rs: relationalStore.ResultSet, column: string): string {
    const index: number = rs.getColumnIndex(column);
    if (index < 0 || rs.isColumnNull(index)) {
      return '';
    }
    return rs.getString(index);
  }
}
