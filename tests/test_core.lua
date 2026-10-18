-- Core 微核心行为:身份键、默认设置、链接格式。
local Stubs = TestStubs
Stubs.Install({ locale = "zhCN", realm = "晨风号角" })

Load.addon("LycheeGroup", "Locale.lua")
Load.addon("LycheeGroup", "Core.lua")

local A = _G.LycheeGroup

-- ---------------------------------------------------------------- PlayerKey

do
	local key, name, realm = A:PlayerKey("艾莉安娜-晨风号角")
	T.eq(key, "艾莉安娜-晨风号角", "内嵌服务器保持原文")
	T.eq(name, "艾莉安娜")
	T.eq(realm, "晨风号角")
end

do
	local key, name, realm = A:PlayerKey("Alice", "Silver Hand")
	T.eq(key, "Alice-SilverHand", "显式服务器去空格")
	T.eq(name, "Alice")
	T.eq(realm, "SilverHand")
end

do
	local key, name, realm = A:PlayerKey("  Bob  ")
	T.ok(key, "无服务器时回落本服")
	T.eq(name, "Bob")
	T.eq(realm, "晨风号角", "本服取 GetRealmName 去空格")
	T.eq(A:PlayerKey("Bob", ""), "Bob-晨风号角", "原生空服务器同样解析为本服")
end

do
	T.eq(A:PlayerKey(""), nil, "空名返回 nil")
	T.eq(A:PlayerKey(nil), nil, "非字符串返回 nil")
	T.eq(A:PlayerKey("   "), nil, "纯空白返回 nil")
end

do
	-- 显式 realm 优先于内嵌。
	local key = A:PlayerKey("Name-Other", "Home")
	T.eq(key, "Name-Home", "显式 realm 覆盖内嵌")
end

-- ---------------------------------------------------------------- 默认设置

do
 _G.LycheeGroupDB={applicantSound=false,applicantTone="wood",soundVolume=25,keywordFilters={global={"carry"},dungeon={"spam"},raid={}}}
	A:LoadDB()
 T.eq(A.db.applicantSound,nil,"retired sound toggle is removed from saved settings")
 T.eq(A.db.applicantTone,nil);T.eq(A.db.soundVolume,nil)
 T.eq(A.db.keywordFilters,nil,"removed keyword settings are discarded from existing saved data")
	T.eq(A.db.notesEnabled, true, "笔记默认启用")
	T.eq(A.db.notesHasRecords, false, "默认无记录摘要")
	T.eq(A.db.askReason, true, "默认询问理由")
	T.eq(A.db.reduceMotion, false, "默认完整动效")
	T.eq(A.db.nativeLFGEntry, true, "默认从原生眼睛进入荔枝组队")
	T.eq(A.db.uiScale, 100, "主窗口缩放以当前尺寸 100% 为默认值")
	T.eq(A.db.schema, 1)
end

do
	-- 已存在的存档值不被默认值覆盖。
	_G.LycheeGroupDB = nil
	A.db = nil
	_G.LycheeGroupDB = { notesEnabled = false, uiScale = 115 }
	A:LoadDB()
	T.eq(A.db.notesEnabled, false, "保留已有值")
	T.eq(A.db.askReason, true, "缺失项补默认")
	T.eq(A.db.uiScale, 115, "保存的主窗口比例不被默认值覆盖")
	T.eq(A.db.keywordFilters,nil,"fresh settings do not recreate keyword filters")
end

-- ---------------------------------------------------------------- 链接格式

do
	local link = A:RecordLink("Alice-SilverHand")
	T.ok(link:find("|Hlycheegroup:note:Alice%-SilverHand|h", 1, false), "链接携带完整身份")
	T.ok(link:find("%[查看记录%]"), "默认链接文字为查看记录")
end

-- ---------------------------------------------------------------- Ensure 失败路径

do
	local module, err = A:Ensure("Group")
	T.eq(module, nil, "LoadAddOn 失败时返回 nil")
	T.eq(err, "LycheeGroup_Group", "错误说明模块名")
end

do
	local module, err = A:Ensure("Nope")
	T.eq(module, nil)
	T.ok(err, "未知模块返回错误")
end

-- 原生身份边界：不把非玩家/受限身份当成可记录玩家。
do
	Stubs.SetUnit("target", {name="Alice",realm="Silver Hand",isPlayer=true,guid="Other"})
	local key, name, realm = A:UnitIdentity("target")
	T.eq(key, "Alice-SilverHand")
	T.eq(name, "Alice")
	T.eq(realm, "SilverHand")
	Stubs.SetUnit("target", {name="Creature",isPlayer=false})
	T.eq(A:UnitIdentity("target"), nil)
	local secret = setmetatable({}, {__tostring=function() error("secret read") end})
	_G.issecretvalue = function(value) return value == secret end
	T.eq(A:PlayerKey(secret), nil)
	T.eq(A:PlayerKey("Alice", secret), nil)
	_G.issecretvalue = nil
