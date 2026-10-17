-- Local layout review from the real Lua widget tree. Sample data; no game calls.
-- lua tests/ui_preview.lua -> tests/preview-data.js
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G,S=f.A,f.U,f.G,f.S
UIParent:SetSize(1280,860);A.db.reduceMotion=true
RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43},PALADIN={r=.96,g=.55,b=.73},MAGE={r=.25,g=.78,b=.92},PRIEST={r=1,g=1,b=1},DRUID={r=1,g=.49,b=.04},SHAMAN={r=0,g=.44,b=.87}}
local names={"晚风听雨","糖霜骑士","暮色星河","云上青鸟","柚子茶"}
local classes={"WARRIOR","PALADIN","MAGE","PRIEST","DRUID"}
local members={}
for i=1,5 do members[i]={name=names[i].."-晨风号角",nameKey=names[i].."-晨风号角",realm="晨风号角",class=classes[i],assignedRole=i==1 and "TANK" or i==2 and "HEALER" or "DAMAGER",specName=({"防护","神圣","冰霜","暗影","平衡"})[i],itemLevel=642+i,dungeonScore=2800+i*70,isLeader=i==1} end
function G:GetRoster() return {members[1],members[2],members[3]} end
function G.Results:GetDetails(record) local m={};for i=1,record.numMembers or 0 do m[i]=members[i] end;return {members=m,counts=U:MemberCounts(m),encounters={}} end
function G:GetHistory() return {{id=1,mapName="艾杰斯亚学院",level=12,completedAt=1792051200,members=members},{id=2,mapName="蕨皮山谷",level=11,completedAt=1791964800,members=members}} end
local titles={"+12 稳定限时 来输出","+10 打完就走 来治疗","+13 冲分 熟练队","+11 周常 友好交流","+12 补一输出","+9 新人练习 一起打"}
for i,title in ipairs(titles) do G.records[i]={id=i,activityID=2,activity=A.Group.Catalog:GetActivity(2),categoryID=2,activityName="Dungeon activity",name=title,leaderName=members[(i-1)%5+1].name,leaderKey=members[(i-1)%5+1].nameKey,numMembers=i%3+2,maxNumPlayers=5,age=i*36,requiredItemLevel=635+i,requiredDungeonScore=2600,leaderOverallDungeonScore=2800+i*83,leaderRating=2800+i*83,requiredRating=2600,level=12,comment="熟练机制，开打前确认路线。打断分配好，沟通友善，争取限时。"} end
G.apps={{id=2,name=titles[2],status="applied",categoryID=2,result=G.records[2],activityID=2,expiresAt=GetTime()+250},{id=4,name=titles[4],status="invited",categoryID=2,result=G.records[4],activityID=2}};G.state="done"
A.Notes:Add("晚风听雨","晨风号角","路线清楚，会提醒打断；上次学院配合很好。",nil,"战士 · 防护",{type="positive",class="WARRIOR",specID=73})
A.Notes:Add("柚子茶","晨风号角","耐心，愿意带新手熟悉机制。",nil,"德鲁伊 · 平衡",{type="neutral",class="DRUID",specID=102})
A.Notes:Add("云上青鸟","白银之手","团队沟通顺畅，保留记录便于下次组队。",nil,"牧师 · 暗影",{type="caution",class="PRIEST",specID=258})
local shots={}
local function snapshot(name)
 U.Motion:Tick(2)
 local ids={};for i,n in ipairs(S.nodes) do ids[n]=i end
 local nodes={}
 for i,n in ipairs(S.nodes) do
  local points={};for _,p in ipairs(n.points) do local point={};for j,v in ipairs(p) do point[j]=type(v)=="table" and {ref=ids[v]} or v end;points[#points+1]=point end
  nodes[i]={id=i,parent=ids[n.parent],kind=n:GetObjectType(),shown=n.shown,alpha=n.alpha,w=n.w,h=n.h,points=points,all=ids[n.allPoints],text=n.text,color=n.color,font=n.font,fill=n:GetObjectType()=="Texture" and n.fill or nil,vertex=n.vertex,texture=type(n.texture)~="table" and n.texture or nil,atlas=n.atlas,coords=n.texCoords,justify=n.justify,wrap=n.wrap,maxLines=n.maxLines,spacing=n.spacing,layer=n.layer,backdrop=n.backdropColor,rotation=n.rotation,level=n.level,scale=n.scale,thumb=ids[n.thumb]}
 end
 shots[#shots+1]={name=name,nodes=nodes,root=ids[U.frame],tooltip=U.Tooltip.interactive and U.Tooltip.interactive:IsShown() and ids[U.Tooltip.interactive] or U.Tooltip.frame and U.Tooltip.frame:IsShown() and ids[U.Tooltip.frame] or nil}
end
A:Open("find");snapshot("寻求组队")
U.Tooltip:ShowGroup(U.pages.find.results.rows[1],G.records[1]);snapshot("队伍悬停")
A:Open("create");LFGListFrame.EntryCreation.Name:UserType("+12 稳定限时 来输出");LFGListFrame.EntryCreation.Description.EditBox:UserType("熟练机制，开打前确认路线。\n打断分配好，沟通友善，争取限时。")
U.pages.create.ilvl.box:SetText("640");U.pages.create.score.box:SetText("2800");snapshot("发布招募")
U.pages.create:TogglePicker();U.pages.create.pickerSearch.box:SetText("Dungeon");snapshot("活动搜索");U.pages.create:ClosePicker()
U.pages.create:Submit()
G.applicants[71]={id=71,status="applied",displayOrderID=1,comment="五人一起，语音沟通，熟悉机制。",members=members}
G.applicants[72]={id=72,status="applied",displayOrderID=2,comment="单人治疗，随时可以出发。",members={members[2]}}
G.applicants[73]={id=73,status="invited",displayOrderID=3,comment="有合剂和食物。",members={members[3]}}
U.pages.create:RefreshApplicants();snapshot("管理申请")
A:Open("notes");U.pages.notes:OpenEdit("晚风听雨-晨风号角");snapshot("荔枝笔记")
A:Open("settings");snapshot("设置")
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
local encoded=json(shots)
local out=assert(io.open("tests/preview-data.js","wb"));out:write("const SHOTS=",encoded,";");out:close()
print("Saved 7 local sample layouts from the addon widget tree.")
