-- Natural offline allocation diagnostic; never stops, steps or forces GC.
-- Native substitute tables are not WoW AddOn bytes. Production remains unchanged.
-- lua tests/measure_ui_cycles.lua [profile|pages|fonts]
local mode=arg[1] or "combined"
local f=dofile("tests/ui_fixture.lua")("enUS")
local A,U=f.A,f.U
dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
local function Count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function Stats(label)
 local c=U.context;local records=0
 for controller in pairs(c.fixedControllers or {}) do records=records+Count(controller.records) end
 print(string.format("%s KiB=%.3f nodes=%d fonts=%d elements=%d controllers=%d records=%d layouts=%d inputs=%d",label,collectgarbage("count"),#f.S.nodes,Count(c.fontStyles),Count(c.elements),Count(c.fixedControllers),records,Count(c.layouts),#U.inputs))
end
local function Settle() U.Motion:Tick(2) end
local pages={"find","create","notes","settings"}
for _,page in ipairs(pages) do A:Open(page);Settle() end
Stats("warm")
local profile={};local level=0;local starts,children={},{}
local function Finish(counter,...)
 local delta=collectgarbage("count")-starts[level]
 counter.calls=counter.calls+1;counter.net=counter.net+delta-children[level]
 level=level-1;if level>0 then children[level]=children[level]+delta end
 return ...
end
local function Wrap(owner,prefix,selected)
 for key,original in pairs(owner) do
  if type(original)=="function" and (not selected or selected[key]) then
   local name=prefix..":"..key;local counter={calls=0,net=0};profile[name]=counter
   owner[key]=function(...)
    level=level+1;local at=level;starts[at]=collectgarbage("count");children[at]=0
    return Finish(counter,original(...))
   end
  end
 end
end
if mode=="profile" then
 Wrap(U,"Host");Wrap(U.Tooltip,"Tooltip");Wrap(U.Application,"Application")
 for _,page in ipairs(pages) do Wrap(U.pages[page],page) end
 Wrap(A.Appearance,"Appearance");Wrap(A.Configuration,"Configuration");Wrap(A.Fonts,"Fonts")
 Wrap(U.C,"C");Wrap(U.context,"Context")
 local native=getmetatable(U.frame).__index
 if type(native)=="table" then Wrap(native,"NativeStub",{
  SetPoint=true,ClearAllPoints=true,SetAllPoints=true,SetFont=true,SetSpacing=true,SetText=true,
  SetVertexColor=true,SetTextColor=true,SetColorTexture=true,SetTexCoord=true,SetSize=true,
  SetWidth=true,SetHeight=true,GetStringWidth=true,GetStringHeight=true,
 }) end
end
for round=1,12 do
 if mode~="fonts" then for _,page in ipairs(pages) do A:Open(page);Settle() end end
 if mode~="pages" then
  assert(A.API.Configuration:Set({["settings.fontScale"]=round%2==1 and 130 or 100},{storage="session"}));Settle()
 end
 Stats("round-"..round)
end
if mode=="profile" then
 local ordered={};for name,counter in pairs(profile) do ordered[#ordered+1]={name=name,counter=counter} end
 table.sort(ordered,function(a,b) return a.counter.net>b.counter.net end)
 for index=1,math.min(30,#ordered) do local row=ordered[index];print(string.format("exclusive %s calls=%d netKiB=%.3f",row.name,row.counter.calls,row.counter.net)) end
end
