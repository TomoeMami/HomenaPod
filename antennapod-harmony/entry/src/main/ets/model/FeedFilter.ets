// Port of: model/src/main/java/de/danoeh/antennapod/model/feed/FeedFilter.java
import { FeedItem } from './FeedItem';

export class FeedFilter {
  private includeFilter: string;
  private excludeFilter: string;
  private minimalDuration: number;

  constructor(includeFilter: string = '', excludeFilter: string = '', minimalDuration: number = -1) {
    this.includeFilter = includeFilter;
    this.excludeFilter = excludeFilter;
    this.minimalDuration = minimalDuration;
  }

  shouldAutoDownload(item: FeedItem): boolean {
    const includeTerms: string[] = this.parseTerms(this.includeFilter);
    const excludeTerms: string[] = this.parseTerms(this.excludeFilter);
    if (includeTerms.length === 0 && excludeTerms.length === 0 && this.minimalDuration <= -1) {
      return true;
    }
    if (this.hasMinimalDurationFilter() && item.media !== undefined) {
      const durationInMs: number = item.media.duration;
      if (durationInMs > 0 && Math.floor(durationInMs / 1000) < this.minimalDuration) {
        return false;
      }
    }
    const title: string = item.title.toLowerCase();
    for (const term of excludeTerms) {
      if (title.indexOf(term.trim().toLowerCase()) >= 0) {
        return false;
      }
    }
    for (const term of includeTerms) {
      if (title.indexOf(term.trim().toLowerCase()) >= 0) {
        return true;
      }
    }
    if (!this.hasIncludeFilter() && this.hasExcludeFilter()) {
      return true;
    }
    if (this.hasMinimalDurationFilter()) {
      return true;
    }
    return false;
  }

  getIncludeFilter(): string[] {
    return this.parseTerms(this.includeFilter);
  }

  getExcludeFilter(): string[] {
    return this.parseTerms(this.excludeFilter);
  }

  getMinimalDurationFilter(): number {
    return this.minimalDuration;
  }

  hasIncludeFilter(): boolean {
    return this.includeFilter.length > 0;
  }

  hasExcludeFilter(): boolean {
    return this.excludeFilter.length > 0;
  }

  hasMinimalDurationFilter(): boolean {
    return this.minimalDuration > -1;
  }

  private parseTerms(filter: string): string[] {
    const terms: string[] = [];
    const pattern: RegExp = /([^"\s]\S*|".+?")\s*/g;
    const matches: RegExpMatchArray[] = [];
    let match: RegExpMatchArray | null = pattern.exec(filter);
    while (match !== null) {
      matches.push(match);
      match = pattern.exec(filter);
    }
    for (const m of matches) {
      terms.push(m[1].replace(/"/g, ''));
    }
    return terms;
  }
}
