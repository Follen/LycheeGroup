-- Real Find controller, LycheeUI list and SeasonScores service with native API substitutes.
-- Standalone: lua tests/test_season_picker.lua
local Fixture=dofile("tests/ui_fixture.lua")
local checks=0
local function Equal(actual,expected,message)
 if T then T.eq(actual,expected,message)
 else assert(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected)) end
 checks=checks+1
end
local function Check(value,message)
 if T then T.ok(value,message) else assert(value,message) end
 checks=checks+1
end
local function Near(actual,expected,message) Check(math.abs(actual-expected)<.01,message) end
local function Click(button) button:Fire("OnClick","LeftButton") end
local function Factor(point,axis)
 if axis=="x" then return point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5 end
 return point:find("BOTTOM") and 0 or point:find("TOP") and 1 or .5
end
-- Resolve actual anchor chains; the fixture's GetLeft/GetRight are viewport stubs.
local function Coordinate(node,anchor,axis,root)
 local size=axis=="x" and node:GetWidth() or node:GetHeight()
 if node==root then return Factor(anchor,axis)*size end
 local point,relative,relativePoint,x,y=node:GetPoint()
 if type(relative)~="table" then
  x,y=relative or 0,relativePoint or 0;relative=node:GetParent();relativePoint=point
 elseif type(relativePoint)~="string" then x,y=relativePoint or 0,x or 0;relativePoint=point end
 return Coordinate(relative,relativePoint,axis,root)+(axis=="x" and x or y)+(Factor(anchor,axis)-Factor(point,axis))*size
