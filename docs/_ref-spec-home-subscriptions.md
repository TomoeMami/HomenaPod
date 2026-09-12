# AntennaPod Android layout reference spec — HOME + SUBSCRIPTIONS

Source: read-only shallow clone at `antenna-repo/`, `app/build.gradle` `versionName "3.12.1"` / `versionCode 3120195`.
Every number below is taken from the files listed at the end. Values marked **(M3 lib)** come from the Material Components library default style (not defined inside this repo) and are approximate visual metrics; everything else is explicit in-repo.

Units: `dp` / `sp` as written in the sources. `1px` = 1 physical pixel (used deliberately in a few CardView insets).

---

## 0. Color / style tokens used by these two screens

| Token | Where used | Resolves to (from `ui/common/src/main/res/values/colors.xml`, `styles.xml`) |
| --- | --- | --- |
| `?attr/colorSurfaceContainer` | `horizontal_itemlist_item` card bg; `subscription_grid_item` outer card bg (set in code); AppBar lifted bg | light `#EBEEF3`; dark `#1C2024` (styles.xml:53 / :112) |
| `?attr/colorSecondaryContainer` | `horizontal_itemlist_item` card bg when that episode is *currently playing* | light `@color/color_secondary_container_light` `#C8D8DE`; dark `@color/color_secondary_container_dark` `#3C4E68` |
| `?attr/colorPrimary` | count-pill border/text (`bg_pill`), `bg_circle` fill | light `@color/accent_light` `#0078C2`; dark `@color/accent_dark` `#3D8BFF` |
| `?attr/colorOnPrimary` | play button tint + circular progress foreground | light `@color/white` `#FFFFFF`; dark `@color/black` `#000000` |
| `@color/non_square_icon_background` | `horizontal_feed_item` card, `subscription_grid_item` inner card, `subscription_list_item` card, `feeditemlist_item` cover holder | `#22777777` (13% alpha grey) |
| `@color/feed_text_bg` | fallback title text bg (grid + list item) | `#55333333` (33% alpha dark grey) |
| `@color/image_readability_tint` | 128dp FrameLayout bg behind the horizontal card cover | `#80000000` (50% black) |
| `@color/white` | `TextPill` text color | `#FFFFFF` |
| `#D2404040` | `bg_pill_translucent` solid (count pill in grid) | hard-coded in drawable |
| `?android:attr/textColorPrimary` | section titles, welcome texts, item titles | light `@color/black`; dark `@color/white` |
| `?attr/colorOnSurfaceVariant` | date label (`AntennaPod.TextView.ListItemSecondaryTitle`) | light `@color/text_color_secondary_light` `#444444`; dark `@color/text_color_secondary_dark` `#cccccc` |
| `?attr/colorOnSurface` | list-item title (`AntennaPod.TextView.ListItemPrimaryTitle`) | light `@color/black`; dark `@color/white` |
| `?android:attr/textColorTertiary` | list-item count text (`subscription_list_item`) | light `#444444`; dark `#cccccc` |
| `@color/light_gray` / `@color/medium_gray` | Glide placeholder / dummy cover in `horizontal_feed_item` | `#bfbfbf` / `#afafaf` |
| `@color/gradient_075` → `@color/gradient_025` | `bg_blue_gradient` (Echo card, 90° linear) | `#1EB0FC` → `#2E6FF6` |
| window background | both screens' scroll background (no explicit bg set) | `colorSurface` = `@color/background_light` `#f9fcff` / `@color/background_darktheme` `#21272b` |

Relevant styles (`ui/common/src/main/res/values/styles.xml`):

| Style | Definition |
| --- | --- |
| `AntennaPod.TextView.ListItemPrimaryTitle` | parent `TextAppearance.Material3.BodyLarge`, textColor `?attr/colorOnSurface`, maxLines 2, ellipsize end, lineHeight 20sp |
| `AntennaPod.TextView.ListItemSecondaryTitle` | parent `TextAppearance.Material3.BodyMedium`, textColor `?attr/colorOnSurfaceVariant`, lines 1, ellipsize end |
| `TextPill` | bg `@drawable/bg_pill_translucent`, layout_margin 8dp, textColor `@color/white`, textAlignment center, paddingStart 8dp, paddingEnd 8dp |
| `bg_pill` (drawable) | 1dp stroke `?attr/colorPrimary`, corners 20dp |
| `bg_pill_translucent` (drawable) | solid `#D2404040`, corners 18dp |
| `bg_circle` (drawable) | solid `?attr/colorPrimary`, corners 30dp, intrinsic size 60×60dp |
| `Widget.AntennaPod.LinearProgressIndicator` | parent `Widget.Material3.LinearProgressIndicator`, trackColor `#55888888` |
| `TextAppearance.Material3.TitleMedium` **(M3 lib)** | ≈16sp medium — used by section title + count pill |
| `Widget.Material3.Button.TextButton` **(M3 lib)** | ≈14sp label, no bg — used by section "more" button |
| `Widget.Material3.Chip.Filter` **(M3 lib)** | ≈32dp height, 8dp corner radius, 14sp label, checkable — tag chips |

