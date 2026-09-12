# Android Layout Reference Spec — PLAYER + secondary screens

**Purpose.** Implementation-ready, numeric description of the upstream AntennaPod **Android** layouts for
the PLAYER screen and the secondary screens listed below, so a HarmonyOS ArkTS developer can replicate
the visual layout exactly. This document records **Android facts only** — it proposes no ArkTS code.

**Source.** Upstream AntennaPod Android checkout at `D:\Git\antennapod-harmony\antenna-repo`
(shallow clone, **read-only**; nothing under it was modified). Every numeric claim carries a
`file:line` reference relative to that directory.

**Units.** `dp` and `sp` exactly as written in the Android resource. Where a value comes from a
theme attribute (`?attr/...`) or the Material/AppCompat library rather than a repo resource, the
resolution is given and marked `[library]`.

**Caveats.**
- The checkout is **partial**: `storage/importexport` (OpmlReader/OpmlWriter), `:model`,
  `:storage:database`, `:event` and `gradle/libs.versions.toml` are absent, so a few data-layer
  behaviours are inferred from call sites.
- No Android SDK is installed in this environment, so a small number of library/platform values are
  marked `[library — not verifiable here]`: `?attr/actionBarSize`, `?android:attr/dividerVertical`,
  `android.R.layout.simple_list_item_multiple_choice` row metrics, Material3 `TextAppearance.*` sizes,
  and `?attr/colorControlHighlight`.

**Contents.**

| § | Screen / topic |
|---|---|
| 0 | Global chrome and cross-cutting tokens (shell, dimens, typography, radii, colours, episode-list item, empty state) |
| A | PLAYER (bottom sheet): toolbar, pager, seek row, controls, cover, dialogs, mini-player |
| B.1 / B.2 | ADD FEED and SEARCH (+ online search) |
| B.3 | DOWNLOADS, PLAYBACK HISTORY, INBOX, FAVORITES, ALL EPISODES |
| B.4 | STATISTICS and OPML import/export |
| B.5 | SETTINGS / STORAGE preference screens + consolidated design tokens |

---

## 0. Global chrome and cross-cutting tokens (applies to every screen)

### 0.1 Application shell

| Element | Value | Ref |
|---|---|---|
| `main.xml` root | `LinearLayout`, match_parent/match_parent, vertical | `app/src/main/res/layout/main.xml:2-11` |
| Drawer | `DrawerLayout @+id/drawer_layout`, match_parent × 0dp, weight 1 | `main.xml:16-20` |
| Content host | `FragmentContainerView @+id/main_content_view`, match_parent/match_parent, `foreground="?android:windowContentOverlay"` | `main.xml:27-33` |
| Player sheet | `FragmentContainerView @+id/audioplayerFragment`, match_parent/match_parent, `elevation="8dp"`, `visibility="gone"`, `app:layout_behavior="de.danoeh.antennapod.ui.common.LockableBottomSheetBehavior"` | `main.xml:35-43` |
| Drawer fragment | `FragmentContainerView @+id/navDrawerFragment`, match_parent/match_parent, `layout_gravity="start"` | `main.xml:47-52` |
| Bottom navigation | `BottomNavigationView @+id/bottomNavigationView`, match_parent × **64dp**, `itemPaddingTop="12dp"`, `itemPaddingBottom="4dp"`, `activeIndicatorLabelPadding="0dp"`, `labelVisibilityMode="labeled"`, label style `@style/TextBottomNav` = **11sp** | `main.xml:56-65`, `ui/common/src/main/res/values/styles.xml:352-354` |
| Bottom inset filler | `View @+id/bottom_padding`, height 0dp, `background="?attr/colorSurfaceContainer"` | `main.xml:67-71` |
| Bottom-nav items | Built at runtime: up to `min(5, getMaxItemCount())` entries taken from the drawer order (subscriptions list excluded), short labels via `NavigationNames.getShortLabel`, icons via `NavigationNames.getDrawable`, plus a trailing **"More"** item with `@drawable/dots_vertical`; overflow popup width **250dp**, gravity `END\|BOTTOM`; Inbox carries a `BadgeDrawable` with the new-episode count | `app/.../ui/screen/drawer/BottomNavigation.java:47-64,96-135,80-82` |
| Collapsed mini-player height | `@dimen/external_player_height` = **64dp** — used as the bottom-sheet peek height and as the bottom margin of `main_content_view` while playing | `ui/common/src/main/res/values/dimens.xml:3`, `MainActivity.java:402-409` |
| Toolbar height | `?attr/actionBarSize` → **56dp** `[library]` (AppCompat `abc_action_bar_default_height_material`; not overridden anywhere in the repo) | e.g. `addfeed.xml:19` |
| Global toolbar style | `toolbarStyle = @style/Style.AntennaPod.Toolbar` → parent `Widget.Material3.Toolbar`; `Theme.AntennaPod.Toolbar` sets `action_icon_color = ?attr/colorOnSurface`, `colorControlNormal = ?attr/colorOnSurface`; `Widget.AntennaPod.ActionBar` sets `background = ?android:attr/colorBackground`, `elevation = 0dp` | `ui/common/src/main/res/values/styles.xml:267-274,325-328` |
| Horizontal breathing room on wide screens | `@dimen/additional_horizontal_spacing` = **0dp** (default) / **56dp** at `values-w1000dp` / 0dp at `values-w300dp`; applied as `paddingHorizontal` on episode list RecyclerViews | `app/src/main/res/values/dimens.xml:3`, `values-w1000dp/dimens.xml:3` |
| Floating multi-select menu | `@dimen/floating_select_menu_height` = **112dp** | `app/src/main/res/values/dimens.xml:6` |
| Drawer corner radius | `@dimen/drawer_corner_size` = **16dp** (should match `m3_navigation_drawer_layout_corner_size`) | `app/src/main/res/values/dimens.xml:5` |

### 0.2 Spacing / size dimens (complete, `ui/common/src/main/res/values/dimens.xml`)

| Name | Value | Used for |
|---|---|---|
| `external_player_height` | **64dp** | mini-player row / bottom-sheet peek |
| `text_size_micro` | **12sp** | player position/length, rewind/FF/speed labels |
| `text_size_small` | **14sp** | cover podcast+episode titles, discovery error label |
| `text_size_navdrawer` | **16sp** | cover "Chapters" label |
| `text_size_large` | **22sp** | `AntennaPod.TextView.Heading` |
| `thumbnail_length_itemlist` | **56dp** | online-search cover, general list thumbnails |
| `thumbnail_length_queue_item` | **56dp** | episode-list cover, chapter-row cover |
| `thumbnail_length_navlist` | **40dp** | navigation drawer list thumbnails |
| `listitem_iconwithtext_height` | **48dp** | icon+text list rows |
| `listitem_iconwithtext_textleftpadding` | **16dp** | — |
| `listitem_threeline_textleftpadding` | **16dp** | episode-row cover→text gap |
| `listitem_threeline_textrightpadding` | **8dp** | episode-row text right padding |
| `listitem_threeline_verticalpadding` | **11dp** | episode-row top/bottom padding |
| `list_vertical_padding` | **8dp** | list top/bottom padding |
| `listitem_icon_leftpadding` | **16dp** | — |
| `audioplayer_playercontrols_length` | **48dp** | rewind / speed / FF / skip buttons |
| `audioplayer_playercontrols_length_big` | **64dp** | play button, buffering ring, loading spinner |
| `audioplayer_playercontrols_margin` | **12dp** | player control margins |
| `nav_drawer_max_screen_size` | **480dp** | drawer max width |
| `additional_horizontal_spacing` | **0dp** / **56dp** (w1000dp) | wide-screen list padding |
| `drawer_corner_size` | **16dp** | drawer corners |
| `floating_select_menu_height` | **112dp** | multi-select bar |

`ui/widget/src/main/res/values/dimens.xml` exists (home-screen widget only, out of scope here).

### 0.3 Typography quick reference

| Style | Parent | Size | Colour token | Notes |
|---|---|---|---|---|
| `AntennaPod.TextView.Heading` | `@android:style/TextAppearance.Medium` | **22sp** | `?android:attr/textColorPrimary` | `fontFamily=sans-serif-light` |
| `AntennaPod.TextView.ListItemPrimaryTitle` | `TextAppearance.Material3.BodyLarge` | **16sp** `[library]` | `?attr/colorOnSurface` | maxLines 2, ellipsize end, lineHeight **20sp** |
| `AntennaPod.TextView.FeedListItemPrimaryTitle` | `TextAppearance.Material3.BodyLarge` | **16sp** `[library]` | inherited | maxLines 2, lineHeight 20sp |
| `AntennaPod.TextView.ListItemSecondaryTitle` | `TextAppearance.Material3.BodyMedium` | **14sp** `[library]` | `?attr/colorOnSurfaceVariant` | lines 1, ellipsize end |
| `AntennaPod.TextView.FeedListItemSecondaryTitle` | `TextAppearance.Material3.LabelSmall` | **11sp** `[library]` | inherited | lines 1, ellipsize end |
| `TextBottomNav` | `TextAppearance.Material3.TitleSmall` | **11sp** | inherited | bottom-nav labels |
| `AddPodcastTextView` | `TextAppearance.Material3.BodyMedium` | **14sp** | `?android:attr/textColorPrimary` | minHeight 48dp, padding 8dp/16dp, drawablePadding 8dp |

Ad-hoc sizes used directly in layouts: **12sp** (player labels, powered-by), **13sp** (statistics legend dot),
**16sp** (cover shownotes/chapters labels, empty-view title, seek toast, statistics title/year),
**28sp** (statistics total value), **32sp** (sleep-timer clock).

### 0.4 Corner-radius quick reference

| Radius | Where | Ref |
|---|---|---|
| **8dp** | player seek toast card; `grey_border` (shownotes / chapters buttons); episode-list cover card; floating select menu card | `audioplayer_fragment.xml:62`; `app/res/drawable/grey_border.xml:8`; `feeditemlist_item.xml:53`; `floating_select_menu.xml` |
| **12dp** | episode-row background/ripple (`bg_episode_list_item`); `horizontal_itemlist_item` card | `app/res/drawable/bg_episode_list_item.xml:11,19,25`; `horizontal_itemlist_item.xml:19` |
| **16dp** | player cover image + its ripple; `horizontal_feed_item` card | `CoverFragment.java:322`; `cover_fragment_ripple_border.xml:7`; `horizontal_feed_item.xml` |
| **28dp** | Add-feed search bar card | `addfeed.xml:45` |

### 0.5 Colour / attribute token table (resolved)

`ui/common/src/main/res/values/colors.xml`:

| Token | Value |
|---|---|
| `white` | #FFFFFF |
| `black` | #000000 |
| `grey100` | #f5f5f5 |
| `grey600` | #757575 |
| `light_gray` | #bfbfbf |
| `medium_gray` | #afafaf |
| `image_readability_tint` | #80000000 |
| `feed_text_bg` | #55333333 |
| `background_light` | #f9fcff |
| `background_elevated_light` | #EFEEEE |
| `background_darktheme` | #21272b |
| `background_elevated_darktheme` | #2D3337 |
| `non_square_icon_background` | #22777777 |
| `seek_background_light` | #90000000 |
| `seek_background_dark` | #905B5B5B |
| `text_color_secondary_light` | #444444 |
| `text_color_secondary_dark` | #cccccc |
| `color_surface_variant_light` | #D3DCE0 |
| `color_surface_variant_dark` | #2F3B4F |
| `color_secondary_container_light` | #C8D8DE |
| `color_secondary_container_dark` | #3C4E68 |
| `accent_light` | #0078C2 |
| `accent_dark` | #3D8BFF |
| `gradient_000 / 025 / 075 / 100` | #364ff3 / #2E6FF6 / #1EB0FC / #16d0ff |

Material3 theme attrs (`ui/common/src/main/res/values/styles.xml`):

| Attr | Light | Dark | TrueBlack |
|---|---|---|---|
| `colorPrimary` / `colorSecondary` / `colorAccent` | #0078C2 | #3D8BFF | #3D8BFF |
| `colorOnPrimary` / `colorOnSecondary` | #FFFFFF | #000000 | #000000 |
| `android:colorBackground` / `colorSurface` | #f9fcff | #21272b | #000000 |
| `colorOnSurface` | #000000 | #FFFFFF | #FFFFFF |
| `colorSurfaceVariant` | #D3DCE0 | #2F3B4F | #2F3B4F |
| `colorOnSurfaceVariant` | #444444 | #cccccc | #cccccc |
| `colorSurfaceContainer` | #EBEEF3 | #1C2024 | #1C2024 |
| `colorSurfaceContainerHigh` | #D3DCE0 | #2F3B4F | #2F3B4F |
| `colorSurfaceContainerHighest` | #C0CFD3 | #38455C | #38455C |
| `colorSurfaceContainerLow` / `Lowest` | #D3DCE0 | #2F3B4F | #2F3B4F |
| `colorSecondaryContainer` | #C8D8DE | #3C4E68 | #3C4E68 |
| `colorOnSecondaryContainer` | #000000 | #FFFFFF | #FFFFFF |
| `colorPrimaryContainer` | #D6E6F3 | #29374E | #0D182B |
| `colorOutline` / `colorOutlineVariant` | #444444 | #cccccc | #cccccc |
| `android:textColorPrimary` | #000000 | #FFFFFF | #FFFFFF |
| `android:textColorSecondary` / `Tertiary` | #444444 | #cccccc | #cccccc |
| `background_color` | #f9fcff | #21272b | #000000 |
| `background_elevated` | #EFEEEE | #2D3337 | #000000 |
| `action_icon_color` | #000000 | #FFFFFF | #FFFFFF |
| `seek_background` | #90000000 | #905B5B5B | #905B5B5B |
| `icon_red` | #CF1800 | #CF1800 | #CF1800 |
| `icon_yellow` | #F59F00 | #F59F00 | #F59F00 |
| `icon_green` | #008537 | #008537 | #008537 |
| `icon_purple` | #5F1984 | #AA55D8 | #AA55D8 |
| `icon_gray` | #25365A | #CDD9E4 | #CDD9E4 |
| `dragview_background` | `@drawable/ic_drag_lighttheme` | `@drawable/ic_drag_darktheme` | same as dark |
| `scrollbar_thumb` | `@drawable/scrollbar_thumb_light` | `@drawable/scrollbar_thumb_dark` | same as dark |

Custom attrs are declared in `ui/common/src/main/res/values/attrs.xml:3-13`.

### 0.6 Episode list item — the app-wide backbone (used by Search, Inbox, Favorites, History, All Episodes)

`app/src/main/res/layout/feeditemlist_item.xml` (adapter `EpisodeItemViewHolder`):

