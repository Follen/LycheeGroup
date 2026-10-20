-- Local layout review from the real Lua widget tree. Sample data; no game calls.
-- lua tests/ui_preview.lua -> tests/preview-data.js
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G,S=f.A,f.U,f.G,f.S
UIParent:SetSize(1640,1000);A.db.reduceMotion=true
C_LFGList.GetActivityGroupInfo=function(id) return id==20 and "塞塔里斯神庙" or "尼鲁巴尔王宫" end
G.Catalog:GetActivity(2).fullName="塞塔里斯神庙（史诗钥石）";G.Catalog:GetActivity(2).name="塞塔里斯神庙（史诗钥石）"
local nativeDifficultyInfo=GetDifficultyInfo
GetDifficultyInfo=function(id) if id==8 then return "史诗钥石" end;return nativeDifficultyInfo(id) end
EJ_GetDifficulty=function() return 15 end;EJ_SetDifficulty=function() end;EJ_SelectInstance=function() end
EJ_GetEncounterInfoByIndex=function(index) return ({"乌格拉克斯","血缚恐魔","席克兰","拉夏南","虫巢扭曲者欧维纳克斯","节点女亲王凯威扎","流丝之庭","安苏雷克女王"})[index] end
RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43},PALADIN={r=.96,g=.55,b=.73},MAGE={r=.25,g=.78,b=.92},PRIEST={r=1,g=1,b=1},DRUID={r=1,g=.49,b=.04},SHAMAN={r=0,g=.44,b=.87}}
-- Native class artwork is a placeholder in this renderer; keep every class visible.
for _,class in ipairs({"HUNTER","ROGUE","DEATHKNIGHT","SHAMAN","WARLOCK","MONK","DRUID","DEMONHUNTER","EVOKER"}) do CLASS_ICON_TCOORDS[class]={0,.25,0,.25} end
local names={"晚风听雨","糖霜骑士","暮色星河","云上青鸟","柚子茶"}
local classes={"WARRIOR","PALADIN","MAGE","PRIEST","DRUID"}
local members={}
for i=1,5 do members[i]={name=names[i].."-晨风号角",nameKey=names[i].."-晨风号角",realm="晨风号角",class=classes[i],localizedClass=({"战士","圣骑士","法师","牧师","德鲁伊"})[i],assignedRole=i==1 and "TANK" or i==2 and "HEALER" or "DAMAGER",specName=({"防护","神圣","冰霜","暗影","平衡"})[i],itemLevel=642+i,dungeonScore=2800+i*70,isLeader=i==1,factionGroup=i%2} end
for i,member in ipairs(members) do member.subgroup=1;member.unit=i==1 and "player" or "party"..(i-1);member.guid="Sample-"..i;member.isSelf=i==1 end
function G:GetRoster() return {members[1],members[2],members[3]} end
function G.Results:GetDetails(record)
 if record.details then return record.details end
 local m={};for i=1,record.numMembers or 0 do m[i]=members[i] end
 return {members=m,counts=U:MemberCounts(m),encounters={},relationships={bnet={"同路人"},character={"糖霜骑士-晨风号角"},guild={"暮色星河"}}}
