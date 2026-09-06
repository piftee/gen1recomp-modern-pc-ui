return function(game)
  local Save = require("src.core.gen2.Save")
  local Mon = require("src.battle.gen2.Mon")
  local Mail = require("src.core.gen2.Mail")
  local Boxes = require("src.core.gen2.Boxes")
  local Screens = require("src.ui.Screens")
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local checks = 0
  local function check(ok, why) assert(ok, "PC QOL: " .. why); checks = checks + 1 end
  local function press(screen, key)
    local old = game.input.wasPressed
    game.input.wasPressed = function(_, k) return k == key end
    local ok, why = pcall(screen.update, screen, 0)
    game.input.wasPressed = old
    assert(ok, why)
  end
  local function focus(screen, region, index)
    screen.region = region
    if region == "party" then screen.partyIndex = index else screen.boxIndex = index end
  end
  local function option(value)
    local bucket = game.mods.modOptions.modern_ui_suite or game.mods.modOptions.modern_pc_ui
    bucket[game.mods.modOptions.modern_ui_suite and "pc.box_exclusive" or "box_exclusive"] = value
  end
  local function action(screen, kind)
    press(screen, "start")
    for i, entry in ipairs(screen.actions or {}) do
      if entry.action == kind then screen.actionIndex = i; press(screen, "a"); return end
    end
    error("missing action " .. kind)
  end
  local function fixture()
    while game.stack:top() do game.stack:pop() end
    game.save = Save.newGame({ playerName = "QOL TEST", trainerId = 1234 })
    local s = game.save
    s.party, s.boxes[1] = {}, {}
    for _, id in ipairs({ "CYNDAQUIL", "MAREEP", "TOTODILE" }) do
      s.party[#s.party + 1] = assert(Mon.new(game.data, id, 20))
    end
    for _ = 1, 6 do s.boxes[1][#s.boxes[1] + 1] = assert(Mon.new(game.data, "CHIKORITA", 20)) end
    s.boxes[2] = { assert(Mon.new(game.data, "WOOPER", 20)) }
    local writes = 0
    local screen = Screens.push(game, "Gen2PcMenu", { save = s, bills = true,
      writer = function() writes = writes + 1; return true end })
    option(false)
    return screen, s, function() return writes end
  end
  local function mark(screen, region, indices)
    focus(screen, region, indices[1]); action(screen, "multi")
    for i = 2, #indices do focus(screen, region, indices[i]); press(screen, "a") end
    check(#screen.multi == #indices, "all requested mons marked")
  end
  local screen, s, writes = fixture()
  for _, size in ipairs({ { 1280, 720 }, { 480, 900 }, { 800, 720 } }) do
    love.window.setMode(size[1], size[2], { resizable = true }); U.wait(2)
    for _, exclusive in ipairs({ false, true }) do
      option(exclusive)
      local layout = screen:modernPCLayoutInfo()
      if not layout.compact or exclusive then
        focus(screen, "party", 1); press(screen, "left")
        check(screen.partyIndex == #s.party, "party browsing wraps to last occupied mon")
        press(screen, "right"); check(screen.partyIndex == 1, "party wraps back to first")
      else
        focus(screen, "party", 2); press(screen, "right")
        check(screen.region == "box", "compact OFF retains Right-to-box")
      end
      focus(screen, "box", 1); press(screen, "left")
      if exclusive then
        check(screen.region == "box" and screen.boxIndex == 5 and s.currentBox == 1,
          "exclusive left edge stays in box")
        press(screen, "right"); check(screen.boxIndex == 1, "exclusive right wraps within row")
        press(screen, "up"); check(screen.region == "party" and not screen.boxSwitching,
          "exclusive up enters party without selector")
        focus(screen, "party", 1); press(screen, "up")
        check(screen.region == "box" and screen.boxIndex >= 16, "exclusive party up goes to bottom box row")
        focus(screen, "party", 6); press(screen, "down")
        check(screen.region == "box" and screen.boxIndex <= 5, "exclusive party down goes to first box row")
      end
      s.currentBox = 1
      press(screen, "select"); press(screen, "right"); press(screen, "b")
      check(s.currentBox == 2, "Select remains deliberate box switch")
      s.currentBox = 1
    end
  end
  screen, s, writes = fixture()
  local one, two = s.boxes[1][1], s.boxes[1][2]
  mark(screen, "box", { 1, 2 })
  check(s.boxes[1][1] == one, "marking does not remove source")
  press(screen, "select"); press(screen, "right"); press(screen, "b")
  focus(screen, "box", 20); press(screen, "a")
  check(s.boxes[2][2] == one and s.boxes[2][3] == two, "group crosses boxes in marked order")
  check(#s.boxes[1] == 4 and screen.multiMode == nil, "successful drop clears group")
  press(screen, "b"); check(writes() == 1, "batch is saved by native close writer")

  screen, s = fixture()
  mark(screen, "party", { 1, 2 }); press(screen, "b")
  check(#s.party == 3 and not screen.multiMode, "cancel leaves all mons untouched")
  local owner = s.party[3]
  owner.item = "FLOWER_MAIL"
  local letter = Mail.entry("FLOWER_MAIL", "UNCHANGED", "QOL", 42, owner.species)
  Mail.set(s, 3, letter)
  mark(screen, "party", { 1, 2 }); focus(screen, "box", 7); press(screen, "a")
  check(#s.party == 1 and s.party[1] == owner and Mail.get(s, 1) == letter,
    "unaffected Mail follows party compaction")
  check(Mail.get(s, 3) == nil, "obsolete Mail slots cleared")
  mark(screen, "party", { 1 }); focus(screen, "box", 1); press(screen, "a")
  check(screen.multiMode and s.party[1] == owner and Mail.get(s, 1) == letter,
    "outgoing Mail carrier refuses full swap without changing anything")
  press(screen, "b")

  screen, s = fixture()
  for i = 2, #s.party do s.party[i].hp = 0 end
  local healthy = s.party[1]
  mark(screen, "party", { 1 }); focus(screen, "box", 7); press(screen, "a")
  check(screen.multiMode and s.party[1] == healthy, "last usable member cannot be deposited")
  press(screen, "b")
  for i = 1, 6 do s.boxes[1][i].isEgg, s.boxes[1][i].hp = true, 0 end
  mark(screen, "box", { 1, 2, 3, 4, 5, 6 }); action(screen, "multi_party")
  check(screen.multiMode and s.party[1] == healthy and #s.party == 3,
    "whole-party swap to all Eggs is refused atomically")
  press(screen, "b")
  s.boxes[1][6].isEgg = false
  mark(screen, "box", { 1, 2, 3, 4, 5, 6 }); action(screen, "multi_party")
  check(not screen.multiMode and #s.party == 6 and s.party[6].hp > 0,
    "whole-party replacement uses final usable state, not intermediate refusals")

  screen, s = fixture()
  one = s.boxes[1][1]
  mark(screen, "box", { 1, 3 })
  table.remove(s.boxes[1], 2)
  focus(screen, "party", 4); press(screen, "a")
  check(screen.multiMode and s.boxes[1][1] == one and #s.party == 3,
    "stale mark rejects whole operation")
  press(screen, "b")
  mark(screen, "party", { 1, 2 })
  local old = Boxes.enterBox
  local count = 0
  Boxes.enterBox = function(mon)
    count = count + 1; old(mon)
    if count == 2 then error("injected batch failure") end
  end
  local partyFirst, partySecond = s.party[1], s.party[2]
  local oldHp = partyFirst.hp; partyFirst.hp = 1
  focus(screen, "box", 1); press(screen, "a")
  Boxes.enterBox = old
  check(screen.multiMode and s.party[1] == partyFirst and s.party[2] == partySecond
    and partyFirst.hp == 1 and not screen.modernPCDirty, "runtime error rolls back all batch data")
  partyFirst.hp = oldHp
  press(screen, "b")
  mark(screen, "box", { 1, 2 }); focus(screen, "party", 4); press(screen, "a")
  screen.modernPCWriter = function() return false end
  press(screen, "b")
  check(game.stack:top() == screen and screen.modernPCDirty, "failed save leaves batch workspace open")
  screen.modernPCWriter = function() return true end
  press(screen, "b")
  check(game.stack:top() ~= screen, "save can be retried")

  screen, s = fixture()
  mark(screen, "box", { 1, 2, 4 })
  local out = os.getenv("SHOT_DIR")
  if out then
    for _, size in ipairs({ { 1280, 720, "wide" }, { 800, 720, "compact" }, { 480, 900, "portrait" } }) do
      love.window.setMode(size[1], size[2], { resizable = true }); U.wait(2)
      screen.status = nil
      check(U.shot(game, out .. "/multi-" .. size[3] .. ".png"), "captured marked group")
    end
  end
  print(("[PC QOL] %d checks passed"):format(checks))
  love.event.quit(0)
end
