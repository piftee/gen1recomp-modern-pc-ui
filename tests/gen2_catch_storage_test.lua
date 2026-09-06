-- Headless guards; the companion driver exercises real Gen 2 catches.
local Boxes = { NUM_BOXES=14, MONS_PER_BOX=20, PARTY_SIZE=6 }
function Boxes.isFull(save,index) return (save.counts[index] or 0)>=Boxes.MONS_PER_BOX end
function Boxes.setCurrent(save,index) save.currentBox=index;return true end
package.loaded["src.core.gen2.Boxes"]=Boxes
local enabled, callback, checks = true, nil, 0
local mod={ options={enabled=function() return enabled end},events={on=function(_,name,fn)
  assert(name=="screen.pushed");callback=fn
end} }
local path=arg[1] or "mods/modern_pc_ui/gen2_catch_storage.lua"
local storage=dofile(path)(mod)
local function eq(a,b,label) checks=checks+1;assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function fixture()
  local save={party={{},{},{},{},{},{}},counts={[1]=20,[2]=20},currentBox=1}
  local screen={screenId="Gen2BattleState",save=save,battle={wild=true},game={data={items={
    POKE_BALL={pocket="BALL"},POTION={pocket="ITEM"},
  }}}}
  function screen:currentBox() return self.save.currentBox end
  function screen:useItem(id,token) self.seenBox=self:currentBox();self.calls=(self.calls or 0)+1;return id,token end
  callback({state=screen});return screen,save
end
local screen,save=fixture()
local a,b=screen:useItem("POKE_BALL","native result")
eq(save.currentBox,3,"skips consecutive full boxes")
eq(screen.seenBox,3,"native gate and write receive the destination")
eq(a,"POKE_BALL","native return values retained")
eq(b,"native result","native extra arguments retained")
callback({state=screen});screen:useItem("POKE_BALL")
eq(screen.calls,2,"repeated screen pushes do not double-wrap")
for current=1,14 do
  screen,save=fixture();save.currentBox=current;save.counts={}
  for i=1,14 do save.counts[i]=20 end
  local expected=current%14+1;save.counts[expected]=19
  screen:useItem("POKE_BALL")
  eq(save.currentBox,expected,"wrap/search from box "..current)
end
screen,save=fixture();save.counts={};screen:useItem("POKE_BALL")
eq(save.currentBox,1,"available current box stays selected")
screen,save=fixture();for i=1,14 do save.counts[i]=20 end
screen:useItem("POKE_BALL");eq(save.currentBox,1,"full storage leaves native refusal in control")
for _,flag in ipairs({"tutorial","contest","link"}) do
  screen,save=fixture();screen[flag]=true;screen:useItem("POKE_BALL")
  eq(save.currentBox,1,flag.." storage is unchanged")
end
screen,save=fixture();screen.battle.wild=false;screen:useItem("POKE_BALL")
eq(save.currentBox,1,"trainer balls do not switch boxes")
screen,save=fixture();screen.battle.over=true;screen:useItem("POKE_BALL")
eq(save.currentBox,1,"completed battles do not switch boxes")
screen,save=fixture();table.remove(save.party);screen:useItem("POKE_BALL")
eq(save.currentBox,1,"party receives catches first")
for _,item in ipairs({"POTION","UNKNOWN"}) do
  screen,save=fixture();screen:useItem(item);eq(save.currentBox,1,item.." cannot switch boxes")
end
screen,save=fixture();enabled=false;screen:useItem("POKE_BALL")
eq(save.currentBox,1,"suite PC off restores native behavior in an open battle")
enabled=true;screen:useItem("POKE_BALL")
eq(save.currentBox,3,"suite PC on restores automatic routing")
print(checks.."/"..checks.." Gen 2 catch storage checks passed")
