// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/Chapter.java
export class Chapter {
  id: number = 0;
  title: string = '';
  start: number = 0;
  feedItemId: number = 0;
  link: string = '';
  imageUrl: string = '';

  constructor(id: number, title: string, start: number, feedItemId: number, link: string, imageUrl: string) {
    this.id = id;
    this.title = title;
    this.start = start;
    this.feedItemId = feedItemId;
    this.link = link;
    this.imageUrl = imageUrl;
  }
}
