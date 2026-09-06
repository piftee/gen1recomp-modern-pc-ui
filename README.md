# Modern PC UI

> [!IMPORTANT]
> **This standalone mod has been superseded by [Modern UI Suite](https://github.com/piftee/gen1recomp-modern-ui-suite).** It remains available for existing installs, but future fixes and features will be maintained in the suite. Disable this standalone mod before enabling the suite; the suite imports its saved settings automatically.

Crystal Animated Sprites with Shiny Visuals 2.0.2 compatibility: Gen 2
PC previews retain the companion's normal/shiny colours and animations.
Native artwork keeps its cartridge palettes. Verified in Gold, Silver and Crystal.

Modern PC UI turns Someone's PC into one party-and-box workspace. It keeps
Pokémon Red's pixel font, menu icons, palettes, cries, box capacity, and save
format while adopting the direct manipulation used by newer Pokémon games.

Gold, Silver, and Crystal open directly into that same workspace, with their
native fourteen boxes, held items, Eggs and Mail records underneath. There is
no intermediate Withdraw/Deposit/Move chooser.

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
intentionally handheld-era: all graphics come from the player's own game data and the
interface is built from crisp pixels and four-shade palette ramps.

Reference material:

- [Sword and Shield's official Pokémon Boxes overview](https://swordshield.pokemon.com/en-gb/gameplay/features-adventure/)
- [Scarlet and Violet party-and-box workflow](https://dotesports.com/pokemon/news/how-to-access-your-pc-boxes-in-pokemon-scarlet-and-violet)
- [Legends: Arceus Pastures controls](https://game8.co/games/Pokemon-Legends-Arceus/archives/353418)

## Gen 2 catches

When your party and current box are full, throwing a ball at an ordinary wild
Pokémon automatically selects the next box with a free slot. Full boxes are
skipped, and the search wraps from Box 14 to Box 1. The new box stays selected
for subsequent catches and PC visits, including when a throw fails.

An open party slot still takes priority. If every box is full, the game refuses
before spending a ball or a battle turn. Captures use the native Gen 2 storage
flow, preserving held items, ownership, nickname prompts and Pokédex records.
Trainer battles, the Bug-Catching Contest and the catching tutorial retain
their original behavior.

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

## Navigation and group selections

Party rows wrap from the first occupied member to the last and back. While
carrying or selecting a group, all six target slots remain reachable. The
compact layout keeps its usual spatial Right-to-box movement by default.

**Box Exclusive** defaults to Off. Enable it to wrap Left/Right within the
current box row instead of browsing adjacent boxes; vertical edges connect
the box and party. SELECT still opens deliberate box switching. In the suite,
this preference appears as **BOX ONLY** on the PC settings page.

Choose **START → MULTIPLE SELECTIONS** to mark the focused Pokémon, then press
A on more Pokémon from that same side. Box selections can span several boxes.
A on an empty target places the group in selection order; A on the opposite
side swaps against its occupied slots. For six selected boxed Pokémon,
**START → SWAP WHOLE PARTY** exchanges the complete party. B cancels all marks.
There is no group Release command.

Group operations validate the complete result before changing storage. Capacity,
last-usable-party, Egg and Gen 2 Mail restrictions apply to the whole operation;
a preparation error restores the original Pokémon, moves, items and Mail.
Empty gaps are never stored: a far-empty target appends to the actual list.

## Gen 2 Mail and held items

Select a party Pokémon and press START, then **ITEM** for native Give/Take,
or **MAIL** for native Read/Take. Giving stationery opens the game's Mail
composer. Taking Mail lets you preserve the letter in the PC mailbox; putting
it in the Bag instead uses the native warning that the message will be lost.
**MAILBOX** is always available from START, including on an empty box slot,
and supports native Read, Put in Pack, and Attach actions.

Letters follow their owners when the party is reordered. A Mail carrier must
remove its Mail before entering a box or being released, but it does not
prevent unrelated Pokémon from moving. Full-mailbox failures leave both the
letter and stationery untouched. Ordinary held items stay with boxed Pokémon.

The last usable, non-Egg party member is protected unless an occupied swap
provides a usable replacement. Native storage healing is retained. Changes
are saved when closing the workspace; if saving fails, the PC stays open so
you can retry. Gen 2 Summary and Item/Mail screens use the live registered
controllers, including their suite replacements when enabled.

## Compatibility

Modern PC UI uses Gen1Recomp's shared Pokémon icon renderer, so species icons,
runtime icon hooks, and compatible icon replacement mods continue to work.
Authored full-colour replacements—including **Unique Menu Icons** and icon
wrappers used by **Wilds of Kanto**—are protected from the PC's type palettes in
party and box slots. Protection is clipped around the live action popup so
covered icons cannot repaint the popup. The wide detail rail uses the same
`battle` front-sprite selection as combat instead, preventing a menu icon from
being mistaken for the Pokémon's in-battle appearance.

Native Gen 2 portrait gaps use reviewed, exact-image cutouts rather than a
global white-color key. Full decoded-image checks preserve white markings,
eyes and highlights and skip different replacement artwork or alpha. The
original source sprites and shared/native renderers are never modified.

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

Kanto Gear 3.x combined-display layouts are also supported. Modern PC UI sizes
itself from the game viewport Kanto Gear leaves available, so a side-by-side
landscape layout stays readable instead of fitting an extra-wide PC canvas
inside the narrower game panel. Portrait, overlay, and separate-screen layouts
retain their existing behaviour.

## Development

From the Gen1Recomp repository root:

```sh
python3 tools/modkit.py validate mods/modern_pc_ui
luajit mods/modern_pc_ui/tests/modern_pc_ui_test.lua
```

The native Gen 2 driver is `tests/gen2_workspace_driver.lua` in this mod.
Run it through `POKEPORT_DRIVER` on a Gen 2-capable runtime with `PC_REPO`
pointing to this checkout and an isolated `POKEPORT_IDENTITY` containing an
imported ROM cache and this enabled mod (or the suite). It creates fixture
saves, so never use your real game identity. Optional `SHOT_DIR` captures the
compact, wide, portrait and native-child screens. Runtime 0.2.56 on Gold,
Silver, and Crystal passed 107 standalone checks and 109 suite checks per game.

This package contains no ROM-derived assets. Pokémon names and imagery are
trademarks of their respective owners; this is an unofficial fan-made mod.