Icon drawables used (all 24dp vectors unless noted): `ic_search`, `ic_settings`, `ic_add`, `ic_shuffle`, `ic_arrow_right_white`, `ic_cancel`, `ic_error`, `ic_subscriptions`, `ic_play_24dp`, `circle_checked`, `circle_unchecked`, `ic_curved_arrow`.

---

# A. HOME (`HomeFragment`, `home_fragment.xml`)

## A1. Toolbar

| Property | Value |
| --- | --- |
| Container | `AppBarLayout` id `appbar`, `wrap_content`, `fitsSystemWindows=true`, **elevation 0dp** |
| Toolbar | `MaterialToolbar` id `toolbar`, height `?attr/actionBarSize` = **56dp** (M3 default; not overridden anywhere in repo) |
| Title string | `@string/home_label` = **"Home"** |
| Navigation icon | none in XML; `MainActivity.setupToolbarToggle(toolbar, displayUpArrow)` adds hamburger (drawer) or back arrow at runtime |
| Lifted state | `LiftOnScrollListener(appbar)` animates the AppBar background from transparent to `?attr/colorSurfaceContainer` when the NestedScrollView `scrollY != 0` |

Menu `app/src/main/res/menu/home.xml`, inflated in `onCreateView`, declaration order:

| # | id | Title string | Icon | showAsAction | Click action |
| --- | --- | --- | --- | --- | --- |
| 1 | `action_search` | "Search" (`search_label`) | `ic_search` | **always** | `loadChildFragment(SearchFragment.newInstance())` |
| 2 | `refresh_item` | "Refresh" (`refresh_label`) | — | never (`menuCategory=container`) | `FeedUpdateManager.runOnceOrAsk()` |
| 3 | `homesettings_items` | "Configure home screen" (`configure_home`) | `ic_settings` | never (`menuCategory=container`) | `HomeSectionsSettingsDialog(...).show()` → on close `populateSectionList()` |

Overflow order = declaration order: Refresh, then Configure home screen.

## A2. Scroll container

| Property | Value |
| --- | --- |
| Root | vertical `LinearLayout` (match/match) → `AppBarLayout` + `welcomeContainer` + `SwipeRefreshLayout` |
| Swipe-to-refresh | **Yes** — `SwipeRefreshLayout` id `swipeRefresh`, match/match, `setDistanceToTriggerSync(R.integer.swipe_refresh_distance = 300)`, listener → `FeedUpdateManager.runOnceOrAsk()`; refreshing state bound to sticky `FeedUpdateRunningEvent` |
| Scroller | `NestedScrollView` id `homeScrollView`, match_parent × wrap_content |
| Content | `LinearLayout` id `homeContainer`, vertical, match_parent × wrap_content, **paddingBottom 12dp**, no horizontal padding |
| Background | none set → theme window background (`colorSurface`) |
| Section spacing | each section root adds **paddingTop 8dp + paddingBottom 4dp**; section title adds marginVertical 4dp ⇒ 16dp between a section's card row and the next section's title; 12dp between the rows themselves |
| Welcome screen | `RelativeLayout` id `welcomeContainer`, `gone` unless total episode count == 0; paddingHorizontal **32dp**; icon 64×64dp (top margin 48dp, bottom 16dp, `@mipmap/ic_launcher`); title "Welcome to AntennaPod!" 20sp; body "You are not subscribed to any podcasts yet. Open the menu to add a podcast." 14sp; optional 80×80dp `ic_curved_arrow` at top-start (hidden if bottom nav) and at bottom-end (margin 16dp, scaleX/Y = −1, visible if bottom nav). When welcome is shown, `homeContainer` + `swipeRefresh` are `GONE`. |

Section order (from `HomePreferences.getSortedSectionTags`): optional **Echo** first, then the saved order; default order = `R.array.home_section_tags`:
`QueueSection`, `InboxSection`, `EpisodesSurpriseSection`, `SubscriptionsSection`, `DownloadsSection`. Each section is hosted in its own `FragmentContainerView` inside `homeContainer`.

## A3. Section inventory

