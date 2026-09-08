// Port of: storage/database Queue table
export class QueueItemValues {
  id: number = 0;
  feeditem: number = 0;
  feed: number = 0;

  constructor(id: number, feeditem: number, feed: number) {
    this.id = id;
    this.feeditem = feeditem;
    this.feed = feed;
  }
}

export class QueueItem {
  id: number = 0;
  feedItemId: number = 0;
  feedId: number = 0;

  constructor(id: number, feedItemId: number, feedId: number) {
    this.id = id;
    this.feedItemId = feedItemId;
    this.feedId = feedId;
  }

  toValues(): QueueItemValues {
    return new QueueItemValues(this.id, this.feedItemId, this.feedId);
  }
}
