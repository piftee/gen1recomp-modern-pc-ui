# Changelog

## [0.4.2] - 2026-08-31

### Fixed

- Stop retaining the PC workspace beneath opaque Summary screens. Opening a
  Pokémon from storage now shows only Modern Party UI's summary portrait,
  preventing the underlying PC portrait from appearing with a different
  orientation or inherited palette while transparent prompts still retain the
  PC as intended.

## [0.4.1] - 2026-08-25

### Compatibility

- Verified load ordering and the PC-to-Summary handoff with Crystal Animated
  Sprites with Shiny Visuals 1.x. Its live true-colour sprite and animation
  update wrapper remain installed when Summary is opened from storage.

### Fixed

- Capped the complete tall-phone PC surface at 256 native pixels, limiting the
  full-width selected-Pokémon panel to roughly 110 pixels instead of allowing
  it to absorb every extra pixel in extremely tall windows.
- Taller portrait windows now letterbox the finished interface while retaining
  the same integer pixel scale and touch-control clearance.

## [0.4.0] - 2026-08-25

### Added

- Added a true tall-phone workspace that uses the available portrait canvas
  instead of centring the 144px interface between black bars.
- Portrait screens show the full-width box grid first, all six party slots in
  one row beneath it, and a generous full-width Pokémon information panel at
  the bottom with battle artwork on the left and details on the right.
- Visible touch controls reserve a black control bed below the PC so they never
  cover the selected-Pokémon panel or footer.

### Changed

- The 160×144 compact arrangement remains limited to genuinely short surfaces;
  tall 160px-wide phone canvases now receive the portrait layout.

## [0.3.3] - 2026-08-25

### Changed

- Restored the space-efficient 2×3 party, box grid, and bottom detail strip at
  genuinely small 160px-wide and portrait-phone game surfaces.
- Medium and desktop windows keep the details-left, box-above, party-bottom
  arrangement introduced in 0.3.0.

## [0.3.2] - 2026-08-25

### Changed

- Removed the alternate compact panel arrangement. Every window size now keeps
  selected-Pokémon details on the left, the active box above, and all six party
  slots in one row along the bottom.
- Narrow windows use tighter panel widths and shorter labels without changing
  navigation or moving the party away from the bottom.

## [0.3.1] - 2026-08-25

### Fixed

- Enabled the redesigned details-left, party-bottom workspace at medium and
  4:3 window widths. Only the true 160×144 view now uses the legacy compact
  arrangement, so ordinary non-widescreen desktop windows no longer appear
  unchanged after upgrading.

## [0.3.0] - 2026-08-25

### Changed

- Rebuilt the widescreen workspace with selected-Pokémon details on the left,
  the active box above, and all six party slots in one row along the bottom.
- LEFT or RIGHT at a widescreen box-grid edge now opens the adjacent box while
  preserving the cursor position and any carried Pokémon.
- DOWN from the box's bottom row enters the nearest party slot; UP returns to
  the nearest position on the box's bottom row.
- A on the focused box header now opens a visible all-box picker for direct
  jumps, while LEFT and RIGHT retain quick sequential browsing.
- Compact mode keeps its established space-efficient panel arrangement.

## [0.2.3] - 2026-08-24

### Fixed

- Clamped authored icon backing colours and true-colour restoration to each
  party or box slot's inner face, preventing sprite backgrounds from cutting
  into selected black frames or unselected card borders.

## [0.2.2] - 2026-08-23

### Changed

- The wide selected-Pokémon detail rail now shows the exact front sprite
  selected for battle instead of enlarging a separate menu icon.
- Party and box grids continue using Unique Menu Icons and fitted HGSS icons,
  preserving their purpose as compact navigation art.
- Added regression coverage for battle-context resolution and retained HGSS
  grid fitting and animation.

## [0.2.1] - 2026-08-22

### Changed

- Only the highlighted party or box slot now animates. All unselected icons
  and the duplicate detail portrait remain on their resting frame.
- HGSS animation follows the PC cursor across party and box slots while
  preserving the fitted sprite alignment and transparent backgrounds.

## [0.2.0] - 2026-08-22

### Changed

- SELECT now focuses a visible box selector instead of silently advancing one
  box. LEFT and RIGHT browse in both directions, including while carrying a
  Pokémon; A, B, DOWN, or SELECT returns to the grid.
- Pressing UP from the top row of the box grid also enters the selector.
- START is now dedicated to actions for the selected Pokémon. Box navigation
  is no longer duplicated at the bottom of the action menu.
- Compact and wide footer hints now describe the current control mode.

### Fixed

- Release confirmation now keeps the Pokémon's name and consequence visible
  together in the native two-line dialogue area.
- START on an empty slot reports that the slot is empty instead of opening a
  menu containing only navigation and Cancel.

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