| Section | Title string | Items shown | Item layout | Horizontal? | Shuffle btn | Count pill | "more" label | "more" target |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `QueueSection` | "Continue listening" (`home_continue_title`) | **8** (`NUM_EPISODES`, `DBReader.getPausedQueue(8)`) | `horizontal_itemlist_item.xml` (card) | Yes | No | No | "Queue" (`queue_label`) | `QueueFragment` |
| `InboxSection` | "See what's new" (`home_new_title`) | **2** (`getEpisodes(0,2, FeedItemFilter.NEW, …)`) | `feeditemlist_item.xml` (vertical 3-line episode row) | **No** (vertical `LinearLayoutManager`) | No | **Yes** — total NEW count, `99+` when ≥100 | "Inbox" (`inbox_label`) | `InboxFragment` |
| `EpisodesSurpriseSection` | "Get surprised" (`home_surprise_title`) | **8** (`getRandomEpisodes(8, seed)`) | `horizontal_itemlist_item.xml` | Yes | **Yes** (`ic_shuffle`, contentDescription "Shuffle suggestions") | No | "Episodes" (`episodes_label`) | `AllEpisodesFragment` |
| `SubscriptionsSection` | "Check your classics" (`home_classics_title`) | **8 feeds** (`NUM_FEEDS`, most-played feeds of last 3 years, state SUBSCRIBED) | `horizontal_feed_item.xml` (96dp square cover card) | Yes | No | No | "Subscriptions" (`subscriptions_label`) | `SubscriptionFragment` |
| `DownloadsSection` | "Manage downloads" (`home_downloads_title`) | **2** (`getEpisodes(0,2, DOWNLOADED…)`) | `feeditemlist_item.xml` (vertical) | **No** | No | No | "Downloads" (`downloads_label`) | `CompletedDownloadsFragment` |
| `EchoSection` | "AntennaPod Echo \<year\>" (`antennapod_echo_year`, `%d` = `EchoConfig.RELEASE_YEAR`) | 1 card | `home_section_echo.xml` | n/a | No | No | none | `EchoActivity` (card click); close button hides for the year |

Per-section empty/loading text (`emptyLabel`, centered, paddingHorizontal 32dp, paddingVertical 8dp, `gone` when list non-empty):

| Section | `emptyLabel` string |
| --- | --- |
| Queue | "You can add episodes by downloading them or long-pressing them and selecting \"Add to queue\"." |
| Inbox | "New episodes will show up here. You can then decide whether you are interested in them." |
| Surprise | "You already played all recent episodes. Nothing to be surprised here ;)" |
| Downloads | "You can download any episode to listen to it offline." |
| Subscriptions | not set (stays `gone`) |

Loading behaviour: horizontal/vertical lists start with `setDummyViews(N)` (8 / 2 / 8 / 8 / 2) and the adapter renders dummy items at `alpha 0.1f` (`"████ █████"` / `"███"`), cleared when the DB read finishes. `RecyclerView.setItemAnimator(null)` for 500 ms after creation, then a `DefaultItemAnimator`.

## A4. `home_section.xml` header geometry (all 5 sections)

Root: `ConstraintLayout`, match_parent × wrap_content, paddingTop 8dp, paddingBottom 4dp.

| Element | Geometry |
| --- | --- |
| `titleLabel` | width 0dp, `layout_constraintWidth_percent="0.6"`, `layout_constraintWidth_max="wrap"`, wrap height; marginStart **16dp**, marginVertical **4dp**; `textAlignment=textStart`; `accessibilityHeading=true`; style `TextAppearance.Material3.TitleMedium` (≈16sp); horizontal chain style packed, bias 0; constrained end → `shuffleButton` |
| `shuffleButton` | `ImageButton`, wrap × wrap; marginVertical 4dp, marginStart 8dp; bg `?attr/selectableItemBackgroundBorderless`; `srcCompat=@drawable/ic_shuffle` (24dp); contentDescription "Shuffle suggestions"; `gone` by default — only `EpisodesSurpriseSection` sets it visible (and hides it again when the list is empty) |
| `numNewItemsLabel` | `TextView`, wrap × wrap; marginStart 8dp, marginTop 2dp, marginBottom 0dp, paddingHorizontal 8dp, **paddingBottom 1sp**; bg `@drawable/bg_pill` (1dp `colorPrimary` stroke, 20dp corners); textColor `?attr/colorPrimary`; style `TitleMedium`; `gone` by default — only Inbox shows it |
| `moreButton` | `Button`, width 0dp with `layout_constraintWidth_percent="0.4"` / max wrap, wrap height; marginStart **16dp**, marginEnd **8dp**; paddingVertical **8dp**, paddingHorizontal **12dp**; `minWidth=0dp`, `minHeight=0dp`, `singleLine=true`, `textAlignment=textEnd`; `app:icon=@drawable/ic_arrow_right_white` (24dp), `iconGravity=end`, `iconPadding=4dp`; style `Widget.Material3.Button.TextButton`. `INVISIBLE` if the section's `getMoreLinkTitle()` is empty (no current section does that). |
| `barrier` | bottom barrier over `titleLabel,moreButton` — everything below is anchored to it |
| `recyclerView` | match_parent × wrap_content, `clipToPadding=false`, `clipToOutline=false`, `clipChildren=false`, `paddingHorizontal=16dp` (overridden at runtime, see below) |
| `emptyLabel` | match_parent × wrap, centered text, paddingHorizontal 32dp, paddingVertical 8dp, `gone` |

Runtime padding overrides on `recyclerView`:
- Queue / Surprise / Subscriptions: `setPadding(12dp*density, 0, 12dp*density, 0)`
- Inbox / Downloads: `setPadding(0,0,0,0)` + `OVER_SCROLL_NEVER`

## A5. `horizontal_itemlist_item.xml` — exact geometry

Outer root: `LinearLayout`, wrap × wrap, `clipToPadding=false`. Item total width ≈ **136dp + 2px** (128dp content + 2×1px + 2×4dp margins).

