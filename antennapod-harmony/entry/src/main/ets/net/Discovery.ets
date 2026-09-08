// Port of: net/discovery/{ItunesPodcastSearcher,PodcastSearchResult}.java
import { HttpClient, HttpResponse } from './HttpClient';

export interface PodcastSearchResult {
  title: string;
  author: string;
  imageUrl: string;
  feedUrl: string;
}

export class Discovery {
  private static readonly ITUNES_URL: string = 'https://itunes.apple.com/search';

  static async searchPodcasts(term: string): Promise<PodcastSearchResult[]> {
    const url: string = Discovery.ITUNES_URL + '?media=podcast&limit=30&term=' + encodeURIComponent(term);
    const response: HttpResponse = await HttpClient.get(url);
    const data: Record<string, object> = JSON.parse(response.body) as Record<string, object>;
    const results: object[] = data['results'] as object[];
    const output: PodcastSearchResult[] = [];
    for (const raw of results) {
      const item: Record<string, string> = raw as Record<string, string>;
      output.push({
        title: item['collectionName'] !== undefined ? item['collectionName'] : '',
        author: item['artistName'] !== undefined ? item['artistName'] : '',
        imageUrl: item['artworkUrl100'] !== undefined ? item['artworkUrl100'] : '',
        feedUrl: item['feedUrl'] !== undefined ? item['feedUrl'] : ''
      });
    }
    return output;
  }
}
