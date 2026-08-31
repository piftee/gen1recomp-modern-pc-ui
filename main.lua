-- Modern PC UI replaces only Someone's/Bill's Pokémon-storage screen. The
-- save format and the native 12-by-20 box model remain unchanged.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  if type(GameVersion.generation) == "function"
      and GameVersion.generation() == 2 then
    return require("mods.modern_pc_ui.gen2")(mod)
  end

  local genderMod = mod.find("gender_mod")
  local genderExports = genderMod and genderMod.exports or nil
  local gen1ModernUi = mod.find("gen1_modern_ui")
  local compatibility = {
    hgssSprites = mod.find("HGSS_SPRITES") ~= nil,
  }

  local source, readErr = mod:read("screen.lua")
  if not source then
    mod.log:error("screen.lua is missing (%s); reinstall the mod",
      tostring(readErr or "unknown read error"))
    return
  end

  local chunk, compileErr = load(source, "@" .. mod.path .. "/screen.lua")
  if not chunk then
    mod.log:error("screen.lua did not compile: %s", tostring(compileErr))
    return
  end

  local okFactory, factory = pcall(chunk)
  if not okFactory or type(factory) ~= "function" then
    mod.log:error("screen.lua must return a factory function: %s",
      tostring(factory))
    return
  end

  local okScreen, screen = pcall(factory, mod, genderExports, compatibility)
  if not okScreen or type(screen) ~= "table"
      or type(screen.new) ~= "function" then
    mod.log:error("PC screen factory failed: %s", tostring(screen))
    return
  end

  if mod.content.screens:get("BoxMenu") then
    mod.content.screens:override("BoxMenu", screen)
  else
    mod.content.screens:register("BoxMenu", screen)
  end

  -- Gen1 Modern UI preserves source-owned custom renderers when they publish
  -- this contract. The PC exposes a compact model for inspection but keeps its
  -- direct-manipulation canvas and controller authoritative.
  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      ModernPCWorkspace = {
        match = function(state)
          return type(state) == "table" and state.modernPCUI == true
        end,
        model = function(game, state)
          local rows = {}
          local party = game and game.save and game.save.party or {}
          for _, mon in ipairs(party) do
            rows[#rows + 1] = {
              label = mon.nickname or mon.species or "POKéMON",
              value = mon.level and ("LV%d"):format(mon.level) or "",
            }
          end
          return {
            title = "POKéMON STORAGE",
            rows = rows,
            index = state.partyIndex or 1,
            footer = { "Modern PC UI" },
          }
        end,
        layer = "screen",
        canSuppressNative = false,
      },
    },
  }

  local uiExports = gen1ModernUi and gen1ModernUi.exports
  if uiExports and type(uiExports.registerAdapter) == "function" then
    local ok, registered, reason = pcall(uiExports.registerAdapter, {
      owner = mod.id,
      contract = mod.exports.gen1ModernUi,
    })
    if not ok or registered == false then
      mod.log:warn("Gen1 Modern UI adapter registration failed: %s",
        tostring(reason or registered))
    end
  end

  local known = {
    { "gender_mod", "Gender Mod" },
    { "dv_tracker", "DV Tracker" },
    { "kanto_ribbons", "Kanto Ribbons" },
    { "gen1_modern_ui", "Gen1 Modern UI" },
    { "DRAMATIC_SHAPE", "DramaticShape Shinies" },
    { "CRYSTAL_251", "Crystal 251" },
    { "crystal_animated_sprites_with_shiny_visuals", "Crystal Sprites" },
    { "unique_menu_icons", "Unique Menu Icons" },
    { "HGSS_SPRITES", "HGSS Visual Overhaul" },
    { "overworld_wild_spawns", "Wilds of Kanto" },
    { "Gold_Silver_Sprites", "Gold & Silver Sprites" },
    { "qol_toggles", "QoL Toggles" },
    { "anytime_rename", "Anytime Rename" },
  }
  local adapters = {}
  for _, entry in ipairs(known) do
    if mod.find(entry[1]) then adapters[#adapters + 1] = entry[2] end
  end
  local suffix = #adapters > 0 and
    (" with " .. table.concat(adapters, ", ")) or ""
  mod.log:info("modern party-and-box workspace enabled%s", suffix)
end
