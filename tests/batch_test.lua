local checks = 0
local function check(ok, why) assert(ok, why); checks = checks + 1 end
for _, path in ipairs({ "mods/modern_pc_ui/batch.lua",
    "mods/modern_ui_suite/components/modern_pc_ui/batch.lua" }) do
  local B = dofile(path)
  local function fixture()
    local save = { party = {}, boxes = { {}, {}, {} }, mail = { party = {} } }
    for i = 1, 6 do save.party[i] = { id = i, hp = 10, moves = { { pp = 3 } } } end
    for i = 1, 12 do save.boxes[1][i] = { id = i + 6, hp = 12 } end
    return save
  end
  local function mark(save, list, indices)
    local marks = {}
    for _, i in ipairs(indices) do
      marks[#marks + 1] = { mon = list[i], sourceList = list, sourceIndex = i,
        sourceRegion = list == save.party and "party" or "box", sourceBox = 1 }
    end
    return marks
  end
  local s = fixture()
  local p, b = s.party, s.boxes[1]
  local originals = { p[1], p[6], b[1], b[6] }
  local plan = assert(B.plan(s, mark(s, b, { 1, 2, 3, 4, 5, 6 }), p, 1, 6))
  check(p[1] == originals[1] and b[1] == originals[3], "planning is mutation-free")
  check(B.commit(s, plan), "whole-party swap succeeds with full party")
  check(p == s.party and b == s.boxes[1], "list identities retained")
  check(p[1] == originals[3] and p[6] == originals[4]
    and b[1] == originals[1] and b[6] == originals[2], "six-for-six exact mapping")
  s = fixture()
  local marks = mark(s, s.boxes[1], { 1, 3 })
  table.remove(s.boxes[1], 2)
  check(not B.plan(s, marks, s.boxes[2], 1, 20), "any stale mark rejects complete batch")
  s = fixture()
  check(not B.plan(s, mark(s, s.party, { 1, 2, 3, 4, 5, 6 }), s.boxes[2], 1, 20),
    "cannot empty party")
  check(not B.plan(s, mark(s, s.boxes[1], { 1, 2 }), s.party, 6, 6), "partial destination capacity refuses")
  local second = { id = 101 }
  s.boxes[2][1] = second
  marks = mark(s, s.boxes[1], { 4, 2 })
  marks[3] = { mon = second, sourceList = s.boxes[2], sourceIndex = 1,
    sourceRegion = "box", sourceBox = 2 }
  local wanted = { marks[1].mon, marks[2].mon, second }
  plan = assert(B.plan(s, marks, s.boxes[3], 20, 20))
  check(B.commit(s, plan), "far empty destination uses compact list insertion")
  check(s.boxes[3][1] == wanted[1] and s.boxes[3][2] == wanted[2]
    and s.boxes[3][3] == wanted[3], "cross-box marking order is deterministic")
  s = fixture()
  local mon, moves, party, box = s.party[1], s.party[1].moves, s.party, s.boxes[1]
  local letter = { text = "HELLO" }
  s.mail.party[1] = letter
  plan = assert(B.plan(s, mark(s, s.party, { 1, 2 }), s.boxes[1], 1, 20))
  local ok = B.commit(s, plan, function()
    mon.moves[1].pp = 0; mon.hp = 0; s.mail.party[1] = nil
    letter.text = "BAD"; s.newField = {}; s.pikachuHappiness = 2
    error("simulated second-member preparation failure")
  end)
  check(not ok, "commit failure is reported")
  check(s.party == party and s.boxes[1] == box and s.party[1] == mon,
    "rollback preserves list and Pokémon references")
  check(mon.moves == moves and moves[1].pp == 3 and mon.hp == 10,
    "rollback restores nested move/HP fields")
  check(s.mail.party[1] == letter and letter.text == "HELLO"
    and s.newField == nil and s.pikachuHappiness == nil, "rollback restores Mail and added save fields")
  -- Conservation across varying group sizes, occupied swaps and empty targets.
  for n = 1, 6 do
    for at = 1, 6 do
      s = fixture()
      local indices = {}
      for i = 1, n do indices[i] = i end
      plan = B.plan(s, mark(s, s.boxes[1], indices), s.party, at, 6)
      if at + n - 1 <= 6 then
        check(plan and B.commit(s, plan), "valid group swap commits")
        local seen, count = {}, 0
        for _, list in ipairs({ s.party, s.boxes[1] }) do
          for _, m in ipairs(list) do
            check(not seen[m.id], "no duplicated Pokémon")
            seen[m.id], count = true, count + 1
          end
        end
        check(count == 18 and #s.party == 6 and #s.boxes[1] == 12, "no Pokémon lost or over capacity")
      else check(not plan, "overflow batch rejected") end
    end
  end
end
print(("PC batch %d/%d checks passed"):format(checks, checks))