| Element | Exact values |
| --- | --- |
| `card` (CardView) | wrap × wrap, `clickable=true`, `foreground=?android:attr/selectableItemBackground`, **layout_margin 4dp**, `cardBackgroundColor=?attr/colorSurfaceContainer` (overridden in code to `?attr/colorSecondaryContainer` while that episode is playing), `cardCornerRadius=12dp`, `cardElevation=0dp` |
| inner CardView (cover clipping) | wrap × wrap, **layout_margin 1px**, `cardCornerRadius=12dp`, `cardBackgroundColor=@android:color/transparent`, `cardElevation=0dp` |
| `cover` container `FrameLayout` | **128dp × 128dp**, `background=@color/image_readability_tint` (`#80000000`) |
| `cover` (`SquareImageView`) | match/match, `outlineProvider=bounds`, `direction=width` ⇒ renders **128dp × 128dp** (1:1) |
| circle behind play button | `ImageView` **48dp × 48dp**, `layout_gravity=bottom|end`, **margin 4dp**, **padding 4dp**, `srcCompat=@drawable/bg_circle` (filled `?attr/colorPrimary`, radius 30dp) |
| `circularProgressBar` | `CircularProgressBar` **48dp × 48dp**, `bottom|end`, **margin 4dp**, `app:foregroundColor=?attr/colorOnPrimary` (download progress ring) |
| `secondaryActionIcon` | `ImageView` **48dp × 48dp**, `bottom|end`, **margin 4dp**, `clickable=true`, `foreground=?attr/selectableItemBackgroundBorderless`, **padding 12dp**, `srcCompat=@drawable/ic_play_24dp`, `tint=?attr/colorOnPrimary`, `tintMode=src_atop`. Icon is swapped at bind time by `ItemActionButton.forItem(item)`: play / pause / stream / download / cancel-download / mark-as-played |
| `progressBar` | `LinearProgressIndicator`, match_parent × **4dp**, `layout_gravity=bottom`, `max=100`, `app:trackStopIndicatorSize=0dp`; track color `#55888888` via `Widget.AntennaPod.LinearProgressIndicator`. Sits **immediately under the 128dp cover, inside the card**, i.e. at the bottom edge of the cover block. `gone` when no playback position; progress clamped to ≥5 so it stays visible under the 12dp corner radius |
| `progressBarReplacementSpacer` | `View` match_parent × **4dp**, `gone` — occupies the progress-bar slot when the bar is hidden (keeps card heights equal) |
| `titleLabel` | **128dp × wrap**, marginTop **4dp**, paddingHorizontal **4dp**, `ellipsize=end`, `lines=2`, `singleLine=false`, `textColor=?android:attr/textColorPrimary`, **textSize 14sp** |
| `dateLabel` | match_parent × wrap, marginBottom **4dp**, paddingHorizontal **4dp**, `singleLine=true`, `textAlignment=textStart`, **textSize 14sp**, style `AntennaPod.TextView.ListItemSecondaryTitle` (color `?attr/colorOnSurfaceVariant`, 1 line, ellipsize end) |

Vertical extent: 128 (cover) + 4 (progress) + 4 (title marginTop) + ~2×18dp (2-line 14sp title) + ~20dp (date) + 4 (date marginBottom) ≈ **198dp content**, ≈ **206dp** with the 4dp card margins.

## A6. `horizontal_feed_item.xml` — exact geometry (SubscriptionsSection)

| Element | Exact values |
| --- | --- |
| Root | `LinearLayout`, match_parent × **96dp**, **padding 4dp**, clipToPadding/clipToOutline/clipChildren = false |
| `cardView` | wrap × wrap, `cardBackgroundColor=@color/non_square_icon_background` (`#22777777`), `cardCornerRadius=16dp`, `cardPreventCornerOverlap=false`, `cardElevation=2dp` |
| `discovery_cover` (`SquareImageView`) | match_parent × **96dp**, `direction=height` ⇒ **96dp × 96dp** square, `elevation=4dp`, `outlineProvider=bounds`, `foreground=?android:attr/selectableItemBackground`, `background=?android:attr/colorBackground` |
| `actionButton` | `Button`, wrap × wrap, `gone` by default, style `Widget.Material3.Button.OutlinedButton` (only used when the adapter is given an end-button, not in the home section) |
| Item footprint | ≈ **104dp wide** (96 + 2×4dp) × 96dp tall. Dummy items: `alpha 0.1f`, cover = `@color/medium_gray`; real items use Glide `placeholder(@color/light_gray)`, `fitCenter`, `dontAnimate` |

## A7. `home_section_echo.xml` — exact geometry

