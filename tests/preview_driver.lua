-- Visual smoke test. Enable Modern PC UI, then run from the repository root:
--   SHOT_DIR=/tmp/modern-pc-ui \
--   POKEPORT_DRIVER=mods/modern_pc_ui/tests/preview_driver.lua \
--   POKEPORT_IDENTITY=modern-pc-preview POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Boxes = require("src.pokemon.Boxes")
  local PaletteFX = require("src.render.PaletteFX")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-pc-ui"

  love.window.setMode(1280, 720, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")

  local function make(species, level, nickname)
    local mon = Pokemon.new(game.data, species, level)
    mon.nickname = nickname
    return mon
  end

  game.save.party = {
    make("PIKACHU", 24, "SPARK"),
    make("IVYSAUR", 22),
    make("CHARMELEON", 23),
    make("WARTORTLE", 22),
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
  game.save.boxes[2] = {
    make("SANDSHREW", 12), make("CLEFAIRY", 15), make("GROWLITHE", 18),
  }

  while game.stack:top() do game.stack:pop() end
  local screen = Screens.push(game, "BoxMenu")
  U.wait(12)
  U.log(screen.modernPCUI and "PASS modern PC is active"
    or "FAIL modern PC was not registered")
  U.shot(game, DIR .. "/modern_pc_workspace.png")

  -- Carry Eevee directly into the open party position.
  screen.boxIndex = 1
  screen:modernPCPickOrDrop()
  screen.region, screen.partyIndex = "party", 6
  U.wait(8)
  U.shot(game, DIR .. "/modern_pc_carrying.png")
  screen:modernPCPickOrDrop()
  U.wait(8)
  U.shot(game, DIR .. "/modern_pc_party_transfer.png")

  -- Exercise a selected party icon against the narrow black card frame.
  screen.region, screen.partyIndex = "party", 3
  U.wait(8)
  U.shot(game, DIR .. "/modern_pc_party_frame_clamp.png")

  -- The action card retains the less frequent management tools.
  screen.region, screen.partyIndex = "party", 1
  game.input.pressQueue[#game.input.pressQueue + 1] = "start"
  U.wait(8)
  U.shot(game, DIR .. "/modern_pc_actions.png")
  screen.actions = nil

  -- Carry a Pokémon while using the visible two-way box selector.
  screen.region, screen.boxIndex = "box", 1
  screen:modernPCPickOrDrop()
  local writeSave = game.writeSave
  game.writeSave = function() end -- isolated preview has no overworld map
  U.tap(game, "select")
  U.wait(4)
  U.shot(game, DIR .. "/modern_pc_box_selector.png")
  U.tap(game, "a")
  U.wait(4)
  U.shot(game, DIR .. "/modern_pc_all_boxes.png")
  U.tap(game, "b")
  U.tap(game, "right")
  U.tap(game, "down")
  game.writeSave = writeSave
  screen.boxIndex = 4
  U.wait(8)
  U.shot(game, DIR .. "/modern_pc_cross_box.png")
  screen:modernPCPickOrDrop()

  -- Release keeps the question and consequence visible together above the
  -- wide PC instead of scrolling the Pokémon's name out of the prompt.
  screen.region, screen.boxIndex = "box", 1
  U.tap(game, "start")
  screen.actionIndex = 3
  U.tap(game, "a")
  U.wait(120)
  U.shot(game, DIR .. "/modern_pc_release_confirmation.png")
  while game.stack:top() ~= screen do game.stack:pop() end

  -- A medium 4:3-ish desktop window still uses the redesigned workspace.
  love.window.setMode(820, 600, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  U.wait(12)
  U.shot(game, DIR .. "/modern_pc_medium_workspace.png")

  -- Portrait phones use a tall 160px-wide box, party, and detail workspace.
  screen.held = nil
  screen.region, screen.partyIndex = "party", 3
  love.window.setMode(480, 1024, {
    resizable = true, minwidth = 160, minheight = 144,
  })
  U.wait(12)
  U.shot(game, DIR .. "/modern_pc_phone_portrait.png")

  -- Classic 160x144 uses the same compact arrangement as portrait phones.
  love.window.setMode(640, 576, {
    resizable = true, minwidth = 640, minheight = 576,
  })
  U.wait(12)
  U.shot(game, DIR .. "/modern_pc_narrow_workspace.png")
  U.tap(game, "select")
  U.wait(4)
  U.shot(game, DIR .. "/modern_pc_narrow_box_selector.png")
  U.tap(game, "a")
  U.wait(4)
  U.shot(game, DIR .. "/modern_pc_narrow_all_boxes.png")
end
