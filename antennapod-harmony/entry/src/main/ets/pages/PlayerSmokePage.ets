// Temporary smoke page for T2 verification (remove in M3)
import { PlayerManager } from '../player/PlayerManager';
import { Playable } from '../model/Playable';
import { MediaType } from '../model/Enums';
import { FeedFetcher } from '../services/FeedFetcher';

@Entry
@Component
struct PlayerSmokePage {
  @State url: string = '';
  @State status: string = 'IDLE';
  @State positionText: string = '0 / 0';

  build() {
    Column({ space: 12 }) {
      Text($r('app.string.player_smoke_title')).fontSize(20).fontWeight(FontWeight.Bold)
      TextInput({ placeholder: 'Audio URL', text: this.url })
        .onChange((value: string) => {
          this.url = value;
        })
        .width('90%')
      Text('Status: ' + this.status).fontSize(14)
      Text(this.positionText).fontSize(14)
      Row({ space: 8 }) {
        Button($r('app.string.player_play'))
          .onClick(() => {
            this.loadAndPlay();
          })
        Button($r('app.string.player_pause'))
          .onClick(() => {
            PlayerManager.pause();
          })
        Button($r('app.string.player_seek_30'))
          .onClick(() => {
            PlayerManager.seekBy(30000);
          })
        Button($r('app.string.player_speed_15'))
          .onClick(() => {
            PlayerManager.setSpeed(1.5, 'smoke');
          })
      }
      Button($r('app.string.player_smoke_load_feed'))
        .onClick(() => {
          this.loadFeed();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  async loadAndPlay(): Promise<void> {
    if (this.url === '') {
      return;
    }
    const playable: Playable = new Playable(0, 0, 'Smoke Episode', 'Smoke Feed', this.url, '', 0, 0, MediaType.AUDIO);
    await PlayerManager.load(playable, 0, true);
    this.status = PlayerManager.getStatus();
  }

  async loadFeed(): Promise<void> {
    if (this.url === '') {
      return;
    }
    try {
      const result = await FeedFetcher.fetchFeed(this.url);
      this.status = 'Parsed feed: ' + result.feed.getTitle() + ' (' + result.feed.items.length + ')';
    } catch (error) {
      this.status = 'Parse failed: ' + (error as Error).message;
    }
  }
}
