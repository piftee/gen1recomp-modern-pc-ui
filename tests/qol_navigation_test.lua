package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Pokemon = require("src.pokemon.Pokemon")
for _, modId in ipairs({ "modern_pc_ui", "modern_ui_suite" }) do
  local run = T.sdk.loadMod("mods/" .. modId, { data = T.fixtures.fresh(), dev = true })
  T.eq(#run.errors, 0, "QoL fixture loads " .. modId)
  require("src.core.Strings").load(run.data)
  local input = { pressed = {} }
  function input:wasPressed(k) return self.pressed[k] == true end
  local stack = { states = {} }
  function stack:push(s) self.states[#self.states + 1] = s end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  local width, height = 256, 144
  local function mon() return Pokemon.new(run.data, "FIXMON_A", 20) end
  local game = { data = run.data, input = input, stack = stack,
    renderer = { uiSize = function() return width, height end },
    writeSave = function() return true end }
  local function option(value)
    run.loader.modOptions[modId] = run.loader.modOptions[modId] or {}
    run.loader.modOptions[modId][modId == "modern_ui_suite" and "pc.box_exclusive" or "box_exclusive"] = value
  end
  local function fixture(n)
    local s = { party = {}, boxes = {}, currentBox = 1,
      player = { name = "RED" }, options = {}, flags = {}, inventory = {} }
    for i = 1, 12 do s.boxes[i] = {} end
    for i = 1, n or 3 do s.party[i] = mon() end
    for i = 1, 6 do s.boxes[1][i] = mon() end
    game.save = s
    local screen = run.data.screens.BoxMenu.new(game)
    stack.states = { screen }; option(false)
    return screen, s
  end
  local function press(screen, key)
    input.pressed[key] = true; screen:update(0); input.pressed[key] = nil
  end
  local function action(screen, kind)
    press(screen, "start")
    for i, item in ipairs(screen.actions or {}) do
      if item.action == kind then screen.actionIndex = i; press(screen, "a"); return end
    end
    error("missing QoL action " .. kind)
  end
  for n = 1, 6 do
    local screen, s = fixture(n)
    for _, size in ipairs({ { 256, 144 }, { 160, 256 } }) do
      width, height = size[1], size[2]
      screen.region, screen.partyIndex = "party", 1
      press(screen, "left"); T.eq(screen.partyIndex, n, "wrap to actual final party member")
      press(screen, "right"); T.eq(screen.partyIndex, 1, "wrap to first party member")
      screen.held = { mon = s.party[1] }
      press(screen, "left"); T.eq(screen.partyIndex, 6, "carrying keeps empty slot six reachable")
      screen.held = nil
    end
  end
  for _, size in ipairs({ { 160, 144 }, { 256, 144 }, { 160, 256 } }) do
    width, height = size[1], size[2]
    local screen, s = fixture()
    if width == 160 and height == 144 then
      screen.region, screen.partyIndex = "party", 2
      press(screen, "right"); T.eq(screen.region, "box", "compact OFF keeps spatial Right-to-box")
    end
    option(true)
    for i = 1, 20 do
      screen.region, screen.boxIndex = "box", i
      press(screen, "left")
      local expected = math.floor((i - 1) / 5) * 5 + ((i - 2) % 5) + 1
      T.eq(screen.boxIndex, expected, "exclusive left maps every box slot")
      T.eq(s.currentBox, 1, "exclusive movement never changes current box")
      press(screen, "right"); T.eq(screen.boxIndex, i, "right reverses exclusive left")
    end
    screen.boxIndex = 1; press(screen, "up")
    T.eq(screen.region, "party", "top box edge enters party")
    T.check(not screen.boxSwitching, "exclusive edge does not open selector")
    press(screen, "select"); press(screen, "right"); press(screen, "b")
    T.eq(s.currentBox, 2, "Select deliberately opens another box")
  end
  width, height = 256, 144
  local screen, s = fixture()
  local a, b = s.boxes[1][1], s.boxes[1][3]
  action(screen, "multi"); screen.boxIndex = 3; press(screen, "a")
  T.eq(#screen.multi, 2, "START and A mark two Pokémon")
  screen:modernPCSwitchBox(1); screen.boxIndex = 20; press(screen, "a")
  T.check(s.boxes[2][1] == a and s.boxes[2][2] == b, "UI group drop preserves order and identities")
  T.eq(#s.boxes[1], 4, "UI group drop removes exactly selected Pokémon")
  T.eq(screen.multiMode, nil, "UI group drop clears selection")
  screen, s = fixture()
  local p = s.party[1]
  s.party[2].hp, s.party[3].hp = 0, 0
  screen.region, screen.partyIndex = "party", 1; action(screen, "multi")
  screen.region, screen.boxIndex = "box", 7; press(screen, "a")
  T.check(screen.multiMode and s.party[1] == p and #s.party == 3,
    "Gen1 refuses moving last usable party member and rolls back")
  press(screen, "b"); T.eq(screen.multiMode, nil, "B cancels refused selection")
  run.release()
end
T.finish("PC QoL navigation")