| Element | Exact values |
| --- | --- |
| Root | `LinearLayout` vertical, match_parent × wrap, **paddingHorizontal 16dp** |
| Header row | horizontal `LinearLayout`; title `TextView` weight 1, **textSize 18sp**, `textColor=?android:attr/textColorPrimary`, marginVertical 8dp, `accessibilityHeading=true`, text "Review the year" (`echo_home_header`) |
| `closeButton` | `ImageView` **48dp × 48dp**, **padding 16dp**, bg `?attr/selectableItemBackgroundBorderless`, contentDescription "Close" (`close_label`), `src=@drawable/ic_cancel` |
| Card | `CardView` match_parent × wrap, `cardCornerRadius=8dp`, `cardElevation=0dp` |
| `echoButton` | inner `LinearLayout`, match_parent × wrap, `background=@drawable/bg_blue_gradient` (90° linear `#1EB0FC` → `#2E6FF6`), **padding 16dp**, `foreground=?attr/selectableItemBackground` |
| Card title | `TextView` match_parent, marginBottom 8dp, `textColor=#fff`, `textFontWeight=500`, style `TextAppearance.Material3.TitleLarge`, text "AntennaPod Echo \<year\>" |
| Card subtitle | `TextView` weight 1, `textColor=#fff`, style `TextAppearance.Material3.BodyMedium`, text "Your top podcasts and stats from the past year. Exclusively on your phone." |
| Card arrow | `ImageView` **24dp × 24dp**, `layout_gravity=bottom`, `src=@drawable/ic_arrow_right_white`, `importantForAccessibility=no` |
| Visibility rule | rendered only while `EchoConfig.isCurrentlyVisible()`, not dismissed for the current year, and **total played time ≥ 36000 s (10 h)**; otherwise the section hides itself and persists the dismissal in `PrefHomeFragment/HideEcho` |

## A8. Horizontal lists & cards-per-screen

- Queue, Surprise and Subscriptions use `LinearLayoutManager(context, HORIZONTAL, false)`; Inbox and Downloads use `VERTICAL` (they are stacked episode rows inside the page scroll, 2 rows each).
- No `layout_width` hint is set on the horizontal items — the width comes from content: `horizontal_itemlist_item` = 128dp cover + 2×1px + 2×4dp margin ≈ **136dp**; `horizontal_feed_item` = 96dp + 2×4dp ≈ **104dp**.
- Cards visible at once with the 12dp RecyclerView padding:
  - 360dp-wide phone: `(360 − 24) / 136` ≈ **2.5** episode cards; `(360 − 24) / 104` ≈ **3.2** feed cards.
  - 411dp-wide phone: ≈ **2.8** episode cards; ≈ **3.7** feed cards.
- No snapping/peeking attributes, no `LinearSnapHelper`, no fixed card count per screen.

---

# B. SUBSCRIPTIONS (`SubscriptionFragment`, `fragment_subscriptions.xml`)

## B1. Toolbar

| Property | Value |
| --- | --- |
| Outer AppBarLayout id `appbar` | wrap_content, `fitsSystemWindows=true` |
| Toolbar id `toolbar` | height `?attr/actionBarSize` = **56dp**; `layout_collapseMode=pin`; title `@string/subscriptions_label` = **"Subscriptions"** (replaced with **"Archive"**, `archive_feed_label_noun`, when opened with `Feed.STATE_ARCHIVED`); `navigationIcon=?homeAsUpIndicator`, `navigationContentDescription="Back"` |
| Lift | `LiftOnScrollListener(appbar)` + a second one on `collapsing_container` |
| Quirk | long-press on the toolbar does `scrollToPosition(5)` then `smoothScrollToPosition(0)` |

Menu `app/src/main/res/menu/subscriptions.xml` (declaration order):

| # | id | Title | Icon | showAsAction | Action |
| --- | --- | --- | --- | --- | --- |
| 1 | `action_search` | "Search" | `ic_search` | **always** | `SearchFragment.newInstance()` (with `INCLUDE_ARCHIVED` filter in Archive mode) |
| 2 | `refresh_item` | "Refresh" | — | never | `FeedUpdateManager.runOnceOrAsk()` |
| 3 | `subscriptions_filter` | "Filter" | — | never | `SubscriptionsFilterDialog` |
| 4 | `subscriptions_sort` | "Sort" | — | never | `FeedSortDialog` |
| 5 | `subscriptions_counter` | "Counter" (`pref_nav_drawer_feed_counter_title`) | — | never | `FeedCounterDialog` |
| 6 | `subscription_num_columns` | "Number of columns" | — | never | submenu (single-checkable group) |
| 6a | `subscription_display_list` | "List" | — | submenu | columns = 1 |
| 6b | `subscription_num_columns_2` | "2" | — | submenu | columns = 2 |
| 6c | `subscription_num_columns_3` | "3" | — | submenu | columns = 3 |
| 6d | `subscription_num_columns_4` | "4" | — | submenu | columns = 4 |
| 6e | `subscription_num_columns_5` | "5" | — | submenu | columns = 5 |
| 7 | `pref_show_subscription_title` | "Show titles" | — | never, checkable | toggles `UserPreferences.setShouldShowSubscriptionTitle`; **menu item visible only when columns > 1** |
| 8 | `show_archive` | "Archive" | — | never | opens `SubscriptionFragment.newInstance(Feed.STATE_ARCHIVED)` |

