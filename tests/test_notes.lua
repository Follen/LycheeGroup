-- Notes 包行为:记录增删改查、合并语义、身份拒绝、提醒去重与检视超时。
local Stubs = TestStubs
Stubs.Install({ locale = "zhCN", realm = "晨风号角" })

-- 用当前命名空间调用检视,旧全局在本测试中不可用。
local oldInspectGlobal = GetInspectSpecialization
GetInspectSpecialization = nil

-- 玩家单位固定存在,供"不能记录自己"与花名册测试使用。
Stubs.SetUnit("player", { name = "本人", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-0" })

Load.addon("LycheeGroup", "Locale.lua")
Load.addon("LycheeGroup", "Core.lua")
Load.addon("LycheeGroup", "Specializations.lua")
LycheeGroup:LoadDB() -- Core ADDON_LOADED precedes every LoD package.
Load.addon("LycheeGroup_Notes", "Locale.lua")
Load.addon("LycheeGroup_Notes", "Notes.lua")
Load.addon("LycheeGroup_Notes", "Records.lua")
Load.addon("LycheeGroup_Notes", "RosterReminder.lua")
Load.addon("LycheeGroup_Notes", "PlayerInfo.lua")

local A = _G.LycheeGroup
local Notes = A.Notes

Notes:Initialize()

-- ---------------------------------------------------------------- 基础记录

T.eq(A.db.notesHasRecords, false, "初始无记录")

do
	local ok, record = Notes:Add("艾莉安娜", "晨风号角", "坦克很强", nil)
	T.ok(ok, "Add 成功")
	T.eq(record.name, "艾莉安娜")
	T.eq(record.server, "晨风号角")
	T.eq(record.reason, "坦克很强")
	T.eq(record.classSpec, "", "无 unit 且无预取专精时存待定语义值")
	T.eq(A.db.notesHasRecords, true, "写入后摘要翻转")
end

do
	-- 跨服同名不混淆:键由名字+服务器组成。
	Notes:Add("艾莉安娜", "银松森林", "另一个人", nil)
	T.ok(Notes:Find("艾莉安娜-晨风号角"), "本服记录仍在")
	T.ok(Notes:Find("艾莉安娜-银松森林"), "跨服记录独立")
end

do
	-- 不能记录自己。
	local ok, err = Notes:Add("本人", "晨风号角", "x", "player")
	T.eq(ok, false)
	T.eq(err, "不能记录自己。")
	local ok2 = Notes:Add("本人", "晨风号角", "x", nil)
	T.eq(ok2, false, "同名同服同样拒绝")
end

do
	-- Edit / Remove / List。
	Notes:Add("Bob", "晨风号角", "旧理由", nil)
	local key = "Bob-晨风号角"
	T.ok(Notes:Edit(key, "新理由"), "Edit 命中")
	T.eq(Notes:Find(key).reason, "新理由")
	T.ok(Notes:Remove(key), "Remove 命中")
	T.eq(Notes:Find(key), nil, "删除后查不到")
	T.eq(Notes:Edit(key, "x"), false, "编辑已删记录失败")
end

do
	-- List:时间倒序,同时间按键稳定;文本过滤。
	local keys = Notes:List()
	T.ok(#keys >= 2, "至少两条记录")
	local a, b = keys[1], keys[2]
	local ta = Notes:Find(a).timestamp
	local tb = Notes:Find(b).timestamp
	T.ok(ta >= tb, "时间倒序")
	local filtered = Notes:List({ text = "坦克很强" })
	T.eq(#filtered, 1, "理由子串过滤")
	T.eq(filtered[1], "艾莉安娜-晨风号角")
end

-- ---------------------------------------------------------------- 合并语义

do
	Notes:Remove("艾莉安娜-晨风号角")
	Notes:Remove("艾莉安娜-银松森林")

	-- 本地无 → 新增。
	local changed, invalid = Notes:Merge({
		{ name = "新玩家", server = "晨风号角", timestamp = 100, reason = "r1", classSpec = "战士-武器" },
	})
	T.eq(changed, 1, "无记录时导入写入 1")
	T.eq(invalid, 0)

	-- 更晚覆盖;相同/更早保留;重复导入 0。
	changed, invalid = Notes:Merge({
		{ name = "新玩家", server = "晨风号角", timestamp = 200, reason = "r2", classSpec = "战士-武器" },
	})
	T.eq(changed, 1, "更晚时间戳覆盖")
	T.eq(Notes:Find("新玩家-晨风号角").reason, "r2")

	changed, invalid = Notes:Merge({
		{ name = "新玩家", server = "晨风号角", timestamp = 200, reason = "r2", classSpec = "战士-武器" },
	})
	T.eq(changed, 0, "相同时间戳重复导入写入 0")

	changed, invalid = Notes:Merge({
		{ name = "新玩家", server = "晨风号角", timestamp = 50, reason = "更早", classSpec = "" },
	})
	T.eq(changed, 0, "更早保留本地")
	T.eq(Notes:Find("新玩家-晨风号角").reason, "r2")

	-- 无效条目计数,不静默截断。
	changed, invalid = Notes:Merge({
		"垃圾字符串",
		{ server = "无名字" },
		{ name = "", server = "x" },
		{ name = "有效", server = "晨风号角", timestamp = 300 },
	})
	T.eq(changed, 1, "混合导入仍写入有效项")
	T.eq(invalid, 3, "无效项计数")

	Notes:Remove("新玩家-晨风号角")
	Notes:Remove("有效-晨风号角")
end

do
 local reason="  "..string.rep("long import reason ",300).."  "
 local classSpec="  "..string.rep("legacy specialization ",220).."  "
 local item={name="重复大记录",server="晨风号角",timestamp=200,reason=reason,classSpec=classSpec}
 Notes:Merge({item})
 local original=Notes:Find("重复大记录-晨风号角")
 local gsub,scans=string.gsub,0
 string.gsub=function(value,...) if #value>4096 then scans=scans+1 end;return gsub(value,...) end
 local changed,invalid=Notes:Merge({item});item.timestamp=100
 local olderChanged,olderInvalid=Notes:Merge({item})
 string.gsub=gsub
 T.eq(changed,0);T.eq(invalid,0);T.eq(olderChanged,0);T.eq(olderInvalid,0)
 T.eq(scans,0,"unchanged or older imports do not rescan discarded long reason/spec text")
 T.eq(Notes:Find("重复大记录-晨风号角"),original)
 item.timestamp=300;Notes:Merge({item})
 T.eq(Notes:Find("重复大记录-晨风号角").reason,reason:match("^%s*(.-)%s*$"),"newer content still receives normal trimming")
 T.eq(Notes:Find("重复大记录-晨风号角").classSpec,classSpec:match("^%s*(.-)%s*$"))
 Notes:Remove("重复大记录-晨风号角")
end

do
	local imported = {
		{ name = "旧零时间", server = "晨风号角", timestamp = 0, reason = "旧理由", classSpec = "历史专精原文" },
		{ name = "旧缺时间", server = "晨风号角", reason = "" },
	}
	Stubs.SetTime(1000)
	local changed, invalid = Notes:Merge(imported)
	T.eq(changed, 2, "旧时间记录正常导入")
	T.eq(invalid, 0)
	T.eq(Notes:Find("旧零时间-晨风号角").timestamp, 0, "未知时间保持稳定0")
	T.eq(Notes:Find("旧缺时间-晨风号角").timestamp, 0)
	T.eq(Notes:Find("旧缺时间-晨风号角").reason, "", "空理由存语义值")
	T.eq(Notes:Find("旧零时间-晨风号角").classSpec, "历史专精原文", "无法还原的历史专精保留原文")
	Notes:Edit("旧零时间-晨风号角", "之后本地修改")
	Stubs.SetTime(2000)
	changed, invalid = Notes:Merge(imported)
	T.eq(changed, 0, "跨秒重导零或缺时间记录写入0")
	T.eq(invalid, 0)
	T.eq(Notes:Find("旧零时间-晨风号角").reason, "之后本地修改", "重导不能覆盖后续本地理由")
	Notes:Remove("旧零时间-晨风号角")
	Notes:Remove("旧缺时间-晨风号角")
	Stubs.SetTime(nil)
end

-- ---------------------------------------------------------------- 订阅发布

do
	local seen = {}
	local unsub = Notes:Subscribe(function(kind, key)
		seen[#seen + 1] = kind .. ":" .. tostring(key)
	end)
	Notes:Add("订阅甲", "晨风号角", "r", nil)
	Notes:Edit("订阅甲-晨风号角", "r2")
	Notes:Remove("订阅甲-晨风号角")
	unsub()
	Notes:Add("订阅乙", "晨风号角", "r", nil)
	T.eq(#seen, 3, "退订后不再收到")
	T.eq(seen[1], "add:订阅甲-晨风号角")
	T.eq(seen[2], "edit:订阅甲-晨风号角")
	T.eq(seen[3], "remove:订阅甲-晨风号角")
	Notes:Remove("订阅乙-晨风号角")
end

do
	local notifications = {}
	local unsub = Notes:Subscribe(function(kind, keys)
		if kind == "merge" then notifications[#notifications + 1] = keys end
	end)
	local imported = {
		{ name = "合并甲", server = "晨风号角", timestamp = 10 },
		{ name = "合并乙", server = "晨风号角", timestamp = 20 },
		{ name = "合并甲", server = "晨风号角", timestamp = 30, reason = "更晚" },
	}
	Notes:Merge(imported)
	T.eq(#notifications, 1, "合并只发布一次批次通知")
	T.same(notifications[1], { "合并甲-晨风号角", "合并乙-晨风号角" }, "通知给出唯一变更身份")
	Notes:Merge(imported)
	T.eq(#notifications, 1, "幂等导入不发布刷新")
	unsub()
	Notes:Remove("合并甲-晨风号角")
	Notes:Remove("合并乙-晨风号角")
end

-- ---------------------------------------------------------------- 入队提醒

local function RosterCount()
	return #Stubs.ChatMessages()
end

do
	-- 自己进入已有队伍必须检查现有成员,重复入组/花名册事件不刷屏。
	Notes:Add("危险人", "晨风号角", "划水", nil)
	A.db.notesEnabled = true
	Notes:SyncEnabled()
	local recorded = { name = "危险人", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-1" }
	Stubs.SetUnit("party1", recorded)
	Stubs.FireEvent("GROUP_JOINED")
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(), 1, "自己入组检查已记录成员")
	T.ok(Stubs.ChatMessages()[1]:find("危险人", 1, true), "提醒包含玩家名")
	T.ok(Stubs.ChatMessages()[1]:find("划水", 1, true), "提醒包含理由")
	T.ok(Stubs.ChatMessages()[1]:find("荔枝|r组队", 1, true), "统一抬头")
	T.ok(Stubs.ChatMessages()[1]:find("|Hlycheegroup:note:", 1, false), "携带查看记录链接")
	Stubs.FireEvent("GROUP_JOINED")
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(), 1, "重复事件不重复提醒")
	Stubs.SetUnit("party2", { name = "队友乙", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-2" })
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(), 1, "无记录新成员不提醒")

	-- 名字暂不可读时不能把成员当作离开,恢复可读后不重复提醒。
	Stubs.SetUnit("party1", { realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-1" })
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	Stubs.SetUnit("party1", recorded)
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(), 1, "身份暂不可读后恢复不重报")

	-- secret 名字/服务器交给唯一身份入口,不先比较或当成本服身份。
	local secret = newproxy(true)
	getmetatable(secret).__tostring = function() error("不应读取受限身份") end
	local oldIsSecret = issecretvalue
	issecretvalue = function(value) return rawequal(value, secret) end
	Stubs.SetUnit("party1", { name = secret, realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-1" })
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	Stubs.SetUnit("party1", { name = "危险人", realm = secret, class = "WARRIOR", classID = 1, guid = "P-1" })
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	Stubs.SetUnit("party1", recorded)
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	issecretvalue = oldIsSecret
	T.eq(RosterCount(), 1, "受限身份恢复后不误判为重新相遇")

	-- 离队后重入 → 再次提醒。
	Stubs.SetUnit("party1", nil)
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	Stubs.SetUnit("party1", recorded)
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(), 2, "离开后重入再次提醒")

	-- 退组清理基线;订阅保留(再入组继续工作),停用才退订。
	Stubs.FireEvent("GROUP_LEFT")
	T.eq(#Stubs.FramesWithEvent("GROUP_ROSTER_UPDATE"), 1, "退组后保留订阅等待下次组队")
	Stubs.FireEvent("GROUP_JOINED")
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(), 3, "自己退组重入再次提醒")
	Stubs.FireEvent("GROUP_LEFT")
	Stubs.SetUnit("party1", { realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-1" })
	Stubs.FireEvent("GROUP_JOINED")
	Stubs.SetUnit("party1", recorded)
	Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(), 4, "入组时名字未就绪在后续事件补发")

	Notes.RosterReminder.Stop()
	T.eq(#Stubs.FramesWithEvent("GROUP_JOINED"), 0, "停用后退订全部事件")
	T.eq(#Stubs.FramesWithEvent("GROUP_LEFT"), 0)
	Notes.RosterReminder.Start()
	T.eq(RosterCount(), 5, "登录恢复或重新启用检查当前队伍")

	-- 清理场景。
	Stubs.SetUnit("party1", nil)
	Stubs.SetUnit("party2", nil)
	Stubs.SetUnit("party3", nil)
	Notes:Remove("危险人-晨风号角")
	T.eq(#Stubs.FramesWithEvent("GROUP_ROSTER_UPDATE"), 0, "移除最后记录立即退订队伍事件")
end

-- ---------------------------------------------------------------- 专精查询

do
	Notes:Add("邀请者", "晨风号角", "本服记录", nil, nil, {type="positive"})
	Notes:Add("邀请者", "银松森林", "跨服记录", nil, nil, {type="caution"})
	Stubs.SetUnit("target", {name="邀请者",realm="银松森林",guid="P-inviter"})
	local function Receive(name, guid)
		Stubs.FireEvent("PARTY_INVITE_REQUEST",name,false,false,false,false,false,guid,false)
	end
	local before=RosterCount()
	Receive("邀请者","P-inviter")
	T.eq(RosterCount(),before+1,"收到邀请时在入队前提示邀请者的记录")
	local message=Stubs.ChatMessages()[before+1]
	T.ok(message:find("跨服记录",1,true),"邀请者GUID对应服务器优先，不能命中本服同名")
	T.ok(message:find("邀请者-银松森林",1,true),"邀请提醒给出完整身份")
	T.ok(message:find("|Hlycheegroup:note:邀请者-银松森林",1,true),"邀请提醒保留查看记录链接")
	T.ok(message:find("荔枝|r组队",1,true),"邀请提醒使用现有品牌输出")
	Receive("邀请者-银松森林","P-uncached")
	T.eq(RosterCount(),before+2,"GUID尚无缓存时仍可识别事件给出的完整身份")
	Receive("邀请者","P-uncached")
	T.eq(RosterCount(),before+2,"不能把未知服务器的邀请者裸名当成本服同名")
	Receive("没有记录-银松森林","P-unknown")
	T.eq(RosterCount(),before+2,"未记录的邀请者不提醒")
	local nativeCalls=#Stubs.PartyInvites()
	T.eq(C_PartyInfo.InviteUnit("邀请者-银松森林"),nil,"出邀观察不制造业务返回值")
	T.eq(#Stubs.PartyInvites(),nativeCalls+1,"原生邀请仍只调用一次")
	T.eq(Stubs.PartyInvites()[nativeCalls+1],"邀请者-银松森林","不改邀请对象")
	T.eq(RosterCount(),before+3,"主动邀请已记录玩家时提示本地记录")
	T.ok(Stubs.ChatMessages()[before+3]:find("你邀请的",1,true),"出邀提示不宣称对方已接受或入队")

	A:SetSetting("reminders","positive")
	before=RosterCount()
	Receive("邀请者","P-inviter");C_PartyInfo.InviteUnit("邀请者-银松森林")
	T.eq(RosterCount(),before,"收邀和出邀都遵循现有记录类型筛选")
	C_PartyInfo.InviteUnit("邀请者")
	T.eq(RosterCount(),before+1,"普通邀请API的本服名字按现有身份入口命中")
	A:SetSetting("reminders","off")
	T.eq(#Stubs.FramesWithEvent("PARTY_INVITE_REQUEST"),0,"关闭提醒立即退订收邀事件")
	before=RosterCount();nativeCalls=#Stubs.PartyInvites()
	Receive("邀请者","P-inviter");C_PartyInfo.InviteUnit("邀请者-银松森林")
	T.eq(RosterCount(),before,"关闭提醒后永久出邀hook保持安静")
	T.eq(#Stubs.PartyInvites(),nativeCalls+1,"关闭提醒不拦截原生邀请")
	A:SetSetting("reminders","all")
	T.eq(#Stubs.FramesWithEvent("PARTY_INVITE_REQUEST"),1,"重新开启只恢复一个收邀订阅")
	for _=1,3 do Notes.RosterReminder.Stop();Notes.RosterReminder.Start() end
	before=RosterCount();C_PartyInfo.InviteUnit("邀请者-银松森林")
	T.eq(RosterCount(),before+1,"反复启停不会叠加永久安全hook")
	A:SetSetting("notesEnabled",false)
	T.eq(#Stubs.FramesWithEvent("PARTY_INVITE_REQUEST"),0)
	before=RosterCount();C_PartyInfo.InviteUnit("邀请者-银松森林")
	T.eq(RosterCount(),before,"笔记总开关同时停止邀请提醒")
	A:SetSetting("notesEnabled",true)
	Notes:Remove("邀请者-晨风号角");Notes:Remove("邀请者-银松森林")
	T.eq(#Stubs.FramesWithEvent("PARTY_INVITE_REQUEST"),0,"删除最后记录立即退订收邀事件")
	before=RosterCount();C_PartyInfo.InviteUnit("邀请者-银松森林")
	T.eq(RosterCount(),before,"无记录时永久hook不查询或输出")
	T.eq(Stubs.PendingTimers(),0,"邀请提醒不增加轮询或到期任务")
	Stubs.SetUnit("target",nil)
end

do
	-- Snapshot:同步已有数据。
	Stubs.SetUnit("party1", { name = "队友甲", realm = "晨风号角", class = "PALADIN", classID = 2, guid = "P-1" })
	local previousGroup=A.Group
	A.Group={Public=function(value) return value end,Notify=function() end,History={OnSpecUpdate=function() end}}
	Load.addon("LycheeGroup_Group","Roster.lua")
	A.Group.Roster:OnLibrarySpec(66,"队友甲-晨风号角")
	Stubs.SetInspectSpec("party1",70)
	local before=#Stubs.InspectRequests()
	local text,details=Notes.PlayerInfo.Snapshot("party1")
	T.eq(text,"圣骑士-神圣","已有同步库GUID缓存优先于旧的原生检视值")
	T.eq(details.class,"PALADIN");T.eq(details.specID,66);T.eq(details.classSpec,text)
	local gotText,gotDetails
	Notes.PlayerInfo.Request("party1",function(value,info) gotText,gotDetails=value,info end)
	T.eq(gotText,text);T.eq(gotDetails.specID,66)
	T.eq(#Stubs.InspectRequests(),before,"已有同步缓存不再发起检视")
	local ok,snapshot=Notes:Add("队友甲","晨风号角","同步记录","party1")
	T.ok(ok);T.eq(snapshot.class,"PALADIN");T.eq(snapshot.specID,66);T.eq(snapshot.classSpec,text)
	Notes:Remove("队友甲-晨风号角")
	A.Group=previousGroup
	Stubs.SetInspectSpec("party1", 66)
	T.eq(Notes.PlayerInfo.Snapshot("party1"), "圣骑士-神圣", "同步快照拼接职业专精")
	text,details=Notes.PlayerInfo.Snapshot("party1")
	T.eq(details.class,"PALADIN");T.eq(details.specID,66,"仅Notes加载也返回结构化原生专精")
	local historical={classSpec="圣骑士-神圣"}
	local resolved=Notes.PlayerInfo.ResolveRecord(historical)
	T.eq(resolved.class,"PALADIN");T.eq(resolved.specID,66)
	T.eq(historical.class,nil);T.eq(historical.specID,nil,"读取旧文字不会改写历史存档")
	T.eq(Notes.PlayerInfo.ResolveRecord({classSpec="圣骑士 · 神圣"}).specID,66,"解析现有编辑器保存的文字分隔符")
	resolved=Notes.PlayerInfo.ResolveRecord({classSpec="未能解析的历史文字"})
	T.eq(resolved.class,nil);T.eq(resolved.specID,nil);T.eq(resolved.classSpec,"未能解析的历史文字")
	local getSpec,reads=GetSpecializationInfoForClassID,0
	GetSpecializationInfoForClassID=function(...) reads=reads+1;return getSpec(...) end
	for i=1,100 do Notes.PlayerInfo.ResolveRecord({classSpec=""}) end
	T.eq(reads,0,"unknown records do not scan the specialization catalog")
	resolved=Notes.PlayerInfo.ResolveRecord({class="PALADIN",classSpec=""})
	T.eq(resolved.class,"PALADIN");T.eq(resolved.specID,nil);T.eq(resolved.classSpec,"圣骑士")
	T.eq(reads,0,"a known class without specialization or legacy text needs no specialization scan")
	GetSpecializationInfoForClassID=getSpec
	do
		local savedMetadata, getClass = A.Specializations, GetClassInfo
		local ready, classReads = false, 0
		Load.addon("LycheeGroup", "Specializations.lua")
		GetClassInfo=function(id)
			classReads=classReads+1
			local name, token, classID=getClass(id)
			if token=="PALADIN" and not ready then return end
			return name, token, classID
		end
		local record={class="PALADIN",specID=66,classSpec=""}
		T.eq(Notes.PlayerInfo.ResolveRecord(record).class,nil,"an incomplete class directory is not treated as a permanent match")
		ready=true
		T.eq(Notes.PlayerInfo.ResolveRecord(record).specID,66,"class metadata recovers when the native directory becomes available")
		Load.addon("LycheeGroup", "Specializations.lua")
		local getSpecializationCount=C_SpecializationInfo.GetNumSpecializationsForClassID
		local specsReady=false
		C_SpecializationInfo.GetNumSpecializationsForClassID=function(classID)
			if classID==2 and not specsReady then return 0 end
			return getSpecializationCount(classID)
		end
		T.eq(Notes.PlayerInfo.ResolveRecord(record).specID,nil,"missing specialization metadata remains unresolved")
		specsReady=true
		T.eq(Notes.PlayerInfo.ResolveRecord(record).specID,66,"specialization metadata can recover on a later read")
		C_SpecializationInfo.GetNumSpecializationsForClassID=getSpecializationCount
		Load.addon("LycheeGroup", "Specializations.lua")
		local getSpecializationInfo=GetSpecializationInfoForClassID
		local infoReady=false
		GetSpecializationInfoForClassID=function(classID,index)
			if classID==2 and not infoReady then return end
			return getSpecializationInfo(classID,index)
		end
		T.eq(Notes.PlayerInfo.ResolveRecord(record).specID,nil,"a partial specialization directory remains unresolved without breaking record display")
		infoReady=true
		T.eq(Notes.PlayerInfo.ResolveRecord(record).specID,66,"a partial specialization directory recovers on the next read")
		GetSpecializationInfoForClassID=getSpecializationInfo
		Load.addon("LycheeGroup", "Specializations.lua")
		T.eq(A.Specializations:Get(66),"Specialization","the generic ID lookup may cache its own label")
		local afterIDLookup=Notes.PlayerInfo.ResolveRecord({class="PALADIN",specID=66,classSpec=""})
		T.eq(afterIDLookup.classSpec,"圣骑士-神圣","structured resolution keeps the per-class catalog label after an ID lookup")
		local winsByID=Notes.PlayerInfo.ResolveRecord({class="PALADIN",specID=66,classSpec="圣骑士-惩戒"})
		T.eq(winsByID.specID,66,"a valid structured specialization takes priority over legacy text")
		T.eq(winsByID.classSpec,"圣骑士-神圣")
		local fallsBackToText=Notes.PlayerInfo.ResolveRecord({class="PALADIN",specID=71,classSpec="圣骑士-神圣"})
		T.eq(fallsBackToText.specID,66,"a specialization ID from another class falls back to matching legacy text")
		classReads=0
		Notes.PlayerInfo.ResolveRecord(record) -- Warm the shared class/name directory before measuring repeated row binding.
		local getSpecializationInfo=GetSpecializationInfoForClassID
		local countReads,infoReads=0,0
		C_SpecializationInfo.GetNumSpecializationsForClassID=function(...) countReads=countReads+1;return getSpecializationCount(...) end
		GetSpecializationInfoForClassID=function(...) infoReads=infoReads+1;return getSpecializationInfo(...) end
		for i=1,100 do
			local identity=Notes.PlayerInfo.ResolveRecord(record)
			T.eq(identity.class,"PALADIN");T.eq(identity.specID,66)
		end
		T.eq(classReads,0,"repeated note bindings reuse the shared class directory")
		T.eq(countReads,0,"repeated structured rows reuse the shared specialization directory")
		T.eq(infoReads,0,"repeated structured rows reuse the shared specialization entry")
		C_SpecializationInfo.GetNumSpecializationsForClassID=getSpecializationCount
		GetSpecializationInfoForClassID=getSpecializationInfo
		local rejectsWrongClass=Notes.PlayerInfo.ResolveRecord({class="WARRIOR",specID=66,classSpec="战士-武器"})
		T.eq(rejectsWrongClass.class,"WARRIOR");T.eq(rejectsWrongClass.specID,71,"an ID belonging to another class falls back to matching legacy text")
		local rejectsWrongClassID=Notes.PlayerInfo.ResolveRecord({class="WARRIOR",specID=66,classSpec=""})
		T.eq(rejectsWrongClassID.class,"WARRIOR");T.eq(rejectsWrongClassID.specID,nil,"an ID belonging to another class is not accepted")
		T.eq(record.classSpec,"","display resolution does not rewrite the stored snapshot")
		GetClassInfo, A.Specializations=getClass, savedMetadata
	end
	ok,snapshot=Notes:Add("旧文字记录","银松森林","",nil,"圣骑士-神圣")
	T.ok(ok);T.eq(snapshot.class,"PALADIN");T.eq(snapshot.specID,66,"接收旧字符串的添加入口也存入可靠结构")
	Notes:Remove("旧文字记录-银松森林")
	ok,snapshot=Notes:Add("手选记录","银松森林","",nil,"圣骑士-神圣",{class="WARRIOR",specID=71})
	T.ok(ok);T.eq(snapshot.class,"WARRIOR");T.eq(snapshot.specID,71);T.eq(snapshot.classSpec,"战士-武器","手动结构选择与文字保持一致，不混入其他玩家专精")
	Notes:Remove("手选记录-银松森林")

	-- Request:同步路径直接回调。
	local got
	Notes.PlayerInfo.Request("party1", function(spec) got = spec end)
	T.eq(got, "圣骑士-神圣", "同步请求立即回调")
	T.eq(Stubs.PendingTimers(), 0, "同步请求不留计时器")
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 0, "同步请求不监听检视结果")

	-- 显式未知专精不能在写入时重新读取一个已经换绑的单位。
	local ok, snapshot = Notes:Add("已捕获身份", "银松森林", "", "party1", "")
	T.ok(ok)
	T.eq(snapshot.classSpec, "", "显式未知不被当前单位专精覆盖")
	T.eq(snapshot.reason, "", "空理由留给显示端本地化")
	Notes:Remove("已捕获身份-银松森林")
	ok, snapshot = Notes:Add("已捕获身份", "银松森林", "", "party1", nil)
	T.ok(ok)
	T.eq(snapshot.classSpec, "", "单位身份已换绑时不重取其他玩家专精")
	Notes:Remove("已捕获身份-银松森林")
	ok, snapshot = Notes:Add("已捕获身份", "银松森林", "", "party1", "已核实的历史专精")
	T.ok(ok)
	T.eq(snapshot.classSpec, "已核实的历史专精", "单位失效不丢弃已核实历史快照")
	Notes:Remove("已捕获身份-银松森林")

	-- Request:异步路径 → NotifyInspect + INSPECT_READY。
	Stubs.SetUnit("party2", { name = "队友乙", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-2" })
	Stubs.SetInspectSpec("party2", 0)
	got = "pending"
	local inspectedDetails
	Notes.PlayerInfo.Request("party2", function(spec,details) got,inspectedDetails = spec,details end)
	T.eq(got, "pending", "未就绪时挂起")
	T.eq(Stubs.PendingTimers(), 1, "异步请求只留单次超时")
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 1)
	T.eq(Stubs.InspectRequests()[#Stubs.InspectRequests()], "party2", "发出检视")
	-- 错误 GUID 的事件被忽略。
	Stubs.SetInspectSpec("party2", 72)
	Stubs.FireEvent("INSPECT_READY", "P-OTHER")
	T.eq(got, "pending", "GUID 不匹配不结束")
	Stubs.FireEvent("INSPECT_READY", "P-2")
	T.eq(got, "战士-狂怒", "GUID 匹配后回调")
	T.eq(inspectedDetails.class,"WARRIOR");T.eq(inspectedDetails.specID,72,"检视完成后字符串和结构一同交回")
	T.eq(Stubs.PendingTimers(), 0, "完成后超时计时器已清理")
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 0, "完成后结果事件已退订")

	-- 同一个 token 换到另一个 GUID,旧结果不能读取新玩家的职业专精。
	Stubs.SetUnit("target", { name = "旧目标", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "OLD" })
	Stubs.SetInspectSpec("target", 0)
	got = "pending"
	Notes.PlayerInfo.Request("target", function(spec) got = spec end)
	Stubs.SetUnit("target", { name = "新目标", realm = "银松森林", class = "PALADIN", classID = 2, guid = "NEW" })
	Stubs.SetInspectSpec("target", 70)
	Stubs.FireEvent("INSPECT_READY", "OLD")
	T.eq(got, nil, "同token换GUID结束为未知")
	T.eq(Stubs.PendingTimers(), 0, "换绑后立即清超时")
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 0)
	Stubs.SetUnit("target", nil)

	-- 原生受限专精/职业在比较或拼接前停止,不保存受限数据。
	local oldIsSecret = issecretvalue
	issecretvalue = function(value) return value == 72 end
	T.eq(Notes.PlayerInfo.Snapshot("party2"), nil, "secret专精不参与数值比较/目录匹配")
	issecretvalue = function(value) return value == "战士" end
	T.eq(Notes.PlayerInfo.Snapshot("party2"), nil, "secret职业名不拼接")
	issecretvalue = oldIsSecret

	-- Request:超时路径。
	Stubs.SetUnit("party3", { name = "队友丙", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-3" })
	Stubs.SetInspectSpec("party3", 0)
	got = "pending"
	Notes.PlayerInfo.Request("party3", function(spec) got = spec end)
	Stubs.AdvanceClock(5)
	T.eq(got, nil, "超时回调 nil")
	T.eq(Stubs.PendingTimers(), 0, "超时后无残留计时器")
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 0)

	-- 调用方取消立即清理,重复取消和迟到结果均不会再次回调。
	local calls = 0
	local cancel = Notes.PlayerInfo.Request("party3", function(spec) got = spec; calls = calls + 1 end)
	T.eq(type(cancel), "function", "异步请求提供取消函数")
	cancel()
	cancel()
	Stubs.FireEvent("INSPECT_READY", "P-3")
	T.eq(calls, 1, "取消只结束一次")
	T.eq(got, nil)
	T.eq(Stubs.PendingTimers(), 0)
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 0)

	-- 新请求取消旧请求:旧回调先收 nil。
	Stubs.SetUnit("party4", { name = "队友丁", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-4" })
	Stubs.SetInspectSpec("party4", 0)
	local oldGot = "pending"
	local cancelOld = Notes.PlayerInfo.Request("party4", function(spec) oldGot = spec end)
	Stubs.SetUnit("party5", { name = "队友戊", realm = "晨风号角", class = "PALADIN", classID = 2, guid = "P-5" })
	Stubs.SetInspectSpec("party5", 0)
	local newGot = "pending"
	Notes.PlayerInfo.Request("party5", function(spec) newGot = spec end)
	T.eq(oldGot, nil, "旧请求被取消并回调 nil")
	cancelOld()
	T.eq(Stubs.PendingTimers(), 1, "旧取消函数不能取消新请求")
	Stubs.SetInspectSpec("party5", 70)
	Stubs.FireEvent("INSPECT_READY", "P-5")
	T.eq(newGot, "圣骑士-惩戒", "新请求正常完成")
	T.eq(Stubs.PendingTimers(), 0)
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 0)

	Stubs.SetInspectSpec("party1", 0)
	got = "pending"
	Notes.PlayerInfo.Request("party1", function(spec) got = spec end)
	Stubs.SetUnit("party1", nil)
	Stubs.FireEvent("INSPECT_READY", "P-1")
	T.eq(got, nil, "单位消失后结束为未知")
	T.eq(Stubs.PendingTimers(), 0)
	T.eq(#Stubs.FramesWithEvent("INSPECT_READY"), 0)

	for i = 1, 5 do Stubs.SetUnit("party" .. i, nil) end
end

T.eq(A.db.notesHasRecords, false, "清理后摘要回到无记录")
T.eq(#Stubs.FramesWithEvent("GROUP_ROSTER_UPDATE"), 0, "无记录没有提醒监听")
GetInspectSpecialization = oldInspectGlobal

_G.LycheeGroupDB = nil
_G.LycheeGroupNotesDB = nil
_G.LycheeGroup = nil
