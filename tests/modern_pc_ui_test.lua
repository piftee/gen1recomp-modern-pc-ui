-- Standalone: luajit mods/modern_pc_ui/tests/modern_pc_ui_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Assets = require("src.render.Assets")
local Boxes = require("src.pokemon.Boxes")
local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local PartyMenu = require("src.ui.PartyMenu")
local Pokemon = require("src.pokemon.Pokemon")

local data = T.fixtures.fresh()
data.icons = {
  icons = {}, byDex = {},
  bySpecies = {
    FIXMON_A = {
      image = "mods/companion_sprite_pack/assets/fixmon_a_icon.png",
      frames = 2,
    },
  },
}
data.palettes = {
  palettes = {
    BLUEMON = {
      { 255, 255, 255 }, { 150, 180, 235 },
      { 55, 95, 175 }, { 0, 0, 0 },
    },
    MEWMON = {
      { 255, 255, 255 }, { 210, 185, 235 },
      { 115, 75, 160 }, { 0, 0, 0 },
    },
    REDMON = {
      { 255, 255, 255 }, { 240, 160, 145 },
      { 175, 45, 35 }, { 0, 0, 0 },
    },
    GREENMON = {
      { 255, 255, 255 }, { 150, 220, 150 },
      { 30, 130, 45 }, { 0, 0, 0 },
    },
    CYANMON = {
      { 255, 255, 255 }, { 165, 220, 230 },
      { 45, 135, 160 }, { 0, 0, 0 },
    },
    YELLOWMON = {
      { 255, 255, 255 }, { 245, 225, 120 },
      { 185, 145, 25 }, { 0, 0, 0 },
    },
  },
  pokemon = {},
}
Font.load(data)
local previousMode = PaletteFX.mode
PaletteFX.setMode("gbc")

local run = T.sdk.loadMod("mods/modern_pc_ui", { data = data, dev = true })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
require("src.core.Strings").load(run.data)

local record = run.data.screens and run.data.screens.BoxMenu
T.check(type(record) == "table" and type(record.new) == "function",
  "the BoxMenu replacement is registered")

local stack = { states = {} }
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end
function input:isDown() return false end

local function mon(species, level)
  return Pokemon.new(run.data, species, level or 10)
end

local partyA, partyB = mon("FIXMON_A", 12), mon("FIXMON_B", 11)
local boxedC, boxedA, boxedB =
  mon("FIXMON_C", 9), mon("FIXMON_A", 8), mon("FIXMON_B", 7)
boxedC.stats = nil -- imported cartridge box_struct shape

local save = {
  player = { name = "RED", rival = "BLUE" },
  party = { partyA, partyB },
  currentBox = 1,
  boxes = {},
  flags = {}, inventory = {},
}
for index = 1, Boxes.COUNT do save.boxes[index] = {} end
save.boxes[1] = { boxedC, boxedA }
save.boxes[2] = { boxedB }

local game = {
  data = run.data, save = save, stack = stack, input = input, writes = 0,
  writeSave = function(self) self.writes = self.writes + 1 end,
}
local screen = record.new(game)
stack:push(screen)

T.check(screen.modernPCUI == true, "the modern PC presentation is active")
T.eq(screen.modernPCLayout, "party-and-box",
  "the combined workspace identifies its layout")
T.check(screen.holdsUIAnchors == true,
  "native Summary and confirmation overlays stay attached to the PC surface")
T.eq(screen.region, "box", "the cursor starts in the active box")

local function press(key)
  input.pressed[key] = true
  screen:update(0)
  input.pressed[key] = nil
end

