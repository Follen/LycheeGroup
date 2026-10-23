-- Core 微核心行为:身份键、默认设置、链接格式。
local Stubs = TestStubs
Stubs.Install({ locale = "zhCN", realm = "晨风号角" })

Load.addon("LycheeGroup", "Locale.lua")
Load.addon("LycheeGroup", "Theme/Defaults.lua")
Load.addon("LycheeGroup", "Core.lua")
Load.addon("LycheeGroup", "Configuration.lua")

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
	T.eq(A.db.nativeLFGEntry, false, "默认保留原生组队眼睛")
	T.eq(A.db.uiScale, 100, "主窗口缩放以当前尺寸 100% 为默认值")
	T.eq(A.db.schema, 1)
end

do
	-- 已存在的存档值不被默认值覆盖。
	_G.LycheeGroupDB = nil
	A.db = nil
	_G.LycheeGroupDB = { notesEnabled = false, uiScale = 115, nativeLFGEntry = true }
	A:LoadDB()
	T.eq(A.db.notesEnabled, false, "保留已有值")
	T.eq(A.db.askReason, true, "缺失项补默认")
	T.eq(A.db.uiScale, 115, "保存的主窗口比例不被默认值覆盖")
	T.eq(A.db.nativeLFGEntry, true, "保留已保存的原生眼睛隐藏设置")
	T.eq(A.db.keywordFilters,nil,"fresh settings do not recreate keyword filters")
end

-- Character settings survive reloads without changing another character or notes.
do
 local account,character=A.db,A.charPrefs
 local notes=_G.LycheeGroupNotesDB
 local legacy={defaultSort="rating",rememberFilters=false,notesEnabled=true}
 local first,second={},{}
 local sharedNotes={records={['Shared-Realm']={reason="Keep across characters"}}}
 _G.LycheeGroupNotesDB=sharedNotes
 local function Login(prefs)
  _G.LycheeGroupDB=legacy;_G.LycheeGroupPrefsDB=prefs;A.db=nil;A.charPrefs=nil;A:LoadDB()
 end
 Login(first)
 T.eq(A:GetSetting("defaultSort"),"rating","the first character inherits the old account default")
 T.eq(A:GetSetting("rememberFilters"),false,"false is a saved preference, not a missing value")
 A:SetSetting("defaultSort","members");A:SetSetting("rememberFilters",true)
 T.eq(first.defaultSort,"members");T.eq(first.rememberFilters,true)
 T.eq(legacy.defaultSort,"rating","character changes leave the migration seed unchanged")
 Login(second)
 T.eq(A:GetSetting("defaultSort"),"rating");T.eq(A:GetSetting("rememberFilters"),false)
 A:SetSetting("defaultSort","itemLevel")
 Login(first)
 T.eq(A:GetSetting("defaultSort"),"members","returning to the first character restores its own sort")
 T.eq(A:GetSetting("rememberFilters"),true)
 T.eq(second.defaultSort,"itemLevel")
 T.eq(_G.LycheeGroupNotesDB,sharedNotes,"character preference loading preserves shared player notes")
 T.eq(sharedNotes.records['Shared-Realm'].reason,"Keep across characters")
 _G.LycheeGroupDB=account;_G.LycheeGroupPrefsDB=character;_G.LycheeGroupNotesDB=notes
 A.db=nil;A.charPrefs=nil;A:LoadDB()
end