end

-- 实际入口文件必须过滤其他插件的加载，且启动监听只执行一次。
do
	local loads, inits, forwarded = {}, 0, 0
	local nativeHandlers = {}
	local nativeMenu
	_G.Menu = {ModifyMenu=function(tag, callback) nativeMenu=callback end}
	_G.LinkUtil = {RegisterLinkHandler=function(kind, callback) nativeHandlers[kind]=callback end}
	_G.IsAddOnLoaded, _G.LoadAddOn = nil, nil -- 正式服入口使用 C_AddOns。
	C_AddOns.IsAddOnLoaded = function() return false, false end
	C_AddOns.LoadAddOn = function(name)
		loads[#loads + 1] = name
		A.Group = {
			Initialize=function() inits=inits+1 end,
			OnEvent=function(_, event) forwarded=forwarded+1; T.eq(event,"CHALLENGE_MODE_START") end,
		}
		return true
	end
	local minimapInits=0
	A.Minimap={Initialize=function() minimapInits=minimapInits+1 end}
	Load.addon("LycheeGroup", "Entrypoints.lua")
	Stubs.FireEvent("ADDON_LOADED", "UnrelatedBefore")
	T.eq(#loads, 0, "其他插件不唤醒业务")
	Stubs.FireEvent("ADDON_LOADED", "LycheeGroup")
	T.eq(#Stubs.FramesWithEvent("ADDON_LOADED"), 0, "自己的存档就绪后退订")
	C_LFGList.GetApplications = function() return {1, 2, 3} end
	C_LFGList.GetApplicationInfo = function(id)
		return id, ({"declined_full", "inviteaccepted", "cancelled"})[id], nil
	end
	Stubs.FireEvent("PLAYER_LOGIN")
	T.eq(minimapInits,1,"登录创建独立小地图入口")
	T.eq(#Stubs.FramesWithEvent("PLAYER_LOGIN"), 0, "登录初始化只运行一次")
	T.eq(#loads, 0, "只有已结束的申请时不加载业务包")
	Stubs.FireEvent("ADDON_LOADED", "UnrelatedAfter")
	T.eq(#loads, 0)
	T.ok(nativeMenu, "原生头像菜单入口已注册")
	Stubs.FireEvent("CHALLENGE_MODE_START", 123)
	T.eq(#loads, 1, "真实业务唤醒才加载")
	T.eq(inits, 1)
	T.eq(forwarded, 1, "首次事件交接一次")
	T.eq(#Stubs.FramesWithEvent("CHALLENGE_MODE_START"), 0, "领域接管后退订核心唤醒")
	A:Ensure("Group")
	T.eq(inits, 1, "重复使用不重复初始化")

	-- 命令处理使用姓名/服务器各自字段，未填写理由不保存本地化占位文本。
	local captured
	local oldOpen = A.Open
	A.Open = function(_, page, context) captured={page=page,context=context}; return true end
	SlashCmdList.LYCHEEGROUP("note Cross-Foreign")
	T.eq(captured.page,"notes")
	T.eq(captured.context.add.name,"Cross")
	T.eq(captured.context.add.realm,"Foreign")
	local call, printed
	A.Notes = {Add=function(_,name,realm,reason,unit,classSpec,details) call={name,realm,reason,unit,classSpec,details}; return true,{} end}
	A.NoteMessage = function(_,text) printed=text end
	C_AddOns.LoadAddOn = function(name) loads[#loads+1]=name; return true end
	A:RecordPlayer("Cross", "Foreign", nil, "explicit reason")
	T.eq(call[1],"Cross")
	T.eq(call[2],"Foreign")
	T.eq(call[3],"explicit reason")
	T.ok(printed:find("Cross%-Foreign"), "笔记命令经统一提醒入口输出")
	A.db.askReason=false
	A:RecordPlayer("Cross", "Foreign")
	T.eq(call[3],"", "空理由保留语言无关语义")
	A.Notes.Find=function() return nil end
	A.Notes.PlayerInfo={Request=function(unit,callback)
		T.eq(unit,"raid2")
		callback("圣骑士-神圣",{class="PALADIN",specID=66,classSpec="圣骑士-神圣"})
	end}
	local notesEnabled=A.db.notesEnabled;A.db.notesEnabled=true
	Stubs.SetUnit("raid2",{name="右键目标",realm="Foreign",class="PALADIN",classID=2,guid="P-menu"})
	local click
	local menu={CreateDivider=function() end,CreateTitle=function() end,CreateButton=function(_,_,callback) click=callback end}
	nativeMenu(nil,menu,{unit="raid2"});T.eq(type(click),"function")
	click()
	T.eq(call[1],"右键目标");T.eq(call[5],"圣骑士-神圣")
	T.ok(call[6],"原生团队右键路径保留结构化查询结果")
	T.eq(call[6].class,"PALADIN");T.eq(call[6].specID,66,"原生团队右键路径将结构化查询结果交给记录服务")
	Stubs.SetUnit("raid2",nil)
	A.db.notesEnabled=notesEnabled

	-- 聊天定位解析真实LinkUtil的options参数，不建立聊天历史索引。
	nativeHandlers.lycheegroup("lycheegroup:note:Cross-Foreign",nil,{options="note:Cross-Foreign"},{button="LeftButton"})
	T.eq(captured.context.playerKey,"Cross-Foreign")
	A.Open=oldOpen
	_G.Menu=nil
end

-- The minimap eye keeps the native menu and battlefield priority. Its addon
-- can arrive after login without loading the product's UI ahead of a click.
do
 local oldOpen,oldActive,oldApplications,oldInfo=A.Open,C_LFGList.HasActiveEntryInfo,C_LFGList.GetApplications,C_LFGList.GetApplicationInfo
 local nativeCalls,opened,listing,status,battlefield,openOK=0,nil,false,"applied",false,true
 _G.QueueStatusButton=CreateFrame("Button")
 QueueStatusButton.angerVal=0
 _G.LFG_ANGER_INC_VAL=nil -- Stock QueueStatus constants are file-local.
 _G.QueueStatus_InActiveBattlefield=function() return battlefield,false end
 _G.IsInLFDBattlefield=function() return false end
 local original=function(_,button) nativeCalls=nativeCalls+1;return button end
 QueueStatusButton:SetScript("OnClick",original)
 C_LFGList.HasActiveEntryInfo=function() return listing end
 C_LFGList.GetApplications=function() return {42} end
 C_LFGList.GetApplicationInfo=function() return 42,status end
 A.Open=function(_,page) opened=page;return openOK end
 Stubs.FireEvent("ADDON_LOADED","Blizzard_QueueStatusFrame")
 local click=QueueStatusButton:GetScript("OnClick")
 T.ok(click~=original,"late native eye installs the click handoff")
 T.eq(#Stubs.FramesWithEvent("ADDON_LOADED"),0,"native addon listener ends after binding")
 T.eq(opened,nil,"binding does not open or load a page")
 click(QueueStatusButton,"LeftButton")
 T.eq(opened,"find");T.eq(nativeCalls,0)
 listing=true;for _=1,4 do click(QueueStatusButton,"LeftButton") end
 T.eq(opened,"create");T.eq(nativeCalls,0)
 T.eq(QueueStatusButton.angerVal,0,"redirected clicks do not duplicate private native eye animation state")
 T.eq(_G.LFG_ANGER_INC_VAL,nil,"native entry routing requires no global copy of a stock local constant")
 T.eq(click(QueueStatusButton,"RightButton"),"RightButton");T.eq(nativeCalls,1)
 battlefield=true;opened=nil;click(QueueStatusButton,"LeftButton")
 T.eq(opened,nil);T.eq(nativeCalls,2,"battlefield retains native priority")
 battlefield=false;listing=false;status="cancelled";click(QueueStatusButton,"LeftButton")
 T.eq(opened,nil);T.eq(nativeCalls,3,"no active premade group keeps native queue action")
 status="applied";A:SetSetting("nativeLFGEntry",false);click(QueueStatusButton,"LeftButton")
 T.eq(opened,nil);T.eq(nativeCalls,4,"disabled preference immediately restores native behavior")
 A:SetSetting("nativeLFGEntry",true);status="invited";click(QueueStatusButton,"LeftButton")
 T.eq(opened,"find");T.eq(nativeCalls,4)
 openOK=false;click(QueueStatusButton,"LeftButton")
 T.eq(nativeCalls,5,"failed product opening leaves the native entry available")
 A.Open,C_LFGList.HasActiveEntryInfo,C_LFGList.GetApplications,C_LFGList.GetApplicationInfo=oldOpen,oldActive,oldApplications,oldInfo
 _G.QueueStatusButton,_G.QueueStatus_InActiveBattlefield,_G.IsInLFDBattlefield,_G.LFG_ANGER_INC_VAL=nil,nil,nil,nil
end

-- Native binding writes keep scope and require explicit conflict replacement.
do
 local savedGlobals={}
 local names={"C_KeyBindings","GetBindingKey","GetBindingAction","GetBindingText","GetCurrentBindingSet","SetBinding","SaveBindings","InCombatLockdown","UnitGUID"}
 for _,name in ipairs(names) do savedGlobals[name]=_G[name] end
 local oldDB=A.db;A.db={}
 local assigned,order,writes,saves={}, {},0,{}
 local scope,combat,reject=1,false,false
 C_KeyBindings={GetBindingContextForAction=function(action) T.eq(action,"LYCHEEGROUP_TOGGLE");return 7 end}
 GetBindingAction=function(key,_,context) T.eq(context,7);return assigned[key] or "" end
 GetBindingKey=function(action,_,context)
  T.eq(context,7)
  local keys={};for _,key in ipairs(order) do if assigned[key]==action then keys[#keys+1]=key end end
  return unpack(keys)
 end
 GetBindingText=function(key) return key end
 GetCurrentBindingSet=function() return scope end
 SetBinding=function(key,action,context)
  T.eq(context,7);writes=writes+1
  if reject then return false end
  for i=#order,1,-1 do if order[i]==key then table.remove(order,i) end end
  assigned[key]=action;if action then order[#order+1]=key end
  return true
 end
 SaveBindings=function(value) saves[#saves+1]=value end
 InCombatLockdown=function() return combat end
 UnitGUID=function() return "Player-binding-test" end
 Load.addon("LycheeGroup","Bindings.lua")
 local B=A.Bindings
 local function Reset(bindings)
  assigned,order,writes,saves={}, {},0,{}
  A.db.bindingDefaultScopes=nil
  for _,entry in ipairs(bindings or {}) do assigned[entry[1]]=entry[2];order[#order+1]=entry[1] end
 end
 B:InitializeDefault()
 T.eq(assigned[";"],B.action,"free half-width semicolon becomes the default")
 T.eq(saves[1],1,"default saves the active account scope")
 assigned[";"]=nil;B:InitializeDefault()
 T.eq(assigned[";"],nil,"an intentionally removed default is not recreated")
 Reset({{";","OPENALLBAGS"}});B:InitializeDefault()
 T.eq(assigned[";"],"OPENALLBAGS","occupied semicolon keeps its original action")
 T.eq(writes,0);T.eq(B:Conflict(";"),"OPENALLBAGS")
 Reset({{"ALT-G",B.action}});B:InitializeDefault()
 T.eq(assigned[";"],nil,"existing addon binding prevents default initialization")
 T.eq(B:Text(),"ALT-G")
 scope=2;Reset();B:InitializeDefault()
 T.eq(saves[1],2,"character binding scope is not switched to account")
 T.ok(A.db.bindingDefaultScopes["character:Player-binding-test"])
 Reset();combat=true;B:InitializeDefault()
 T.eq(writes,0,"default initialization does not write during combat")
 combat=false;Stubs.FireEvent("PLAYER_REGEN_ENABLED")
 T.eq(assigned[";"],B.action,"default initialization resumes once after combat")
 T.eq(#Stubs.FramesWithEvent("PLAYER_REGEN_ENABLED"),0)
 Reset({{"ALT-G",B.action},{"CTRL-G",B.action},{"M","TOGGLEWORLDMAP"}})
 local ok,reason,conflict=B:SetKey("M")
 T.eq(ok,false);T.eq(reason,"conflict");T.eq(conflict,"TOGGLEWORLDMAP")
 T.eq(writes,0,"conflict detection leaves both actions unchanged")
 ok,reason=B:SetKey("M","OPENALLBAGS")
 T.eq(ok,false);T.eq(reason,"conflict","changed conflict must be confirmed again")
 ok=B:SetKey("M","TOGGLEWORLDMAP")
 T.eq(ok,true);T.eq(assigned.M,B.action);T.eq(assigned["ALT-G"],nil)
 T.eq(assigned["CTRL-G"],B.action,"secondary Blizzard binding is preserved")
 local first,second=B:Keys();T.eq(first,"M");T.eq(second,"CTRL-G")
 T.eq(saves[1],2)
 local before=writes;combat=true;ok,reason=B:SetKey("F")
 T.eq(ok,false);T.eq(reason,"combat");T.eq(writes,before)
 combat=false;reject=true;ok,reason=B:SetKey("F")
 T.eq(ok,false);T.eq(reason,"failed");T.eq(assigned.M,B.action,"failed write keeps prior binding")
 for _,name in ipairs(names) do _G[name]=savedGlobals[name] end
 A.db=oldDB
end

do
 local oldUI,oldOpen=A.UI,A.Open
 local shown,hidden,opened=false,0,0
 A.UI={IsShown=function() return shown end,Hide=function() hidden=hidden+1;shown=false end}
 A.Open=function(_,page) T.eq(page,"find");opened=opened+1;shown=true;return true end
 A:ToggleWindow();T.eq(opened,1)
 A:ToggleWindow();T.eq(hidden,1,"binding closes the current main window")
 A.UI,A.Open=oldUI,oldOpen
end

_G.LycheeGroupDB = nil
