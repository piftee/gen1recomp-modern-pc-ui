-- Shared workspace navigation/layout; native Gen 2 storage and Mail records.
return function(mod)
  local catchSource = assert(mod:read("gen2_catch_storage.lua"))
  assert(load(catchSource, "@" .. mod.path .. "/gen2_catch_storage.lua"))()(mod)
  local cutoutSource = assert(mod:read("gen2_portrait_cutouts.lua"))
  local PortraitCutouts = assert(load(cutoutSource, "@" .. mod.path
    .. "/gen2_portrait_cutouts.lua"))()
  local Boxes = require("src.core.gen2.Boxes")
  local Mail = require("src.core.gen2.Mail")
  local PcMenu = require("src.ui.gen2.PcMenu")
  local BoxMenu = require("src.ui.gen2.BoxMenu")
  local PartyMenu = require("src.ui.gen2.PartyMenu")
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local GbcPalette = require("src.render.GbcPalette")
  local Palettes = require("src.world.gen2.Palettes")
  local Screens = require("src.ui.Screens")
  local Sound = require("src.core.Sound")
  local Strings = require("src.core.Strings")
  local storage = {}

  storage.Boxes = {
    COUNT = Boxes.NUM_BOXES, CAPACITY = Boxes.MONS_PER_BOX, active = Boxes.box,
    ensure = function(save)
      save.currentBox = math.max(1, math.min(Boxes.NUM_BOXES,
        tonumber(save.currentBox) or 1))
      for i = 1, Boxes.NUM_BOXES do Boxes.box(save, i) end
    end,
  }
  local function name(mon)
    return mon and (mon.isEgg and "EGG"
      or mon.nickname or mon.name or mon.species) or "EMPTY"
  end
  function storage.size(screen)
    return screen.modernPCDrawWidth or screen.modernPCLastWideWidth or 160,
      screen.modernPCDrawHeight or screen.modernPCLastWideHeight or 144
  end
  function storage.play(screen, id)
    local sounds = { Press_AB = "Sfx_ReadText2", Swap = "Sfx_SwitchPokemon",
      Withdraw_Deposit = "Sfx_ChoosePcOption" }
    local data = screen.game.data
    id = sounds[id] or id
    if data.audio and data.audio.sfx and data.audio.sfx[Sound.resolve(data, id)] then
      Sound.play(data, id)
    end
  end
  function storage.changed(screen) screen.modernPCDirty = true end
  local function refuse(screen, reason)
    screen.status = Strings(reason)
    storage.play(screen, "Sfx_Wrong")
    return false
  end

  -- MOVE W/O MAIL's whole-party gate is unnecessary when each edit carries
  -- slot-indexed letters with their owners. Only the departing mon is gated.
  local function mayLeave(screen, slot, incoming)
    local party = screen.game.save.party
    if Mail.monHoldsMail(party[slot]) then
      return false, "Remove MAIL first. START: MAIL."
    end
    if #party <= 1 and not incoming then
      return false, "Keep one POKéMON in your party!"
    end
    local usable = incoming and not incoming.isEgg
      and (incoming.maxHp or incoming.hp or 0) > 0
    for i, other in ipairs(party) do
      if i ~= slot and not other.isEgg and (other.hp or 0) > 0 then usable = true end
    end
    if not usable then return false, "Keep a usable POKéMON in your party!" end
    return true
  end
  local function partyMail(save)
    local byMon, letters = {}, Mail.state(save).party
    for i, mon in ipairs(save.party) do byMon[mon] = letters[i] end
    return byMon
  end
  local function restorePartyMail(save, byMon)
    local letters = Mail.state(save).party
    for i = 1, Mail.PARTY_LENGTH do letters[i] = byMon[save.party[i]] end
  end
  local function enterParty(mon)
    -- Boxes.withdraw's healing; ordinary held items stay attached.
    mon.status, mon.statusTurns = nil, nil
    mon.hp = mon.isEgg and 0 or (mon.maxHp or mon.hp)
  end

  function storage.finishMove(screen, target, at, capacity)
    local held = screen.held
    if not held or held.sourceList[held.sourceIndex] ~= held.mon then
      screen.held = nil
      return refuse(screen, "That POKéMON moved already.")
    end
    local save = screen.game.save
    local source, from, mon = held.sourceList, held.sourceIndex, held.mon
    local other = target[at]
    local fromParty, toParty = source == save.party, target == save.party
    if source == target and from == at then
      screen.held = nil
      screen.status = Strings("Put %s back.", name(mon))
      return true
    end
    if source ~= target then
      if not other and #target >= capacity then
        return refuse(screen, toParty and "The party is full!" or "This BOX is full!")
      end
      local leaving = fromParty and from or (toParty and other and at)
      if leaving then
        local incoming
        if fromParty then incoming = other else incoming = mon end
        local ok, why = mayLeave(screen, leaving, incoming)
        if not ok then return refuse(screen, why) end
      end
      if (not fromParty and Mail.monHoldsMail(mon))
          or (not toParty and other and Mail.monHoldsMail(other)) then
        return refuse(screen, "MAIL cannot be moved from a BOX.")
      end
    end
    local letters = partyMail(save)
    if other then source[from], target[at] = other, mon
    else
      table.remove(source, from)
      if source == target and from < at then at = at - 1 end
      at = math.max(1, math.min(at, #target + 1))
      table.insert(target, at, mon)
    end
    if fromParty ~= toParty then
      if fromParty then
        Boxes.enterBox(mon)
        if other then enterParty(other) end
      else
        enterParty(mon)
        if other then Boxes.enterBox(other) end
      end
    end
    restorePartyMail(save, letters)
    if toParty then screen.partyIndex = at else screen.boxIndex = at end
    screen.held = nil
    screen.status = Strings("Moved %s.", name(mon))
    storage.changed(screen)
    storage.play(screen, "Swap")
    return true
  end

  function storage.quickTransfer(screen)
    if screen.held then return refuse(screen, "Place the moving POKéMON first.") end
    local mon, source, index = screen:modernPCSelected()
    if not mon then return refuse(screen, "That slot is empty.") end
    local target = screen.region == "party" and Boxes.box(screen.game.save)
      or screen.game.save.party
    local capacity = screen.region == "party" and Boxes.MONS_PER_BOX or Boxes.PARTY_SIZE
    screen.held = { sourceList = source, sourceIndex = index, mon = mon }
    local ok = storage.finishMove(screen, target, #target + 1, capacity)
    screen.held = nil
    return ok
  end
  function storage.finishBatch(screen, plan, Batch)
    local save = screen.game.save
    for _, mon in ipairs(plan.outgoing) do
      if Mail.monHoldsMail(mon) then return false, "Remove MAIL first. START: MAIL." end
    end
    local entering = {}
    for _, mon in ipairs(plan.incoming) do
      if Mail.monHoldsMail(mon) then return false, "MAIL cannot be moved from a BOX." end
      entering[mon] = true
    end
    if plan.lists[save.party] then
      local usable = false
      for _, mon in ipairs(plan.party) do
        local hp = entering[mon] and (mon.maxHp or mon.hp or 0) or (mon.hp or 0)
        if not mon.isEgg and hp > 0 then usable = true end
      end
      if not usable then return false, "Keep a usable POKéMON in your party!" end
    end
    local letters = partyMail(save)
    local ok, why = Batch.commit(save, plan, function()
      for _, mon in ipairs(plan.outgoing) do Boxes.enterBox(mon) end
      for _, mon in ipairs(plan.incoming) do enterParty(mon) end
      restorePartyMail(save, letters)
    end)
    if not ok then
      mod.log:error("PC batch rolled back: %s", tostring(why))
      return false, "Could not move group. Nothing changed."
    end
    storage.changed(screen)
    return true
  end
  local function releaseAllowed(screen, list, index, mon)
    if list[index] ~= mon then return false, "That POKéMON moved already." end
    if mon.isEgg then return false, "No releasing EGGS!" end
    if Mail.monHoldsMail(mon) then return false, "Remove MAIL first. START: MAIL." end
    if list == screen.game.save.party then return mayLeave(screen, index) end
    return true
  end
  function storage.requestRelease(screen)
    local mon, list, index = screen:modernPCSelected()
    if not mon then return refuse(screen, "That slot is empty.") end
    local ok, why = releaseAllowed(screen, list, index, mon)
    if not ok then return refuse(screen, why) end
    screen.modernPCConfirm = { mon = mon, list = list, index = index, choice = 2 }
    return true
  end
  function storage.update(screen)
    local confirm = screen.modernPCConfirm
    if not confirm then return false end
    local input = screen.game.input
    if input:wasPressed("b") then
      screen.modernPCConfirm = nil
      screen.status = Strings("Release cancelled.")
    elseif input:wasPressed("up") or input:wasPressed("down") then
      confirm.choice = confirm.choice == 1 and 2 or 1
    elseif input:wasPressed("a") then
      screen.modernPCConfirm = nil
      if confirm.choice == 2 then screen.status = Strings("Release cancelled.")
      else
        local ok, why = releaseAllowed(screen, confirm.list, confirm.index, confirm.mon)
        if not ok then refuse(screen, why)
        else
          local save = screen.game.save
          if confirm.list == save.party then Boxes.releaseFromParty(save, confirm.index)
          else table.remove(confirm.list, confirm.index) end
          screen.status = Strings("Released %s.", name(confirm.mon))
          storage.changed(screen)
        end
      end
    end
    return true
  end

  local function openNative(screen, id, opts, opaque)
    opts = opts or {}
    opts.save = screen.game.save
    opts.onClose = function()
      screen.game.stack:pop()
      storage.changed(screen)
    end
    local child = Screens.push(screen.game, id, opts)
    if opaque then
      -- Paint the native party behind Item/Mail overlays without repainting
      -- a second, 160x144 copy of the widescreen workspace.
      child.isOpaque = true
      local draw = child.draw
      local backdrop = id ~= "Gen2MailboxMenu" and PartyMenu.new(screen.game,
        { save = screen.game.save })
      if backdrop then backdrop.index = screen.partyIndex end
      child.draw = function(self)
        Chrome.clear()
        if backdrop then backdrop:drawPanel() end
        return draw(self)
      end
    end
    return child
  end
  function storage.actionItems(screen)
    local mon = screen:modernPCSelected()
    local entries = {}
    if mon then
      entries[#entries + 1] = { label = Strings("SUMMARY"), action = "summary" }
      entries[#entries + 1] = { label = Strings(screen.region == "party"
        and "SEND TO BOX" or "ADD TO PARTY"), action = "transfer" }
      if screen.region == "party" and not mon.isEgg then
        local mail = Mail.monHoldsMail(mon)
        entries[#entries + 1] = { label = Strings(mail and "MAIL" or "ITEM"),
          action = mail and "mail" or "item" }
      end
      if not mon.isEgg then
        entries[#entries + 1] = { label = Strings("RELEASE"), action = "release" }
      end
    end
    entries[#entries + 1] = { label = Strings("MAILBOX"), action = "mailbox" }
    for _, entry in ipairs(screen.modernPCExtras or {}) do entries[#entries + 1] = entry end
    entries[#entries + 1] = { label = Strings("CANCEL"), action = "cancel" }
    return entries
  end
  function storage.runAction(screen, entry)
    local mon = screen:modernPCSelected()
    if entry.action == "summary" and mon then
      return openNative(screen, "Gen2SummaryMenu", { mon = mon })
    elseif entry.action == "transfer" then return storage.quickTransfer(screen)
    elseif entry.action == "release" then return storage.requestRelease(screen)
    elseif entry.action == "mailbox" then
      return openNative(screen, "Gen2MailboxMenu", {}, true)
    elseif mon and screen.region == "party" and not mon.isEgg then
      if entry.action == "mail" and Mail.monHoldsMail(mon) then
        return openNative(screen, "Gen2MailMenu", { slot = screen.partyIndex }, true)
      elseif entry.action == "item" and not Mail.monHoldsMail(mon) then
        return openNative(screen, "Gen2HeldItemMenu", { slot = screen.partyIndex }, true)
      end
    end
    if entry.action == "extra" then return entry.activate() end
  end
  function storage.close(screen)
    if screen.modernPCDirty and screen.modernPCWriter then
      local ok, saved = pcall(screen.modernPCWriter, screen.game.save)
      if not ok or not saved then
        return refuse(screen, "Could not save. Close PC to retry.")
      end
      screen.modernPCDirty = false
    end
    if screen.modernPCOnClose then screen.modernPCOnClose()
    else screen.game.stack:pop() end
  end

  local WHITE, INK = { 1, 1, 1 }, { .02, .03, .05 }
  local RED, BLUE = { 1, .10, .08 }, { .23, .45, .92 }
  local LIGHT, PAPER = { .75, .85, 1 }, { .94, .95, .98 }
  local COLORS = {
    normal = { .56, .60, .64 }, fighting = { .81, .25, .42 },
    flying = { .56, .66, .87 }, poison = { .67, .42, .78 },
    ground = { .85, .47, .27 }, rock = { .79, .71, .55 },
    bug = { .56, .75, .17 }, ghost = { .32, .41, .68 },
    fire = { 1, .61, .33 }, water = { .30, .56, .84 },
    grass = { .40, .74, .37 }, electric = { .96, .82, .23 },
    psychic = { .98, .44, .47 }, ice = { .45, .81, .75 },
    dragon = { .04, .43, .76 }, dark = { .36, .32, .40 }, steel = { .36, .56, .63 },
  }
  local function color(c) love.graphics.setColor(c[1], c[2], c[3], 1) end
  local function card(x, y, w, h, face, border)
    color(face)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    color(border or INK)
    love.graphics.setLineWidth(border == BLUE and 2 or 1)
    love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1, 2, 2)
  end
  local function text(value, x, y, width, ink)
    value = tostring(value or "")
    if Font.width(value) > width then
      local spans = Font.split(value)
      local n = Font.spansFitting(spans, math.max(0, width - Font.width(".")))
      value = n > 0 and value:sub(1, spans[n].to) .. "." or ""
    end
    ink = ink or INK
    local rgb = { ink[1] * 255, ink[2] * 255, ink[3] * 255 }
    local palette, glyph, finish = Chrome.paletteGlyphs(
      { { 255, 255, 255 }, rgb, rgb, rgb }, false, true)
    if palette then
      for _, code in ipairs(Font.encode(value)) do
        glyph(code, math.floor(x), math.floor(y)); x = x + Font.advanceOf(code)
      end
      finish()
    else color(ink); Font.draw(value, math.floor(x), math.floor(y)) end
  end
  local function monColor(screen, mon)
    local def = mon and screen.game.data.pokemon[mon.species]
    return COLORS[tostring(def and def.types and def.types[1] or "normal"):lower()]
      or COLORS.normal
  end
  local function icon(screen, mon, x, y)
    local renderer = screen.modernPCIconRenderer
    renderer.clock = screen.blink
    renderer:drawIcon(mon, math.floor(x), math.floor(y))
  end
  local function portrait(screen, mon, rect)
    local renderer = screen.modernPCPicRenderer
    local image = mon.isEgg and renderer:image(
      ((screen.game.data.gen2MenuGfx or {}).eggHatch or {}).egg) or renderer:picFor(mon)
    if not image then return icon(screen, mon, rect.x, rect.y) end
    local iw, ih = image:getDimensions()
    local scale = math.min(1, rect.w / iw, rect.h / ih)
    local colors = Palettes.monColors(screen.game.data.gen2Palettes,
      mon.isEgg and "EGG" or mon.species, mon.shiny)
    local function draw()
      color(WHITE)
      love.graphics.draw(image, rect.x + (rect.w - iw * scale) / 2,
        rect.y + (rect.h - ih * scale) / 2, 0, scale, scale)
    end
    -- The modern detail rail bypasses Crystal's native drawPicBlock wrapper.
    -- Use its image identity predicate, including for animated shiny frames,
    -- so native/egg art still receives the cartridge palette.
    local provider = mod.find and mod.find("crystal_animated_sprites_with_shiny_visuals")
    local api = provider and provider.exports
    if api and type(api.isCrystalImage) == "function" and api.isCrystalImage(image) then
      local shader = love.graphics.getShader()
      love.graphics.setShader()
      draw()
      love.graphics.setShader(shader)
    elseif colors and GbcPalette.available() then
      GbcPalette.with(colors, draw)
    else
      draw()
    end
  end
  local function details(screen, layout)
    local d = layout.detail
    card(d.x, d.y, d.w, d.h, INK)
    local mon = screen.held and screen.held.mon or screen:modernPCSelected()
    if not mon then return text("EMPTY SLOT", d.x + 5, d.y + 10, d.w - 10, LIGHT) end
    local item = mon.item and screen.game.data.items[mon.item]
    local itemName = (item and item.name) or mon.item or "NO ITEM"
    if layout.compact then
      icon(screen, mon, d.x + 4, d.y + 6)
      text(name(mon), d.x + 25, d.y + 4, d.w - 30, WHITE)
      text(itemName, d.x + 25, d.y + 16, d.w - 30, LIGHT)
      return
    end
    local x, y, width
    if layout.portrait then
      portrait(screen, mon, { x = d.x + 4, y = d.y + 4, w = 56, h = d.h - 8 })
      x, y, width = d.x + 64, d.y + 8, d.w - 68
    else
      portrait(screen, mon, { x = d.x + 3, y = d.y + 3, w = d.w - 6, h = 48 })
      x, y, width = d.x + 4, d.y + 55, d.w - 8
    end
    text(name(mon), x, y, width, WHITE)
    local gender = mon.gender == "male" and "M" or mon.gender == "female" and "F" or ""
    text(mon.isEgg and "EGG" or ("LV%d %s"):format(mon.level or 1, gender),
      x, y + 12, width, LIGHT)
    text(mon.isEgg and "" or ("%d/%d"):format(mon.hp or 0, mon.maxHp or 0),
      x, y + 24, width, WHITE)
    text(Mail.monHoldsMail(mon) and width < Font.width(itemName) and "MAIL"
      or itemName, x, y + 36, width, LIGHT)
    text(screen.held and "MOVING" or screen.region == "party" and "PARTY"
      or Boxes.name(screen.game.save, screen.game.save.currentBox), x, y + 48, width, WHITE)
  end
  function storage.draw(screen, layout, slotRect)
    local G = love.graphics
    local wasBattle = Font.useBattleExtra(true)
    color(PAPER); G.rectangle("fill", 0, 0, layout.width, layout.height)
    color({ .73, .76, .94 })
    for x = -144, layout.width, 16 do
      G.line(x, 16, x + 144, layout.height); G.line(x + 144, 16, x, layout.height)
    end
    color(RED); G.rectangle("fill", 0, 0, layout.width, 16)
    local box = Boxes.box(screen.game.save)
    text(layout.compact and "PARTY" or "STORAGE", 4, 4,
      layout.compact and 44 or layout.detail.w, WHITE)
    local boxLabel = ("%s %d/%d"):format(Boxes.name(screen.game.save,
      screen.game.save.currentBox), #box, Boxes.MONS_PER_BOX)
    card(layout.box.x, 1, layout.box.w, 13,
      screen.boxSwitching and BLUE or RED, screen.boxSwitching and WHITE or RED)
    color(WHITE)
    local bx, bw = layout.box.x, layout.box.w
    G.polygon("fill", bx + 2, 7, bx + 6, 4, bx + 6, 10)
    G.polygon("fill", bx + bw - 2, 7, bx + bw - 6, 4, bx + bw - 6, 10)
    text(boxLabel, bx + 9, 4, bw - 18, WHITE)
    for _, region in ipairs({ "party", "box" }) do
      local panel = layout[region]
      local list = region == "party" and screen.game.save.party or box
      card(panel.x, panel.y, panel.w, panel.h, PAPER)
      for i = 1, region == "party" and Boxes.PARTY_SIZE or Boxes.MONS_PER_BOX do
        local r = slotRect(layout, region, i)
        local mon = list[i]
        local chosen = screen.region == region and not screen.boxSwitching
          and i == (region == "party" and screen.partyIndex or screen.boxIndex)
        card(r.x + 1, r.y + 1, r.w - 2, r.h - 2,
          mon and monColor(screen, mon) or PAPER, chosen and BLUE or { .68, .70, .76 })
        if mon then icon(screen, mon, r.x + math.floor((r.w - 16) / 2), r.y + 2) end
        if screen.held and screen.held.sourceList == list and screen.held.sourceIndex == i then
          color(WHITE); G.line(r.x + 2, r.y + r.h - 3, r.x + r.w - 3, r.y + 2)
        end
        if chosen and screen.held then
          color(WHITE); G.rectangle("line", r.x + 3, r.y + 3, r.w - 6, r.h - 6)
        end
        if screen:modernPCMultiMarked(list, i) then
          color(INK); G.rectangle("fill", r.x + 1, r.y + 1, 7, 7)
          color(WHITE); G.line(r.x + 2, r.y + 4, r.x + 4, r.y + 6, r.x + 7, r.y + 2)
        end
      end
    end
    details(screen, layout)
    color(RED); G.rectangle("fill", 0, layout.footerY, layout.width, 8)
    local hint = screen.boxSwitching and "L/R BOX  A LIST  B BACK"
      or screen.multiMode and ("%d MARKED A MARK/PLACE B END"):format(#(screen.multi or {}))
      or screen.held and "A PLACE  B CANCEL  SELECT BOX"
      or "A MOVE  START MENU  SELECT BOX"
    if Font.width(hint) > layout.width - 6 then
      hint = screen.boxSwitching and "L/R BOX A LIST B END"
        or screen.multiMode and ("%d MARKED A/B SEL"):format(#(screen.multi or {}))
        or screen.held and "A PLACE  B CANCEL" or "A MOVE  START MENU"
    end
    text(hint, 3, layout.footerY, layout.width - 6, WHITE)
    if screen.status then
      local h = 24
      card(2, layout.footerY - h - 1, layout.width - 4, h, INK, BLUE)
      local spans = Font.split(screen.status)
      local n = Font.spansFitting(spans, layout.width - 16)
      local split = n > 0 and spans[n].to or 0
      text(screen.status:sub(1, split), 7, layout.footerY - h + 3, layout.width - 14, WHITE)
      text(screen.status:sub(split + 1), 7, layout.footerY - h + 13, layout.width - 14, WHITE)
    end
    if screen.boxPicker then
      local p = layout.box
      card(p.x, p.y, p.w, p.h, INK, BLUE)
      text("ALL BOXES", p.x + 5, p.y + 4, p.w - 10, WHITE)
      local cw, ch = (p.w - 8) / 4, (p.h - 19) / 4
      for i = 1, Boxes.NUM_BOXES do
        local x = p.x + 4 + (i - 1) % 4 * cw
        local y = p.y + 16 + math.floor((i - 1) / 4) * ch
        card(x, y, cw - 2, ch - 1, i == screen.boxPickerIndex and BLUE or PAPER)
        text(("%02d"):format(i), x + 3, y + 2, cw - 5)
      end
    end
    local entries, confirm = screen.actions, screen.modernPCConfirm
    if entries or confirm then
      entries = confirm and { { label = "YES" }, { label = "NO" } } or entries
      local visible = math.min(7, #entries)
      local index = confirm and confirm.choice or screen.actionIndex
      local offset = math.max(0, index - visible)
      local w, h = math.min(layout.width - 8, 144), visible * 14 + 22
      local x, y = layout.width - w - 4, math.max(18, layout.footerY - h - 2)
      card(x, y, w, h, { .54, .62, .91 }, BLUE)
      text(confirm and "RELEASE?" or "PC ACTIONS", x + 6, y + 5, w - 12, WHITE)
      for row = 1, visible do
        local i = row + offset
        if i == index then card(x + 4, y + 18 + (row - 1) * 14, w - 8, 13, BLUE) end
        text(entries[i].label, x + 8, y + 21 + (row - 1) * 14, w - 16,
          i == index and WHITE or INK)
      end
    end
    Font.useBattleExtra(wasBattle); color(WHITE)
  end

  local source = assert(mod:read("screen.lua"))
  local workspace = assert(load(source, "@" .. mod.path .. "/screen.lua"))()(mod,
    nil, { storage = storage })
  local function make(game, opts)
    opts = opts or {}
    local native = PcMenu.new(game, opts)
    if native.message then return native end
    if opts.save and opts.save ~= game.save then
      game = setmetatable({ save = opts.save }, { __index = game })
    end
    local screen = workspace.new(game)
    screen.modernPCGeneration, screen.modernPCEntryGeneration = 2, 2
    screen.modernPCOnClose = opts.onClose
    screen.modernPCWriter = opts.writer or (game.writeSave and function() return game:writeSave() end)
    screen.modernPCIconRenderer = PartyMenu.new(game, { save = game.save })
    screen.modernPCPicRenderer = BoxMenu.new(game, { save = game.save, mode = "move" })
    PortraitCutouts.attachBox(screen.modernPCPicRenderer)
    screen.modernPCExtras = {}
    for i, entry in ipairs(native.entries) do
      if entry.id == "decoration" or (not entry.builtin and type(entry.onSelect) == "function") then
        local index = i
        screen.modernPCExtras[#screen.modernPCExtras + 1] = {
          label = entry.label, action = "extra",
          activate = function() native.index = index; native:choose() end,
        }
      end
    end
    function screen:wantsFillScale() return true end
    function screen:drawsWidescreen() return true end
    function screen:drawWidescreen(winW, winH)
      local G = love.graphics
      local scale = math.max(1, math.floor(math.min(winW / 160, winH / 144)))
      local width = math.max(160, math.min(640, math.floor(winW / scale)))
      local height = 144
      if winH >= winW * 1.35 then
        scale = math.max(1, math.floor(winW / 160))
        width, height = 160, math.min(256, math.floor(winH / scale))
      end
      self.modernPCDrawWidth, self.modernPCDrawHeight = width, height
      self.modernPCLastWideWidth = width
      self.modernPCLastWideHeight = height
      color(PAPER); G.rectangle("fill", 0, 0, winW, winH)
      G.push("all")
      G.translate(math.floor((winW - width * scale) / 2), math.floor((winH - height * scale) / 2))
      G.scale(scale, scale)
      local ok, err = pcall(self.draw, self)
      G.pop()
      self.modernPCDrawWidth, self.modernPCDrawHeight = nil, nil
      if not ok then error(err, 0) end
    end
    function screen:modernPCActionItems() return storage.actionItems(self) end
    function screen:modernPCRunAction(entry) return storage.runAction(self, entry) end
    return screen
  end
  for _, id in ipairs({ "Gen2PcMenu", "Gen2BoxMenu" }) do
    local record = { new = make }
    if mod.content.screens:get(id) then mod.content.screens:override(id, record)
    else mod.content.screens:register(id, record) end
  end
  mod.exports.generation, mod.exports.boxCount = 2, Boxes.NUM_BOXES
  mod.log:info("direct Gen 2 party-and-box workspace with native Mail enabled")
end
