-- 仅实际记录请求才发起一次原生检视。最多一个待决请求与一个 5 秒超时;
-- 优先读取已加载 Group 持有的同步库缓存；不为笔记加载 Group。
-- 同步快照不发请求,完成/取消/超时后清理监听和计时器。
local A = _G.LycheeGroup
local Notes = A.Notes
local PlayerInfo = {}
Notes.PlayerInfo = PlayerInfo

local frame
local pending -- {unit, guid, callback, timer}

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

local function ResolveClass(classID, className, class, specID, text, selected)
	local textMatch
	for index = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
		local id, specName = GetSpecializationInfoForClassID(classID, index)
		local classSpec = className .. "-" .. specName
		if id == specID then return {class=class, specID=id, classSpec=classSpec} end
		if text == classSpec or text == className .. " · " .. specName then
			textMatch = {class=class, specID=id, classSpec=classSpec}
		end
	end
	if textMatch then return textMatch end
	if selected or text == className then return {class=class, classSpec=className} end
end

local function BuildClassSpec(unit, specID)
	local className, class, classID = UnitClass(unit)
	if IsSecret(className) or IsSecret(class) or IsSecret(classID) then return nil end
	if type(className) ~= "string" or className == "" or type(class) ~= "string" or type(classID) ~= "number" then return nil end
	if IsSecret(specID) or type(specID) ~= "number" or specID <= 0 then specID = nil end
	local details = ResolveClass(classID, className, class, specID, "", true)
	return details.specID and details.classSpec or nil, details
end

-- ResolveRecord(record) -> {class?, specID?, classSpec}。
-- 只解析记录本身的结构或本地化旧文字，不读取当前玩家，不改写历史存档。
function PlayerInfo.ResolveRecord(record)
	local text = type(record.classSpec) == "string" and record.classSpec or ""
	if record.class then
		for classID = 1, GetNumClasses() do
			local name, class = GetClassInfo(classID)
			if class == record.class then return ResolveClass(classID, name, class, record.specID, text, true) end
		end
	end
	for classID = 1, GetNumClasses() do
		local name, class = GetClassInfo(classID)
		if name then
			local details = ResolveClass(classID, name, class, record.specID, text)
			if details then return details end
		end
	end
	return {classSpec=text}
end

-- Snapshot(unit) -> "职业-专精" | nil, {class, specID?, classSpec} | nil。
-- 原生目录名已本地化，不缓存另一套职业目录；未知专精仍能返回可靠职业。
function PlayerInfo.Snapshot(unit)
	if type(unit) ~= "string" or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
	local roster = A.Group and A.Group.Roster
	local guid = UnitGUID(unit)
	if roster and not IsSecret(guid) and type(guid) == "string" then
		local specID = roster:GetCachedSpec(guid)
		if specID then
			local text, details = BuildClassSpec(unit, specID)
			if text then return text, details end
		end
	end
	return BuildClassSpec(unit, C_SpecializationInfo.GetInspectSpecialization(unit))
end

local function Finish(result, details)
	local request = pending
	if not request then return end
	pending = nil
	if request.timer then request.timer:Cancel() end
	frame:UnregisterEvent("INSPECT_READY")
	request.callback(result, details or request.details)
end

-- 返回 cancel() 或 nil(同步结束)。取消、新请求替换、超时均回调 nil 一次;
-- UI 如已取消表单,先使自己的编辑令牌失效再调用 cancel。
function PlayerInfo.Request(unit, callback)
	if type(callback) ~= "function" then return end
	if pending then Finish(nil) end
	if type(unit) ~= "string" or not UnitExists(unit) or not UnitIsPlayer(unit) then
		callback(nil)
		return
	end
	local sync, details = PlayerInfo.Snapshot(unit)
	if sync then
		callback(sync, details)
		return
	end
	local guid = UnitGUID(unit)
	if IsSecret(guid) or type(guid) ~= "string" or guid == "" then
		callback(nil)
		return
	end
	if not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, _, guidArg)
			if not pending or IsSecret(guidArg) or guidArg ~= pending.guid then return end
			local currentGUID = UnitGUID(pending.unit)
			if IsSecret(currentGUID) or currentGUID ~= pending.guid then
				Finish(nil)
				return
			end
			Finish(PlayerInfo.Snapshot(pending.unit))
		end)
	end
	local request = { unit = unit, guid = guid, callback = callback, details = details }
	pending = request
	frame:RegisterEvent("INSPECT_READY")
	local ok = pcall(NotifyInspect, unit)
	if not ok then
		Finish(nil)
		return
	end
	request.timer = C_Timer.NewTimer(5, function()
		if pending == request then Finish(nil) end
	end)
	return function()
		if pending == request then Finish(nil) end
	end
end
