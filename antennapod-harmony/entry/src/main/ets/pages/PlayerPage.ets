import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { SleepTimer } from '../player/SleepTimer';
import { ChapterRepository } from '../db/repositories/ChapterRepository';
import { Chapter } from '../model/Chapter';

@Entry
@Component
struct PlayerPage {
  @State title: string = '';
  @State status: string = 'IDLE';
  @State playPosition: number = 0;
  @State duration: number = 0;
  @State chapters: Chapter[] = [];
  private timerId: number = -1;

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.player_title')).fontSize(22).fontWeight(FontWeight.Bold)
      Text(this.title === '' ? $r('app.string.player_no_playback') : this.title).fontSize(18)
      Text('Status: ' + this.status)
      Text(Math.floor(this.playPosition / 1000) + ' / ' + Math.floor(this.duration / 1000) + ' s')
      Slider({
        value: this.playPosition,
        min: 0,
        max: this.duration > 0 ? this.duration : 1
      })
        .onChange((value: number) => {
          PlayerManager.seek(value);
        })
        .width('90%')
      Row({ space: 12 }) {
        Button($r('app.string.player_play')).onClick(() => {
          PlayerManager.play();
        })
        Button($r('app.string.player_pause')).onClick(() => {
          PlayerManager.pause();
        })
        Button($r('app.string.player_speed_15')).onClick(() => {
          PlayerManager.setSpeed(1.5);
        })
      }
      Button($r('app.string.player_seek_30')).onClick(() => {
        PlayerManager.seekBy(30000);
      })
      Button($r('app.string.player_sleep_15')).onClick(() => {
        SleepTimer.start(15, () => {
          PlayerManager.pause();
        });
      })
      if (this.chapters.length > 0) {
        Text($r('app.string.player_chapters')).fontSize(16).fontWeight(FontWeight.Bold)
        List({ space: 4 }) {
          ForEach(this.chapters, (chapter: Chapter) => {
            ListItem() {
              Text(chapter.title).fontSize(14).padding(8)
                .onClick(() => {
                  PlayerManager.seek(chapter.start);
                })
            }
          }, (chapter: Chapter) => chapter.id.toString())
        }
        .height(160)
        .width('90%')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  aboutToAppear(): void {
    this.refresh();
    if (this.timerId < 0) {
      this.timerId = setInterval(() => {
        this.refresh();
      }, 1000);
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  async refresh(): Promise<void> {
    const playable: Playable | undefined = PlayerManager.getCurrent();
    if (playable !== undefined) {
      this.title = playable.title;
      if (playable.feedItemId > 0) {
        try {
          this.chapters = await ChapterRepository.listByFeedItem(playable.feedItemId);
        } catch (error) {
          this.chapters = [];
        }
      } else {
        this.chapters = [];
      }
    }
    this.status = PlayerManager.getStatus();
    this.playPosition = PlayerManager.getCurrentTime();
    this.duration = PlayerManager.getDuration();
  }
}