-- Direct box -> party placement, including the native box-mon stat rebuild.
screen.boxIndex = 1
T.check(screen:modernPCPickOrDrop(), "A picks up a boxed Pokémon")
T.eq(screen.held.mon, boxedC, "the carried Pokémon keeps its identity")
screen.region, screen.partyIndex = "party", 3
T.check(screen:modernPCPickOrDrop(), "A places it in an empty party slot")
T.eq(#save.party, 3, "the party grows after direct placement")
T.eq(#save.boxes[1], 1, "the source box shrinks after direct placement")
T.eq(save.party[3], boxedC, "the chosen party slot receives the boxed Pokémon")
T.check(type(boxedC.stats) == "table" and boxedC.stats.hp ~= nil,
  "an imported boxed Pokémon gets party stats before it is displayed there")

-- A carried Pokémon can cross boxes in either direction through the visible
-- header selector, then return to the grid without losing the carry.
screen.region, screen.boxIndex = "box", 1
local crossBoxMon = save.boxes[1][1]
T.check(screen:modernPCPickOrDrop(), "a second boxed Pokémon can be carried")
press("select")
T.check(screen.boxSwitching,
  "SELECT focuses the box header while a Pokémon is carried")
T.eq(screen.held.mon, crossBoxMon,
  "entering the box selector preserves the carried Pokémon")
press("left")
T.eq(save.currentBox, Boxes.COUNT,
  "LEFT wraps backward from the first box to the last box")
press("right")
T.eq(save.currentBox, 1,
  "RIGHT returns forward from the last box to the first box")
press("right")
T.eq(save.currentBox, 2, "RIGHT opens the next box")
T.eq(game.writes, 3, "each box change retains the native save checkpoint")
press("down")
T.check(not screen.boxSwitching and screen.region == "box",
  "DOWN returns from the header to the box grid")
T.eq(screen.held.mon, crossBoxMon,
  "leaving the box selector keeps the cross-box move active")
screen.boxIndex = 2
T.check(screen:modernPCPickOrDrop(), "the carried Pokémon drops in another box")
T.eq(#save.boxes[1], 0, "the old box loses the cross-box Pokémon")
T.eq(save.boxes[2][2], crossBoxMon,
  "the next box receives the carried Pokémon at the chosen position")

-- Occupied party/box targets swap even when the party is full.
while #save.party < 6 do
  save.party[#save.party + 1] = mon("FIXMON_A", 6 + #save.party)
end
screen.region, screen.boxIndex = "box", 1
local incoming, outgoing = save.boxes[2][1], save.party[1]
T.check(screen:modernPCPickOrDrop(), "an occupied box slot can be picked up")
screen.region, screen.partyIndex = "party", 1
T.check(screen:modernPCPickOrDrop(), "an occupied full-party slot can be swapped")
T.eq(save.party[1], incoming, "the boxed Pokémon enters the selected party slot")
T.eq(save.boxes[2][1], outgoing, "the displaced party Pokémon enters the box")
T.eq(#save.party, 6, "a swap does not grow the full party")

-- Same-box movement swaps occupied positions without changing list shape.
save.currentBox = 2
screen.region, screen.boxIndex = "box", 1
local first, second = save.boxes[2][1], save.boxes[2][2]
screen:modernPCPickOrDrop()
screen.boxIndex = 2
screen:modernPCPickOrDrop()
T.eq(save.boxes[2][1], second, "same-box move swaps the source position")
T.eq(save.boxes[2][2], first, "same-box move swaps the destination position")
screen.boxIndex = 1
local movedToEmpty = save.boxes[2][1]
screen:modernPCPickOrDrop()
screen.boxIndex = 20
T.check(screen:modernPCPickOrDrop(),
  "any visible empty box slot accepts a carried Pokémon")
T.eq(save.boxes[2][#save.boxes[2]], movedToEmpty,
  "a far empty slot maps safely to the compact list's next open position")

-- The last-party rule is enforced during direct movement and keeps the carry
-- active so the player may choose a valid occupied swap instead.
local only = mon("FIXMON_C", 15)
save.party = { only }
screen.region, screen.partyIndex = "party", 1
screen:modernPCPickOrDrop()
screen.region, screen.boxIndex = "box", #save.boxes[2] + 1
T.check(not screen:modernPCPickOrDrop(),
  "the last party Pokémon cannot be placed into an empty box slot")
T.eq(save.party[1], only, "the rejected move leaves the party unchanged")
T.eq(screen.held.mon, only, "the rejected move keeps the Pokémon carried")

press("b")
T.eq(screen.held, nil, "B cancels a carried Pokémon without mutating storage")

-- Quick transfer provides the modern one-step path when exact placement is
-- unimportant, with the same capacity safeguards.
save.party = { mon("FIXMON_A", 10), mon("FIXMON_B", 10) }
save.boxes[2] = { mon("FIXMON_C", 10) }
screen.region, screen.partyIndex = "party", 2
T.check(screen:modernPCQuickTransfer(), "quick transfer sends party to box")
T.eq(#save.party, 1, "quick deposit removes one party member")
T.eq(#save.boxes[2], 2, "quick deposit appends to the active box")

local imported = save.boxes[2][1]
imported.stats = nil
screen.region, screen.boxIndex = "box", 1
T.check(screen:modernPCQuickTransfer(), "quick transfer adds box to party")
T.eq(save.party[#save.party], imported,
  "quick withdrawal appends the selected Pokémon to the party")
T.check(imported.stats and imported.stats.hp,
  "quick withdrawal derives missing party stats")

while #save.party < 6 do
  save.party[#save.party + 1] = mon("FIXMON_A", 5)
end
screen.region, screen.boxIndex = "box", 1
T.check(not screen:modernPCQuickTransfer(),
  "quick withdrawal refuses a seventh party member")

-- START is reserved for actions on the selected Pokémon. Box navigation lives
-- in the visible header selector rather than being duplicated in this menu.
save.party = { mon("FIXMON_A", 10), mon("FIXMON_B", 10) }
screen.region, screen.partyIndex = "party", 1
press("start")
local labels = {}
for _, entry in ipairs(screen.actions or {}) do labels[#labels + 1] = entry.label end
T.eq(table.concat(labels, "|"),
  "SUMMARY|SEND TO BOX|RELEASE|CANCEL",
  "START keeps only actions for the selected Pokémon")
press("b")
T.eq(screen.actions, nil, "B closes the action card")

screen.region, screen.boxIndex = "box", 20
press("start")
T.eq(screen.actions, nil,
  "START does not open an action card for an empty slot")
T.eq(screen.status, "That slot is empty.",
  "an empty slot explains why no Pokémon actions opened")

-- Release copy must fit the native two-line dialogue area so the subject of
-- the YES/NO question never scrolls away before the choice appears.
screen.region, screen.boxIndex = "box", 1
press("start")
screen.actionIndex = 3
press("a")
local releasePrompt = stack:top()
T.check(releasePrompt ~= screen and releasePrompt.pages ~= nil,
  "RELEASE opens the native confirmation prompt")
local firstReleasePage = releasePrompt.pages and releasePrompt.pages[1] or {}
T.eq(#firstReleasePage, 2,
  "the release warning fits without scrolling its first line away")
T.check(tostring(firstReleasePage[1] or ""):find("Release", 1, true) ~= nil,
  "the visible release question keeps the Pokémon action in context")
stack:pop()

-- UP from the top box row is a second discoverable way into the selector;
-- B leaves that mode without closing the PC or changing the cursor region.
screen.region, screen.boxIndex = "box", 1
press("up")
T.check(screen.boxSwitching, "UP from the first box row focuses the header")
press("b")
T.check(not screen.boxSwitching and stack:top() == screen,
  "B leaves the box selector without closing the PC")

screen.region, screen.partyIndex = "party", 1
press("select")
press("right")
press("a")
T.check(not screen.boxSwitching and screen.region == "party",
  "browsing boxes without a carry returns focus to the original party panel")

-- Responsive and compact layouts both keep every panel on one native-pixel
-- surface and draw without a ROM-backed icon atlas in the SDK fixture.
local graphics = love.graphics
local realDimensions = graphics.getPixelDimensions
graphics.getPixelDimensions = function() return 1280, 720 end
local wideW, wideH = screen:uiSize()
T.eq(wideW, 256, "a 16:9 window exposes a 256x144 PC workspace")
T.eq(wideH, 144, "the responsive PC keeps the Game Boy screen height")
local wideLayout = screen:modernPCLayoutInfo()
T.check(not wideLayout.compact and wideLayout.detail.x > wideLayout.box.x,
  "widescreen adds a dedicated detail rail to the right of the box")
local wideOK, wideErr = pcall(screen.draw, screen)
T.check(wideOK, "the widescreen PC draws headlessly: " .. tostring(wideErr))

-- Authored species icons and wrapper-supplied icon claims remain full colour
-- in party slots, box slots, and the enlarged detail rail. Claims are held
-- until the action card is complete and clipped around its live geometry.
local realDrawIcon = PartyMenu.drawIcon
local realMarkTrueColor = PaletteFX.markTrueColor
local colorMarks = {}
graphics.getPixelDimensions = function() return 1920, 720 end
PartyMenu.drawIcon = function(_, drawn, x, y)
  if drawn.species == "FIXMON_B" then
    PaletteFX.markTrueColor(x, y, 16, 16)
  end
  return true
end
PaletteFX.markTrueColor = function(x, y, w, h)
  colorMarks[#colorMarks + 1] = { x = x, y = y, w = w, h = h }
end
screen.region, screen.partyIndex = "party", 1
screen.actions = nil
local colorOK, colorErr = pcall(screen.draw, screen)
T.check(colorOK,
  "replacement icons draw through the PC compatibility layer: "
    .. tostring(colorErr))
local nativeGuard, scaledGuard, wrappedClaim
for _, rect in ipairs(colorMarks) do
  if rect.w == 18 and rect.h == 18 then nativeGuard = rect end
  if rect.w == 36 and rect.h == 36 then scaledGuard = rect end
  if rect.w == 16 and rect.h == 16 then wrappedClaim = rect end
end
T.check(nativeGuard ~= nil,
  "authored party and box icons receive an 18px true-colour seam guard")
T.check(scaledGuard ~= nil,
  "the enlarged detail icon receives a correctly scaled full-colour guard")
T.check(wrappedClaim ~= nil,
  "true-colour claims made by an icon wrapper remain active")

colorMarks = {}
screen.actions = {
  { label = "SUMMARY" }, { label = "SEND TO BOX" },
  { label = "RELEASE" }, { label = "PREV BOX" },
  { label = "NEXT BOX" }, { label = "CANCEL" },
}
screen.actionIndex = 1
local popupOK, popupErr = pcall(screen.draw, screen)
T.check(popupOK,
  "the action popup draws over colour icons: " .. tostring(popupErr))
local popup = { x = 268, y = 56, w = 114, h = 80 }
for _, rect in ipairs(colorMarks) do
  local overlaps = rect.x < popup.x + popup.w
    and popup.x < rect.x + rect.w
    and rect.y < popup.y + popup.h
    and popup.y < rect.y + rect.h
  T.check(not overlaps,
    "full-colour restores never repaint pixels over the PC action popup")
end
screen.actions = nil
PartyMenu.drawIcon = realDrawIcon
PaletteFX.markTrueColor = realMarkTrueColor

graphics.getPixelDimensions = function() return 640, 576 end
local compact = screen:modernPCLayoutInfo()
T.check(compact.compact and compact.detail.y > compact.box.y + compact.box.h,
  "160px mode places a compact detail strip below party and box")
local compactOK, compactErr = pcall(screen.draw, screen)
T.check(compactOK, "the compact PC draws headlessly: " .. tostring(compactErr))
local zones = screen:sgbPalettes(game) or {}
T.check(#zones >= 7, "the PC emits base, panel, Pokémon, focus, and footer colours")
T.eq(zones[1].w, 160, "palette coverage follows the compact UI width")
graphics.getPixelDimensions = realDimensions

T.check(screen:isWideBattleLayout(),
  "the PC owns its responsive canvas while native overlays are visible")

run.release()
PaletteFX.setMode(previousMode)

-- Mirror the companion stack already supported by Modern Party UI. Gender
-- markers use public exports, Gen1 Modern UI keeps the PC renderer visible,
-- and callback-backed party utilities such as Anytime Rename remain usable
-- from the PC action card.
local compatData = T.fixtures.fresh()
compatData.icons = data.icons
compatData.palettes = data.palettes
Font.load(compatData)
PaletteFX.setMode("gbc")
local compatRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/gender_mod",
  "mods/modern_party_ui/tests/fixtures/gen1_modern_ui",
  "mods/modern_party_ui/tests/fixtures/anytime_rename",
  "mods/modern_pc_ui",
}, { data = compatData, dev = true })
T.eq(#compatRun.errors, 0,
  "loads beside Gender Mod, Gen1 Modern UI, and Anytime Rename")

local compatStack = { states = {} }
function compatStack:push(state) self.states[#self.states + 1] = state end
function compatStack:pop() return table.remove(self.states) end
function compatStack:top() return self.states[#self.states] end
local compatInput = { pressed = {} }
function compatInput:wasPressed(key) return self.pressed[key] == true end
function compatInput:isDown() return false end
local genderMon = Pokemon.new(compatRun.data, "FIXMON_A", 12)
genderMon.nickname = "NIDORAN♂"
genderMon.gender_mod = "M"
local compatSave = {
  player = { name = "RED", rival = "BLUE" },
  party = { genderMon, Pokemon.new(compatRun.data, "FIXMON_B", 10) },
  currentBox = 1, boxes = {}, flags = {}, inventory = {}, options = {},
}
for index = 1, Boxes.COUNT do compatSave.boxes[index] = {} end
local compatGame = {
  data = compatRun.data, save = compatSave, stack = compatStack,
  input = compatInput,
}
local compatRecord = compatRun.data.screens.BoxMenu
local compatScreen = compatRecord.new(compatGame)
compatStack:push(compatScreen)
compatScreen.region, compatScreen.partyIndex = "party", 1

local realFontDraw = Font.draw
local compatGlyphs, compatMarks = {}, {}
Font.draw = function(value, x, y)
  compatGlyphs[#compatGlyphs + 1] = { text = value, x = x, y = y }
  return realFontDraw(value, x, y)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  compatMarks[#compatMarks + 1] = { x = x, y = y, w = w, h = h }
end
local genderOK, genderErr = pcall(compatScreen.draw, compatScreen)
Font.draw = realFontDraw
PaletteFX.markTrueColor = realMarkTrueColor
T.check(genderOK,
  "the gender-aware PC draws: " .. tostring(genderErr))
local sawGender, sawStrippedName, sawGenderMark = false, false, false
for _, call in ipairs(compatGlyphs) do
  if call.text == "♂" then sawGender = true end
  if call.text == "NIDORAN" then sawStrippedName = true end
end
for _, rect in ipairs(compatMarks) do
  if rect.w == 8 and rect.h == 8 then sawGenderMark = true break end
end
T.check(sawGender, "Gender Mod's exported marker appears in the PC")
T.check(sawStrippedName,
  "the exported gender marker replaces the nickname's baked-in suffix")
T.check(sawGenderMark,
  "Gender Mod's colour marker is protected from the PC palette")

compatInput.pressed.start = true
compatScreen:update(0)
compatInput.pressed.start = nil
local renameIndex
for index, entry in ipairs(compatScreen.actions or {}) do
  if entry.label == "NICKNAME" then renameIndex = index break end
end
T.check(renameIndex ~= nil,
  "Anytime Rename's callback-backed party action appears in the PC")
compatScreen.actionIndex = renameIndex or 1
compatInput.pressed.a = true
compatScreen:update(0)
compatInput.pressed.a = nil
T.eq(compatStack:top() and compatStack:top().screenId, "NamingScreen",
  "the PC executes companion action callbacks without interpreting them")

local uiExports = compatRun.loader.exports.gen1_modern_ui
local registrations = uiExports and uiExports.registrations or {}
T.eq(registrations[#registrations] and registrations[#registrations].owner,
  "modern_pc_ui", "the PC registers its Gen1 Modern UI source contract")
T.check(uiExports.shouldSuppress(compatScreen) == false,
  "Gen1 Modern UI leaves the modern party-and-box canvas visible")

compatRun.release()
PaletteFX.setMode(previousMode)

-- HGSS Visual Overhaul replaces the native 16x16 menu contract with padded
-- 32x32 true-colour frames. Use controlled alpha bounds to prove that the PC
-- crops and centres the visible art, never publishes the old oversized colour
-- rectangle, and still has a safe fallback when ImageData is unavailable.
do
local hgssData = T.fixtures.fresh()
hgssData.icons = { icons = {}, byDex = {}, bySpecies = {} }
for _, species in ipairs({ "FIXMON_A", "FIXMON_B", "FIXMON_C" }) do
  hgssData.icons.bySpecies[species] = {
    image = "mods/HGSS_SPRITES/assets/icons/"
      .. species:lower() .. ".png",
    frames = 2,
    trueColor = true,
  }
end
hgssData.palettes = data.palettes
Font.load(hgssData)
PaletteFX.setMode("gbc")

local drawIconBeforeHgss = PartyMenu.drawIcon
local hgssRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/hgss_sprites",
  "mods/modern_pc_ui",
}, { data = hgssData, dev = true })
T.eq(#hgssRun.errors, 0, "loads beside HGSS Visual Overhaul 1.0.0")

local hgssSave = {
  player = { name = "RED", rival = "BLUE" },
  party = {
    Pokemon.new(hgssRun.data, "FIXMON_A", 12),
    Pokemon.new(hgssRun.data, "FIXMON_B", 11),
  },
  currentBox = 1, boxes = {}, flags = {}, inventory = {}, options = {},
}
for index = 1, Boxes.COUNT do hgssSave.boxes[index] = {} end
hgssSave.boxes[1] = { Pokemon.new(hgssRun.data, "FIXMON_C", 10) }
local hgssInput = { wasPressed = function() return false end,
  isDown = function() return false end }
local hgssGame = {
  data = hgssRun.data, save = hgssSave, input = hgssInput,
  stack = { states = {}, pop = function() end },
}
local hgssScreen = hgssRun.data.screens.BoxMenu.new(hgssGame)
hgssScreen.region, hgssScreen.partyIndex = "party", 1

local graphics = love.graphics
local oldDimensions = graphics.getPixelDimensions
local oldDraw = graphics.draw
local oldScale = graphics.scale
local oldImageData = Assets.imageData
local oldImage = Assets.image
local oldMark = PaletteFX.markTrueColor
local oldLoveImage = love.image
local fakeImage = {}
local fakeData = {}
function fakeData:getDimensions() return 32, 64 end
function fakeData:getPixel(px, py)
  local frameY = py % 32
  local opaque
  if py < 32 then
    opaque = px >= 8 and px <= 23 and frameY >= 6 and frameY <= 25
  else
    opaque = px >= 8 and px <= 23 and frameY >= 7 and frameY <= 26
  end
  return 1, 1, 1, opaque and 1 or 0
end

local fittedDraws, hgssMarks, backingFills = {}, {}, {}
local oldRectangle = graphics.rectangle
graphics.getPixelDimensions = function() return 1920, 720 end
Assets.imageData = function(path)
  if tostring(path):lower():find("hgss", 1, true) then return fakeData end
  return oldImageData(path)
end
Assets.image = function(path)
  if tostring(path):lower():find("hgss", 1, true) then return fakeImage end
  return oldImage(path)
end
graphics.draw = function(image, quad, x, y, rotation, sx, sy, ...)
  if image == fakeImage then
    fittedDraws[#fittedDraws + 1] = {
      quad = quad, x = x, y = y, sx = sx or 1, sy = sy or sx or 1,
    }
  end
  return oldDraw(image, quad, x, y, rotation, sx, sy, ...)
end
graphics.rectangle = function(mode, x, y, w, h, ...)
  if mode == "fill" and ((w == 15 and h == 18)
      or (w == 26 and h == 32)) then
    backingFills[#backingFills + 1] = { x = x, y = y, w = w, h = h }
  end
  return oldRectangle(mode, x, y, w, h, ...)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  hgssMarks[#hgssMarks + 1] = { x = x, y = y, w = w, h = h }
end

local fittedOK, fittedErr = pcall(hgssScreen.draw, hgssScreen)
T.check(fittedOK,
  "alpha-fitted HGSS icons draw headlessly: " .. tostring(fittedErr))
T.eq(#fittedDraws, 4,
  "party, box, and detail views use the cropped HGSS renderer")
T.eq(#hgssRun.loader.exports.HGSS_SPRITES.calls, 0,
  "the fitted path bypasses HGSS's oversized shared 32px renderer")

local wideLayout = hgssScreen:modernPCLayoutInfo()
local firstParty = wideLayout.party
local innerW, innerH = firstParty.w - 4, firstParty.h - 4
local rectX = firstParty.x + 2
local rectY = firstParty.y + 2
local rectH = math.floor(innerH / firstParty.rows)
local iconX = rectX + 2
local iconY = rectY + math.max(0, math.floor((rectH - 16) / 2))
local firstDraw = fittedDraws[1]
local firstW = firstDraw.quad.w * firstDraw.sx
local firstH = firstDraw.quad.h * firstDraw.sy
T.check(firstW <= 18 and firstH <= 18,
  "HGSS party art stays inside the 18px slot footprint")
T.check(math.abs((firstDraw.x + firstW / 2) - (iconX + 8)) <= 0.6
    and math.abs((firstDraw.y + firstH / 2) - (iconY + 8)) <= 0.6,
  "transparent HGSS padding does not shift the centred party sprite")

local detailDraw = fittedDraws[#fittedDraws]
local detailW = detailDraw.quad.w * detailDraw.sx
local detailH = detailDraw.quad.h * detailDraw.sy
T.check(detailW <= 32 and detailH <= 32,
  "the enlarged HGSS detail portrait stays inside its 32px footprint")
local oversizedMark = false
for _, rect in ipairs(hgssMarks) do
  if rect.w > 32 or rect.h > 32
      or (rect.w == 32 and rect.h == 32) then
    oversizedMark = true
  end
end
T.check(not oversizedMark,
  "HGSS no longer restores a grey or oversized full-frame rectangle")
T.eq(#backingFills, 0,
  "cropped HGSS icons no longer restore rectangular panel backings")
T.check(#hgssMarks > #fittedDraws,
  "HGSS true-colour protection follows opaque pixel runs")

-- HGSS commonly authors its animation as a one-pixel shift inside the same
-- canvas. Both frames must use one fitted envelope or centring cancels it out.
local beforeAnimated = #fittedDraws
hgssScreen.blink = 5
local animatedOK, animatedErr = pcall(hgssScreen.draw, hgssScreen)
T.check(animatedOK,
  "the second fitted HGSS frame draws: " .. tostring(animatedErr))
local animated = fittedDraws[beforeAnimated + 1]
local animatedW = animated.quad.w * animated.sx
local animatedH = animated.quad.h * animated.sy
T.check(animated.quad.y >= 32 and animatedW <= 18 and animatedH <= 18,
  "the selected icon advances to the second source frame")
for i = beforeAnimated + 2, beforeAnimated + 4 do
  T.check(fittedDraws[i] and fittedDraws[i].quad.y < 32,
    "unselected PC and duplicate detail icons stay on the resting frame")
end
T.check(math.abs((animated.x + animatedW / 2) - (iconX + 8)) <= 0.6
    and math.abs((animated.y + animatedH / 2) - (iconY + 8)) <= 0.6,
  "the shared animation envelope remains centred")
T.check(animated.quad.x == firstDraw.quad.x
    and animated.quad.y % 32 == firstDraw.quad.y % 32
    and animated.quad.w == firstDraw.quad.w
    and animated.quad.h == firstDraw.quad.h
    and animated.x == firstDraw.x and animated.y == firstDraw.y
    and animated.sx == firstDraw.sx and animated.sy == firstDraw.sy,
  "PC frames retain HGSS's authored internal bob instead of re-centring it")

-- Box records loaded from a save may not contain calculated battle stats.
-- The selected record must still animate using its fallback pace.
hgssSave.boxes[1][1].stats = nil
hgssSave.boxes[1][1].hp = nil
hgssScreen.region, hgssScreen.boxIndex = "box", 1
local beforeStatless = #fittedDraws
hgssScreen.blink = 32
local statlessOK, statlessErr = pcall(hgssScreen.draw, hgssScreen)
T.check(statlessOK,
  "a statless boxed HGSS icon animates: " .. tostring(statlessErr))
local statlessBoxDraw = fittedDraws[beforeStatless + 3]
T.check(statlessBoxDraw and statlessBoxDraw.quad.y >= 32,
  "a highlighted stored Pokémon without battle stats still uses frame two")
for _, offset in ipairs({ 1, 2, 4 }) do
  local draw = fittedDraws[beforeStatless + offset]
  T.check(draw and draw.quad.y < 32,
    "only the highlighted statless box icon animates")
end

-- Compatibility wrappers can redraw the PC without advancing BoxMenu.update.
-- The wall clock must keep the highlighted icon moving in that situation.
local oldGetTime = love.timer.getTime
love.timer.getTime = function() return 0.6 end
hgssScreen.blink = 0
local beforeClock = #fittedDraws
local clockOK, clockErr = pcall(hgssScreen.draw, hgssScreen)
love.timer.getTime = oldGetTime
T.check(clockOK,
  "wall-clock HGSS animation draws: " .. tostring(clockErr))
for offset = 1, 4 do
  local draw = fittedDraws[beforeClock + offset]
  T.check(draw and ((offset == 3 and draw.quad.y >= 32)
      or (offset ~= 3 and draw.quad.y < 32)),
    "the PC wall clock advances only the highlighted fitted HGSS icon")
end

-- If a host cannot expose ImageData, reduce the complete HGSS source to the
-- available cells and transform its true-colour claim by the same amount.
hgssSave.party = { Pokemon.new(hgssRun.data, "FIXMON_C", 9) }
hgssSave.boxes[1] = {}
hgssScreen.blink = 0
local fallbackMarks, fallbackScales = {}, {}
love.image = nil
graphics.scale = function(x, y)
  fallbackScales[#fallbackScales + 1] = { x = x, y = y }
  return oldScale(x, y)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  fallbackMarks[#fallbackMarks + 1] = { x = x, y = y, w = w, h = h }
end
local fallbackOK, fallbackErr = pcall(hgssScreen.draw, hgssScreen)
T.check(fallbackOK,
  "the HGSS no-ImageData fallback draws: " .. tostring(fallbackErr))
local sawSlotScale = false
for _, call in ipairs(fallbackScales) do
  if math.abs(call.x - 18 / 32) < 0.0001
      and math.abs(call.y - 18 / 32) < 0.0001 then
    sawSlotScale = true
  end
end
T.check(sawSlotScale,
  "the fallback reduces a 32px HGSS source to the 18px slot")
for _, rect in ipairs(fallbackMarks) do
  T.check(rect.w <= 32 and rect.h <= 32,
    "fallback HGSS colour claims never exceed their target cell")
end

love.image = oldLoveImage
graphics.getPixelDimensions = oldDimensions
graphics.draw = oldDraw
graphics.scale = oldScale
graphics.rectangle = oldRectangle
Assets.imageData = oldImageData
Assets.image = oldImage
PaletteFX.markTrueColor = oldMark
PartyMenu.drawIcon = drawIconBeforeHgss
hgssRun.release()
PaletteFX.setMode(previousMode)
end

T.finish()
