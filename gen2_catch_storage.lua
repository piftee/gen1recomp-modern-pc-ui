-- Route an ordinary wild-ball attempt before the native full-box gate runs.
-- Keep the native catch tail responsible for ownership, caught data, naming,
-- healing, PP, Unown registration and the pokemon.caught event.
return function(mod)
  local Boxes = require("src.core.gen2.Boxes")
  local Storage = {}

  function Storage.nextBoxWithSpace(save, current)
    for offset = 0, Boxes.NUM_BOXES - 1 do
      local index = (current - 1 + offset) % Boxes.NUM_BOXES + 1
      if not Boxes.isFull(save, index) then return index end
    end
  end

  function Storage.attach(screen)
    if type(screen) ~= "table" or screen.modernPCCatchStorage
        or (screen.screenId ~= "Gen2BattleState" and screen.screenId ~= "BattleState")
        or type(screen.useItem) ~= "function"
        or type(screen.currentBox) ~= "function" then return end
    screen.modernPCCatchStorage = true
    local nativeUseItem = screen.useItem
    screen.useItem = function(self, itemId, ...)
      local enabled = not mod.options.enabled or mod.options:enabled()
      local save, battle = self.save, self.battle
      local data = self.game and self.game.data
      local item = data and data.items and data.items[itemId]
      if enabled and save and battle and battle.wild and not battle.over
          and not self.tutorial and not self.contest and not self.link
          and item and item.pocket == "BALL"
          and #(save.party or {}) >= Boxes.PARTY_SIZE then
        local current = self:currentBox()
        local target = Storage.nextBoxWithSpace(save, current)
        if target and target ~= current then
          -- Select once, before the attempt. The gate, insertion and
          -- just-filled check must all use this same box, even when the
          -- captured Pokémon takes its final slot. Subsequent PC visits and
          -- catches continue using the automatically selected box.
          Boxes.setCurrent(save, target)
        end
      end
      -- If every box is full, the original gate refuses without spending a
      -- ball or a turn. Trainer, contest, tutorial and party catches stay native.
      return nativeUseItem(self, itemId, ...)
    end
  end

  mod.events:on("screen.pushed", function(event)
    Storage.attach(event and (event.state or event.screen))
  end)
  return Storage
end
