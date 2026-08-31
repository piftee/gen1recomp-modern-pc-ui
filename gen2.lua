-- Bill's PC in Gen 2 is already a direct-manipulation controller across the
-- party and fourteen boxes. Keep that model and add the Modern PC workspace
-- identity to its native list/picture presentation.
return function(mod)
  local BoxMenu = require("src.ui.gen2.BoxMenu")
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local GbcPalette = require("src.render.GbcPalette")

  local INK_BLACK = { 0, 0, 0 }
  local INK_WHITE = { 1, 1, 1 }
  local INK_LIGHT = { 0.75, 0.85, 1 }
  local HEADER = { 1.00, 0.10, 0.08 }
  local HEADER_LIGHT = { 1.00, 0.56, 0.18 }
  local BLUE = { 0.23, 0.45, 0.92 }
  local BLUE_DARK = { 0.08, 0.18, 0.43 }
  local MODAL = { 0.54, 0.62, 0.91 }
  local PAPER = { 0.94, 0.95, 0.96 }

  local TYPE_COLORS = {
    normal = { 144 / 255, 152 / 255, 162 / 255 },
    fighting = { 206 / 255, 63 / 255, 107 / 255 },
    flying = { 143 / 255, 168 / 255, 222 / 255 },
    poison = { 171 / 255, 106 / 255, 200 / 255 },
    ground = { 217 / 255, 119 / 255, 70 / 255 },
    rock = { 201 / 255, 182 / 255, 139 / 255 },
    bug = { 144 / 255, 192 / 255, 44 / 255 },
    ghost = { 82 / 255, 105 / 255, 173 / 255 },
    fire = { 254 / 255, 156 / 255, 85 / 255 },
    water = { 77 / 255, 144 / 255, 214 / 255 },
    grass = { 101 / 255, 188 / 255, 94 / 255 },
    electric = { 244 / 255, 210 / 255, 59 / 255 },
    psychic = { 249 / 255, 113 / 255, 119 / 255 },
    ice = { 115 / 255, 206 / 255, 191 / 255 },
    dragon = { 9 / 255, 109 / 255, 195 / 255 },
    dark = { 91 / 255, 82 / 255, 101 / 255 },
    steel = { 91 / 255, 142 / 255, 161 / 255 },
    fairy = { 236 / 255, 144 / 255, 231 / 255 },
  }

  local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
  end

  local function inkPalette(color)
    color = color or INK_BLACK
    local ink = {}
    for i = 1, 3 do
      local value = color[i] or 0
      ink[i] = math.floor((value <= 1 and value * 255 or value) + 0.5)
    end
    return {
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] / 2), math.floor(ink[2] / 2),
        math.floor(ink[3] / 2) }, ink,
    }
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    if not maxWidth or Font.width(text) <= maxWidth then return text end
    local budget = math.max(0, maxWidth - Font.width("."))
    if Font.split and Font.spansFitting then
      local spans = Font.split(text)
      local count = Font.spansFitting(spans, budget)
      return count > 0 and text:sub(1, spans[count].to) .. "." or ""
    end
    while #text > 0 and Font.width(text) > budget do text = text:sub(1, -2) end
    return text .. "."
  end

  local function drawInk(text, x, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs(
      inkPalette(color), false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(text, math.floor(x), math.floor(y))
      return Font.width(text)
    end
    local pen = math.floor(x)
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - math.floor(x)
  end

  local function drawInkRight(text, right, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawInk(text, right - width, y, width, color)
  end

  local function drawInkCentered(text, x, y, width, color)
    text = fitText(text, width)
    drawInk(text, x + math.floor((width - Font.width(text)) / 2), y,
      width, color)
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = math.max(0, math.min(cut or 0, math.floor(math.min(w, h) / 2)))
    if cut == 0 or not love.graphics.polygon then
      love.graphics.rectangle(mode, x, y, w, h)
      return
    end
    love.graphics.polygon(mode, {
      x + cut, y, x + w - cut, y, x + w, y + cut,
      x + w, y + h - cut, x + w - cut, y + h,
      x + cut, y + h, x, y + h - cut, x, y + cut,
    })
  end

  local function pcLayout(menu)
    local width = menu.modernPCWideWidth or 160
    local detailW = width >= 196
      and math.min(96, math.max(64, math.floor(width * 0.28))) or 58
    local listX = detailW + 6
    return {
      width = width, detailW = detailW, listX = listX,
      listW = width - listX - 2,
    }
  end

  local function installWideDraw(menu, drawPanel)
    menu.drawWidescreen = function(self, winW, winH)
      local G = love.graphics
      local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
      local width = math.max(160, math.min(640, math.floor(winW / scale)))
      local ox = math.floor((winW - width * scale) / 2)
      local oy = math.floor((winH - 144 * scale) / 2)
      setColor({ 0.94, 0.94, 0.98 })
      G.rectangle("fill", 0, 0, winW, winH)
      G.push()
      G.translate(ox, oy)
      G.scale(scale, scale)
      self.modernPCLastWideWidth = width
      self.modernPCWideWidth = width
      drawPanel(self)
      self.modernPCWideWidth = nil
      G.pop()
      G.setColor(1, 1, 1, 1)
    end
  end

  local function monColor(menu, mon)
    local def = mon and menu.pokemon and menu.pokemon[mon.species]
    local types = def and def.types or {}
    return TYPE_COLORS[tostring(types[1] or "normal"):lower()]
      or TYPE_COLORS.normal
  end

  local function drawBackdrop(menu)
    local G = love.graphics
    local width = menu.modernPCWideWidth or 160
    setColor({ 0.94, 0.94, 0.98 })
    G.rectangle("fill", 0, 0, width, 144)
    setColor({ 0.73, 0.76, 0.94 })
    for x = -144, width, 16 do
      G.line(x, 16, x + 126, 120)
      G.line(x + 126, 16, x, 120)
    end
  end

  local PIC_PAD = { [7] = { 0, 0 }, [6] = { 1, 1 }, [5] = { 1, 2 } }

  local function drawDetailSprite(menu, mon)
    if not mon then return end
    local image, colors
    if mon.isEgg then
      colors = menu.panelColors and menu:panelColors("EGG", mon.shiny)
      local gfx = (menu.menuGfx or {}).eggHatch
      image = menu.image and menu:image(gfx and gfx.egg)
    else
      colors = menu.panelColors and menu:panelColors(mon.species, mon.shiny)
      image = menu.picFor and menu:picFor(mon)
    end
    if not image then return end
    local pad = PIC_PAD[math.floor(image:getWidth() / 8)] or PIC_PAD[7]
    love.graphics.setColor(1, 1, 1, 1)
    local function body()
      local layout = pcLayout(menu)
      local x = 5 + math.max(0, math.floor((layout.detailW - 58) / 2))
      love.graphics.draw(image, x + pad[1] * 8, 20 + pad[2] * 8)
    end
    if colors and GbcPalette.available() then GbcPalette.with(colors, body)
    else body() end
  end

  local function drawDetail(menu, mon)
    local G = love.graphics
    local layout = pcLayout(menu)
    local w = layout.detailW
    setColor({ 0.03, 0.04, 0.06 })
    chamfer("fill", 3, 18, w, 100, 4)
    setColor(mon and monColor(menu, mon) or { 0.40, 0.42, 0.48 })
    G.rectangle("fill", 5, 20, w - 4, 56)
    if mon then
      drawDetailSprite(menu, mon)
      if not mon.isEgg then
        drawInk(mon.nickname or mon.name or mon.species or "?", 8, 81, w - 10,
          INK_WHITE)
        drawInk("LV" .. tostring(mon.level or 1), 8, 92, w - 10, INK_LIGHT)
        local gender = mon.gender == "male" and "M"
          or mon.gender == "female" and "F" or "-"
        drawInkRight(gender, w - 4, 92, 12, INK_LIGHT)
        drawInk(mon.name or mon.species or "?", 8, 103, w - 10, INK_WHITE)
      else
        drawInkCentered("EGG", 8, 90, w - 10, INK_WHITE)
      end
    else
      drawInkCentered("EMPTY", 7, 86, w - 8, INK_LIGHT)
    end
  end

  local function drawFooter(menu)
    local G = love.graphics
    local width = menu.modernPCWideWidth or 160
    setColor(HEADER)
    G.rectangle("fill", 0, 120, width, 24)
    setColor(HEADER_LIGHT)
    G.rectangle("fill", 0, 120, width, 2)
    if menu.message then
      local y = 123
      for line in (tostring(menu.message) .. "\n"):gmatch("(.-)\n") do
        if line:lower():find("saving", 1, true) then
          line = "SAVING - LEAVE ON"
        end
        drawInk(line, 5, y, width - 10, INK_WHITE)
        y = y + 9
      end
    else
      if menu.phase == "insert" then
        drawInk("MOVE TO WHERE?", 5, 126, width - 10, INK_WHITE)
      elseif menu.phase == "submenu" then
        drawInk("CHOOSE ACTION", 5, 126, width - 10, INK_WHITE)
      else
        drawInk("A MOVE", 5, 126, 58, INK_WHITE)
        drawInkRight("L/R BOX", width - 5, 126, 70, INK_WHITE)
      end
    end
  end

  local function drawSubmenu(menu)
    if menu.phase ~= "submenu" then return end
    local G = love.graphics
    local rows = menu:submenuRows()
    local h = #rows * 16 + 22
    local width = menu.modernPCWideWidth or 160
    local x, y, w = width - 86, math.max(18, 118 - h), 84
    setColor(MODAL)
    chamfer("fill", x, y, w, h, 4)
    setColor(BLUE_DARK)
    G.setLineWidth(2)
    chamfer("line", x + 1, y + 1, w - 2, h - 2, 4)
    drawInk("SUMMARY", x + 8, y + 5, w - 16, INK_WHITE)
    for i, label in ipairs(rows) do
      local rowY = y + 18 + (i - 1) * 16
      local selected = i == menu.submenuIndex
      if selected then
        setColor(BLUE_DARK)
        G.rectangle("fill", x + 5, rowY, w - 10, 14)
        setColor(INK_WHITE)
        G.rectangle("fill", x + 8, rowY + 5, 3, 5)
      end
      drawInk(label, x + 14, rowY + 3, w - 22,
        selected and INK_WHITE or INK_BLACK)
    end
  end

  local function modernPanel(menu)
    local G = love.graphics
    local wasBattle = Font.useBattleExtra(true)
    local layout = pcLayout(menu)
    local width = layout.width
    drawBackdrop(menu)
    setColor(HEADER)
    G.rectangle("fill", 0, 0, width, 16)
    setColor(HEADER_LIGHT)
    G.rectangle("fill", 0, 14, width, 2)
    drawInk(tostring(menu:title()), 4, 4, 112, INK_WHITE)
    local capacityIndex = menu.mode == "deposit" and 0
      or (menu.boxIndex or menu.currentBox or 1)
    drawInkRight(("%02d/%02d"):format(#menu:list(),
      menu:capacityAt(capacityIndex)), width - 4, 4, 42, INK_WHITE)

    local list = menu:list()
    local panelMon = menu:panelMon()
    drawDetail(menu, panelMon)
    for visible = 1, 5 do
      local i = visible + (menu.scroll or 0)
      local y = 18 + (visible - 1) * 20
      local mon = list[i]
      local selected = i == menu.index
      local face = mon and monColor(menu, mon) or PAPER
      if selected and mon then
        face = { math.min(1, face[1] + 0.12), math.min(1, face[2] + 0.12),
          math.min(1, face[3] + 0.12) }
      end
      setColor(face)
      chamfer("fill", layout.listX, y, layout.listW, 18, 2)
      setColor(selected and BLUE or { 0.32, 0.34, 0.40 })
      G.setLineWidth(selected and 2 or 1)
      chamfer("line", layout.listX + 0.5, y + 0.5,
        layout.listW - 1, 17, 2)
      if menu.phase == "insert" and selected then
        setColor(HEADER)
        G.rectangle("fill", layout.listX + 3, y, layout.listW - 6, 2)
      end
      if mon then
        if selected then
          setColor(BLUE)
          G.rectangle("fill", layout.listX + 4, y + 5, 2, 8)
        end
        drawInk(mon.nickname or mon.name or mon.species or "?",
          layout.listX + 10, y + 5, layout.listW - 16, INK_BLACK)
      elseif not (menu.phase == "insert") and i == menu:total() then
        drawInk("CANCEL", layout.listX + 10, y + 5,
          layout.listW - 16, INK_BLACK)
      end
    end
    drawFooter(menu)
    drawSubmenu(menu)
    Font.useBattleExtra(wasBattle)
    G.setColor(1, 1, 1, 1)
  end

  local inherited = mod.content.screens:get("Gen2BoxMenu")
  local provider = inherited or BoxMenu
  local record = {
    new = function(game, ...)
      local menu = provider.new(game, ...)
      if type(menu) ~= "table" or menu.modernPCGeneration == 2 then return menu end
      local nativePanel = menu.drawPanel
      menu.modernPCUI = true
      menu.modernPCGeneration = 2
      menu.classicGen2BoxPanel = nativePanel
      menu.drawPanel = modernPanel
      installWideDraw(menu, menu.drawPanel)
      return menu
    end,
  }

  if inherited then
    mod.content.screens:override("Gen2BoxMenu", record)
  else
    mod.content.screens:register("Gen2BoxMenu", record)
  end
  mod.exports.generation = 2
  mod.exports.boxCount = 14
  mod.log:info("modern fourteen-box Gen 2 storage workspace enabled")
end