Archive mode removes items 2, 3, 5, 8 from the toolbar and hides the FAB. Column numbers 2–5 are set programmatically with `String.format(Locale, "%d", i+1)` so they localize.

## B2. Tag-filter chip row + "Filtered" row

Both live inside a second `AppBarLayout` → `CollapsingToolbarLayout` id `collapsing_container` (`titleEnabled=false`, `contentScrim=#00000000`, `layout_scrollFlags=scroll|snap|enterAlways|exitUntilCollapsed`); in select mode the flags become `scroll|exitUntilCollapsed`, restored afterwards.

| Element | Exact values |
| --- | --- |
| `tags_recycler` | `RecyclerView`, match_parent × **wrap_content**, **paddingHorizontal 12dp**, `clipToPadding=false`; `LinearLayoutManager(HORIZONTAL)`; `ItemOffsetDecoration(context, 4, 0)` ⇒ **4dp horizontal gap, 0dp vertical**; `visibility` toggled at runtime — visible only when at least one tag other than "All"/"Untagged" exists |
| Chip (`item_tag_chip.xml`) | `com.google.android.material.chip.Chip`, wrap × wrap, **elevation forced to 0** in the adapter, `checkable=true`, `longClickable=true`, style `Widget.Material3.Chip.Filter` **(M3 lib ≈ 32dp tall, 8dp corner radius, 14sp label)**; checked = the currently selected tag |
| Chip labels | first chip = "All" (`tag_all`, `FeedPreferences.TAG_ROOT`); "Untagged" (`tag_untagged`, `TAG_UNTAGGED`); other tag titles truncated to **19 chars + "…"** when longer than 20 |
| Chip interactions | tap = filter (persists `last_tag`), long-press / right-click = context menu `R.menu.nav_folder_context` (suppressed for All/Untagged). On data load the selected chip is scrolled to be horizontally centered |
| `feeds_filtered_message` | `TextView`, match_parent × wrap, text **"Filtered"** (`filtered_label`), `background=?android:attr/selectableItemBackground`; XML paddingHorizontal 16dp / paddingVertical 4dp, **overridden in code** to `density × (largePadding ? 60 : 16)` horizontal and `density × 4` vertical, where `largePadding = displayUpArrow || !UserPreferences.isBottomNavigationEnabled()`; tap → `SubscriptionsFilterDialog`. `GONE` unless state == SUBSCRIBED **and** `UserPreferences.getSubscriptionsFilter().isEnabled()` **and** not in action mode (then `INVISIBLE`) |

## B3. Grid container

| Element | Exact values |
| --- | --- |
| `swipeRefresh` | `SwipeRefreshLayout` match/match, `layout_behavior=@string/appbar_scrolling_view_behavior`, `setDistanceToTriggerSync(300)`, listener → `FeedUpdateManager.runOnceOrAsk()` |
| `subscriptions_grid` | `RecyclerView` match/match, `clipToPadding=false`, `layout_gravity=center_horizontal`, **paddingBottom 88dp** (FAB clearance), no horizontal padding |
| Layout manager | `GridLayoutManager(context, columns, VERTICAL, false)`; when `columns == 1 && defaultColumns == 5` (tablet) it is `GridLayoutManager(context, 2, VERTICAL, false)` — i.e. list rows laid out in **2 columns** |
| Grid divider | only when `columns > 1`: `GridDividerItemDecorator` adds **1dp inset on all 4 sides of every item** (`outRect.set(1dp,1dp,1dp,1dp)`) |
| Columns default | `R.integer.subscriptions_default_num_of_columns` = **3** (phones) / **5** (`values-sw600dp`) |

## B4. `subscription_grid_item.xml` — exact geometry

