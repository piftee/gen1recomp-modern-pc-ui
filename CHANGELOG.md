# Changelog

## [0.1.3] - 2026-08-22

- HGSS icons in party, box, and detail cells now animate whenever Modern
  Party UI's ICON ANIMATION setting is enabled; the preference also disables
  those animations consistently across both mods.
- Boxed HGSS Pokémon now animate even when their stored records do not include
  calculated battle stats, using a safe fallback animation pace.
- HGSS animation also follows a steady wall clock, so PC compatibility wrappers
  cannot freeze every party, box, or detail icon by skipping the local update.
- Both HGSS source frames now share one fitted alpha envelope, preserving the
  icons' authored one-pixel movement instead of re-centring it away.
- True-colour restoration now follows opaque sprite-pixel runs rather than a
  rectangular fitted footprint, removing the remaining shaded backplates.

## [0.1.2] - 2026-08-22

### Fixed

- Fitted HGSS Visual Overhaul's padded 32×32 menu frames into party, box, and
  detail cells using each animation frame's visible alpha bounds.
- Centred HGSS sprites independently of their transparent source padding.
- Removed the grey full-frame backplates caused by restoring HGSS's original
  32×32 true-colour claims over the finished PC.

### Added

- Explicit HGSS Visual Overhaul load ordering and compatibility detection.
- Regression coverage for cropped frame bounds, safe rendered dimensions,
  true-colour regions, and the image-data-free fallback.

## [0.1.1] - 2026-08-20

### Fixed

- Preserved authored full-colour species icons in party slots, box slots, and
  the scaled detail portrait.
- Clipped icon and gender true-colour restores around the action popup.
- Matched Modern Party UI's optional dependency order so companion hooks,
  exports, controllers, and artwork initialize before the PC.

### Added

- Gender Mod marker and name handling on PC surfaces.
- Gen1 Modern UI source-screen registration.
- Callback-backed party utilities from Anytime Rename and Wilds of Kanto.
- Regression coverage for replacement icons, transformed icon claims, popup
  overlap, Gender Mod, Gen1 Modern UI, and Anytime Rename.

## [0.1.0] - 2026-08-20

### Added

- Combined party and active-box storage screen.
- Direct pick-up, drop, reorder, and swap controls.
- Carrying Pokémon between boxes with in-place box switching.
- Quick transfer, Summary, Release, and previous/next box actions.
- Responsive pixel layout, colour palettes, detail panel, tests, and previews.
