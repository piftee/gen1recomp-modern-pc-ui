-- Run against an imported Gen 2 runtime in an isolated POKEPORT_IDENTITY.
-- No real save is loaded/written: native models operate on fresh fixtures.
return function(game)
  local Save = require("src.core.gen2.Save")
  local Mon = require("src.battle.gen2.Mon")
  local Mail = require("src.core.gen2.Mail")
  local Boxes = require("src.core.gen2.Boxes")
  local Bag = require("src.inventory.Bag")
  local Screens = require("src.ui.Screens")
  local CenterPcMenu = require("src.ui.gen2.CenterPcMenu")
  local GameVersion = require("src.core.GameVersion")
  local U = dofile(assert(os.getenv("PC_REPO")) .. "/tests/drivers/util.lua")
  local shots = os.getenv("SHOT_DIR")
  local checks = 0
  local function check(ok, message)
    assert(ok, "PC WORKSPACE: " .. message)
    checks = checks + 1
    print("[PC] PASS " .. message)
  end
  local function eq(a, b, message) check(a == b, message) end
  local function press(screen, key)
    local old = game.input.wasPressed
    game.input.wasPressed = function(_, k) return k == key end
    local ok, why = pcall(screen.update, screen, 1 / 60)
    game.input.wasPressed = old
    assert(ok, why)
  end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local function mon(id) return assert(Mon.new(game.data, id or "CYNDAQUIL", 20)) end
  local function fixture()
    clear()
    game.save = Save.newGame({ playerName = "PC TEST", trainerId = 1234 })
    local save = game.save
    save.party = { mon("CYNDAQUIL"), mon("MAREEP"), mon("TOTODILE") }
    save.boxes[1] = { mon("CHIKORITA"), mon("TOGEPI") }
    save.boxes[2] = { mon("WOOPER") }
    save.boxNames[1] = "JOHTO"
    local writes = 0
    local screen = Screens.push(game, "Gen2PcMenu", { save = save, bills = true,
      writer = function() writes = writes + 1; return true end,
      onClose = function() game.stack:pop() end })
    eq(screen.modernPCLayout, "party-and-box", "Gen2PcMenu opens combined workspace")
    return screen, save, function() return writes end
  end
  local function focus(screen, region, index)
    screen.region = region
    if region == "party" then screen.partyIndex = index else screen.boxIndex = index end
  end
  local function action(screen, kind)
    press(screen, "start")
    for i, entry in ipairs(screen.actions or {}) do
      if entry.action == kind then
        screen.actionIndex = i; press(screen, "a"); return game.stack:top()
      end
    end
    error("missing action " .. kind)
  end
  local function drain(screen)
    for _ = 1, 20 do
      if not screen.message then return end
      press(screen, "a")
    end
    error("native message failed to finish")
  end
  local function shot(slug)
    if shots then
      U.wait(2)
      check(U.shot(game, shots .. "/" .. slug .. ".png"), "captured " .. slug)
    end
  end

  local screen, save, writes = fixture()
  clear()
  local center = CenterPcMenu.new(game, { save = save })
  game.stack:push(center)
  center.say = function(_, _, done) if done then done() end end
  center.index = 1; center:choose()
  eq(game.stack:top().modernPCLayout, "party-and-box", "Bill's PC enters workspace directly")
  screen, save, writes = fixture()
  local partyMon, boxed = save.party[1], save.boxes[1][1]
  press(screen, "a")
  eq(save.boxes[1][1], boxed, "pickup keeps source intact")
  focus(screen, "party", 4); press(screen, "a")
  eq(save.party[4], boxed, "A drops boxed Pokémon into party")
  eq(#save.boxes[1], 1, "withdraw removes one boxed entry")
  focus(screen, "party", 1); press(screen, "a")
  screen:modernPCSwitchBox(1); focus(screen, "box", 2); press(screen, "a")
  eq(save.boxes[2][2], partyMon, "carry across box switch then deposit")
  eq(#save.party, 3, "deposit removes one party member")
  eq(partyMon.hp, partyMon.maxHp, "deposit restores native HP")
  press(screen, "b")
  eq(writes(), 1, "closing dirty PC writes once through supplied writer")

  screen, save = fixture()
  local letterMon = save.party[2]
  letterMon.item = "FLOWER_MAIL"
  local letter = Mail.entry("FLOWER_MAIL", "HELLO JOHTO", "ISH", 456, letterMon.species)
  Mail.set(save, 2, letter)
  focus(screen, "party", 2); press(screen, "a")
  focus(screen, "party", 1); press(screen, "a")
  eq(save.party[1], letterMon, "Mail carrier can swap inside party")
  eq(Mail.get(save, 1), letter, "letter follows party swap")
  eq(Mail.get(save, 2), nil, "old letter slot clears")
  press(screen, "a"); focus(screen, "party", 6); press(screen, "a")
  eq(save.party[3], letterMon, "Mail carrier can move to end of party")
  eq(Mail.get(save, 3), letter, "letter follows compact party reorder")
  focus(screen, "party", 1)
  check(screen:modernPCQuickTransfer(), "non-Mail member can deposit while another holds Mail")
  eq(Mail.get(save, 2), letter, "Mail shifts behind removed party slot")
  focus(screen, "box", 1); press(screen, "a")
  focus(screen, "party", 1); press(screen, "a")
  eq(Mail.get(save, 2), letter, "letter remains pinned during unrelated cross-list swap")
  focus(screen, "party", 2); press(screen, "a")
  focus(screen, "box", 1); press(screen, "a")
  eq(save.party[2], letterMon, "occupied-slot swap cannot box Mail carrier")
  check(screen.held ~= nil, "rejected drop keeps held cursor")
  eq(Mail.get(save, 2), letter, "rejected drop preserves letter")
  press(screen, "b")
  eq(screen.held, nil, "B cancels without moving Pokémon")
  focus(screen, "party", 2)
  check(not screen:modernPCQuickTransfer(), "quick deposit also blocks Mail carrier")
  eq(Mail.get(save, 2), letter, "quick-transfer refusal keeps Mail unchanged")
  focus(screen, "box", 1); press(screen, "a")
  focus(screen, "party", 2); press(screen, "a")
  eq(save.party[2], letterMon, "reverse swap cannot eject a Mail carrier")
  eq(Mail.get(save, 2), letter, "reverse swap refusal preserves letter")
  press(screen, "b")

  local summary = action(screen, "summary")
  eq(summary.screenId, "Gen2SummaryMenu", "SUMMARY uses registered native or suite screen")
  shot("summary-from-pc")
  press(summary, "b")
  eq(game.stack:top(), screen, "Summary returns to same workspace")
  eq(screen.partyIndex, 2, "Summary preserves selected party slot")

  local mailMenu = action(screen, "mail")
  eq(mailMenu.screenId, "Gen2MailMenu", "START MAIL opens native READ/TAKE/QUIT")
  shot("mail-actions")
  press(mailMenu, "a")
  local read = game.stack:top()
  eq(read.screenId, "Gen2MailRead", "READ opens letter stationery")
  eq(read.entry, letter, "READ receives the exact letter")
  shot("mail-read")
  read.onClose()
  eq(game.stack:top(), screen, "reading returns to workspace")
  mailMenu = action(screen, "mail")
  press(mailMenu, "down"); press(mailMenu, "a")
  check(mailMenu.confirm ~= nil, "TAKE asks about preserving Mail in PC")
  press(mailMenu, "a"); drain(mailMenu)
  eq(letterMon.item, nil, "TAKE removes Mail item only after confirmation")
  eq(Mail.mailbox(save)[1], letter, "TAKE preserves complete letter in mailbox")
  check(screen:modernPCQuickTransfer(), "Mail removal unlocks deposit")
  eq(game.stack:top(), screen, "native Mail action closes back to workspace")
  local mailbox = action(screen, "mailbox")
  eq(mailbox.screenId, "Gen2MailboxMenu", "MAILBOX accessible with any selected slot")
  mailbox:attachMail()
  local picker = game.stack:top()
  eq(picker.screenId, "Gen2PartyMenu", "ATTACH MAIL uses native party selection")
  picker.onChoose(1, save.party[1])
  eq(Mail.get(save, 1), letter, "ATTACH retains letter identity and metadata")
  eq(save.party[1].item, "FLOWER_MAIL", "ATTACH restores held stationery")
  drain(mailbox)
  eq(game.stack:top(), screen, "attach finishes back in workspace")

  screen, save = fixture()
  focus(screen, "party", 2)
  check(Bag.add(save, "FLOWER_MAIL", 1, game.data), "fixture supplies writable Mail")
  local itemMenu = action(screen, "item")
  eq(itemMenu.screenId, "Gen2HeldItemMenu", "START ITEM opens native Give/Take")
  press(itemMenu, "a")
  local pack = game.stack:top()
  eq(pack.screenId, "Gen2PackMenu", "GIVE uses live PACK picker")
  pack.onChoose("FLOWER_MAIL"); drain(itemMenu)
  local compose = game.stack:top()
  eq(compose.screenId, "Gen2MailCompose", "giving stationery opens native composer")
  compose:addCharacter("H"); compose:addCharacter("I"); compose:accept()
  eq(Mail.get(save, 2).message, "HI", "composer writes party-slot Mail")
  eq(Mail.get(save, 2).authorId, 1234, "composed letter retains trainer identity")
  eq(game.stack:top(), screen, "compose returns to PC workspace")
  for i = 1, Mail.MAILBOX_CAPACITY do Mail.mailbox(save)[i] = Mail.entry("SURF_MAIL", "FULL", "X") end
  local authored = Mail.get(save, 2)
  mailMenu = action(screen, "mail"); mailMenu:take(); press(mailMenu, "a"); drain(mailMenu)
  eq(Mail.get(save, 2), authored, "full mailbox keeps original letter on Pokémon")
  eq(save.party[2].item, "FLOWER_MAIL", "full mailbox keeps stationery")

  screen, save = fixture()
  save.party[1].item = "BERRY"
  save.party[1].hp = 1; save.party[1].status = "poison"
  save.party[1].moves[1].pp = 0
  local ordinary = save.party[1]
  focus(screen, "party", 1); check(screen:modernPCQuickTransfer(), "ordinary held item can be deposited")
  eq(ordinary.item, "BERRY", "deposit preserves held item")
  eq(ordinary.status, nil, "deposit clears native status")
  eq(ordinary.moves[1].pp, ordinary.moves[1].maxPp, "deposit restores native PP")
  focus(screen, "box", #save.boxes[1]); check(screen:modernPCQuickTransfer(), "ordinary held item withdraws")
  eq(save.party[#save.party], ordinary, "withdraw preserves Pokémon identity")
  eq(ordinary.item, "BERRY", "withdraw preserves held item")
  focus(screen, "party", #save.party)
  itemMenu = action(screen, "item"); itemMenu:takeItem(); drain(itemMenu)
  eq(ordinary.item, nil, "native TAKE removes ordinary item")
  eq(save.inventory.BERRY, 1, "native TAKE puts item into bag")

  screen, save = fixture()
  save.party = { save.party[1] }
  focus(screen, "party", 1)
  check(not screen:modernPCQuickTransfer(), "cannot deposit final party Pokémon")
  save.party[2] = mon(); save.party[2].hp = 0
  check(not screen:modernPCQuickTransfer(), "cannot deposit only usable Pokémon")
  save.party[2].isEgg = true
  check(not screen:modernPCQuickTransfer(), "Egg does not satisfy usable-party guard")
  local onlyUsable, replacement = save.party[1], save.boxes[1][1]
  press(screen, "a"); focus(screen, "box", 1); press(screen, "a")
  eq(save.party[1], replacement, "healthy replacement allows last-usable occupied swap")
  eq(save.boxes[1][1], onlyUsable, "replacement swap retains outgoing Pokémon")
  focus(screen, "party", 2)
  check(screen:modernPCQuickTransfer(), "Egg can enter box when usable Pokémon remains")
  focus(screen, "box", #save.boxes[1])
  check(not screen:modernPCRequestRelease(), "Egg release is refused")
  screen, save = fixture()
  while #save.party < 6 do save.party[#save.party + 1] = mon() end
  while #save.boxes[1] < 20 do save.boxes[1][#save.boxes[1] + 1] = mon() end
  focus(screen, "party", 1); check(not screen:modernPCQuickTransfer(), "full box rejects extra deposit")
  focus(screen, "box", 1); check(not screen:modernPCQuickTransfer(), "full party rejects extra withdrawal")
  local p, b = save.party[1], save.boxes[1][1]
  press(screen, "a"); focus(screen, "party", 1); press(screen, "a")
  eq(save.party[1], b, "occupied swap works when party and box are full")
  eq(save.boxes[1][1], p, "full swap keeps outgoing Pokémon")
  eq(#save.party, 6, "full swap preserves party size")
  eq(#save.boxes[1], 20, "full swap preserves box size")
  focus(screen, "box", 1); press(screen, "a")
  screen:modernPCSwitchBox(13); eq(save.currentBox, 14, "fourteenth box is reachable")
  focus(screen, "box", 1); press(screen, "a")
  eq(save.boxes[14][1], p, "box-to-box drop keeps carried Pokémon")
  check(screen:modernPCRequestRelease(), "release requests confirmation")
  eq(screen.modernPCConfirm.choice, 2, "release defaults to NO")
  press(screen, "a"); eq(save.boxes[14][1], p, "default release preserves Pokémon")
  screen:modernPCRequestRelease(); press(screen, "up"); press(screen, "a")
  eq(#save.boxes[14], 0, "confirmed release removes only selected Pokémon")
  screen.modernPCWriter = function() return false end
  press(screen, "b"); eq(game.stack:top(), screen, "failed save keeps workspace open for retry")
  screen.modernPCWriter = function() error("simulated I/O failure") end
  press(screen, "b"); eq(game.stack:top(), screen, "save exception keeps workspace open")
  screen.modernPCWriter = function() return true end
  press(screen, "b"); check(game.stack:top() ~= screen, "successful retry closes workspace")

  screen, save = fixture()
  save.party = {}
  local refusal = Screens.build(game, "Gen2PcMenu", { save = save, bills = true })
  check(refusal.message ~= nil and not refusal.modernPCUI, "empty party preserves native PC refusal")

  screen, save = fixture()
  save.party[2].item = "FLOWER_MAIL"; Mail.set(save, 2, letter)
  local nativeSaved = Save.save(save)
  check(nativeSaved, "native save serializer accepts workspace record shape")
  local reloaded = assert(Save.load(GameVersion.get()))
  eq(reloaded.mail.party[2].message, letter.message, "Mail message survives native save/load")
  eq(reloaded.party[2].item, "FLOWER_MAIL", "held Mail survives native save/load")

  for _, size in ipairs({ { 800, 720, "compact" }, { 1280, 720, "wide" }, { 480, 900, "portrait" } }) do
    love.window.setMode(size[1], size[2], { resizable = true })
    screen.status, screen.actions = nil, nil
    focus(screen, "party", 2)
    shot("workspace-" .. size[3])
    local layout = screen:modernPCLayoutInfo()
    check(layout.party and layout.box and layout.detail, "all three regions visible in " .. size[3])
  end
  love.window.setMode(1280, 720, { resizable = true })
  screen.actions = screen:modernPCActionItems(); screen.actionIndex = 3
  shot("workspace-actions")
  screen.actions = nil
  press(screen, "select"); press(screen, "a"); shot("workspace-box-picker")
  screen.boxPickerIndex = 14; press(screen, "a")
  eq(save.currentBox, 14, "all-box picker directly selects box fourteen")
  screen:modernPCSwitchBox(1)
  eq(save.currentBox, 1, "box browsing wraps from fourteen to one")
  press(screen, "b"); press(screen, "b")
  local suite = game.mods.modOptions.modern_ui_suite
  if suite then
    suite["pc.enabled"] = false
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.modern_ui_suite = { ["pc.enabled"] = false }
    Screens.invalidate()
    local native = Screens.build(game, "Gen2PcMenu", { save = game.save, bills = true })
    eq(native.modernPCUI, nil, "suite OFF restores native entry")
    check(type(native.entries) == "table", "disabled native entry retains operations")
  end
  print(("[PC] %d checks passed on %s"):format(checks, GameVersion.get()))
  love.event.quit(0)
end
