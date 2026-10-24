-- Unknown result numbers retain their meaning through the real Results service and UI.
local Fixture=dofile("tests/ui_fixture.lua")
local f=Fixture("zhCN")
local A,U,G=f.A,f.U,f.G
local originalSecret=issecretvalue
local secret={}
issecretvalue=function(value) return value==secret end
local native={}
local list={}
local nativeAPI=C_LFGList
local originalAPI={}
local apiKeys={"GetSearchResultInfo","GetFilteredSearchResults","GetSearchResultPlayerInfo","GetSearchResultLeaderInfo","GetSearchResultMemberCounts","GetSearchResultEncounterInfo","GetSearchResultFriends"}
for _,key in ipairs(apiKeys) do originalAPI[key]=nativeAPI[key] end
local function Result(id,numbers)
 local info={name="Numbers "..id,leaderName="Leader"..id.."-Away",partyGUID="numbers-"..id,activityIDs={2},numMembers=2,age=60,requiredItemLevel=0}
 for key,value in pairs(numbers or {}) do info[key]=value end
 native[id]=info;list[#list+1]=id
 return info
end
C_LFGList.GetSearchResultInfo=function(id)
 local copy={};for key,value in pairs(native[id] or {}) do copy[key]=value end;return copy
end
C_LFGList.GetFilteredSearchResults=function() return #list,list end
local memberReads=0
C_LFGList.GetSearchResultPlayerInfo=function() memberReads=memberReads+1 end
C_LFGList.GetSearchResultLeaderInfo=function() end
C_LFGList.GetSearchResultMemberCounts=function() return {TANK=0,HEALER=0,DAMAGER=0} end
C_LFGList.GetSearchResultEncounterInfo=function() return {} end
C_LFGList.GetSearchResultFriends=function() return {},{},{} end
function G:RemotePlayerKey(name) return A:PlayerKey(name) end
G.Game={frame=CreateFrame("Frame")}
function G.Applications:AdoptResult() return false end
G.filters={}
function G.Search:GetFilters() return G.filters end
dofile("addon/LycheeGroup_Group/Results.lua")
local R=G.Results
function G:GetResults() return R:GetResults() end
function G:GetResult(id) return R:GetResult(id) end
function G:GetResultCount() return R:GetCount() end
function G:GetResultDetails(id) return R:GetDetails(id) end
local function Refresh()
 R:BeginSearch(1);R:CommitResults(1)
end
local function Filter(filters)
 G.filters=filters or {};R:InvalidateView();return R:GetResults()
end
local ok,err=pcall(function()
 Result(1,{numMembers=secret,age=secret,requiredItemLevel=secret})
 Refresh()
 local record=R:GetResult(1)
 T.eq(record.numMembers,nil,"a public result table with a restricted member field is unknown")
 T.eq(record.age,nil,"restricted age is not a new listing")
 T.eq(record.requiredItemLevel,nil,"restricted item level is not an unrestricted requirement")
 T.same(Filter({maxItemLevel=600}),{},"maximum-only item-level ranges exclude unknown requirements")
 T.same(Filter({maxMembers=5}),{},"maximum-only member ranges exclude unknown counts")
 T.same(Filter({minMembers=1}),{})
 T.same(Filter({}),{1},"unknown numbers remain available without numeric filters")
 -- Consumers must not invent members or attempt a numeric loop over nil.
 T.eq(R:GetLeaderClass(record),nil)
 T.eq(R:HasMemberSpec(record,71),false)
 T.eq(R:HasMemberClass(record,"WARRIOR"),false)
 T.eq(R:MatchesPartyFilters(record,"WARRIOR","TANK",true),true)
 T.eq(#R:GetDetails(record).members,0)
 T.eq(memberReads,0,"unknown member counts do not query made-up roster indexes")
 native[1].numMembers,native[1].age,native[1].requiredItemLevel=2,120,0
 R:OnResultUpdated(1)
 T.eq(R:GetResult(1),record,"recovery retains the published record")
 T.eq(record.numMembers,2);T.eq(record.age,120);T.eq(record.requiredItemLevel,0)
 T.same(Filter({maxItemLevel=0,maxMembers=2}),{1},"known zero is a real unrestricted requirement and matches a zero maximum")
 R:GetDetails(record);T.eq(memberReads,2,"recovered member counts invalidate the empty detail snapshot")
 native[1].numMembers,native[1].age,native[1].requiredItemLevel=nil,nil,nil
 R:OnResultUpdated(1)
 T.eq(record.numMembers,nil);T.eq(record.age,nil);T.eq(record.requiredItemLevel,nil)
 T.same(Filter({maxItemLevel=600}),{},"missing fields share the unknown contract")

 Result(2,{numMembers=3,age=20,requiredItemLevel=100})
 Result(3,{numMembers=0,age=0,requiredItemLevel=0})
 Result(4,{numMembers=secret,age=secret,requiredItemLevel=secret,numCharFriends=1})
 Result(5,{numMembers=4,age=30,requiredItemLevel=200,numCharFriends=1})
 Result(6,{numMembers=5,age=10,requiredItemLevel=300})
 Result(7,{numMembers=secret,age=secret,requiredItemLevel=secret})
 G.declinedParties["numbers-6"],G.declinedParties["numbers-7"]=1,1
 Refresh()
 for _,sort in ipairs({"members","itemLevel","rating","newest"}) do
  local expected=(sort=="members" or sort=="itemLevel") and {5,4,2,3,1,6,7} or {5,4,3,2,1,6,7}
  T.same(Filter({sort=sort}),expected,"default "..sort.." retains relation/decline buckets and places unknown values last within each bucket")
 end
 T.same(Filter({maxItemLevel=600}),{5,3,2,6})
 T.same(Filter({maxMembers=5}),{5,3,2,6})
 T.same(Filter({minMembers=3,maxMembers=4}),{5,2},"member range endpoints are inclusive")
 Filter({})

 A.Configuration:Set({["layout.tables.findResults.sortKey"]=false,["layout.tables.findResults.descending"]=false},{storage="character"})
 A:SetSetting("reduceMotion",true);A:Open("find")
 local page=U.pages.find
 page:CommitChoice();G.state="done";page:RefreshResults()
 local function Row(id)
  for _,row in ipairs(page.results.rows) do if row.key==id then return row end end
  error("missing result row "..id)
 end
 T.eq(Row(1).ilvl:GetText(),"—");T.eq(Row(1).age:GetText(),"—")
 T.eq(Row(3).ilvl:GetText(),"不限","a known zero requirement keeps the unrestricted label")
 T.eq(Row(3).age:GetText(),"","known zero age retains its existing display")
 T.eq(U:MemberCountText(R:GetResult(1)),"—/5")
 T.eq(U:MemberCountText(R:GetResult(3)),"0/5")
 for _,key in ipairs({"members","ilvl","age"}) do
  page.resultsHeader:SetSort(key,false);page:RefreshResults()
  T.same(page.results.ids,{5,4,3,2,1,6,7},key.." ascending keeps unknowns last inside each relation/decline bucket")
  page.resultsHeader:SetSort(key,true);page:RefreshResults()
  T.same(page.results.ids,{5,4,2,3,1,6,7},key.." descending keeps unknowns last inside each relation/decline bucket")
 end
 U.Tooltip:ShowGroup(Row(1),R:GetResult(1))
 T.eq(U.Tooltip.interactive.metrics[2].value:GetText(),"—","group tooltip shows an unknown item-level requirement")
 T.eq(U.Tooltip.interactive.metrics[4].value:GetText(),"—/5")
 U.Tooltip:ShowGroup(Row(3),R:GetResult(3))
 T.eq(U.Tooltip.interactive.metrics[2].value:GetText(),"不限")
 U:Hide(true)
end)
issecretvalue=originalSecret
for _,key in ipairs(apiKeys) do nativeAPI[key]=originalAPI[key] end
if not ok then error(err) end