end
local historyMembers={}
for i,member in ipairs(members) do historyMembers[i]={name=names[i],realm=member.realm,class=member.class,specName=member.specName,specID=member.specID,assignedRole=member.assignedRole} end
function G:GetHistory() return {{id=1,mapName="艾杰斯亚学院",level=12,completedAt=1792051200,members=historyMembers},{id=2,mapName="蕨皮山谷",level=11,completedAt=1791964800,members=historyMembers}} end
local titles={"+12 稳定限时 来输出","+10 打完就走 来治疗","+13 冲分 熟练队","+11 周常 友好交流","+12 补一输出","+9 新人练习 一起打"}
for i,title in ipairs(titles) do G.records[i]={id=i,activityID=2,activity=A.Group.Catalog:GetActivity(2),categoryID=2,activityName="Dungeon activity",name=title,leaderName=members[(i-1)%5+1].name,leaderKey=members[(i-1)%5+1].nameKey,numMembers=i%3+2,maxNumPlayers=5,age=i*36,requiredItemLevel=635+i,requiredDungeonScore=2600,leaderOverallDungeonScore=2800+i*83,leaderRating=2800+i*83,requiredRating=2600,level=12,comment="熟练机制，开打前确认路线。打断分配好，沟通友善，争取限时。"} end
G.apps={{id=2,name=titles[2],status="applied",categoryID=2,result=G.records[2],activityID=2,expiresAt=GetTime()+250},{id=4,name=titles[4],status="invited",categoryID=2,result=G.records[4],activityID=2}};G.state="done"
A.Notes:Add("晚风听雨","晨风号角","路线清楚，会提醒打断；上次学院配合很好。",nil,"战士 · 防护",{type="positive",class="WARRIOR",specID=73})
A.Notes:Add("柚子茶","晨风号角","耐心，愿意带新手熟悉机制。",nil,"德鲁伊 · 平衡",{type="neutral",class="DRUID",specID=102})
A.Notes:Add("云上青鸟","白银之手","团队沟通顺畅，保留记录便于下次组队。",nil,"牧师 · 暗影",{type="caution",class="PRIEST",specID=258})
local shots={}
local function snapshot(name,root)
 U.Motion:Tick(2)
 local ids={};for i,n in ipairs(S.nodes) do ids[n]=i end
 local nodes={}
 for i,n in ipairs(S.nodes) do
  local points={};for _,p in ipairs(n.points) do local point={};for j,v in ipairs(p) do point[j]=type(v)=="table" and {ref=ids[v]} or v end;points[#points+1]=point end
  nodes[i]={id=i,parent=ids[n.parent],kind=n:GetObjectType(),shown=n.shown,alpha=n.alpha,w=n.w,h=n.h,points=points,all=ids[n.allPoints],text=(n:GetObjectType()=="FontString" or n:GetObjectType()=="EditBox") and n.text or nil,color=n.color,font=n.font,fill=n:GetObjectType()=="Texture" and n.fill or nil,vertex=n.vertex and {unpack(n.vertex)},texture=type(n.texture)~="table" and n.texture or nil,atlas=n.atlas,coords=n.texCoords,justify=n.justify,wrap=n.wrap,maxLines=n.maxLines,spacing=n.spacing,layer=n.layer,backdrop=n.backdropColor,rotation=n.rotation,level=n.level,strata=n.strata,scale=n.scale,clamp=n.clampInsets,thumb=ids[n.thumb],scroll=type(n.scroll)=="number" and n.scroll or nil,scrollChild=ids[n.scrollChild]}
 end
 shots[#shots+1]={name=name,nodes=nodes,root=ids[root or U.frame],menu=U.context.menu and U.context.menu:IsShown() and ids[U.context.menu] or nil,tooltip=U.Tooltip.interactive and U.Tooltip.interactive:IsShown() and ids[U.Tooltip.interactive] or U.Tooltip.frame and U.Tooltip.frame:IsShown() and ids[U.Tooltip.frame] or nil}
end
A:Open("find")
local function ChooseSearchActivity(category,key)
 local page=U.pages.find;page:SelectCategory(category)
 for _,row in ipairs(page.activities.rows) do if row.key==key then row:Fire("OnClick","LeftButton");return end end
 error("Missing preview activity "..key)
end
ChooseSearchActivity("seasonDungeon",20);snapshot("寻求组队")
U.pages.find:SelectCategory("seasonDungeon")
for _,button in ipairs(U.pages.find.difficultyButtons) do if button.value==8 then button:Fire("OnClick") end end
U.pages.find:SetMultiSelectMode(true);snapshot("活动多选返回");U.pages.find:ClosePicker()
U.Tooltip:ShowGroup(U.pages.find.results.rows[1],G.records[1]);snapshot("队伍悬停")
U.Tooltip:Hide()
local dungeonRecords=G.records;G.records={}
local raidTitles={"H 7 8 10","普通678","H10","H678 来的带小作文【一手团】","H3眼神速推","公会M固定团招人"}
local raidDescriptions={"熟练机制，语音听指挥。","来治疗和远程，稳定打完。","", "集合后开打，带合剂食物，能全程。", "单刷进度勿扰，打完就散。", "每周二四日，长期固定。"}
for id,source in pairs(dungeonRecords) do
 local record={};for key,value in pairs(source) do record[key]=value end
 record.activityID,record.activity,record.categoryID=1,G.Catalog:GetActivity(1),3
 record.name,record.comment,record.activityName=raidTitles[id],raidDescriptions[id],"尼鲁巴尔王宫（英雄）";record.maxNumPlayers=30
 G.records[id]=record
end
ChooseSearchActivity("seasonRaid",10);snapshot("团本搜索描述列")
G.records=dungeonRecords;ChooseSearchActivity("seasonDungeon",20)
A:Open("create");LFGListFrame.EntryCreation.Name:UserType("+12 稳定限时 来输出");LFGListFrame.EntryCreation.Description.EditBox:UserType("熟练机制，开打前确认路线。\n打断分配好，沟通友善，争取限时。")
U.pages.create.ilvl.box:SetText("640");U.pages.create.score.box:SetText("2800");snapshot("发布招募")
for i=1,6 do G.Presets:ToggleFavorite({activityID=2,requiredItemLevel=310+i*2,requiredDungeonScore=3000+i*100,isCrossFactionListing=true}) end
U.pages.create.favorite:Fire("OnClick")
U.pages.create.favoritesToggle:Fire("OnClick");U.pages.create.favoritesToggle:Fire("OnEnter");snapshot("收藏条件");U.pages.create.favoritesToggle:Fire("OnLeave")
local favorites=U.pages.create.favoritesList;favorites.clip.mouseOver=true
favorites.rows[1]:Fire("OnEnter");favorites.rows[1].remove:Fire("OnEnter");snapshot("收藏操作悬停")
favorites.rows[1].remove:Fire("OnLeave");favorites.rows[1]:Fire("OnLeave");favorites.clip.mouseOver=nil
U.pages.create.favoritesToggle:Fire("OnClick")
U.pages.create:TogglePicker();snapshot("活动分类留白");U.pages.create.pickerSearch.box:SetText("Dungeon");snapshot("活动搜索");U.pages.create:ClosePicker()
U.pages.create:Submit()
U.pages.create.favoritesToggle:Fire("OnClick");snapshot("招募中收藏不可用");U.pages.create.favoritesToggle:Fire("OnClick")
local function Applicant(id,people,comment,status)
 local app={id=id,status=status or "applied",displayOrderID=id-70,activityID=2,comment=comment,members={}}
 for index,source in ipairs(people) do
  local member={};for key,value in pairs(source) do member[key]=value end
  member.applicantID,member.applicantIndex=id,index;app.members[index]=member
 end
 G.applicants[id]=app;return app
end
local mainApplicant=Applicant(71,members,"五人一起，语音沟通，熟悉机制。")
Applicant(72,{members[2]},"单人治疗，随时可以出发。")
Applicant(73,{members[3]},"有合剂和食物。","invited")
U.pages.create:RefreshApplicants();U.pages.create.batchPool[1]:Fire("OnEnter");snapshot("管理申请");U.pages.create.batchPool[1]:Fire("OnLeave")
G.listing.activityID=1;for _,app in pairs(G.applicants) do app.activityID=1 end;G:Notify("listing");snapshot("团队申请无评分")
U.Tooltip:ShowPlayer(U.pages.create.batchPool[1].people[1],mainApplicant.members[1]);snapshot("团队申请者个人详情");U.Tooltip:Hide()
G.listing.activityID=2;for _,app in pairs(G.applicants) do app.activityID=2 end;G:Notify("listing")
mainApplicant.members[1].dungeonScores={current={name="红玉新生法池",level=18,timed=true},best={name="毒牙洞窟",level=19,timed=false}}
U.Tooltip:ShowPlayer(U.pages.create.batchPool[1].people[1],mainApplicant.members[1]);snapshot("申请者大秘境纪录");U.Tooltip:Hide()
A:Open("notes");U.pages.notes:OpenEdit("晚风听雨-晨风号角");snapshot("荔枝笔记")
local notes=U.pages.notes;notes.list.clip.mouseOver=true;notes.list.rows[3]:Fire("OnEnter");snapshot("笔记列表悬停");notes.list.rows[3]:Fire("OnLeave");notes.list.clip.mouseOver=nil
notes:SelectTab("history");notes.historyList.clip.mouseOver=true;notes.historyList.rows[1]:Fire("OnEnter");snapshot("历史记录悬停");notes.historyList.rows[1]:Fire("OnLeave");notes.historyList.clip.mouseOver=nil
A:Open("settings");snapshot("设置")
local raidMembers={}
for i=1,30 do local member={};for key,value in pairs(members[(i-1)%5+1]) do member[key]=value end;member.nameKey=member.nameKey..i;member.name=member.nameKey;member.isLeader=i==1;member.isSelf=i==1;member.subgroup=math.ceil(i/5);member.unit="raid"..i;member.guid="SampleRaid-"..i;raidMembers[i]=member end
A:Open("find");A.db.raidMembers="always"
U.Tooltip:ShowGroup(U.pages.find.results.rows[1],{name="英雄团本 熟练清场",leaderName=raidMembers[1].name,leaderKey=raidMembers[1].nameKey,categoryID=3,activityID=1,activity=G.Catalog:GetActivity(1),numMembers=30,maxNumPlayers=30,details={members=raidMembers,counts=U:MemberCounts(raidMembers),encounters={},relationships={bnet={"同路人"},character={"糖霜骑士-晨风号角"},guild={"暮色星河"}}}});snapshot("团本成员布局")
function G:GetRoster() return raidMembers end
G.listing=nil;A:Open("create");U.pages.create:UsePreset({activityID=1});snapshot("赛季团本增益")
U.pages.create.groupSummary:Fire("OnEnter");snapshot("当前队伍悬浮名单");U.Tooltip:Hide()
function G:GetRoster() return {members[1],members[2],members[3],members[4]} end
U.pages.create:RefreshRoster();U.pages.create.groupSummary:Fire("OnEnter");snapshot("四人团本名单");U.Tooltip:Hide()
U.pages.create.groupSummary:Fire("OnEnter");U.Tooltip.interactive.memberButtons[1]:Fire("OnEnter");snapshot("团队成员悬停");U.Tooltip.interactive.memberButtons[1]:Fire("OnLeave");U.Tooltip:Hide()
U.pages.create:UsePreset({activityID=2});snapshot("小队成员列表")
local inlineMember=U.pages.create.rosterList.rows[1];inlineMember:Fire("OnEnter");snapshot("小队成员悬停");inlineMember:Fire("OnLeave")
U.Tooltip:ShowRoster(U.pages.create.rosterList.rows[1],G:GetRoster(),nil,U.pages.create.rosterContext)
-- Native action availability is sample data here; no menu action is executed.
UnitIsHumanPlayer=function() return true end;UnitIsConnected=function() return true end
UnitCanCooperate=function() return true end;UnitCanAttack=function() return false end
UnitIsDeadOrGhost=function() return false end;CanInspect=function() return true end
UnitIsGroupLeader=function(unit) return unit=="player" end;UnitIsGroupAssistant=function() return false end
HasLFGRestrictions=function() return false end;GetInstanceInfo=function() return "","none" end
C_PartyInfo.ChallengeModeRestrictionsActive=function() return false end
U.Tooltip.interactive.memberButtons[2]:Fire("OnClick","RightButton");snapshot("队友右键菜单");U.Tooltip:Hide()
function G:GetRoster() return raidMembers end
U.pages.create:UsePreset({activityID=1});U.pages.create:RefreshRoster()
U.pages.create.favoritesToggle:Fire("OnClick");snapshot("收藏与增益");U.pages.create.favoritesToggle:Fire("OnClick")
local mage={name="约翰凯瑟琳-白银之手",nameKey="约翰凯瑟琳-白银之手",class="MAGE",localizedClass="法师",specName="奥术",assignedRole="DAMAGER",factionGroup=0,itemLevel=330,dungeonScore=3834,dungeonScores={current={name="夺目谷",level=19,timed=true},best={name="纳洛拉克的洞穴",level=20,timed=true}}}
U.Tooltip:ShowPlayer(U.pages.create.groupSummary,mage);snapshot("玩家详情优化");U.Tooltip:Hide()
A:Open("find");U.pages.find:SelectCategory("seasonDungeon");U.pages.find:SetFiltersOpen(true)
U.pages.find.rolePresenceChoices.TANK.buttons[1]:Fire("OnClick");U.pages.find.rolePresenceChoices.DAMAGER.buttons[1]:Fire("OnClick");snapshot("职责筛选")
A:Open("settings");A:SetSetting("uiScale",75);U.pages.settings:Sync();snapshot("主窗口75%")
A:SetSetting("uiScale",125);U.pages.settings:Sync();snapshot("主窗口125%")
A:SetSetting("uiScale",100);U.pages.settings:Sync()
SetBinding("M","TOGGLEWORLDMAP");U.pages.settings:BeginBindingCapture();snapshot("行内修改快捷键")
U.pages.settings.bindingCapture:Fire("OnKeyDown","M");snapshot("按键冲突")
U:Hide(true)
dofile("addon/LycheeGroup/Floating.lua")
dofile("addon/LycheeGroup/API.lua")
function G:ResolveMemberSpec(member) return member.specID,member.specName,nil,member.localizedClass end
G.listing={activityID=2};G.applicants={}
for i,member in ipairs(members) do G.applicants[i]={id=i,status="applied",activityID=2,comment=i==1 and "熟练机制，打断分配好。" or "",members={member}} end
A.Floating:Bind(G);A.Floating:UpdateSettings()
A.Floating.frame:ClearAllPoints();A.Floating.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",40,-24)
-- The basic frame substitute does not resolve anchored GetTop coordinates.
A.Floating.frame.GetTop=function(self) return UIParent:GetHeight()/self:GetScale()-24 end
A.Floating:ShowPanel();snapshot("浮窗阵营标",A.Floating.frame)
G.listing.activityID=1;G:Notify("listing");A.Floating:ShowPanel();snapshot("团队浮窗装等",A.Floating.frame)
G.listing=nil;G:Notify("listing");A.Floating:ShowPanel();snapshot("申请浮窗留白",A.Floating.frame)
local visiting={}
local function json(v,path)
 path=path or "$"
 assert(type(v)~="function","non-data preview value at "..path)
 if type(v)=="table" then assert(not visiting[v],"cyclic preview value at "..path);visiting[v]=true end
 if v==nil then return "null" elseif type(v)=="boolean" or type(v)=="number" then return tostring(v)
 elseif type(v)=="string" then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t'):gsub('[%z\1-\31]',function(c)return ('\\u%04x'):format(c:byte()) end)..'"'
 else local parts={};if #v>0 then for i,x in ipairs(v) do parts[#parts+1]=json(x,path..'['..i..']') end;visiting[v]=nil;return '['..table.concat(parts,',')..']' end
  for k,x in pairs(v) do parts[#parts+1]=json(tostring(k))..':'..json(x,path..'.'..tostring(k)) end;visiting[v]=nil;return '{'..table.concat(parts,',')..'}' end
end
local out=assert(io.open("tests/preview-data.js","wb"));out:write("const SHOTS=[")
for i,shot in ipairs(shots) do
 if i>1 then out:write(",") end
 out:write(json(shot))
end
out:write("];");out:close()
print("Saved "..#shots.." local sample layouts from the addon widget tree.")
