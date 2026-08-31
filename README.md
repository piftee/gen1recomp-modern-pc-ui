# Modern PC UI

Modern PC UI turns Someone's PC into one party-and-box workspace. It keeps
Pokémon Red's pixel font, menu icons, palettes, cries, box capacity, and save
format while adopting the direct manipulation used by newer Pokémon games.

On Gold, Silver, and Crystal the mod keeps Bill's native fourteen-box storage
controller and adds a generation-aware workspace treatment to its list and
preview panels.

## What changes

- the party and active PC box stay visible together
- A picks up, places, reorders, or swaps a Pokémon
- widescreen places details on the left, the active box above, and the whole
  party in one row along the bottom
- LEFT/RIGHT at a widescreen box edge browse adjacent boxes without putting a
  carried Pokémon down; DOWN enters the party and UP returns to the box
- SELECT focuses the box header; A opens a numbered list for jumping directly
  to any box
- START provides Summary, one-step transfer, Release, and companion actions
- selected Pokémon show their battle-front artwork, name, level, type, HP,
  and current location
- empty party and box positions remain visible
- widescreen displays add a full detail rail and horizontal party strip
- genuinely small, short 160×144 surfaces use a compact 2×3 party grid and
  bottom detail strip so icons and text remain legible
- tall phone screens instead use their extra height: full-width box grid,
  horizontal party row, then a large full-width information panel with the
  selected Pokémon's battle artwork beside its details
- primary-type colours match Modern Party UI's card palette

The combined layout adapts the storage workflow from Pokémon Sword and Shield,
Scarlet and Violet, and Legends: Arceus: an active box grid, a nearby party,
selected-Pokémon details, and in-place box switching. On widescreen displays,
the party runs beneath the box so vertical movement reaches it naturally while
the grid's left and right edges browse boxes. The implementation stays
intentionally Gen 1: all graphics come from the player's own game data and the
interface is built from crisp pixels and four-shade palette ramps.

Reference material:

- [Sword and Shield's official Pokémon Boxes overview](https://swordshield.pokemon.com/en-gb/gameplay/features-adventure/)
- [Scarlet and Violet party-and-box workflow](https://dotesports.com/pokemon/news/how-to-access-your-pc-boxes-in-pokemon-scarlet-and-violet)
- [Legends: Arceus Pastures controls](https://game8.co/games/Pokemon-Legends-Arceus/archives/353418)

## Controls

| Action | Control |
| --- | --- |
| Move cursor | D-pad / arrow keys |
| Pick up or place Pokémon | A |
| Cancel a carried Pokémon / close PC | B |
| Focus box selector | SELECT, or Up from the box's top row |
| Previous/next box | Left/Right at a widescreen grid edge or while the header is focused |
| Open all-box picker | A while the box header is focused |
| Choose a box directly | D-pad then A in the all-box picker |
| Return to the box grid | Down or SELECT from the header; B from the PC |
| Move between box and party | Down from the bottom box row; Up from the party |
| Summary, quick transfer, Release, companion actions | START |

A carried Pokémon stays attached to the cursor while browsing from either grid
edge, the highlighted header, or the all-box picker. Sequential browsing and
direct jumps therefore share one visible control path. START's **SEND TO BOX**
and **ADD TO PARTY** actions provide an even faster one-step transfer when exact
placement does not matter.

The usual safety rules remain: the last party Pokémon cannot be deposited or
released, a seventh party member cannot be withdrawn, and a 21st Pokémon cannot
be added to a box. Swapping an occupied party slot with an occupied box slot is
still allowed when both sides are full because neither collection grows.

## Compatibility

Modern PC UI uses Gen1Recomp's shared Pokémon icon renderer, so species icons,
runtime icon hooks, and compatible icon replacement mods continue to work.
Authored full-colour replacements—including **Unique Menu Icons** and icon
wrappers used by **Wilds of Kanto**—are protected from the PC's type palettes in
party and box slots. Protection is clipped around the live action popup so
covered icons cannot repaint the popup. The wide detail rail uses the same
`battle` front-sprite selection as combat instead, preventing a menu icon from
being mistaken for the Pokémon's in-battle appearance.

**HGSS Visual Overhaul** is handled separately because its party artwork uses
padded 32×32 frames rather than Gen 1's 16×16 icon contract. Modern PC UI reads
both frames' visible pixels, fits their shared envelope inside the slot, and
protects only the opaque artwork. Using one envelope preserves HGSS's authored
frame movement while keeping icons inside their cells and preventing transparent
padding from returning as grey rectangles after the palette pass.

The PC mirrors Modern Party UI's established companion list:

- **Gender Mod 0.3.5** supplies its public marker, colour, and name handling.
- **Gen1 Modern UI 0.9.2** receives a source-screen contract that keeps this
  direct-manipulation renderer visible.
- **Anytime Rename 1.2.1** and **Wilds of Kanto** can add callback-backed
  NICKNAME and FOLLOW utilities to a party Pokémon's START actions.
- **DV Tracker**, **Kanto Ribbons**, **DramaticShape**, **Crystal 251**,
  **Crystal Animated Sprites with Shiny Visuals 1.x**, **Pokémon Gold & Silver
  Sprites**, **HGSS Visual Overhaul**, and **QoL Toggles** initialize before the
  PC. Selecting SUMMARY therefore opens their live compatible Summary
  controller and the responsive presentation supplied by Modern Party UI when
  it is installed. Crystal 1.x's true-colour artwork and animation update
  wrapper remain live through the PC-to-Summary handoff.

A boxed Pokémon receives its derived stat block when it enters the party or
opens Summary, matching the native engine. Pokémon Yellow's deposited-Pikachu
happiness change is retained. FOLLOW and other party-state actions are offered
only for Pokémon currently in the party, never for boxed Pokémon.

Modern Bag UI and Modern Party UI are optional companions. Together the three
mods use the same diagonal pixel backdrop, chamfered focus cards, responsive
width, and type-colour language.

## Development

From the Gen1Recomp repository root:

```sh
python3 tools/modkit.py validate mods/modern_pc_ui
luajit mods/modern_pc_ui/tests/modern_pc_ui_test.lua
```

This package contains no ROM-derived assets. Pokémon names and imagery are
trademarks of their respective owners; this is an unofficial fan-made mod.
