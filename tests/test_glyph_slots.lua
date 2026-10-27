-- Glyph slots retain Frame geometry while their textures supply native color.
local cases={
 {"host.navigation.item","icon","find"},{"host.settingsButton","icon","find"},{"host.closeButton","icon","find"},
 {"notes.addButton","icon","notes"},{"notes.navigation","glyph","notes"},{"notes.navigation","icon","notes"},
 {"notes.type","icon","notes"},{"notes.eClose","elementIcon","notes"},{"notes.record","kindIcons/positive","notes"},
 {"notes.record","kindIcons/neutral","notes"},{"notes.record","kindIcons/caution","notes"},
 {"notes.history","chevron","notes"},{"find.category","chevron","find"},{"find.searchIcon","root","find"},
 {"find.search","icon","find"},{"find.searchClear","elementIcon","find"},{"find.refresh","icon","find"},
 {"find.filterClose","icon","find"},{"find.pickerClose","icon","find"},{"find.limitNotice","close/icon","find"},
 {"create.pickerSearch","elementIcon","create"},{"create.pickerClear","elementIcon","create"},
 {"create.formNotice","close/icon","create"},{"create.correctionNotice","close/icon","create"},{"create.manageNotice","close/icon","create"},
 {"create.favoriteRow","remove/elementIcon","create"},
 {"tooltip.noteGlyph","root","tooltip"},{"tooltip.rich","noteGlyph","tooltip"},{"tooltip.back","elementIcon","tooltip"},
 {"modal","close/icon","modal"},{"settings.bindingNotice","close/icon","settings"},
}
local checks,failures=0,{}
local function Check(value,message)
 checks=checks+1
 if T then T.ok(value,message) else assert(value,message) end
end
local function Slot(target,record,name)
 if name=="root" then return target end
 if record.slots[name] then return record.slots[name] end
 local item=record.slots
 for part in name:gmatch("[^/]+") do item=item and item[tonumber(part) or part] end
 return item
