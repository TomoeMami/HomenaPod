import { describe, it, expect } from '@ohos/hypium';
import { DurationUtils } from '../../main/ets/utils/DurationUtils';
import { DateUtils } from '../../main/ets/utils/DateUtils';
import { MimeTypeUtils } from '../../main/ets/utils/MimeTypeUtils';
import { HtmlCleaner } from '../../main/ets/utils/HtmlCleaner';
import { MediaType } from '../../main/ets/model/Enums';

export default function utilsTest() {
  describe('UtilsRegression', () => {
    it('DurationClock', 0, () => {
      expect(DurationUtils.parseToMillis('01:30')).assertEqual(90000);
      expect(DurationUtils.parseToMillis('1:02:03')).assertEqual(3723000);
    });

    it('DurationIso8601', 0, () => {
      expect(DurationUtils.parseToMillis('PT1H2M3S')).assertEqual(3723000);
      expect(DurationUtils.parseToMillis('PT30S')).assertEqual(30000);
    });

    it('DateRfc3339', 0, () => {
      expect(DateUtils.parseToEpochMillis('1970-01-01T00:00:00Z')).assertEqual(0);
      expect(DateUtils.parseToEpochMillis('1970-01-01T00:01:00Z')).assertEqual(60000);
    });

    it('MimeType', 0, () => {
      expect(MimeTypeUtils.mediaTypeFromMime('audio/mpeg')).assertEqual(MediaType.AUDIO);
      expect(MimeTypeUtils.mediaTypeFromMime('video/mp4')).assertEqual(MediaType.VIDEO);
      expect(MimeTypeUtils.guessExtension('http://x/a.mp3', 'audio/mpeg')).assertEqual('.mp3');
    });

    it('HtmlCleaner', 0, () => {
      expect(HtmlCleaner.stripHtml('<p>Hello <b>World</b></p>')).assertEqual('Hello World');
    });
  });
}
