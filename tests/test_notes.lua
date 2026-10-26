-- Notes 包行为:记录增删改查、合并语义、身份拒绝、提醒去重与检视超时。
local Stubs = TestStubs
Stubs.Install({ locale = "zhCN", realm = "晨风号角" })

-- 用当前命名空间调用检视,旧全局在本测试中不可用。
local oldInspectGlobal = GetInspectSpecialization
GetInspectSpecialization = nil

-- 玩家单位固定存在,供"不能记录自己"与花名册测试使用。
Stubs.SetUnit("player", { name = "本人", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-0" })

Load.addon("LycheeGroup", "Locale.lua")
Load.addon("LycheeGroup", "Theme/Defaults.lua")
Load.addon("LycheeGroup", "Core.lua")
Load.addon("LycheeGroup", "Configuration.lua")
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

-- Non-table roots are isolated before records bind; legitimate subsequent
-- records and the independent character preferences remain usable.
do
 local previous=_G.LycheeGroupNotesDB
 local account,character,sort=A.db,A.charPrefs,A:GetSetting("defaultSort")
 for _,invalid in ipairs({true,false,"damaged notes root",7}) do
  _G.LycheeGroupNotesDB=invalid;Notes.db=nil;Notes:Initialize()
  local recovery=Notes.db.invalidRecords
  T.eq(recovery and recovery[1] and recovery[1].key,"$root")
  T.eq(recovery[1].value,invalid);T.eq(type(recovery[1].error),"string")
  T.eq(A.db,account);T.eq(A.charPrefs,character);T.eq(A:GetSetting("defaultSort"),sort)
  local ok,record=Notes:Add("恢复后玩家","晨风号角","正常写入",nil)
  T.ok(ok);T.eq(Notes:Find("恢复后玩家-晨风号角"),record)
  Notes.db=nil;Notes:Initialize()
  T.eq(Notes.db.invalidRecords,recovery);T.eq(#recovery,1,"reinitialization does not append the same root damage again")
  T.eq(Notes:Find("恢复后玩家-晨风号角"),record,"healthy records retain identity after root recovery")
  Notes:Remove("恢复后玩家-晨风号角")
 end
 _G.LycheeGroupNotesDB=nil;Notes.db=nil;Notes:Initialize()
 T.eq(Notes.db.invalidRecords,nil,"nil notes storage is a normal first installation")
 local record={name="既有玩家",server="晨风号角",timestamp=100,reason="保留",classSpec="",type="neutral"}
 local records={["既有玩家-晨风号角"]=record};local valid={schema=3,records=records}
 _G.LycheeGroupNotesDB=valid;Notes.db=nil;Notes:Initialize()
 T.eq(Notes.db,valid);T.eq(Notes.db.records,records);T.eq(Notes:Find("既有玩家-晨风号角"),record)
 T.eq(Notes.db.invalidRecords,nil)
 Notes:Remove("既有玩家-晨风号角")
 _G.LycheeGroupNotesDB=previous;Notes.db=nil;Notes:Initialize()
end

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
 local calls=0
 local function Changed() calls=calls+1 end
 local oldStop=Notes:Subscribe(Changed)
 oldStop()
 local newStop=Notes:Subscribe(Changed)
 oldStop();oldStop()
 Notes:Add("RepeatedSubscription","Away","first")
 T.eq(calls,1,"an old cancellation cannot remove a new Notes subscription")
 newStop();newStop()
 Notes:Edit("RepeatedSubscription-Away","second")
 T.eq(calls,1,"cancellation remains safe to repeat")
 Notes:Remove("RepeatedSubscription-Away")
end

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

do
	-- JSON 合法的超大指数在 Lua 中成为 infinity，存储边界应保留未知时间语义。
	Load.file("addon/LycheeGroup_UI/Transfer.lua")
	local decoded = A.UI.Transfer.Decode("LN-W3sibmFtZSI6Ik90aGVyIiwic2VydmVyIjoiQXdheSIsInRpbWVzdGFtcCI6MWU5OTksInJlYXNvbiI6IngifV0=")
	T.eq(type(decoded), "table", "超大指数文本可到达实际导入边界")
	local changed, invalid = Notes:Merge(decoded)
	T.eq(changed, 1);T.eq(invalid, 0)
	T.eq(Notes:Find("Other-Away").timestamp, 0, "无穷导入时间规范为未知0")
	changed = Notes:Merge({{name="Other",server="Away",timestamp=100,reason="正常更新"}})
	T.eq(changed, 1, "正常后续导入可更新超大指数记录")
	T.eq(Notes:Find("Other-Away").reason, "正常更新")
	Notes:Remove("Other-Away")
	for index, timestamp in ipairs({math.huge, -math.huge, 0/0, 1e100, 1e308}) do
		local name = "异常时间" .. index
		changed, invalid = Notes:Merge({{name=name,server="Away",timestamp=timestamp}})
		T.eq(changed, 1);T.eq(invalid, 0)
		T.eq(Notes:Find(name.."-Away").timestamp, 0, "NaN和正负无穷都不进入存档")
		Notes.db.records[name.."-Away"].timestamp = timestamp
		T.eq(Notes:Merge({{name=name,server="Away",timestamp=0}}), 0, "未知时间不会覆盖本地内容")
		T.eq(Notes:Find(name.."-Away").timestamp, 0, "合并比较到的坏本地时间也被原位修复")
		changed = Notes:Merge({{name=name,server="Away",timestamp=10}})
		T.eq(changed, 1, "已存在的异常时间不能阻止正常记录合并")
		Notes:Remove(name.."-Away")
	end
end

-- ---------------------------------------------------------------- 入队提醒

local function RosterCount()
	return #Stubs.ChatMessages()
end

do
	-- 自己进入已有队伍必须检查现有成员,重复入组/花名册事件不刷屏。
	Notes:Add("危险人", "晨风号角", "划水", nil)
	A:SetSetting("notesEnabled",true)
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
	local before=RosterCount()
	Notes:Add("重逢甲","晨风号角","甲记录",nil)
	Notes:Add("重逢乙","晨风号角","乙记录",nil)
	local first={name="重逢甲",realm="晨风号角",guid="P-return-A"}
	local second={name="重逢乙",realm="晨风号角",guid="P-return-B"}
	Stubs.SetUnit("party1",first)
	Stubs.SetUnit("party2",{realm="晨风号角",guid="P-unresolved"})
	Stubs.FireEvent("GROUP_JOINED")
	T.eq(RosterCount(),before+1)
	Stubs.SetUnit("party1",second);Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	Stubs.SetUnit("party1",first);Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(),before+3,"另有未知成员时，已离队的玩家重入仍重新提醒")
	Stubs.SetUnit("party1",{realm="晨风号角",guid="P-return-A"});Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	Stubs.SetUnit("party1",first);Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(),before+3,"当前GUID的名字短暂不可读不重复提醒")
	local secret=newproxy(true);getmetatable(secret).__tostring=function() error("受限身份不能被转换") end
	local oldIsSecret=issecretvalue
	issecretvalue=function(value) return rawequal(value,secret) end
	Stubs.SetUnit("party1",{name=secret,realm="晨风号角",guid=secret});Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	Stubs.SetUnit("party1",first);Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	issecretvalue=oldIsSecret
	T.eq(RosterCount(),before+3,"身份暂时全部受限后恢复，不重复提醒当前成员")
	for index=1,200 do
		Stubs.SetUnit("party1",{name="临时成员"..index,realm="晨风号角",guid="P-transient-"..index})
		Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	end
	Stubs.SetUnit("party1",first);Stubs.FireEvent("GROUP_ROSTER_UPDATE")
	T.eq(RosterCount(),before+4,"连续换人后重逢仍提醒")
	local function Upvalue(fn,wanted)
		for index=1,30 do local name,value=debug.getupvalue(fn,index);if not name then break end;if name==wanted then return value end end
	end
	local onRoster=assert(Upvalue(Stubs.FramesWithEvent("GROUP_ROSTER_UPDATE")[1]:GetScript("OnEvent"),"OnRosterUpdate"))
	local function RetainedMembers()
		local count=0;for _ in pairs(assert(Upvalue(onRoster,"members"))) do count=count+1 end;return count
	end
	T.ok(RetainedMembers()<=3,"提醒缓存规模受当前三人队约束，不累积离队历史")
	Stubs.FireEvent("GROUP_LEFT");T.eq(RetainedMembers(),0,"退组释放当前身份缓存")
	Stubs.FireEvent("GROUP_JOINED");Notes.RosterReminder.Stop()
	T.eq(RetainedMembers(),0,"停用释放当前身份缓存")
	Stubs.SetUnit("party1",nil);Stubs.SetUnit("party2",nil)
	Notes:Remove("重逢甲-晨风号角");Notes:Remove("重逢乙-晨风号角")
end

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
	A.Group={Public=function(value) return value end,Notify=function() end,History={OnSpecUpdate=function() end},Game={RefreshApplicationSubscriptions=function() end}}
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

-- 存档装载异常只隔离损坏项；受支持 schema 保留同一份正常记录。
do
	local function InitializeFixture(raw)
		Notes.RosterReminder.Stop()
		Notes.db = nil
		_G.LycheeGroupNotesDB = raw
		local ok, err = pcall(Notes.Initialize, Notes)
		T.ok(ok, "缺失或异常存档不会让Notes装载失败: " .. tostring(err))
		T.eq(Notes.db, raw, "保留存档根表")
		T.eq(type(raw.records), "table", "初始化总是写回可用的records容器")
		T.eq(raw.schema, 3)
	end
	for _, schema in ipairs({2, 3}) do
		for _, container in ipairs({false, "损坏容器", 42}) do
			local raw = {schema=schema, records=container}
			InitializeFixture(raw)
			T.eq(next(raw.records), nil)
			T.eq(A.db.notesHasRecords, false)
			T.eq(raw.invalidRecords[1].value, container, "原坏容器保留供恢复")
		end
		InitializeFixture({schema=schema})
		T.eq(A.db.notesHasRecords, false, "缺失记录容器按空名单恢复")
		local good = {name="完好",server="Away",timestamp=21,reason="  原文保留  ",classSpec="旧专精",type="positive",class="WARRIOR",specID=71}
		local bad = {name={}, reason="坏身份原文"}
		local records = {["完好-Away"]=good, ["损坏行"]=false, ["坏身份"]=bad}
		local raw = {schema=schema,records=records}
		InitializeFixture(raw)
		T.eq(raw.records, records, "已支持schema不复制有效记录表")
		T.eq(Notes:Find("完好-Away"), good, "有效记录保留原引用")
		T.eq(good.timestamp, 21);T.eq(good.reason, "  原文保留  ");T.eq(good.classSpec, "旧专精")
		T.eq(good.type, "positive");T.eq(good.class, "WARRIOR");T.eq(good.specID, 71)
		T.eq(#Notes:List(), 1, "非表行与无效身份不进入查询服务")
		T.eq(#raw.invalidRecords, 2, "损坏项单独隔离")
		local preserved = {};for _, item in ipairs(raw.invalidRecords) do preserved[item.key] = item.value end
		T.eq(preserved["损坏行"], false);T.eq(preserved["坏身份"], bad)
	end
	for _, schema in ipairs({1, 2, 3}) do
		local records = {}
		for index, timestamp in ipairs({math.huge, -math.huge, 0/0, 1e100, 1e308}) do
			local name = "迁移时间" .. index
			records[name.."-Away"] = {name=name,server="Away",timestamp=timestamp,reason="历史",classSpec=""}
		end
		records["正常-Away"] = {name="正常",server="Away",timestamp=123,reason="正常历史",classSpec="职业原文"}
		local raw = {schema=schema,records=records}
		InitializeFixture(raw)
		T.eq(#Notes:List(), 6, "各schema修复时间时保留所有正常身份")
		T.eq(Notes:Find("正常-Away").timestamp,123);T.eq(Notes:Find("正常-Away").classSpec,"职业原文")
		for index=1,5 do
			local name = "迁移时间" .. index
			T.eq(Notes:Find(name.."-Away").timestamp, 0, "装载后UI只能取得规范时间")
			T.eq(Notes:Find(name.."-Away").type, "neutral", "旧schema缺少类型时迁移为中性")
			T.eq(Notes:Merge({{name=name,server="Away",timestamp=100,reason="恢复更新"}}), 1)
		end
	end
	local legacyBad = {name="",reason="无法匹配的旧原文"}
	local legacy = {schema=1,records={
		["旧身份-Away"]={timestamp=7,reason="旧理由",classSpec="旧专精"},
		alias={name="旧身份",server="Away",timestamp=math.huge,reason="不能胜过有效时间"},
		missing={name="缺时间",server="Away",reason="历史"},
		text={name="文本时间",server="Away",timestamp="100",reason="历史"},
		broken=false, badIdentity=legacyBad,
	}}
	InitializeFixture(legacy)
	T.eq(#Notes:List(),3,"旧schema迁移有效项，隔离非法行")
	T.eq(Notes:Find("旧身份-Away").timestamp,7,"无穷时间不能在旧schema去重中压过正常时间")
	T.eq(Notes:Find("旧身份-Away").reason,"旧理由")
	T.eq(Notes:Find("旧身份-Away").classSpec,"旧专精")
	T.eq(Notes:Find("缺时间-Away").timestamp,0)
	T.eq(Notes:Find("文本时间-Away").timestamp,0,"非数字旧时间继续保持未知语义")
	T.eq(#legacy.invalidRecords,2,"旧schema原坏值同样保留")
	local migratedRecords=legacy.records
	Notes:Initialize()
	T.eq(legacy.records,migratedRecords,"同次会话重复初始化不重做迁移")
	InitializeFixture({})
	T.eq(A.db.notesHasRecords, false)
end
GetInspectSpecialization = oldInspectGlobal

-- Finite JSON numbers can still lie outside the native date formatter's range.
do
	local fixture=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true})
	local notes,ui=fixture.A.Notes,fixture.U
	local text=assert(ui.Transfer.Encode({{name="Other",server="Away",timestamp=1e100,reason="Imported"}}))
	local decoded=assert(ui.Transfer.Decode(text))
	T.eq(decoded[1].timestamp,1e100,"finite oversized time reaches the real LN import boundary")
	T.eq(notes:Merge(decoded),1)
	local ok,err=pcall(function() fixture.A:Open("notes") end)
	T.ok(ok,"the real notes page opens after importing oversized time: "..tostring(err))
	T.eq(notes:Find("Other-Away").timestamp,0)
	T.eq(notes:Merge({{name="Other",server="Away",timestamp=123,reason="Later valid record"}}),1)
	T.eq(notes:Find("Other-Away").timestamp,123,"ordinary early timestamps remain valid")
	ui:Hide(true)
	for i=1,8 do notes:Merge({{name="Sorted"..i,server="Away",timestamp=100+i}}) end
	local nativeDate,calls=date,0
	date=function(...) calls=calls+1;return nativeDate(...) end
	local listed=notes:List()
	date=nativeDate
	T.eq(#listed,9);T.eq(calls,0,"sorting validated records does not format dates")
end

-- Case-insensitive identity belongs to Notes; original Core/storage/display
-- keys stay usable by native members, note entry, LN imports and list actions.
do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{askReason=false,reduceMotion=true})
 local a,notes=f.A,f.A.Notes
 f.base.SetUnit("player",{name="Self",realm="SilverHand",class="WARRIOR",classID=1,guid="Player-self"})
 f.base.SetUnit("party1",{name="Alice",realm="SilverHand",class="MAGE",classID=8,guid="Player-alice"})
 dofile("addon/LycheeGroup/Entrypoints.lua")
 a:RecordPlayer("alice-SilverHand",nil,nil,"known-person")
 local record=notes:Find("alice-SilverHand")
 T.ok(record,"the note entry stores its requested player")
 local nativeKey=a:UnitIdentity("party1")
 local found,key=notes:Find(nativeKey)
 T.eq(found,record,"the entered lowercase spelling matches the actual native member")
 T.eq(key,"alice-SilverHand","lookup returns the stored key for follow-up actions")
 T.eq(a:PlayerKey("Alice","SilverHand"),"Alice-SilverHand","Core preserves public identity formatting")
 T.eq(a:RecordPlayer("self","silverhand",nil,"same player"),false,"case changes cannot record the current character")
 T.eq(notes:Find("self-silverhand"),nil)
 T.ok(notes:Edit(nativeKey,"edited through native identity"));T.eq(record.reason,"edited through native identity")
 a:Open("notes",{playerKey=nativeKey});local page=f.U.pages.notes
 T.eq(page.list.selectedKey,key,"opening native identity selects its actual stored row")
 page.eReason.box:UserType("UI edited");page.eSave:Fire("OnClick","LeftButton")
 T.eq(record.reason,"UI edited","the actual editor writes the resolved record")
 notes:Edit(key,"external edit")
 T.eq(page.eReason.box:GetText(),"external edit","stored-key notifications refresh the open editor")
 f.G.GetHistory=function() return {{id="recorded-run",members={{name="Alice",realm="SilverHand",class="MAGE"}}}} end
 page:SelectTab("history")
 local runRow=page.historyList.rows[1];runRow:Fire("OnMouseDown","LeftButton");runRow:Fire("OnClick","LeftButton")
 local memberRow=page.historyModal.list.rows[1];memberRow:Fire("OnMouseDown","LeftButton");memberRow:Fire("OnClick","LeftButton")
 T.eq(page.list.selectedKey,key,"history member navigation selects the resolved stored note")
 local added,updated=notes:Add("ALICE","SILVERHAND","updated spelling")
 T.ok(added);T.eq(updated.name,"alice");T.eq(updated.server,"SilverHand")
 T.eq(#notes:List(),1,"adding another spelling updates one logical identity")
 T.eq(notes:Find(nativeKey),updated)
 local events={};local unsubscribe=notes:Subscribe(function(kind,actual) events[#events+1]={kind,actual} end)
 local decoded=assert(f.U.Transfer.Decode(f.U.Transfer.Encode({
  {name="Alice",server="silverhand",timestamp=updated.timestamp,reason="same timestamp"},
  {name="ALICE",server="SILVERHAND",timestamp=updated.timestamp-1,reason="older"},
  {name="SELF",server="SilverHand",timestamp=updated.timestamp+100,reason="self import"},
 })))
 local changed,invalid=notes:Merge(decoded)
 T.eq(changed,0);T.eq(invalid,1,"LN import rejects the current character independent of casing")
 T.eq(#events,0);T.eq(#notes:List(),1)
 decoded={{name="Alice",server="silverhand",timestamp=updated.timestamp+1,reason="newer import"}}
 changed,invalid=notes:Merge(assert(f.U.Transfer.Decode(f.U.Transfer.Encode(decoded))))
 T.eq(changed,1);T.eq(invalid,0);T.eq(#notes:List(),1)
 T.eq(events[1][1],"merge");T.eq(events[1][2][1],key,"merge notifications carry the actual stored key")
 T.eq(notes:Find(nativeKey).name,"alice","newer imports preserve the original display identity")
 T.eq(notes:Merge(decoded),0,"reimporting another spelling is idempotent")
 T.ok(notes:Remove(nativeKey));T.eq(events[#events][2],key);T.eq(notes:Find(key),nil)
 unsubscribe();f.U:Hide(true)
end

do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true,reminders="off"})
 local a,notes,u=f.A,f.A.Notes,f.U
 f.base.SetUnit("player",{name="Self",realm="SilverHand",class="WARRIOR",classID=1,guid="Player-self"})
 local function Rebind(records)
  local raw={schema=3,records=records}
  _G.LycheeGroupNotesDB=raw;notes.db=nil;notes:Initialize()
  T.eq(notes.db.records,records,"case indexing preserves the original saved records table")
  T.eq(raw.invalidRecords,nil,"legacy casing collisions remain active records")
 end
 local upper={name="Alice",server="SilverHand",timestamp=100,reason="upper",classSpec="",type="neutral"}
 local lower={name="alice",server="SilverHand",timestamp=200,reason="lower",classSpec="",type="neutral"}
 local records={["Alice-SilverHand"]=upper,["alice-SilverHand"]=lower}
 Rebind(records)
 T.eq(notes:Find("Alice-SilverHand"),upper,"an exact legacy key remains independently accessible")
 T.eq(notes:Find("alice-SilverHand"),lower)
 local preferred,stored=notes:Find("ALICE-SILVERHAND")
 T.eq(preferred,lower,"a nonexact spelling selects the newest effective timestamp")
 T.eq(stored,"alice-SilverHand")
 local listed=notes:List();T.eq(#listed,2);T.eq(listed[1],"alice-SilverHand");T.eq(listed[2],"Alice-SilverHand")
 a:Open("notes");local page=u.pages.notes
 T.eq(#page.list.ids,2,"both legacy records remain visible in the real notes list")
 for _,key in ipairs(listed) do
  a:Open("notes",{playerKey=key});T.eq(page.list.selectedKey,key)
  page.eReason.box:UserType("edited "..key);page.eSave:Fire("OnClick","LeftButton")
  T.eq(records[key].reason,"edited "..key,"each exact list key edits only its original record")
 end
 local changed=notes:Merge({{name="Alice",server="SILVERHAND",timestamp=150,reason="between existing timestamps"}})
 T.eq(changed,0,"imports compare against the logical identity's newest record")
 local update={{name="ALICE",server="SILVERHAND",timestamp=300,reason="latest"}}
 T.eq(notes:Merge(update),1);T.eq(notes:Merge(update),0);T.eq(#notes:List(),2,"duplicate imports never create a third casing")
 T.eq(records["Alice-SilverHand"],upper,"updating the preferred alias preserves the other legacy record")
 T.eq(records["alice-SilverHand"].name,"alice");T.eq(records["alice-SilverHand"].reason,"latest")
 local added,latest=notes:Add("Alice","SilverHand","new local add")
 T.ok(added);T.eq(records["alice-SilverHand"],latest,"Add also targets the logical identity's preferred record")
 T.eq(latest.name,"alice");T.eq(records["Alice-SilverHand"],upper);T.eq(#notes:List(),2)
 u:Hide(true)
 local scans=0;local pairsOf=pairs
 _G.pairs=function(value) if value==records then scans=scans+1 end;return pairsOf(value) end
 for _=1,100 do notes:Find("ALICE-SILVERHAND");notes:Find("not-saved") end
 local removed=notes:Remove("alice-SilverHand")
 _G.pairs=pairsOf
 T.ok(removed);T.eq(scans,0,"point queries and collision removal do not scan the stored library")
 T.eq(records["Alice-SilverHand"],upper);T.eq(notes:Find("ALICE-SILVERHAND"),upper,"removing the preferred alias immediately exposes the surviving record")
 a:Open("notes",{playerKey="ALICE-SILVERHAND"});T.eq(page.list.selectedKey,"Alice-SilverHand")
 page.eDelete:Fire("OnClick","LeftButton")
 T.eq(notes:Find("Alice-SilverHand"),nil,"the actual editor removes its resolved surviving record")
 T.eq(#notes:List(),0)
 -- Deterministic ties and index rebinding cannot depend on table iteration order.
 upper.timestamp=200;lower.timestamp=200
 Rebind({["alice-SilverHand"]=lower,["Alice-SilverHand"]=upper})
 T.eq(notes:Find("ALICE-SILVERHAND"),upper,"equal timestamps use the actual key's ascending order")
 Rebind({});T.eq(notes:Find("ALICE-SILVERHAND"),nil,"binding a new store releases every old identity alias")
 notes:Add("Bob","Away","new bind");T.ok(notes:Find("BOB-AWAY"));T.eq(notes:Find("ALICE-SILVERHAND"),nil)
 u:Hide(true)
end

-- Legacy imports can contain many case variants of the same character. Measure
-- actual Initialize work, not only resulting data or individual helper calls.
do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reminders="off"})
 local notes=f.A.Notes
 local function InitializeVariants(count)
  local records={};local newest
  for index=0,count-1 do
   local letters={}
   for bit=0,6 do
    local letter=string.char(97+bit)
    letters[#letters+1]=math.floor(index/2^bit)%2==1 and letter:upper() or letter
   end
   local name=table.concat(letters)
   local record={name=name,server="Away",timestamp=100+index,reason="original "..index,classSpec="",type="neutral"}
   records[name.."-Away"]=record;newest=record
  end
  local raw={schema=3,records=records};_G.LycheeGroupNotesDB=raw;notes.db=nil
  local nativeDate,dateCalls=date,0
  date=function(...) dateCalls=dateCalls+1;return nativeDate(...) end
  local oldHook,oldMask,oldCount=debug.gethook()
  local instructions=0
  debug.sethook(function() instructions=instructions+100 end,"",100)
  local ok,err=pcall(notes.Initialize,notes)
  debug.sethook(oldHook,oldMask,oldCount);date=nativeDate
  T.ok(ok,"real initialization accepts the legacy case variants: "..tostring(err))
  T.eq(notes.db.records,records);T.eq(#notes:List(),count,"initialization preserves every original casing variant")
  for key,record in pairs(records) do T.eq(notes:Find(key),record,"exact legacy records remain independently addressable") end
  T.eq(notes:Find("ABCDEFG-AWAY"),newest,"nonexact lookup still selects the greatest effective timestamp")
  return instructions,dateCalls
 end
 local small,smallDates=InitializeVariants(64)
 local large,largeDates=InitializeVariants(128)
 T.ok(large<=small*2.3,"doubling valid legacy variants has linear initialization work: "..small.." -> "..large.." Lua instructions")
 T.eq(smallDates,64,"the initialization boundary validates each stored timestamp once")
 T.eq(largeDates,128,"collision indexing does not repeat date validation")
 print(("Notes case variants: 64=%d instructions/%d date checks; 128=%d/%d"):format(small,smallDates,large,largeDates))
 local ordered=notes:List();local second=notes:Find(ordered[2])
 T.ok(notes:Remove("ABCDEFG-AWAY"))
 T.eq(notes:Find("ABCDEFG-AWAY"),second,"removing a large bucket's preferred key selects its next newest record")
 local newest=notes:Find(ordered[2])
 local added,updated=notes:Add(newest.name,newest.server,"updated existing collision")
 T.ok(added);T.eq(notes:Find("ABCDEFG-AWAY"),updated)
 T.eq(#notes:List(),127,"updating an existing key cannot append it to the collision bucket again")
 T.ok(notes:Remove("ABCDEFG-AWAY"));T.eq(notes:Find("ABCDEFG-AWAY"),notes:Find(ordered[3]),"removal after an existing-key update leaves the next original record accessible")
 _G.LycheeGroupNotesDB={schema=3,records={}};notes.db=nil;notes:Initialize()
 T.eq(notes:Find("ABCDEFG-AWAY"),nil,"rebinding releases the prior collision index")
end

-- Native UTF-8 folding is preferred; absent or nonreturning native APIs retain
-- deterministic ASCII matching without changing saved/display spellings.
for _,mode in ipairs({"absent","nil","error","utf8"}) do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reminders="off"})
 local notes=f.A.Notes;local native=C_Intl;local calls=0
 if mode=="absent" then C_Intl=nil
 else C_Intl={FoldCase=function(key)
  calls=calls+1
  if mode=="nil" then return nil end
  if mode=="error" then error("native unavailable") end
  return key:lower():gsub("Ä","ä")
 end} end
 local name=mode=="utf8" and "Älice" or "Alice"
 local query=mode=="utf8" and "äLICE-SILVERHAND" or "ALICE-SILVERHAND"
 local ok,record=notes:Add(name,"SilverHand","folded")
 T.ok(ok);T.eq(notes:Find(query),record,"identity folding works with native mode "..mode)
 T.eq(record.name,name,"folding preserves display name in mode "..mode)
 if mode~="absent" then T.ok(calls>0,"the native fold boundary is exercised") end
 C_Intl=native
end

_G.LycheeGroupDB = nil
_G.LycheeGroupNotesDB = nil
_G.LycheeGroup = nil