end
for _,case in ipairs(cases) do
 local color={.17,.38,.61,1}
 local theme={schema=1,id="glyph.native",revision=1,appearance={main={elements={}}}}
 theme.appearance.main.elements[case[1]]={base={[case[2]]={color=color,width=19,height=15,points={{"CENTER","$parent","CENTER",3,-2}}}}}
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true},theme)
 f.A.Notes:Merge({{name="Player",server="Home",class="WARRIOR",type="positive",reason="Note",timestamp=100}})
 f.G.GetHistory=function() return {{mapName="Dungeon",level=12,startedAt=10,completedAt=100,members={}}} end
 local createFrame=CreateFrame
 CreateFrame=function(kind,...)
  local frame=createFrame(kind,...)
  if kind=="Frame" then
   local previous=getmetatable(frame);local index=previous.__index
   local mt={};for key,value in pairs(previous) do mt[key]=value end
   mt.__index=function(object,key)
    if key=="GetTextColor" or key=="SetTextColor" or key=="GetVertexColor" or key=="SetVertexColor" then return nil end
    if type(index)=="function" then return index(object,key) end
    return index[key]
   end
   setmetatable(frame,mt)
  end
  return frame
 end
 local ok,err=pcall(function()
  f.A:Open((case[3]=="tooltip" or case[3]=="modal") and "find" or case[3])
  if case[1]=="create.pickerSearch" or case[1]=="create.pickerClear" then f.U.pages.create:TogglePicker() end
  if case[1]=="create.favoriteRow" then f.G.Presets:ToggleFavorite({activityID=2});f.U.pages.create.favoritesToggle:Fire("OnClick") end
  if case[1]=="find.pickerClose" then f.U.pages.find:SelectCategory("seasonDungeon") end
  if case[1]=="notes.history" then f.U.pages.notes:SelectTab("history") end
  if case[3]=="modal" then f.U:CopyText("Identity","Player-Away") end
  if case[1]=="settings.bindingNotice" then f.U.pages.settings:ShowBindingNotice("Recording") end
  if case[3]=="tooltip" then f.U.Tooltip:ShowPlayer(f.U.frame,{name="One-Away",nameKey="One-Away",class="MAGE"}) end
 end)
 CreateFrame=createFrame
 if not ok then failures[#failures+1]=case[1].."."..case[2]..": "..tostring(err)
 else
  local count=0
  local rebindTarget,rebindRecord,rebindGlyph
  for target,record in pairs(f.U.context.elements) do if record.id==case[1] and (not record.template or record.key~=nil) then
   local glyph=Slot(target,record,case[2]);count=count+1
   Check(glyph and glyph:GetObjectType()=="Frame",case[1].." retains the original glyph Frame")
   Check(glyph.GetTextColor==nil and glyph.GetVertexColor==nil,case[1].." cannot read native color from a Frame")
   Check(glyph:GetWidth()==19 and glyph:GetHeight()==15,case[1].." honors startup Frame size")
   local point,relative,relativePoint,x,y=glyph:GetPoint()
   Check(point=="CENTER" and relative==glyph:GetParent() and relativePoint=="CENTER" and x==3 and y==-2,case[1].." retains the original $parent and startup anchor")
   local texture=glyph.texture
   Check(texture and texture:GetObjectType()=="Texture",case[1].." reads color from its glyph texture")
   local actual={texture:GetVertexColor()}
   -- Native texture alpha shares the fourth color channel. A color-only
   -- declaration keeps RGB fixed while ordinary icon alpha feedback continues.
   for i=1,3 do Check(math.abs(actual[i]-color[i])<.000001,case[1].." honors startup RGB") end
   local owner=record.stateOwner
   if owner and owner.Fire then
    for _,event in ipairs({"OnEnter","OnLeave"}) do
     owner:Fire(event)
     local hovered={texture:GetVertexColor()}
     for i=1,3 do Check(math.abs(hovered[i]-color[i])<.000001,case[1].." retains its declared RGB after "..event) end
    end
   end
   if case[1]=="notes.record" then rebindTarget,rebindRecord,rebindGlyph=target,record,glyph end
  end end
  Check(count>0,case[1].." is constructed by the real route")
  if rebindTarget then
   local oldKey=rebindTarget.key
   f.A.Notes:Merge({{name="Newer",server="Home",class="MAGE",type="neutral",reason="Replacement",timestamp=200}})
   f.U.pages.notes:RefreshList()
   Check(rebindTarget.key~=oldKey,"a populated record reuses the same pool row for a new key")
   Check(Slot(rebindTarget,rebindRecord,case[2])==rebindGlyph,"rekeying preserves the original glyph Frame")
   local rebound={rebindGlyph.texture:GetVertexColor()}
   for i=1,3 do Check(math.abs(rebound[i]-color[i])<.000001,"rekeying retains the fixed texture RGB") end
  end
 end
 f.U:Hide(true)
end
for _,failure in ipairs(failures) do print("[glyph slot] "..failure) end
Check(#failures==0,"public glyph slots must construct with native Frame capabilities and preserve their geometry")
do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=false})
 local context=f.U.context;context.Motion:StopAll()
 local button=context.C.IconButton(context.frame,"close",32,function() end,{variant="creditsLink"})
 local before={button.icon.texture:GetVertexColor()}
 button:Fire("OnEnter")
 Check(context.Motion:IsRunning(button.icon),"real Glyph hover starts a color transition")
 context.Motion:Tick(.007)
 local current={button.icon.texture:GetVertexColor()}
 Check(current[1]~=before[1] or current[2]~=before[2] or current[3]~=before[3],"first Glyph animation frame interpolates without a cached .color field")
 button:Fire("OnLeave");context.Motion:Tick(0)
 local redirected={button.icon.texture:GetVertexColor()}
 for i=1,3 do Check(math.abs(redirected[i]-current[i])<.000001,"hover exit retargets from the current Glyph color") end
 context.Motion:Tick(.3)
 Check(not context.Motion:IsRunning(button.icon),"Glyph hover exit finishes its color transition")
 context:Hide()
end
print("Glyph Frame slots: "..checks.." checks passed")
