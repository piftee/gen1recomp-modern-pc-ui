-- Visual integration proof for Kanto Gear's combined-screen viewport.
-- Install Kanto Gear and Modern PC UI, then run from the engine root:
--   SHOT_DIR=/tmp/modern-pc-kanto \
--   POKEPORT_DRIVER=mods/modern_pc_ui/tests/kanto_gear_preview_driver.lua \
--   POKEPORT_VERSION=red POKEPORT_TOUCH=0 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Boxes = require("src.pokemon.Boxes")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-pc-kanto"

  local function make(species, level)
    return Pokemon.new(game.data, species, level)
  end

  local options = game.mods.modOptions
  options.kanto_gear = options.kanto_gear or {}
  local gear = options.kanto_gear
  gear.display_mode = "combined"
  gear.combined_layout = "auto"
  gear.combined_primary = "game"
  gear.secondary_size = "auto"
  gear.bottom_safe_area = 0
  for _, key in ipairs({ "display_mode", "combined_layout",
      "combined_primary", "secondary_size", "bottom_safe_area" }) do
    game.mods.events:emit("mod.options_changed", {
      mod = "kanto_gear", key = key, value = gear[key],
    })
  end

  game.save.party = {
    make("PIKACHU", 24), make("IVYSAUR", 22),
    make("CHARMELEON", 23), make("WARTORTLE", 22),
    make("PIDGEOTTO", 20),
  }
  Boxes.ensure(game.save)
  game.save.currentBox = 1
  game.save.boxes[1] = {
    make("EEVEE", 18), make("VULPIX", 17), make("PSYDUCK", 16),
    make("ODDISH", 15), make("MAGNEMITE", 19), make("CUBONE", 20),
    make("GASTLY", 18), make("DRATINI", 21), make("JIGGLYPUFF", 14),
    make("SCYTHER", 25), make("LAPRAS", 26), make("ABRA", 13),
  }

  while game.stack:top() do game.stack:pop() end
  local screen = Screens.push(game, "BoxMenu")

  love.window.setMode(1280, 720, {
    resizable = true, minwidth = 160, minheight = 144,
  })
  U.wait(20)
  local landscapeW, landscapeH = screen:uiSize()
  U.log((landscapeW <= 224 and landscapeH == 144)
      and "PASS Kanto landscape uses the allocated game panel"
      or ("FAIL Kanto landscape PC size " .. tostring(landscapeW)
        .. "x" .. tostring(landscapeH)))
  U.shot(game, DIR .. "/modern_pc_kanto_landscape.png")

  love.window.setMode(480, 1024, {
    resizable = true, minwidth = 160, minheight = 144,
  })
  U.wait(20)
  U.shot(game, DIR .. "/modern_pc_kanto_portrait.png")
end
