// Port of: storage/importexport OpmlImporter/OpmlExporter
import { Feed } from '../model/Feed';
import { SubscriptionService } from './SubscriptionService';
import { XmlReader, XmlTag } from '../parser/XmlReader';
import { Logger } from '../utils/Logger';

const TAG: string = 'OpmlService';

export interface OpmlOutline {
  text: string;
  xmlUrl: string;
  htmlUrl: string;
}

export class OpmlService {
  static exportOpml(feeds: Feed[]): string {
    let body: string = '<?xml version="1.0" encoding="UTF-8"?>\n<opml version="2.0">\n<head><title>AntennaPod Subscriptions</title></head>\n<body>\n';
    for (const feed of feeds) {
      const title: string = OpmlService.escapeXml(feed.getTitle());
      const xmlUrl: string = OpmlService.escapeXml(feed.downloadUrl);
      const htmlUrl: string = OpmlService.escapeXml(feed.link);
      body += `  <outline text="${title}" title="${title}" type="rss" xmlUrl="${xmlUrl}" htmlUrl="${htmlUrl}"/>\n`;
    }
    body += '</body>\n</opml>\n';
    return body;
  }

  static async importOpml(xml: string): Promise<Feed[]> {
    const outlines: OpmlOutline[] = [];
    let currentOutline: OpmlOutline | undefined = undefined;
    XmlReader.parse(xml, {
      onStart: (tag: XmlTag): void => {
        if (tag.name.toLowerCase() === 'outline') {
          const xmlUrl: string = tag.getAttribute('xmlUrl');
          if (xmlUrl !== '') {
            currentOutline = {
              text: tag.getAttribute('text') !== '' ? tag.getAttribute('text') : tag.getAttribute('title'),
              xmlUrl: xmlUrl,
              htmlUrl: tag.getAttribute('htmlUrl')
            };
          }
        }
      },
      onEnd: (name: string): void => {
        if (name.toLowerCase() === 'outline' && currentOutline !== undefined) {
          outlines.push(currentOutline);
          currentOutline = undefined;
        }
      },
      onText: (text: string): void => undefined,
      onAttribute: (name: string, value: string): void => undefined
    });
    const imported: Feed[] = [];
    for (const outline of outlines) {
      try {
        const feed: Feed = await SubscriptionService.subscribe(outline.xmlUrl);
        imported.push(feed);
      } catch (error) {
        Logger.warn(TAG, 'import failed for ' + outline.xmlUrl + ': ' + (error as Error).message);
      }
    }
    return imported;
  }

  private static escapeXml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }
}