-- Settings update their stored value before notifying the already-loaded owner.
do
 local oldGroup,oldEnsure,oldHistoryWake=A.Group,A.Ensure,A.SyncHistoryWake
 local history,autoJoin=A.db.history,A.db.autoJoin
 local loads,changes=0,{}
 A.Ensure=function() loads=loads+1 end
 A.SyncHistoryWake=function() end
 A.Group=nil
 A:SetSetting("history",not history)
 A:SetSetting("autoJoin",not autoJoin)
 T.eq(loads,0,"group preferences do not load the business package")
 A.Group={OnSettingChanged=function(_,key,value)
  T.eq(A.db[key],value,"the owner sees the updated setting")
  changes[#changes+1]={key,value}
 end}
 A:SetSetting("history",history)
 A:SetSetting("autoJoin",autoJoin)
 A:SetSetting("autoJoin",autoJoin)
 T.same(changes,{{"history",history},{"autoJoin",autoJoin}},"loaded owner gets each actual setting change once")
 T.eq(loads,0)
 A.Group,A.Ensure,A.SyncHistoryWake=oldGroup,oldEnsure,oldHistoryWake
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
			History={Discard=function() end},
		}
		return true
	end
	local minimapInits=0
	A.Minimap={Initialize=function() minimapInits=minimapInits+1 end}
	local oldChallengeActive=C_ChallengeMode.IsChallengeModeActive
	local challengeActive=true
	C_ChallengeMode.IsChallengeModeActive=function() return challengeActive end
	A:SetSetting("history",false)
	local notesEnabled,notesHasRecords,reminders=A.db.notesEnabled,A.db.notesHasRecords,A.db.reminders
	A:SetSetting("notesEnabled",true);A.db.notesHasRecords=true;A:SetSetting("reminders","off")
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
	T.eq(A.Notes,nil,"登录时关闭记录提醒不提前加载完整笔记存档")
	A.db.notesHasRecords=notesHasRecords;A:SetSetting("notesEnabled",notesEnabled);A:SetSetting("reminders",reminders)
	T.eq(#Stubs.FramesWithEvent("CHALLENGE_MODE_START"),0,"关闭历史的秘境内登录不加载 Group 或监听开始事件")
	Stubs.FireEvent("CHALLENGE_MODE_START")
	T.eq(#loads,0,"关闭历史后秘境事件不唤醒 Group")
	local ensure=A.Ensure
	local historyRestores=0
	A.Ensure=function(_,module) T.eq(module,"Group");historyRestores=historyRestores+1;return {History={Discard=function() end,Restore=function() end}} end
	A:SetSetting("history",true)
	T.eq(historyRestores,1,"在进行中的秘境启用历史立即请求加载和恢复")
	A:SetSetting("history",false)
	T.eq(#Stubs.FramesWithEvent("CHALLENGE_MODE_START"),0,"加载前停用历史即撤销开始监听")
	A.Ensure=ensure;challengeActive=false
	A:SetSetting("history",true)
	T.eq(#loads,0,"启用历史但秘境未开始不提前加载")
	T.eq(#Stubs.FramesWithEvent("CHALLENGE_MODE_START"),1,"启用历史保留下一次开始唤醒")
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
	C_ChallengeMode.IsChallengeModeActive=oldChallengeActive

	-- 命令处理使用姓名/服务器各自字段，未填写理由不保存本地化占位文本。
	local captured
	local toggle, toggles = A.ToggleWindow, 0
	A.ToggleWindow = function() toggles = toggles + 1 end
	SlashCmdList.LYCHEEGROUP(""); SlashCmdList.LYCHEEGROUP("find")
	T.eq(toggles,2,"slash toggles use the common transition decision")
	A.ToggleWindow = toggle
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
	A:SetSetting("askReason",false)
	A:RecordPlayer("Cross", "Foreign")
	T.eq(call[3],"", "空理由保留语言无关语义")
	A.Notes.Find=function() return nil end
	A.Notes.PlayerInfo={Request=function(unit,callback)
		T.eq(unit,"raid2")
		callback("圣骑士-神圣",{class="PALADIN",specID=66,classSpec="圣骑士-神圣"})
	end}
	local notesEnabled=A:GetSetting("notesEnabled");A:SetSetting("notesEnabled",true)
	Stubs.SetUnit("raid2",{name="右键目标",realm="Foreign",class="PALADIN",classID=2,guid="P-menu"})
	local click,label
	local menu={CreateDivider=function() end,CreateTitle=function() end,CreateButton=function(_,text,callback) label=text;click=callback end}
	local notes,ensure,hasRecords=A.Notes,A.Ensure,A.db.notesHasRecords
	local menuLoads,removed=0,nil
	A.Notes=nil;A.db.notesHasRecords=true
	notes.Find=function() return {} end
	notes.Remove=function(_,key) removed=key;return true end
	A.Ensure=function(_,module) T.eq(module,"Notes");menuLoads=menuLoads+1;A.Notes=notes;return notes end
	nativeMenu(nil,menu,{unit="raid2"})
	T.eq(menuLoads,1,"原生玩家菜单按需读取关闭提醒后的已有记录")
	T.eq(label,A.L.removeRecord,"延迟加载后仍显示取消记录")
	click();T.eq(removed,"右键目标-Foreign")
	A.Ensure=ensure;A.db.notesHasRecords=hasRecords;notes.Find=function() return nil end
	nativeMenu(nil,menu,{unit="raid2"});T.eq(type(click),"function")
	T.eq(label,A.L.recordPlayer)
	click()
	T.eq(call[1],"右键目标");T.eq(call[5],"圣骑士-神圣")
	T.ok(call[6],"原生团队右键路径保留结构化查询结果")
	T.eq(call[6].class,"PALADIN");T.eq(call[6].specID,66,"原生团队右键路径将结构化查询结果交给记录服务")
	Stubs.SetUnit("raid2",nil)
	A:SetSetting("notesEnabled",notesEnabled)

	-- 聊天定位解析真实LinkUtil的options参数，不建立聊天历史索引。
	nativeHandlers.lycheegroup("lycheegroup:note:Cross-Foreign",nil,{options="note:Cross-Foreign"},{button="LeftButton"})
	T.eq(captured.context.playerKey,"Cross-Foreign")
	A.Open=oldOpen
	_G.Menu=nil
end

-- Concealing the eye leaves its native animation and callbacks alive. A late
-- native addon and settings changes use the same one-time hooks.
do
 A:SetSetting("nativeLFGEntry",true)
 local oldOpen=A.Open
 local oldGetLFGMode,oldCategoryCount=GetLFGMode,NUM_LE_LFG_CATEGORYS
 local modes={}
 NUM_LE_LFG_CATEGORYS=8
 GetLFGMode=function(category) local state=modes[category];if state then return unpack(state) end end
 local nativeCalls,opened,hooks=0,nil,0
 local eye=CreateFrame("Button");_G.QueueStatusButton=eye
 _G.QueueStatusFrame=CreateFrame("Frame");QueueStatusFrame:Show()
 function QueueStatusFrame:Update() return "native update" end
 eye.alpha=.8;eye.mouse=true;eye.EyeHighlightAnim={playing=true}
 function eye:GetAlpha() return self.alpha end
 function eye:SetAlpha(alpha) self.alpha=alpha end
 function eye:IsMouseEnabled() return self.mouse end
 function eye:EnableMouse(enabled) self.mouse=enabled end
 function eye:HookScript(name,hook)
  hooks=hooks+1;local original=self:GetScript(name)
  self:SetScript(name,function(...) if original then original(...) end;hook(...) end)
 end
 function eye:Show() self.shown=true;local onShow=self:GetScript("OnShow");if onShow then onShow(self) end end
 function eye:Hide() self.shown=false;self.EyeHighlightAnim.playing=false end
 eye:Show()
 local original=function(_,button) nativeCalls=nativeCalls+1;return button end
 eye:SetScript("OnClick",original)
 A.Open=function(_,page) opened=page;return true end
 Stubs.FireEvent("ADDON_LOADED","Blizzard_QueueStatusFrame")
 T.eq(eye:GetAlpha(),0);T.eq(eye:IsMouseEnabled(),false,"hidden eye cannot intercept clicks or hover")
 T.eq(eye:IsShown(),true);T.eq(eye.EyeHighlightAnim.playing,true,"the stock sound animation remains alive")
 T.eq(QueueStatusFrame:IsShown(),false,"a tooltip already open on the eye is dismissed")
 T.eq(eye:GetScript("OnClick"),original,"the native click callback stays intact")
 T.eq(#Stubs.FramesWithEvent("ADDON_LOADED"),0,"native addon listener ends after binding")
 T.eq(opened,nil,"binding does not open or load a page")
 eye:SetAlpha(1);T.eq(eye:GetAlpha(),0,"later opacity changes cannot reveal the eye")
 eye:Show();T.eq(eye:GetAlpha(),0);T.eq(eye:IsMouseEnabled(),false)
 A:SetSetting("nativeLFGEntry",false)
 T.eq(eye:GetAlpha(),.8);T.eq(eye:IsMouseEnabled(),true,"turning the option off restores the original entry")
 T.eq(original(eye,"RightButton"),"RightButton");T.eq(nativeCalls,1)
 eye:SetAlpha(.6);eye:Show();T.eq(eye:GetAlpha(),.6,"disabled hooks allow normal native changes")
 A:SetSetting("nativeLFGEntry",true);A:SyncNativeLFGEntry()
 T.eq(eye:GetAlpha(),0);T.eq(hooks,1,"setting changes reuse the same hooks")
 A:SetSetting("nativeLFGEntry",false);T.eq(eye:GetAlpha(),.6)
 A:SetSetting("nativeLFGEntry",true)

 -- The native update also runs when the eye was already shown for a premade
 -- group. Matchmade dungeon/raid queues must release both opacity and mouse.
 local oldActiveEntry=C_LFGList.HasActiveEntryInfo
 C_LFGList.HasActiveEntryInfo=function() return true end
 for _,mode in ipairs({"rolecheck","queued","proposal","lfgparty","abandonedInDungeon"}) do
  modes[1]={mode}
  T.eq(QueueStatusFrame:Update(),"native update","the original native updater still runs")
  T.eq(eye:GetAlpha(),.6,"a native dungeon queue remains visible during "..mode)
  T.eq(eye:IsMouseEnabled(),true,"native queue actions remain available")
 end
 QueueStatusFrame:Show();eye:SetAlpha(.7);QueueStatusFrame:Update()
 T.eq(eye:GetAlpha(),.7,"native opacity changes are allowed while a dungeon queue is active")
 T.eq(QueueStatusFrame:IsShown(),true,"native queue details are not dismissed")
 T.eq(eye:GetScript("OnClick"),original,"native queue and leave actions keep their callback")
 T.eq(eye.EyeHighlightAnim.playing,true)
 A:SetSetting("nativeLFGEntry",false);A:SetSetting("nativeLFGEntry",true)
 T.eq(eye:GetAlpha(),.7,"enabling concealment during a native queue leaves it visible")
 modes[3]={"queued"};modes[1]=nil;QueueStatusFrame:Update()
 T.eq(eye:GetAlpha(),.7,"a remaining raid finder queue keeps the eye visible")
 T.eq(eye:IsMouseEnabled(),true)
 modes[3]=nil;QueueStatusFrame:Update()
 T.eq(eye:GetAlpha(),0,"leaving every native queue restores premade concealment without OnShow")
 T.eq(eye:IsMouseEnabled(),false);T.eq(QueueStatusFrame:IsShown(),false)
 T.eq(eye.EyeHighlightAnim.playing,true,"premade applicant sounds still have their native animation")
 modes[3]={"lfgparty","noteleport"};QueueStatusFrame:Update()
 T.eq(eye:GetAlpha(),0,"a state excluded by the native queue display does not reveal the eye")
 modes[3]={"queued"};eye:Show()
 T.eq(eye:GetAlpha(),.7,"OnShow also restores an active native queue")
 T.eq(eye:IsMouseEnabled(),true);T.eq(hooks,1)
 C_LFGList.HasActiveEntryInfo=oldActiveEntry
 GetLFGMode,NUM_LE_LFG_CATEGORYS=oldGetLFGMode,oldCategoryCount
 A.Open=oldOpen;_G.QueueStatusButton,_G.QueueStatusFrame=nil,nil
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

-- Normal opens follow the current native listing without depending on a loaded
-- Group snapshot or on permission to edit that listing.
do
 local oldUI,oldGroup,oldEnsure=A.UI,A.Group,A.Ensure
 local oldActiveEntry,oldLeader=C_LFGList.HasActiveEntryInfo,UnitIsGroupLeader
 local active,leader=false,false
 local shownPage,shownContext,loads
 local ui={Show=function(_,page,context) shownPage,shownContext=page,context end}
 C_LFGList.HasActiveEntryInfo=function() return active end
 UnitIsGroupLeader=function() return leader end
 A.Group=nil
 A.Ensure=function(_,module) loads[#loads+1]=module;return module=="UI" and ui or {} end
 for _,role in ipairs({"leader","transferred leader","member"}) do
  active=true;leader=role~="member";loads={}
  T.eq(A:GetDefaultPage(),"create",role.." uses the active party listing before Group loads")
  T.eq(A:Open(),true);T.eq(shownPage,"create",role.." opens the current recruitment")
  T.eq(loads[1],"Group");T.eq(loads[2],"UI")
 end
 active=false;loads={};A:Open();T.eq(shownPage,"find","an unlisted party opens normal search")
 active=true
 local context={applicationID=17}
 loads={};A:Open("find",context)
 T.eq(shownPage,"find","explicit application navigation keeps its target page")
 T.eq(shownContext,context)
 loads={};A:Open("notes");T.eq(shownPage,"notes","unrelated explicit navigation remains targeted")
 A.UI,A.Group,A.Ensure=oldUI,oldGroup,oldEnsure
 C_LFGList.HasActiveEntryInfo,UnitIsGroupLeader=oldActiveEntry,oldLeader
end

do
 local oldUI,oldOpen=A.UI,A.Open
 local oldActiveEntry=C_LFGList.HasActiveEntryInfo
 local active=false
 C_LFGList.HasActiveEntryInfo=function() return active end
 local shown,hidden,opened=false,0,0
 A.UI={IsShown=function() return shown end,Hide=function() hidden=hidden+1;shown=false end}
 A.Open=function(_,page) T.eq(page,active and "create" or "find");opened=opened+1;shown=true;return true end
 A:ToggleWindow();T.eq(opened,1)
 A:ToggleWindow();T.eq(hidden,1,"binding closes the current main window")
 active=true;A:ToggleWindow();T.eq(opened,2,"binding opens the party's active recruitment")
 A.UI.hiding=true;A:ToggleWindow();T.eq(opened,3,"reopening during exit also resolves the current listing")
 A.UI,A.Open=oldUI,oldOpen
 C_LFGList.HasActiveEntryInfo=oldActiveEntry
end

_G.LycheeGroupDB = nil

-- A START that first loads Group is a new run; login inside a run is recovery.
for _,entry in ipairs({"start","login","enable"}) do
 local loginInRun=entry=="login"
 Stubs.Install({locale="enUS",realm="Home"});Stubs.SetTime(10000)
 Stubs.SetUnit("player",{name="New",realm="Home",class="WARRIOR",guid="Player-new"})
 Load.addon("LycheeGroup","Locale.lua");Load.addon("LycheeGroup","Theme/Defaults.lua");Load.addon("LycheeGroup","Core.lua");Load.addon("LycheeGroup","Configuration.lua")
 local core=LycheeGroup;core:LoadDB();core:SetSetting("history",entry~="enable");core:SetSetting("nativeLFGEntry",false)
 core.Minimap={Initialize=function() end}
 local active,loads=loginInRun,0
 C_ChallengeMode={IsChallengeModeActive=function() return active end,GetActiveChallengeMapID=function() return active and 502 end,
  GetActiveKeystoneInfo=function() return 10 end,GetMapUIInfo=function() return "Current map" end}
 C_LFGList.GetApplications=function() return {} end
 C_LFGList.HasActiveEntryInfo=function() return false end
 local saved={runs={},activeRun={id="old-run",startedAt=100,mapChallengeModeID=502,level=10,mapName="Old map",
  members={["Old-Away"]={key="Old-Away",name="Old",realm="Away",specID=71}},order={"Old-Away"}}}
 C_AddOns.IsAddOnLoaded=function() return false,false end
 C_AddOns.LoadAddOn=function()
  loads=loads+1
  local group={charDB=saved,Public=function(value) return value end,Notify=function() end,
   Game={EnableRunTracking=function() end,DisableRunTracking=function() end},Roster={GetUnitSpec=function() end}}
  core.Group=group;Load.addon("LycheeGroup_Group","History.lua")
  function group:Initialize() self.History:Restore() end
  function group:OnEvent(event)
   if event=="CHALLENGE_MODE_START" then self.History:OnStart() elseif event=="CHALLENGE_MODE_COMPLETED" then self.History:OnCompleted() end
  end
  return true
 end
 Load.addon("LycheeGroup","Entrypoints.lua");Stubs.FireEvent("PLAYER_LOGIN")
 if not loginInRun then
  T.eq(loads,0,"outside a run the stale LoD baseline does not load Group")
  active=true;Stubs.FireEvent("CHALLENGE_MODE_START")
  if entry=="enable" then
   T.eq(loads,0,"history disabled during START keeps Group unloaded")
   core:SetSetting("history",true)
  end
 end
 T.eq(loads,1)
 local group=core.Group;local run=group.History:GetActiveRun()
 if loginInRun then
  T.eq(run.id,"old-run","login during the active run keeps its saved identity")
  T.eq(run.startedAt,100);T.eq(#run.members,2,"recovery retains the earlier member baseline")
 else
  T.ok(run.id~="old-run","a new same-map same-level run must not reuse an abandoned saved run")
  T.eq(run.startedAt,10000);T.eq(#run.members,1);T.eq(run.members[1].key,"New-Home")
 end
 T.eq(#saved.runs,0,"recovery and new-run handoff never complete the old run")
 group:OnEvent("CHALLENGE_MODE_START")
 T.eq(group.History:GetActiveRun().id,run.id,"duplicate delivery preserves the accepted current baseline")
 group:OnEvent("CHALLENGE_MODE_COMPLETED")
 T.eq(saved.runs[1].id,run.id);T.eq(saved.runs[1].startedAt,run.startedAt);T.eq(#saved.runs[1].members,#run.members)
 T.eq(saved.activeRun,nil)
end