| Element | Exact values |
| --- | --- |
| Root | `FrameLayout`, wrap × wrap, **padding 4dp**, `clipToPadding=false` (tools hint `layout_width=150dp`) |
| `outerContainer` (CardView) | match/match, `clickable=false`, `foreground=?attr/selectableItemBackground`, **`cardCornerRadius=12dp`**, **`cardElevation=1dp`**; background color **set in code** to `ThemeUtils.getColorFromAttr(?, attr/colorSurfaceContainer)` |
| Inner CardView | wrap × wrap, `cardBackgroundColor=@color/non_square_icon_background` (`#22777777`), **`cardCornerRadius=12dp`**, `cardElevation=0dp`, `clickable=false` |
| Cover `RelativeLayout` | wrap × wrap, **`layout_margin=1px`** |
| `coverImage` (`SquareImageView`) | match/match, `scaleType=fitCenter`, `outlineProvider=background`, `direction=width` ⇒ **1:1 square**; column width = `screenWidth/columns − 2dp (1dp insets) − 8dp (4dp item padding)`; e.g. 360dp/3 cols ⇒ ≈ **110dp** cover |
| `fallbackTitleLabel` | aligned to all 4 edges of `coverImage`, `background=@color/feed_text_bg` (`#55333333`), `gravity=center`, `ellipsize=end`, **padding 6dp**, `textColor=#fff`; visible only when the title row is hidden (`shouldShowSubscriptionTitle == false && columns > 1`); text size set in code (see B7) |
| `gradientOverlay` | `ImageView` match_parent × **48dp**, `layout_gravity=top`, `rotation=180`, `alpha=0.4`, `src=@drawable/bg_gradient`, `tint=#000`, `gone` unless in action mode |
| `countViewPill` | `TextView` wrap × wrap, `layout_alignParentEnd=true` ⇒ **top-end**, `textSize=14sp`, style `TextPill` ⇒ bg `@drawable/bg_pill_translucent` (solid `#D2404040`, **corner radius 18dp**), `textColor=@color/white` `#FFFFFF`, `layout_margin=8dp`, `paddingStart/End=8dp`, `textAlignment=center`; `gone` when counter == 0 |
| `errorIcon` | `ImageView` **24dp × 24dp**, `alignParentEnd` + `alignBottom=@id/coverImage` ⇒ **bottom-end of cover**, `layout_margin=8dp`, `gone`, contentDescription "Last refresh failed. Tap to view details." (`refresh_failed_msg`), `src=@drawable/ic_error` |
| `titleLabel` | match_parent × wrap, `ellipsize=end`, `gravity=start`, `textColor=?android:attr/textColorPrimary`, **`lines=2`**, `importantForAccessibility=no`; text size + padding set in code (B7) |
| `selectedIcon` | `ImageView` **32dp × 32dp**, `layout_gravity=top` ⇒ **top-start**, `layout_margin=4dp`, **`elevation=2dp`**, `gone` unless action mode, `srcCompat=@drawable/circle_unchecked` / `@drawable/circle_checked`; when selected the whole card gets an animated uniform margin of **12dp** (100 ms `ValueAnimator`) to visually shrink it |

## B5. `subscription_list_item.xml` — exact geometry (columns == 1)

| Element | Exact values |
| --- | --- |
| Root | `LinearLayout` horizontal, match_parent × wrap, **paddingHorizontal 16dp**, **paddingVertical 8dp**, `foreground=?attr/selectableItemBackground` |
| Cover CardView | **56dp × 56dp**, `clickable=false`, `cardBackgroundColor=@color/non_square_icon_background` (`#22777777`), **`cardCornerRadius=12dp`**, `cardElevation=0dp` |
| Cover `RelativeLayout` | wrap × wrap, **`layout_margin=1px`** |
| `coverImage` | match/match, `scaleType=fitCenter`, `outlineProvider=background`, `direction=width` ⇒ **56dp square** |
| `fallbackTitleLabel` | aligned to all 4 cover edges, `background=@color/feed_text_bg` (`#55333333`), `gravity=center`, `ellipsize=end`, **padding 6dp**, `textColor=#fff`; **hidden** in list mode (`shouldShowSubscriptionTitle() || columnCount == 1` ⇒ title is shown, no fallback needed) |
| `titleLabel` | width 0dp, `layout_weight=1`, **marginHorizontal 8dp**, `layout_gravity=center_vertical`, `ellipsize=end`, `gravity=start`, **`maxLines=2`**, `importantForAccessibility=no`, style `AntennaPod.TextView.ListItemPrimaryTitle` (BodyLarge, `?attr/colorOnSurface`, lineHeight 20sp) |
| `countViewPill` | `TextView` wrap × wrap, `layout_gravity=center_vertical`, **`textColor=?android:attr/textColorTertiary`**, **`textSize=14sp`** — note: in list mode this is **plain text with no pill background** |
| `errorIcon` | `ImageView` **24dp × 24dp**, `layout_margin=8dp`, `layout_gravity=center_vertical`, `gone`, contentDescription "Last refresh failed. Tap to view details.", `src=@drawable/ic_error` |
| Row height | 56dp cover + 2×8dp vertical padding = **72dp** (or 2 lines of title + padding if taller) |

## B6. FAB and select mode

| Element | Exact values |
| --- | --- |
| `subscriptions_add` | `FloatingActionButton`, **56dp × 56dp**, **`layout_margin=16dp`**, **`layout_gravity=bottom|end`**, `contentDescription="Add podcast"` (`add_feed_label`), `app:srcCompat=@drawable/ic_add` (24dp) |
| Action | `MainActivity.loadChildFragment(new AddFeedFragment())` — the "Add podcast" screen |
| Hidden when | Archive mode (`STATE_ARCHIVED`) and during multi-select mode |
| `floatingSelectMenu` | `de.danoeh.antennapod.ui.view.FloatingSelectMenu`, match_parent × wrap, `layout_gravity=bottom`, `gone`; shown instead of the FAB in select mode (card bg = `SurfaceColors.getColorForElevation(8dp)`) |
| `progressBar` | `ProgressBar` wrap × wrap, `layout_gravity=center`, `indeterminateOnly=true`, `visibility=visible` on create — this is the **loading state** |

## B7. Grid vs list preference and defaults