| Node | Geometry |
|---|---|
| root `FrameLayout` | match_parent × wrap_content |
| `LinearLayout @+id/container` | match_parent × wrap_content, horizontal, `gravity=center_vertical`, `paddingStart=12dp`, `paddingEnd=0dp`, `background=@drawable/bg_episode_list_item`, `duplicateParentState=true` |
| `LinearLayout @+id/left_padding` | wrap_content × match_parent, `minWidth=4dp`; holds `@+id/drag_handle` (16dp × match_parent, `paddingEnd=4dp`) which is forced **GONE** in this adapter |
| `CardView @+id/coverHolder` | **56×56dp**, `marginTop/Bottom=11dp`, `marginEnd=16dp`, `cardBackgroundColor=#22777777`, `cardCornerRadius=8dp`, `cardElevation=0dp`, `cardPreventCornerOverlap=false`; contains `@+id/txtvPlaceholder` (56×56dp, bg #bfbfbf, maxLines 3, padding 2dp) and `@+id/imgvCover` (56×56dp) |
| text column | 0dp × wrap_content weight 1, `marginTop/Bottom=11dp`, `marginEnd=8dp`, vertical |
| `@+id/status` row | horizontal; icons `@+id/statusInbox`, `@+id/ivIsVideo`, `@+id/isFavorite`, `@+id/ivInPlaylist` each **12sp × 12sp**, tinted `?attr/colorOnSurfaceVariant`; `@+id/separatorIcons` "·" with `marginStart/End=4dp`; `@+id/txtvPubDate`, anon "·", `@+id/size` each `marginEnd=4dp`, all `FeedListItemSecondaryTitle` (**11sp**) |
| `@+id/txtvTitle` | wrap_content, `ellipsize=end`, `textAlignment=viewStart`, `FeedListItemPrimaryTitle` (**16sp**, maxLines 2, lineHeight 20sp) |
| `@+id/progress` row | horizontal; `@+id/txtvPosition` (11sp), `LinearProgressIndicator @+id/progressBar` (0dp weight 1, max 100, `margin=4dp`, `trackStopIndicatorSize=0dp`), `@+id/txtvDuration` (11sp) |
| trailing `@layout/secondary_action` | **48×48dp**, `marginEnd=12dp`, borderless ripple; icon `@+id/secondaryActionIcon` **24×24dp** centred; `CircularProgressBar @+id/secondaryActionProgress` **40×40dp** |
| Row background | `bg_episode_list_item.xml` = inset (left/right **4dp**, top/bottom **2dp**) + ripple (`?attr/colorControlHighlight`) + mask rect radius **12dp**; activated/selected fill `?attr/colorSecondaryContainer`; otherwise transparent |
| Played state | `container.setAlpha(0.5f)` |
| **Dividers** | **none** — separation is the 4dp/2dp inset + 12dp radius |
| RecyclerView chrome | `EpisodeItemListRecyclerView` applies `@style/FastScrollRecyclerView` (`scrollbars=none`, fast-scroll thumb `?attr/scrollbar_thumb`, track `@drawable/scrollbar_track`), `LinearLayoutManager`, `setHasFixedSize(true)`, `setClipToPadding(false)` |

### 0.7 Shared empty-state view

`ui/common/src/main/res/layout/empty_view_layout.xml`, inflated by `EmptyViewHandler` and added to the
nearest `RelativeLayout`/`FrameLayout`/`CoordinatorLayout` ancestor with centre gravity:

| Node | Geometry |
|---|---|
| root `LinearLayout` | match_parent/match_parent, vertical, `gravity=center`, `paddingLeft/Right=40dp` |
| `@+id/emptyViewIcon` | **32×32dp**, `visibility=gone` until `setIcon()` |
| `@+id/emptyViewTitle` | wrap_content, **16sp**, `textAlignment=center`, `textColor=?android:attr/textColorPrimary` |
| `@+id/emptyViewMessage` | wrap_content, **14sp**, `textAlignment=center` |
| `@+id/button` | wrap_content, `marginTop=16dp`, `visibility=gone`, `style=@style/Widget.Material3.Button.OutlinedButton` |
| Visibility rule | list is set `INVISIBLE` and the empty view `VISIBLE` when the adapter item count is 0 |


---

## A. PLAYER (audio player bottom sheet)

Source of truth: `app/src/main/res/layout/audioplayer_fragment.xml`,
`.../ui/screen/playback/audio/AudioPlayerFragment.java`, `PlayButton.java`, `ChapterSeekBar.java`,
`CoverFragment.java`, `cover_fragment.xml`, `item_description_fragment.xml`,
`speed_select_dialog.xml`, `playback_speed_seek_bar.xml`, `time_dialog.xml`,
`res/menu/mediaplayer.xml`, `external_player_fragment.xml`, `main.xml`, `MainActivity.java`.

### A.0 Hosting model (why the player looks the way it does)

| Fact | Value | Ref |
|---|---|---|
| Host container | `FragmentContainerView @+id/audioplayerFragment`, match_parent/match_parent, `android:elevation="8dp"`, `android:background="?android:attr/colorBackground"`, `android:visibility="gone"`, behavior `LockableBottomSheetBehavior` | `main.xml:35-43` |
| Collapsed peek height | `@dimen/external_player_height` = **64dp** (`sheetBehavior.setPeekHeight(externalPlayerHeight)`) | `MainActivity.java:402,407` |
| Main content bottom margin when player visible | 64dp (`params.setMargins(insetL,0,insetR, visible ? externalPlayerHeight : 0)`) | `MainActivity.java:403-406` |
| Player content padding | `playerContent.setPadding(systemBarInsets.left, systemBarInsets.top, systemBarInsets.right, 0)` | `MainActivity.java:415-416` |
| Bottom nav bar | `BottomNavigationView` height **64dp**, `itemPaddingTop=12dp`, `itemPaddingBottom=4dp`, `activeIndicatorLabelPadding=0dp`, label style `TextBottomNav` (11sp) | `main.xml:56-65`, `styles.xml:352-354` |
| Slide fade | player fragment alpha 1→0 across slideOffset 0.2→0.4; toolbar alpha 0→1 across 0.6→0.8 | `AudioPlayerFragment.java:533-541` |
| Pager page count | **2** (`POS_COVER=0`, `POS_DESCRIPTION=1`), `setOffscreenPageLimit(2)`. **There is no "chapters" page** — chapters is a modal dialog. | `AudioPlayerFragment.java:84-86,150-152` |

---

### A.1 Toolbar

`MaterialToolbar @+id/toolbar` — `match_parent` × `wrap_content`, `layout_alignParentTop="true"`,
`android:minHeight="?attr/actionBarSize"` (**≈56dp** — AppCompat `abc_action_bar_default_height_material`;
not overridden anywhere in this repo).

| Property | Value | Ref |
|---|---|---|
| Title | `""` (empty — `toolbar.setTitle("")`) | `AudioPlayerFragment.java:118` |
| Navigation icon | `@drawable/ic_arrow_down` — 24×24dp vector, viewport 24×24, `fillColor="?attr/action_icon_color"` (chevron-down path) | `audioplayer_fragment.xml:30-31`, `ui/common/res/drawable/ic_arrow_down.xml` |
| Navigation contentDescription | `@string/toolbar_back_button_content_description` = **"Back"** | `strings.xml:808` |
| Navigation action | collapses the bottom sheet (`setState(STATE_COLLAPSED)`) | `AudioPlayerFragment.java:119-120` |
| Menu source | `toolbar.inflateMenu(R.menu.mediaplayer)` | `AudioPlayerFragment.java:122` |
| Cast button | injected at runtime via `((CastEnabledActivity) getActivity()).requestCastButton(toolbar.getMenu())` | `AudioPlayerFragment.java:491` |

#### Menu items — declaration order in `res/menu/mediaplayer.xml`

| # | id | icon drawable | icon size | title string (exact English) | showAsAction | declared visible |
|---|---|---|---|---|---|---|
| 1 | `add_to_favorites_item` | `ic_star_border` | 24dp | "Add to favorites" | always | (runtime) |
| 2 | `remove_from_favorites_item` | `ic_star` | 24dp | "Remove from favorites" | always | (runtime) |
| 3 | `disable_sleeptimer_item` | `ic_sleep_off` | 24dp | "Sleep timer" | always | false |
| 4 | `set_sleeptimer_item` | `ic_sleep` | 24dp | "Set sleep timer" | always | true |
| 5 | `audio_controls` | — | — | "Audio controls" | never | false |
| 6 | `playback_speed` | — | — | "Playback speed" | never | false |
| 7 | `open_feed_item` | `ic_feed` | 24dp | "Open podcast" | collapseActionView | false → **set true** in `setupOptionsMenu()` |
| 8 | `visit_website_item` | `ic_web` | 24dp | "Visit website" | collapseActionView | false (runtime) |
| 9 | `player_switch_to_audio_only` | — | — | "Switch to audio only" | collapseActionView | false |
| 10 | `player_show_chapters` | — | — | "Chapters" | never | false |
| 11 | `transcript_item` | `transcript` (960×960 viewport, 24dp) | 24dp | "Show transcript" | never | true (runtime) |
| 12 | `open_social_interact_url` | `ic_chat` | 24dp | "Show comments" | never | false (runtime) |
| 13 | `share_item` | `ic_share` | 24dp | "Share" | always, `android:menuCategory="container"` | true (runtime) |

Runtime visibility is driven by `FeedItemMenuHandler.onPrepareMenu(...)`
(`app/.../ui/episodeslist/FeedItemMenuHandler.java:107-131`):
`add_to_favorites_item`/`remove_from_favorites_item`, `visit_website_item`, `share_item`,
`transcript_item`, `open_social_interact_url` are toggled. Items not present in `mediaplayer.xml`
(`skip_episode_item`, `remove_item`, `download_item`, `mark_read_item`, …) are silently ignored.

**Effective always-visible action bar order:** favourite star → sleep-timer icon → (cast, injected) → share.
**Overflow order:** Open podcast → Visit website → Show transcript → Show comments.

Sleep-timer swap logic (`AudioPlayerFragment.java:330-337`):
`set_sleeptimer_item` visible when `!timerActive`, `disable_sleeptimer_item` visible when `timerActive`.
Clicking either opens `SleepTimerDialog` (`AudioPlayerFragment.java:506-508`).

---

### A.2 Pager area (cover / shownotes), gradient, seek-time toast

| Element | Geometry | Notes | Ref |
|---|---|---|---|
| `ViewPager2 @+id/pager` | `match_parent` × `0dp`, `layout_above="@id/playtime_layout"`, `layout_below="@id/toolbar"`, `layout_marginBottom="12dp"`, `android:foreground="?android:windowContentOverlay"`, `android:orientation="vertical"` | 2 pages: CoverFragment, ItemDescriptionFragment | `audioplayer_fragment.xml:33-41` |
| Bottom gradient `ImageView` | `match_parent` × **8dp**, `layout_alignBottom="@id/pager"`, `srcCompat="@drawable/bg_gradient"`, `tint="?android:attr/colorBackground"`, `importantForAccessibility="no"` | `bg_gradient` = linear gradient `angle=90`, startColor `#ffffffff` → endColor `#00ffffff`, corners 0dp; tinted to the window background so it fades the pager content into the seek row | `audioplayer_fragment.xml:43-49`, `ui/common/res/drawable/bg_gradient.xml` |
| Seek-time toast `CardView @+id/cardViewSeek` | `wrap_content`×`wrap_content`, `layout_alignBottom="@+id/pager"`, `layout_centerHorizontal="true"`, marginLeft/Right **16dp**, marginBottom **12dp**, `android:alpha="0"`, `cardBackgroundColor="?attr/seek_background"`, `app:cardCornerRadius="8dp"`, `app:cardElevation="0dp"` | shown only while dragging the seek bar | `audioplayer_fragment.xml:51-64` |
| `TextView @+id/txtvSeek` | `wrap_content`×`wrap_content`, `gravity="center"`, paddingLeft/Right **24dp**, paddingTop/Bottom **4dp**, `textColor="@color/white"` = **#FFFFFF**, `textSize="16sp"` | text = chapter title + `"\n"` + position when chapters exist, else position only | `audioplayer_fragment.xml:66-77`, `AudioPlayerFragment.java:444-448` |
| Toast animation | start `scaleX=scaleY=0.8`, animate alpha 0→1 & scale→1 over **200ms** `FastOutSlowInInterpolator`; on release animate alpha→0 & scale→0.8 over 200ms | | `AudioPlayerFragment.java:452-485` |

`?attr/seek_background` resolves to `@color/seek_background_light` = **#90000000** (light) /
`@color/seek_background_dark` = **#905B5B5B** (dark) — `ui/common/res/values/styles.xml:21,78`,
`ui/common/res/values/colors.xml:19-20`.

#### Page 0 — `cover_fragment.xml` (see A.5)

#### Page 1 — `item_description_fragment.xml` (shownotes)

| Element | Geometry | Ref |
|---|---|---|
| Root `NestedScrollableHost` | `match_parent`×`match_parent`, `fillViewport="false"`, `nestedScrollingEnabled="true"`, `app:preferVertical="10"` | `item_description_fragment.xml:2-9` |
| `ShownotesWebView @+id/webview` | `match_parent`×`match_parent` | `item_description_fragment.xml:11-14` |
| HTML style | injected `assets/shownotes-style.css` with `body { padding: 8px 8px 8px 8px }` (8dp→px via `TypedValue.COMPLEX_UNIT_DIP`); `* { color: <android.R.attr.textColorPrimary> }`; `a { color: <R.attr.colorAccent> }`; `img, iframe { display:block; margin:10 auto; max-width:100%; height:auto }` | `ShownotesCleaner.java:53-66`, `app/src/main/assets/shownotes-style.css` |
| Load error view padding | 40dp on all sides (`40 * density`) | `ShownotesWebView.java:106-107` |

---

### A.3 Seek-bar row (`@+id/playtime_layout`)

`LinearLayout` `match_parent` × `wrap_content`, `layout_alignParentBottom="true"`,
`android:layoutDirection="ltr"`, `orientation="vertical"` — `audioplayer_fragment.xml:81-87`.

| Element | Geometry / values | Ref |
|---|---|---|
| `ChapterSeekBar @+id/sbPosition` | `match_parent` × `wrap_content`, marginLeft/Right **8dp**, `android:clickable="true"`, `android:max="500"` | `audioplayer_fragment.xml:89-97` |
| ChapterSeekBar custom paint | track height = `2 × 1.5dp` = **3dp** centred; chapter dividers: segment gap `1.2dp`, expanded (pressed/highlighted) height = `2 × 2.0dp` = **4dp**; `setBackground(null)` removes thumb shadow | `ChapterSeekBar.java:42,80-82,107-109` |
| ChapterSeekBar colors | background paint = `?attr/colorSurfaceVariant` at **alpha 128/255** (light #D3DCE0, dark #2F3B4F); progress paint = `?attr/colorPrimary` (light #0078C2, dark #3D8BFF); thumb = default AppCompat SeekBar thumb | `ChapterSeekBar.java:46-48`, `colors.xml:23-24,28-29` |
| Chapter dividers source | `dividerPos[i] = chapter.start / (float) duration`, padded with 0 and 1 | `AudioPlayerFragment.java:168-187` |
| Position/duration row | `RelativeLayout`, `match_parent`×`wrap_content`, `layout_marginTop="4dp"`, `layout_marginBottom="4dp"`, paddingLeft/Right **8dp** | `audioplayer_fragment.xml:99-105` |
| `NoRelayoutTextView @+id/txtvPosition` | `wrap_content`, alignParentStart/Left, marginStart/Left **16dp**, `text="@string/position_default_label"` = **"00:00:00"**, `textColor="?android:attr/textColorSecondary"` (light #444444 / dark #cccccc), `textSize="@dimen/text_size_micro"` = **12sp** | `audioplayer_fragment.xml:107-117`, `dimens.xml:4` |
| `NoRelayoutTextView @+id/txtvLength` | `wrap_content`, alignParentEnd/Right, marginEnd/Right **16dp**, `textAlignment="textEnd"`, `background="?android:attr/selectableItemBackground"` (tappable), same color token, **12sp** | `audioplayer_fragment.xml:119-131` |
| Length text modes | tap toggles between total duration and remaining time prefixed with `-`; contentDescriptions `"Position: %1$s"` / `"Remaining time: %1$s"` / `"Duration: %1$s"` | `AudioPlayerFragment.java:391-403`; `strings.xml:820-821,139` |

---

### A.4 Control row `@+id/player_control`

`RelativeLayout` `match_parent` × `wrap_content`, `android:layout_marginBottom="24dp"` — `audioplayer_fragment.xml:135-139`.

Dimens used: `audioplayer_playercontrols_length` = **48dp**, `audioplayer_playercontrols_length_big` = **64dp**,
`audioplayer_playercontrols_margin` = **12dp** (`ui/common/res/values/dimens.xml:21-23`).

Horizontal order left→right (LTR): **speed → rewind → PLAY (centre) → fast-forward → skip**.
Positioning is RelativeLayout-relative, not a LinearLayout:

| Control | id | size | margins / anchors | icon (size) | label | Ref |
|---|---|---|---|---|---|---|
| Play button | `butPlay` (`de.danoeh.antennapod.ui.screen.playback.PlayButton`) | **64×64dp** | centerHorizontal + centerVertical; marginStart/Left **12dp**, marginEnd/Right **12dp**; `background="?attr/selectableItemBackgroundBorderless"`, `android:padding="8dp"`, `scaleType="fitCenter"` | `@drawable/ic_play_48dp` (**48×48dp** vector, viewport 24×24) → animated swap to `ic_pause`/`ic_animate_play_pause`/`ic_animate_pause_play` | contentDescription `"Pause"` (`"Play"` when showing play) | `audioplayer_fragment.xml:141-156`, `PlayButton.java:31-50`, `strings.xml:252-253` |
| Buffering spinner | `CircularProgressBar` (no id) | **64×64dp** | centre, margins **16dp** each side; `app:foregroundColor="?attr/action_icon_color"` | — | — | `audioplayer_fragment.xml:158-167` |
| Loading indicator | `ProgressBar @+id/progLoading` | **64×64dp** | centre, `visibility="gone"`, `style="?android:attr/progressBarStyle"` | — | shown on `BufferUpdateEvent.hasStarted()` | `audioplayer_fragment.xml:169-176` |
| Rewind | `butRev` | **48×48dp** | centerVertical, marginStart/Left **12dp**, `layout_toStartOf="@id/butPlay"`, borderless ripple, `scaleType="fitCenter"` | `@drawable/ic_fast_rewind` (**48×48dp**) | — | `audioplayer_fragment.xml:178-191` |
| Rewind seconds label | `txtvRev` | `wrap_content` | `layout_below="@id/butRev"`, aligned start+end to `butRev`, `clickable="false"`, `gravity="center"` | — | default text `"30"`; set to `UserPreferences.getRewindSecs()` formatted; `textColor="?android:attr/textColorSecondary"`, `textSize="12sp"` | `audioplayer_fragment.xml:193-206`, `AudioPlayerFragment.java:344` |
| Playback speed | `butPlaybackSpeed` | **48×48dp** | centerVertical, `layout_toStartOf="@id/butRev"` (no gap → touches rewind), `android:padding="8dp"`, borderless ripple, `scaleType="fitCenter"`, `app:foregroundColor="?attr/action_icon_color"` | `@drawable/ic_playback_speed` (**24×24dp**) | contentDescription `"Playback speed"`; opens `VariableSpeedDialog` | `audioplayer_fragment.xml:208-220`, `AudioPlayerFragment.java:145-146` |
| Speed value label | `txtvPlaybackSpeed` | `wrap_content` | `layout_below="@id/butPlaybackSpeed"`, aligned start+end to it, `clickable="false"`, `gravity="center"` | — | default `"1.00"`, live value `new DecimalFormat("0.00").format(speed)`; `textColor="?android:attr/textColorSecondary"`, `textSize="12sp"` | `audioplayer_fragment.xml:222-235`, `AudioPlayerFragment.java:280-281` |
| Fast-forward | `butFF` | **48×48dp** | centerVertical, marginEnd/Right **12dp**, `layout_toEndOf="@id/butPlay"`, borderless ripple | `@drawable/ic_fast_forward` (**48×48dp**) | — | `audioplayer_fragment.xml:237-250` |
| FF seconds label | `txtvFF` | `wrap_content` | `layout_below="@id/butFF"`, aligned start+end to `butFF`, `gravity="center"` | — | default `"30"`; `UserPreferences.getFastForwardSecs()`; `textColor="?android:attr/textColorSecondary"`, `textSize="12sp"` | `audioplayer_fragment.xml:252-265`, `AudioPlayerFragment.java:345` |
| Skip | `butSkip` | **48×48dp** | centerVertical, `layout_toEndOf="@id/butFF"` (no gap → touches FF), borderless ripple | `@drawable/ic_skip_48dp` (**48×48dp**) | contentDescription `"Skip episode"` | `audioplayer_fragment.xml:267-278`, `strings.xml:308` |

Geometry summary: play = 64dp square with 12dp horizontal margins; the two 48dp buttons on each side are
flush against each other (0dp gap) and 12dp from the play button; each 48dp button carries a 12sp
secondary-colour number label directly underneath it (increasing the row's effective height beyond 64dp).
Long-press on `butRev`/`butFF` opens the skip-seconds preference dialog (`SkipPreferenceDialog`).
Row bottom margin = **24dp**.

---

### A.5 `cover_fragment.xml` (pager page 0)

Root `LinearLayout @+id/cover_fragment`, `match_parent`×`match_parent`, `orientation="vertical"`, `android:padding="8dp"` — `cover_fragment.xml:2-11`.

| Element | Geometry | Ref |
|---|---|---|
| `ConstraintLayout @+id/coverHolder` | `match_parent` × `0dp`, `layout_weight="1"` | `:13-17` |
| `ImageView @+id/imgvCover` | `0dp`×`0dp` constrained to all 4 parent sides; `layout_marginHorizontal="32dp"`; `app:layout_constraintDimensionRatio="1:1"`; `squareImageView:direction="minimum"`; `scaleType="fitCenter"`; `foreground="@drawable/cover_fragment_ripple_border"`; `importantForAccessibility="no"` | `:19-34` |
| → effective cover size | **min(availableWidth − 64dp, availableHeight)**, always 1:1 square, centred | derived |
| Cover corner radius | **16dp** — Glide `RoundedCorners((int)(16 * density))` + `FitCenter` | `CoverFragment.java:318-322` |
| Ripple border | `cover_fragment_ripple_border` = ripple with mask rect `corners radius="16dp"`, `colorControlHighlight` | `app/res/drawable/cover_fragment_ripple_border.xml` |
| `LinearLayout @+id/cover_fragment_text_container` | `match_parent`×`wrap_content`, `layout_marginVertical="8dp"`, `gravity="center"`, `orientation="vertical"` | `:38-44` |
| `TextView @+id/txtvPodcastTitle` | `match_parent`×`wrap_content`; `background="?android:selectableItemBackground"`; `ellipsize="none"`; `gravity="center_horizontal"`; **maxLines 2**; paddingTop/Bottom **2dp**; `textColor="?android:attr/textColorSecondary"`; `textSize="@dimen/text_size_small"` = **14sp**; `textIsSelectable="false"` | `:46-59` |
| Podcast-title content | `feedTitle + "\u00A0" + "・" + "\u00A0" + abbrevPubDate` (non-breaking spaces); tap opens feed; long-press copies | `CoverFragment.java:148-159` |
| `TextView @+id/txtvEpisodeTitle` | `match_parent`×`wrap_content`; `ellipsize="none"`; `gravity="center_horizontal"`; **maxLines 2**; paddingTop/Bottom **2dp**; `textColor="?android:attr/textColorPrimary"`; `textSize="14sp"`; `layout_marginBottom="32dp"` | `:61-74` |
| Episode-title marquee | tap animates `scrollY` for `lines*1500ms`, fades out after 1500ms then fades back in | `CoverFragment.java:162-188` |
| `LinearLayout @+id/episode_details` | `wrap_content` × **36dp**; `baselineAligned="false"`; horizontal; `layout_gravity="center_horizontal"`; paddingLeft/Right **8dp** | `:78-86` |
| `LinearLayout @+id/openDescription` | `match_parent`×`wrap_content`; `layout_marginHorizontal="8dp"`; `paddingHorizontal="8dp"`; `background="@drawable/grey_border"`; clickable+focusable; `gravity="center"`; **minWidth 150dp**; `layout_weight="1"`; horizontal | `:88-100` |
| `grey_border` drawable | ripple; shape = rectangle, corners **8dp**, `stroke width="1dp" color="?android:attr/textColorSecondary"`, solid transparent | `app/res/drawable/grey_border.xml` |
| `ImageView @+id/description_icon` | `wrap_content` × **36dp**; `padding="2dp"`; `srcCompat="@drawable/ic_info"` (24×24dp); contentDescription `"swipe up to read shownotes"`; colorFilter = `txtvPodcastTitle` text colour with `SRC_IN` | `:102-108`, `CoverFragment.java:105-109`, `strings.xml:142` |
| `TextView @+id/shownotes_label` | `wrap_content`; `ellipsize="none"`; marginStart/Left **2dp**; `gravity="center_horizontal"`; **maxLines 2**; text `"Shownotes"`; `textColor="?android:attr/textColorSecondary"`; **16sp** | `:110-121`, `strings.xml:141` |
| `LinearLayout @+id/chapterButton` | `match_parent`×`wrap_content`; `layout_marginHorizontal="8dp"`; `layout_weight="1"`; `background="@drawable/grey_border"`; clickable+focusable; `gravity="center"`; **minWidth 150dp**; horizontal; `visibility="gone"` until chapters exist | `:125-138` |
| `ImageButton @+id/butPrevChapter` | **36×36dp**; borderless ripple; `scaleType="fitCenter"`; `srcCompat="@drawable/ic_chapter_prev"` (24dp); contentDescription `"Previous chapter"`; colorFilter as above | `:140-147`, `strings.xml:823` |
| `TextView @+id/chapters_label` | `0dp`×`wrap_content`, `layout_weight="1"`, `gravity="center"`, text `"Chapters"`, `textColor="?android:attr/textColorSecondary"`, `textSize="@dimen/text_size_navdrawer"` = **16sp** | `:149-157`, `strings.xml:137` |
| `ImageButton @+id/butNextChapter` | **36×36dp**; `srcCompat="@drawable/ic_chapter_next"`; contentDescription `"Next chapter"`; set `INVISIBLE` on last chapter | `:159-166`, `strings.xml:824`, `CoverFragment.java:229-235` |
| Tapping `chapterButton` | opens `ChaptersFragment` dialog | `CoverFragment.java:110-111` |

**Orientation switch** (`CoverFragment.java:350-370`):
- Portrait: root vertical; `coverHolder` = match_parent × 0dp weight 1; text container = match_parent × wrap_content;
  `episode_details` is a child of the **root** (below the text block).
- Landscape: root horizontal; `coverHolder` = 0dp × match_parent weight 1; text container = 0dp × match_parent weight 1;
  `episode_details` is re-parented **inside** the text container.

#### Chapters dialog (`ChaptersFragment`)
`MaterialAlertDialogBuilder`: title `"Chapters"`, view = `R.layout.simple_list_fragment` with the toolbar
forced `GONE`; positive button `"Close"`, neutral button `"Refresh"` (visible only when
`item.getPodcastIndexChapterUrl()` is non-empty). Content = `RecyclerView @+id/recyclerView` with
`DividerItemDecoration`, `ProgressBar @+id/progLoading` while loading. Empty list → `dismiss()` + Toast
`"No chapters"`. Row = `simplechapter_item.xml`: cover `@dimen/thumbnail_length_queue_item` = **56×56dp**
marginStart **16dp**; text column weight 1 marginStart **16dp**, marginTop/Bottom
`@dimen/listitem_threeline_verticalpadding` = **11dp**, marginEnd `@dimen/listitem_threeline_textrightpadding` = **8dp**;
`txtvStart` (secondary style, 1 line), `txtvTitle` (primary style, 2 lines/20sp lineHeight), `txtvLink` (gone),
`txtvDuration`; trailing `@layout/secondary_action` = **48×48dp** button, marginEnd **12dp**, icon **24×24dp**,
`CircularProgressBar` 40×40dp.

#### Transcript dialog (`TranscriptDialogFragment` + `transcript_dialog.xml`)
`LinearLayout` match_parent/match_parent vertical; `MaterialToolbar @+id/toolbar` match_parent × `?attr/actionBarSize`
with `app:title="Transcript"`; `ProgressBar @+id/progLoading` match_parent × wrap_content, centred, indeterminate, gone;
`RecyclerView @+id/transcript_list` match_parent × 0dp weight 1, vertical scrollbar, `scrollbarStyle="outsideInset"`,
`scrollIndicators="right"`; `CheckBox @+id/followAudioCheckbox` match_parent × wrap_content,
`layout_marginHorizontal="16dp"`, text `"Follow audio"`.
Row `transcript_item.xml`: `speaker` TextView match_parent × wrap_content, marginVertical **8dp**,
paddingHorizontal **24dp**, `textStyle="bold"`, `textColor="?android:attr/textColorPrimary"`;
`content` TextView match_parent × wrap_content, `minLines=1`, `maxLines=100`, paddingHorizontal **24dp**,
`textColor="?android:attr/textColorPrimary"`.

---

### A.6 Playback-speed dialog (`speed_select_dialog.xml` + `VariableSpeedDialog`)

Shown as a `BottomSheetDialogFragment`.

| Element | Geometry | Ref |
|---|---|---|
| Root `LinearLayout` | `match_parent`×`match_parent`, vertical, `android:padding="16dp"` | `speed_select_dialog.xml:2-7` |
| Header row | `match_parent`×`wrap_content` horizontal | `:9-11` |
| `TextView` label | `0dp` × wrap_content, weight 1, text `"Playback speed"`, `style="@style/AntennaPod.TextView.ListItemPrimaryTitle"` | `:13-18`, `strings.xml:941` |
| `Chip @+id/add_current_speed_chip` | `wrap_content`×`wrap_content`; text = speed `"%1$.2f"`; close icon enabled with `@drawable/ic_add`, closeIcon contentDescription `"Add preset"` | `:20-23`, `VariableSpeedDialog.java:107,136-141`, `strings.xml:826` |
| `PlaybackSpeedSeekBar @+id/speed_seek_bar` | `match_parent`×`wrap_content`, `layout_marginTop="-8dp"` | `:27-31` |
| → inner layout | horizontal, `gravity="center_vertical"` | `playback_speed_seek_bar.xml:2-8` |
| → `ImageView @+id/butDecSpeed` | **48×48dp**, `padding="14dp"`, `src="@drawable/ic_minus"` (24dp), `app:tint="?attr/colorSecondary"`, borderless ripple, contentDescription `"Decrease speed"` | `:10-19`, `strings.xml:812` |
| → `SeekBar @+id/playback_speed` | `0dp` × wrap_content weight 1, `android:minHeight="40dp"`, `android:max="70"`, `android:paddingVertical="4dp"` | `:21-28` |
| → speed mapping | `progress = round(20*speed − 10)`; `speed = (progress + 10)/20` → range **0.50× … 4.00×** in **0.05** steps | `PlaybackSpeedSeekBar.java:69-82` |
| → `ImageView @+id/butIncSpeed` | **48×48dp**, `padding="14dp"`, `src="@drawable/ic_add"`, tint `?attr/colorSecondary`, contentDescription `"Increase speed"` | `:30-39`, `strings.xml:811` |
| `TextView` "Presets" | `wrap_content`, `layout_marginBottom="8dp"`, text `"Presets"`, style `ListItemPrimaryTitle` | `:33-38`, `strings.xml:422` |
| `RecyclerView @+id/selected_speeds_grid` | `match_parent`×`wrap_content`; `GridLayoutManager` **spanCount = 3**; `ItemOffsetDecoration(context, 4)` → **4dp** offsets; items = Material `Chip` with `textAlignment=center` and text `"%1$.2f"` | `:40-43`, `VariableSpeedDialog.java:129-134,176-185` |
| `CheckBox @+id/skipSilence` | `match_parent`×`wrap_content`, text `"Skip silence in audio"` | `:45-49`, `strings.xml:592` |
| Snackbar on duplicate preset | `"%1$.2fx is already saved as a preset."` | `strings.xml:423` |

### A.7 Sleep-timer dialog (`time_dialog.xml` + `SleepTimerDialog`)

Also a `BottomSheetDialogFragment`.

| Element | Geometry / text | Ref |
|---|---|---|
| Root `ScrollView` | `match_parent`×`wrap_content` | `time_dialog.xml:2-7` |
| Inner `LinearLayout` | `match_parent`×`wrap_content`, vertical, `gravity="center"`, `padding="16dp"` | `:9-14` |
| `LinearLayout @+id/timeSetupContainer` | `match_parent`×`wrap_content`, vertical | `:16-20` |
| `EditText @+id/timeEditText` | `0dp` × wrap_content weight 1, `layout_margin="8dp"`, `ems="2"`, `inputType="number"`, `maxLength="3"`, `selectAllOnFocus="true"` | `:27-36` |
| `Spinner @+id/sleepTimerType` | `wrap_content`×`wrap_content`, `layout_marginTop="8dp"`, `layout_marginBottom="8dp"`; entries: **"minutes"** (`time_minutes`), **"episodes"** (`sleep_timer_episodes_label`) | `:38-44`, `SleepTimerDialog.java:152-156`, `strings.xml:723,703` |
| `TextView @+id/sleepTimerHintText` | `match_parent`×`wrap_content`, `visibility="visible"`, `layout_margin="8dp"`; text = `"Continuous playback is disabled in the settings. Always stopping at the end of the episode."` or a `num_episodes` quantity string | `:48-54`, `SleepTimerDialog.java:324,349`, `strings.xml:714` |
| `Button @+id=setSleeptimerButton` | `match_parent`×`wrap_content`, text `"Set sleep timer"`, `style="@style/Widget.Material3.Button"` | `:56-61`, `strings.xml:700` |
| `LinearLayout @+id=timeDisplayContainer` | `match_parent`×`wrap_content`, vertical, `visibility="visible"` | `:65-70` |
| `TextView @+id=time` | `match_parent`×`match_parent`, text `"00:00:00"`, `gravity="center"`, **textSize 32sp**, `textColor="?android:attr/textColorPrimary"` | `:72-80` |
| Extend row | horizontal, `gravity="center_vertical"`, 3 × `Button` each `0dp` weight 1, `paddingHorizontal="2dp"`, `paddingVertical="4dp"`, `style="?attr/materialButtonOutlinedStyle"`, inter-button margin **4dp** | `:82-125` |
| Extend labels (timer mode) | `extend_sleep_timer_label` = **"+%d min"** with display values **+5 min / +10 min / +30 min** | `strings.xml:702`, `SleepTimerDialog.java:61-66,386-393` |
| Extend labels (episodes mode) | `num_episodes` plurals → **"1 episode" / "2 episodes" / "3 episodes"** | `strings.xml:177-180`, `SleepTimerDialog.java:397-403` |
| `Button @+id=disableSleeptimerButton` | `match_parent`×`wrap_content`, text `"Disable sleep timer"`, `style="@style/Widget.Material3.Button"` | `:127-132`, `strings.xml:701` |
| Bottom `LinearLayout` | `match_parent`×`wrap_content`, vertical, `layout_marginTop="8dp"` | `:136-140` |
| `CheckBox @+id=shakeToResetCheckbox` | `match_parent`×`wrap_content`, text `"Shake to reset"` | `:142-146`, `strings.xml:720` |
| `CheckBox @+id=vibrateCheckbox` | `match_parent`×`wrap_content`, text `"Vibrate shortly before end"` | `:148-152`, `strings.xml:721` |
| Row `weightSum="1"` | `CheckBox @+id=autoEnableCheckbox` `0dp` weight 1, text `"Automatically activate the sleep timer when pressing play"` (or `"…between %1$s and %2$s"`), + `ImageView @+id=changeTimesButton` `wrap_content` × match_parent, borderless ripple, `srcCompat="@drawable/ic_settings"`, contentDescription `"Change time range"` | `:154-175`, `strings.xml:741-743` |
| `Button @+id=playbackPreferencesButton` | `match_parent`×`wrap_content`, `visibility="visible"`, text `"Settings"` | `:177-182`, `strings.xml:27` |
| Error colour | EditText text set to `?attr/colorError` on invalid input; Snackbar `"Invalid input, time has to be an integer"` | `SleepTimerDialog.java:299,268`, `strings.xml:709` |
| Confirm dialog strings | `"Disable continuous playback"`, `"Change hours"`, message `"Instead of always automatically enabling the sleep timer with one episode, please instead disable \"continuous playback\" in the settings."` | `strings.xml:704-706` |

### A.8 Audio-track selection dialog (`audio_controls.xml`)

Used by `PlaybackControlsDialog` (menu item `audio_controls`, title `"Audio controls"`,
positive button `"Close"`).

`HorizontalScrollView` `match_parent`×`wrap_content`, `android:padding="16dp"`, `scrollbars="none"`;
inner `LinearLayout @+id/track_selection_container` `wrap_content`×`wrap_content`, horizontal,
`gravity="center_vertical"`; rows inflated from `item_tag_chip` (`Chip`), `chip.setText(opt.label)`.

### A.9 Mini-player / external player row (`external_player_height` = 64dp)

Appears in **two** places:
1. As the collapsed state of the player bottom sheet (peek height 64dp; main content gets a 64dp bottom margin).
2. As `@+id/playerFragment` **at the top of the expanded player sheet** — `FragmentContainerView`
   `match_parent` × `wrap_content`, `layout_gravity="top"`, `android:elevation="8dp"`,
   `android:outlineProvider="none"`, `android:background="?attr/colorSurfaceContainer"`
   (light **#EBEEF3** / dark **#1C2024**), `tools:layout_height="@dimen/external_player_height"`.
   It is also faded out as the sheet slides up (`fadePlayerToToolbar`).

`external_player_fragment.xml` (`LinearLayout @+id/fragmentLayout`, `match_parent` × **64dp**,
`background="?attr/selectableItemBackground"`, vertical):

| Element | Geometry | Ref |
|---|---|---|
| Row container | `match_parent` × `0dp` weight 1, `gravity="center_vertical"` | `:12-16` |
| `ImageView @+id/imgvCover` | `wrap_content` × `match_parent`, `adjustViewBounds="true"`, `cropToPadding="true"`, **`android:maxWidth="96dp"`**, `scaleType="fitCenter"`, `background="@color/non_square_icon_background"` = **#22777777**; placeholder/error colour `@color/light_gray` = #bfbfbf | `:18-27`, `ExternalPlayerFragment.java:169-181`, `colors.xml:7,18` |
| Text column | `0dp` × wrap_content weight 1, vertical, marginStart/Left **16dp** | `:29-35` |
| `TextView @+id/txtvTitle` | `match_parent`×`wrap_content`, `ellipsize="end"`, `maxLines="1"`, `style="@style/Base.TextAppearance.AppCompat.Body1"` (16sp) | `:37-44` |
| `TextView @+id/txtvAuthor` | `match_parent`×`wrap_content`, `textColor="?android:attr/textColorSecondary"`, `ellipsize="end"`, `maxLines="1"`, `style="@style/TextAppearance.AppCompat.Body1"` | `:46-54` |
| `PlayButton @+id/butPlay` | **52dp** × `match_parent`, contentDescription `"Pause"`, `background="?attr/selectableItemBackground"`, `scaleType="fitCenter"`, `android:padding="8dp"`, `srcCompat="@drawable/ic_play_48dp"`; hidden for video media | `:58-67`, `ExternalPlayerFragment.java:183-190` |
| `LinearProgressIndicator @+id/episodeProgress` | `match_parent` × **4dp**, `indeterminate="false"`, `app:trackStopIndicatorSize="0dp"`; progress = `position/duration*100` | `:71-77`, `ExternalPlayerFragment.java:118-123` |
| Tap behaviour | audio → expand bottom sheet; video → launch player activity | `ExternalPlayerFragment.java:69-80` |

---

### A.10 Colour / attr tokens used by the player (resolved)

| Token | Light | Dark | Ref |
|---|---|---|---|
| `@color/white` | #FFFFFF | #FFFFFF | `ui/common/.../colors.xml:4` |
| `@color/black` | #000000 | #000000 | `:9` |
| `@color/light_gray` | #bfbfbf | #bfbfbf | `:7` |
| `@color/grey600` | #757575 | #757575 | `:6` |
| `@color/background_light` | #f9fcff | — | `:14` |
| `@color/background_darktheme` | — | #21272b | `:16` |
| `@color/background_elevated_light` | #EFEEEE | — | `:15` |
| `@color/background_elevated_darktheme` | — | #2D3337 | `:17` |
| `@color/non_square_icon_background` | #22777777 | #22777777 | `:18` |
| `@color/seek_background_light` | #90000000 | — | `:19` |
| `@color/seek_background_dark` | — | #905B5B5B | `:20` |
| `@color/text_color_secondary_light` | #444444 | — | `:21` |
| `@color/text_color_secondary_dark` | — | #cccccc | `:22` |
| `@color/color_surface_variant_light` | #D3DCE0 | — | `:23` |
| `@color/color_surface_variant_dark` | — | #2F3B4F | `:24` |
| `@color/color_secondary_container_light` | #C8D8DE | — | `:25` |
| `@color/color_secondary_container_dark` | — | #3C4E68 | `:26` |
| `@color/accent_light` (`colorPrimary`/`colorSecondary`) | #0078C2 | — | `:28` |
| `@color/accent_dark` | — | #3D8BFF | `:29` |
| `?attr/colorSurfaceContainer` | #EBEEF3 | #1C2024 | `ui/common/.../styles.xml:53,112` |
| `?attr/colorSurfaceContainerHighest` | #C0CFD3 | #38455C | `:62,121` |
| `?attr/colorPrimaryContainer` | #D6E6F3 | #29374E (TrueBlack #0D182B) | `:45,104,142` |
| `?attr/action_icon_color` | #000000 | #FFFFFF | `:19,75` |
| `?attr/colorSurface` / `?android:attr/colorBackground` | #f9fcff | #21272b | `:48,107` |
| `?android:attr/textColorPrimary` | #000000 | #FFFFFF | `:56,115` |
| `?android:attr/textColorSecondary` | #444444 | #cccccc | `:57,116` |
| `?attr/colorOnSurfaceVariant` | #444444 | #cccccc | `:52,111` |
| icon tints | red #CF1800, yellow #F59F00, green #008537, purple #5F1984 / #AA55D8, gray #25365A / #CDD9E4 | | `:24-28,81-85` |

Custom attrs declared in `ui/common/src/main/res/values/attrs.xml:4-13`:
`action_icon_color`, `background_color`, `background_elevated`, `seek_background`,
`icon_red`, `icon_yellow`, `icon_green`, `icon_purple`, `icon_gray`, `dragview_background`, `scrollbar_thumb`.

Text styles (`ui/common/src/main/res/values/styles.xml`):

| Style | Parent | textSize | textColor | other |
|---|---|---|---|---|
| `AntennaPod.TextView.Heading` | `@android:style/TextAppearance.Medium` | `@dimen/text_size_large` = **22sp** | `?android:attr/textColorPrimary` | `fontFamily=sans-serif-light` |
| `AntennaPod.TextView.ListItemPrimaryTitle` | `TextAppearance.Material3.BodyLarge` | 16sp (M3) | `?attr/colorOnSurface` | maxLines 2, ellipsize end, lineHeight **20sp** |
| `AntennaPod.TextView.FeedListItemPrimaryTitle` | `TextAppearance.Material3.BodyLarge` | 16sp | inherited | maxLines 2, lineHeight 20sp |
| `AntennaPod.TextView.ListItemSecondaryTitle` | `TextAppearance.Material3.BodyMedium` | 14sp (M3) | `?attr/colorOnSurfaceVariant` | lines 1, ellipsize end |
| `AntennaPod.TextView.FeedListItemSecondaryTitle` | `TextAppearance.Material3.LabelSmall` | 11sp (M3) | inherited | lines 1, ellipsize end |
| `TextBottomNav` | `TextAppearance.Material3.TitleSmall` | **11sp** | inherited | bottom-nav labels |
| `Style.AntennaPod.Toolbar` | `Widget.Material3.Toolbar` | — | `action_icon_color` = `?attr/colorOnSurface` | via `Theme.AntennaPod.Toolbar` |

Spacing dimens (`ui/common/src/main/res/values/dimens.xml`):
`text_size_micro` 12sp, `text_size_small` 14sp, `text_size_navdrawer` 16sp, `text_size_large` 22sp,
`thumbnail_length_itemlist` 56dp, `thumbnail_length_queue_item` 56dp, `thumbnail_length_navlist` 40dp,
`listitem_iconwithtext_height` 48dp, `listitem_iconwithtext_textleftpadding` 16dp,
`listitem_threeline_textleftpadding` 16dp, `listitem_threeline_textrightpadding` 8dp,
`listitem_threeline_verticalpadding` 11dp, `list_vertical_padding` 8dp, `listitem_icon_leftpadding` 16dp,
`audioplayer_playercontrols_length` 48dp, `audioplayer_playercontrols_length_big` 64dp,
`audioplayer_playercontrols_margin` 12dp, `external_player_height` 64dp, `nav_drawer_max_screen_size` 480dp.

`app/src/main/res/values/dimens.xml`: `additional_horizontal_spacing` 0dp (→ **56dp** at `values-w1000dp`),
`drawer_corner_size` 16dp, `floating_select_menu_height` 112dp.


---

## B.1 / B.2 — ADD FEED and SEARCH

Source of truth: upstream AntennaPod Android repo at `D:\Git\antennapod-harmony\antenna-repo` (read-only).
Every numeric claim carries a `file:line` reference. Units are `dp`/`sp` exactly as written in the resource.
Anything not present in the code is called out explicitly under §15 "Non-existent / explicit negatives".

Paths below are relative to `antenna-repo/`.

---

### 1. Shared host chrome (applies to both screens)

Both screens are fragments hosted in `MainActivity` (`app/src/main/java/de/danoeh/antennapod/activity/MainActivity.java:444-446` for AddFeed, `SearchFragment` loaded as a child fragment).

| Element | Value | Ref |
|---|---|---|
| Root | `LinearLayout`, `match_parent`/`match_parent`, `orientation=vertical` | `app/src/main/res/layout/main.xml:2-11` |
| Drawer | `DrawerLayout` `@+id/drawer_layout`, `match_parent`/`0dp` + `layout_weight=1` | `app/src/main/res/layout/main.xml:16-20` |
| Content | `FragmentContainerView` `@+id/main_content_view`, `match_parent`/`match_parent`, `foreground=?android:windowContentOverlay` | `app/src/main/res/layout/main.xml:27-33` |
| Player sheet | `@+id/audioplayerFragment`, `elevation=8dp`, `visibility=gone`, `app:layout_behavior=LockableBottomSheetBehavior` | `app/src/main/res/layout/main.xml:35-43` |
| Drawer fragment | `@+id/navDrawerFragment`, `match_parent`/`match_parent`, `layout_gravity=start` | `app/src/main/res/layout/main.xml:47-52` |
| Bottom nav | `BottomNavigationView` `@+id/bottomNavigationView`, `match_parent`/`64dp`, `itemPaddingTop=12dp`, `itemPaddingBottom=4dp`, `activeIndicatorLabelPadding=0dp`, `labelVisibilityMode=labeled`, text appearance `@style/TextBottomNav` (11sp) | `app/src/main/res/layout/main.xml:56-65`; `ui/common/src/main/res/values/styles.xml:352-354` |
| Bottom inset filler | `View` `@+id/bottom_padding`, height `0dp`, `background=?attr/colorSurfaceContainer` | `app/src/main/res/layout/main.xml:67-71` |
| External player height | `64dp` | `ui/common/src/main/res/values/dimens.xml:3` |
| Bottom-nav items | Built in code: up to `min(5, getMaxItemCount())`; AddFeed item id `@id/bottom_navigation_addfeed`, short label `@string/add_feed_label_short` = `"Add"`, icon `@drawable/ic_add`; overflow item `@id/bottom_navigation_more` = `"More"` / `@drawable/dots_vertical` | `app/src/main/java/de/danoeh/antennapod/ui/screen/drawer/BottomNavigation.java:51-62`; `.../NavigationNames.java:36-37, 63-64, 92-93, 117-118, 142-143`; `app/src/main/res/values/ids.xml:37,40`; `ui/i18n/src/main/res/values/strings.xml:16, 466` |
| `additional_horizontal_spacing` | `0dp` default; `56dp` at `w1000dp`; `0dp` at `w300dp` | `app/src/main/res/values/dimens.xml:3`; `app/src/main/res/values-w1000dp/dimens.xml:3`; `app/src/main/res/values-w300dp/dimens.xml:3` |
| `floating_select_menu_height` | `112dp` | `app/src/main/res/values/dimens.xml:6` |

---

### 2. ADD FEED — Toolbar

`app/src/main/res/layout/addfeed.xml:9-24`.

| Property | Value | Ref |
|---|---|---|
| Container | `com.google.android.material.appbar.AppBarLayout` `@+id/appbar`, `match_parent`/`wrap_content`, `fitsSystemWindows=true` | `addfeed.xml:9-13` |
| Toolbar | `com.google.android.material.appbar.MaterialToolbar` `@+id/toolbar`, `match_parent`/`wrap_content`, `minHeight=?attr/actionBarSize` | `addfeed.xml:15-19` |
| Title | `app:title="@string/add_feed_label"` → literal **"Add podcast"** | `addfeed.xml:20`; `ui/i18n/src/main/res/values/strings.xml:15` |
| Navigation icon (XML) | `app:navigationIcon="?homeAsUpIndicator"` | `addfeed.xml:22` |
| Navigation contentDescription | `app:navigationContentDescription="@string/toolbar_back_button_content_description"` → **"Back"** | `addfeed.xml:21`; `strings.xml:808` |
| Navigation icon (runtime) | `MainActivity.setupToolbarToggle()`: when `displayUpArrow==false` and a drawer exists → `ActionBarDrawerToggle` hamburger (`@drawable/abc_ic_drawer`-equivalent, content desc `"Open menu"`/`"Close menu"`); when no drawer and `!displayUpArrow` → `setNavigationIcon(null)`; otherwise `ThemeUtils.getDrawableFromAttr(this, R.attr.homeAsUpIndicator)` | `app/src/main/java/de/danoeh/antennapod/activity/MainActivity.java:336-353`; `AddFeedFragment.java:86-90`; `strings.xml:91-92` |
| Toolbar menu | **NONE.** `AddFeedFragment` never calls `inflateMenu()` / `setSupportActionBar`; there is no `res/menu` file for this screen. | `app/src/main/java/de/danoeh/antennapod/ui/screen/AddFeedFragment.java:77-130` (no `inflateMenu` anywhere) |
| `?attr/actionBarSize` | Not defined in this repo → Material3 default `56dp` | grep: no `actionBarSize` dimension declared in `antenna-repo` (only `?attr/actionBarSize` references, e.g. `addfeed.xml:19`) |
| AppBar lift | `LiftOnScrollListener(viewBinding.appbar)` animates `appbar` background from `colorSurfaceContainer & 0x00ffffff` → full `?attr/colorSurfaceContainer` on scroll | `AddFeedFragment.java:92-93`; `ui/common/src/main/java/de/danoeh/antennapod/ui/common/LiftOnScrollListener.java:18-21, 44-59` |

---

### 3. ADD FEED — top-level content structure (`addfeed.xml`)

Root → `LinearLayout` `match_parent`/`match_parent`, `orientation=vertical`, no id, no padding, no background (`addfeed.xml:2-7`).

| # | Element | id | width × height | Layout / padding / margin | Background | Ref |
|---|---|---|---|---|---|---|
| 1 | `AppBarLayout` | `appbar` | `match_parent` × `wrap_content` | `fitsSystemWindows=true` | — | `addfeed.xml:9-13` |
| 2 | `MaterialToolbar` | `toolbar` | `match_parent` × `wrap_content` | `minHeight=?attr/actionBarSize` | — | `addfeed.xml:15-22` |
| 3 | `androidx.core.widget.NestedScrollView` | `scrollView` | `match_parent` × `0dp` + `layout_weight=1` | `scrollbars=vertical` | — | `addfeed.xml:26-31` |
| 3.1 | `LinearLayout` (scroll content) | — | `match_parent` × `wrap_content` | `orientation=vertical`, `paddingBottom=16dp` | — | `addfeed.xml:33-37` |
| 3.1.1 | `androidx.cardview.widget.CardView` | — | `match_parent` × `wrap_content` | `marginTop=8dp`, `marginBottom=8dp`, `marginHorizontal=16dp`, `cardCornerRadius=28dp`, `cardElevation=0dp` | — | `addfeed.xml:39-46` |
| 3.1.2 | `FragmentContainerView` | `quickFeedDiscovery` | `match_parent` × `wrap_content` | `marginVertical=16dp`, `marginHorizontal=16dp`, `android:name=de.danoeh.antennapod.ui.discovery.QuickFeedDiscoveryFragment` | — | `addfeed.xml:88-94` |
| 3.1.3 | `TextView` × 6 (add-podcast rows) | `addViaUrlButton`, `addLocalFolderButton`, `searchItunesButton`, `searchFyydButton`, `searchPodcastIndexButton`, `opmlImportButton` | `match_parent` × `wrap_content` | `style=@style/AddPodcastTextView` (see §4.1) | `?android:attr/selectableItemBackground` (from style) | `addfeed.xml:96-148` |

Scroll behavior: the only scrolling container on the screen is the `NestedScrollView` (`@+id/scrollView`); the quick-discovery grid is *inside* it, so the whole page scrolls as one column (`addfeed.xml:26-152`).

---

### 4. ADD FEED — the "search bar card"

`addfeed.xml:39-86`. **There is no `TextInputLayout` and no trailing clear/voice icon** — only a leading `ImageView` + a plain `EditText`.

| Element | Property | Value | Ref |
|---|---|---|---|
| `CardView` | width × height | `match_parent` × `wrap_content` | `addfeed.xml:40-41` |
| | corner radius | `app:cardCornerRadius=28dp` | `addfeed.xml:45` |
| | elevation | `app:cardElevation=0dp` | `addfeed.xml:46` |
| | margins | top `8dp`, bottom `8dp`, horizontal `16dp` | `addfeed.xml:42-44` |
| | min/measured height | no explicit height; measured = max(48dp icon, EditText wrap_content) ≈ 48–52dp | `addfeed.xml:56-82` |
| `LinearLayout` `@+id/searchbar` | width × height | `match_parent` × `wrap_content` | `addfeed.xml:49-51` |
| | orientation / gravity | `horizontal` / `center_vertical` | `addfeed.xml:52-53` |
| | background | `?attr/colorSurfaceContainer` → `#EBEEF3` light / `#1C2024` dark | `addfeed.xml:54`; `ui/common/src/main/res/values/styles.xml:53, 112` |
| | corner radius (visual) | inherited from the CardView clip: `28dp` | `addfeed.xml:45` |
| `ImageView` `@+id/searchButton` | size | `48dp` × `48dp` | `addfeed.xml:57-59` |
| | padding / scaleType | `padding=12dp` / `center` (⇒ visible glyph 24dp) | `addfeed.xml:60, 64` |
| | margins | `layout_marginLeft=8dp`, `layout_marginRight=8dp` | `addfeed.xml:61-62` |
| | drawable | `app:srcCompat="@drawable/ic_search"` (vector 24×24dp, viewport 24, fill `?attr/action_icon_color`) | `addfeed.xml:65`; `ui/common/src/main/res/drawable/ic_search.xml:1-4` |
| | contentDescription | `@string/search_podcast_hint` → **"Search podcast…"** | `addfeed.xml:63`; `strings.xml:891` |
| `EditText` `@+id/combinedFeedSearchEditText` | size / weight | `0dp` × `wrap_content`, `layout_weight=1` | `addfeed.xml:69-71` |
| | padding | `paddingTop=16dp`, `paddingBottom=16dp`, no horizontal padding | `addfeed.xml:79-80` |
| | margins | start `0dp`, left `0dp`, right `8dp`, end `8dp` | `addfeed.xml:75-78` |
| | hint | `@string/search_podcast_hint` → **"Search podcast…"** | `addfeed.xml:81`; `strings.xml:891` |
| | inputType / imeOptions | `text` / `actionSearch` | `addfeed.xml:72-73` |
| | importantForAutofill | `no` | `addfeed.xml:74` |
| | background | `@null` (no underline/box) | `addfeed.xml:82` |
| | trailing icons | **none** | `addfeed.xml:67-82` |
| Behaviour | `searchButton` click → `performSearch()`; `IME actionSearch` → `performSearch()`; `performSearch()` hides keyboard, clears focus, if query matches `http[s]?://.*` opens `OnlineFeedviewActivity` else loads `OnlineSearchFragment(CombinedSearcher, query)` then clears the field | | `AddFeedFragment.java:102-105, 127, 201-211` |

---

### 5. ADD FEED — the "Quick feed discovery" (suggestions) block

Inflated by `addfeed.xml:88-94` (`android:name=de.danoeh.antennapod.ui.discovery.QuickFeedDiscoveryFragment`).
Layout: `ui/discovery/src/main/res/layout/quick_feed_discovery.xml`.

| Element | id | Geometry | Ref |
|---|---|---|---|
| Root `LinearLayout` | — | `match_parent` × `wrap_content`, `vertical` | `quick_feed_discovery.xml:2-7` |
| `RelativeLayout` | — | `match_parent` × `wrap_content` | `quick_feed_discovery.xml:9-11` |
| `WrappingGridView` | `discover_grid` | `match_parent` × `wrap_content`, `numColumns=4` (XML) → overridden in code to **4** (≤600dp width) or **6** (>600dp), `scrollbars=none`, `marginTop=8dp`, `centerInParent`, `gravity=center_horizontal` | `quick_feed_discovery.xml:13-23`; `QuickFeedDiscoveryFragment.java:56-62` |
| `LinearLayout` | `errorContainer` | `match_parent` × `wrap_content`, `centerInParent`, `gravity=center`, `vertical` | `quick_feed_discovery.xml:25-31` |
| `TextView` | `errorLabel` | `match_parent` × `wrap_content`, `gravity=center`, `margin=16dp`, `textSize=@dimen/text_size_small` = **14sp** | `quick_feed_discovery.xml:33-41`; `ui/common/src/main/res/values/dimens.xml:5` |
| `Button` | `errorRetryButton` | `wrap_content` × `wrap_content`, `margin=16dp`, text `@string/retry_label` = **"Retry"** (runtime swaps to `@string/discover_confirm` = **"Show suggestions"**) | `quick_feed_discovery.xml:43-49`; `QuickFeedDiscoveryFragment.java:97, 118`; `strings.xml:144, 903` |
| `LinearLayout` (footer) | — | `match_parent` × `wrap_content`, `gravity=center_vertical`, `horizontal` | `quick_feed_discovery.xml:55-59` |
| `TextView` | `poweredByLabel` | `0dp` × `wrap_content`, `weight=1`, `text=@string/discover_powered_by_itunes` = **"Suggestions by Apple Podcasts"**, `paddingHorizontal=4dp`, `style=@style/TextAppearance.Material3.BodySmall` | `quick_feed_discovery.xml:61-68`; `strings.xml:902` |
| `Button` | `discover_more` | `wrap_content` × `wrap_content`, `minHeight=48dp`, `minWidth=0dp`, text `@string/discover_more` = **"Discover more »"**, `style=@style/Widget.MaterialComponents.Button.TextButton` | `quick_feed_discovery.xml:70-77`; `strings.xml:901` |
| Grid item | `discovery_cover` | `quick_feed_discovery_item.xml`: root `LinearLayout` `match_parent`×`match_parent`, `padding=4dp`, `clipToPadding=false`; `SquareImageView` `match_parent`×`match_parent`, `elevation=4dp`, `outlineProvider=background`, `foreground=?android:attr/selectableItemBackground`, `direction=width` (⇒ square = cell width); Glide corner radius = `8 * density` | `quick_feed_discovery_item.xml:2-19`; `FeedDiscoverAdapter.java:53, 69-76` |
| Click | `discover_grid` item click → `OnlineFeedviewActivity` for `podcast.feedUrl` (no-op when empty); `discover_more` → `MainActivity` with `DiscoveryFragment.TAG` | | `QuickFeedDiscoveryFragment.java:48-50, 152-159` |
| Dummy placeholders | `NUM_SUGGESTIONS = 12` dummy `PodcastSearchResult` inserted before load to keep height stable | | `QuickFeedDiscoveryFragment.java:38, 66-71` |
| States | hidden → `errorLabel="You selected to hide suggestions."`, grid `GONE`, retry `GONE`, poweredBy `GONE`; free-flavor confirm → `errorLabel=""`, grid `VISIBLE`, retry `VISIBLE` text "Show suggestions"; empty result → `errorLabel=@string/search_status_no_results` (**"No results were found"**), grid `INVISIBLE`; error → `errorLabel=error.getLocalizedMessage()`, grid `INVISIBLE`, retry `VISIBLE` text "Retry" | | `QuickFeedDiscoveryFragment.java:104-149`; `strings.xml:900, 647` |

---

### 6. ADD FEED — FULL "Add podcast" row list

**Exactly 6 rows exist** (`addfeed.xml:96-148`). All six use `style="@style/AddPodcastTextView"` and `android:layout_width="match_parent"`, `android:layout_height="wrap_content"`.

#### 6.1 Shared row style `AddPodcastTextView`

`ui/common/src/main/res/values/styles.xml:330-341`, parent `@style/TextAppearance.Material3.BodyMedium` (⇒ 14sp, letter-spacing 0.25sp, regular).

| Token | Value | Ref |
|---|---|---|
| `android:drawablePadding` | `8dp` | `styles.xml:331` |
| `android:paddingTop` / `paddingBottom` | `8dp` / `8dp` | `styles.xml:332-333` |
| `android:paddingStart` / `paddingEnd` | `16dp` / `16dp` | `styles.xml:334-335` |
| `android:minHeight` | `48dp` | `styles.xml:339` |
| `android:gravity` | `center_vertical` | `styles.xml:340` |
| `android:background` | `?android:attr/selectableItemBackground` | `styles.xml:336` |
| `android:textColor` | `?android:attr/textColorPrimary` (`@color/black` light / `@color/white` dark) | `styles.xml:337`; `styles.xml:56, 115` |
| `android:clickable` | `true` | `styles.xml:338` |
| Divider between rows | **none** — no `View`, no `divider` attr; rows are separated only by their own `selectableItemBackground` ripple | `addfeed.xml:96-148` |
| View class | plain `TextView` (no `?attr/selectableItemBackgroundBorderless`, no `CardView`, no `RecyclerView` adapter) | `addfeed.xml:96-148` |
| Icon geometry | 24×24dp vector via `app:drawableStartCompat` (and duplicated `app:drawableLeftCompat` for RTL-less API parity) | `addfeed.xml:101-102` etc.; e.g. `ui/common/src/main/res/drawable/ic_feed.xml:1-3` |

#### 6.2 Row table (in document order)

| # | id | Label (English literal) | String ref | Icon drawable | Click target | Ref |
|---|---|---|---|---|---|---|
| 1 | `@+id/addViaUrlButton` | **"Add podcast by RSS address"** | `@string/add_podcast_by_url` | `@drawable/ic_feed` | `MaterialAlertDialogBuilder` "Add podcast by RSS address" with an outlined `TextInputLayout` (`@layout/edit_text_dialog`); on Confirm validates `Patterns.WEB_URL` → `OnlineFeedviewActivityStarter(url).withManualUrl()` | `addfeed.xml:96-103`; `strings.xml:895`; `AddFeedFragment.java:107-108, 147-199` |
| 2 | `@+id/addLocalFolderButton` | **"Add local folder"** | `@string/add_local_folder` | `@drawable/ic_folder` | `ActivityResultContracts.OpenDocumentTree` (+ read/write/persistable flags) → `FeedDatabaseWriter.updateFeed` of a `PREFIX_LOCAL_FOLDER` feed, then `FeedItemlistFragment`; on failure posts `@string/unable_to_start_system_file_manager` | `addfeed.xml:105-112`; `strings.xml:908, 914`; `AddFeedFragment.java:119-126, 222-267` |
| 3 | `@+id/searchItunesButton` | **"Search Apple Podcasts"** | `@string/search_itunes_label` | `@drawable/ic_search` | `activity.loadChildFragment(OnlineSearchFragment.newInstance(ItunesPodcastSearcher.class))` | `addfeed.xml:114-121`; `strings.xml:892`; `AddFeedFragment.java:95-96` |
| 4 | `@+id/searchFyydButton` | **"Search fyyd"** | `@string/search_fyyd_label` | `@drawable/ic_search` | `OnlineSearchFragment.newInstance(FyydPodcastSearcher.class)` | `addfeed.xml:123-130`; `strings.xml:894`; `AddFeedFragment.java:97-98` |
| 5 | `@+id/searchPodcastIndexButton` | **"Search Podcast Index"** | `@string/search_podcastindex_label` | `@drawable/ic_search` | `OnlineSearchFragment.newInstance(PodcastIndexPodcastSearcher.class)` | `addfeed.xml:132-139`; `strings.xml:893`; `AddFeedFragment.java:99-100` |
| 6 | `@+id/opmlImportButton` | **"Import podcast list (OPML)"** | `@string/opml_add_podcast_label` | `@drawable/ic_download` | `GetContent` launcher with `"*/*"` → `OpmlImportActivity` with the picked URI; on `ActivityNotFoundException` posts `@string/unable_to_start_system_file_manager` | `addfeed.xml:141-148`; `strings.xml:675, 914`; `AddFeedFragment.java:110-117, 213-220` |

Drawable geometry (all four are 24dp vectors, `fillColor="?attr/action_icon_color"`):
`ic_search.xml:1-4`, `ic_feed.xml:1-3`, `ic_folder.xml:1-3`, `ic_download.xml:1-5` (all in `ui/common/src/main/res/drawable/`).

#### 6.3 Add-by-URL dialog (`ui/common/src/main/res/layout/edit_text_dialog.xml`)

| Element | Value | Ref |
|---|---|---|
| Root `LinearLayout` | `match_parent`/`match_parent`, `vertical`, `padding=16dp` | `edit_text_dialog.xml:2-7` |
| `TextInputLayout` `@+id/textInputLayout` | `match_parent`×`wrap_content`, `marginBottom=8dp`, `style=@style/Widget.MaterialComponents.TextInputLayout.OutlinedBox` | `edit_text_dialog.xml:9-14` |
| `TextInputEditText` `@+id/textInput` | `match_parent`×`wrap_content`, hint `@string/rss_address` = **"RSS address"**, inputType `TEXT\|MULTI_LINE\|VARIATION_URI`, error `@string/rss_address_invalid` = **"The RSS address you entered is not valid."** | `edit_text_dialog.xml:16-19`; `strings.xml:896-897`; `AddFeedFragment.java:151-153, 189` |
| Dialog buttons | positive `@string/confirm_label` = **"Confirm"**, negative `@string/cancel_label` = **"Cancel"** | `strings.xml:122-123`; `AddFeedFragment.java:181-182` |
| Clipboard prefill | If primary clip text trimmed starts with `"http"` it is pre-filled into the field | `AddFeedFragment.java:172-179` |

---

### 7. ADD FEED — empty / loading states

| State | Exists? | Detail | Ref |
|---|---|---|---|
| Screen-level empty state | **No** | `addfeed.xml` has no empty view, no `EmptyViewHandler` | `addfeed.xml:1-154` |
| Screen-level loading state | **No** | no `ProgressBar` in `addfeed.xml`; the only placeholder mechanism is the 12 dummy discovery cells | `addfeed.xml:1-154`; `QuickFeedDiscoveryFragment.java:66-71` |
| Discovery error state | Yes | `errorContainer` + `errorLabel` (14sp, `margin=16dp`) + `errorRetryButton` (`margin=16dp`) + `poweredByLabel` (`TextAppearance.Material3.BodySmall`, `paddingHorizontal=4dp`) | `quick_feed_discovery.xml:25-79` |
| Discovery state matrix | hidden / confirm / empty / error as enumerated in §5 | | `QuickFeedDiscoveryFragment.java:94-149` |

---

### 8. SEARCH — Toolbar + menu

`app/src/main/res/layout/search_fragment.xml:8-25`, menu `app/src/main/res/menu/search.xml`.

| Property | Value | Ref |
|---|---|---|
| AppBar | `@+id/appbar`, `match_parent`×`wrap_content`, `fitsSystemWindows=true`, `elevation=0dp` | `search_fragment.xml:8-13` |
| Toolbar | `@+id/toolbar`, `match_parent`×`wrap_content`, `minHeight=?attr/actionBarSize`, `android:theme=@style/ThemeOverlay.Material3.ActionBar` | `search_fragment.xml:15-20` |
| Title | XML `app:title="@string/search_label"` = **"Search"**; also re-set in code `toolbar.setTitle(R.string.search_label)` | `search_fragment.xml:21`; `SearchFragment.java:246`; `strings.xml:649` |
| Navigation icon | `app:navigationIcon="?homeAsUpIndicator"`; click → `getParentFragmentManager().popBackStack()` | `search_fragment.xml:23`; `SearchFragment.java:247` |
| Navigation contentDescription | `@string/toolbar_back_button_content_description` = **"Back"** | `search_fragment.xml:22`; `strings.xml:808` |
| Menu inflate | `toolbar.inflateMenu(R.menu.search)` | `SearchFragment.java:248` |

Menu items (`res/menu/search.xml`) — **exactly 1 item**:

| Order | id | icon | title | showAsAction | actionViewClass |
|---|---|---|---|---|---|
| 1 | `@+id/action_search` | `@drawable/ic_search` (24×24dp vector) | `@string/search_label` = **"Search"** | `collapseActionView\|always` | `de.danoeh.antennapod.ui.common.CollapsibleSearchView` |

Refs: `app/src/main/res/menu/search.xml:5-10`; `ui/common/src/main/res/drawable/ic_search.xml:1-4`; `strings.xml:649`.

Runtime: item is force-expanded (`item.expandActionView()`), query hint = `@string/search_label` = **"Search"** (`searchView.setQueryHint(...)`, *not* `search_podcast_hint`), pre-filled from `ARG_QUERY`, `requestFocus()`, keyboard shown on focus; collapsing the item pops the back stack (`SearchFragment.java:250-291`).
Debounce: `SEARCH_DEBOUNCE_INTERVAL = 1500` ms; searches instantly on empty/space-ending input or after a pause, otherwise re-searches after `1500/2 = 750` ms (`SearchFragment.java:73, 265-278`).

`CollapsibleSearchView` is an `androidx.appcompat.widget.SearchView` whose `onActionViewExpanded()` sets `layout_width = MATCH_PARENT` and `setIconifiedByDefault(false)` — its internal search/close icons are AppCompat library resources (`abc_ic_search_api_material` / `abc_ic_clear_material`), **not defined in this repo** (`ui/common/src/main/java/de/danoeh/antennapod/ui/common/CollapsibleSearchView.java:14-36`; no `searchViewStyle` override anywhere in `antenna-repo`).

---

### 9. SEARCH — top-level content structure (`search_fragment.xml`)

Root: `RelativeLayout`, `match_parent`/`match_parent`, no padding (`search_fragment.xml:2-6`).

| # | Element | id | width × height | Rules / padding / margin | Visibility | Ref |
|---|---|---|---|---|---|---|
| 1 | `AppBarLayout` | `appbar` | `match_parent` × `wrap_content` | `fitsSystemWindows=true`, `elevation=0dp` | visible | `search_fragment.xml:8-13` |
| 2 | `MaterialToolbar` | `toolbar` | `match_parent` × `wrap_content` | `minHeight=?attr/actionBarSize` | visible | `search_fragment.xml:15-23` |
| 3 | `com.google.android.material.chip.ChipGroup` | `filter_chips` | `wrap_content` × `wrap_content` | `layout_below=@id/appbar`, `marginLeft=10dp`, `marginRight=0dp` | `gone` by default; set `VISIBLE` when `getChildCount()>0` | `search_fragment.xml:27-34`; `SearchFragment.java:400` |
| 4 | `ProgressBar` | `progressBar` | `wrap_content` × `wrap_content` | `centerInParent`, `layout_gravity=center`, `style=?android:attr/progressBarStyle` (indeterminate) | `gone` → `VISIBLE` on submit | `search_fragment.xml:36-43`; `SearchFragment.java:373-374, 455, 464` |
| 5 | `RecyclerView` (horizontal subscription strip) | `recyclerViewFeeds` | `match_parent` × `wrap_content` | `layout_below=@id/filter_chips`, `paddingLeft=12dp`, `paddingRight=12dp`, `clipToPadding=false`, `LinearLayoutManager(HORIZONTAL)` | always present | `search_fragment.xml:45-52`; `SearchFragment.java:177-180` |
| 6 | `de.danoeh.antennapod.ui.episodeslist.EpisodeItemListRecyclerView` | `recyclerView` | `match_parent` × `match_parent` | `layout_below=@id/recyclerViewFeeds`, `marginTop=-4dp`, `paddingTop=12dp`, `paddingHorizontal=@dimen/additional_horizontal_spacing` (`0dp`; `56dp` ≥1000dp) | visible / `INVISIBLE` when empty | `search_fragment.xml:54-61`; `EmptyViewHandler.java:170-171` |
| 7 | `de.danoeh.antennapod.ui.view.FloatingSelectMenu` | `floatingSelectMenu` | `match_parent` × `wrap_content` | `layout_alignParentBottom=true` | `gone` (set in ctor) → `VISIBLE` in multi-select | `search_fragment.xml:63-67`; `FloatingSelectMenu.java:44`; `SearchFragment.java:489` |
| — | AppBar lift | `LiftOnScrollListener(layout.findViewById(R.id.appbar))` on `recyclerView` | | | | `SearchFragment.java:175` |

Chip geometry: `item_tag_chip.xml` → `com.google.android.material.chip.Chip` `@+id/tag_chip`, `wrap_content`×`wrap_content`, `elevation=0dp`, `checkable=true`, `longClickable=true`, `style=@style/Widget.Material3.Chip.Filter`; chips are non-checkable, close-icon visible, click on close removes the filter (`item_tag_chip.xml:2-10`; `SearchFragment.java:403-410`).
Chip labels used: `@string/queue_label` = **"Queue"**, `@string/archive_feed_label_noun` = **"Archive"**, or the feed title (`SearchFragment.java:383, 389, 395`; `strings.xml:21, 208`).

---

### 10. SEARCH — search input geometry

The Search screen has **no in-layout `EditText`**: the input is the expanded toolbar `actionView` (`CollapsibleSearchView`).

| Property | Value | Ref |
|---|---|---|
| View | `CollapsibleSearchView extends androidx.appcompat.widget.SearchView` | `CollapsibleSearchView.java:14` |
| Width | `MATCH_PARENT` after expand | `CollapsibleSearchView.java:28-36` |
| Height | toolbar height (`?attr/actionBarSize`, Material3 default 56dp) | `search_fragment.xml:19` |
| Hint text | `getString(R.string.search_label)` → **"Search"** | `SearchFragment.java:253`; `strings.xml:649` |
| Leading icon | AppCompat internal search icon (library resource, not in repo) | `CollapsibleSearchView.java:14-36` |
| Trailing clear icon | AppCompat internal close icon (library resource, not in repo); no voice icon | same |
| Focus / keyboard | `requestFocus()` at setup; keyboard shown on focus gain; hidden on list drag | `SearchFragment.java:210-223, 255` |
| Keyboard hide on submit | `searchView.clearFocus()` then `searchWithProgressBar()` | `SearchFragment.java:258-261` |

---

### 11. SEARCH — result list item layouts

Two independent lists:

#### 11.1 Horizontal subscription strip (`recyclerViewFeeds`)

Adapter `HorizontalFeedListAdapter` inflates **`app/src/main/res/layout/horizontal_feed_item.xml`** (`app/src/main/java/de/danoeh/antennapod/ui/screen/subscriptions/HorizontalFeedListAdapter.java:53`) — *not* `horizontal_itemlist_item.xml` (see §15).

| Element | id | Geometry | Ref |
|---|---|---|---|
| Root `LinearLayout` | — | `match_parent` × `96dp`, `padding=4dp`, `clipToPadding=false`, `clipToOutline=false`, `clipChildren=false` | `horizontal_feed_item.xml:2-11` |
| `CardView` | `cardView` | `wrap_content`×`wrap_content`, `cardBackgroundColor=@color/non_square_icon_background` (`#22777777`), `cardCornerRadius=16dp`, `cardPreventCornerOverlap=false`, `cardElevation=2dp` | `horizontal_feed_item.xml:13-20`; `ui/common/src/main/res/values/colors.xml:18` |
| `SquareImageView` | `discovery_cover` | `match_parent` × `96dp`, `elevation=4dp`, `outlineProvider=bounds`, `foreground=?android:attr/selectableItemBackground`, `background=?android:attr/colorBackground`, `direction=height` (⇒ 96×96dp); adapter re-sets `DIRECTION_HEIGHT` on bind | `horizontal_feed_item.xml:22-30`; `HorizontalFeedListAdapter.java:142-143` |
| `Button` (end button) | `actionButton` | `wrap_content`×`wrap_content`, `visibility=gone`, `style=@style/Widget.Material3.Button.OutlinedButton`; shown as last item with text `@string/search_online` = **"Search online"** | `horizontal_feed_item.xml:34-39`; `SearchFragment.java:439-440`; `strings.xml:651` |
| Dummy/placeholder cells | — | `itemView.setAlpha(0.1f)` + `imageView.setImageResource(@color/medium_gray)` for positions beyond data; Glide placeholder `@color/light_gray` | `HorizontalFeedListAdapter.java:68-93` |
| Divider | **none** | | `horizontal_feed_item.xml:1-41` |
| Click | cover click → `FeedItemlistFragment` (child fragment); long-press → context menu `@menu/nav_feed_context` | `HorizontalFeedListAdapter.java:78, 80-85, 119-127` |
| Visibility rule | empty list when searching within a feed or with episode filters | `SearchFragment.java:447-449` |

#### 11.2 Episode results list (`recyclerView`)

`EpisodeItemListAdapter` → `EpisodeItemViewHolder` → **`app/src/main/res/layout/feeditemlist_item.xml`** (`app/src/main/java/de/danoeh/antennapod/ui/episodeslist/EpisodeItemViewHolder.java:67`). View type is always `@id/view_type_episode_item` (`EpisodeItemListAdapter.java:59-61`; `app/src/main/res/values/ids.xml:16`).

| Element | id | Geometry / style | Ref |
|---|---|---|---|
| Root `FrameLayout` | — | `match_parent` × `wrap_content` | `feeditemlist_item.xml:2-8` |
| `LinearLayout` | `container` | `match_parent`×`wrap_content`, `horizontal`, `gravity=center_vertical`, `paddingStart=12dp`, `paddingEnd=0dp`, `background=@drawable/bg_episode_list_item` | `feeditemlist_item.xml:14-25` |
| `LinearLayout` | `left_padding` | `wrap_content`×`match_parent`, `minWidth=4dp` | `feeditemlist_item.xml:27-31` |
| `ImageView` | `drag_handle` | `16dp`×`match_parent`, `paddingEnd=4dp`, `srcCompat=?attr/dragview_background`; **forced `GONE`** in this adapter | `feeditemlist_item.xml:33-41`; `EpisodeItemListAdapter.java:81` |
| `CardView` (cover) | `coverHolder` | `56dp`×`56dp` (`@dimen/thumbnail_length_queue_item`), `marginTop=11dp`, `marginBottom=11dp` (`@dimen/listitem_threeline_verticalpadding`), `marginEnd=16dp` (`@dimen/listitem_threeline_textleftpadding`), `cardBackgroundColor=@color/non_square_icon_background` (`#22777777`), `cardCornerRadius=8dp`, `cardElevation=0dp`, `cardPreventCornerOverlap=false` | `feeditemlist_item.xml:45-55`; `ui/common/src/main/res/values/dimens.xml:9, 14, 16` |
| Placeholder `TextView` | `txtvPlaceholder` | `56dp`×`56dp`, `background=@color/light_gray` (`#bfbfbf`), `maxLines=3`, `padding=2dp`, `gravity=center`, `ellipsize=end`; text = feed title | `feeditemlist_item.xml:61-70`; `colors.xml:7`; `EpisodeItemViewHolder.java:95` |
| Cover `ImageView` | `imgvCover` | `56dp`×`56dp`, `centerVertical` | `feeditemlist_item.xml:72-78` |
| Text column | — | `0dp`×`wrap_content`, `weight=1`, `marginTop/Bottom=11dp`, `marginEnd=8dp` (`@dimen/listitem_threeline_textrightpadding`) | `feeditemlist_item.xml:84-91`; `dimens.xml:15` |
| Status row | `status` | `match_parent`×`wrap_content`, `horizontal`, `gravity=center_vertical` | `feeditemlist_item.xml:93-98` |
| Status icons | `statusInbox`, `ivIsVideo`, `isFavorite`, `ivInPlaylist` | each `12sp` × `12sp`, `app:tint=?attr/colorOnSurfaceVariant`; drawables `@drawable/ic_inbox`, `@drawable/ic_videocam`, `@drawable/ic_star`, `@drawable/ic_playlist_play`; contentDescriptions `"In the inbox"`, `"Video"`, `"Marked as favorite"`, `"In the queue"` | `feeditemlist_item.xml:100-130`; `strings.xml:817, 813, 816, 815` |
| Separator dot | `separatorIcons` | `wrap_content`, `marginStart/End=4dp`, text `"·"`, `style=@style/AntennaPod.TextView.FeedListItemSecondaryTitle`; hidden when no status icons | `feeditemlist_item.xml:132-140`; `EpisodeItemViewHolder.java:263-270` |
| Date | `txtvPubDate` | `wrap_content`, `marginEnd=4dp`, `FeedListItemSecondaryTitle`; text = `DateFormatter.formatAbbrev` | `feeditemlist_item.xml:142-148`; `EpisodeItemViewHolder.java:102` |
| Dot / size | (anon) / `size` | `wrap_content`, `marginEnd=4dp`, `FeedListItemSecondaryTitle`; size text = `Formatter.formatShortFileSize` | `feeditemlist_item.xml:150-164`; `EpisodeItemViewHolder.java:176-193` |
| Title | `txtvTitle` | `wrap_content`×`wrap_content`, `ellipsize=end`, `textAlignment=viewStart`, `style=@style/AntennaPod.TextView.FeedListItemPrimaryTitle` → parent `TextAppearance.Material3.BodyLarge` (**16sp**), `maxLines=2`, `ellipsize=end`, `lineHeight=20sp`; `importantForAccessibility=no` | `feeditemlist_item.xml:173-181`; `ui/common/src/main/res/values/styles.xml:290-295` |
| Progress row | `progress` | `match_parent`×`wrap_content`, `horizontal`, `gravity=center_vertical` | `feeditemlist_item.xml:183-188` |
| Position | `txtvPosition` | `wrap_content`, `FeedListItemSecondaryTitle`, `marginBottom=0dp`; visible only when playing/in progress | `feeditemlist_item.xml:190-196`; `EpisodeItemViewHolder.java:157-174` |
| Progress bar | `progressBar` | `0dp`×`wrap_content`, `weight=1`, `max=100`, `margin=4dp`, `app:trackStopIndicatorSize=0dp` | `feeditemlist_item.xml:198-205` |
| Duration | `txtvDuration` | `wrap_content`, `FeedListItemSecondaryTitle`, `marginBottom=0dp` | `feeditemlist_item.xml:207-213` |
| Right-side action | `secondaryActionButton` (`include @layout/secondary_action`) | `48dp`×`48dp`, `marginRight=12dp`, `marginEnd=12dp`, `background=?selectableItemBackgroundBorderless`, `clickable=true`, `focusable=false` | `feeditemlist_item.xml:219-221`; `app/src/main/res/layout/secondary_action.xml:2-14` |
| — action icon | `secondaryActionIcon` | `24dp`×`24dp`, `layout_gravity=center`; drawable set by `ItemActionButton.forItem(item).configure(...)` (play / pause / download / …) | `secondary_action.xml:16-22`; `EpisodeItemViewHolder.java:109-110` |
| — circular progress | `secondaryActionProgress` | `40dp`×`40dp`, `layout_gravity=center`, `app:foregroundColor=?attr/action_icon_color` | `secondary_action.xml:24-29` |
| Row background / divider | — | **no divider view**. `@drawable/bg_episode_list_item`: `inset` left `4dp`, right `4dp`, top `2dp`, bottom `2dp`; `ripple` color `?attr/colorControlHighlight`; mask rectangle `corners radius=12dp`; activated/selected fill `?attr/colorSecondaryContainer`; default `@android:color/transparent` | `app/src/main/res/drawable/bg_episode_list_item.xml:2-31` |
| Played state | `container.setAlpha(0.5f)` when played, else `1.0f` | | `EpisodeItemViewHolder.java:107` |
| Click | item → `ItemPagerFragment.newInstance(episodes, item)` (or `toggleSelection` in action mode); long-press → context menu `@menu/feeditemlist_context` (+ `@id/multi_select`) | | `EpisodeItemListAdapter.java:88-110, 197-216`; `SearchFragment.java:155-172` |
| RecyclerView chrome | `EpisodeItemListRecyclerView` wraps context in `@style/FastScrollRecyclerView` (`scrollbars=none`, `fastScrollEnabled=true`, `?attr/scrollbar_thumb` + `@drawable/scrollbar_track`), `LinearLayoutManager`, `setHasFixedSize(true)`, `setClipToPadding(false)` | | `EpisodeItemListRecyclerView.java:18-38`; `ui/common/src/main/res/values/styles.xml:312-319` |

#### 11.3 Multi-select overlay (`FloatingSelectMenu`)

| Element | Value | Ref |
|---|---|---|
| Root `FrameLayout` | `match_parent` × `@dimen/floating_select_menu_height` = **112dp** | `floating_select_menu.xml:2-6`; `app/src/main/res/values/dimens.xml:6` |
| `CardView` `@+id/card` | `match_parent`×`match_parent`, `marginHorizontal=16dp`, `marginBottom=16dp`, `cardCornerRadius=8dp`, background = `SurfaceColors.getColorForElevation(ctx, 8 * density)` | `floating_select_menu.xml:8-14`; `FloatingSelectMenu.java:41-42` |
| `HorizontalScrollView` `@+id/scrollView` | `paddingHorizontal=8dp`, `clipToPadding=true`, `requiresFadingEdge=horizontal`, `fadingEdgeLength=48dp` | `floating_select_menu.xml:16-23` |
| Item root | `wrap_content`×`match_parent`, `paddingHorizontal=4dp`, `paddingTop=12dp`, `paddingBottom=8dp`, `background=?attr/selectableItemBackgroundBorderless` | `floating_select_menu_item.xml:2-10` |
| Item icon `@+id/icon` | `28dp`×`28dp`, `center_horizontal` | `floating_select_menu_item.xml:12-17` |
| Item label `@id/titleLabel` | `maxWidth=96dp`, `minWidth=72dp`, `marginTop=8dp`, `maxLines=2`, `textAlignment=center`, `ellipsize=end`, `hyphenationFrequency=full`, `style=@style/TextAppearance.Material3.BodySmall` | `floating_select_menu_item.xml:19-31` |
| Show/hide | `VISIBLE` on select-mode start (alpha 0 → 1 over 100 ms), `GONE` on end; list bottom padding set to `@dimen/floating_select_menu_height` while open | `FloatingSelectMenu.java:82-97`; `SearchFragment.java:487-501` |
| Menu inflated | `@menu/episodes_apply_action_speeddial`; empty selection → toast `@string/no_items_selected_message` = **"No items selected"** | `SearchFragment.java:224-234`; `strings.xml:314` |

---

### 12. SEARCH — empty / loading / no-result states

Empty view = `ui/common/src/main/res/layout/empty_view_layout.xml`, inflated by `EmptyViewHandler` and inserted into the **first** ancestor that is a `RelativeLayout` (here: the `search_fragment.xml` root) with `RelativeLayout.CENTER_IN_PARENT` (`EmptyViewHandler.java:97-124`).

| Element | id | Geometry / style | Ref |
|---|---|---|---|
| Root `LinearLayout` | — | `match_parent`×`match_parent`, `vertical`, `gravity=center`, `paddingLeft=40dp`, `paddingRight=40dp` | `empty_view_layout.xml:2-11` |
| Icon `ImageView` | `emptyViewIcon` | `32dp`×`32dp`, `visibility=gone` → `VISIBLE` when set | `empty_view_layout.xml:13-19`; `EmptyViewHandler.java:67-70` |
| Title `TextView` | `emptyViewTitle` | `wrap_content`, `textSize=16sp`, `textAlignment=center`, `textColor=?android:attr/textColorPrimary` | `empty_view_layout.xml:21-28` |
| Message `TextView` | `emptyViewMessage` | `wrap_content`, `textSize=14sp`, `textAlignment=center`; **never set on the Search screen** (stays empty) | `empty_view_layout.xml:30-36` |
| Button | `button` | `wrap_content`, `marginTop=16dp`, `visibility=gone`, `style=@style/Widget.Material3.Button.OutlinedButton`; not used by SearchFragment | `empty_view_layout.xml:38-46` |

State matrix:

| State | Trigger | Empty view | RecyclerView | ProgressBar | Ref |
|---|---|---|---|---|---|
| Idle / no query | query empty | title `@string/type_to_search` = **"Type a query to search"**, icon `@drawable/ic_search` (32dp) | `INVISIBLE` when adapter empty | `GONE` | `SearchFragment.java:199-202, 443-446`; `strings.xml:648` |
| Loading | `onQueryTextSubmit` / chip removal | `emptyViewHandler.hide()` | — | `VISIBLE` | `SearchFragment.java:373-377` |
| Results | query non-empty, results returned | hidden (adapter non-empty) | `VISIBLE` | `GONE` (set on each successful emission) | `EmptyViewHandler.java:161-172`; `SearchFragment.java:455, 464` |
| No results | query non-empty, 0 results | title `@string/no_results_for_query` = **`No results were found for "%1$s"`** (with the raw query; feeds list uses the plain `query`, episodes list uses `searchView.getQuery()`) | `INVISIBLE` | `GONE` | `SearchFragment.java:457, 467`; `strings.xml:650` |

---

### 13. ONLINE SEARCH screen (opened from Add Feed rows 3–5 and from the "Search online" button)

Layout `ui/discovery/src/main/res/layout/fragment_online_search.xml`; list item `ui/discovery/src/main/res/layout/online_search_listitem.xml`; menu `ui/discovery/src/main/res/menu/online_search.xml`.

| Element | id | Value | Ref |
|---|---|---|---|
| Root | — | `RelativeLayout`, `match_parent`/`match_parent` | `fragment_online_search.xml:2-7` |
| AppBar | `appbar` | `match_parent`×`wrap_content`, `alignParentTop=true`, `fitsSystemWindows=true`, `elevation=0dp` | `fragment_online_search.xml:9-15` |
| Toolbar | `toolbar` | `minHeight=?attr/actionBarSize`, `theme=@style/ThemeOverlay.Material3.ActionBar`, `app:title="@string/discover"` = **"Discover"**, nav icon `?homeAsUpIndicator`, content desc **"Back"** | `fragment_online_search.xml:17-25`; `strings.xml:898, 808` |
| Toolbar menu | `@menu/online_search` | 1 item `@+id/action_search`, icon `@drawable/ic_search`, title `@string/search_label` = **"Search"**, `showAsAction=collapseActionView\|ifRoom`, `actionViewClass=CollapsibleSearchView`; expanded in code; query hint = `@string/search_podcast_hint` = **"Search podcast…"** | `ui/discovery/src/main/res/menu/online_search.xml:5-10`; `OnlineSearchFragment.java:134-170`; `strings.xml:891` |
| `GridView` | `gridView` | `match_parent`×`match_parent`, `layout_below=@id/appbar`, `clipToPadding=false`, `columnWidth=400dp`, `numColumns=auto_fit`, `stretchMode=columnWidth`, `gravity=center`, `horizontalSpacing=8dp`, `verticalSpacing=8dp`, `paddingTop=@dimen/list_vertical_padding` (**8dp**), `paddingBottom=8dp` | `fragment_online_search.xml:29-43`; `ui/common/src/main/res/values/dimens.xml:18` |
| Empty | `@android:id/empty` | `match_parent`×`match_parent`, `centerInParent`, `gravity=center`, `visibility=gone`, text `@string/search_status_no_results` = **"No results were found"** (replaced at runtime by `@string/no_results_for_query`) | `fragment_online_search.xml:45-52`; `OnlineSearchFragment.java:189-190`; `strings.xml:647, 650` |
| Progress | `progressBar` | `wrap_content`×`wrap_content`, `centerInParent`, `indeterminateOnly=true`, `visibility=gone` → `VISIBLE` | `fragment_online_search.xml:54-60`; `OnlineSearchFragment.java:184, 201-207` |
| Error | `txtvError` | `wrap_content`×`wrap_content`, `centerInParent`, `margin=16dp`, `textAlignment=center`, `textSize=@dimen/text_size_small` (**14sp**), `visibility=gone`; text = `error.toString()` | `fragment_online_search.xml:62-73`; `OnlineSearchFragment.java:194-195` |
| Retry | `butRetry` | `wrap_content`×`wrap_content`, `layout_below=@id/txtvError`, `centerHorizontal`, `margin=16dp`, text `@string/retry_label` = **"Retry"**, `visibility=gone` | `fragment_online_search.xml:75-85`; `strings.xml:144` |
| Powered-by | `search_powered_by` | `wrap_content`×`wrap_content`, `alignParentBottom/Right/End`, `textColor=?android:attr/textColorTertiary`, `textSize=12sp`, `padding=4dp`, `background=?android:attr/colorBackground`, text = `@string/search_powered_by` = **`Results by %1$s`** (searcher class name) | `fragment_online_search.xml:87-99`; `OnlineSearchFragment.java:106`; `strings.xml:904` |
| List item root | — | `RelativeLayout`, `match_parent`×`wrap_content`, `paddingTop=8dp`, `paddingLeft=16dp`, `paddingRight=16dp`, `paddingBottom=8dp` | `online_search_listitem.xml:2-11` |
| Cover | `imgvCover` | `@dimen/thumbnail_length_itemlist` = **56dp** × 56dp, `alignParentLeft/Start/Top`, `adjustViewBounds=true`, `cropToPadding=true`, `scaleType=fitXY`; Glide `RoundedCorners(4 * density)` + placeholder `@color/light_gray`, `diskCacheStrategy=NONE` | `online_search_listitem.xml:13-25`; `ui/common/src/main/res/values/dimens.xml:8`; `OnlineSearchAdapter.java:80-89` |
| Text column | — | `match_parent`×`wrap_content`, `toRightOf/toEndOf=@id/imgvCover`, `centerVertical`, `vertical`, `marginLeft/Start=16dp` | `online_search_listitem.xml:27-35` |
| Title | `txtvTitle` | `match_parent`×`wrap_content`, `style=@style/AntennaPod.TextView.ListItemPrimaryTitle` → parent `TextAppearance.Material3.BodyLarge` (**16sp**), `textColor=?attr/colorOnSurface`, `maxLines=2`, `ellipsize=end`, `lineHeight=20sp` | `online_search_listitem.xml:37-43`; `ui/common/src/main/res/values/styles.xml:282-288` |
| Author / URL | `txtvAuthor` | `match_parent`×`wrap_content`, `textSize=14sp`, `textColor=?android:attr/textColorSecondary`, `ellipsize=middle`, `maxLines=2`, `style=android:style/TextAppearance.Small`; hidden when author empty and URL contains `itunes.apple.com` | `online_search_listitem.xml:45-55`; `OnlineSearchAdapter.java:70-78` |
| Divider | **none** | | `online_search_listitem.xml:1-59` |
| Click | item → `OnlineFeedviewActivity` for `podcast.feedUrl` | | `OnlineSearchFragment.java:97-100` |

---

### 14. Color / attr token resolution

All values from `ui/common/src/main/res/values/colors.xml` and `ui/common/src/main/res/values/styles.xml`.

| Token | Light | Dark | Ref |
|---|---|---|---|
| `?attr/colorSurfaceContainer` (AddFeed search card bg, appbar lift target) | `#EBEEF3` | `#1C2024` | `styles.xml:53, 112` |
| `?attr/colorSurfaceContainerHigh` | `@color/color_surface_variant_light` = `#D3DCE0` | `@color/color_surface_variant_dark` = `#2F3B4F` | `styles.xml:61, 120`; `colors.xml:23-24` |
| `?attr/colorSurfaceContainerHighest` | `#C0CFD3` | `#38455C` | `styles.xml:62, 121` |
| `?attr/colorSurfaceContainerLow` / `Lowest` | `#D3DCE0` | `#2F3B4F` | `styles.xml:63-64, 122-123` |
| `?attr/colorSurfaceVariant` | `#D3DCE0` | `#2F3B4F` | `styles.xml:51, 110` |
| `?attr/colorSecondaryContainer` (row selected fill) | `#C8D8DE` | `#3C4E68` | `styles.xml:54, 113`; `colors.xml:25-26`; `bg_episode_list_item.xml:18, 24` |
| `?attr/colorOnSurface` | `@color/black` `#000000` | `@color/white` `#FFFFFF` | `styles.xml:49, 108`; `colors.xml:4, 9` |
| `?attr/colorOnSurfaceVariant` | `@color/text_color_secondary_light` `#444444` | `@color/text_color_secondary_dark` `#cccccc` | `styles.xml:52, 111`; `colors.xml:21-22` |
| `?android:attr/textColorPrimary` | `#000000` | `#FFFFFF` | `styles.xml:56, 115` |
| `?android:attr/textColorSecondary` | `#444444` | `#cccccc` | `styles.xml:57, 116` |
| `?android:attr/textColorTertiary` | `#444444` | `#cccccc` | `styles.xml:58, 117` |
| `?android:attr/colorBackground` / `?attr/colorSurface` | `@color/background_light` `#f9fcff` | `@color/background_darktheme` `#21272b` (TrueBlack: `#000000`) | `styles.xml:47-48, 106-107, 129-132`; `colors.xml:14, 16, 9` |
| `?attr/action_icon_color` (all add-feed row icons, secondary action progress) | `@color/black` | `@color/white` | `styles.xml:19, 75`; `ic_search.xml:4` etc. |
| `?attr/colorControlHighlight` (row ripple) | theme default (not overridden in repo) | — | `bg_episode_list_item.xml:7` |
| `?attr/colorOnPrimary` (horizontal item circular progress) | `@color/white` | `@color/black` | `styles.xml:40, 99`; `horizontal_itemlist_item.xml:67` (not used by Search) |
| `@color/non_square_icon_background` (cover card bg) | `#22777777` (single value, both themes) | `#22777777` | `colors.xml:18` |
| `@color/light_gray` (placeholder / Glide placeholder) | `#bfbfbf` | `#bfbfbf` | `colors.xml:7` |
| `@color/medium_gray` (dummy cells) | `#afafaf` | `#afafaf` | `colors.xml:8` |
| `@color/image_readability_tint` | `#80000000` | `#80000000` | `colors.xml:10` |
| `@color/button_bg_selector` | defined in `ui/common/src/main/res/color/` (used by `OutlinedButtonBetterContrast`, not by these two screens) | — | `styles.xml:308-310` |
| `?attr/homeAsUpIndicator` | AppCompat theme attribute → `abc_ic_ab_back_material` (24dp). Not declared in this repo; `MainActivity` may replace it with the drawer toggle | `addfeed.xml:22`; `search_fragment.xml:23`; `MainActivity.java:345-351` |
| `?attr/actionBarSize` | Material3 default `56dp`; not declared in this repo | `addfeed.xml:19`; `search_fragment.xml:19` |
| `?android:attr/progressBarStyle` | framework default indeterminate circular; not overridden | `search_fragment.xml:43` |

---

### 15. Non-existent / explicit negatives

| Item asked about | Finding |
|---|---|
| Add Feed toolbar menu items (share, sync, OPML export, gpodder) | **Do not exist.** `addfeed.xml` has no menu and `AddFeedFragment` never calls `inflateMenu()`. OPML **export**, gpodder.net **sync**, and "share" live in Settings (`ui:preferences`) — e.g. `@string/opml_export_label` (`strings.xml:680`), `@string/dialog_choose_sync_service_title` (`strings.xml:749`), `@string/synchronization_sync_changes_title` (`strings.xml:775`). |
| Add Feed "Add by folder / OPML export" row | **Does not exist.** The only folder-related row is `@+id/addLocalFolderButton` → "Add local folder" (`addfeed.xml:105-112`). |
| Add Feed "Discover / Trends" row | **Does not exist as a text row.** Discovery is the embedded `QuickFeedDiscoveryFragment` grid plus its "Discover more »" button (`addfeed.xml:88-94`; `quick_feed_discovery.xml:70-77`). The full `DiscoveryFragment` screen is a separate destination reached from that button (`QuickFeedDiscoveryFragment.java:48-50`). |
| Add Feed "Share" row | **Does not exist.** |
| Trailing clear / voice icon in the Add Feed search card | **Does not exist.** Only the leading `@+id/searchButton` ImageView (`addfeed.xml:56-65`). |
| `horizontal_itemlist_item.xml` used by the Search screen | **No.** `horizontal_itemlist_item.xml` (128dp cover, `cardCornerRadius=12dp`, `cardBackgroundColor=?attr/colorSurfaceContainer`) is inflated by `HorizontalItemViewHolder` (`app/src/main/java/de/danoeh/antennapod/ui/episodeslist/HorizontalItemViewHolder.java:40`) for horizontal *episode* strips; the Search screen's horizontal strip uses `horizontal_feed_item.xml` (`HorizontalFeedListAdapter.java:53`). |
| Divider views in the Search result lists | **Do not exist.** Separation comes from `bg_episode_list_item.xml` insets (`4dp`/`2dp`) + `12dp` corner radius (`bg_episode_list_item.xml:2-31`). |
| `TextInputLayout` in the Add Feed search card | **Does not exist** (plain `EditText`, `background=@null`) — `addfeed.xml:67-82`. |
| Search screen in-layout search field | **Does not exist**; input is the toolbar action view (`CollapsibleSearchView`) — `search_fragment.xml` has no `EditText`. |
| Message text under the Search empty-state title | **Not set**; `emptyViewMessage` stays empty (`SearchFragment` only calls `setTitle`/`setIcon`) — `SearchFragment.java:199-202, 444, 457, 467`. |
| Explicit heights for the Add Feed search card / EditText | **Not declared**; both are `wrap_content` (`addfeed.xml:41, 70`). |

---

### 16. String literal index (exact English)

| String name | Literal | Ref |
|---|---|---|
| `add_feed_label` | `Add podcast` | `strings.xml:15` |
| `add_feed_label_short` | `Add` | `strings.xml:16` |
| `search_podcast_hint` | `Search podcast…` (U+2026 ellipsis) | `strings.xml:891` |
| `search_itunes_label` | `Search Apple Podcasts` | `strings.xml:892` |
| `search_podcastindex_label` | `Search Podcast Index` | `strings.xml:893` |
| `search_fyyd_label` | `Search fyyd` | `strings.xml:894` |
| `add_podcast_by_url` | `Add podcast by RSS address` | `strings.xml:895` |
| `rss_address` | `RSS address` | `strings.xml:896` |
| `rss_address_invalid` | `The RSS address you entered is not valid.` | `strings.xml:897` |
| `discover` | `Discover` | `strings.xml:898` |
| `discover_hide` | `Hide` | `strings.xml:899` |
| `discover_is_hidden` | `You selected to hide suggestions.` | `strings.xml:900` |
| `discover_more` | `Discover more »` | `strings.xml:901` |
| `discover_powered_by_itunes` | `Suggestions by Apple Podcasts` | `strings.xml:902` |
| `discover_confirm` | `Show suggestions` | `strings.xml:903` |
| `search_powered_by` | `Results by %1$s` | `strings.xml:904` |
| `select_country` | `Select country` | `strings.xml:905` |
| `add_local_folder` | `Add local folder` | `strings.xml:908` |
| `local_folder` | `Local folder` | `strings.xml:909` |
| `unable_to_start_system_file_manager` | `Unable to start system file manager` | `strings.xml:914` |
| `opml_add_podcast_label` | `Import podcast list (OPML)` | `strings.xml:675` |
| `search_label` | `Search` | `strings.xml:649` |
| `search_status_no_results` | `No results were found` | `strings.xml:647` |
| `type_to_search` | `Type a query to search` | `strings.xml:648` |
| `no_results_for_query` | `No results were found for "%1$s"` | `strings.xml:650` |
| `search_online` | `Search online` | `strings.xml:651` |
| `retry_label` | `Retry` | `strings.xml:144` |
| `confirm_label` | `Confirm` | `strings.xml:122` |
| `cancel_label` | `Cancel` | `strings.xml:123` |
| `toolbar_back_button_content_description` | `Back` | `strings.xml:808` |
| `queue_label` | `Queue` | `strings.xml:21` |
| `archive_feed_label_noun` | `Archive` | `strings.xml:208` |
| `no_items_selected_message` | `No items selected` | `strings.xml:314` |
| `is_inbox_label` | `In the inbox` | `strings.xml:817` |
| `media_type_video_label` | `Video` | `strings.xml:813` |
| `is_favorite_label` | `Marked as favorite` | `strings.xml:816` |
| `in_queue_label` | `In the queue` | `strings.xml:815` |
| `is_played` | `Played` | `strings.xml:818` |
| `overflow_more` | `More` | `strings.xml:466` |
| `drawer_open` / `drawer_close` | `Open menu` / `Close menu` | `strings.xml:91-92` |

---

### 17. Quick numeric summary (most-used values)

- Toolbar height `56dp` (`?attr/actionBarSize`, Material3 default); AddFeed toolbar has **0** menu items; Search toolbar has **1**.
- AddFeed page: horizontal margins `16dp`, card corner `28dp`, card elevation `0dp`, scroll padding bottom `16dp`, discovery block margins `16dp` vertical+horizontal.
- AddFeed search card: `48dp` leading icon (padding `12dp`, glyph `24dp`), `8dp` icon side margins, EditText `16dp` vertical padding, `8dp` end margin, hint `"Search podcast…"`.
- AddFeed rows: `6` rows, each `minHeight 48dp`, padding `8dp/16dp`, `drawablePadding 8dp`, `24dp` icon, `14sp` text, **no divider**.
- Discovery grid: `4` columns (≤600dp) / `6` (>600dp), item `padding 4dp`, cover `elevation 4dp`, corner radius `8 × density`, `12` dummy cells, footer button `minHeight 48dp`.
- Search screen: 2 result lists (horizontal feed strip `96dp` rows / episode list `56dp` covers + `48dp` trailing action), progress `wrap_content` centered, empty icon `32dp`, empty title `16sp`, empty message `14sp`, multi-select overlay `112dp` tall with `28dp` icons and `8dp` card radius.
- Online search (from AddFeed rows): grid `columnWidth 400dp`, `auto_fit`, `8dp` spacing, list item `56dp` cover, `16sp` title, `14sp` author, item padding `8dp/16dp`.


---

## B.3 — DOWNLOADS, PLAYBACK HISTORY, INBOX, FAVORITES, ALL EPISODES

Read-only analysis of upstream AntennaPod Android at `antenna-repo`. Every numeric claim carries `file:line`.
Paths are relative to `antenna-repo/` unless stated. `strings.xml` = `ui/i18n/src/main/res/values/strings.xml`.

Source of truth:
`app/src/main/res/layout/{episodes_list_fragment,simple_list_fragment,feeditemlist_item,download_log_fragment,downloadlog_item,download_log_details_dialog,secondary_action,floating_select_menu,floating_select_menu_item}.xml`,
`ui/common/src/main/res/layout/empty_view_layout.xml`,
`app/src/main/res/menu/{episodes,favorites,inbox,playback_history,downloads_completed,download_log,episodes_apply_action_speeddial,feeditemlist_context}.xml`,
`app/.../ui/episodeslist/{EpisodesListFragment,EpisodeItemListAdapter,EpisodeItemViewHolder,EpisodeItemListRecyclerView}.java`,
`app/.../ui/screen/{AllEpisodesFragment,FavoritesFragment,InboxFragment,PlaybackHistoryFragment}.java`,
`app/.../ui/screen/download/*.java`, `app/.../ui/view/FloatingSelectMenu.java`,
`ui/common/src/main/java/de/danoeh/antennapod/ui/common/{EmptyViewHandler,CircularProgressBar}.java`,
`app/src/main/res/values/{dimens,integers}.xml`, `app/src/main/res/values-sw600dp/integers.xml`, `app/src/main/res/values-w1000dp/dimens.xml`,
`ui/common/src/main/res/values/{dimens,styles,colors,attrs,integers}.xml`.

---

### 0. Shared host + token inventory (read this before the per-screen sections)

#### 0.1 Screen → fragment → layout → menu

| Screen (nav label) | Fragment | Root layout | Menu | Toolbar title literal |
|---|---|---|---|---|
| Downloads | `CompletedDownloadsFragment` | `simple_list_fragment.xml` | `menu/downloads_completed.xml` | **"Downloads"** (`strings.xml:28`) |
| Download log (modal bottom sheet) | `DownloadLogFragment` (`BottomSheetDialogFragment`) | `download_log_fragment.xml` | `menu/download_log.xml` | **"Download log"** (`strings.xml:30`) |
| Playback history | `PlaybackHistoryFragment` | `episodes_list_fragment.xml` | `menu/playback_history.xml` | **"Playback history"** (`strings.xml:35`) |
| Inbox | `InboxFragment` | `episodes_list_fragment.xml` | `menu/inbox.xml` | **"Inbox"** (`strings.xml:23`) |
| Favorites | `FavoritesFragment` | `episodes_list_fragment.xml` | `menu/favorites.xml` | **"Favorites"** (`strings.xml:25`) |
| All episodes ("Episodes") | `AllEpisodesFragment` | `episodes_list_fragment.xml` | `menu/episodes.xml` | **"Episodes"** (`strings.xml:17`) |

Titles are set at runtime, not in XML: `CompletedDownloadsFragment.java:90`, `InboxFragment.java:47`,
`FavoritesFragment.java:30`, `PlaybackHistoryFragment.java:37`, `AllEpisodesFragment.java:41`,
`download_log_fragment.xml:15` (`app:title="@string/downloads_log_label"`).
Shared base class of the last four: `EpisodesListFragment` (`EpisodesListFragment.java:61-62`);
`AllEpisodesFragment`, `FavoritesFragment`, `InboxFragment`, `PlaybackHistoryFragment` all `extends EpisodesListFragment`
(`AllEpisodesFragment.java:31`, `FavoritesFragment.java:19`, `InboxFragment.java:35`, `PlaybackHistoryFragment.java:26`).
`CompletedDownloadsFragment` does **not** extend it — it re-implements the same wiring (`CompletedDownloadsFragment.java:66-138`).

#### 0.2 Toolbar + navigation icon (all four `episodes_list_fragment` screens + Downloads)

| Property | Value | Ref |
|---|---|---|
| Host | `AppBarLayout @+id/appbar`, match_parent × wrap_content, `android:fitsSystemWindows="true"` | `episodes_list_fragment.xml:9-13`, `simple_list_fragment.xml:8-12` |
| Toolbar | `MaterialToolbar @+id/toolbar`, match_parent × **`?attr/actionBarSize`** (M3 default 56dp; not overridden in repo — `grep actionBarSize` finds only uses, no `<dimen>`/`<item>` definition) | `episodes_list_fragment.xml:15-20`, `simple_list_fragment.xml:14-19` |
| XML navigation icon | `app:navigationIcon="?homeAsUpIndicator"` | `episodes_list_fragment.xml:20`, `simple_list_fragment.xml:19` |
| XML nav contentDescription | `@string/toolbar_back_button_content_description` = **"Back"** | `episodes_list_fragment.xml:19`, `strings.xml:808` |
| Runtime override | `MainActivity.setupToolbarToggle(toolbar, displayUpArrow)` — drawer (hamburger) when a `DrawerLayout` exists and `displayUpArrow==false`; `null` icon on tablet when `!displayUpArrow`; else `?attr/homeAsUpIndicator` + `popBackStack()` | `EpisodesListFragment.java:159`, `CompletedDownloadsFragment.java:102`, `MainActivity.java:336-353` |
| `displayUpArrow` source | `getParentFragmentManager().getBackStackEntryCount() != 0` | `EpisodesListFragment.java:155`, `CompletedDownloadsFragment.java:98` |
| Toolbar long-press | scroll to position 5 then smooth-scroll to 0 | `EpisodesListFragment.java:150-154`, `CompletedDownloadsFragment.java:93-97` |
| Toolbar elevation | 0dp (`Widget.AntennaPod.ActionBar`, `elevation=0dp`, `background=?android:attr/colorBackground`) | `ui/common/.../styles.xml:325-328` |
| Toolbar menu inflation | `toolbar.inflateMenu(R.menu.…)` — exactly one menu per screen, no base menu merge | `InboxFragment.java:46`, `FavoritesFragment.java:29`, `AllEpisodesFragment.java:40`, `PlaybackHistoryFragment.java:36`, `CompletedDownloadsFragment.java:91`, `DownloadLogFragment.java:62` |

Download-log sheet toolbar differs: `match_parent × wrap_content`, `android:minHeight="?attr/actionBarSize"` (**≥56dp**), `layout_alignParentTop="true"`, **no navigation icon declared and none set at runtime** (`download_log_fragment.xml:9-15`).

#### 0.3 Material 3 library defaults referenced below (NOT defined in this repo)

These values come from the Material3 AAR (no `<style>` override exists in the repo — only
`ui/common/src/main/res/values/styles.xml` and `values-v27/styles.xml` define styles, and neither
redeclares `TextAppearance.Material3.*`). Treat as library defaults:

| Style | textSize | lineHeight |
|---|---|---|
| `TextAppearance.Material3.BodyLarge` | 16sp | 24sp (overridden to **20sp** by AntennaPod styles) |
| `TextAppearance.Material3.BodyMedium` | 14sp | 20sp |
| `TextAppearance.Material3.BodySmall` | 12sp | 16sp |
| `TextAppearance.Material3.LabelSmall` | 11sp | 16sp |
| `TextAppearance.Material3.TitleMedium` | 16sp | 24sp (medium weight) |
| `TextAppearance.Material3.TitleSmall` | 14sp | 20sp |
| `?attr/actionBarSize` | 56dp | — |
| `?dialogPreferredPadding` | 24dp | — |
| `Widget.Material3.LinearProgressIndicator` default thickness | 4dp | — |

#### 0.4 Spacing dimens used by these screens

| dimen | value | declared | used by |
|---|---|---|---|
| `additional_horizontal_spacing` | **0dp** (default) | `app/src/main/res/values/dimens.xml:3` | recyclerView horizontal padding (`episodes_list_fragment.xml:46`, `simple_list_fragment.xml:33`) |
| `additional_horizontal_spacing` | **56dp** @ `w1000dp` | `app/src/main/res/values-w1000dp/dimens.xml:3` | same (large screens) |
| `additional_horizontal_spacing` | **0dp** @ `w300dp` | `app/src/main/res/values-w300dp/dimens.xml:3` | same (small screens) |
| `floating_select_menu_height` | **112dp** | `app/src/main/res/values/dimens.xml:6` | multi-select bottom bar + recyclerView bottom padding (`EpisodesListFragment.java:317`, `CompletedDownloadsFragment.java:351`) |
| `list_vertical_padding` | **8dp** | `ui/common/src/main/res/values/dimens.xml:18` | download-log `ListView` `paddingVertical` (`download_log_fragment.xml:21`) |
| `listitem_threeline_verticalpadding` | **11dp** | `ui/common/src/main/res/values/dimens.xml:16` | item top/bottom margins (`feeditemlist_item.xml:49,50,87,89`, `downloadlog_item.xml:16,19`) |
| `listitem_threeline_textleftpadding` | **16dp** | `ui/common/src/main/res/values/dimens.xml:14` | cover → text gap (`feeditemlist_item.xml:51`) |
| `listitem_threeline_textrightpadding` | **8dp** | `ui/common/src/main/res/values/dimens.xml:15` | text column right margin (`feeditemlist_item.xml:88`, `downloadlog_item.xml:17-18`) |
| `thumbnail_length_queue_item` | **56dp** | `ui/common/src/main/res/values/dimens.xml:9` | episode-list cover (`feeditemlist_item.xml:47-48,63-64,74-75`) |
| `thumbnail_length_navlist` | **40dp** | `ui/common/src/main/res/values/dimens.xml:10` | drawer icon (`nav_listitem.xml:14-15`) |
| `thumbnail_length_itemlist` | 56dp | `ui/common/src/main/res/values/dimens.xml:8` | **not** used by these 5 screens (only `ui/discovery/.../online_search_listitem.xml:15-16`) |
| `text_size_small` | 14sp | `ui/common/src/main/res/values/dimens.xml:5` | podcast-author line in feed header only |
| `text_size_navdrawer` | 16sp | `ui/common/src/main/res/values/dimens.xml:6` | drawer item title (`nav_listitem.xml:46`) |

`swipe_refresh_distance` = **300** (`app/src/main/res/values/integers.xml:5`), applied to every screen's `SwipeRefreshLayout`
(`EpisodesListFragment.java:174`, `CompletedDownloadsFragment.java:105`).
`fragment_transition_duration` = **300** (`ui/common/src/main/res/values/integers.xml:2`).
`nav_drawer_screen_size_percent` = **80** (`app/src/main/res/values/integers.xml:4`).

#### 0.5 Text styles used by these screens (`ui/common/src/main/res/values/styles.xml`)

| Style | Parent | size | color | other |
|---|---|---|---|---|
| `AntennaPod.TextView.ListItemPrimaryTitle` | `TextAppearance.Material3.BodyLarge` | 16sp (M3) | `?attr/colorOnSurface` | maxLines **2**, ellipsize end, `lineHeight` **20sp** | `:282-288` |
| `AntennaPod.TextView.FeedListItemPrimaryTitle` | `TextAppearance.Material3.BodyLarge` | 16sp (M3) | inherited | maxLines **2**, ellipsize end, `lineHeight` **20sp** | `:290-295` |
| `AntennaPod.TextView.ListItemSecondaryTitle` | `TextAppearance.Material3.BodyMedium` | 14sp (M3) | `?attr/colorOnSurfaceVariant` | lines **1**, ellipsize end | `:297-301` |
| `AntennaPod.TextView.FeedListItemSecondaryTitle` | `TextAppearance.Material3.LabelSmall` | 11sp (M3) | inherited (`?android:attr/textColorPrimary`) | lines **1**, ellipsize end | `:303-306` |
| `AntennaPod.TextView.Heading` | `@android:style/TextAppearance.Medium` | `text_size_large` = **22sp** | `?android:attr/textColorPrimary` | `sans-serif-light` | `:276-280` |
| `Widget.AntennaPod.LinearProgressIndicator` | `Widget.Material3.LinearProgressIndicator` | — | — | `trackColor` = **#55888888** | `:321-323` |
| `FastScrollRecyclerView` | `android:Widget` | — | — | `scrollbars=none`, `fastScrollEnabled=true`, thumb `?attr/scrollbar_thumb`, track `@drawable/scrollbar_track` | `:312-319` |

`linearProgressIndicatorStyle` is bound to `@style/Widget.AntennaPod.LinearProgressIndicator` in both light and dark base themes
(`ui/common/.../styles.xml:13`, `:72`).

---

### A. DOWNLOADS (downloaded-episodes list, `CompletedDownloadsFragment`)

#### A.1 Toolbar + menu

Title `downloads_label` = **"Downloads"** (`CompletedDownloadsFragment.java:90`, `strings.xml:28`).
Navigation icon: see §0.2. Menu: `R.menu.downloads_completed` (`CompletedDownloadsFragment.java:91`).

| # | id | icon | icon size | title literal | showAsAction | note |
|---|---|---|---|---|---|---|
| 1 | `action_search` | `@drawable/ic_search` | 24dp | **"Search"** (`strings.xml:649`) | `always` | → `SearchFragment` (`CompletedDownloadsFragment.java:179-181`) |
| 2 | `action_download_logs` | `@drawable/ic_history` | 24dp | **"Download log"** (`strings.xml:30`) | `always` | opens `DownloadLogFragment` sheet (`:176-178`) |
| 3 | `action_delete_downloads_played` | — | — | **"Delete played"** (`strings.xml:243`) | `never` | confirmation dialog (`:185-202`) |
| 4 | `refresh_item` | — | — | **"Refresh"** (`strings.xml:136`) | `never`, `menuCategory="container"` | feed update (`:173-175`) |
| 5 | `downloads_sort` | — | — | **"Sort"** (`strings.xml:407`) | *(absent → never)* | `DownloadsSortDialog` (`:182-184`) |

Refs: `menu/downloads_completed.xml:7-31`.

#### A.2 Content structure

| Element | Geometry | Ref |
|---|---|---|
| Root | `RelativeLayout`, match_parent × match_parent | `simple_list_fragment.xml:2-6` |
| `AppBarLayout @+id/appbar` | match_parent × wrap_content, `fitsSystemWindows=true` | `:8-12` |
| `SwipeRefreshLayout @+id/swipeRefresh` | match_parent × match_parent, `layout_below="@id/appbar"`; `distanceToTriggerSync` = **300** | `:23-27`, `CompletedDownloadsFragment.java:105` |
| `EpisodeItemListRecyclerView @+id/recyclerView` | match_parent × match_parent, `android:paddingHorizontal="@dimen/additional_horizontal_spacing"` (**0dp**, 56dp @w1000dp) | `:29-33` |
| Layout manager | `LinearLayoutManager` — **single column, no grid**; `setHasFixedSize(true)`, `setClipToPadding(false)` | `EpisodeItemListRecyclerView.java:33-38` |
| Dividers | **none** (no `addItemDecoration` on any of the 5 screens) | `grep addItemDecoration` → only Chapters/Subscriptions/dialogs |
| `ProgressBar @+id/progLoading` | wrap_content × wrap_content, `centerInParent`, `indeterminateOnly=true`, `visibility=gone`; set **VISIBLE** on create, **GONE** after load | `:37-43`, `CompletedDownloadsFragment.java:116-117,336` |
| `FloatingSelectMenu @+id/floatingSelectMenu` | match_parent × wrap_content, `alignParentBottom` | `:45-49` |
| Empty state | `ic_download` / **"No downloaded episodes"** / **"You can download episodes on the podcast details screen."** | `CompletedDownloadsFragment.java:242-248`, `strings.xml:431-432` |
| List item | `feeditemlist_item.xml` → see §G |
| Extra long-press behaviour | toolbar long-press scrolls to pos 5 → 0 | `:93-97` |
| `list_vertical_padding` | **not applied** on this screen (recyclerView has no vertical padding) | `simple_list_fragment.xml:29-33` |

Sort order source: `UserPreferences.getDownloadsSortedOrder()`; sortable keys limited to `DATE_OLD_NEW`, `DURATION_SHORT_LONG`,
`EPISODE_TITLE_A_Z`, `SIZE_SMALL_LARGE` (`CompletedDownloadsFragment.java:312,404-409`).

#### A.3 Per-row secondary action override

When `!inActionMode()` and the item `isDownloaded()` and `!UserPreferences.shouldDownloadsButtonActionPlay()`, the 48dp
right-hand button is replaced by `DeleteActionButton` (`ic_delete`, label "Delete") — `CompletedDownloadsFragment.java:368-377`,
`DeleteActionButton.java:25,31,46-52`.

---

### B. DOWNLOAD LOG (modal bottom sheet, `DownloadLogFragment`)

#### B.1 Host + toolbar + menu

| Property | Value | Ref |
|---|---|---|
| Fragment type | `BottomSheetDialogFragment` (`public class DownloadLogFragment extends BottomSheetDialogFragment`) | `DownloadLogFragment.java:34-35` |
| Sheet theme | library default (`Theme.Material3.*` `bottomSheetDialogTheme`); **no** override anywhere in the repo (`grep bottomSheetDialogTheme` → 0 hits) |
| Root | `RelativeLayout`, match_parent × match_parent, `android:minHeight="300dp"` | `download_log_fragment.xml:2-7` |
| Toolbar | `MaterialToolbar @+id/toolbar`, match_parent × wrap_content, `minHeight="?attr/actionBarSize"` (≥56dp), `layout_alignParentTop`, `app:title="@string/downloads_log_label"` = **"Download log"** | `:9-15` |
| Navigation icon | **none** (not declared, not set at runtime) | `:9-15` |
| Menu | `toolbar.inflateMenu(R.menu.download_log)` | `DownloadLogFragment.java:62` |

| # | id | icon | icon size | title literal | showAsAction | menuCategory | action |
|---|---|---|---|---|---|---|---|
| 1 | `clear_logs_item` | `@drawable/ic_delete` | 24dp | **"Clear history"** (`strings.xml:116`) | `always` | `container` | `DBWriter.clearDownloadLog()` (`DownloadLogFragment.java:102-104`) |

Ref: `menu/download_log.xml:6-11`. This is the **only** menu item — no search, no refresh, no sort.

#### B.2 Content structure

| Element | Geometry | Ref |
|---|---|---|
| `ListView @+id/list` | match_parent × wrap_content, `android:paddingVertical="@dimen/list_vertical_padding"` = **8dp**, `layout_below="@id/toolbar"`; `setNestedScrollingEnabled(true)` | `download_log_fragment.xml:17-22`, `DownloadLogFragment.java:74` |
| Adapter | `DownloadLogAdapter extends BaseAdapter` (ListView, not RecyclerView) | `DownloadLogAdapter.java:26,43-53` |
| Section/group headers | **none** — flat list of `DownloadResult`, newest first from `DBReader.getDownloadLog()` | `DownloadLogFragment.java:113-119` |
| `ProgressBar @+id/progLoading` | wrap_content × wrap_content, `centerInParent`, `indeterminateOnly=true`, `visibility=gone` — **never referenced in Java; stays gone forever (dead view)** | `download_log_fragment.xml:24-30`; `grep progLoading` in `app/.../java` → no `DownloadLogFragment` hit |
| Empty state | `ic_download` / **"No download log"** (`strings.xml:433`) / **"Download logs will appear here when available."** (`strings.xml:434`); attached with `attachToListView(list)` | `DownloadLogFragment.java:65-69` |
| Row click | opens `DownloadLogDetailsDialog.newInstance(item, true)` on the **parent** fragment manager | `DownloadLogFragment.java:87-93` |
| Live refresh | `@Subscribe onDownloadLogChanged(DownloadLogEvent)` → `loadDownloadLog()` | `DownloadLogFragment.java:95-98` |

#### B.3 `downloadlog_item.xml` — full row spec

Root `LinearLayout @+id/container`: match_parent × wrap_content, `orientation=horizontal`, `gravity=center_vertical`,
`baselineAligned=false`, `descendantFocusability="blocksDescendants"` (`:2-11`). **No cover/thumbnail on this row.**

| # | Element | Geometry | Text / color | Ref |
|---|---|---|---|---|
| 1 | inner text column (unnamed `LinearLayout`) | `0dp × wrap_content`, `layout_weight=1`, `layout_marginLeft/Start=16dp`, `layout_marginTop/Bottom=@dimen/listitem_threeline_verticalpadding` = **11dp**, `layout_marginRight/End=@dimen/listitem_threeline_textrightpadding` = **8dp**, vertical | — | `:13-23` |
| 2 | `ImageView @+id/icon` | **16dp × 16dp**, `marginEnd=4dp`, `gravity=center`, `importantForAccessibility=no` | runtime: `ic_check` (success), `ic_info` (duplicate), `ic_error` (other failures); contentDescription = "successful" / "Error" | `:31-37`, `DownloadLogAdapter.java:73-85`, `strings.xml:318,134` |
| 3 | `TextView @+id/txtvTitle` | match_parent × wrap_content, **`maxLines=1`**, `ellipsize=end`, `style=AntennaPod.TextView.ListItemPrimaryTitle` (16sp BodyLarge, `lineHeight` 20sp, color `?attr/colorOnSurface`; style's own `maxLines=2` is overridden by the inline `maxLines=1`) | text = `status.getTitle()` else **"Unknown title"** (`strings.xml:359`); `setHyphenationFrequency(HYPHENATION_FREQUENCY_FULL)` | `:39-47`, `DownloadLogAdapter.java:67-71`, `DownloadLogItemViewHolder.java:34` |
| 4 | `TextView @+id/status` | wrap_content × wrap_content, `style=AntennaPod.TextView.ListItemSecondaryTitle` (14sp BodyMedium, color `?attr/colorOnSurfaceVariant`, lines 1, ellipsize end) | `"<Feed|Media file> · <relative time>"` — `download_type_feed` = **"Feed"** (`strings.xml:360`) / `download_type_media` = **"Media file"** (`strings.xml:361`), separator literal `" · "`, time via `DateUtils.getRelativeTimeSpanString(..., MINUTE_IN_MILLIS, 0)` | `:51-56`, `DownloadLogAdapter.java:56-65` |
| 5 | `TextView @+id/txtvReason` | match_parent × wrap_content, **`textSize=14sp`**, `textColor=?attr/icon_red` (**#CF1800**) | `DownloadErrorLabel.from(reason)`; `GONE` on success, `VISIBLE` on failure | `:58-64`, `DownloadLogAdapter.java:77,86-88` |
| 6 | `TextView @+id/txtvTapForDetails` | match_parent × wrap_content, **`textSize=14sp`**, `textColor=?android:attr/textColorSecondary` (#444444 light / #cccccc dark), static text **"Tap to view details."** (`strings.xml:329`) | `GONE` on success, `VISIBLE` on failure | `:66-72`, `DownloadLogAdapter.java:78,88` |
| 7 | `<include layout="@layout/secondary_action"/>` (no `android:id`, so root id `secondaryActionButton` is kept) | `FrameLayout` **48dp × 48dp**, `marginEnd=12dp`, `background=?selectableItemBackgroundBorderless` | icon `ImageView` **24dp × 24dp** centered; `CircularProgressBar @+id/secondaryActionProgress` **40dp × 40dp** centered, `foregroundColor=?attr/action_icon_color` | `:76-77`, `secondary_action.xml:2-31` |

Row height (derived, no explicit `minHeight`): success ≈ title 20sp + status 20sp + 22dp margins; failure ≈ +20sp (reason) +20sp (tap hint). **Failure rows are the tallest state.**

Secondary-action behaviour (`DownloadLogAdapter.java:73-122`):
- success → `secondaryActionButton` `INVISIBLE`, `reason`/`tapForDetails` `GONE` (`:76-78`)
- failure + a **newer** successful entry for the same `feedfileType`/`feedfileId` → `INVISIBLE`, listener nulled (`:90-93`, `:125-133`)
- failure otherwise → icon `@drawable/ic_refresh`, `VISIBLE`; feed row → `FeedUpdateManager.runOnce`, media row → `DownloadActionButton` + toast **"Episode is being downloaded"** (`strings.xml:814`) (`:95-120`)

Icon drawables (all 24dp vectors, viewport 24×24):
- `ic_check` — fill `?attr/action_icon_color` (`ui/common/.../drawable/ic_check.xml:3`)
- `ic_info` — fill `?attr/action_icon_color` (`ic_info.xml:4`)
- `ic_error` — **two paths**: outer circle `?android:attr/colorBackground`, inner glyph `?attr/icon_red` (`ic_error.xml:6-11`)
- `ic_refresh` — fill `?attr/action_icon_color` (`ic_refresh.xml:4`)

#### B.4 `download_log_details_dialog.xml` — field rows

Dialog chrome (`DownloadLogDetailsDialog.java:63-71`): `MaterialAlertDialogBuilder`
title = **"Details"** (`download_error_details`, `strings.xml:321`),
positive = `android.R.string.ok` = **"OK"**,
neutral = **"Copy to clipboard"** (`copy_to_clipboard`, `strings.xml:585`) → copies the composed multi-line text (`:153-154`).

| Element | Geometry | Text | Ref |
|---|---|---|---|
| `ScrollView` root | match_parent × wrap_content, `android:padding="?dialogPreferredPadding"` (M3 default **24dp**; not overridden in repo) | — | `:2-8` |
| `@+id/podcastContainer` | match_parent × wrap_content, horizontal | left column `0dp` weight 1: label `@string/feed` = **"Podcast"** (`strings.xml:413`) `style=TextAppearance.Material3.TitleMedium` (16sp) + `@+id/podcastNameLabel` (`singleLine`, `ellipsize=end`); right: `MaterialButton @+id/goToPodcastButton`, `minWidth=0dp`, `marginStart=8dp`, text **"Open"** (`download_log_open_feed`, `strings.xml:326`), `Widget.Material3.Button.TextButton` | `:16-54` |
| `@+id/episodeContainer` | match_parent × wrap_content, vertical, `layout_marginTop=8dp` | label `@string/episode` = **"Episode"** (`strings.xml:411`) TitleMedium + `@+id/episodeNameLabel` (`singleLine`, `ellipsize=middle`) | `:57-79` |
| `@+id/humanReadableReasonContainer` | `marginTop=8dp` | label **"Status"** (`download_log_details_human_readable_reason_title`, `strings.xml:323`) + `@+id/humanReadableReasonLabel` = `DownloadErrorLabel.from(...)` | `:82-102`, `.java:145-146` |
| `@+id/technicalReasonContainer` | `marginTop=8dp` | label **"Technical details"** (`strings.xml:324`) + `@+id/technicalReasonLabel`, `background=?android:attr/selectableItemBackground`, tap copies | `:105-126`, `.java:84-86` |
| `@+id/fileUrlContainer` | `marginTop=8dp` | label **"File URL"** (`strings.xml:325`) + `@+id/fileUrlLabel`, `background=?android:attr/selectableItemBackground`, tap copies; default `url = "unknown"` | `:129-150`, `.java:42,82-83` |
| Header labels | each `layout_marginEnd="4dp"`, `wrap_content × wrap_content`, `TextAppearance.Material3.TitleMedium` (16sp) | — | `:32,68,93,116,140` |
| Value labels | `wrap_content × wrap_content`, **no explicit textSize/color** → theme default text appearance (M3 body, ≈16sp) — not pinned in repo | — | `:35-41,71-77,96-100,119-124,143-148` |
| Visibility rules | `goToPodcastButton` visible only if `isJumpToFeed && feed != null`; `podcastContainer`/`episodeContainer` `GONE` when the name is `null` | — | `.java:139-143` |

`DownloadLogDetailsDialog` is also reused from the podcast screen with `isJumpToFeed=false`
(`FeedItemlistFragment.java:599`) and can be launched directly from `MainActivity.java:751`.

#### B.5 `DownloadErrorLabel` → string mapping (exact English literals)

`DownloadErrorLabel.java:14-45`; literals at `strings.xml:330-352`, `:318`, `:345`.

| DownloadError | string | literal |
|---|---|---|
| `SUCCESS` | `download_successful` | "successful" |
| `ERROR_PARSER_EXCEPTION`, `ERROR_PARSER_EXCEPTION_DUPLICATE` | `download_error_parser_exception` | "The podcast host's server sent a broken podcast feed. We recommend checking with a podcast validator such as castfeedvalidator.com and contacting the podcast creator to let them know." |
| `ERROR_UNSUPPORTED_TYPE` | `download_error_unsupported_type` | "Unsupported feed type" |
| `ERROR_UNSUPPORTED_TYPE_HTML` | `download_error_unsupported_type_html` | "The podcast host's server sent a website, not a podcast." |
| `ERROR_CONNECTION_ERROR` | `download_error_connection_error` | "Connection error" |
| `ERROR_MALFORMED_URL`, `ERROR_FILE_EXISTS`, default | `download_error_error_unknown` | "Unknown error" |
| `ERROR_IO_ERROR` | `download_error_io_error` | "IO error" |
| `ERROR_DOWNLOAD_CANCELLED` | `download_canceled_msg` | "Download canceled" |
| `ERROR_DEVICE_NOT_FOUND` | `download_error_device_not_found` | "Storage Device not found" |
| `ERROR_HTTP_DATA_ERROR` | `download_error_http_data_error` | "HTTP data error" |
| `ERROR_NOT_ENOUGH_SPACE` | `download_error_insufficient_space` | "There is not enough space left on your device." |
| `ERROR_UNKNOWN_HOST` | `download_error_unknown_host` | "Cannot find the server. Check if the address is typed correctly and if you have a working network connection." |
| `ERROR_REQUEST_ERROR` | `download_error_request_error` | "Request error" |
| `ERROR_DB_ACCESS_ERROR` | `download_error_db_access` | "Database access error" |
| `ERROR_UNAUTHORIZED` | `download_error_unauthorized` | "Authentication error. Make sure that username and password are correct." |
| `ERROR_FILE_TYPE` | `download_error_file_type_type` | "File type error" |
| `ERROR_FORBIDDEN` | `download_error_forbidden` | "The podcast host's server refuses to respond." |
| `ERROR_IO_WRONG_SIZE` | `download_error_wrong_size` | "The server connection was lost before completing the download" |
| `ERROR_IO_BLOCKED` | `download_error_blocked` | "The download was blocked by another app on your device (like a VPN or ad blocker)." |
| `ERROR_NOT_FOUND` | `download_error_not_found` | "The podcast host's server does not know where to find the file. It may have been deleted." |
| `ERROR_CERTIFICATE` | `download_error_certificate` | "Unable to establish a secure connection. This can mean that another app on your device (like a VPN or an ad blocker) blocked the download, or that something is wrong with the server certificates." |

---

### C. PLAYBACK HISTORY (`PlaybackHistoryFragment`)

| Property | Value | Ref |
|---|---|---|
| Toolbar title | **"Playback history"** (`playback_history_label`) | `PlaybackHistoryFragment.java:37`, `strings.xml:35` |
| Navigation icon | §0.2 | — |
| Menu | `R.menu.playback_history` | `PlaybackHistoryFragment.java:36` |
| Root / recyclerView / progress / empty / swipe | identical to §F.2 (`episodes_list_fragment.xml`) | `EpisodesListFragment.java:146` |
| Empty state | `@drawable/ic_history` (24dp) / **"No history"** (`no_history_head_label`) / **"After you listen to an episode, it will appear here."** (`no_history_label`) | `PlaybackHistoryFragment.java:39-41`, `strings.xml:435-436` |
| Sort | hard-coded `SortOrder.COMPLETION_DATE_NEW_OLD` (no sort dialog) | `PlaybackHistoryFragment.java:106,112-113` |
| Filter | `FeedItemFilter(IS_IN_HISTORY, INCLUDE_ALL_FEED_STATES)` | `PlaybackHistoryFragment.java:28-29` |
| Page size | `EPISODES_PER_PAGE = 150` | `EpisodesListFragment.java:65` |
| Live update | `@Subscribe onHistoryUpdated(PlaybackHistoryEvent)` → `loadItems()` + `updateToolbar()` | `PlaybackHistoryFragment.java:97-101` |

Menu `menu/playback_history.xml:4-8` — **only one item; there is no Search and no Refresh on this screen**:

| # | id | icon | icon size | title literal | showAsAction | runtime visibility |
|---|---|---|---|---|---|---|
| 1 | `clear_history_item` | `@drawable/ic_delete` | 24dp | **"Clear history"** (`strings.xml:116`) | `ifRoom` | `setVisible(!episodes.isEmpty())` → hidden on empty list | 

Ref: `PlaybackHistoryFragment.java:92-95` (`updateToolbar` deliberately does not call `super`).
Confirm dialog: title **"Clear history"**, message **"This will clear the entire playback history. Are you sure you want to proceed?"**
(`clear_playback_history_msg`, `strings.xml:117`), then `DBWriter.clearPlaybackHistory()` (`PlaybackHistoryFragment.java:71-87`).

---

### D. INBOX (`InboxFragment`)

| Property | Value | Ref |
|---|---|---|
| Toolbar title | **"Inbox"** (`inbox_label`) | `InboxFragment.java:47`, `strings.xml:23` |
| Navigation icon | §0.2 | — |
| Menu | `R.menu.inbox` | `InboxFragment.java:46` |
| Empty state | `@drawable/ic_inbox` (24dp) / **"No episodes in the inbox"** (`no_inbox_head_label`) / **"New episodes will show up here. You can then decide whether you are interested in them."** (`home_new_empty_text`) | `InboxFragment.java:50-52`, `strings.xml:442`, `:74` |
| Filter | `FeedItemFilter(NEW)` | `InboxFragment.java:57-59` |
| Sort | `UserPreferences.getInboxSortedOrder()`; dialog offers only `DATE_OLD_NEW`, `DURATION_SHORT_LONG` | `InboxFragment.java:100,146-150` |
| Scroll restore | static `Pair<Integer,Integer>` saved in `onPause`, restored in `onItemsFirstLoaded` | `InboxFragment.java:40,67-75` |

Menu `menu/inbox.xml:5-27`:

| # | id | icon | icon size | title literal | showAsAction | menuCategory | action |
|---|---|---|---|---|---|---|---|
| 1 | `action_search` | `@drawable/ic_search` | 24dp | **"Search"** | `always` | — | `SearchFragment` (`EpisodesListFragment.java:118-121`) |
| 2 | `refresh_item` | — | — | **"Refresh"** | `never` | `container` | `FeedUpdateManager.runOnceOrAsk` (`EpisodesListFragment.java:115-117`) |
| 3 | `inbox_sort` | — | — | **"Sort"** | *(absent → never)* | — | `InboxSortDialog` (`InboxFragment.java:89-92`) |
| 4 | `remove_all_inbox_item` | `@drawable/ic_check` | 24dp | **"Remove all from inbox"** (`strings.xml:198`) | **`collapseActionView`** (verbatim) | `container` | confirm → `DBWriter.removeAllNewFlags()`; toast **"Removed all from inbox"** (`strings.xml:199`) (`InboxFragment.java:82-88,115-118`) |

Remove-all dialog: title **"Remove all from inbox"**, message **"Please confirm that you want to remove all from the inbox."**
(`strings.xml:200`), custom view `checkbox_do_not_show_again.xml` (padding L/R 16dp, T/B 8dp; `CheckBox` text
**"Do not show again"**, `strings.xml:394`), buttons **"Confirm"** / **"Cancel"** (`strings.xml:122-123`) (`InboxFragment.java:120-136`).
Preference key `prefDoNotPromptRemovalAllFromInbox` in `PrefNewEpisodesFragment` (`InboxFragment.java:37-38`).

---

### E. FAVORITES (`FavoritesFragment`)

| Property | Value | Ref |
|---|---|---|
| Toolbar title | **"Favorites"** (`favorite_episodes_label`) | `FavoritesFragment.java:30`, `strings.xml:25` |
| Navigation icon | §0.2 | — |
| Menu | `R.menu.favorites` | `FavoritesFragment.java:29` |
| Empty state | `@drawable/ic_star` (24dp) / **"No favorites"** (`no_fav_episodes_head_label`) / **"Mark episodes as favorites by tapping the star icon."** (`no_fav_episodes_label`) | `FavoritesFragment.java:32-34`, `strings.xml:437-438` |
| Filter | `FeedItemFilter(IS_FAVORITE, INCLUDE_ALL_FEED_STATES)` (static) | `FavoritesFragment.java:21-22` |
| Sort | `UserPreferences.getAllEpisodesSortOrder()` (no sort dialog) | `FavoritesFragment.java:63,70` |

Menu `menu/favorites.xml:6-17` — 2 items only:

| # | id | icon | icon size | title literal | showAsAction | menuCategory |
|---|---|---|---|---|---|---|
| 1 | `action_search` | `@drawable/ic_search` | 24dp | **"Search"** | `always` | — |
| 2 | `refresh_item` | — | — | **"Refresh"** | `never` | `container` |

---

### F. ALL EPISODES (`AllEpisodesFragment`)

#### F.1 Toolbar + menu

Title **"Episodes"** (`episodes_label`, `strings.xml:17`) — `AllEpisodesFragment.java:41`. Menu `R.menu.episodes`
(`AllEpisodesFragment.java:40`), `menu/episodes.xml:6-28`:

| # | id | icon | icon size | title literal | showAsAction | menuCategory | action |
|---|---|---|---|---|---|---|---|
| 1 | `action_search` | `@drawable/ic_search` | 24dp | **"Search"** | `always` | — | `SearchFragment` |
| 2 | `refresh_item` | — | — | **"Refresh"** | `never` | `container` | feed update |
| 3 | `filter_items` | `@drawable/ic_filter` | 24dp | **"Filter"** (`strings.xml:916`) | `ifRoom` | `container` | `AllEpisodesFilterDialog` (`AllEpisodesFragment.java:104-106`) |
| 4 | `episodes_sort` | — | — | **"Sort"** | `never` | — | `AllEpisodesSortDialog` (`:107-110`) |

#### F.2 Content structure (`episodes_list_fragment.xml`, shared by C/D/E/F)

| Element | Geometry | Ref |
|---|---|---|
| Root | `RelativeLayout`, match_parent × match_parent | `:2-7` |
| `AppBarLayout @+id/appbar` | match_parent × wrap_content, `fitsSystemWindows=true` | `:9-13` |
| Toolbar | match_parent × `?attr/actionBarSize` (56dp) | `:15-20` |
| `TextView @+id/txtvInformation` ("Filtered" bar) | match_parent × wrap_content, `layout_marginTop="-16dp"`, `paddingVertical=4dp`, `paddingHorizontal=16dp` (XML), `background=?attr/selectableItemBackground`, `text=@string/filtered_label` = **"Filtered"** (`strings.xml:226`), `visibility=gone`; runtime padding **density×60dp** horizontal (when `displayUpArrow || !bottomNavigation`) else **density×16dp**, vertical **density×4dp** | `:22-32`, `AllEpisodesFragment.java:44-50`, `:122-133` |
| `SwipeRefreshLayout @+id/swipeRefresh` | match_parent × match_parent, `layout_below="@id/appbar"`, `distanceToTriggerSync` = **300** | `:36-40`, `EpisodesListFragment.java:174` |
| `EpisodeItemListRecyclerView @+id/recyclerView` | match_parent × match_parent, `paddingHorizontal=@dimen/additional_horizontal_spacing` (**0dp**; **56dp** @w1000dp) | `:42-46` |
| Layout manager | `LinearLayoutManager`, **1 column** (`setHasFixedSize(true)`, `setClipToPadding(false)`) | `EpisodeItemListRecyclerView.java:33-38` |
| RecyclerView theme | `ContextThemeWrapper(context, R.style.FastScrollRecyclerView)` (fast scroll, no scrollbars) | `EpisodeItemListRecyclerView.java:19`, `styles.xml:312-319` |
| Dividers | **none** | see §A.2 |
| `ProgressBar @+id/progressBar` | wrap_content × wrap_content, `layout_centerInParent=true`, `gravity=center`, `indeterminateOnly=true`, `visibility=gone` → **VISIBLE** in `onCreateView`, **GONE** after first load | `:50-58`, `EpisodesListFragment.java:196-197,412` |
| `FloatingSelectMenu @+id/floatingSelectMenu` | match_parent × wrap_content, `alignParentBottom` | `:60-64` |
| Empty state | `@drawable/ic_feed` / **"No episodes"** / **"When you add a podcast, the episodes will be shown here."**; filtered variant message **"Try clearing the filter to see more episodes."** (`no_all_episodes_filtered_label`, `strings.xml:441`) | `EpisodesListFragment.java:201-205`, `AllEpisodesFragment.java:124-132` |
| Skeleton/dummy rows | `listAdapter.setDummyViews(1)` appends 1 dummy row on load-more; dummy = `container` alpha **0.1f**, title `"███████"`, pubDate `"████"`, duration `"████"`, cover = `@color/medium_gray` (#afafaf) | `EpisodesListFragment.java:280`, `EpisodeItemViewHolder.java:196-223` |
| Animation | `SimpleItemAnimator.setSupportsChangeAnimations(false)` | `EpisodesListFragment.java:168-171` |
| Scroll-to-bottom trigger | `isScrolledToBottom()` = `(total - visible) <= firstVisible + 3` | `EpisodeItemListRecyclerView.java:61-66` |

Filter for All Episodes: `UserPreferences.getPrefFilterAllEpisodes()`; adds `INCLUDE_ALL_FEED_STATES` when
`filter.showIsFavorite` (`AllEpisodesFragment.java:73-81`). Sort dialog limited to `DATE_OLD_NEW`, `DURATION_SHORT_LONG`
(`:155-159`).

---

### G. SHARED EPISODE LIST ITEM (`feeditemlist_item.xml`) — used by Downloads, Playback history, Inbox, Favorites, All episodes

Inflated by `EpisodeItemViewHolder` (`EpisodeItemViewHolder.java:67`); adapter binds every row via
`EpisodeItemListAdapter` (`EpisodeItemListAdapter.java:65-67`). RecyclerView item view type is a single type
(`R.id.view_type_episode_item`, `EpisodeItemListAdapter.java:58-61`).

#### G.1 Outer geometry

| Element | Geometry | Ref |
|---|---|---|
| Root `FrameLayout` | match_parent × wrap_content (exists only so `ItemAnimator` alpha changes do not clash with the played indicator) | `:2-13` |
| `@+id/container` `LinearLayout` | match_parent × wrap_content, `orientation=horizontal`, `gravity=center_vertical`, `baselineAligned=false`, **`paddingStart=12dp`**, **`paddingEnd=0dp`**, `background=@drawable/bg_episode_list_item`, `duplicateParentState=true` | `:14-25` |
| `@+id/left_padding` `LinearLayout` | wrap_content × match_parent, **`minWidth=4dp`** | `:27-31` |
| `@+id/drag_handle` `ImageView` | **16dp** wide × match_parent, `paddingStart=0dp`, `paddingEnd=4dp`, `scaleType=fitCenter`, `srcCompat=?attr/dragview_background`; **`visibility=GONE`** in normal lists (only used in Queue) | `:33-41`, `EpisodeItemListAdapter.java:81` |
| `@+id/coverHolder` `CardView` | **56dp × 56dp** (`@dimen/thumbnail_length_queue_item`), `layout_marginTop/Bottom=@dimen/listitem_threeline_verticalpadding` = **11dp**, `layout_marginEnd=@dimen/listitem_threeline_textleftpadding` = **16dp**, **`app:cardCornerRadius="8dp"`**, `app:cardElevation="0dp"`, `app:cardBackgroundColor=@color/non_square_icon_background` (**#22777777**), `cardPreventCornerOverlap=false` | `:45-55` |
| `@+id/txtvPlaceholder` `TextView` | 56dp × 56dp, `gravity=center`, `background=@color/light_gray` (**#bfbfbf**), **`maxLines=3`**, `padding=2dp`, `ellipsize=end`; text = feed title | `:61-70`, `EpisodeItemViewHolder.java:95` |
| `@+id/imgvCover` `ImageView` | 56dp × 56dp, `layout_centerVertical=true` | `:72-78` |
| text column (`LinearLayout`) | **`0dp` × wrap_content, `layout_weight=1`**, `layout_marginTop/Bottom` = **11dp**, `layout_marginEnd=@dimen/listitem_threeline_textrightpadding` = **8dp**, vertical | `:84-91` |
| `@+id/secondaryActionButton` (`<include layout="@layout/secondary_action">`) | **48dp × 48dp**, `marginEnd=12dp`, `background=?selectableItemBackgroundBorderless`, `clickable=true`, `focusable=false`, `focusableInTouchMode=false` | `:219-221`, `secondary_action.xml:2-14` |
| **Total minimum row height** | **56 (cover) + 11 + 11 = 78dp**; independent confirmation: swipe-preview row is **76dp** (`swipeactions_row.xml:55`) containing a mock `feeditemlist_item` | derived; `feeditemlist_item.xml:47-50,87-89` |

#### G.2 Status row (`@+id/status`, lines `:93-166`) — left-to-right

| # | Element | Size | Content / color | Ref |
|---|---|---|---|---|
| 1 | `@+id/statusInbox` | **12sp × 12sp** (verbatim `sp`, not dp) | `ic_inbox`, `app:tint=?attr/colorOnSurfaceVariant`, contentDescription **"In the inbox"** (`is_inbox_label`, `strings.xml:817`) | `:100-106` |
| 2 | `@+id/ivIsVideo` | **12sp × 12sp** | `ic_videocam`, same tint, contentDescription **"Video"** (`media_type_video_label`, `strings.xml:813`) | `:108-114` |
| 3 | `@+id/isFavorite` | **12sp × 12sp** | `ic_star`, same tint, contentDescription **"Marked as favorite"** (`is_favorite_label`, `strings.xml:816`) | `:116-122` |
| 4 | `@+id/ivInPlaylist` | **12sp × 12sp** | `ic_playlist_play`, same tint, contentDescription **"In the queue"** (`in_queue_label`, `strings.xml:815`) | `:124-130` |
| 5 | `@+id/separatorIcons` | wrap × wrap, `marginStart/End=4dp` | literal `"·"`, `importantForAccessibility=no`, `style=FeedListItemSecondaryTitle` (11sp LabelSmall); hidden when no status icons are visible | `:132-140`, `EpisodeItemViewHolder.java:263-270` |
| 6 | `@+id/txtvPubDate` | wrap × wrap, `marginEnd=4dp` | `style=FeedListItemSecondaryTitle`; text = `DateFormatter.formatAbbrev(pubDate)`, contentDescription = `formatForAccessibility` | `:142-148`, `EpisodeItemViewHolder.java:102-103` |
| 7 | separator `TextView` | wrap × wrap, `marginEnd=4dp` | literal `"·"` | `:150-156` |
| 8 | `@+id/size` | wrap × wrap, `marginEnd=4dp` | `style=FeedListItemSecondaryTitle`; `Formatter.formatShortFileSize(size)` e.g. "10 MB"; empty string when size unknown | `:158-164`, `EpisodeItemViewHolder.java:176-193` |

Visibility driven by `EpisodeItemViewHolder.java:104-106`: inbox icon `item.isNew()`, favorite `item.isTagged(TAG_FAVORITE)`,
queue `item.isTagged(TAG_QUEUE)`; video icon `media.getMediaType()==VIDEO` (`:136`).

#### G.3 Title + progress row

| Element | Geometry / style | Ref |
|---|---|---|
| `@+id/txtvTitle` | wrap_content × wrap_content, `ellipsize=end`, `textAlignment=viewStart`, `importantForAccessibility=no`, `style=AntennaPod.TextView.FeedListItemPrimaryTitle` → **16sp BodyLarge, maxLines 2, lineHeight 20sp**; hyphenation `FULL` set in code | `:173-181`, `EpisodeItemViewHolder.java:74` |
| `@+id/progress` row | match_parent × wrap_content, horizontal, `gravity=center_vertical` | `:183-188` |
| `@+id/txtvPosition` | wrap × wrap, `layout_marginBottom=0dp`, `style=FeedListItemSecondaryTitle` (11sp) | `:190-196` |
| `@+id/progressBar` `LinearProgressIndicator` | **`0dp` × wrap_content, `layout_weight=1`** (M3 default thickness **4dp**), `android:max=100`, **`layout_margin=4dp`**, `app:trackStopIndicatorSize="0dp"`; style track color **#55888888** | `:198-205`, `styles.xml:321-323` |
| `@+id/txtvDuration` | wrap × wrap, `layout_marginBottom=0dp`, `style=FeedListItemSecondaryTitle` (11sp); shows total duration, or **"-<remaining>"** when `shouldShowRemainingTime()` | `:207-213`, `EpisodeItemViewHolder.java:154-170` |
| Visibility | progress bar + position shown only when playing or in progress (`progressBar.setProgress(100*pos/dur)`), else `GONE`; duration `GONE` when `duration <= 0` | `EpisodeItemViewHolder.java:157-174`, `:137` |

#### G.4 Action button (the only icon button on a row)

`secondary_action.xml` — `FrameLayout` **48dp × 48dp**, `marginEnd=12dp`, borderless ripple background.
`@+id/secondaryActionIcon` `ImageView` **24dp × 24dp** centered; `@+id/secondaryActionProgress` `CircularProgressBar`
**40dp × 40dp** centered, `foregroundColor=?attr/action_icon_color` (`:6-29`).
`CircularProgressBar` draws its arcs procedurally: padding = `height*0.08`, background stroke = `height*0.03`,
progress stroke = padding, dashes `{5,5}` when indeterminate (`CircularProgressBar.java:78-83`, `:18`).

Icon chosen by `ItemActionButton.forItem(item)` (`ItemActionButton.java:36-56`):

| State | Class | icon (24dp) | label (contentDescription) |
|---|---|---|---|
| currently playing | `PauseActionButton` | `ic_pause` (48dp intrinsic) | "Pause" (`strings.xml:253`) |
| local feed | `PlayLocalActionButton` | `ic_play_24dp` | "Play" (`:252`) |
| downloaded | `PlayActionButton` | `ic_play_24dp` | "Play" |
| downloading | `CancelDownloadActionButton` | `ic_cancel` | "Cancel download" (`:34`) |
| stream-over-download pref | `StreamActionButton` | `ic_stream` | "Stream" (`:254`) |
| default | `DownloadActionButton` | `ic_download` | "Download" (`:247`) |
| no media | `MarkAsPlayedActionButton` | `ic_check` | (mark played) |
| Downloads screen override | `DeleteActionButton` | `ic_delete` | "Delete" (`:255`) |

There is **no** favorite / queue / "more" button on a row — those are the 12sp status glyphs in §G.2 plus the long-press
context menu `menu/feeditemlist_context.xml` (12 items: `skip_episode_item`, `remove_inbox_item`, `mark_read_item`,
`mark_unread_item`, `add_to_queue_item`, `remove_from_queue_item`, `remove_item`, `add_to_favorites_item`,
`remove_from_favorites_item`, `reset_position`, `share_item`, `multi_select` — all `menuCategory="container"`,
`multi_select` `visible=false`) and the swipe actions (`SwipeActions.attachTo(recyclerView)`, `EpisodesListFragment.java:165`,
`CompletedDownloadsFragment.java:113`).

#### G.5 Item background + played/playing indicators

`bg_episode_list_item.xml`: `<inset insetLeft=4dp insetRight=4dp insetTop=2dp insetBottom=2dp>` wrapping a
`<ripple color="?attr/colorControlHighlight">`; mask = black rectangle radius **12dp**; content selector:
`state_activated=true` → solid `?attr/colorSecondaryContainer` radius **12dp**; `state_selected=true` → same;
default → `@android:color/transparent` (`:2-31`).

| State | Mechanism | Value | Ref |
|---|---|---|---|
| played | container alpha | **0.5f** (unplayed = 1.0f) | `EpisodeItemViewHolder.java:107` |
| played (a11y) | `left_padding` contentDescription | `"<title>. Played"` (`is_played` = **"Played"**, `strings.xml:818`) | `EpisodeItemViewHolder.java:97-101` |
| currently playing | `itemView.setActivated(true)` → background `?attr/colorSecondaryContainer` | light #C8D8DE / dark #3C4E68 | `EpisodeItemViewHolder.java:139`, `bg_episode_list_item.xml:16-21` |
| selected (multi-select) | `itemView.setSelected(true)` → same background | — | `EpisodeItemListAdapter.java:121-129` |
| download progress | `CircularProgressBar` in the 48dp button (see §G.4) | 0…1, dashed while queued | `EpisodeItemViewHolder.java:141-152` |
| download-finished/not-downloaded | percentage 1 / 0, not animated | — | `:146-152` |

---

### H. Empty state, loading, multi-select bar (shared)

#### H.1 Empty view (`ui/common/src/main/res/layout/empty_view_layout.xml`)

| Element | Geometry | Ref |
|---|---|---|
| Root `LinearLayout` | match_parent × match_parent, `orientation=vertical`, **`gravity=center`**, `layout_centerInParent=true`, **`paddingLeft/Right=40dp`** | `:2-11` |
| `@+id/emptyViewIcon` `ImageView` | **32dp × 32dp**, `visibility=gone` until `setIcon()` | `:13-19`, `EmptyViewHandler.java:67-70` |
| `@+id/emptyViewTitle` `TextView` | wrap × wrap, **`textSize=16sp`**, `textAlignment=center`, `textColor=?android:attr/textColorPrimary` | `:21-28` |
| `@+id/emptyViewMessage` `TextView` | wrap × wrap, **`textSize=14sp`**, `textAlignment=center` (color = theme default secondary) | `:30-36` |
| `@+id/button` `Button` | wrap × wrap, `visibility=gone`, `layout_marginTop=16dp`, `Widget.Material3.Button.OutlinedButton` — **never used by these 5 screens** | `:38-46` |
| Attachment | inflated + added to the nearest `RelativeLayout` / `FrameLayout` / `CoordinatorLayout` ancestor, centered (`CENTER_IN_PARENT` / `Gravity.CENTER`) | `EmptyViewHandler.java:97-124` |
| Show/hide rule | empty → emptyView `VISIBLE` **and list `INVISIBLE`** (not GONE); non-empty → reverse | `EmptyViewHandler.java:161-172` |

Per-screen empty content:

| Screen | icon (32dp box, 24dp vector) | title (16sp) | message (14sp) |
|---|---|---|---|
| Downloads | `ic_download` | "No downloaded episodes" | "You can download episodes on the podcast details screen." |
| Download log | `ic_download` | "No download log" | "Download logs will appear here when available." |
| Playback history | `ic_history` | "No history" | "After you listen to an episode, it will appear here." |
| Inbox | `ic_inbox` | "No episodes in the inbox" | "New episodes will show up here. You can then decide whether you are interested in them." |
| Favorites | `ic_star` | "No favorites" | "Mark episodes as favorites by tapping the star icon." |
| All episodes | `ic_feed` | "No episodes" | "When you add a podcast, the episodes will be shown here." / filtered: "Try clearing the filter to see more episodes." |

Refs: `CompletedDownloadsFragment.java:243-247`, `DownloadLogFragment.java:66-68`, `PlaybackHistoryFragment.java:39-41`,
`InboxFragment.java:50-52`, `FavoritesFragment.java:32-34`, `EpisodesListFragment.java:201-203`, `AllEpisodesFragment.java:126-131`.

#### H.2 Loading indicators

| Screen | view | type | geometry | Ref |
|---|---|---|---|---|
| Episodes list screens (C/D/E/F) | `@+id/progressBar` | indeterminate `ProgressBar` | wrap × wrap, centered in parent | `episodes_list_fragment.xml:50-58` |
| Downloads | `@+id/progLoading` | indeterminate `ProgressBar` | wrap × wrap, centered | `simple_list_fragment.xml:37-43` |
| Download log | `@+id/progLoading` | indeterminate `ProgressBar` | wrap × wrap, centered — **never shown (dead)** | `download_log_fragment.xml:24-30` |
| Load-more (episodes) | dummy row | skeleton row, alpha 0.1 | 1 row per page load | `EpisodeItemViewHolder.java:196-223` |
| Swipe refresh | `SwipeRefreshLayout` | circular, `distanceToTriggerSync` = **300** | match_parent × match_parent | `EpisodesListFragment.java:173-175` |

#### H.3 Multi-select bottom bar (`FloatingSelectMenu` — this is the "speed dial", not a FAB)

`floating_select_menu.xml`: `FrameLayout` match_parent × **`@dimen/floating_select_menu_height` = 112dp**;
`CardView` with `layout_marginHorizontal=16dp`, `layout_marginBottom=16dp`, `cardCornerRadius=8dp`,
background = `SurfaceColors.getColorForElevation(ctx, 8dp)`; inner `HorizontalScrollView` `paddingHorizontal=8dp`,
`requiresFadingEdge=horizontal`, `fadingEdgeLength=48dp` (`:2-33`, `FloatingSelectMenu.java:41-44`).
Each action item (`floating_select_menu_item.xml`): wrap × match_parent, `paddingHorizontal=4dp`, `paddingTop=12dp`,
`paddingBottom=8dp`, icon `ImageView` **28dp × 28dp**, title `TextView` `marginTop=8dp`, `maxWidth=96dp`,
`minWidth=72dp`, `maxLines=2`, `textAlignment=center`, `TextAppearance.Material3.BodySmall` (12sp) (`:2-31`).
Show/hide animates alpha 0→1 over **100ms** (`FloatingSelectMenu.java:89`, `:91`).
RecyclerView bottom padding while in select mode = `floating_select_menu_height` (112dp), reset to 0 afterwards
(`EpisodesListFragment.java:313-325`, `CompletedDownloadsFragment.java:345-360`).
Menu source: `R.menu.episodes_apply_action_speeddial` (`menu/episodes_apply_action_speeddial.xml:10-75`) —
`remove_item`/`ic_delete` "Delete", `download_item`/`ic_download` "Download", `mark_unread_item`/`ic_mark_unplayed`
"Mark as unplayed", `mark_read_item`/`ic_mark_played` "Mark as played", `remove_from_queue_item`/`ic_playlist_remove`
"Remove from queue", `add_to_queue_item`/`ic_playlist_play` "Add to queue", `share_item`/`ic_share` "Share",
`remove_inbox_item`/`ic_check` "Remove from inbox", `add_to_favorites_item`/`ic_star` "Add to favorites",
`remove_from_favorites_item`/`ic_star_border` "Remove from favorites", `reset_position`/`ic_replay` "Reset playback position",
`move_to_top_item`/`ic_arrow_full_up` "Move to top" (`visible=false`), `move_to_bottom_item`/`ic_arrow_full_down`
"Move to bottom" (`visible=false`). Note the file comment: FAB speed dial renders items in reverse, so XML order is
deliberately inverted (`:5-9`).
**No `FloatingActionButton` exists on any of these 5 screens** — the only FAB in the app is on Subscriptions
(`fragment_subscriptions.xml:102`).

---

### I. Counters / badges — where item counts live

| Counter | Where | Value / format | Ref |
|---|---|---|---|
| Selection count (episodes screens) | **Action-mode title** (top app bar, not the list) | plural `num_selected_label` = **"%1$d/%2$d selected"** — selected/total | `SelectableAdapter.java:200-202`, `strings.xml:173-176` |
| Total for that denominator | `loadTotalItemCount()` → `listAdapter.setTotalNumberOfItems(...)` (falls back to `getItemCount()` when `COUNT_AUTOMATICALLY = -1`) | `DBReader.getTotalEpisodeCount(filter)` | `EpisodesListFragment.java:415`, `SelectableAdapter.java:20,192-199,223-225` |
| Inbox unread badge | **Navigation drawer row**, `@+id/txtvCount` — 14sp, `padding=8dp`, `textColor=?android:attr/textColorTertiary`, `lines=1`, shown only when > 0 | `NumberFormat.getInstance().format(unreadItems)` | `nav_listitem.xml:71-79`, `NavListAdapter.java:200-205` |
| Queue badge | same drawer view | queue size, shown only when > 0 | `NavListAdapter.java:194-199` |
| Subscriptions badge | same drawer view | sum of feed counters | `NavListAdapter.java:206-212` |
| Per-feed badge | same drawer view | `item.getCounter()` | `NavListAdapter.java:232-238` |
| In-list right side | **no count text anywhere** — the right side of a row is the single 48dp action button (§G.4); download-log rows end with the same 48dp button | `feeditemlist_item.xml:219-221`, `downloadlog_item.xml:76-77` |
| List footer "load next page" | **not used by these 5 screens** — `more_content_list_footer.xml` is only instantiated by `FeedItemlistFragment` (`FeedItemlistFragment.java:173`) | `more_content_list_footer.xml:5-34` |

---

### J. Explicit negatives (things that do NOT exist on these 5 screens)

| Claim | Evidence |
|---|---|
| No grid / no column count on any of the 5 screens | `LinearLayoutManager` only (`EpisodeItemListRecyclerView.java:34`); `subscriptions_default_num_of_columns` 3 → 5 (`app/src/main/res/values/integers.xml:3`, `values-sw600dp/integers.xml:3`) is used **only** by the Subscriptions grid |
| No dividers / no `ItemDecoration` | `grep addItemDecoration` → ChaptersFragment, SubscriptionFragment, dialogs only |
| No `FloatingActionButton` / `SpeedDialView` | `grep FloatingActionButton` in `app/src/main/res/layout` → `fragment_subscriptions.xml:102` only |
| No download-log section headers / group rows | flat `ListView` + `BaseAdapter` (`DownloadLogAdapter.java:26,43-53`) |
| No cover/thumbnail in download-log rows | `downloadlog_item.xml:2-79` has no `CardView`/`ImageView` cover |
| No header view (`feeditemlist_header.xml`) on these screens | used only by `FeedItemlistFragment` (podcast detail, `feeditemlist_header.xml:1-259`) |
| No `more_content_list_footer` on these screens | `FeedItemlistFragment.java:173` |
| No count text inside list rows | see §I |
| `horizontal_itemlist_item.xml` / `horizontal_feed_item.xml` not used here | `HorizontalItemViewHolder.java:40` (Echo/statistics), `HorizontalFeedListAdapter.java:53` (subscriptions horizontal list) |
| Download-log `progLoading` never displayed | no Java reference (see §B.2) |
| Playback history has no Search/Refresh menu item | `menu/playback_history.xml` contains only `clear_history_item` |
| `dots_vertical.xml` (24dp "more" icon) is unreferenced | `grep dots_vertical` → 0 hits outside its own file |
| No explicit `minHeight` on episode rows or download-log rows | `feeditemlist_item.xml:14-25`, `downloadlog_item.xml:2-11` |

---

### K. Colour / attr tokens (resolved)

Declared in `ui/common/src/main/res/values/colors.xml`; theme bindings in `ui/common/src/main/res/values/styles.xml`;
custom attrs in `ui/common/src/main/res/values/attrs.xml:3-13`.

| Token | Light | Dark | Ref |
|---|---|---|---|
| `@color/white` | #FFFFFF | #FFFFFF | `colors.xml:4` |
| `@color/black` | #000000 | #000000 | `colors.xml:9` |
| `@color/light_gray` (cover placeholder) | #bfbfbf | #bfbfbf | `colors.xml:7` |
| `@color/medium_gray` (dummy skeleton cover) | #afafaf | #afafaf | `colors.xml:8` |
| `@color/non_square_icon_background` (cover card bg) | #22777777 | #22777777 | `colors.xml:18` |
| `@color/image_readability_tint` | #80000000 | #80000000 | `colors.xml:10` |
| `@color/text_color_secondary_light` / `_dark` | #444444 | #cccccc | `colors.xml:21-22` |
| `@color/color_secondary_container_light` / `_dark` | #C8D8DE | #3C4E68 | `colors.xml:25-26` |
| `@color/color_surface_variant_light` / `_dark` | #D3DCE0 | #2F3B4F | `colors.xml:23-24` |
| `@color/background_light` / `@color/background_darktheme` | #f9fcff | #21272b | `colors.xml:14,16` |
| `@color/background_elevated_light` / `_darktheme` | #EFEEEE | #2D3337 | `colors.xml:15,17` |
| `@color/accent_light` / `_dark` (`colorAccent`, `colorPrimary`) | #0078C2 | #3D8BFF | `colors.xml:28-29`, `styles.xml:39-41,98-100` |
| `?attr/icon_red` (download-log failure reason, error icon) | #CF1800 | #CF1800 | `styles.xml:24,81` |
| `?attr/icon_yellow` / `_green` / `_purple` / `_gray` | #F59F00 / #008537 / #5F1984 / #25365A | #F59F00 / #008537 / #AA55D8 / #CDD9E4 | `styles.xml:25-28,82-85` |
| `?attr/colorOnSurface` (episode title) | #000000 | #FFFFFF | `styles.xml:49,108` |
| `?attr/colorOnSurfaceVariant` (status row tint, download-log status) | #444444 | #cccccc | `styles.xml:52,111` |
| `?android:attr/textColorSecondary` (download-log tap hint) | #444444 | #cccccc | `styles.xml:57,116` |
| `?android:attr/textColorTertiary` (drawer count) | #444444 | #cccccc | `styles.xml:58,117` |
| `?attr/colorSecondaryContainer` (activated/selected row) | #C8D8DE | #3C4E68 | `styles.xml:54,113` |
| `?attr/colorSurfaceContainer` (horizontal card bg, not these screens) | #EBEEF3 | #1C2024 | `styles.xml:53,112` |
| `?attr/action_icon_color` (all 24dp icon fills) | #000000 | #FFFFFF | `styles.xml:19,75` |
| `?attr/action_icon_color` inside a toolbar | `?attr/colorOnSurface` | `?attr/colorOnSurface` | `styles.xml:271-274` |
| `?android:attr/colorBackground` / `?attr/colorSurface` | #f9fcff | #21272b | `styles.xml:47-48,106-107` |
| `?attr/colorControlHighlight` (row ripple) | library default | library default | `bg_episode_list_item.xml:7` |
| linear-progress `trackColor` | #55888888 | #55888888 | `styles.xml:322` |

Icon drawables referenced by these screens (all 24dp vectors, viewport 24×24, `fillColor="?attr/action_icon_color"`
unless noted): `ic_search`, `ic_filter`, `ic_history`, `ic_delete`, `ic_check`, `ic_download`, `ic_star`, `ic_star_border`,
`ic_inbox`, `ic_feed`, `ic_refresh`, `ic_info`, `ic_playlist_play`, `ic_playlist_remove`, `ic_mark_played`,
`ic_mark_unplayed`, `ic_share`, `ic_cancel`, `ic_stream`, `ic_play_24dp`, `ic_videocam`, `ic_load_more`
(`ui/common/src/main/res/drawable/*.xml`, each line 2-3 declares `android:width="24dp"`).
Exceptions: `ic_error` (24dp, two-path red/background vector, `ic_error.xml:6-11`), `ic_pause` (**48dp** intrinsic,
`ic_pause.xml:2`), `ic_replay` (**48dp**, `ic_replay.xml:4`).


---

## B.4 — STATISTICS and OPML import/export

Read-only analysis of `D:\Git\antennapod-harmony\antenna-repo`.

Source of truth (upstream, read-only): `ui/statistics/src/main/res/layout/*.xml` (9 files),
`ui/statistics/src/main/res/menu/statistics.xml`, `ui/statistics/src/main/java/de/danoeh/antennapod/ui/statistics/**`
(13 files), `ui/common/src/main/res/layout/pager_fragment.xml`, `ui/common/src/main/res/layout/toolbar_activity.xml`,
`ui/common/src/main/res/values/dimens.xml`, `ui/common/src/main/res/values/styles.xml`,
`ui/common/src/main/res/values/colors.xml`, `ui/common/src/main/res/drawable/ic_filter.xml`,
`app/src/main/res/layout/opml_selection.xml`, `app/src/main/res/menu/opml_selection_options.xml`,
`app/src/main/res/values/ids.xml`, `app/src/main/java/de/danoeh/antennapod/activity/OpmlImportActivity.java`,
`app/src/main/java/de/danoeh/antennapod/ui/screen/preferences/ImportExportPreferencesFragment.java`,
`app/src/main/AndroidManifest.xml`, `ui/preferences/src/main/res/xml/preferences_import_export.xml`,
`ui/i18n/src/main/res/values/strings.xml`.

Checkout caveat: this repo is a **partial checkout**. Present: `app/`, `storage/preferences/`, `store-metadata/`,
`ui/{app-start-intent,chapters,common,discovery,echo,episodes,glide,i18n,notifications,preferences,statistics,transcript,widget}`.
**Absent**: `storage/importexport/` (i.e. `OpmlReader`/`OpmlWriter`/`OpmlElement` sources), `:event`, `:model`,
`:storage:database`, `gradle/libs.versions.toml`. No Android SDK is installed on this machine, so **platform-owned
values (`android.R.layout.*`, `?attr/actionBarSize`, `?android:attr/dividerVertical`, Material3 text-appearance
sizes) could not be resolved locally**; those are marked `[platform/library — not verifiable here]`.

---

### A. STATISTICS

#### A.0 Hosting & navigation model

| Fact | Value | Ref |
|---|---|---|
| Host activity | `MainActivity` (nav-drawer fragment host) | `MainActivity.java:450-451` |
| Fragment | `StatisticsFragment extends PagedToolbarFragment` | `StatisticsFragment.java:40` |
| Fragment tag | `StatisticsFragment.TAG = "StatisticsFragment"` | `StatisticsFragment.java:41` |
| Drawer label | `R.string.statistics_label` = **"Statistics"** | `NavigationNames.java:61-62`, `strings.xml:13` |
| Bottom-nav / short label | `R.string.statistics_label_short` = **"Stats"** | `NavigationNames.java:90-91`, `strings.xml:14` |
| Drawer icon | `R.drawable.ic_chart_box` | `NavigationNames.java:34-35` |
| Root layout | `R.layout.pager_fragment` (ui/common) | `StatisticsFragment.java:64` |
| Pager pages | **3** (`POS_SUBSCRIPTIONS=0`, `POS_YEARS=1`, `POS_SPACE_TAKEN=2`, `TOTAL_COUNT=3`) | `StatisticsFragment.java:48-51,170-172` |
| Child fragments | 0→`SubscriptionStatisticsFragment`, 1→`YearsStatisticsFragment`, 2→`DownloadStatisticsFragment` | `StatisticsFragment.java:157-166` |
| Menu inflate | `toolbar.inflateMenu(R.menu.statistics)` | `StatisticsFragment.java:68` |
| Menu→child routing | page change + click forwarded to `child.onOptionsItemSelected` / `child.onPrepareOptionsMenu` | `PagedToolbarFragment.java:15-43` |

#### A.1 Toolbar (`ui/common/src/main/res/layout/pager_fragment.xml`)

| Property | Value | Ref |
|---|---|---|
| Container | `LinearLayout` vertical, match_parent/match_parent | `pager_fragment.xml:2-7` |
| App bar | `com.google.android.material.appbar.AppBarLayout`, `wrap_content`, `fitsSystemWindows="true"` | `pager_fragment.xml:9-13` |
| Toolbar | `MaterialToolbar @+id/toolbar`, match_parent × `?attr/actionBarSize` `[platform/library — not verifiable here]` | `pager_fragment.xml:15-18` |
| Toolbar title | `toolbar.setTitle(R.string.statistics_label)` = **"Statistics"** | `StatisticsFragment.java:67` |
| Navigation icon | `?homeAsUpIndicator`; contentDescription = **"Back"** (`toolbar_back_button_content_description`) | `pager_fragment.xml:19-20`, `strings.xml:808` |
| Up-arrow logic | up arrow shown when `getParentFragmentManager().getBackStackEntryCount() != 0`, else back-pop listener; saved as `KEY_UP_ARROW` | `StatisticsFragment.java:46,72-80,104-107` |
| Toolbar elevation | 0dp (`Widget.AntennaPod.ActionBar`, `elevation=0dp`, background `?android:attr/colorBackground`) | `styles.xml:325-328` |
| Toolbar theme overlay | `Style.AntennaPod.Toolbar` → `Widget.Material3.Toolbar`; `action_icon_color`/`colorControlNormal` = `?attr/colorOnSurface` | `styles.xml:267-274` |

#### A.2 Toolbar menu — declaration order in `ui/statistics/src/main/res/menu/statistics.xml`

| # | id | icon | title (exact English literal) | showAsAction | declared `visible` | runtime visibility |
|---|---|---|---|---|---|---|
| 1 | `statistics_reset` | — (none) | **"Reset statistics data"** (`statistics_reset_data`) | `never` | (unset → true) | visible on tabs 0 & 1; hidden on tab 2 | 
| 2 | `statistics_filter` | `@drawable/ic_filter` (24×24dp vector, `fillColor="?attr/action_icon_color"`) | **"Filter"** (`filter`) | `ifRoom` | (unset → true) | visible on tab 0 only; hidden on tabs 1 & 2 | 
| 3 | `show_echo` | — (none) | **"AntennaPod Echo"** (`antennapod_echo`, `translatable="false"`) | `never` | `false` | shown iff `BuildConfig.DEBUG \|\| EchoConfig.isCurrentlyVisible()` | 

Refs: menu rows `statistics.xml:5-20`; icon `ui/common/src/main/res/drawable/ic_filter.xml:1-6`;
titles `strings.xml:61,916,1006`; runtime visibility `SubscriptionStatisticsFragment.java:87-88`,
`YearsStatisticsFragment.java:74-75`, `DownloadStatisticsFragment.java:59-60`, `StatisticsFragment.java:69-71`.

Menu actions: `statistics_reset` → `confirmResetStatistics()`; `statistics_filter` → `new StatisticsFilterDialog(ctx, statisticsResult.oldestDate).show()`;
`show_echo` → start `EchoActivity`. (`StatisticsFragment.java:110-133`, `SubscriptionStatisticsFragment.java:92-99`.)

#### A.3 Tab bar / the ordered list of visible section titles

`com.google.android.material.tabs.TabLayout @+id/sliding_tabs` — match_parent × `wrap_content`,
`background="?android:attr/colorBackground"`, `app:tabBackground="?attr/selectableItemBackground"`,
`app:tabMode="auto"`, `app:tabGravity="fill"` (`pager_fragment.xml:24-31`). Tab text appearance is **not overridden**
→ Material3 default (`TextAppearance.Material3.TitleSmall`, 14sp) `[library — not verifiable here]`.

| Pos | Tab title (exact English literal) | string name | Ref |
|---|---|---|---|
| 0 | **"Subscriptions"** | `subscriptions_label` | `StatisticsFragment.java:88`, `strings.xml:31` |
| 1 | **"Years"** | `years_statistics_label` | `StatisticsFragment.java:91`, `strings.xml:37` |
| 2 | **"Downloads"** | `downloads_label` | `StatisticsFragment.java:94`, `strings.xml:28` |

Page content: `ViewPager2 @+id/viewpager`, match_parent/match_parent (`pager_fragment.xml:33-36`).

#### A.4 Shared list container — `ui/statistics/src/main/res/layout/statistics_fragment.xml`

Inflated by all three tabs (`SubscriptionStatisticsFragment.java:54`, `YearsStatisticsFragment.java:41`,
`DownloadStatisticsFragment.java:41`).

| Node | Geometry / styling | Ref |
|---|---|---|
| root `FrameLayout` | match_parent × match_parent (`android:orientation="vertical"` present but a no-op on FrameLayout) | `statistics_fragment.xml:2-7` |
| `ProgressBar @+id/progressBar` | `wrap_content` × `wrap_content`, `layout_gravity="center"`; no size/tint set in repo | `statistics_fragment.xml:9-13` |
| `RecyclerView @+id/statistics_list` | match_parent × match_parent, `clipToPadding="false"`, `paddingTop`/`paddingBottom` = `@dimen/list_vertical_padding` = **8dp**, `scrollbarStyle="outsideOverlay"` | `statistics_fragment.xml:15-23`, `dimens.xml:18` |
| LayoutManager | `LinearLayoutManager` (vertical, default) | `SubscriptionStatisticsFragment.java:58`, `DownloadStatisticsFragment.java:45`, `YearsStatisticsFragment.java:45` |
| Item decoration / dividers between rows | **none** (no `addItemDecoration` anywhere in the module) | grep of module: no match |
| Empty state | **none** — no `EmptyViewHandler`/empty view in any statistics layout; list always renders at least the header row | `statistics_fragment.xml` has no empty view; `StatisticsListAdapter.java:33-34` always returns `size+1` |
| Loading behaviour | progress bar VISIBLE + list GONE while loading, swapped on result | `SubscriptionStatisticsFragment.java:103-104,133-134` |
| Row click | `statistics_listitem` rows open `FeedStatisticsDialogFragment` (bottom sheet) | `PlaybackStatisticsListAdapter.java:71-73`, `DownloadStatisticsListAdapter.java:56-58` |
| Sort order | tab 0 by `timePlayed` desc; tab 2 by `totalDownloadSize` desc; tab 1 newest year first | `SubscriptionStatisticsFragment.java:120-121`, `DownloadStatisticsFragment.java:78-79`, `YearStatisticsListAdapter.java:96` |

#### A.5 Header row, tabs 0 & 2 — `statistics_listitem_total.xml`

Inflated as `TYPE_HEADER` (position 0) by both pie-chart tabs (`StatisticsListAdapter.java:22,39,47`).

| Node | Geometry / styling | Ref |
|---|---|---|
| root `RelativeLayout` | match_parent × wrap_content, **padding 16dp all sides** | `statistics_listitem_total.xml:2-7` |
| `PieChartView @+id/pie_chart` | `wrap_content` × `wrap_content`, `layout_centerInParent="true"`, `marginLeft`/`marginRight` = **8dp**, `android:minWidth="460dp"`, `android:maxWidth="800dp"` | `statistics_listitem_total.xml:9-17` |
| **Pie chart height** | custom `onMeasure`: `setMeasuredDimension(width, width / 2)` → **height = width/2**; with `minWidth 460dp` the chart is **≥ 230dp tall** | `PieChartView.java:68-72` |
| `TextView @+id/total_time` | match_parent × wrap_content, `textColor="?android:attr/textColorPrimary"`, `gravity="center_horizontal"`, **textSize 28sp**, `marginBottom 4dp`, `layout_above="@id/total_description"` | `statistics_listitem_total.xml:19-28` |
| `TextView @+id/total_description` | wrap_content × wrap_content, `layout_centerHorizontal`, `textAlignment="center"`, `maxLines="3"`, **textSize 14sp**, `marginBottom 16dp`, `layout_alignBottom="@id/pie_chart"` | `statistics_listitem_total.xml:30-39` |
| Divider `View` | match_parent × **1dp**, `marginTop 16dp`, `background="?android:attr/dividerVertical"` `[platform — not verifiable here]`, `layout_below="@id/pie_chart"` | `statistics_listitem_total.xml:41-46` |
| Effective header height | 16 (top pad) + ≥230 (pie) + 16 (divider margin) + 1 (divider) + 16 (bottom pad) ≈ **≥279dp** | derived from above |
| Header value text | tab 0: `Converter.shortLocalizedDuration(sum)`; tab 2: `Formatter.formatShortFileSize(sum)` | `PlaybackStatisticsListAdapter.java:52-54`, `DownloadStatisticsListAdapter.java:33-35` |
| Header caption text | tab 0: **"Played in total"** (`statistics_counting_total`) when "include marked" is on, else **"Played between %1$s and %2$s"** (`statistics_counting_range`) with `MMM yyyy` dates; tab 2: **"Total size of %d episode on the device"** / **"Total size of %d episodes on the device"** (`total_size_downloaded_podcasts`) | `PlaybackStatisticsListAdapter.java:39-49`, `DownloadStatisticsListAdapter.java:27-30`, `strings.xml:63-64,85-88` |

##### A.5.1 Pie chart drawable geometry (`PieChartView.java`)

| Property | Value | Ref |
|---|---|---|
| View base | `AppCompatImageView` | `PieChartView.java:19` |
| Stroke width | `bounds.height() / 30f` | `PieChartView.java:130-131` |
| Radius | `bounds.height() - strokeSize` (semicircle) | `PieChartView.java:133` |
| Center X | `bounds.width() / 2f` | `PieChartView.java:134` |
| Arc bounds | `RectF(center-radius, strokeSize, center+radius, strokeSize + radius*2)` | `PieChartView.java:135` |
| Start angle | **180°** (top half only) | `PieChartView.java:137` |
| Slice gap | `PADDING_DEGREES = 3f`; first slice uses `1.5°`, others `3°`; total usable sweep = `180 - 3 = 177°` | `PieChartView.java:115,143-144` |
| Slice sweep | `(180 - 3) * percentage` | `PieChartView.java:144` |
| Slices below threshold | `isLargeEnoughToDisplay` = percentage **> 0.04 (4%)**; iteration **breaks** at the first too-small slice, remainder drawn `Color.GRAY` (`0xFF888888`) | `PieChartView.java:102-104,139-140,151-157` |
| Slice colors | 15-entry palette `COLOR_VALUES` (see A.15), `index % 15` | `PieChartView.java:75-77,110` |
| Chip/legend color | `getColorOfItem(i)` — same palette, or `Color.GRAY` if slice < 4% | `PieChartView.java:106-111` |
| Animation | `ValueAnimator 0→1`, duration **400ms**, start delay **200ms**, `DecelerateInterpolator`, runs only when `animationProgress == 0f` | `PieChartView.java:20-21,51-64` |

##### A.5.2 Bar chart geometry (`years/BarChartView.java`)

| Property | Value | Ref |
|---|---|---|
| View base | `AppCompatImageView`; height **200dp**, width match_parent (from layout) | `BarChartView.java:22`, `statistics_listitem_barchart.xml:9-12` |
| `barHeight` | `height * 0.9` = **180dp** of the 200dp view | `BarChartView.java:101` |
| `textPadding` (left) | `width * 0.05` | `BarChartView.java:102` |
| `stepSize` | `(width - textPadding) / (data.size() + 2)` | `BarChartView.java:103` |
| Grid text size | `height * 0.06` = **12dp** | `BarChartView.java:104-105` |
| Bar width | `stepSize * 0.95` | `BarChartView.java:135` |
| Bar fill style | `Paint.Style.FILL`, anti-aliased; `strokeWidth = height * 0.015` (irrelevant for FILL) | `BarChartView.java:86-87,107` |
| Bar colors | alternates `{0xff3775e6, 0xff9c27b0}` per year, `colorIndex % 2`; year label drawn at year boundary (suppressed for last 4 bars); month-1 boundary gets a full-height line | `BarChartView.java:82,118-129` |
| Min bar height | `max(0.005, value/maxValue)` (0.5% floor) | `BarChartView.java:131` |
| Stagger | per-bar animation offset `0.6 * i / (size-1)` over the first `0.4` of progress | `BarChartView.java:132-133` |
| Grid lines | `DashPathEffect({10f, 10f}, 0f)`, `Paint.Style.STROKE`, color = `android.R.attr.textColorSecondary`; two lines: `maxLine = floor(maxValue / (10h)) * 10h` and `midLine = maxLine/2`; labels = hours as integers | `BarChartView.java:88-90,138-146` |
| Grid text color | `android.R.attr.textColorSecondary` via `ThemeUtils.getColorFromAttr` | `BarChartView.java:91-94` |
| Animation | `ValueAnimator 0→1`, duration **400ms**, delay **200ms**, `LinearInterpolator` | `BarChartView.java:23-24,62-65` |

##### A.5.3 Years header layout — `statistics_listitem_barchart.xml`

| Node | Geometry / styling | Ref |
|---|---|---|
| root `LinearLayout` | vertical, match_parent × wrap_content, **padding 16dp** | `statistics_listitem_barchart.xml:2-7` |
| `BarChartView @+id/barChart` | match_parent × **200dp** | `statistics_listitem_barchart.xml:9-12` |
| `TextView @+id/barchart_description` | wrap_content, `textAlignment="center"`, `layout_gravity="center"`, text = **"Time played per month"** (`statistics_years_barchart_description`); no explicit textSize/color → theme default body | `statistics_listitem_barchart.xml:14-20`, `strings.xml:868` |
| Divider `View` | match_parent × **1dp**, `marginTop 16dp`, `background="?android:attr/dividerVertical"` | `statistics_listitem_barchart.xml:22-26` |
| Header height | 16 + 200 + text line + 16 + 1 + 16 ≈ **≥249dp** | derived |

#### A.6 Feed row, tabs 0 & 2 — `statistics_listitem.xml`

Inflated as `TYPE_FEED` (`StatisticsListAdapter.java:23,39,49`).

| Node | Geometry / styling | Ref |
|---|---|---|
| root `RelativeLayout` | match_parent × wrap_content, `paddingLeft/Right` **16dp**, `paddingTop/Bottom` **8dp**, `background="?android:attr/selectableItemBackground"` | `statistics_listitem.xml:2-12` |
| `ImageView @+id/imgvCover` | **40dp × 40dp**, `alignParentStart`, `centerVertical`, `adjustViewBounds`, `cropToPadding`, `scaleType="fitCenter"`, `importantForAccessibility="no"` | `statistics_listitem.xml:15-27` |
| `TextView @+id/txtvTitle` | wrap_content, `lines="1"`, `singleLine`, `ellipsize="end"`, `textColor="?android:attr/textColorPrimary"`, **textSize 16sp**, `marginStart 16dp`, `toEndOf=imgvCover`, `alignTop=imgvCover` | `statistics_listitem.xml:29-44` |
| `TextView @+id/chip` (legend dot) | wrap_content, **textSize 13sp**, `toEndOf=imgvCover`, `marginStart 16dp`, `marginEnd 4dp`, `layout_below="@+id/txtvTitle"`, hardcoded text **"⬤"**; color set at bind time to the slice color | `statistics_listitem.xml:46-59`, `StatisticsListAdapter.java:72` |
| `TextView @+id/txtvValue` | wrap_content, `lines="1"`, `textColor="?android:attr/textColorTertiary"`, **textSize 14sp**, `toEndOf=chip`, `layout_below="@+id/txtvTitle"` | `statistics_listitem.xml:61-71` |
| Row min height | 8 + 40 (cover) + 8 = **56dp** | derived from above |
| Cover placeholder/error | `@color/light_gray` = **#bfbfbf**, `fitCenter`, `dontAnimate` (Glide) | `StatisticsListAdapter.java:62-69`, `colors.xml:7` |
| Value text — tab 0 | `Converter.shortLocalizedDuration(timePlayed)` | `PlaybackStatisticsListAdapter.java:67-69` |
| Value text — tab 2 | `formatShortFileSize(size) + " • " + quantityString(num_episodes, n)` → e.g. "12 MB • 3 episodes" | `DownloadStatisticsListAdapter.java:50-54`, `strings.xml:177-180` |
| **There is no legend view** — the legend is the per-row `⬤` chip above | — | `statistics_listitem.xml:46-59` |

#### A.7 Year row, tab 1 — `statistics_year_listitem.xml`

Inflated as `TYPE_FEED` (`YearStatisticsListAdapter.java:24,40,50`).

| Node | Geometry / styling | Ref |
|---|---|---|
| root `LinearLayout` | vertical, match_parent × wrap_content, `paddingLeft/Right` **16dp**, `paddingTop` **16dp**, `paddingBottom` **8dp**, `background="?android:attr/selectableItemBackground"` | `statistics_year_listitem.xml:2-13` |
| `TextView @+id/yearLabel` | wrap_content, `lines="1"`, `textColor="?android:attr/textColorPrimary"`, **textSize 16sp**; text = `String.format("%d ", year)` — **note the trailing space** | `statistics_year_listitem.xml:15-22`, `YearStatisticsListAdapter.java:61` |
| `TextView @+id/hoursLabel` | wrap_content, `lines="1"`, `textColor="?android:attr/textColorTertiary"`, **textSize 14sp**; text = `shortLocalizedDuration(timePlayed/1000)` | `statistics_year_listitem.xml:24-31`, `YearStatisticsListAdapter.java:62` |
| Row min height | 16 + ~21 (16sp) + ~18 (14sp) + 8 ≈ **63dp** | derived |
| No cover image, no chip, no click handler on year rows | — | `YearStatisticsListAdapter.java:54-63` |

#### A.8 Tab 2 "Downloads" deltas vs tab 0

| Aspect | Difference | Ref |
|---|---|---|
| Header caption | `total_size_downloaded_podcasts` plural | `DownloadStatisticsListAdapter.java:27-30` |
| Header value | `Formatter.formatShortFileSize` (bytes) | `DownloadStatisticsListAdapter.java:33-35` |
| Pie values | `totalDownloadSize` (not time) | `DownloadStatisticsListAdapter.java:41-44` |
| Filters ignored | `DBReader.getStatistics(false, 0, Long.MAX_VALUE)` | `DownloadStatisticsFragment.java:77` |
| Menu | `statistics_reset` and `statistics_filter` both hidden | `DownloadStatisticsFragment.java:59-60` |
| Row value | size + `" • "` + episode count | `DownloadStatisticsListAdapter.java:50-54` |

#### A.9 Feed statistics (bottom sheet) — `feed_statistics_dialog.xml` + `feed_statistics.xml` + `feed_statistics_card.xml`

Opened from a statistics row (`FeedStatisticsDialogFragment`), and embedded (non-detailed) inside `FeedInfoFragment`
(`FeedInfoFragment.java:102,238`).

| Node | Geometry / styling | Ref |
|---|---|---|
| Sheet root | `LinearLayout` vertical, match_parent × wrap_content, **padding 8dp** | `feed_statistics_dialog.xml:2-7` |
| `TextView @+id/title` | match_parent, `textAppearance="@style/TextAppearance.Material3.TitleLarge"` (**22sp** `[library]`), `marginHorizontal 8dp`, `marginVertical 16dp`; text = feed title | `feed_statistics_dialog.xml:9-15`, `FeedStatisticsDialogFragment.java:34` |
| `FragmentContainerView @+id/statisticsContainer` | match_parent × wrap_content (hosts `FeedStatisticsFragment`) | `feed_statistics_dialog.xml:17-20`, `FeedStatisticsDialogFragment.java:47-49` |
| `MaterialButton @+id/openPodcastButton` | wrap_content, `layout_gravity="end"`, `marginHorizontal 8dp`, `marginTop 8dp`, `marginBottom 16dp`, text = **"Open podcast"** (`open_podcast`), style `Widget.Material3.Button.TextButton` | `feed_statistics_dialog.xml:22-31`, `strings.xml:229` |

`feed_statistics.xml` — 3 rows of cards (`LinearLayout` vertical root, each row horizontal):

| Row | Cards (left→right, `include` of `feed_statistics_card`) | Visibility | Ref |
|---|---|---|---|
| 1 | `playbackTime`, `episodesStarted`, `spaceDownloaded` | always | `feed_statistics.xml:9-26` |
| 2 | `durationTotal`, `episodesTotal`, `episodesDownloaded` | container `@+id/secondRowContainer` `visibility="gone"`; shown only when `EXTRA_DETAILED` is true (bottom-sheet path) | `feed_statistics.xml:28-48`, `FeedStatisticsFragment.java:59-60` |
| 3 | `expectedNextEpisode`, `episodeSchedule` | always | `feed_statistics.xml:50-63` |

`feed_statistics_card.xml` (each card):

| Property | Value | Ref |
|---|---|---|
| Container | `LinearLayout` vertical, match_parent × match_parent, `layout_weight="1"`, **margin 4dp**, **padding 8dp** | `feed_statistics_card.xml:2-12` |
| Background | `?attr/colorSurfaceContainer` — **#EBEEF3** (light) / **#1C2024** (dark) | `feed_statistics_card.xml:10`, `styles.xml:53,112` |
| Background (detailed sheet) | overridden at runtime to `R.attr.colorSurfaceContainerHighest` = **#C0CFD3** (light) / **#38455C** (dark) | `FeedStatisticsFragment.java:61-69`, `styles.xml:62,121` |
| `@+id/mainLabel` | match_parent × wrap_content, style `TextAppearance.Material3.TitleSmall` (**14sp** `[library]`) | `feed_statistics_card.xml:14-20` |
| `@+id/subtitleLabel` | match_parent × wrap_content, style `TextAppearance.Material3.BodySmall` (**12sp** `[library]`) | `feed_statistics_card.xml:22-27` |
| No corner radius, no elevation, no stroke | plain rectangles (M3 `colorSurfaceContainer` fill) | `feed_statistics_card.xml:2-12` |

Card label literals (main value / subtitle caption), in visible order:

| # | Card id | main value source | subtitle literal | Ref |
|---|---|---|---|---|
| 1 | `playbackTime` | `shortLocalizedDuration(timePlayed)` | **"played"** (`statistics_time_played`) | `FeedStatisticsFragment.java:167-168`, `strings.xml:860` |
| 2 | `episodesStarted` | `num_episodes` plural ("%d episode(s)") | **"started"** (`statistics_episodes_started`) | `FeedStatisticsFragment.java:157-160`, `strings.xml:847-850` |
| 3 | `spaceDownloaded` | `formatShortFileSize(totalDownloadSize)` | **"space taken"** (`statistics_episodes_space`) | `FeedStatisticsFragment.java:178-179`, `strings.xml:861` |
| 4 | `durationTotal` (detailed only) | `shortLocalizedDuration(time)` | **"total"** (`statistics_time_total`) | `FeedStatisticsFragment.java:170-171`, `strings.xml:859` |
| 5 | `episodesTotal` (detailed only) | `num_episodes` plural | **"total"** (`statistics_episodes_total`) | `FeedStatisticsFragment.java:162-165`, `strings.xml:851-854` |
| 6 | `episodesDownloaded` (detailed only) | `num_episodes` plural | **"downloaded"** (`statistics_episodes_downloaded`) | `FeedStatisticsFragment.java:173-176`, `strings.xml:855-858` |
| 7 | `expectedNextEpisode` | date / **"Any day now"** / **"Any time now"** / **"Unknown"** / **"Local folder"** / **"Updates disabled"** | **"next episode (estimate)"** (`statistics_release_next`) | `FeedStatisticsFragment.java:181,190-203`, `strings.xml:863-866,909,231` |
| 8 | `episodeSchedule` | schedule string (**"daily"**, **"on weekdays"**, **"weekly, Mon"**, **"every two weeks, Mon"**, **"monthly"**, **"multiple times per day"**, …) | **"release schedule"** (`statistics_release_schedule`) | `FeedStatisticsFragment.java:124-153,182,204-208`, `strings.xml:875-888` |

#### A.10 Filter dialog / year-period selector — `statistics_filter_dialog.xml`

Shown from menu item `statistics_filter` (tab 0 only). `MaterialAlertDialogBuilder` with `setTitle(R.string.filter)` =
**"Filter"** and positive button `android.R.string.ok`; no negative button (`StatisticsFilterDialog.java:41-46,88,105`).

| Node | Geometry / styling | Ref |
|---|---|---|
| root `LinearLayout` | vertical, match_parent × wrap_content, **padding 16dp** | `statistics_filter_dialog.xml:2-7` |
| `CheckBox @+id/includeMarkedCheckbox` | match_parent × wrap_content, text = **"Include duration of episodes that are just marked as played"** (`statistics_include_marked`), `marginBottom 8dp` | `statistics_filter_dialog.xml:9-14`, `strings.xml:54` |
| `LinearLayout @+id/dateSelectionContainer` | vertical; `setAlpha(0.5f)` when the checkbox is checked, else `1f` | `statistics_filter_dialog.xml:16-20`, `StatisticsFilterDialog.java:52` |
| Row: labels | 2 `TextView`s, `layout_weight="1"`, **padding 4dp**, texts **"From"** (`statistics_from`) / **"To"** (`statistics_to`) | `statistics_filter_dialog.xml:22-41`, `strings.xml:56-57` |
| Row: spinners | `Spinner @+id/timeFromSpinner` and `@+id/timeToSpinner`, `layout_weight="1"`, wrap_content; adapters use `android.R.layout.simple_spinner_item` + `simple_spinner_dropdown_item` | `statistics_filter_dialog.xml:43-60`, `StatisticsFilterDialog.java:57-59,68-70` |
| Row: quick buttons | `Button @+id/past_year_button` **"Past year"** (`statistics_filter_past_year`) weight 1, `marginEnd 4dp`; `Button @+id/allTimeButton` **"All time"** (`statistics_filter_all_time`) weight 1, `marginStart 4dp`; both `style="@style/Widget.MaterialComponents.Button.OutlinedButton"` (**M2 outlined** style, not M3) | `statistics_filter_dialog.xml:62-85`, `strings.xml:59-60` |
| Footer notice | `TextView` match_parent, text = **"Notice: Playback speed is never taken into account."** (`statistics_speed_not_counted`), `marginTop 16dp`; no explicit size/color → theme body default | `statistics_filter_dialog.xml:89-93`, `strings.xml:55` |
| Disable behaviour | checking the box disables both spinners + both buttons | `StatisticsFilterDialog.java:47-53` |
| Spinner item list | one entry per month from the oldest data date to now, formatted with the locale `MMM yyyy` best pattern; the "to" list additionally appends **"Today"** (`statistics_today`) with value `Long.MAX_VALUE` | `StatisticsFilterDialog.java:108-139`, `strings.xml:58` |
| Button behaviour | "All time" → from=index 0, to=last; "Past year" → from=`length-12`, to=`length-2` | `StatisticsFilterDialog.java:79-86` |
| Persistence | `SharedPreferences "StatisticsActivityPrefs"`: `countAll`, `filterFrom`, `filterTo` | `StatisticsFragment.java:42-45`, `StatisticsFilterDialog.java:98-102` |

#### A.11 Reset confirmation dialog (menu item 1)

`ConfirmationDialog` → `MaterialAlertDialogBuilder` with title `R.string.statistics_reset_data` =
**"Reset statistics data"**, message `R.string.statistics_reset_data_msg` =
**"This will erase the history of duration played for all episodes. Are you sure you want to proceed?"**,
positive = `R.string.confirm_label` = **"Confirm"**, negative = `R.string.cancel_label` = **"Cancel"**.
(`StatisticsFragment.java:120-133`, `ConfirmationDialog.java:44-53`, `strings.xml:61-62,122-123`.)

#### A.12 Layout inventory — `ui/statistics/src/main/res/layout/` (9 files, **all used**)

| File | Renders | Inflated by |
|---|---|---|
| `statistics_fragment.xml` | progress bar + statistics `RecyclerView` (shared by all 3 tabs) | `SubscriptionStatisticsFragment.java:54`, `YearsStatisticsFragment.java:41`, `DownloadStatisticsFragment.java:41` |
| `statistics_listitem_total.xml` | pie-chart header (total value + caption + divider) | `StatisticsListAdapter.java:47` |
| `statistics_listitem.xml` | one feed row: 40dp cover, 16sp title, 13sp ⬤ chip, 14sp value | `StatisticsListAdapter.java:49` |
| `statistics_listitem_barchart.xml` | years header: 200dp bar chart + "Time played per month" + divider | `YearStatisticsListAdapter.java:48` |
| `statistics_year_listitem.xml` | one year row: 16sp year + 14sp hours | `YearStatisticsListAdapter.java:50` |
| `statistics_filter_dialog.xml` | filter dialog body (checkbox, From/To spinners, Past year / All time, notice) | `StatisticsFilterDialog.java:42` (view binding) |
| `feed_statistics_dialog.xml` | bottom-sheet shell: title, fragment container, "Open podcast" button | `FeedStatisticsDialogFragment.java:33` |
| `feed_statistics.xml` | 3 rows × cards grid (8 cards) | `FeedStatisticsFragment.java:56` (view binding) |
| `feed_statistics_card.xml` | one stat card (main label + subtitle) | included 8× from `feed_statistics.xml` |

Unused layouts in this module: **none**. (`ui/statistics/src/main/res/` contains only `layout/` and `menu/statistics.xml`
— **no `values/` folder**, so the module defines no dimens/colors/styles/strings of its own; every dimen it references
comes from `ui/common/src/main/res/values/dimens.xml`.)

#### A.13 Color / attr token resolution

| Token | Resolved value | Ref |
|---|---|---|
| `?android:attr/textColorPrimary` | `@color/black` #000000 (light) / `@color/white` #FFFFFF (dark) | `styles.xml:56,115` |
| `?android:attr/textColorSecondary` | `@color/text_color_secondary_light` **#444444** / `@color/text_color_secondary_dark` **#cccccc** | `styles.xml:57,116`, `colors.xml:21-22` |
| `?android:attr/textColorTertiary` | same as secondary (#444444 / #cccccc) | `styles.xml:58,117` |
| `?android:attr/dividerVertical` | **not defined in this repo** → platform/AppCompat list-divider drawable `[platform — not verifiable here]` | `statistics_listitem_total.xml:45`, `statistics_listitem_barchart.xml:26` |
| `?android:attr/selectableItemBackground` | platform ripple `[platform]` | `statistics_listitem.xml:12`, `statistics_year_listitem.xml:12` |
| `?android:attr/colorBackground` | `@color/background_light` **#f9fcff** / `@color/background_darktheme` **#21272b** | `styles.xml:47,106`, `colors.xml:14,16` |
| `?attr/colorSurfaceContainer` | **#EBEEF3** (light, `styles.xml:53`) / **#1C2024** (dark, `styles.xml:112`) | `feed_statistics_card.xml:10` |
| `R.attr.colorSurfaceContainerHighest` | **#C0CFD3** (light, `styles.xml:62`) / **#38455C** (dark, `styles.xml:121`) | `FeedStatisticsFragment.java:61` |
| `?attr/action_icon_color` | `@color/black` (light) / `@color/white` (dark); toolbar overlay maps it to `?attr/colorOnSurface` | `styles.xml:19,75,272` |
| `@color/light_gray` (cover placeholder/error) | **#bfbfbf** | `StatisticsListAdapter.java:65-66`, `colors.xml:7` |
| `?attr/actionBarSize` | not in repo; Material3 theme default `[library — not verifiable here]` | `pager_fragment.xml:18` |
| `@dimen/list_vertical_padding` | **8dp** | `dimens.xml:18` |

Dynamic-color note: `Theme.AntennaPod.Dynamic.Light/Dark` (parent `Theme.Material3.DynamicColors.*`) are the base
themes (`styles.xml:12,71`); when Material You dynamic color is active, `colorSurfaceContainer` /
`colorSurfaceContainerHighest` are **overridden by the system palette**, not by the literals above
(`Theme.AntennaPod.Light/Dark` set `isMaterial3DynamicColorApplied=false`, `styles.xml:38,97`).

#### A.14 Chart color arrays (hard-coded, not theme tokens)

| Array | Values | Ref |
|---|---|---|
| Pie chart palette (15) | `0xFF3775E6`, `0xFFE51C23`, `0xFFFF9800`, `0xFF259B24`, `0xFF9C27B0`, `0xFF0099C6`, `0xFFDD4477`, `0xFF66AA00`, `0xFFB82E2E`, `0xFF316395`, `0xFF994499`, `0xFF22AA99`, `0xFFAAAA11`, `0xFF6633CC`, `0xFF0073E6` | `PieChartView.java:75-77` |
| Pie "other/too small" | `Color.GRAY` = `0xFF888888` | `PieChartView.java:108,151` |
| Bar chart palette (2, alternating per year) | `0xFF3775E6`, `0xFF9C27B0` | `BarChartView.java:82` |

---

### B. OPML IMPORT

#### B.0 Entry points

| Entry | Detail | Ref |
|---|---|---|
| Settings → "Backup & restore" → **"OPML import"** preference | key `prefOpmlImport`, summary **"Import your subscriptions from another podcast app"** | `preferences_import_export.xml:29-32`, `strings.xml:671,674` |
| "Add podcast" screen → **"Import podcast list (OPML)"** row | `TextView @+id/opmlImportButton`, style `AddPodcastTextView`, drawable `ic_download` | `addfeed.xml:141-148`, `AddFeedFragment.java:110-117,213-220` |
| External intent | `ACTION_VIEW` / `ACTION_SEND` with mime `text/xml`, `text/x-opml`, `application/xml`, schemes `file`/`content`/`http`/`https`, `exported=true` | `AndroidManifest.xml:145-166` |
| Host activity | `OpmlImportActivity extends ToolbarActivity`; `setContentView(OpmlSelectionBinding)` | `OpmlImportActivity.java:55,68-69` |

#### B.1 Toolbar

| Property | Value | Ref |
|---|---|---|
| Toolbar layout | `ui/common/src/main/res/layout/toolbar_activity.xml`: `MaterialToolbar @+id/toolbar`, match_parent × `wrap_content`, `minHeight="?attr/actionBarSize"`; content `FrameLayout @android:id/content` | `toolbar_activity.xml:9-18` |
| Title literal | **"OPML import"** (`opml_import_label`, from `android:label` on the manifest activity; `ToolbarActivity` calls `setSupportActionBar(toolbar)`) | `AndroidManifest.xml:148`, `strings.xml:674`, `ToolbarActivity.java:19` |
| Navigation | up arrow enabled (`setDisplayHomeAsUpEnabled(true)`); `android.R.id.home` → `finish()` | `OpmlImportActivity.java:67,191-193` |
| Theme | no-title theme (`ThemeSwitcher.getNoTitleTheme`) | `ToolbarActivity.java:16` |

#### B.2 `app/src/main/res/layout/opml_selection.xml` — structure

Root: **`RelativeLayout`**, match_parent × match_parent (`opml_selection.xml:2-6`). **No scroll container, no
AppBar, no empty-state view, no selection-count TextView.**

| Node | Geometry / styling | Ref |
|---|---|---|
| `Button @+id/butConfirm` | wrap_content × wrap_content, `alignParentBottom` + `alignParentRight` + `alignParentEnd`, **margin 8dp**, text = **"Confirm"** (`confirm_label`), `style="@style/Widget.MaterialComponents.Button.TextButton"` (**M2 text button**) | `opml_selection.xml:8-17`, `strings.xml:122` |
| `Button @+id/butCancel` | wrap_content × wrap_content, `alignParentBottom`, `layout_toStartOf="@+id/butConfirm"`, **margin 8dp**, text = **"Cancel"** (`cancel_label`), same M2 text-button style | `opml_selection.xml:19-28`, `strings.xml:123` |
| `ListView @+id/feedlist` | match_parent × **0dp**, `layout_alignParentTop="true"`, `layout_above="@id/butConfirm"` → fills the area above the button row; **no padding, no divider overrides, no choice-mode attrs in XML**; `tools:listitem="@android:layout/simple_list_item_multiple_choice"` | `opml_selection.xml:30-36` |
| `ProgressBar @+id/progressBar` | wrap_content × wrap_content, `layout_centerInParent="true"`; default indeterminate circular, no text | `opml_selection.xml:38-42` |
| Choice mode | set in code: `ListView.CHOICE_MODE_MULTIPLE` | `OpmlImportActivity.java:71` |

#### B.3 List rows (platform layout — **not in this repo**)

| Fact | Value | Ref |
|---|---|---|
| Adapter layout | `android.R.layout.simple_list_item_multiple_choice` (platform `CheckedTextView` with `@android:id/text1`) | `OpmlImportActivity.java:244-246` |
| Row text | `OpmlElement.getText()` (the OPML `text` attribute) | `OpmlImportActivity.java:157-165` |
| Row height / text size / check mark / padding | **platform-owned, not resolvable in this checkout** (no Android SDK installed; `android.R.layout` is not in the repo) `[platform — not verifiable here]` | — |
| Closest in-repo analogue (structure only, **used by `SelectSubscriptionActivity`, NOT by OPML**) | `simple_list_item_multiple_choice_on_start.xml`: `CheckedTextView`, `layout_height="?android:attr/listPreferredItemHeightSmall"`, `textAppearance="?android:attr/textAppearanceListItemSmall"`, `gravity="center_vertical"`, `drawableStart/Left="?android:attr/listChoiceIndicatorMultiple"`, `padding{Start,Left,End,Right}="?android:attr/listPreferredItemPadding*"`, `maxLines="2"`, `ellipsize="end"` | `simple_list_item_multiple_choice_on_start.xml:20-34`, `SelectSubscriptionActivity.java:138` |
| Fallback title when `text` is null | literal **"Unknown podcast"** (hard-coded, not a string resource) | `OpmlImportActivity.java:123` |

#### B.4 Menu — `app/src/main/res/menu/opml_selection_options.xml`

| # | id | icon | title (exact English literal) | showAsAction | declared `visible` | runtime visibility |
|---|---|---|---|---|---|---|
| 1 | `select_all_item` | — | **"Select all"** (`select_all_label`) | `never` | (unset → true) | hidden once all rows are checked |
| 2 | `deselect_all_item` | — | **"Deselect all"** (`deselect_all_label`) | `never` | (unset → true) | `setVisible(false)` at inflate; shown only when all rows are checked |

Refs: menu `opml_selection_options.xml:5-15`; ids declared `app/src/main/res/values/ids.xml:3-4`;
titles `strings.xml:678-679`; visibility logic `OpmlImportActivity.java:171-175,80-86,181-190`.
Both items are overflow-only (`showAsAction="never"`); **no icons are declared**.

#### B.5 How selection counts are shown

**They are not shown as text anywhere.** There is no counter label in `opml_selection.xml` and no
`setTitle`/`setSubtitle` call. The only feedback is the Select all / Deselect all menu-item swap:
`checkedCount == listAdapter.getCount()` → hide `select_all_item`, show `deselect_all_item`, otherwise the reverse
(`OpmlImportActivity.java:72-87,197-201`). The plural `num_selected_label` (**"%1$d/%2$d selected"**) exists
(`strings.xml:173-176`) but is used by `SelectableAdapter.java:201` (episode lists), **not by OPML**.

#### B.6 Import progress

| Aspect | Value | Ref |
|---|---|---|
| Progress UI | the in-layout indeterminate `ProgressBar` centred over the list (no dialog, no text) | `opml_selection.xml:38-42` |
| Shown during parsing | `progressBar.setVisibility(VISIBLE)` before `OpmlReader.readDocument`; GONE on success | `OpmlImportActivity.java:224,241` |
| Shown during subscription insert | VISIBLE before `FeedDatabaseWriter.updateFeed` loop + `FeedUpdateManager.runOnce`; GONE on success/error | `OpmlImportActivity.java:114,133,140` |
| Completion | starts `MainActivity` (`CLEAR_TOP \| NEW_TASK`) and finishes | `OpmlImportActivity.java:134-137` |
| Error | `Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG)` | `OpmlImportActivity.java:141` |
| **No "Please wait…" string is used here** (`please_wait` is used only by the export `ProgressDialog`, see B.8) | — | `ImportExportPreferencesFragment.java:107` |

#### B.7 Dialogs and exact string literals (OPML import)

| Trigger | Dialog | Exact strings | Ref |
|---|---|---|---|
| `uri == null` | `MaterialAlertDialogBuilder` message only, positive `android.R.string.ok` | **"No file selected!"** (`opml_import_error_no_file`) | `OpmlImportActivity.java:146-151`, `strings.xml:677` |
| Storage permission denied | `MaterialAlertDialogBuilder`, positive `android.R.string.ok` → re-request, negative `cancel_label` → `finish()` | **"Access to external storage is required to read the OPML file"** (`opml_import_ask_read_permission`) / **"Cancel"** | `OpmlImportActivity.java:211-218`, `strings.xml:691,123` |
| Parse failure | `MaterialAlertDialogBuilder`, title `error_label`, positive `android.R.string.ok` → `finish()` | title **"Error"** (`error_label`); message = **"An error has occurred while reading the file. Make sure that you have actually selected an OPML file and that the file is valid."** (`opml_reader_error`) + `"\n\n"` + `e.getMessage()`, the exception part spanned `ForegroundColorSpan(0x88888888)` | `OpmlImportActivity.java:260-270`, `strings.xml:134,676` |
| Parental control | `ParentalControlDialog.show(this, this::doImport)` when password set + require-subscribe set | (dialog lives in `:ui:preferences`, not present in this checkout) | `OpmlImportActivity.java:93-96` |
| Import exception | `Toast` with `e.getMessage()`, `LENGTH_LONG` | — | `OpmlImportActivity.java:141` |

---

### C. OPML EXPORT

#### C.1 Where it is triggered

| Fact | Value | Ref |
|---|---|---|
| Screen | Settings → **"Backup & restore"** (`import_export_pref`) — `ImportExportPreferencesFragment` | `strings.xml:455`, `ImportExportPreferencesFragment.java:113` |
| Preference | `Preference` key `prefOpmlExport`, inside `PreferenceCategory` titled **"OPML"** (`opml`) | `preferences_import_export.xml:24-28`, `strings.xml:667` |
| Preference title (exact) | **"OPML export"** (`opml_export_label`) | `preferences_import_export.xml:27`, `strings.xml:680` |
| Preference summary (exact) | **"Transfer your subscriptions to another podcast app"** (`opml_export_summary`) | `preferences_import_export.xml:28`, `strings.xml:670` |
| Click handler | `openExportPathPicker(Export.OPML, chooseOpmlExportPathLauncher)` | `ImportExportPreferencesFragment.java:125-130` |
| Picker | `Intent.ACTION_CREATE_DOCUMENT` + `CATEGORY_OPENABLE`, type **`text/x-opml`**, `EXTRA_TITLE` = **`antennapod-feeds-yyyy-MM-dd.opml`** | `ImportExportPreferencesFragment.java:67-68,186-188,285-291` |
| Fallback when no file manager | writes to `UserPreferences.getDataFolder("export/")` + same filename | `ImportExportPreferencesFragment.java:303-307` |
| Writer | `OpmlWriter.writeDocument(DBReader.getFeedList(), writer)`, UTF-8 | `ImportExportPreferencesFragment.java:358-366` |
| **No OPML export dialog, no OPML export layout, no `OpmlExport*` class exists** | the export uses the shared `ProgressDialog` + `MaterialAlertDialogBuilder` below | glob `**/Opml*.java` → only `OpmlImportActivity.java` |

#### C.2 Exact dialog / snackbar strings used by the export path

| UI | Exact literal | Ref |
|---|---|---|
| Progress dialog | `ProgressDialog` with `setIndeterminate(true)`, message = **"Please wait…"** (`please_wait`, `&#8230;` ellipsis) — shared by OPML/HTML/favorites/database export | `ImportExportPreferencesFragment.java:105-107`, `strings.xml:688` |
| Success | `Snackbar` **"Export successful"** (`export_success_title`), `LENGTH_LONG`, action label **"Share"** (`share_label`) | `ImportExportPreferencesFragment.java:228-235`, `strings.xml:690,213` |
| Error | `MaterialAlertDialogBuilder`: title **"Export error"** (`export_error_label`), message = `error.getMessage()`, positive `android.R.string.ok` | `ImportExportPreferencesFragment.java:238-245`, `strings.xml:689` |
| File-manager missing | `Snackbar` **"Unable to start system file manager"** (`unable_to_start_system_file_manager`) | `ImportExportPreferencesFragment.java:299-301`, `strings.xml:914` |
| Import-side error (shared) | title **"Import error"** (`import_error_label`) | `ImportExportPreferencesFragment.java:247-254`, `strings.xml:695` |
| Option label enum | `Export.OPML(CONTENT_TYPE_OPML, DEFAULT_OPML_OUTPUT_NAME, R.string.opml_export_label)` — `labelResId` is **assigned but never read**, so the visible label comes from the XML preference, not from this enum | `ImportExportPreferencesFragment.java:423-437` (no other `labelResId` reference) |

---

### D. Explicitly non-existent / not-in-repo items

| Item | Status |
|---|---|
| `ui/statistics/src/main/res/values/` (dimens/styles/colors/strings in the statistics module) | **does not exist** — module has only `layout/` + `menu/statistics.xml` |
| Statistics empty state / "no data" view | **does not exist** in any statistics layout |
| Legend view for the pie chart | **does not exist** — per-row `⬤` chip is the legend |
| Year selector as a dropdown/chip in the statistics toolbar | **does not exist** — the only period selector is the `Filter` dialog (A.10) |
| OPML selection counter text | **does not exist** (only the Select all / Deselect all menu swap) |
| OPML empty state | **does not exist** |
| OPML import progress dialog | **does not exist** — in-layout centred `ProgressBar` only |
| `OpmlExportActivity` / `OpmlExportFragment` / `opml_export*.xml` | **does not exist** |
| `storage/importexport` (`OpmlReader`, `OpmlWriter`, `OpmlElement`) | **not present in this checkout** |
| `gradle/libs.versions.toml` (exact Material/AppCompat versions) | **not present in this checkout** |
| Android SDK platform resources (`android.R.layout.simple_list_item_multiple_choice`, `?attr/actionBarSize`, `?android:attr/dividerVertical`, Material3 text appearances) | **not resolvable on this machine** — marked `[platform/library — not verifiable here]` |


---

## B.5 — SETTINGS / STORAGE preference screens + design tokens

Upstream source of truth: `D:\Git\antennapod-harmony\antenna-repo` (read-only), commit `d05a58b47643592e968e9d1ed55736cc822ac8f2` (2026-09-09, "Fix 3 tiny usability problems (#8727)").

All paths below are relative to `antenna-repo/`. Every claim carries `file:line`.
All `@string/...` values were resolved against `ui/i18n/src/main/res/values/strings.xml` (the only English strings file — `antenna-repo/AGENTS.md`).

> **Note on the Gradle version catalog:** the `gradle/` directory (`libs.versions.toml`) does **not exist** in this checkout, so exact library versions of `libs.google.material` / `libs.androidx.preference` cannot be resolved here. Statements marked "library default" are therefore behavioural claims about Material Components / androidx.preference, not repo-declared values.

---

### PART A — SETTINGS / STORAGE

#### A1. Complete file list: `ui/preferences/src/main/res/xml/` (12 files)

| # | File | Screen it defines | Top-level `<PreferenceScreen>` `android:title` | ActionBar title (set at runtime) |
|---|------|-------------------|-----------------------------------------------|----------------------------------|
| 1 | `preferences.xml` | Top-level settings list (root) | **none** (`preferences.xml:2-4`) | `@string/settings_label` = **"Settings"** — `app/.../MainPreferencesFragment.java:76`, `app/src/main/AndroidManifest.xml:136` |
| 2 | `preferences_user_interface.xml` | User interface | **none** (`:2-4`) | `@string/user_interface_label` = **"User interface"** — `app/.../UserInterfacePreferencesFragment.java:41` |
| 3 | `preferences_playback.xml` | Playback | **none** (`:2-3`) | `@string/playback_pref` = **"Playback"** — `app/.../PlaybackPreferencesFragment.java:35` |
| 4 | `preferences_downloads.xml` | Downloads | **none** (`:2-4`) | `@string/downloads_pref` = **"Downloads"** — `app/.../DownloadsPreferencesFragment.java:32` |
| 5 | `preferences_autodownload.xml` | Automatic download | **none** (`:2`) | `@string/pref_automatic_download_title` = **"Automatic download"** — `ui/preferences/.../AutoDownloadPreferencesFragment.java:17` |
| 6 | `preferences_auto_deletion.xml` | Automatic deletion | **none** (`:2-3`) | `@string/pref_auto_delete_title` = **"Automatic deletion"** — `ui/preferences/.../AutomaticDeletionPreferencesFragment.java:28` |
| 7 | `preferences_synchronization.xml` | Synchronization | **none** (`:2-4`) | `@string/synchronization_pref` = **"Synchronization"** — `ui/preferences/.../SynchronizationPreferencesFragment.java:56` |
| 8 | `preferences_import_export.xml` | Backup & restore (storage / import-export) | **none** (`:2-4`) | `@string/import_export_pref` = **"Backup & restore"** — `app/.../ImportExportPreferencesFragment.java:113` |
| 9 | `preferences_notifications.xml` | Notifications | **none** (`:2-3`) | `@string/notification_pref_fragment` = **"Notifications"** — `ui/preferences/.../NotificationPreferencesFragment.java:21` |
| 10 | `preferences_swipe.xml` | Swipe actions | **none** (`:2`) | `@string/swipeactions_label` = **"Swipe actions"** — `app/.../SwipePreferencesFragment.java:61` |
| 11 | `preferences_parental_control.xml` | Parental Controls | **none** (`:2`) | `@string/pref_parental_control_title` = **"Parental Controls"** — `app/.../ParentalControlPreferencesFragment.java:28` |
| 12 | `preferences_about.xml` | About | **none** (`:2-3`) | `@string/about_pref` = **"About"** — `ui/preferences/.../about/AboutFragment.java:68` |

**Important negative finding:** **no** preference XML in the repo declares a top-level `android:title` on `<PreferenceScreen>`; the screen title is always applied to the `ActionBar` by the fragment's `onStart()` (see table above). `PreferenceActivity.getTitleOfPage()` (`app/.../PreferenceActivity.java:91-116`) mirrors those strings for the back-stack label and search breadcrumbs.

---

#### A2. Per-screen ordered contents (exact English strings)

#### A2.1 `preferences.xml` — "Settings" (root list)

| # | XML line | Node | key | Title (exact) | Summary (exact) | Icon |
|---|----------|------|-----|---------------|-----------------|------|
| 0 | `:6-12` | `com.bytehamster.lib.preferencesearch.SearchPreference` | `searchPreference` | — (hint "Search…") | — | — |
| 1 | `:14-18` | `Preference` | `prefScreenInterface` | User interface | Appearance, subscriptions, lockscreen | `@drawable/ic_appearance` |
| 2 | `:20-24` | `Preference` | `prefScreenPlayback` | Playback | Headphone controls, Skip intervals, Queue | `@drawable/ic_play_24dp` |
| 3 | `:26-30` | `Preference` | `prefScreenDownloads` | Downloads | Update interval, Mobile data, Automatic download, Automatic deletion | `@drawable/ic_download` |
| 4 | `:32-36` | `Preference` | `prefScreenSynchronization` | Synchronization | Synchronize with other devices | `@drawable/ic_cloud` |
| 5 | `:38-42` | `Preference` | `prefScreenImportExport` | Backup & restore | Move subscriptions and queue to another device | `@drawable/ic_storage` |
| 6 | `:44-47` | `Preference` | `notifications` | Notifications | *(none)* | `@drawable/ic_notifications` |
| 7 | `:49-53` | `Preference` | `prefScreenParentalControl` | Parental Controls | Restrict features with a password | `@drawable/ic_supervisor_account` |
| 8 | `:55-78` | `PreferenceCategory` | `project` | **Project** | — | — |
| 8.1 | `:58-61` | `Preference` | `prefDocumentation` | Documentation & support | — | `@drawable/ic_questionmark` |
| 8.2 | `:62-65` | `Preference` | `prefViewForum` | User forum | — | `@drawable/ic_chat` |
| 8.3 | `:66-69` | `Preference` | `prefContribute` | Contribute | — | `@drawable/ic_contribute` |
| 8.4 | `:70-73` | `Preference` | `prefSendBugReport` | Report bug | — | `@drawable/ic_bug` |
| 8.5 | `:74-77` | `Preference` | `prefAbout` | About | — | `@drawable/ic_info` |

String sources: `ui/i18n/.../strings.xml:520` (`user_interface_label`), `:521` (`user_interface_sum`), `:494` (`playback_pref`), `:495` (`playback_pref_sum`), `:496` (`downloads_pref`), `:497` (`downloads_pref_sum`), `:451` (`synchronization_pref`), `:452` (`synchronization_sum`), `:455` (`import_export_pref`), `:665` (`import_export_summary`), `:38` (`notification_pref_fragment`), `:999` (`pref_parental_control_title`), `:1000` (`pref_parental_control_sum`), `:450` (`project_pref`), `:583` (`documentation_support`), `:584` (`visit_user_forum`), `:612` (`pref_contribute`), `:621` (`report_bug_title`), `:635` (`about_pref`), `:462-466` (search hints: "Search…", "No results", "Clear history", "Clear", "More").

Runtime visibility: the whole `project` category is hidden for non-official package hashes (`app/.../MainPreferencesFragment.java:50-70`); the Parental Controls row is only visible on child (Family Link) devices, debug builds, or when a password is set (`MainPreferencesFragment.java:142-149`).

#### A2.2 `preferences_user_interface.xml` — "User interface" (5 categories, 17 rows)

| Category (line) | Row (line) | Node | key | Title | Summary |
|---|---|---|---|---|---|
| **Theming** `:6` | `:7-8` | `ThemePreference` | `prefTheme` | *(custom card layout; labels "Automatic"/"Light"/"Dark")* | — |
| | `:9-13` | `SwitchPreferenceCompat` | `prefThemeBlack` | Full black | Use full black for the dark theme |
| | `:14-18` | `SwitchPreferenceCompat` | `prefTintedColors` | Dynamic colors | Adapt app colors based on the wallpaper |
| **Episode information** `:20` | `:21-26` | Switch | `prefEpisodeCover` | Use episode cover | Use the episode specific cover in lists whenever available. If unchecked, the app will always use the podcast cover image. |
| | `:27-32` | Switch | `showTimeLeft` | Show remaining time | Display remaining time of episodes when checked. If unchecked, display total duration of episodes. |
| | `:33-37` | Switch | `prefPlaybackTimeRespectsSpeed` | Adjust media info to playback speed | Displayed position and duration are adapted to playback speed |
| **External elements** `:39` | `:40-46` | Switch | `prefExpandNotify` | High notification priority | This usually expands the notification to show playback buttons. |
| | `:47-52` | Switch | `prefPersistNotify` | Persistent playback controls | Keep notification and lockscreen controls when playback is paused |
| | `:53-56` | `Preference` | `prefFullNotificationButtons` | Set notification buttons | Change the buttons on the playback notification |
| **Behavior** `:58` | `:59-65` | `MaterialListPreference` | `prefDefaultPage` | Default page | Screen that is opened when starting AntennaPod |
| | `:66-70` | Switch | `prefBottomNavigation` | Bottom navigation | Access the most important screens from everywhere, in a single tap |
| | `:71-74` | `Preference` | `prefHiddenDrawerItems` | Customize navigation | Change which items appear in the navigation drawer or bottom navigation |
| | `:75-79` | Switch | `prefBackButtonOpensDrawer` | Back button opens drawer | Pressing the back button on the default page opens the navigation drawer |
| **Episode lists** `:81` | `:82-85` | `Preference` | `prefGlobalDefaultSortedOrder` | Default sort order | Choose the default order for episodes on the podcast screen |
| | `:86-89` | `Preference` | `prefSwipe` | Swipe actions | Choose what happens when swiping an episode in a list |
| | `:90-94` | Switch | `prefStreamOverDownload` | Prefer streaming | Display stream button instead of download button in lists |
| | `:95-100` | Switch | `prefDownloadsButtonAction` | Play from downloads screen | Display play button instead of delete button on downloads screen |

String sources: `:457` `theming`, `:522` `pref_black_theme_title`, `:523` `pref_black_theme_message`, `:524` `pref_tinted_theme_title`, `:525` `pref_tinted_theme_message`, `:616` `episode_information`, `:541-544`, `:563-564`, `:458` `external_elements`, `:569-575`, `:593` `behavior`, `:595-598`, `:602-603`, `:594` `episode_lists`, `:617-618`, `:45-46` `swipeactions_label/summary`, `:512-513`, `:526-527`, `:529-530`.

Runtime: `prefTintedColors` hidden below API 31 (`UserInterfacePreferencesFragment.java:52-54`); `prefExpandNotify` hidden on API ≥ 26 (`:96-98`); `prefPersistNotify` hidden on API ≥ 30 (`:100-102`); `prefBackButtonOpensDrawer` disabled while bottom navigation is on (`:118-120`).

#### A2.3 `preferences_playback.xml` — "Playback" (4 categories, 13 rows)

| Category (line) | Row (line) | Node | key | Title | Summary |
|---|---|---|---|---|---|
| **Interruptions** `:5` | `:6-11` | Switch | `prefPauseOnHeadsetDisconnect` | Headphones or Bluetooth disconnect | Pause playback when headphones or Bluetooth devices get disconnected |
| | `:12-19` | Switch | `prefUnpauseOnHeadsetReconnect` | Headphones reconnect | Resume playback when the headphones get reconnected |
| | `:20-27` | Switch | `prefUnpauseOnBluetoothReconnect` | Bluetooth reconnect | Resume playback when bluetooth reconnects |
| **Playback control** `:30` | `:31-34` | `Preference` | `prefPlaybackFastForwardDeltaLauncher` | Fast-forward skip time | Customize the number of seconds to jump forward when the fast-forward button is clicked |
| | `:35-38` | `Preference` | `prefPlaybackRewindDeltaLauncher` | Rewind skip time | Customize the number of seconds to jump backwards when the rewind button is clicked |
| | `:39-42` | `Preference` | `prefPlaybackSpeedLauncher` | Playback speed | Customize the speeds available for variable speed playback |
| **Reassign hardware buttons** `:45` | `:46-52` | `MaterialListPreference` | `prefHardwareForwardButton` | Forward button | Customize the forward button behavior |
| | `:53-59` | `MaterialListPreference` | `prefHardwarePreviousButton` | Previous button | Customize the previous button behavior |
| **Queue** `:62` | `:63-68` | `MaterialListPreference` | `prefEnqueueLocation` | Enqueue location | Add episodes to: %1$s (runtime) |
| | `:69-74` | Switch | `prefEnqueueDownloaded` | Enqueue downloaded | Add downloaded episodes to the queue |
| | `:75-80` | Switch | `prefFollowQueue` | Continuous playback | Jump to next queue item when playback completes |
| | `:81-87` | `MaterialListPreference` | `prefSmartMarkAsPlayedSecs` | Smart mark as played | Mark episodes as played even if less than a certain amount of seconds of playing time is still left |
| | `:88-93` | Switch | `prefSkipKeepsEpisode` | Keep skipped episodes | Keep episodes when they are skipped |

String sources: `:459` `interruptions`, `:509-511`, `:469-471`, `:460` `playback_control`, `:565-568`, `:549`, `:941` `playback_speed`, `:461` `reassign_hardware_buttons`, `:472-475`, `:21` `queue_label`, `:576-577`, `:590-591`, `:508` `pref_followQueue_title`, `:480`, `:489`/`:488`, `:491`/`:490`.
Runtime: both reconnect switches hidden on API ≥ 31 (`PlaybackPreferencesFragment.java:53-56`).

#### A2.4 `preferences_downloads.xml` — "Downloads" (2 categories + 1 root row, 8 rows)

| Category (line) | Row (line) | Node | key | Title | Summary |
|---|---|---|---|---|---|
| — | `:6-8` | `Preference` | `prefChooseDataDir` | Choose data folder | *(runtime: absolute path, `DownloadsPreferencesFragment.java:73-78`)* |
| **Automation** `:10` | `:11-17` | `MaterialListPreference` | `prefAutoUpdateIntervall` | Refresh podcasts | Specify an interval at which AntennaPod looks for new episodes automatically |
| | `:18-24` | `MaterialListPreference` | `prefNewEpisodesAction` | New episodes action | Action to take for new episodes |
| | `:25-29` | `Preference` | `prefAutoDownloadSettings` | Automatic download | Configure the automatic download of episodes |
| | `:30-33` | `Preference` | `prefAutoDeleteScreen` | Automatic deletion | Delete episodes after playing or when automatic download needs space |
| | `:34-39` | Switch | `prefDeleteRemovesFromQueue` | Delete removes from queue | Automatically remove an episode from the queue when it is deleted |
| **Details** `:42` | `:43-49` | `MaterialMultiSelectListPreference` | `prefMobileUpdateTypes` | Mobile updates | Select what should be allowed over the mobile data connection |
| | `:50-53` | `Preference` | `prefProxy` | Proxy | Set a network proxy |

String sources: `:790` `choose_data_directory`, `:453` `automation`, `:498-499`, `:614-615`, `:532` `pref_automatic_download_title`, `:536` `pref_automatic_download_sum`, `:483` `pref_auto_delete_title`, `:484` `pref_auto_delete_sum`, `:600-601`, `:454` `download_pref_details`, `:514-515`, `:587-588`.

#### A2.5 `preferences_autodownload.xml` — "Automatic download" (no categories, 4 rows)

| Row (line) | Node | key | Title | Summary | default |
|---|---|---|---|---|---|
| `:4-8` | Switch | `prefEnableAutoDl` | Automatic download | Automatically download episodes from the inbox. Can be overridden per podcast. | false |
| `:9-13` | Switch | `prefEnableAutoDlQueue` | Download queued | Automatically download queued episodes | false |
| `:14-20` | `MaterialListPreference` | `prefEpisodeCacheSize` | Episode limit | Automatic download is stopped if this number is reached | `25`; entries `5,10,25,50,100,500,Unlimited` (`ui/preferences/.../arrays.xml:118-136`, `:548` `pref_episode_cache_unlimited`) |
| `:21-25` | Switch | `prefEnableAutoDownloadOnBattery` | Download when not charging | Allow automatic download when the battery is not charging | true |

String sources: `:532-540`. Entries for `prefEnableAutoDl` overridden per-feed are separate (`arrays.xml:17-28`: Global default / Enabled / Disabled).

#### A2.6 `preferences_auto_deletion.xml` — "Automatic deletion" (no categories, 4 rows)

| Row (line) | Node | key | Title | Summary | default |
|---|---|---|---|---|---|
| `:5-10` | Switch | `prefAutoDelete` | Delete after playing | Delete episode when playback completes | false |
| `:11-16` | Switch | `prefAutoDeleteLocal` | Auto delete from local folders | Also delete files added through "add local folder". Note that these are not downloaded by AntennaPod and cannot be re-downloaded | false |
| `:17-22` | Switch | `prefFavoriteKeepsEpisode` | Keep favorite episodes | Keep episodes when they are marked favorite | true |
| `:23-29` | `MaterialListPreference` | `prefEpisodeCleanup` | Delete before auto download | Episodes that should be eligible for removal if Auto Download needs space for new episodes | `-2` |

String sources: `:481-486`, `:492-493`, `:467-468`.
Runtime: `prefAutoDeleteLocal` and `prefFavoriteKeepsEpisode` are disabled unless `prefAutoDelete` is on (`AutomaticDeletionPreferencesFragment.java:31-34`); enabling `prefAutoDeleteLocal` first shows a warning dialog with body `pref_auto_local_delete_dialog_body` (`:53-63`, string `:487`). `prefEpisodeCleanup` entries are rebuilt in code (`:66-91`): "When not favorited" (`:162`), "When not in queue" (`:163`), "After finishing" (`:164`), then `1/3/5/7` days as plurals, then "Never" (`:161`).

#### A2.7 `preferences_synchronization.xml` — "Synchronization" (no categories, 5 rows)

| Row (line) | Node | key | Title | Summary | notes |
|---|---|---|---|---|---|
| `:6-8` | `Preference` | `preference_synchronization_description` | *(empty when logged in; "Choose synchronization provider" when not)* | You can choose from multiple providers to synchronize your subscriptions and episode play state with | title/summary/icon set in `SynchronizationPreferencesFragment.java:120-136`; strings `:747`, `:748` |
| `:10-14` | `Preference` | `pref_gpodnet_setlogin_information` | Change login information | Change the login information for your gpodder.net account. | `app:isPreferenceVisible="false"` in XML; shown only for GPODDER_NET (`:138-140`) |
| `:16-19` | `Preference` | `pref_synchronization_sync` | Synchronize now | Synchronize subscription and episode state changes | |
| `:21-24` | `Preference` | `pref_synchronization_force_full_sync` | Force full synchronization | Re-synchronize all subscriptions and episode states | |
| `:26-28` | `Preference` | `pref_synchronization_logout` | Logout | *(login status HTML when logged in, `:144-151`)* | |

String sources: `:748`, `:747`, `:773-779`. Provider chooser dialog: title `dialog_choose_sync_service_title` = "Choose synchronization provider" (`:749`), body `synchronization_provider_chooser_explanation` (`:753`), button `synchronization_more_information` = "More information" (`:755`), list rows = provider summaries `gpodnet_description` / `synchronization_summary_nextcloud` (`SynchronizationPreferencesFragment.java:238-247`).

#### A2.8 `preferences_import_export.xml` — "Backup & restore" (3 categories, 7 rows)

| Category (line) | Row (line) | Node | key | Title | Summary |
|---|---|---|---|---|---|
| **Database** `:6` | `:7-11` | `Preference` | `prefDatabaseExport` | Database export | Transfer subscriptions, listened episodes and queue to AntennaPod on another device |
| | `:12-16` | Switch | `prefAutomaticDatabaseExport` | Automatic database export | Create a backup of the AntennaPod database every 3 days. Only keep the 5 most recent backups. |
| | `:17-21` | `Preference` | `prefDatabaseImport` | Database import | Import AntennaPod database from another device |
| **OPML** `:24` | `:25-28` | `Preference` | `prefOpmlExport` | OPML export | Transfer your subscriptions to another podcast app |
| | `:29-32` | `Preference` | `prefOpmlImport` | OPML import | Import your subscriptions from another podcast app |
| **HTML** `:35` | `:36-39` | `Preference` | `prefHtmlExport` | HTML export | Show your subscriptions to a friend |
| | `:40-43` | `Preference` | `prefFavoritesExport` | Favorites export | Export saved favorites to file |

String sources: `:666` `database`, `:682-684`, `:686`, `:667` `opml`, `:680`, `:670`, `:674`, `:671`, `:668` `html`, `:681`, `:669`, `:696-697`. Search keywords: `import_export_search_keywords` = "import, export" (`:456`, used at `preferences_import_export.xml:9,19`).

#### A2.9 `preferences_notifications.xml` — "Notifications" (1 category, 2 rows)

| Category (line) | Row (line) | Node | key | Title | Summary |
|---|---|---|---|---|---|
| **Errors** `:5-6` | `:7-12` | Switch | `prefShowDownloadReport` | Download failed | Shown when download or feed update fails. |
| | `:13-17` | Switch | `pref_gpodnet_notifications` | Synchronization failed | Shown when gpodder synchronization fails. |

String sources: `:961` `notification_group_errors`, `:971-974`. Runtime: `pref_gpodnet_notifications` disabled unless a sync provider is connected (`NotificationPreferencesFragment.java:25`). On API ≥ 26 `PreferenceActivity.openScreen` instead launches the system app-notification settings (`PreferenceActivity.java:120-124`).

#### A2.10 `preferences_swipe.xml` — "Swipe actions" (no categories, 7 rows)

| Row (line) | key | Title | Target surface |
|---|---|---|---|
| `:4-6` | `prefSwipeQueue` | Queue | `QueueFragment` |
| `:8-10` | `prefSwipeInbox` | Inbox | `InboxFragment` |
| `:12-14` | `prefSwipeEpisodes` | Episodes | `AllEpisodesFragment` |
| `:16-18` | `prefSwipeDownloads` | Downloads | `CompletedDownloadsFragment` |
| `:20-22` | `prefSwipeHistory` | Playback history | `PlaybackHistoryFragment` |
| `:24-26` | `prefSwipeFavorites` | Favorites | `FavoritesFragment` |
| `:28-30` | `prefSwipeFeed` | Individual subscription | `FeedItemlistFragment` |

String sources: `:21`, `:23`, `:17`, `:28`, `:35`, `:25`, `:51`. Bindings: `app/.../SwipePreferencesFragment.java:28-55`.

#### A2.11 `preferences_parental_control.xml` — "Parental Controls" (no categories, 2 rows)

| Row (line) | Node | key | Title | Summary | default |
|---|---|---|---|---|---|
| `:3-6` | Switch | `prefParentalControlEnabled` | Enable | — | `android:persistent="false"` |
| `:7-11` | Switch | `prefParentalControlRequireSubscribe` | Restrict subscribing | Ask for the parental control password when subscribing to new podcasts | true |

String sources: `:1001`, `:1002`, `:1003`.

#### A2.12 `preferences_about.xml` — "About" (no categories, 5 rows)

| Row (line) | Node | key | Title | Summary | Icon |
|---|---|---|---|---|---|
| `:5-6` | `Preference` | — | *(custom layout `@layout/about_teaser`)* | — | — |
| `:7-11` | `Preference` | `about_version` | AntennaPod version | runtime `"<versionName> (<commitHash>)"`, XML placeholder `1.7.2 (asd8qs)` | `@drawable/ic_star` |
| `:12-16` | `Preference` | `about_contributors` | Contributors | Everyone can help to make AntennaPod better - with code, translations or by helping users in our forum | `@drawable/ic_contributors` |
| `:17-21` | `Preference` | `about_privacy_policy` | Privacy policy | `www.antennapod.org/privacy` (XML literal) | `@drawable/ic_policy` |
| `:22-26` | `Preference` | `about_licenses` | Licenses | AntennaPod uses other great software | `@drawable/ic_info` |

String sources: `:636-638`, `:642-644`. Runtime: version summary + click-to-copy (`AboutFragment.java:35-46`).

---

#### A3. Complete file list: `ui/preferences/src/main/res/layout/` (22 files)

| # | File | Root / view types | IDs | Explicit text sizes |
|---|------|-------------------|-----|---------------------|
| 1 | `about_teaser.xml` | `ImageView` match_parent × wrap_content, `adjustViewBounds`, `app:srcCompat="@drawable/teaser"`, `importantForAccessibility="no"` (`:2-9`) | — | — |
| 2 | `alertdialog_sync_provider_chooser.xml` | `LinearLayout` horizontal, padding 16dp; `ImageView` 48×48dp; `TextView` (`:2-27`) | `@+id/icon`, `@+id/title` | — |
| 3 | `authentication_dialog.xml` | `LinearLayout` vertical padding 16dp; 2× `TextInputLayout` (`Widget.MaterialComponents.TextInputLayout.OutlinedBox`); 2× `TextInputEditText`; `ImageView` 40×40dp (`:2-62`) | `@+id/usernameEditText`, `@+id/passwordEditText`, `@+id/showPasswordButton` | `20sp` on `showPasswordButton` (`:55`, vestigial — it is an ImageView) |
| 4 | `bug_report_fragment.xml` | `LinearLayout` → `ScrollView` → `ConstraintLayout`; `TextView`×12, `MaterialDivider`×3, `Button`×3, `ImageView`×2, `Barrier`, `Group`, `HorizontalScrollView` (`:2-320`) | `userMessageLabel`, `topDivider`, `deviceInfoGroup`, `deviceInfoImage`, `deviceInformationLabel`, `appVersionLabel`, `androidVersionLabel`, `deviceNameLabel`, `reportDetailsBarrier`, `attribAppVersionLabel`, `attribAndroidVersionLabel`, `attribDeviceNameLabel`, `middleDivider`, `crashLogGroup`, `crashLogImage`, `crashLogTitleLabel`, `expandCrashLogButton`, `crashLogMessageLabel`, `crashLogContentContainer`, `crashLogContentText`, `crashLogToggleGroup`, `copyToClipboardButton`, `openGithubButton`, `openForumButton` | `12sp` monospace on `crashLogContentText` (`:257-258`); `maxLines/minLines=4` (`:254-255`); others M3 styles: BodyMedium `:28`, TitleMedium `:70,:206`, TitleSmall `:81,:92,:103`, BodySmall `:123,:140,:157` |
| 5 | `choose_data_folder_dialog.xml` | `LinearLayout` vertical; `RecyclerView` (`:2-13`) | `@+id/recyclerView` | — |
| 6 | `choose_data_folder_dialog_entry.xml` | `RelativeLayout` margin 16dp, `?attr/selectableItemBackground`; `RadioButton` padding 4dp; `LinearLayout` vertical with 2× `TextView` + `LinearProgressIndicator` (`:2-50`) | `@+id/root`, `@+id/radio_button`, `@+id/path`, `@+id/size`, `@+id/used_space` | — |
| 7 | `dialog_switch_preference.xml` | `LinearLayout` padding 24dp; `MaterialSwitch` (`:2-15`) | `@+id/dialogSwitch` | — |
| 8 | `dialog_sync_provider_chooser.xml` | `LinearLayout` vertical; `TextView`, `MaterialButton` (`Widget.Material3.Button.TextButton`, icon `ic_open_in_new`, `iconGravity="textEnd"`, `iconPadding="4dp"`), `ListView` `divider="@null"` (`:2-34`) | `@+id/explanation`, `@+id/more_information`, `@+id/provider_list` | — |
| 9 | `gpodnetauth_credentials.xml` | `LinearLayout` vertical; 2× `TextView`, 2× `TextInputLayout` OutlinedBox + 2× `TextInputEditText`, `ProgressBar`, `TextView` error, `Button` (`:2-83`) | `@+id/createAccountWarning`, `@+id/etxtUsername`, `@+id/etxtPassword`, `@+id/progBarLogin`, `@+id/credentialsError`, `@+id/butLogin` | `@dimen/text_size_small` = **14sp** on `credentialsError` (`:70`); error color `?attr/icon_red` (`:20,:69`) |
| 10 | `gpodnetauth_device.xml` | `LinearLayout` vertical; `TextView`, `TextInputLayout`+`TextInputEditText`, `Button`, `TextView` (style `AntennaPod.TextView.Heading`), `TextView` error, `LinearLayout` container, `ProgressBar` (`:2-67`) | `@+id/deviceName`, `@+id/createDeviceButton`, `@+id/deviceSelectError`, `@+id/devicesContainer`, `@+id/progbarCreateDevice` | Heading = **22sp** (`:42` → `styles.xml:276-280`); `@dimen/text_size_small` = **14sp** on `deviceSelectError` (`:49`) |
| 11 | `gpodnetauth_device_row.xml` | `FrameLayout` paddingTop 8dp; `Button` style `?attr/materialButtonOutlinedStyle` (`:2-14`) | `@+id/selectDeviceButton` | — |
| 12 | `gpodnetauth_dialog.xml` | `ScrollView` padding 16dp `clipToPadding=false`; `ViewFlipper` with 4 `<include>` (`gpodnetauth_host`, `gpodnetauth_credentials`, `gpodnetauth_device`, `gpodnetauth_finish`) (`:2-29`) | `@+id/viewflipper` | — |
| 13 | `gpodnetauth_finish.xml` | `LinearLayout` vertical; `ImageView` 64×64dp, `TextView`, `Button` (`:2-30`) | `@id/icon`, `@+id/txtvDescription`, `@+id/butSyncNow` | — |
| 14 | `gpodnetauth_host.xml` | `LinearLayout` vertical; `TextView`, `TextInputLayout` OutlinedBox + `TextInputEditText`, `Button` (`:2-38`) | `@+id/serverUrlText`, `@+id/chooseHostButton` | — |
| 15 | `nextcloud_auth_dialog.xml` | `ScrollView` → `LinearLayout` padding 16dp; `TextView`, `TextInputLayout` + `TextInputEditText`, `LinearLayout` progress row (`ProgressBar`+`TextView`), `Button` (`:2-67`) | `@+id/serverUrlTextInput`, `@+id/serverUrlText`, `@+id/loginProgressContainer`, `@+id/chooseHostButton` | — |
| 16 | `proxy_settings.xml` | `LinearLayout` vertical padding 16dp; `TextInputLayout` `...OutlinedBox.ExposedDropdownMenu` + `AutoCompleteTextView`; 4× `TextInputLayout` OutlinedBox + `EditText`; `TextView` (`:2-100`) | `@+id/proxyTypeSpinner`, `@+id/hostText`, `@+id/portText`, `@+id/usernameText`, `@+id/passwordText`, `@+id/infoLabel` | — |
| 17 | `reorder_dialog.xml` | `RecyclerView` paddingTop `16sp` (`:2-7`) | `@+id/recyclerView` | `16sp` padding (`:6`) |
| 18 | `reorder_dialog_entry.xml` | `LinearLayout` horizontal; `ImageView` 48×40dp `src="?attr/dragview_background"`; `TextView` (`:2-30`) | `@+id/dragHandle`, `@+id/sectionLabel` | **16sp** on `sectionLabel` (`:28`) |
| 19 | `reorder_dialog_header.xml` | `LinearLayout` horizontal, `background="?attr/colorSurfaceVariant"`; `TextView` (`:2-20`) | `@+id/headerLabel` | **16sp** on `headerLabel` (`:18`) |
| 20 | `settings_activity.xml` | `androidx.fragment.app.FragmentContainerView` match_parent (`:2-6`) | `@+id/settingsContainer` | — |
| 21 | `simple_icon_list_item.xml` | `LinearLayout` horizontal padding 16dp; `ImageView` 40×40dp; `LinearLayout` vertical; 2× `TextView` (`:2-42`) | `@+id/icon`, `@+id/title`, `@+id/subtitle` | **16sp** title (`:29`), **14sp** subtitle (`:37`) |
| 22 | `theme_preference.xml` | `LinearLayout` horizontal padding 8dp, `background="?android:attr/colorBackground"`; 3× `CardView` (weight 1, `cardElevation=0dp`, `cardCornerRadius=16dp`, `contentPadding=16dp`), each with `ImageView` (`maxHeight=200dp`) + `TextView` (`:2-134`) | `@+id/themeSystemCard`, `@+id/themeLightCard`, `@+id/themeDarkCard`, `@+id/themeSystemRadio`, `@+id/themeLightRadio`, `@+id/themeDarkCardRadio` | — |

**Related layout outside this directory (used by the preference theming):** `ui/common/src/main/res/layout/preference_material_switch.xml` — a single `MaterialSwitch` with `@+id/switchWidget`, `background="@null"`, `clickable=false`, `focusable=false`; derived from androidx `preference_widget_switch_compat.xml` (`:2-10`).

---

#### A4. Preference theme / style tokens and typography

| Token | Definition | Resolved |
|---|---|---|
| `preferenceTheme` | `ui/common/src/main/res/values/styles.xml:34` (Light base), `:93` (Dark base) | `@style/AppPreferenceThemeOverlay` |
| `AppPreferenceThemeOverlay` | `styles.xml:356-358`, parent `@style/PreferenceThemeOverlay` | overrides only `switchPreferenceCompatStyle` → `@style/AppSwitchPreference` |
| `AppSwitchPreference` | `styles.xml:360-362`, parent `@style/Preference.SwitchPreferenceCompat.Material` | `widgetLayout` → `@layout/preference_material_switch` |
| `preference_material_switch` | `ui/common/src/main/res/layout/preference_material_switch.xml:3-10` | local layout (not a library layout), root = `com.google.android.material.materialswitch.MaterialSwitch` |
| `config_materialPreferenceIconSpaceReserved` | `app/src/main/res/values-sw360dp/resource-overrides.xml:3` | `false` (overrides the Material default `true`) → **no icon gutter reserved on sw360dp+ screens** |

**Typography of preference rows — library defaults, NOT overridden in this repo.** `AppPreferenceThemeOverlay` declares exactly one item (`styles.xml:357`); a grep for `textAppearanceListItem|preferenceStyle|preferenceCategoryStyle|preferenceScreenStyle` under `antenna-repo/ui` returns **no matches**, and there is **no** `textAppearanceListItem` override in `app/src/main/java` either. Therefore:

| Element | Source of size | Value |
|---|---|---|
| Preference **title** | Material3 theme `textAppearanceListItem` (library default) | Material3 `BodyLarge` = **16sp / 24sp line height** |
| Preference **summary** | Material3 theme `textAppearanceListItemSecondary` (library default) | Material3 `BodyMedium` = **14sp / 20sp line height** |
| Preference **category header** | androidx.preference `preference_category.xml` default | library default (not in repo) |
| Switch widget | `MaterialSwitch` from `preference_material_switch.xml:3-10` | library default (`Widget.Material3.CompoundButton.MaterialSwitch`) |

Material3 type-scale reference (library defaults, for cross-checking): <https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md>

**AntennaPod-owned text styles that *are* declared** (`ui/common/src/main/res/values/styles.xml:276-306`):

| Style | Parent | textSize | textColor token | maxLines / lines | lineHeight |
|---|---|---|---|---|---|
| `AntennaPod.TextView.Heading` | `@android:style/TextAppearance.Medium` (`:276`) | `@dimen/text_size_large` = **22sp** (`:277`) | `?android:attr/textColorPrimary` (`:278`) | none | none (`fontFamily=sans-serif-light`, `:279`) |
| `AntennaPod.TextView.ListItemPrimaryTitle` | `@style/TextAppearance.Material3.BodyLarge` (`:282`) | library default **16sp** | `?attr/colorOnSurface` (`:283`) | `maxLines=2`, `ellipsize=end` (`:284-285`) | `lineHeight` **20sp** + `android:lineHeight` **20sp** (`:286-287`) |
| `AntennaPod.TextView.FeedListItemPrimaryTitle` | `@style/TextAppearance.Material3.BodyLarge` (`:290`) | library default **16sp** | inherited | `maxLines=2`, `ellipsize=end` (`:291-292`) | `lineHeight` **20sp** + `android:lineHeight` **20sp** (`:293-294`) |
| `AntennaPod.TextView.ListItemSecondaryTitle` | `@style/TextAppearance.Material3.BodyMedium` (`:297`) | library default **14sp** | `?attr/colorOnSurfaceVariant` (`:298`) | `lines=1`, `ellipsize=end` (`:299-300`) | none |
| `AntennaPod.TextView.FeedListItemSecondaryTitle` | `@style/TextAppearance.Material3.LabelSmall` (`:303`) | library default **11sp** | inherited | `lines=1`, `ellipsize=end` (`:304-305`) | none |

In-repo usages of these styles: `ui/preferences/src/main/res/layout/gpodnetauth_device.xml:42` (`Heading`), `ui/discovery/src/main/res/layout/online_search_listitem.xml:41` (`ListItemPrimaryTitle`).

---

#### A5. Settings entry point

| Item | Value | Source |
|---|---|---|
| Activity | `de.danoeh.antennapod.ui.screen.preferences.PreferenceActivity` | `app/src/main/AndroidManifest.xml:132-143` |
| `android:label` | `@string/settings_label` = **"Settings"** | `AndroidManifest.xml:136`, `strings.xml:27` |
| Exported / parent | `exported="false"`; `PARENT_ACTIVITY = de.danoeh.antennapod.activity.MainActivity`; intent-filter `android.intent.action.APPLICATION_PREFERENCES` | `AndroidManifest.xml:135-142` |
| Content layout | `@layout/settings_activity` → `FragmentContainerView @+id/settingsContainer` | `PreferenceActivity.java:47-48`, `layout/settings_activity.xml:2-6` |
| Root fragment | `MainPreferencesFragment`, tag `tag_preferences` | `PreferenceActivity.java:33, 50-54` |
| Root preference XML | `R.xml.preferences` | `MainPreferencesFragment.java:41` |
| ActionBar title | `R.string.settings_label` | `MainPreferencesFragment.java:76` |
| Extras that deep-link | `OpenAutoDownloadSettings` → `preferences_autodownload`; `OpenPlaybackSettings` → `preferences_playback` | `PreferenceActivity.java:34-35, 56-61` |
| Base class | `AnimatedPreferenceFragment extends PreferenceFragmentCompat`; X-axis `MaterialSharedAxis` transitions; view background = `?attr/colorSurface` | `ui/preferences/.../AnimatedPreferenceFragment.java:12-26` |
| Search | `SearchPreference` (`com.bytehamster.lib.preferencesearch`), container `R.id.settingsContainer`, breadcrumbs enabled, indexes 9 XML files | `MainPreferencesFragment.java:151-179` |

**Row order on the top-level list (labels + icons):** User interface (`ic_appearance`) → Playback (`ic_play_24dp`) → Downloads (`ic_download`) → Synchronization (`ic_cloud`) → Backup & restore (`ic_storage`) → Notifications (`ic_notifications`) → Parental Controls (`ic_supervisor_account`) → [Category **Project**] Documentation & support (`ic_questionmark`), User forum (`ic_chat`), Contribute (`ic_contribute`), Report bug (`ic_bug`), About (`ic_info`). Sources: `preferences.xml:14-78` (in document order).

---

#### A6. Storage / data folder / automatic download / auto delete

| Surface | Exact title | Type | Source |
|---|---|---|---|
| "Data & storage" | **DOES NOT EXIST** — no such screen, string, or XML file in the repo | — | grep for `storage` in `ui/i18n/.../strings.xml` returns only `download_error_device_not_found` = "Storage Device not found" (`:330`); no `preferences_storage.xml` exists |
| Data folder row | **"Choose data folder"** (row 0 of the Downloads screen, above all categories) | `Preference`, key `prefChooseDataDir`; summary = absolute path at runtime | `preferences_downloads.xml:6-8`, `strings.xml:790`, `DownloadsPreferencesFragment.java:73-78` |
| Data folder dialog | Title **"Choose data folder"**; body "Please choose the base of your data folder. AntennaPod will create the appropriate subdirectories."; negative button "Cancel" | `MaterialAlertDialogBuilder` + `@layout/choose_data_folder_dialog` (RecyclerView of `choose_data_folder_dialog_entry` rows: radio, path, size, used-space bar) | `ui/preferences/.../downloads/ChooseDataFolderDialog.java:17-35`, `strings.xml:791` |
| Downloads screen title | **"Downloads"** | ActionBar | `DownloadsPreferencesFragment.java:32`, `strings.xml:496` |
| Downloads → **Automation** category | **"Automation"** (rows: Refresh podcasts, New episodes action, Automatic download, Automatic deletion, Delete removes from queue) | `PreferenceCategory` | `preferences_downloads.xml:10-40`, `strings.xml:453` |
| Downloads → **Details** category | **"Details"** (rows: Mobile updates, Proxy) | `PreferenceCategory` | `preferences_downloads.xml:42-54`, `strings.xml:454` |
| Automatic download screen | **"Automatic download"** — rows: "Automatic download", "Download queued", "Episode limit", "Download when not charging" | `preferences_autodownload.xml:4-25` | `strings.xml:532,534,539,537`; ActionBar `AutoDownloadPreferencesFragment.java:17` |
| Automatic deletion screen | **"Automatic deletion"** — rows: "Delete after playing", "Auto delete from local folders", "Keep favorite episodes", "Delete before auto download" | `preferences_auto_deletion.xml:5-29` | `strings.xml:482,485,493,467`; ActionBar `AutomaticDeletionPreferencesFragment.java:28` |
| Backup & restore (storage-ish) | **"Backup & restore"** with categories "Database", "OPML", "HTML" | `preferences_import_export.xml` | `strings.xml:455,666,667,668` |
| Import/export summary on root list | "Move subscriptions and queue to another device" | `preferences.xml:41` | `strings.xml:665` |

---

#### A7. Part A — explicit negative findings (do NOT invent)

- **No** `preferences_storage.xml`, no "Data & storage" string, no "Storage" settings screen.
- **No** top-level "Statistics" entry in Settings. `statistics_label` exists only as a default-page option (`arrays.xml:280`).
- **No** top-level "Network" screen. Network settings live as the "Details" category inside Downloads (`preferences_downloads.xml:42-54`: Mobile updates, Proxy).
- **No** top-level "Automation" screen. "Automation" is a category inside Downloads (`preferences_downloads.xml:10`).
- **No** top-level "Downloads" *category* — Downloads is a single row that opens `preferences_downloads.xml`.
- **No** `app/src/main/res/values/colors.xml`, no `themes*.xml`, no `attrs*.xml` under `app/` (glob over `antenna-repo/**` returns exactly one `colors.xml`, one `attrs.xml`, and `styles.xml` only in `ui/common/src/main/res/values{,-v27}/`).
- **No** `values-night/` color or style overrides.
- **No** `<PreferenceScreen android:title>` literal in any of the 12 preference XML files.
- `preferences_about.xml:11` and `:20` contain **hard-coded English literals** (`1.7.2 (asd8qs)`, `www.antennapod.org/privacy`) — the first is replaced at runtime (`AboutFragment.java:35-36`), the second is not.

---

### PART B — DESIGN TOKENS

#### B1. Colour resources — `ui/common/src/main/res/values/colors.xml` (only colours.xml in the repo, 24 entries)

| Token | Line | Resolved hex | Light / Dark / TrueBlack role | Representative usage |
|---|---|---|---|---|
| `white` | `:4` | `#FFFFFF` | all | `colorOnPrimary` (`styles.xml:40`), `colorOnSurface` dark (`:108`), `action_icon_color` dark (`:75`) |
| `grey100` | `:5` | `#F5F5F5` | both | `ui/common/.../drawable/ic_shortcut_background.xml:6`; `app/.../drawable-anydpi-v26/ic_shortcut_{feed,subscriptions,refresh,playlist}.xml:3` |
| `grey600` | `:6` | `#757575` | Light | `android:statusBarColor` + `android:navigationBarColor` of `Theme.AntennaPod.Dynamic.Light` (`styles.xml:8-9`) |
| `light_gray` | `:7` | `#BFBFBF` | both | `ui/common/.../ImagePlaceholder.java:14`; `ui/statistics/.../StatisticsListAdapter.java:65-66`; `app/.../feeditemlist_item.xml:67` |
| `medium_gray` | `:8` | `#AFAFAF` | both | `app/.../episodeslist/EpisodeItemViewHolder.java:218`, `app/.../subscriptions/HorizontalFeedListAdapter.java:71` |
| `black` | `:9` | `#000000` | Light + TrueBlack | `colorOnPrimary` light (`:40`), `action_icon_color` light (`:19`), TrueBlack `colorSurface`/`background_color`/`background_elevated` (`:130-132`) |
| `image_readability_tint` | `:10` | `#80000000` (50% black) | both | `app/.../feedinfo.xml:27,103`, `feeditemlist_header.xml:23`, `feed_item_list_fragment.xml:27`, `horizontal_itemlist_item.xml:43` |
| `feed_text_bg` | `:11` | `#55333333` (33% `#333333`) | both | `app/.../subscription_grid_item.xml:59`, `subscription_list_item.xml:46` |
| `background_light` | `:14` | `#F9FCFF` | **Light** surface | `background_color` (`:16`), `colorSurface` (`:48`), `android:colorBackground` (`:47`) |
| `background_elevated_light` | `:15` | `#EFEEEE` | **Light** elevated | `background_elevated` (`:18`) |
| `background_darktheme` | `:16` | `#21272B` | **Dark** surface | `background_color` (`:73`), `colorSurface` (`:107`), `android:colorBackground` (`:106`) |
| `background_elevated_darktheme` | `:17` | `#2D3337` | **Dark** elevated | `background_elevated` (`:74`) |
| `non_square_icon_background` | `:18` | `#22777777` (13% `#777777`) | both | `app/.../external_player_fragment.xml:26`, `feeditemlist_header.xml:111`, `feeditemlist_item.xml:52`, `horizontal_feed_item.xml:17`, `subscription_grid_item.xml:31`, `subscription_list_item.xml:18` |
| `seek_background_light` | `:19` | `#90000000` (56% black) | **Light** | `seek_background` (`:21`); used at `app/src/main/res/layout/audioplayer_fragment.xml:61` |
| `seek_background_dark` | `:20` | `#905B5B5B` (56% `#5B5B5B`) | **Dark** | `seek_background` (`:78`); used at `app/src/main/res/layout/video_player_controls.xml:97` |
| `text_color_secondary_light` | `:21` | `#444444` | **Light** secondary text | `colorOnSurfaceVariant` (`:52`), `colorOutline`/`colorOutlineVariant` (`:59-60`), `android:textColorSecondary`/`Tertiary` (`:57-58`) |
| `text_color_secondary_dark` | `:22` | `#CCCCCC` | **Dark** secondary text | `colorOnSurfaceVariant` (`:111`), `colorOutline`/`colorOutlineVariant` (`:118-119`), `android:textColorSecondary`/`Tertiary` (`:116-117`) |
| `color_surface_variant_light` | `:23` | `#D3DCE0` | **Light** | `colorSurfaceVariant` (`:51`), `colorSurfaceContainerHigh/Low/Lowest` (`:61,63,64`) |
| `color_surface_variant_dark` | `:24` | `#2F3B4F` | **Dark** | `colorSurfaceVariant` (`:110`), `colorSurfaceContainerHigh/Low/Lowest` (`:120,122,123`) |
| `color_secondary_container_light` | `:25` | `#C8D8DE` | **Light** | `colorSecondaryContainer` (`:54`) |
| `color_secondary_container_dark` | `:26` | `#3C4E68` | **Dark** | `colorSecondaryContainer` (`:113`) |
| `accent_light` | `:28` | `#0078C2` | **Light** accent | `colorPrimary`, `colorAccent`, `colorSecondary`, `colorPrimaryDark` (`:39,41,42,44`) |
| `accent_dark` | `:29` | `#3D8BFF` | **Dark** accent | `colorPrimary`, `colorAccent`, `colorSecondary`, `colorPrimaryDark` (`:98,100,101,103`) |
| `gradient_000` | `:31` | `#364FF3` | both | Echo background gradient start (`ui/echo/.../background/BaseBackground.java`) |
| `gradient_025` | `:32` | `#2E6FF6` | both | gradient |
| `gradient_075` | `:33` | `#1EB0FC` | both | gradient |
| `gradient_100` | `:34` | `#16D0FF` | both | `ui/echo/.../background/BaseBackground.java:27` (gradient end) |

#### B2. Custom attribute tokens → per-theme resolved value

Attribute declarations: `ui/common/src/main/res/values/attrs.xml:3-13`. Resolution mechanism: `ui/common/src/main/java/de/danoeh/antennapod/ui/common/ThemeUtils.java:15-28` (`resolveAttribute(attr, …, resolveRefs=true)`).

| Attr | Format | Light (`Theme.AntennaPod.Light`) | Dark (`Theme.AntennaPod.Dark`) | TrueBlack (`Theme.AntennaPod.TrueBlack`) | Where used |
|---|---|---|---|---|---|
| `background_color` | color (`attrs.xml:6`) | `@color/background_light` = **`#F9FCFF`** (`styles.xml:16`) | `@color/background_darktheme` = **`#21272B`** (`:73`) | `@color/black` = **`#000000`** (`:131`) | `ic_rounded_corner_left.xml:6`, `ic_rounded_corner_right.xml:6`, `app/.../swipeactions_row.xml:56` |
| `background_elevated` | color (`attrs.xml:7`) | `@color/background_elevated_light` = **`#EFEEEE`** (`:18`) | `@color/background_elevated_darktheme` = **`#2D3337`** (`:74`) | `@color/black` = **`#000000`** (`:132`) | `app/.../swipeactions_row.xml:73` |
| `action_icon_color` | color (`attrs.xml:4`) | `@color/black` = **`#000000`** (`:19`), overridden to `?attr/colorOnSurface` inside toolbars (`:272`) | `@color/white` = **`#FFFFFF`** (`:75`), toolbar override `?attr/colorOnSurface` (`:272`) | inherits Dark = **`#FFFFFF`** | ~70 vector drawables in `ui/common/.../drawable/` (e.g. `ic_settings.xml:4`, `ic_download.xml:7`, `ic_appearance.xml:4`); `app/.../audioplayer_fragment.xml:167,219`, `secondary_action.xml:29` |
| `seek_background` | color (`attrs.xml:8`) | `@color/seek_background_light` = **`#90000000`** (`:21`) | `@color/seek_background_dark` = **`#905B5B5B`** (`:78`) | inherits Dark = **`#905B5B5B`** | `app/.../audioplayer_fragment.xml:61`, `video_player_controls.xml:97` |
| `icon_red` | color (`attrs.xml:9`) | **`#CF1800`** (`:24`) | **`#CF1800`** (`:81`) | inherits Dark | `ic_error.xml:10`, `bg_message_error.xml:6,13`, `preferences/.../gpodnetauth_credentials.xml:20,69`, `gpodnetauth_device.xml:48,64`, `app/.../downloadlog_item.xml:63`, `feeditemlist_header.xml:173` |
| `icon_yellow` | color (`attrs.xml:10`) | **`#F59F00`** (`:25`) | **`#F59F00`** (`:82`) | inherits Dark | icon tinting |
| `icon_green` | color (`attrs.xml:11`) | **`#008537`** (`:26`) | **`#008537`** (`:83`) | inherits Dark | icon tinting |
| `icon_purple` | color (`attrs.xml:12`) | **`#5F1984`** (`:27`) | **`#AA55D8`** (`:84`) | inherits Dark | icon tinting |
| `icon_gray` | color (`attrs.xml:13`) | **`#25365A`** (`:28`) | **`#CDD9E4`** (`:85`) | inherits Dark | icon tinting |
| `dragview_background` | reference (`attrs.xml:3`) | `@drawable/ic_drag_lighttheme` (`:22`) → fill **`#9D9D9D`** (`ic_drag_lighttheme.xml:8`), 20×30dp | `@drawable/ic_drag_darktheme` (`:79`) → fill **`#A9A9A9`** (`ic_drag_darktheme.xml:8`) | inherits Dark | `preferences/.../reorder_dialog_entry.xml:18`, `app/.../feeditemlist_item.xml:41` |
| `scrollbar_thumb` | reference (`attrs.xml:5`) | `@drawable/scrollbar_thumb_light` (`:23`) → selector: pressed `scrollbar_thumb_pressed_light`, else `scrollbar_thumb_default` (`scrollbar_thumb_light.xml:3-4`) | `@drawable/scrollbar_thumb_dark` (`:80`) → pressed `scrollbar_thumb_pressed_dark`, else `scrollbar_thumb_default` (`scrollbar_thumb_dark.xml:3-4`) | inherits Dark | `styles.xml:315,317` (`FastScrollRecyclerView`) |

**`button_bg_selector`** (`ui/common/src/main/res/color/button_bg_selector.xml:2-6`) — colour state list, not a plain colour:

| State | Value | Source |
|---|---|---|
| `state_checked="true"` | `?attr/colorPrimary` at `android:alpha="0.3"` (Material default is 0.08; the file comments the deliberate difference at `:3`) | `button_bg_selector.xml:4` |
| `state_checked="false"` | `@android:color/transparent` | `button_bg_selector.xml:5` |

Used as `backgroundTint` of `OutlinedButtonBetterContrast` (`styles.xml:308-310`), parent `Widget.Material3.Button.OutlinedButton`.

#### B3. Material3 theme values per theme

Themes are defined in `ui/common/src/main/res/values/styles.xml` (no `themes.xml` file exists). Inheritance: `Theme.AntennaPod.Dynamic.Light` ← `Theme.Base.AntennaPod.Dynamic.Light` ← `Theme.Material3.DynamicColors.Light` (`:4-35`); `Theme.AntennaPod.Light` ← `Theme.AntennaPod.Dynamic.Light` (`:37-65`); `Theme.AntennaPod.Dynamic.Dark` ← `Theme.Base.AntennaPod.Dynamic.Dark` ← `Theme.Material3.DynamicColors.Dark` (`:67-94`); `Theme.AntennaPod.Dark` ← `Theme.AntennaPod.Dynamic.Dark` (`:96-124`); `Theme.AntennaPod.Dynamic.TrueBlack` ← `Theme.AntennaPod.Dynamic.Dark` (`:126-133`); `Theme.AntennaPod.TrueBlack` ← `Theme.AntennaPod.Dark` (`:135-144`).

| Attribute | Light (`:39-64`) | Dark (`:98-123`) | TrueBlack (`:135-144`) |
|---|---|---|---|
| `colorPrimary` | `@color/accent_light` = **`#0078C2`** | `@color/accent_dark` = **`#3D8BFF`** | inherits Dark = **`#3D8BFF`** |
| `colorOnPrimary` | `@color/white` = **`#FFFFFF`** | `@color/black` = **`#000000`** | inherits Dark = **`#000000`** |
| `colorSecondary` | **`#0078C2`** | **`#3D8BFF`** | inherits Dark |
| `colorOnSecondary` | **`#FFFFFF`** | **`#000000`** | inherits Dark |
| `colorAccent` / `colorPrimaryDark` | **`#0078C2`** | **`#3D8BFF`** | inherits Dark |
| `colorSurface` | `@color/background_light` = **`#F9FCFF`** | `@color/background_darktheme` = **`#21272B`** | `@color/black` = **`#000000`** |
| `colorOnSurface` | `@color/black` = **`#000000`** | `@color/white` = **`#FFFFFF`** | inherits Dark |
| `colorSurfaceVariant` | `@color/color_surface_variant_light` = **`#D3DCE0`** | `@color/color_surface_variant_dark` = **`#2F3B4F`** | inherits Dark |
| `colorOnSurfaceVariant` | `@color/text_color_secondary_light` = **`#444444`** | `@color/text_color_secondary_dark` = **`#CCCCCC`** | inherits Dark |
| `colorSurfaceContainer` | literal **`#EBEEF3`** | literal **`#1C2024`** | inherits Dark |
| `colorSurfaceContainerHigh` | `@color/color_surface_variant_light` = **`#D3DCE0`** | `@color/color_surface_variant_dark` = **`#2F3B4F`** | inherits Dark |
| `colorSurfaceContainerHighest` | literal **`#C0CFD3`** | literal **`#38455C`** | inherits Dark |
| `colorSurfaceContainerLow` | `@color/color_surface_variant_light` = **`#D3DCE0`** | `@color/color_surface_variant_dark` = **`#2F3B4F`** | inherits Dark |
| `colorSurfaceContainerLowest` | `@color/color_surface_variant_light` = **`#D3DCE0`** | `@color/color_surface_variant_dark` = **`#2F3B4F`** | inherits Dark |
| `colorSecondaryContainer` | `@color/color_secondary_container_light` = **`#C8D8DE`** | `@color/color_secondary_container_dark` = **`#3C4E68`** | inherits Dark |
| `colorOnSecondaryContainer` | **`#000000`** | **`#FFFFFF`** | inherits Dark |
| `colorOutline` | `@color/text_color_secondary_light` = **`#444444`** | `@color/text_color_secondary_dark` = **`#CCCCCC`** | inherits Dark |
| `colorOutlineVariant` | **`#444444`** | **`#CCCCCC`** | inherits Dark |
| `colorPrimaryContainer` | literal **`#D6E6F3`** | literal **`#29374E`** | literal **`#0D182B`** (`:142`) |
| `colorOnPrimaryContainer` | **`#000000`** | **`#FFFFFF`** | **`#FFFFFF`** (`:143`) |
| `android:colorBackground` | `@color/background_light` = **`#F9FCFF`** | `@color/background_darktheme` = **`#21272B`** | `@color/black` = **`#000000`** |
| `android:textColorPrimary` | **`#000000`** | **`#FFFFFF`** | **`#FFFFFF`** |
| `android:textColorSecondary` / `Tertiary` | **`#444444`** | **`#CCCCCC`** | inherits Dark |
| `isMaterial3DynamicColorApplied` | `false` (`:38`) | `false` (`:97`) | inherited from `Theme.AntennaPod.Dark` = `false` |

Notes:
- **Dynamic (`*Dynamic*`) variants**: `Theme.AntennaPod.Dynamic.Light` / `.Dynamic.Dark` do **not** pin `colorPrimary` etc.; those come from `Theme.Material3.DynamicColors.*` (wallpaper-derived, API 31+). They still pin the AntennaPod-specific attrs (`background_color`, `background_elevated`, `seek_background`, `icon_*`, `dragview_background`, `scrollbar_thumb`, `preferenceTheme`). `Theme.AntennaPod.Dynamic.TrueBlack:126-133` pins `android:colorBackground`, `colorSurface`, `background_color`, `background_elevated` all to `@color/black` (`#000000`).
- **Status bar / navigation bar**: Light dynamic theme = `@color/grey600` = **`#757575`** for both (`styles.xml:8-9`); Dark = `@android:color/transparent` (`:88,91`); `values-v27/styles.xml:3-5` adds `android:windowLightNavigationBar=true` for Light only.
- **TrueBlack** does **not** override `colorSurfaceContainer*`, `colorSurfaceVariant`, `colorSecondaryContainer`, `colorOutline*`, `colorOnSurfaceVariant`, `colorPrimary`, `colorSecondary` — they all fall through to `Theme.AntennaPod.Dark`.
- Other AntennaPod theme attrs: `linearProgressIndicatorStyle` → `@style/Widget.AntennaPod.LinearProgressIndicator` with `trackColor = #55888888` (`styles.xml:321-323`); `actionBarStyle` → `@style/Widget.AntennaPod.ActionBar`, `background=?android:attr/colorBackground`, `elevation=0dp` (`:325-328`); `toolbarStyle` → `@style/Style.AntennaPod.Toolbar` → `materialThemeOverlay=@style/Theme.AntennaPod.Toolbar` → `action_icon_color=?attr/colorOnSurface`, `colorControlNormal=?attr/colorOnSurface` (`:267-274`); `android:textAllCaps=false` (`:20,77`); `android:splitMotionEvents=false` (`:29,86`); `android:fitsSystemWindows=false` (`:30,87`); `android:windowContentTransitions=true` (`:31,90`).

#### B4. Dimension tokens

#### B4.1 `ui/common/src/main/res/values/dimens.xml` (all 19 entries)

| Name | Value | Line |
|---|---|---|
| `external_player_height` | 64dp | `:3` |
| `text_size_micro` | 12sp | `:4` |
| `text_size_small` | 14sp | `:5` |
| `text_size_navdrawer` | 16sp | `:6` |
| `text_size_large` | 22sp | `:7` |
| `thumbnail_length_itemlist` | 56dp | `:8` |
| `thumbnail_length_queue_item` | 56dp | `:9` |
| `thumbnail_length_navlist` | 40dp | `:10` |
| `listitem_iconwithtext_height` | 48dp | `:11` |
| `listitem_iconwithtext_textleftpadding` | 16dp | `:12` |
| `listitem_threeline_textleftpadding` | 16dp | `:14` |
| `listitem_threeline_textrightpadding` | 8dp | `:15` |
| `listitem_threeline_verticalpadding` | 11dp | `:16` |
| `list_vertical_padding` | 8dp | `:18` |
| `listitem_icon_leftpadding` | 16dp | `:19` |
| `audioplayer_playercontrols_length` | 48dp | `:21` |
| `audioplayer_playercontrols_length_big` | 64dp | `:22` |
| `audioplayer_playercontrols_margin` | 12dp | `:23` |
| `nav_drawer_max_screen_size` | 480dp | `:25` |

#### B4.2 `app/src/main/res/values/dimens.xml` (3 entries) + qualifier overrides

| Name | Default (`values/dimens.xml`) | `values-w1000dp` | `values-w300dp` | Note |
|---|---|---|---|---|
| `additional_horizontal_spacing` | **0dp** (`:3`) | **56dp** (`values-w1000dp/dimens.xml:3`) | **0dp** (`values-w300dp/dimens.xml:3`) | |
| `drawer_corner_size` | **16dp** (`:5`) | — | — | comment: should match `@dimen/m3_navigation_drawer_layout_corner_size` (`:4`) |
| `floating_select_menu_height` | **112dp** (`:6`) | — | — | |
| `sd_label_max_width` | *(not defined in `values/`)* | — | **240dp** (`values-w300dp/dimens.xml:10`) | overrides the FAB library default; `tools:ignore="MissingDefaultResource, UnusedResources"` |

Other qualifier files:
- `app/src/main/res/values-sw360dp/resource-overrides.xml:3` — `<bool name="config_materialPreferenceIconSpaceReserved" tools:override="true">false</bool>` (preference rows lose the icon gutter).
- `app/src/main/res/values-sw600dp/integers.xml:3` — `<integer name="subscriptions_default_num_of_columns">5</integer>` (not a dimen).
- **No `values-sw360dp/dimens.xml`, no `values-sw600dp/dimens.xml`** exist.
- `ui/widget/src/main/res/values/dimens.xml:3-5` — `widget_margin` 0dp, `widget_inner_radius` 4dp, `widget_cover_large` 72dp.

#### B5. Other numeric style tokens (for completeness)

| Token | Value | Source |
|---|---|---|
| `AddPodcastTextView` | parent `TextAppearance.Material3.BodyMedium`; drawablePadding 8dp; paddingTop/Bottom 8dp; paddingStart/End 16dp; minHeight 48dp | `styles.xml:330-341` |
| `TextPill` | background `@drawable/bg_pill_translucent`; margin 8dp; textColor `@color/white`; paddingStart/End 8dp | `styles.xml:343-350` |
| `TextBottomNav` | parent `TextAppearance.Material3.TitleSmall`; textSize **11sp** | `styles.xml:352-354` |
| `Widget.AntennaPod.LinearProgressIndicator` | parent `Widget.Material3.LinearProgressIndicator`; trackColor **`#55888888`** | `styles.xml:321-323` |
| `Theme.AntennaPod.Splash` | parent `Theme.SplashScreen`; `windowSplashScreenAnimatedIcon=@drawable/launcher_animate`; status/nav bars transparent | `styles.xml:247-257` |

---

#### B6. Part B — explicit negative findings

- There is exactly **one** `colors.xml` in the whole repo: `ui/common/src/main/res/values/colors.xml`. **`app/src/main/res/values/colors.xml` does not exist** (the only files in `app/src/main/res/values/` are `design_time_attributes.xml`, `dimens.xml`, `ids.xml`, `integers.xml`, `svg.xml`).
- There is **no** `themes.xml` / `themes*.xml` anywhere in the repo; all themes live in `ui/common/src/main/res/values/styles.xml` (+ `values-v27/styles.xml`).
- There is **no** `app/src/main/res/values/attrs.xml`; the only `attrs*.xml` is `ui/common/src/main/res/values/attrs.xml`.
- There are **no** `values-night/` overrides, so light/dark switching is done exclusively via the six theme parents listed in B3.
- `icon_red`, `icon_yellow`, `icon_green` are **identical** in Light and Dark; only `icon_purple` (`#5F1984` → `#AA55D8`) and `icon_gray` (`#25365A` → `#CDD9E4`) differ.
- `seek_background_light` and `seek_background_dark` are the **only** seek tokens; there is no `seek_background_trueblack` — TrueBlack inherits `#905B5B5B`.
- Preference **title/summary text sizes are library defaults** (M3 BodyLarge 16sp / BodyMedium 14sp); the repo overrides only `switchPreferenceCompatStyle` in `AppPreferenceThemeOverlay` (`styles.xml:356-358`).