end
local function Session(locale)
 local f=Fixture(locale);local a,u,g=f.A,f.U,f.G
 local s={fixture=f,requests=0,mapReads=0,statReads=0,scoreReads=0,maps={},cmIDs={},levels={},scores={}}
 local nativeInfo,nativeActivities,nativeName=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities,C_LFGList.GetActivityGroupInfo
 local entries,ids,names={},{},{}
 for index=1,14 do
  local key,id,cmID,mapID=19+index,99+index,100+index,500+index
  names[key]=index==14 and (locale=="zhCN" and "在首次滚动窗口之外的长副本名称仍应完整显示" or "A long dungeon title beyond the initial visible viewport") or "Dungeon "..index
  entries[id]={id=id,categoryID=2,mapID=mapID,fullName=names[key],shortName=names[key],groupFinderActivityGroupID=key,difficultyID=8,isMythicPlusActivity=true,maxNumPlayers=5,orderIndex=index}
  ids[#ids+1]=id
  s.cmIDs[#s.cmIDs+1]=cmID;s.maps[cmID]=mapID;s.levels[cmID]={level=14+index};s.scores[cmID]=350+index
 end
 -- A normal variant keeps the real difficulty selection path available.
 entries[200]={id=200,categoryID=2,mapID=501,fullName="Normal variant",shortName="Normal",groupFinderActivityGroupID=20,difficultyID=1,maxNumPlayers=5,orderIndex=20}
 entries[201]={id=201,categoryID=2,mapID=520,fullName="Normal only",shortName="Normal only",groupFinderActivityGroupID=40,difficultyID=1,maxNumPlayers=5,orderIndex=21}
 ids[#ids+1]=200;ids[#ids+1]=201;names[40]="Normal only"
 C_LFGList.GetActivityInfoTable=function(id) return entries[id] or nativeInfo(id) end
 C_LFGList.GetAvailableActivities=function(category,...) if category==2 then return ids end;return nativeActivities(category,...) end
 C_LFGList.GetActivityGroupInfo=function(id) return names[id] or nativeName(id) end
 g.Catalog:Invalidate()
 C_ChallengeMode.GetMapTable=function() s.mapReads=s.mapReads+1;return s.cmIDs end
 C_ChallengeMode.GetMapUIInfo=function(id) return "Dungeon",nil,nil,nil,nil,s.maps[id] end
 C_MythicPlus={
  RequestMapInfo=function() s.requests=s.requests+1;if s.synchronous then s:Fire("CHALLENGE_MODE_MAPS_UPDATE") end end,
  GetSeasonBestForMap=function(id) s.statReads=s.statReads+1;return s.levels[id],{level=99} end,
  GetSeasonBestAffixScoreInfoForMap=function(id) s.scoreReads=s.scoreReads+1;return {},s.scores[id] end,
 }
 -- One unknown timed record with a valid score of zero, and an ambiguous map.
 s.levels[102]=nil;s.scores[102]=0;s.cmIDs[#s.cmIDs+1]=999;s.maps[999]=503
 dofile("addon/LycheeGroup_Group/SeasonScores.lua")
 function s:Fire(event)
  for _,node in ipairs(f.S.nodes) do if node.events[event] then node:Fire("OnEvent",event) end end
 end
 function s:Subscriptions()
  local count=0
  for _,node in ipairs(f.S.nodes) do
   if node.events.CHALLENGE_MODE_MAPS_UPDATE then
    for _ in pairs(node.events) do count=count+1 end
   end
  end
  return count
 end
 a:SetSetting("reduceMotion",true);a:Open("find")
 s.page=u.pages.find
 function s:Open()
  local p=self.page
  if not p.picker or not p.picker:IsShown() then p:SelectCategory("seasonDungeon") end
  for _,button in ipairs(p.difficultyButtons) do if button:IsShown() and button.value==8 then Click(button);return end end
  error("keystone difficulty not found")
 end
 function s:Row(key)
  for _,row in ipairs(self.page.activities.rows) do if row.key==key and row:IsShown() then return row end end
 end
 return s
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local s=Session(locale);local p,u=s.page,s.fixture.U
 Equal(s.requests,0,"opening Find does not request selector scores")
 s:Open();Equal(s.requests,1);Equal(s:Subscriptions(),3)
 local row=s:Row(20)
 Equal(row.seasonLevel:GetText(),"+15");Equal(row.seasonScore:GetText(),locale=="zhCN" and "351 分" or "351 pts")
 Near(row.seasonLevel.color[1],u.Theme.good[1])
 Equal(s:Row(21).seasonLevel:GetText(),"—");Equal(s:Row(21).seasonScore:GetText(),locale=="zhCN" and "0 分" or "0 pts")
 Equal(s:Row(22).seasonLevel:GetText(),"—");Equal(s:Row(22).seasonScore:GetText(),"—")
 Check(not s:Row(0).seasonLevel:IsShown(),"the all-instances row has no character records")
 -- A checkbox keeps native multi-select behavior while scores occupy a separate area.
 Click(row.multiSelect);Equal(row.multiSelect:GetValue(),true);Check(p.pickerConfirm:IsShown())
 local reads=s.mapReads+s.statReads+s.scoreReads
 local initialRows=#p.activities.rows
 for _,scale in ipairs({.7,1,1.3}) do
  u:ApplyFont(s.fixture.A.Fonts:GetPath(),scale)
  local width=p.picker:GetWidth()
  Check(width>336,"offscreen titles contribute to picker width")
  for _,control in ipairs({p.tierChoice,p.difficultySurface,p.activities,p.pickerConfirm}) do Near(control:GetWidth(),width-16) end
  local previous=0
  for _,button in ipairs(p.difficultyButtons) do if button:IsShown() then
   local left=Coordinate(button,"LEFT","x",p.difficultySurface)
   Check(left>=previous-.01,"difficulty tabs do not overlap")
   previous=left+button:GetWidth()
   Check(button.label:GetWidth()+.01>=button.label:GetUnboundedStringWidth(),"difficulty text remains complete")
  end end
  Check(previous<=p.difficultySurface:GetWidth()-2.99,"difficulty tabs stay inside the expanded surface")
  for _,offset in ipairs({0,240,480,720,0}) do
   p.activities:SetPixelOffset(offset,false)
   for _,current in ipairs(p.activities.rows) do if current.key and current:IsShown() then
    if current.seasonLevel:IsShown() then
     Check(current.title:GetWidth()+.01>=current.title:GetUnboundedStringWidth(),"recycled titles stay complete")
     local titleRight=Coordinate(current.title,"RIGHT","x",current)
     local badgeLeft=Coordinate(current.seasonLevel,"LEFT","x",current)
     Check(titleRight<=badgeLeft-11.99,"title and records have a twelve-unit gap")
     for _,label in ipairs({current.seasonLevel,current.seasonScore}) do
      Check(label:GetWidth()+.01>=label:GetUnboundedStringWidth(),"record text fits its reserved width")
      Check(Coordinate(label,"RIGHT","x",current)<=Coordinate(current.multiSelect,"LEFT","x",current)-7.99,"records do not overlap the checkbox")
      Check(Coordinate(label,"BOTTOM","y",current)>=-.01 and Coordinate(label,"TOP","y",current)<=current:GetHeight()+.01,"both lines fit the row")
     end
     Check(Coordinate(current.seasonLevel,"BOTTOM","y",current)>=Coordinate(current.seasonScore,"TOP","y",current)+1.99,"record lines have a two-unit gap")
    else
     Equal(current.seasonLevel:GetText(),"");Equal(current.seasonScore:GetText(),"")
    end
   end end
  end
  local offscreen
  p.activities:SetPixelOffset(720,false);offscreen=s:Row(33);Check(offscreen~=nil,"the last long title is reachable")
  p.activities:SetPixelOffset(0,false);Check(not s:Row(0).seasonLevel:IsShown(),"recycling a scored row back to all-instances clears it")
  Equal(s:Row(20).multiSelect:GetValue(),true,"scrolling and font changes preserve checkbox state")
  for _=1,4 do p:RefreshPicker();Near(p.picker:GetWidth(),width,"repeated layout does not accumulate width") end
 end
 Equal(#p.activities.rows,initialRows,"scrolling and repeated fonts reuse the existing row pool")
 Equal(s.mapReads+s.statReads+s.scoreReads,reads,"layout and scrolling reuse per-CMID records")
 local beforeWidth=p.picker:GetWidth()
 s.scores[114]=9876543210;s:Fire("CHALLENGE_MODE_MAPS_UPDATE")
 Check(p.picker:GetWidth()>beforeWidth,"new score width updates when the API event arrives")
 p:SelectCategory("2");Equal(s:Subscriptions(),0)
 for _,current in ipairs(p.activities.rows) do Check(not current.seasonLevel:IsShown() and not current.seasonScore:IsShown(),"scores clear outside seasonal dungeons") end
 local requests=s.requests;reads=s.mapReads+s.statReads+s.scoreReads
 s:Fire("CHALLENGE_MODE_COMPLETED");p:RefreshPicker();Equal(s.requests,requests);Equal(s.mapReads+s.statReads+s.scoreReads,reads)
 p:ClosePicker();s:Open();Equal(s.requests,requests+1)
 p.picker:Hide();Equal(s:Subscriptions(),0)
 requests=s.requests;reads=s.mapReads+s.statReads+s.scoreReads
 p:RefreshPicker();s:Fire("CHALLENGE_MODE_MAPS_UPDATE")
 Equal(s.requests,requests);Equal(s.mapReads+s.statReads+s.scoreReads,reads,"hidden refresh performs no score queries")
 s:Open();s.fixture.A:Open("notes");Equal(s:Subscriptions(),0,"leaving Find releases season observation")
end

-- Sync native completion cannot recursively request, and preview never falls back to live data.
do
 local s=Session("enUS");local p,u=s.page,s.fixture.U;s.synchronous=true
 s:Open();Equal(s.requests,1);Equal(p.refreshingPicker,nil)
 Equal(s:Row(20).seasonLevel:GetText(),"+15")
 local requests=s.requests;local reads=s.mapReads+s.statReads+s.scoreReads
 u.preview={provider={Catalog=s.fixture.G.Catalog}}
 p:RefreshPicker();Equal(s:Subscriptions(),0)
 Equal(s.requests,requests);Equal(s.mapReads+s.statReads+s.scoreReads,reads,"missing preview service performs no live API reads")
 local previewBegins,previewEnds=0,0
 u.preview.provider.SeasonScores={
  Begin=function() previewBegins=previewBegins+1 end,
  End=function() previewEnds=previewEnds+1 end,
  GetRecord=function() return {level=42,score=700} end,
 }
 p:RefreshPicker();Equal(previewBegins,1)
 Equal(s:Row(20).seasonLevel:GetText(),"+42")
 Equal(s.requests,requests);Equal(s.mapReads+s.statReads+s.scoreReads,reads)
 p.picker:Hide();Equal(previewEnds,1)
 u.preview=nil
end

if not T then print("Season picker: "..checks.." checks passed") end
