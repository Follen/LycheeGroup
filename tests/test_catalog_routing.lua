-- Routing preserves existing category preference without warming unrelated data.
TestStubs.Install({locale="enUS",realm="Realm"})
_G.bit={bor=function(a,b) return a+b end}
_G.Enum={LFGListFilter={PvE=1,CurrentSeason=2,NotCurrentSeason=4}}
_G.LycheeGroup={Group={L={seasonDungeon="S2",seasonRaid="S3"}},GetLocale=function() return "enUS" end}
local source={
 [2001]={categoryID=2,mapID=20},[2002]={categoryID=2,mapID=20},[2003]={categoryID=2,mapID=20},
 [3001]={categoryID=3,mapID=31},[3002]={categoryID=3,mapID=32},[9001]={categoryID=9,mapID=90},
}
local reads,allocations=0,0
local function NativeList(category,flags)
 if category==2 then return flags==3 and {2001,2003} or {2002,2003} end
 if category==3 then return {3001,3002} end
 if category==9 then return {9001} end
 return {}
end
_G.C_EncounterJournal={GetInstanceForGameMap=function(map) return map end}
_G.C_LFGList={GetAvailableCategories=function() return {2,3,121,9} end,
 GetLfgCategoryInfo=function(id) return {name="Category "..id} end,
 GetAvailableActivities=function(category,_,flags) reads=reads+1;return NativeList(category,flags) end,
 GetActivityInfoTable=function(id)
  local data=source[id];if not data then return end
  allocations=allocations+1
  return {categoryID=data.categoryID,mapID=data.mapID,fullName="Activity "..id,shortName="A",groupFinderActivityGroupID=id,maxNumPlayers=5}
 end,
}
local function Session()
 Load.addon("LycheeGroup_Group","Catalog.lua")
 local c=LycheeGroup.Group.Catalog
 function c:GetTiers() self.tiers={};self.seasonRaidJournals={[31]=true};return self.tiers end
 return c
end
local function Legacy(c,id,preferred)
 if preferred then for _,a in ipairs(c:GetActivities(preferred)) do if a.id==id then return preferred end end end
 for _,category in ipairs(c:GetCategories()) do for _,a in ipairs(c:GetActivities(category.key)) do if a.id==id then return category.key end end end
end
for _,preferred in ipairs({false,"seasonDungeon","2","seasonRaid","3","9","missing"}) do
 for _,id in ipairs({2001,2002,2003,3001,3002,9001,9999}) do
  for _,mode in ipairs({"cold_nil","cached","invalid","stale","invalidated"}) do
   local function Init()
    local c=Session()
    if mode~="cold_nil" then local a=c:GetActivity(id);if a then
     if mode=="invalid" then a.categoryID="unknown" elseif mode=="stale" then a.categoryID=a.categoryID==9 and 2 or 9 end
    end end
    if mode=="invalidated" then c:Invalidate() end
    return c
   end
   local expected=Legacy(Init(),id,preferred or nil)
   T.eq(Init():GetContextForActivity(id,preferred or nil),expected,mode.."/"..tostring(preferred).."/"..id)
  end
 end
end
local c=Session();c:GetActivity(2003)
T.eq(c:GetContextForActivity(2003),"seasonDungeon","shared native-category membership keeps seasonal-first order")
T.eq(c:GetContextForActivity(2003,"2"),"2","a valid explicit ordinary-category preference stays first")
c=Session();c:GetActivity(9001);reads,allocations=0,0
T.eq(c:GetContextForActivity(9001),"9")
T.eq(reads,1);T.eq(allocations,0,"routing uses the already-owned activity and does not read another native table")
T.eq(c.activities[2001],nil);T.eq(c.activities[3001],nil,"unrelated activity directories stay lazy")
T.eq(#c:GetActivities("seasonDungeon"),2,"later deliberate access still loads all legal activity data")
T.ok(c.activities[2001]~=nil)
