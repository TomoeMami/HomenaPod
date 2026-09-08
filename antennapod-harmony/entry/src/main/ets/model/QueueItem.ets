// Port of: storage/database Queue table
export class QueueItem {
  id: number = 0;
  feedItemId: number = 0;
  feedId: number = 0;

  constructor(id: number, feedItemId: number, feedId: number) {
    this.id = id;
    this.feedItemId = feedItemId;
    this.feedId = feedId;
  }

  toValues(): Record<string, number> {
    return { id: this.id, feeditem: this.feedItemId, feed: this.feedId };
  }
}