| Setting | Storage | Key | Default | Effect |
| --- | --- | --- | --- | --- |
| Number of columns | SharedPreferences file **`"SubscriptionFragment"`** | `"columns"` (int) | `R.integer.subscriptions_default_num_of_columns` = **3** phone / **5** sw≥600dp | `columns == 1` ⇒ list layout; `2..5` ⇒ grid with that many columns; `1` on a tablet-default-5 device ⇒ 2-column grid of list rows |
| Show titles | `UserPreferences` default prefs | `PREF_SUBSCRIPTION_TITLE = "prefSubscriptionTitle"` (boolean) | **false** | When `false` and `columns > 1`, the title row is `GONE` and `fallbackTitleLabel` is drawn over the cover instead |

Title / fallback-text metrics applied in `SubscriptionViewHolder.bind()`:

| columns | title textSize | title + fallback padding (all 4 sides) |
| --- | --- | --- |
| 2 | **16sp** | 16dp |
| 3 | **15sp** | 16dp |
| 4, 5 | **14sp** | **8dp** |
| 1 (list) | **14sp** | 16dp |

Count text uses `NumberFormat.getInstance().format(counter)` where `counter` comes from `NavDrawerData.feedCounters` (0 ⇒ hidden).

## B8. Empty state / loading state

| State | Presentation |
| --- | --- |
| Loading | centered indeterminate `ProgressBar` (`visibility=visible` in XML) while the Rx `DBReader.getNavDrawerData(...)` call runs; hidden in the success callback. `emptyView.hide()` is called before the load |
| Empty | `EmptyViewHandler` inflates `ui/common/.../empty_view_layout.xml` into the `CoordinatorLayout`, `gravity=center`; the RecyclerView is set `INVISIBLE` while the empty view is `VISIBLE` |
| Empty view geometry | root `LinearLayout` match/match, `gravity=center`, **paddingLeft/Right 40dp**; icon **32dp × 32dp** (here `@drawable/ic_subscriptions`); title `TextView` **16sp**, `textAlignment=center`, `textColor=?android:attr/textColorPrimary`; message `TextView` **14sp**, `textAlignment=center`; optional `Button` marginTop 16dp, style `Widget.Material3.Button.OutlinedButton`, `gone` (unused here) |
| Empty strings | Archive mode: title **"Nothing archived"**, message **"You can archive podcasts from the main subscriptions screen."** · filter enabled: title **"No subscriptions"**, message **"Try clearing the filter to see more subscriptions."** · otherwise: title **"No subscriptions"**, message **"To subscribe to a podcast, press the plus icon below."** |
| Swipe refresh | available in all states (wraps the grid) |

---

## C. Cross-cutting notes for the ArkTS port

1. `1px` insets in `horizontal_itemlist_item` (inner cover card), `subscription_grid_item` and `subscription_list_item` (cover `RelativeLayout`) exist to hide anti-aliased cover edges under the 12dp corner radius — reproduce as ~0.3vp or 1 physical pixel.
2. Both screens share the "cover + 12dp radius + 0dp elevation card" idiom; home horizontal cards use `colorSurfaceContainer`, subscription cards use `colorSurfaceContainer` for the outer card and `#22777777` for the inner cover card.
3. The home count pill uses a **1dp `colorPrimary` stroke, 20dp radius, transparent fill**; the subscription grid count pill uses a **solid `#D2404040`, 18dp radius, white text** — they are visually different components despite the similar name.
4. `?attr/actionBarSize` resolves to **56dp** (Material3 default; no override in the repo).
5. Neither screen defines a background color; both inherit the theme surface color.
6. Home has one swipe-to-refresh (page level); Subscriptions has one swipe-to-refresh (grid level). Both trigger the same feed-update flow.

## D. Files read

- Layouts: `app/src/main/res/layout/{home_fragment,home_section,home_section_echo,horizontal_itemlist_item,horizontal_feed_item,fragment_subscriptions,subscription_grid_item,subscription_list_item,item_tag_chip,feeditemlist_item,empty_view_layout}.xml`, `ui/common/src/main/res/layout/empty_view_layout.xml`
- Menus: `app/src/main/res/menu/{home,subscriptions}.xml`
- Java: `ui/screen/home/{HomeFragment,HomeSection}.java`, `ui/screen/home/sections/*.java`, `ui/screen/home/settingsdialog/HomePreferences.java`, `ui/screen/subscriptions/*.java`, `ui/episodeslist/{HorizontalItemViewHolder,EpisodeItemListAdapter,EpisodeItemViewHolder}.java`, `ui/common/src/main/java/.../{EmptyViewHandler,ItemOffsetDecoration,LiftOnScrollListener,SquareImageView,CircularProgressBar}.java`
- Resources: `ui/common/src/main/res/values/{styles,colors,dimens}.xml`, `ui/common/src/main/res/drawable/{bg_pill,bg_pill_translucent,bg_circle,bg_blue_gradient,bg_gradient,circle_unchecked}.xml`, `app/src/main/res/values/integers.xml`, `app/src/main/res/values-sw600dp/integers.xml`, `ui/preferences/src/main/res/values/arrays.xml`, `ui/i18n/src/main/res/values/strings.xml`, `storage/preferences/.../UserPreferences.java`
