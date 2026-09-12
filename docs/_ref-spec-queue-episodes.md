# Reference layout spec — QUEUE screen & EPISODE LIST / FEED DETAIL (AntennaPod Android)

Source: read-only inspection of `antenna-repo/` (shallow clone).
All numbers are Android layout units: **dp** for dimensions, **sp** for text, exactly as written in the XML
unless explicitly marked "computed". Nothing here is HarmonyOS code; this is the Android ground truth.

---

## 0. Source map, tokens and resolved values

### 0.1 Files read

| Concern | Path (relative to `antenna-repo\`) |
|---|---|
| Queue screen | `app/src/main/res/layout/queue_fragment.xml` |
| Queue logic | `app/src/main/java/de/danoeh/antennapod/ui/screen/queue/QueueFragment.java`, `QueueRecyclerAdapter.java` |
| Row (both screens) | `app/src/main/res/layout/feeditemlist_item.xml` + `secondary_action.xml` |
| Row binder | `app/src/main/java/de/danoeh/antennapod/ui/episodeslist/EpisodeItemViewHolder.java`, `EpisodeItemListAdapter.java`, `EpisodeItemListRecyclerView.java` |
| Feed header | `app/src/main/res/layout/feeditemlist_header.xml` |
| Feed detail screen | `app/src/main/res/layout/feed_item_list_fragment.xml`, `app/src/main/java/.../ui/screen/feed/FeedItemlistFragment.java` |
| Feed info screen | `app/src/main/res/layout/feedinfo.xml`, `.../ui/screen/feed/FeedInfoFragment.java` |
| Episodes list screen | `app/src/main/res/layout/episodes_list_fragment.xml`, `.../ui/episodeslist/EpisodesListFragment.java`, `.../ui/screen/AllEpisodesFragment.java` |
| Floating menu | `app/src/main/res/layout/floating_select_menu.xml`, `floating_select_menu_item.xml`, `.../ui/view/FloatingSelectMenu.java` |
| Menus | `app/src/main/res/menu/{queue,queue_context,episodes,feedlist,feedinfo,feeditemlist_context,episodes_apply_action_speeddial,multi_select_options}.xml` |
| Background | `app/src/main/res/drawable/bg_episode_list_item.xml`; `ui/common/src/main/res/drawable/bg_message_{error,info}.xml` |
| Tokens | `ui/common/src/main/res/values/{dimens,colors,styles}.xml`; `app/src/main/res/values/dimens.xml` (+ `values-w300dp`, `values-w1000dp`) |
| Strings | `ui/i18n/src/main/res/values/strings.xml` |
| Empty state | `ui/common/src/main/res/layout/empty_view_layout.xml`, `ui/common/src/main/java/.../ui/common/EmptyViewHandler.java` |

### 0.2 Dimension tokens

| Token | Value | Notes |
|---|---|---|
| `thumbnail_length_queue_item` | **56dp** | cover size in the queue row |
| `thumbnail_length_itemlist` | 56dp | not used by this row (row hardcodes the queue token) |
| `listitem_threeline_verticalpadding` | **11dp** | cover top/bottom margin, text column top/bottom margin |
| `listitem_threeline_textleftpadding` | **16dp** | cover `marginEnd` |
| `listitem_threeline_textrightpadding` | **8dp** | text column `marginEnd` |
| `text_size_large` | **22sp** | feed header title (`AntennaPod.TextView.Heading`) |
| `text_size_small` | **14sp** | feed header author |
| `text_size_micro` | 12sp | (not used here) |
| `floating_select_menu_height` | **112dp** | container height of the multi-select bar |
| `additional_horizontal_spacing` | **0dp** phones / 56dp at `w≥1000dp` | RecyclerView + header horizontal padding |
| `?attr/actionBarSize` | 56dp (Material default) | toolbar height, and header `layout_marginTop` |

Material3 text appearances used (library values, not redefined in this repo):
`BodyLarge` 16sp/24sp · `BodyMedium` 14sp/20sp · `BodySmall` 12sp/16sp · `LabelSmall` 11sp/16sp · `TitleMedium` 16sp/24sp (medium weight).

### 0.3 Custom text styles

| Style | Parent | Overrides |
|---|---|---|
| `AntennaPod.TextView.FeedListItemPrimaryTitle` | `TextAppearance.Material3.BodyLarge` | `maxLines=2`, `ellipsize=end`, `lineHeight=20sp` |
| `AntennaPod.TextView.FeedListItemSecondaryTitle` | `TextAppearance.Material3.LabelSmall` | `lines=1`, `ellipsize=end` |
| `AntennaPod.TextView.Heading` | `@android:style/TextAppearance.Medium` | `textSize=22sp`, `textColor=?android:attr/textColorPrimary`, `fontFamily=sans-serif-light` |
| `Widget.AntennaPod.LinearProgressIndicator` | `Widget.Material3.LinearProgressIndicator` | `trackColor=#55888888` |
| `OutlinedButtonBetterContrast` | `Widget.Material3.Button.OutlinedButton` | `backgroundTint=@color/button_bg_selector` |

### 0.4 Color tokens (resolved, non-dynamic themes)

| Token | Light (`Theme.AntennaPod.Light`) | Dark (`Theme.AntennaPod.Dark`) |
|---|---|---|
| `@color/non_square_icon_background` | `#22777777` | `#22777777` |
| `@color/image_readability_tint` | `#80000000` | `#80000000` |
| `@color/light_gray` | `#bfbfbf` | `#bfbfbf` |
| `@color/medium_gray` | `#afafaf` | `#afafaf` |
| `@color/black` / `@color/white` | `#000000` / `#FFFFFF` | same |
| `?attr/colorOnSurface` | `#000000` | `#FFFFFF` |
| `?attr/colorOnSurfaceVariant` | `#444444` (`text_color_secondary_light`) | `#cccccc` (`text_color_secondary_dark`) |
| `?attr/colorSecondaryContainer` | `#C8D8DE` | `#3C4E68` |
| `?attr/colorAccent` / `colorPrimary` | `#0078C2` (`accent_light`) | `#3D8BFF` (`accent_dark`) |
| `?attr/icon_red` | `#CF1800` | `#CF1800` |
| `?attr/action_icon_color` | `#000000` | `#FFFFFF` |
| `?attr/colorSurfaceContainer` | `#EBEEF3` | `#1C2024` |
| `?android:attr/colorBackground` | `#f9fcff` (`background_light`) | `#21272b` (`background_darktheme`); TrueBlack: `#000000` |

> Dynamic-color themes (`Theme.AntennaPod.Dynamic.*` → `Theme.Material3.DynamicColors.*`) replace every `?attr/*` above with the system palette; the literal `@color/*` values never change.

### 0.5 Icon assets (all vector, all in `ui/common/src/main/res/drawable/`)

`ic_inbox`, `ic_videocam`, `ic_star`, `ic_star_border`, `ic_playlist_play`, `ic_playlist_remove`, `ic_search`, `ic_filter`, `ic_check`, `ic_delete`, `ic_download`, `ic_mark_played`, `ic_mark_unplayed`, `ic_share`, `ic_replay`, `ic_arrow_full_up`, `ic_arrow_full_down`, `ic_web`, `ic_feed` — intrinsic **24×24dp**.
`ic_info_white`, `ic_filter_white`, `ic_settings_white` — white-filled, intrinsic **24×24dp**.
`ic_drag_lighttheme` / `ic_drag_darktheme` — **20dp × 30dp**, 6 filled circles (2 cols × 3 rows, r=0.5 in a 3×4.5 viewport), fill `#9d9d9d` (light) / `#a9a9a9` (dark).
`ic_rounded_corner_left` / `_right` — 24dp intrinsic but rendered **12×12dp**, fill `?attr/background_color`.
`ic_load_more` — 16dp (pagination footer).

---

# A. QUEUE SCREEN

## A.1 Screen skeleton — `queue_fragment.xml`

```
RelativeLayout (match_parent × match_parent)
├─ AppBarLayout#appbar  (match_parent × wrap_content, fitsSystemWindows=true, elevation=0dp)
│  ├─ MaterialToolbar#toolbar (match_parent × ?attr/actionBarSize)
│  └─ TextView#info_bar       (match_parent × wrap_content)
├─ SwipeRefreshLayout#swipeRefresh (match_parent × match_parent, layout_below=#appbar)
│  └─ EpisodeItemListRecyclerView#recyclerView (match_parent × match_parent,
│        paddingHorizontal=@dimen/additional_horizontal_spacing)
├─ ProgressBar#progressBar (wrap_content, centerInParent, indeterminateOnly, visibility=gone)
└─ FloatingSelectMenu#floatingSelectMenu (match_parent × wrap_content, alignParentBottom)
```

* AppBarLayout background is **transparent at rest** and animates to `?attr/colorSurfaceContainer` (`#EBEEF3` light / `#1C2024` dark) when the list is scrolled — `LiftOnScrollListener` drives a `ValueAnimator.ofArgb(0x00RRGGBB → colorSurfaceContainer)`.
* RecyclerView: `hasFixedSize=true`, `clipToPadding=false`, `LinearLayoutManager` vertical, `android:scrollbars=none` + `fastScrollEnabled=true` (`FastScrollRecyclerView` style). Item animator: change animations disabled.
* In multi-select mode the RecyclerView gets `paddingBottom = 112dp` (`floating_select_menu_height`); it is reset to 0 on exit.
* Swipe refresh distance = `@integer/swipe_refresh_distance` = **300** (px).

## A.2 Toolbar

| Property | Value |
|---|---|
| Title | `@string/queue_label` = **"Queue"** |
| Height | `?attr/actionBarSize` = 56dp |
| Navigation icon | `?homeAsUpIndicator`; runtime (`MainActivity.setupToolbarToggle`): drawer hamburger when the drawer exists and no up-arrow is needed, back arrow when `displayUpArrow`, **null** on the tablet layout without a drawer |
| Navigation content description | `@string/toolbar_back_button_content_description` = **"Back"** |
| Overflow icon | Material default (3 dots, `?attr/colorOnSurface`) |
| Menu source | `R.menu.queue`, inflated in `onCreateView` |

Menu items, in XML order (this is the overflow order; `ifRoom`/`collapseActionView` control icon visibility):

| # | id | Title string | Icon | `showAsAction` | Extra |
|---|---|---|---|---|---|
| 1 | `action_search` | "Search" | `ic_search` | `ifRoom` | — |
| 2 | `refresh_item` | "Refresh" | none | `never` | `menuCategory=container` |
| 3 | `queue_lock` | "Lock queue" | none | (default `never`) | `checkable=true`, `menuCategory=container` |
| 4 | `queue_sort` | "Sort" | none | (default `never`) | — |
| 5 | `clear_queue` | "Clear queue" | `ic_check` | `collapseActionView` | — |

* `queue_lock` is hidden (`setVisible(false)`) while "keep sorted" is on; its checked state mirrors `UserPreferences.isQueueLocked()`.
* `clear_queue` opens `ConfirmationDialog("Clear queue", "Please confirm that you want to remove ALL episodes from the queue.")`.
* Long-pressing the toolbar scrolls to item 5 then smooth-scrolls to top.

## A.3 Info bar under the toolbar (`TextView#info_bar`)

| Property | Value |
|---|---|
| Position | 2nd child of `AppBarLayout`, below the toolbar |
| Width × height | `match_parent` × `wrap_content` |
| `layout_marginTop` | **−12dp** (pulls it up against the toolbar) |
| `layout_marginBottom` | **8dp** |
| `paddingHorizontal` (XML) | 16dp — **overridden at runtime** |
| `paddingHorizontal` (runtime) | **60dp** if `displayUpArrow || !isBottomNavigationEnabled()`, else **16dp**; vertical padding forced to 0 |
| `textSize` | **12sp** |
| Text color | not set → theme `?android:attr/textColorPrimary` (`#000000` light, `#FFFFFF` dark) |
| Gravity | default (start) |
| Visibility | `INVISIBLE` while in multi-select action mode, `VISIBLE` otherwise |

**Exact string**: `@string/queue_time_left_label` = **`"%1$s • %2$s left"`** (U+2022 bullet, spaces around it).

* `%1$s` = `@plurals/num_episodes` → `"%d episode"` / `"%d episodes"` (queue size).
* `%2$s` = `Converter.getDurationStringLocalized(res, timeLeft, false)` → hours+minutes only, e.g. `"1 hour 20 minutes"`; NBSP (U+00A0) between number and unit; hours segment omitted when `h == 0`; days never shown here. `timeLeft = Σ (duration − position) / playbackSpeed` over all queue items (speed only applied when the "time respects speed" preference is on).
* Rendered examples: **`12 episodes • 1 hour 20 minutes left`**, `1 episode • 4 minutes left`.
* The `tools:text` in the XML (`"12 Episodes - Time remaining: 12 hours"`) is **stale** — do not use it as the spec.

## A.4 Queue row — `feeditemlist_item.xml` (shared by both screens)

### A.4.1 Geometry tree (exact)

```
FrameLayout (match_parent × wrap_content)          ← wrapper so the ItemAnimator's alpha does not fight the played indicator
└─ LinearLayout#container
     orientation=horizontal, gravity=center_vertical, baselineAligned=false,
     paddingStart=12dp, paddingEnd=0dp,
     background=@drawable/bg_episode_list_item, duplicateParentState=true
   ├─ LinearLayout#left_padding (wrap_content × match_parent, minWidth=4dp)
   │  └─ ImageView#drag_handle
   │       16dp × match_parent, paddingStart=0dp, paddingEnd=4dp,
   │       scaleType=fitCenter, srcCompat=?attr/dragview_background,
   │       importantForAccessibility=no
   ├─ CardView#coverHolder
   │       56dp × 56dp (thumbnail_length_queue_item),
   │       marginTop=11dp, marginBottom=11dp, marginEnd=16dp,
   │       cardCornerRadius=8dp, cardElevation=0dp, cardPreventCornerOverlap=false,
   │       cardBackgroundColor=@color/non_square_icon_background (#22777777)
   │  └─ RelativeLayout (match_parent)
   │     ├─ TextView#txtvPlaceholder 56×56dp, centerVertical, gravity=center,
   │     │       background=@color/light_gray (#bfbfbf), maxLines=3, padding=2dp, ellipsize=end
   │     └─ ImageView#imgvCover    56×56dp, centerVertical
   ├─ LinearLayout (text column)
   │       width=0dp, layout_weight=1, orientation=vertical,
   │       marginTop=11dp, marginBottom=11dp, marginEnd=8dp
   │  ├─ LinearLayout#status (match_parent × wrap_content, horizontal, gravity=center_vertical)
   │  │  ├─ ImageView#statusInbox    12sp × 12sp, src=ic_inbox,          tint=?attr/colorOnSurfaceVariant, cd="In the inbox"
   │  │  ├─ ImageView#ivIsVideo      12sp × 12sp, src=ic_videocam,       tint=?attr/colorOnSurfaceVariant, cd="Video"
   │  │  ├─ ImageView#isFavorite     12sp × 12sp, src=ic_star,           tint=?attr/colorOnSurfaceVariant, cd="Marked as favorite"
   │  │  ├─ ImageView#ivInPlaylist   12sp × 12sp, src=ic_playlist_play,  tint=?attr/colorOnSurfaceVariant, cd="In the queue"
   │  │  ├─ TextView#separatorIcons  "·"  marginStart=4dp marginEnd=4dp  style=FeedListItemSecondaryTitle
   │  │  ├─ TextView#txtvPubDate     marginEnd=4dp                       style=FeedListItemSecondaryTitle
   │  │  ├─ TextView (literal "·")   marginEnd=4dp                       style=FeedListItemSecondaryTitle
   │  │  └─ TextView#size            marginEnd=4dp                       style=FeedListItemSecondaryTitle
   │  ├─ TextView#txtvTitle  wrap_content × wrap_content,
   │  │       style=FeedListItemPrimaryTitle (16sp, lineHeight 20sp, maxLines 2, ellipsize=end),
   │  │       textAlignment=viewStart, importantForAccessibility=no
   │  └─ LinearLayout#progress (match_parent × wrap_content, horizontal, gravity=center_vertical)
   │     ├─ TextView#txtvPosition    style=FeedListItemSecondaryTitle, marginBottom=0dp
   │     ├─ LinearProgressIndicator#progressBar
   │     │       0dp × wrap_content, layout_weight=1, android:max=100,
   │     │       layout_margin=4dp, app:trackStopIndicatorSize=0dp
   │     └─ TextView#txtvDuration    style=FeedListItemSecondaryTitle, marginBottom=0dp
   └─ include#secondaryActionButton → @layout/secondary_action
```

Notes:
* `12sp` is used literally as the *pixel* size of the four status `ImageView`s (12 scaled pixels), i.e. tiny 12-unit icons, not 12dp.
* The status row icons are **not** spaced: no margins between them; only the two literal `·` separators carry 4dp start/end margins.
* The first `·` (`#separatorIcons`) is `GONE` when no status icon is visible (`hideSeparatorIfNecessary()`); the second `·` before the size is **never** hidden (it is a plain, unnamed TextView).
* Text column content order = status row → title → progress row.
* Effective row height: `max(56 + 11 + 11 = 78dp, text column + 22dp)`. With a 2-line title the text column is ≈ 16 (status) + 40 (title) + 16 (progress) = 72dp → row ≈ 94dp.

### A.4.2 Per-row state bindings (`EpisodeItemViewHolder.bind`)

| State | Effect |
|---|---|
| Played | `container.setAlpha(0.5f)` on the whole row; else `1.0f`. `left_padding` contentDescription = `"<title>. Played"` (else just title) |
| Currently playing | `itemView.setActivated(true)` → background `?attr/colorSecondaryContainer` rounded rect |
| Selected (multi-select) | `itemView.setSelected(true)` → same `?attr/colorSecondaryContainer` background |
| `isNew()` | `statusInbox` VISIBLE |
| video media | `ivIsVideo` VISIBLE |
| `TAG_FAVORITE` | `isFavorite` VISIBLE |
| `TAG_QUEUE` | `ivInPlaylist` VISIBLE — **forced GONE in the queue screen** (`QueueRecyclerAdapter.afterBindViewHolder`) |
| no media | progress bar, position, duration all GONE; `isVideo` GONE; `setActivated(false)` |
| downloaded/playing/in-progress | `progressBar` + `position` VISIBLE, progress = `100 * position / duration`; `duration` shows remaining prefixed with `-` when "show remaining time" is on |
| size unknown | `size` text empty, async fetch via `MediaSizeLoader` (only when head download allowed) |
| dummy/skeleton row | `container.alpha=0.1f`, title `"███████"`, date `"████"`, duration `"████"`, cover = `@color/medium_gray` |

### A.4.3 Background `@drawable/bg_episode_list_item`

```xml
<inset insetLeft=4dp insetRight=4dp insetTop=2dp insetBottom=2dp>
  <ripple color="?attr/colorControlHighlight">
    <item id="@android:id/mask">  rectangle, solid @android:color/black, corners radius 12dp  </item>
    <item>  selector
        state_activated=true → rectangle, solid ?attr/colorSecondaryContainer, corners 12dp
        state_selected=true  → rectangle, solid ?attr/colorSecondaryContainer, corners 12dp
        default              → @android:color/transparent
    </selector>  </item>
  </ripple>
</inset>
```

* So each row's visual surface is inset **4dp** from the left and right of the RecyclerView width and **2dp** top/bottom between rows.
* Corner radius **12dp**; ripple colour `?attr/colorControlHighlight`; selected/playing fill `#C8D8DE` light / `#3C4E68` dark.
* **There is no separate played-state drawable** — played is expressed by 0.5 alpha on `#container` (the FrameLayout wrapper exists precisely so the RecyclerView ItemAnimator's alpha changes do not clobber this).

### A.4.4 Secondary action button — `secondary_action.xml`

| Property | Value |
|---|---|
| Container | `FrameLayout#secondaryActionButton`, **48dp × 48dp**, `marginEnd=12dp`, `background=?selectableItemBackgroundBorderless`, `clickable=true`, `focusable=false`, `focusableInTouchMode=false` |
| Icon | `ImageView#secondaryActionIcon`, **24dp × 24dp**, `layout_gravity=center` |
| Progress | `CircularProgressBar#secondaryActionProgress`, **40dp × 40dp**, `layout_gravity=center`, `app:foregroundColor=?attr/action_icon_color` (black light / white dark) |
| Download ring | `CircularProgressBar` draws with `padding = height*0.08`, progress stroke = `padding`, background stroke = `height*0.03`; dashed (`DashPathEffect 5,5`) when indeterminate (queued) |

**Default action** = `ItemActionButton.forItem(item)`, resolved in this order:

| Condition | Class | Icon | Label (contentDescription) |
|---|---|---|---|
| no media | `MarkAsPlayedActionButton` | `ic_check` | "Mark as played" / "Mark as read" (no media) |
| currently playing | `PauseActionButton` | `ic_pause` | "Pause" |
| local feed | `PlayLocalActionButton` | `ic_play_24dp` | "Play" |
| downloaded | `PlayActionButton` | `ic_play_24dp` | "Play" |
| downloading | `CancelDownloadActionButton` | `ic_cancel` | "Cancel download" |
| stream-over-download pref | `StreamActionButton` | `ic_stream` | "Stream" |
| otherwise | `DownloadActionButton` | `ic_download` | "Download" |

The ring shows download progress: downloading → `max(percent, 0.01)`; downloaded → `1.0`; else `0`.

## A.5 Floating select menu (multi-select bar)

Container `FloatingSelectMenu` = `FrameLayout(match_parent × @dimen/floating_select_menu_height = 112dp)`, anchored to the parent bottom (`layout_alignParentBottom`).

| Element | Geometry |
|---|---|
| `CardView#card` | `match_parent × match_parent`, `marginHorizontal=16dp`, `marginBottom=16dp`, `cardCornerRadius=8dp` |
| Card background | `SurfaceColors.getColorForElevation(ctx, 8 * density)` — surface tint at **8dp elevation** (set in `FloatingSelectMenu.setup()`, not in XML) |
| `HorizontalScrollView#scrollView` | `match_parent × match_parent`, `paddingHorizontal=8dp`, `clipToPadding=true`, `requiresFadingEdge=horizontal`, `fadingEdgeLength=48dp` |
| `LinearLayout#selectContainer` | `wrap_content × match_parent`, horizontal |
| Item root (`floating_select_menu_item.xml`) | `wrap_content × match_parent`, `paddingHorizontal=4dp`, `paddingTop=12dp`, `paddingBottom=8dp`, `background=?attr/selectableItemBackgroundBorderless`, vertical |
| `ImageView#icon` | **28dp × 28dp**, `layout_gravity=center_horizontal` |
| `TextView#titleLabel` | `marginTop=8dp`, `minWidth=72dp`, `maxWidth=96dp`, `maxLines=2`, `textAlignment=center`, `ellipsize=end`, `hyphenationFrequency=full`, `textColor=?android:attr/textColorPrimary`, style `TextAppearance.Material3.BodySmall` (12sp) |

Vertical budget check: 12 + 28 + 8 + 2 lines × ~16sp + 8 ≈ 88–96dp inside the 112dp container (card loses 16dp bottom margin → 96dp usable). Show/hide animates alpha over **100ms**.

**Actions** come from `R.menu.episodes_apply_action_speeddial`, iterated in XML order and appended left→right (`FloatingSelectMenu.updateItemVisibility` skips `!isVisible()`):

| # | id | Icon | Label |
|---|---|---|---|
| 1 | `remove_item` | `ic_delete` | "Delete" |
| 2 | `download_item` | `ic_download` | "Download" |
| 3 | `mark_unread_item` | `ic_mark_unplayed` | "Mark as unplayed" |
| 4 | `mark_read_item` | `ic_mark_played` | "Mark as played" |
| 5 | `remove_from_queue_item` | `ic_playlist_remove` | "Remove from queue" |
| 6 | `add_to_queue_item` | `ic_playlist_play` | "Add to queue" |
| 7 | `share_item` | `ic_share` | "Share" |
| 8 | `remove_inbox_item` | `ic_check` | "Remove from inbox" |
| 9 | `add_to_favorites_item` | `ic_star` | "Add to favorites" |
| 10 | `remove_from_favorites_item` | `ic_star_border` | "Remove from favorites" |
| 11 | `reset_position` | `ic_replay` | "Reset playback position" |
| 12 | `move_to_top_item` | `ic_arrow_full_up` | "Move to top" — `android:visible="false"` by default |
| 13 | `move_to_bottom_item` | `ic_arrow_full_down` | "Move to bottom" — `android:visible="false"` by default |

Queue-screen visibility rules (`QueueFragment.onSelectedItemsUpdated`):
* `FeedItemMenuHandler.onPrepareMenu(menu, selected, R.id.add_to_queue_item, R.id.remove_inbox_item)` — items 6 and 8 are **always excluded on the queue screen**; the rest are shown per-item state (e.g. `remove_from_queue_item` when tagged queue, `mark_unplayed` when played, `remove_item` when downloaded/downloading, `download_item` when neither, favourites pair mutually exclusive for multi-selection, `share_item` hidden when >1 selected, `reset_position` when position ≠ 0).
* `move_to_top_item` / `move_to_bottom_item` visible only when `canMove(queue, selected)` — false when the queue is empty, locked, keep-sorted, everything selected, or the selection is already at that end.
* Tapping an action with 0 selected posts "No items selected"; otherwise `EpisodeMultiSelectActionHandler` runs and select mode ends.

Action-mode chrome (from `SelectableAdapter`):
* Title = `@plurals/num_selected_label` = **`"%1$d/%2$d selected"`** (e.g. `3/12 selected`; uses the *total* count when lazy-loaded pages are implied).
* Overflow menu `R.menu/multi_select_options.xml`: `select_toggle` "Select all" / "Deselect all", `select_all_above` "Select all above", `select_all_below` "Select all below" (all `showAsAction=never`).
* Announcement on open: "Multi select actions shown at the bottom".
* The info bar becomes INVISIBLE; drag/swipe are disabled.

## A.6 Drag & drop and locked state

* `QueueSwipeActions extends SwipeActions extends ItemTouchHelper.SimpleCallback` with **dragDirs = `UP | DOWN`**, swipeDirs = `RIGHT | LEFT`.
* `isLongPressDragEnabled()` returns **false** — long-press never starts a drag; long-press opens the context menu instead.
* Drag starts on `ACTION_DOWN` of either:
  1. `#drag_handle` (the 16dp-wide 6-dot grip), or
  2. `#coverHolder`, but **only when the touch X is in the left half of the cover** (`factor * event.getX() < factor * 0.5 * width`, RTL-aware).
* `onMove` reorders the in-memory `queue` list and calls `notifyItemMoved(from, to)`; `clearView` commits with `DBWriter.moveQueueItem(from, to, true)` only if `dragFrom != dragTo`.
* `dragDropEnabled = !(isQueueKeepSorted() || isQueueLocked())`, recomputed in `updateDragDropEnabled()` (which calls `notifyDataSetChanged()`):
  * enabled → `drag_handle` VISIBLE + touch listeners attached; cover touch listener attached.
  * disabled → `drag_handle` **GONE**, both touch listeners set to `null`.
* In action mode both touch listeners are cleared (handle visibility keeps following `dragDropEnabled`).
* Lock toggle flow: toolbar `queue_lock` → `toggleQueueLock()`. First time shows `MaterialAlertDialogBuilder` titled **"Lock queue"**, message **"If you lock the queue, you can no longer reorder episodes."**, with an inflated `checkbox_do_not_show_again.xml` (LinearLayout padding 16/8/16/8dp containing a CheckBox **"Do not show again"**), positive button **"Lock queue"**, negative **"Cancel"**. If the queue is empty while toggling, a snackbar message "Queue locked" / "Queue unlocked" is posted.
* Manual reorder is also blocked when keep-sorted is on (the lock item is hidden then).

## A.7 Empty state

`EmptyViewHandler` inflates `empty_view_layout.xml` and adds it to the nearest `RelativeLayout`/`FrameLayout`/`CoordinatorLayout` ancestor with **center** gravity. The RecyclerView is set `INVISIBLE` while empty.

| Element | Value |
|---|---|
| Root | `LinearLayout`, `match_parent × match_parent`, `gravity=center`, `paddingLeft=40dp`, `paddingRight=40dp` |
| `#emptyViewIcon` | **32dp × 32dp**, `visibility=gone` by default, shown by `setIcon()` |
| `#emptyViewTitle` | `textSize=16sp`, `textAlignment=center`, `textColor=?android:attr/textColorPrimary` |
| `#emptyViewMessage` | `textSize=14sp`, `textAlignment=center`, default colour |
| `#button` | `Widget.Material3.Button.OutlinedButton`, `wrap_content`, `layout_marginTop=16dp`, `visibility=gone` |

Queue values:

| Field | Value |
|---|---|
| Icon | `ic_playlist_play` |
| Title | `@string/no_items_header_label` = **"No queued episodes"** |
| Message (default) | `@string/no_items_label` = **"Add an episode by downloading it, or long press an episode and select \"Add to queue\"."** |
| Message (inbox has new episodes) | `@string/no_queue_items_inbox_has_items_label` = **"No episodes lined up, but there are new episodes that await you!"** |
| Button | `@string/no_queue_items_inbox_has_items_button_label` = **"Go to inbox"** → opens `InboxFragment` |

## A.8 Long-press context menu (queue)

Inflated in `QueueRecyclerAdapter.onCreateContextMenu`: `R.menu.queue_context` first, then `R.menu.feeditemlist_context` (header title = episode title).

| Order | Title |
|---|---|
| 1 | "Move to top" (`move_to_top_item`) — hidden if the pressed item is already first or keep-sorted |
| 2 | "Move to bottom" (`move_to_bottom_item`) — hidden if already last or keep-sorted |
| 3 | "Skip episode" |
| 4 | "Remove from inbox" |
| 5 | "Mark as played" |
| 6 | "Mark as unplayed" |
| 7 | "Add to queue" |
| 8 | "Remove from queue" |
| 9 | "Delete" |
| 10 | "Add to favorites" |
| 11 | "Remove from favorites" |
| 12 | "Reset playback position" |
| 13 | "Share" |
| 14 | "Multi select" (visible only outside action mode) |

Visibility of 3–13 is driven by `FeedItemMenuHandler.onPrepareMenu`. Items 1 and 2 are hidden while in action mode.

---

# B. EPISODE LIST / FEED DETAIL

## B.1 Which layout serves which screen

| Screen | Fragment | Layout | Toolbar menu |
|---|---|---|---|
| Feed detail (podcast episode list) | `FeedItemlistFragment` | `feed_item_list_fragment.xml` (+ `feeditemlist_header.xml`) | `R.menu.feedlist` |
| Feed info | `FeedInfoFragment` | `feedinfo.xml` (+ same header include) | `R.menu.feedinfo` |
| All Episodes | `AllEpisodesFragment extends EpisodesListFragment` | `episodes_list_fragment.xml` | `R.menu.episodes` |
| Inbox / Favorites / Playback history / Completed downloads | same base class | `episodes_list_fragment.xml` | none of the above |

**Rows are the identical `feeditemlist_item.xml`** in all of them (bound by `EpisodeItemViewHolder`).

## B.2 `feed_item_list_fragment.xml` (feed detail shell)

```
CoordinatorLayout (match_parent × match_parent, fitsSystemWindows=true)
├─ AppBarLayout#appBar (match_parent × wrap_content)
│  └─ CollapsingToolbarLayout (match_parent × match_parent,
│        titleEnabled=false, scrimAnimationDuration=200ms, layout_scrollFlags=scroll|exitUntilCollapsed)
│     ├─ ImageView#imgvBackground (match_parent × match_parent,
│     │     background=@color/image_readability_tint #80000000, scaleType=fitStart,
│     │     collapseMode=parallax, parallaxMultiplier=0.6,
│     │     runtime LightingColorFilter(0xff666666, 0x000000))
│     ├─ include#header @layout/feeditemlist_header (collapseMode=parallax)
│     └─ MaterialToolbar#toolbar (match_parent × wrap_content, minHeight=?attr/actionBarSize,
│           navigationIcon=?homeAsUpIndicator, navigationContentDescription="Back",
│           collapseMode=pin)
├─ SwipeRefreshLayout#swipeRefresh (match_parent × match_parent, behavior=appbar_scrolling_view_behavior)
│  └─ EpisodeItemListRecyclerView#recyclerView (match_parent × match_parent,
│        paddingHorizontal=@dimen/additional_horizontal_spacing)
├─ ProgressBar#progressBar (wrap_content, layout_gravity=center, indeterminate, gone)
├─ include#more_content @layout/more_content_list_footer (layout_gravity=bottom, gone)
└─ FloatingSelectMenu#floatingSelectMenu (match_parent × wrap_content, layout_gravity=bottom)
```

* Toolbar title: **empty while the header is expanded**, set to the feed title once collapsed (`OnCollapseChangeListener`).
* Toolbar icon tint: `ToolbarIconTintManager` applies `PorterDuffColorFilter(0xFFFFFFFF, SRC_ATOP)` to the navigation icon, overflow icon, collapse icon and **every menu icon** while expanded, and clears it (`null` filter) when collapsed.
* Pagination footer (`more_content_list_footer.xml`): `LinearLayout` `match_parent × wrap_content`, `padding=8dp`, `gravity=center`, `background=?android:attr/colorBackground`, `foreground=?attr/selectableItemBackground`; `ImageView#imgExpand` 16×16dp (`ic_load_more`) + `TextView` "Load next page" (`layout_marginLeft/Right=8dp`, `textColor=?android:attr/textColorPrimary`) + `ProgressBar#progBar` 16×16dp. Shown only when scrolled to the bottom and the feed is paged; while shown it supplies the RecyclerView bottom padding.
* `episodes_list_fragment.xml` (All Episodes and friends) is the simpler variant: `RelativeLayout` → `AppBarLayout` with `MaterialToolbar` (title "Episodes") + a `TextView#txtvInformation` ("Filtered") → `SwipeRefreshLayout` → RecyclerView → center `ProgressBar` → bottom `FloatingSelectMenu`. `txtvInformation`: `layout_marginTop=−16dp`, `paddingVertical=4dp`, `paddingHorizontal=16dp` (overridden at runtime to 60dp/16dp horizontal × 4dp vertical), `background=?attr/selectableItemBackground`, `visibility=gone`, text "Filtered".

## B.3 Feed header — `feeditemlist_header.xml`

Root `LinearLayout#headerContainer`: `match_parent × wrap_content`, `paddingHorizontal=@dimen/additional_horizontal_spacing` (0dp phone / 56dp ≥1000dp), **`layout_marginTop=?attr/actionBarSize` (56dp)** — pushes the content below the pinned toolbar — `orientation=vertical`.

### B.3.1 The 156dp image area

```
RelativeLayout (match_parent × 156dp, gravity=bottom)
├─ LinearLayout#buttonContainer (match_parent × wrap_content,
│     background=@color/image_readability_tint #80000000, horizontal, gravity=center_vertical,
│     layout_alignParentBottom=true)
│  ├─ View spacer           148dp × match_parent
│  ├─ Button#butSubscribe   wrap_content × wrap_content, marginVertical=4dp, text "Subscribe", gone unless STATE_NOT_SUBSCRIBED
│  ├─ Button#butRestore     wrap_content × wrap_content, marginVertical=4dp, text "Restore", gone unless STATE_ARCHIVED
│  ├─ ImageButton#butShowInfo   48dp × 48dp, padding=12dp, marginStart=−4dp, scaleType=fitXY,
│  │        background=?attr/selectableItemBackground, cd="Show information", src=ic_info_white
│  ├─ ImageButton#butFilter     48dp × 48dp, padding=12dp, scaleType=fitXY,
│  │        background=?attr/selectableItemBackground, cd="Filter", src=ic_filter_white
│  └─ ImageButton#butShowSettings 48dp × 48dp, padding=12dp, scaleType=fitXY,
│           background=?attr/selectableItemBackground, cd="Show podcast settings", src=ic_settings_white
├─ ImageView (12dp × 12dp, alignParentBottom+Left,  scaleType=fitXY, src=ic_rounded_corner_left)
├─ ImageView (12dp × 12dp, alignParentBottom+Right, scaleType=fitXY, src=ic_rounded_corner_right)
├─ CardView#coverHolder (124dp × 124dp, marginBottom=24dp, marginLeft=16dp, marginRight=16dp,
│     layout_alignParentBottom=true, cardCornerRadius=16dp, cardElevation=0dp,
│     cardPreventCornerOverlap=false, cardBackgroundColor=@color/non_square_icon_background)
│  └─ ImageView#imgvCover (match_parent × match_parent, centerVertical)
└─ LinearLayout (match_parent × wrap_content, layout_toEndOf=#coverHolder,
      layout_above=#buttonContainer, marginEnd=16dp, marginBottom=16dp, vertical)
   ├─ TextView#txtvTitle   match_parent × wrap_content, maxLines=2, ellipsize=end,
   │        textColor=@color/white, shadowColor=@color/black, shadowRadius=2,
   │        style=AntennaPod.TextView.Heading (22sp, sans-serif-light)
   └─ TextView#txtvAuthor  match_parent × wrap_content, maxLines=2, ellipsize=end,
            textColor=@color/white, shadowColor=@color/black, shadowRadius=2,
            textSize=@dimen/text_size_small (14sp)
```

* Buttons row height ≈ 48dp (tallest child) and spans the full width; the 148dp spacer leaves the cover column free.
* The 12×12dp corner images paint `?attr/background_color` shapes that visually round the junction between the darkened image area and the content below.
* `butSubscribe` / `butRestore` use the theme's default Material3 filled button (min height 40dp, corner radius 20dp, `marginVertical=4dp`).
* Visibility logic (`FeedItemlistFragment.refreshHeaderView`): `butShowInfo` visible unless not-subscribed; `butFilter` and `butShowSettings` visible only for subscribed & non-archived; `butSubscribe` only when `STATE_NOT_SUBSCRIBED`; `butRestore` only when `STATE_ARCHIVED`. In `FeedInfoFragment` the info/filter/settings buttons are forced `INVISIBLE`.
* Cover loading: `fitCenter`, placeholder/error `@color/light_gray`; background image uses `FastBlurTransformation` with placeholder/error `@color/image_readability_tint`.
* In `FeedInfoFragment` the title gets `maxLines=6`.

### B.3.2 Message rows (below the 156dp area)

Wrapper: `LinearLayout` `match_parent × wrap_content`, vertical, `background=?android:attr/colorBackground`.

| View | Background | Text colour | Margins | Padding | Text |
|---|---|---|---|---|---|
| `TextView#txtvFailure` | `@drawable/bg_message_error` | `?attr/icon_red` `#CF1800` | `marginHorizontal=16dp`, `marginVertical=8dp` | `paddingHorizontal=16dp`, `paddingVertical=8dp` | "Last refresh failed. Tap to view details." — `foreground=?android:attr/selectableItemBackground`; visible when `feed.hasLastUpdateFailed()` |
| `TextView#txtvInformation` | none | `?attr/colorAccent` (`#0078C2` / `#3D8BFF`) | none | `padding=2dp` | "Filtered" — `gravity=center`, `foreground=?android:attr/selectableItemBackground`; visible when the feed has an item filter; tap opens the filter dialog |
| `TextView#txtvUpdatesDisabled` | none | `?attr/colorAccent` | none | `padding=2dp` | "Updates disabled" — `gravity=center`; visible when keep-updated is off (and not not-subscribed) or archived |

`bg_message_error` = shape, `stroke width=2dp color=?attr/icon_red`, `corners radius=8dp`, `solid = icon_red at alpha 0.1`.
`bg_message_info` = shape, `stroke width=2dp color=?attr/colorPrimary`, `corners radius=8dp`, `solid = colorPrimary at alpha 0.1`.

### B.3.3 Description container

`LinearLayout#descriptionContainer`: `match_parent × wrap_content`, `paddingHorizontal=16dp`, `paddingTop=16dp`, `background=?android:attr/colorBackground`, vertical, **`visibility=gone`** — shown only when the feed is `STATE_NOT_SUBSCRIBED`.

| Child | Style / geometry | Text |
|---|---|---|
| `TextView#subscribeNagLabel` | `marginBottom=8dp`, `paddingHorizontal=16dp`, `paddingVertical=8dp`, `background=@drawable/bg_message_info`, `textColor=?attr/colorAccent`; visible only if the feed has been interacted with | "You are not subscribed to this podcast yet. Subscribe for free to access it more easily and keep its playback history." |
| "Description" label | `marginBottom=4dp`, `style=TextAppearance.Material3.TitleMedium` (16sp) | **"Description"** |
| `TextView#headerDescriptionLabel` | `lineHeight=20dp`, `maxLines=3`, `ellipsize=end`, `marginBottom=16dp`, `background=?android:attr/selectableItemBackground`, `style=TextAppearance.Material3.BodyMedium` (14sp); tap opens feed info | plain-text feed description |
| "Episodes preview" label | `marginBottom=4dp`, `style=TextAppearance.Material3.TitleMedium` | **"Episodes preview"** |

## B.4 Row differences in the feed/episodes adapters

| Aspect | Queue (`QueueRecyclerAdapter`) | Feed detail (`FeedItemlistFragment.FeedItemListAdapter`) | Generic episodes list (`EpisodeItemListAdapter`) |
|---|---|---|---|
| Drag handle | VISIBLE (16dp) when drag is enabled, GONE otherwise | **always GONE** (`EpisodeItemListAdapter.onBindViewHolder` sets `dragHandle.setVisibility(GONE)` on every bind) | always GONE |
| Cover | default `CoverLoader` with `ImageResourceUtils.getEpisodeListImageLocation(item)` + feed image fallback | `coverHolder` hidden before bind, then shown and loaded explicitly with the episode's own `getImageLocation()` (ignores the "show episode cover" setting) + feed image fallback | default loader |
| In-queue icon | **forced GONE** | shown when `TAG_QUEUE` | shown when `TAG_QUEUE` |
| Secondary action | `ItemActionButton.forItem(item)` | same, but **hidden entirely when `feed.getState() != STATE_SUBSCRIBED`** | same |
| Drag/cover touch listeners | attached when drag is enabled | none | none |
| Select-mode secondary action | toggles selection | toggles selection | toggles selection |
| Select-mode menu excludes | `add_to_queue_item`, `remove_inbox_item`; move-to-top/bottom per `canMove` | none; move-to-top/bottom stay invisible | none |
| Context-menu "Multi select" | visible outside action mode | visible outside action mode and when feed state ≠ NOT_SUBSCRIBED | visible outside action mode |
| Toolbar title | "Queue" | "" expanded / feed title collapsed | "Episodes" (All Episodes) |

Everything else — padding, cover 56dp/8dp radius, 12sp status icons, title style, progress row, 48dp secondary action, `bg_episode_list_item` — is byte-identical because it is the same XML.

## B.5 Toolbars / menus

### `feedlist.xml` — feed detail (`R.menu.feedlist`)

| # | id | Title | Icon | `showAsAction` |
|---|---|---|---|---|
| 1 | `sort_items` | "Sort" | — | never |
| 2 | `refresh_item` | "Refresh" | — | never |
| 3 | `refresh_complete_item` | "Refresh complete podcast" | — | collapseActionView |
| 4 | `action_search` | "Search" | `ic_search` | always |
| 5 | `visit_website_item` | "Visit website" | `ic_web` | collapseActionView |
| 6 | `share_feed` | "Share" | — | never |
| 7 | `remove_all_inbox_item` | "Remove all from inbox" | `ic_check` | collapseActionView |
| 8 | `remove_archive_feed` | "Unsubscribe / archive" | `ic_delete` | collapseActionView |
| 9 | `remove_restore_feed` | "Unsubscribe / restore" | `ic_delete` | collapseActionView, `visible=false` |

Runtime visibility: `visit_website_item` only when `feed.getLink() != null`; `refresh_complete_item` only when `feed.isPaged()`; for `STATE_NOT_SUBSCRIBED` → `sort_items`, `refresh_item`, `action_search` hidden; for `STATE_ARCHIVED` → `sort_items` hidden; the rest via `FeedMenuHandler.onPrepareMenu`.

### `episodes.xml` — All Episodes

| # | id | Title | Icon | `showAsAction` |
|---|---|---|---|---|
| 1 | `action_search` | "Search" | `ic_search` | always |
| 2 | `refresh_item` | "Refresh" | — | never |
| 3 | `filter_items` | "Filter" | `ic_filter` | ifRoom (category container) |
| 4 | `episodes_sort` | "Sort" | — | never |

### `feedinfo.xml` — feed info screen

| # | id | Title | Icon | `showAsAction` |
|---|---|---|---|---|
| 1 | `visit_website_item` | "Visit website" | `ic_web` | ifRoom \| collapseActionView |
| 2 | `share_item` | "Share" | `ic_share` | ifRoom |

## B.6 Sorting / filter entry points and visible chips

**Filter dialog** (`ItemFilterDialog`, a `BottomSheetDialogFragment` forced to `STATE_EXPANDED`, full height):
* Entry points: feed header `#txtvInformation` ("Filtered" row) and `#butFilter` (48dp `ic_filter_white`) on the feed detail; `#txtvInformation` ("Filtered" bar under the toolbar) and the `filter_items` toolbar icon on All Episodes.
* Layout `filter_dialog.xml`: `ScrollView` → `LinearLayout#filter_rows`, `paddingLeft/Top/Right=24dp`, `paddingBottom=8dp`; first child is a horizontal row with two `MaterialButton`s, `match_parent × wrap_content`, `layout_weight=1` each, `Widget.MaterialComponents.Button.TextButton`, texts **"Reset"** and **"Confirm"**; new rows are inserted *before the last child*.
* Each row `filter_dialog_row.xml`: `MaterialButtonToggleGroup#buttonGroup` (`match_parent × wrap_content`, `weightSum=2`, `app:singleSelection=true`) containing two `Button`s `0dp × match_parent`, `layout_weight=1`, style `OutlinedButtonBetterContrast` (outlined Material3 button with `backgroundTint=@color/button_bg_selector`); `maxLines=3`, `singleLine=false` in code.
* Chip checked/unchecked colours: `button_bg_selector` = `state_checked=true → ?attr/colorPrimary at alpha 0.3`; `state_checked=false → @android:color/transparent` (comment in the file notes the alpha is 0.3 instead of Material's 0.08).
* Six rows × two chips (left chip = "hide X" filter, right chip = inverse):

| Row | Chip 1 | Chip 2 |
|---|---|---|
| Played | "Played" (`hide_played_episodes_label`) | "Not played" |
| Paused | "Paused" (`hide_paused_episodes_label`) | "Not paused" |
| Favorite | "Is favorite" (`hide_is_favorite_label`) | "Not favorite" |
| Media | "Has media" | "No media" |
| Queued | "Queued" | "Not queued" |
| Downloaded | "Downloaded" (`hide_downloaded_episodes_label`) | "Not downloaded" |

* "Reset" clears every toggle group and applies an empty filter; "Confirm" just dismisses (each toggle already applies immediately).

**Sort dialog** (`ItemSortDialog`, `BottomSheetDialogFragment` forced expanded):
* Entry points: `sort_items` (feed detail → `SingleFeedSortDialog`), `episodes_sort` (All Episodes → `AllEpisodesSortDialog`), `queue_sort` (queue → `QueueSortDialog`).
* Layout `sort_dialog.xml`: `LinearLayout` `padding=16dp` → `GridLayout#gridLayout` (`match_parent × wrap_content`, `columnCount=2`, `rowOrderPreserved=false`, `useDefaultMargins=true`, `alignmentMode=alignBounds`) → one chip per sort order; plus `CheckBox#keepSortedCheckbox` ("Keep sorted", `visibility=gone` except in `QueueSortDialog`).
* Chip layout `sort_dialog_item.xml`: `Button` `0dp × wrap_content`, `layout_gravity=fill_horizontal|center_vertical`, `layout_columnWeight=1`, `Widget.Material3.Button.OutlinedButton`. Active chip uses `sort_dialog_item_active.xml` = `Widget.Material3.Button.TonalButton` and its label gets a `\u00A0▲` / `\u00A0▼` suffix.
* Base chip set: "Episode title", "Podcast title", "Duration", "Date", "Size", "File name", "Random", "Smart shuffle".
  * `QueueSortDialog`: drops "File name" and "Size"; shows "Keep sorted"; "Random" force-unchecks and disables the keep-sorted checkbox.
  * `SingleFeedSortDialog`: keeps only "Date", "Duration", "Episode title" (+ "File name" for local feeds) and appends "Global default".
  * `AllEpisodesSortDialog`: keeps only "Date" and "Duration".

## B.7 Empty state (episode lists)

Same `EmptyViewHandler` / `empty_view_layout.xml` as §A.7 (icon 32dp, title 16sp, message 14sp, 40dp side padding, centered).

| Screen | Icon | Title | Message |
|---|---|---|---|
| All Episodes (no filter) | `ic_feed` | "No episodes" (`no_all_episodes_head_label`) | "When you add a podcast, the episodes will be shown here." (`no_all_episodes_label`) |
| All Episodes (filtered) | `ic_feed` | "No episodes" | "Try clearing the filter to see more episodes." (`no_all_episodes_filtered_label`) |
| Feed detail / others | `ic_feed` | "No episodes" | same base message; no button |
| Queue | `ic_playlist_play` | "No queued episodes" | see §A.7 (optionally with a "Go to inbox" button) |

---

## Appendix — exact English strings used by these screens

| Key | Value |
|---|---|
| `queue_label` | Queue |
| `queue_time_left_label` | `%1$s • %2$s left` |
| `num_episodes` | `%d episode` / `%d episodes` |
| `num_selected_label` | `%1$d/%2$d selected` |
| `search_label` | Search |
| `refresh_label` | Refresh |
| `lock_queue` | Lock queue |
| `queue_lock_warning` | If you lock the queue, you can no longer reorder episodes. |
| `queue_locked` / `queue_unlocked` | Queue locked / Queue unlocked |
| `checkbox_do_not_show_again` | Do not show again |
| `sort` | Sort |
| `keep_sorted` | Keep sorted |
| `clear_queue_label` | Clear queue |
| `clear_queue_confirmation_msg` | Please confirm that you want to remove ALL episodes from the queue. |
| `move_to_top_label` / `move_to_bottom_label` | Move to top / Move to bottom |
| `no_items_header_label` | No queued episodes |
| `no_items_label` | Add an episode by downloading it, or long press an episode and select "Add to queue". |
| `no_queue_items_inbox_has_items_label` | No episodes lined up, but there are new episodes that await you! |
| `no_queue_items_inbox_has_items_button_label` | Go to inbox |
| `no_all_episodes_head_label` | No episodes |
| `no_all_episodes_label` | When you add a podcast, the episodes will be shown here. |
| `no_all_episodes_filtered_label` | Try clearing the filter to see more episodes. |
| `episodes_label` | Episodes |
| `filter` / `filtered_label` | Filter / Filtered |
| `refresh_failed_msg` | Last refresh failed. Tap to view details. |
| `updates_disabled_label` | Updates disabled |
| `subscribe_label` | Subscribe |
| `restore_archive_label` | Restore |
| `show_info_label` | Show information |
| `show_feed_settings_label` | Show podcast settings |
| `description_label` | Description |
| `preview_episodes` | Episodes preview |
| `state_deleted_not_subscribed` | You are not subscribed to this podcast yet. Subscribe for free to access it more easily and keep its playback history. |
| `multi_select` | Multi select |
| `select_all_label` / `deselect_all_label` | Select all / Deselect all |
| `select_all_above` / `select_all_below` | Select all above / Select all below |
| `multi_select_started_talkback` | Multi select actions shown at the bottom |
| `no_items_selected_message` | No items selected |
| `toolbar_back_button_content_description` | Back |
| `is_inbox_label` / `media_type_video_label` / `is_favorite_label` / `in_queue_label` | In the inbox / Video / Marked as favorite / In the queue |
| `is_played` | Played |
| Speed-dial labels | Delete, Download, Mark as unplayed, Mark as played, Remove from queue, Add to queue, Share, Remove from inbox, Add to favorites, Remove from favorites, Reset playback position, Move to top, Move to bottom |
