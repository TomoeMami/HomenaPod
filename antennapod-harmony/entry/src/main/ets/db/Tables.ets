// Port of: storage/database/src/main/java/de/danoeh/antennapod/storage/database/PodDBAdapter.java (CREATE TABLE statements)
export const DB_NAME: string = 'Homenapod.db';
export const DB_VERSION: number = 2;

export const TABLE_FEEDS: string = 'Feeds';
export const TABLE_FEED_ITEMS: string = 'FeedItems';
export const TABLE_FEED_MEDIA: string = 'FeedMedia';
export const TABLE_DOWNLOAD_LOG: string = 'DownloadLog';
export const TABLE_QUEUE: string = 'Queue';
export const TABLE_SIMPLECHAPTERS: string = 'SimpleChapters';
export const TABLE_FAVORITES: string = 'Favorites';

export const DDL: string[] = [
  `CREATE TABLE IF NOT EXISTS Feeds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    custom_title TEXT,
    file_url TEXT,
    download_url TEXT,
    last_refresh_attempt INTEGER,
    link TEXT,
    description TEXT,
    payment_link TEXT,
    last_update TEXT,
    language TEXT,
    author TEXT,
    image_url TEXT,
    type TEXT,
    feed_identifier TEXT,
    auto_download_enabled INTEGER DEFAULT 1,
    username TEXT,
    password TEXT,
    include_filter TEXT DEFAULT '',
    exclude_filter TEXT DEFAULT '',
    minimal_duration_filter INTEGER DEFAULT -1,
    keep_updated INTEGER DEFAULT 1,
    is_paged INTEGER DEFAULT 0,
    next_page_link TEXT,
    hide TEXT,
    sort_order TEXT,
    last_update_failed INTEGER DEFAULT 0,
    auto_delete_action INTEGER DEFAULT 0,
    feed_playback_speed REAL DEFAULT 0,
    feed_skip_silence INTEGER DEFAULT 0,
    feed_volume_adaption INTEGER DEFAULT 0,
    feed_tags TEXT,
    feed_skip_intro INTEGER DEFAULT 0,
    feed_skip_ending INTEGER DEFAULT 0,
    episode_notification INTEGER DEFAULT 0,
    state INTEGER DEFAULT 1,
    new_episodes_action INTEGER DEFAULT 0,
    inbox_baseline INTEGER DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS FeedItems (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    pubdate INTEGER,
    read INTEGER,
    link TEXT,
    description TEXT,
    payment_link TEXT,
    media INTEGER,
    feed INTEGER,
    has_chapters INTEGER,
    item_identifier TEXT,
    image_url TEXT,
    auto_download_enabled INTEGER,
    podcastindex_chapter_url TEXT,
    podcastindex_transcript_type TEXT,
    podcastindex_transcript_url TEXT,
    social_interact_url TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS FeedMedia (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    duration INTEGER,
    file_url TEXT,
    download_url TEXT,
    download_date INTEGER,
    position INTEGER,
    size INTEGER,
    mime_type TEXT,
    last_played_time_history INTEGER,
    feeditem INTEGER,
    played_duration INTEGER,
    has_embedded_picture INTEGER,
    last_played_time_statistics INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS DownloadLog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feedfile INTEGER,
    feedfiletype INTEGER,
    reason INTEGER,
    successful INTEGER,
    completion_date INTEGER,
    reason_detailed TEXT,
    downloadstatus_title TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS Queue (
    id INTEGER PRIMARY KEY,
    feeditem INTEGER,
    feed INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS SimpleChapters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    start INTEGER,
    feeditem INTEGER,
    link TEXT,
    image_url TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS Favorites (
    id INTEGER PRIMARY KEY,
    feeditem INTEGER,
    feed INTEGER
  )`,
  `CREATE INDEX IF NOT EXISTS FeedItems_feed ON FeedItems (feed)`,
  `CREATE INDEX IF NOT EXISTS FeedItems_pubdate ON FeedItems (pubdate)`,
  `CREATE INDEX IF NOT EXISTS FeedItems_read ON FeedItems (read)`,
  `CREATE INDEX IF NOT EXISTS Queue_feeditem ON Queue (feeditem)`,
  `CREATE INDEX IF NOT EXISTS FeedMedia_feeditem ON FeedMedia (feeditem)`,
  `CREATE INDEX IF NOT EXISTS SimpleChapters_feeditem ON SimpleChapters (feeditem)`
];
