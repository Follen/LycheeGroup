-- Real Results getters through real Find renderers: raid rows need no full roster.
local f=dofile("tests/ui_fixture.lua")("enUS")
local A,U,G=f.A,f.U,f.G
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
G.Public=function(value) return value end
function G:RemotePlayerKey(name) return A:PlayerKey(name) end
local fixtureResults=G.Results
dofile("addon/LycheeGroup_Group/Results.lua")
local actual=G.Results;G.Results=fixtureResults
for _,name in ipairs({"GetDetails","GetMemberCounts","GetLeaderClass","GetProgressCount"}) do G.Results[name]=actual[name] end
local members,encounters={},{}
local reads={players=0,counts=0,relations=0,details=0}
C_LFGList.GetSearchResultPlayerInfo=function(id,index)
 reads.players=reads.players+1
 local source=members[id][index];if not source then return end
 local member={};for key,value in pairs(source) do member[key]=value end;return member
end
C_LFGList.GetSearchResultMemberCounts=function() reads.counts=reads.counts+1;return {TANK=2,HEALER=6,DAMAGER=22} end
C_LFGList.GetSearchResultFriends=function() reads.relations=reads.relations+1;return {"Friend-Away"},{},{} end
C_LFGList.GetSearchResultEncounterInfo=function(id) return encounters[id] end
local full=G.Results.GetDetails
G.Results.GetDetails=function(self,record) reads.details=reads.details+1;return full(self,record) end
local raidActivity={id=1,categoryID=3,maxNumPlayers=30,mapID=110,journalID=10,difficultyID=14}
EJ_GetDifficulty=function() return 14 end;EJ_SetDifficulty=function() end
EJ_SelectInstance=function() end
EJ_GetEncounterInfoByIndex=function(index) return ({"Boss A","Boss B"})[index] end
local function Record(id,maximum,leaderIndex,flag)
 local record={id=id,name="Result "..id,activity=maximum==5 and G.Catalog:GetActivity(2) or raidActivity,activityID=maximum==5 and 2 or 1,
  categoryID=maximum==5 and 2 or 3,maxNumPlayers=maximum,numMembers=maximum,leaderName="Member"..id.."_"..leaderIndex.."-Away",
  bnetFriends=1,charFriends=0,guildMates=0,age=0,requiredItemLevel=0}
 record.leaderKey=record.leaderName
 members[id]={}
 for index=1,maximum do members[id][index]={name="Member"..id.."_"..index.."-Away",classFilename=index==leaderIndex and "MAGE" or "WARRIOR",className="Class",assignedRole="DAMAGER",isLeader=flag and index==leaderIndex or false} end
 return record
end
RAID_CLASS_COLORS={MAGE={r=.1,g=.2,b=.9},WARRIOR={r=.8,g=.6,b=.4}}
local raid=Record(1,30,26,true);local application=Record(2,30,4,false)
G.records[1],G.records[2]=raid,application;encounters[1]={}
G.apps[1]={id=2,result=application,name=application.name,leaderName=application.leaderName,categoryID=3,status="applied"}
A:SetSetting("reduceMotion",true);A:Open("find")
local page=U.pages.find;page:SelectCategory("seasonRaid");page:CommitChoice();page:DoSearch();page:RefreshApplications()
Check(reads.details==0 and reads.relations==0,"non-five-player result and application rows never build complete members or relationships")
Check(raid.details==nil and application.details==nil,"scalar list rendering does not leave a partial details snapshot")
Check(reads.players==30,"leader lookup stops at each original matching member, including non-first leaders")
Check(page.results.rows[1].leader.color[3]==.9 and page.appList.rows[1].leader.color[3]==.9,"both list renderers preserve the non-first leader's class color")
Check(page.results.rows[1].roster.counts[1].text:GetText()=="2","raid role counts retain their native count display")
Check(U:ProgressText(raid)=="0/2" and U:ProgressText(application)=="—","zero progress and unknown progress remain distinct")
Check(U:ProgressText(raid,{encounters={"Boss A"}})=="1/2","an opened Tooltip's supplied full progress is used directly")
local prior=reads.players;page:RefreshResults();page:RefreshApplications()
Check(reads.players==prior and reads.details==0,"unchanged list refresh reuses scalar caches")
local directReads=0
C_LFGList.GetSearchResultLeaderInfo=function(id)
 directReads=directReads+1
 return {name=id==1 and "Member1_26" or "Member2_4",isLeader=true,classFilename="MAGE"}
end
raid.leaderClassKnown,raid.leaderClass=nil,nil;application.leaderClassKnown,application.leaderClass=nil,nil
page:RefreshResults();page:RefreshApplications()
Check(directReads==2 and reads.players==prior,"the direct native leader API colors both large-group lists without member reads")
Check(raid.details==nil and application.details==nil and reads.details==0,"direct summaries still do not create partial details")
Check(page.results.rows[1].leader.color[3]==.9 and page.appList.rows[1].leader.color[3]==.9,"direct summaries retain the same leader colors")
local hovered=page.results.rows[1];page.results.clip.mouseOver=true;hovered.mouseOver=true
hovered.tooltipArea:Fire("OnEnter")
Check(reads.details>0 and raid.details and #raid.details.members==30,"opening the actual Tooltip reads the complete raid roster")
Check(reads.relations==1 and raid.details.relationships.bnet[1]=="Friend-Away","the opened Tooltip retains complete relationship details")
U.Tooltip:Hide()
local party=Record(3,5,3,true);G.records[1]=nil;G.records[3]=party
local before=reads.details;page:RefreshResults()
Check(reads.details>before and party.details and #party.details.members==5,"five-player rows still build all portrait members")
Check(page.results.rows[1].roster.slots[1].icon:IsShown(),"five-player portraits remain visible")
U:Hide(true)
print("Result row scalar details: "..checks.." checks passed")
