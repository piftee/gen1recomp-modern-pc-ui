-- Isolated, silent background runtime only. All saves belong to this test.
return function(game)
  local Save=require("src.core.gen2.Save")
  local Boxes=require("src.core.gen2.Boxes")
  local Mon=require("src.battle.gen2.Mon")
  local Battle=require("src.battle.gen2.Battle")
  local Catching=require("src.battle.gen2.Catching")
  local Screens=require("src.ui.Screens")
  local Runtime=require("src.mods.Runtime")
  local Version=require("src.core.GameVersion")
  local checks=0
  local function check(ok,label) checks=checks+1;assert(ok,label);print("[CATCH STORAGE] "..label) end
  local function eq(a,b,label) check(a==b,label) end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local function mon(species) return assert(Mon.new(game.data,species or "PIDGEY",10)) end
  if os.getenv("CATCH_REOPEN")=="1" then
    local loaded=assert(Save.load(Version.get()))
    eq(loaded.currentBox,3,"automatic destination survives a full process restart")
    local caught=loaded.boxes[3][1]
    eq(caught.nickname,"OVERFLOW","caught nickname survives a full process restart")
    eq(caught.item,"BERRY","caught held item survives a full process restart")
    eq(#loaded.boxes[1],20,"full source remains intact after restart")
    eq(#loaded.boxes[2],20,"skipped full box remains intact after restart")
    print("[CATCH STORAGE] PASS restart "..checks);return
  end
  local function fresh(current,counts,partyCount,unattached)
    clear();game.save=Save.newGame({playerName="CATCH QA",trainerId=1234})
    local save=game.save;save.party={};save.currentBox=current or 1
    for i=1,(partyCount or 6) do save.party[i]=mon("CYNDAQUIL") end
    for i=1,Boxes.NUM_BOXES do
      save.boxes[i]={}
      for slot=1,((counts or {})[i] or 0) do save.boxes[i][slot]=mon("WOOPER") end
    end
    save.inventory.MASTER_BALL=5;save.inventory.POKE_BALL=5;save.inventory.FRIEND_BALL=5
    local enemy=mon();enemy.item="BERRY";enemy.hp=1;enemy.status="SLP"
    enemy.moves[1].pp=0
    local battle=Battle.new({data=game.data,save=save,party=save.party,wild=enemy,
      random=function() return 0 end})
    local screen=Screens.build(game,"Gen2BattleState",{save=save,battle=battle,onDone=function() end})
    if not unattached then game.stack:push(screen) end
    return screen,save,battle,enemy
  end
  local function countReference(save,enemy)
    local count=0
    for _,v in ipairs(save.party) do if v==enemy then count=count+1 end end
    for _,box in pairs(save.boxes) do for _,v in ipairs(box) do if v==enemy then count=count+1 end end end
    return count
  end
  local function capture(screen,save,battle,enemy,target)
    local previous=Boxes.box(save,target)[1]
    local caughtEvent,atEvent
    local cancel=Runtime.events:on("pokemon.caught",function(event)
      caughtEvent=event;atEvent=save.boxes[target][1]==enemy and save.currentBox==target
    end,0,"catch-storage-qa")
    local before=save.inventory.MASTER_BALL
    screen:useItem("MASTER_BALL");cancel()
    eq(battle.outcome,"caught","real Master Ball succeeds")
    eq(save.inventory.MASTER_BALL,before-1,"exactly one ball is consumed")
    eq(save.currentBox,target,"active box advances to destination "..target)
    eq(save.boxes[target][1],enemy,"native capture inserts at the destination head")
    if previous then eq(save.boxes[target][2],previous,"existing destination occupant is preserved") end
    eq(countReference(save,enemy),1,"captured record exists exactly once")
    eq(#save.party,6,"full party remains intact")
    eq(enemy.item,"BERRY","held item is preserved")
    eq(enemy.hp,enemy.maxHp,"native box HP restoration is retained")
    eq(enemy.moves[1].pp,enemy.moves[1].maxPp,"native box PP restoration is retained")
    eq(enemy.status,nil,"native box status clearing is retained")
    check(save.pokedex.caught[enemy.species],"native caught Pokédex record is retained")
    check(caughtEvent and caughtEvent.mon==enemy and caughtEvent.destination=="box" and atEvent,
      "caught event observes the stored record in its actual destination")
    local nickname=false
    for _,event in ipairs(screen.queue) do
      if event.kind=="ask-nickname" and event.mon==enemy then nickname=true end
    end
    check(nickname,"native nickname prompt references the stored Pokémon")
  end

  local screen,save,battle,enemy=fresh(1,{[1]=20,[2]=20,[3]=1},6,true)
  screen:useItem("MASTER_BALL")
  check(screen.message and screen.message:find("full",1,true),"unmodified Gen 2 reproduces the current-box-full refusal")
  eq(save.inventory.MASTER_BALL,5,"original refusal leaves ball unused")
  eq(countReference(save,enemy),0,"original refusal stores no Pokémon")
  game.stack:push(screen)
  check(screen.modernPCCatchStorage,"loaded package attaches catch routing")
  capture(screen,save,battle,enemy,3)
  eq(#save.boxes[1],20,"full source box is untouched")
  eq(#save.boxes[2],20,"next full box is skipped without alteration")
  enemy.nickname="OVERFLOW"
  local persisted=save

  screen,save,battle,enemy=fresh(4,{[4]=2})
  capture(screen,save,battle,enemy,4)
  screen,save,battle,enemy=fresh(14,{[14]=20,[1]=20,[2]=19})
  capture(screen,save,battle,enemy,2)
  eq(#save.boxes[2],20,"destination respects its twenty-Pokémon capacity")
  eq(battle.boxFilled,true,"last-slot catch retains the native just-filled flag")
  screen,save,battle,enemy=fresh(2,{[2]=20})
  capture(screen,save,battle,enemy,3)

  local full={};for i=1,Boxes.NUM_BOXES do full[i]=20 end
  screen,save,battle,enemy=fresh(11,full)
  local queue=screen.queue;local turnCalls=0;local takeTurn=battle.takeTurn
  battle.takeTurn=function(self,...) turnCalls=turnCalls+1;return takeTurn(self,...) end
  screen:useItem("MASTER_BALL")
  check(screen.message and screen.message:find("full",1,true),"all-full storage retains a clear refusal")
  eq(save.inventory.MASTER_BALL,5,"all-full refusal consumes no ball")
  eq(turnCalls,0,"all-full refusal consumes no battle turn")
  eq(save.currentBox,11,"all-full refusal keeps current box")
  eq(countReference(save,enemy),0,"all-full refusal never inserts beyond capacity")

  screen,save,battle,enemy=fresh(11,full,5)
  screen:useItem("MASTER_BALL")
  eq(save.party[6],enemy,"a free party slot takes priority even with every box full")
  eq(save.currentBox,11,"party catch does not switch boxes")
  eq(countReference(save,enemy),1,"party catch exists exactly once")

  screen,save,battle,enemy=fresh(1,{[1]=20})
  local attempt=Catching.attempt
  Catching.attempt=function() return false,0 end
  local ok,why=pcall(screen.useItem,screen,"POKE_BALL");Catching.attempt=attempt;assert(ok,why)
  eq(save.currentBox,2,"failed throw keeps the next usable box selected")
  eq(save.inventory.POKE_BALL,4,"failed throw retains native ball consumption")
  eq(countReference(save,enemy),0,"failed throw stores no Pokémon")

  screen,save,battle,enemy=fresh(1,{[1]=20})
  attempt=Catching.attempt;Catching.attempt=function() return true,255 end
  ok,why=pcall(screen.useItem,screen,"FRIEND_BALL");Catching.attempt=attempt;assert(ok,why)
  eq(save.boxes[2][1],enemy,"specialty-ball catch uses the next box")
  eq(enemy.happiness,Catching.FRIEND_BALL_HAPPINESS,"Friend Ball happiness survives routing")

  check(Save.save(persisted),"native save serializer accepts the overflow capture")
  local loaded=assert(Save.load(Version.get()))
  eq(loaded.currentBox,3,"automatic box selection survives native save/load")
  eq(loaded.boxes[3][1].nickname,"OVERFLOW","stored nickname survives native save/load")
  eq(loaded.boxes[3][1].item,"BERRY","stored held item survives native save/load")
  check(not love.window.hasFocus(),"test remained in the background")
  clear();print("[CATCH STORAGE] PASS native "..checks)
end
