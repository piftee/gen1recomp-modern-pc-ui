-- Pure batch planning plus rollback-safe application. Never remove a marked
-- Pokémon until every source and the complete destination have been checked.
local Batch = {}
local function copy(list)
  local out = {}
  for i, mon in ipairs(list) do out[i] = mon end
  return out
end
local function indexOf(list, mon)
  for i, value in ipairs(list) do if value == mon then return i end end
end
function Batch.plan(save, marks, target, at, capacity)
  if type(marks) ~= "table" or #marks == 0 then return nil, "Mark a POKéMON first." end
  local plan = { lists = {}, outgoing = {}, incoming = {}, count = #marks }
  local function staged(list)
    if not plan.lists[list] then plan.lists[list] = copy(list) end
    return plan.lists[list]
  end
  local side, seen = marks[1].sourceRegion, {}
  for _, mark in ipairs(marks) do
    local live = mark.sourceRegion == "party" and save.party
      or save.boxes[mark.sourceBox]
    if mark.sourceRegion ~= side or live ~= mark.sourceList
        or live[mark.sourceIndex] ~= mark.mon or seen[mark.mon] then
      return nil, "Selection changed. Cancel and mark again."
    end
    seen[mark.mon] = true
    staged(live)
  end
  local toParty, fromParty = target == save.party, side == "party"
  local dest = staged(target)
  at = math.max(1, math.min(tonumber(at) or 1, #dest + 1))
  plan.at = at
  if fromParty ~= toParty then
    if at + #marks - 1 > capacity then
      return nil, "Not enough destination slots."
    end
    for i, mark in ipairs(marks) do
      local source = staged(mark.sourceList)
      local si, di = assert(indexOf(source, mark.mon)), at + i - 1
      local other = dest[di]
      if other then source[si], dest[di] = other, mark.mon
      else table.remove(source, si); table.insert(dest, di, mark.mon) end
      plan.outgoing[#plan.outgoing + 1] = fromParty and mark.mon or other
      plan.incoming[#plan.incoming + 1] = toParty and mark.mon or other
    end
  else
    -- Remove by identity, then insert in marking order (also across boxes).
    local removedBefore = 0
    for _, mark in ipairs(marks) do
      if mark.sourceList == target and mark.sourceIndex < at then
        removedBefore = removedBefore + 1
      end
      local source = staged(mark.sourceList)
      table.remove(source, assert(indexOf(source, mark.mon)))
    end
    if #dest + #marks > capacity then return nil, "Not enough destination slots." end
    at = math.max(1, math.min(at - removedBefore, #dest + 1))
    plan.at = at
    for i, mark in ipairs(marks) do table.insert(dest, at + i - 1, mark.mon) end
  end
  plan.party = plan.lists[save.party] or save.party
  if #plan.party < 1 then return nil, "Keep one POKéMON in your party!" end
  if #plan.party > 6 then return nil, "The party is full!" end
  for list, proposed in pairs(plan.lists) do
    if #proposed > (list == save.party and 6 or 20) then
      return nil, "This BOX is full!"
    end
  end
  return plan
end
-- Snapshot the save's table graph without cloning identities. On error, all
-- original lists, mons, nested move records and Mail tables are restored in place.
local function snapshot(root)
  local graph = {}
  local function visit(value)
    if type(value) ~= "table" or graph[value] then return end
    local fields = {}
    graph[value] = fields
    for k, v in pairs(value) do fields[k] = v; visit(k); visit(v) end
  end
  visit(root)
  return function()
    for object, fields in pairs(graph) do
      for k in pairs(object) do object[k] = nil end
      for k, v in pairs(fields) do object[k] = v end
    end
  end
end
function Batch.commit(save, plan, apply)
  local restore = snapshot(save)
  local ok, err = pcall(function()
    for list, proposed in pairs(plan.lists) do
      for i = #list, 1, -1 do list[i] = nil end
      for i, mon in ipairs(proposed) do list[i] = mon end
    end
    if apply then apply(plan) end
  end)
  if not ok then restore(); return false, tostring(err) end
  return true
end
return Batch
