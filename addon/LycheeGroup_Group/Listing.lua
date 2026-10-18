-- 当前招募:快照来自原生 LfgEntryData;发布/更新/下架以 API 返回值与事件共同确认。
-- 标题与说明由引擎读取界面接入的原生受保护 EditBox,不作为 Lua 字符串提交。
local A = _G.LycheeGroup
local G = A.Group
local L = A.GroupLocale
local Listing = {}
G.Listing = Listing
local snapshot

local function NormalizeEntry()
	if not C_LFGList.HasActiveEntryInfo() then return nil end
	local data = C_LFGList.GetActiveEntryInfo()
	-- An active entry can be waiting for its refreshed details; only native
	-- inactive state ends the last confirmed listing.
	if type(data) ~= "table" then return snapshot end
	local activityID = type(data.activityIDs) == "table" and data.activityIDs[1] or nil
	local activityName
	if activityID then
		local activity = C_LFGList.GetActivityInfoTable(activityID)
		activityName = activity and activity.fullName or nil
	end
	return {
		activityID = activityID,
		activityIDs = data.activityIDs,
		activityName = activityName,
		name = data.name,
		comment = data.comment,
		requiredItemLevel = data.requiredItemLevel,
		requiredDungeonScore = data.requiredDungeonScore,
		requiredPvpRating = data.requiredPvpRating,
		autoAccept = data.autoAccept,
		privateGroup = data.privateGroup,
		questID = data.questID,
		playstyle = data.playstyle,
		generalPlaystyle = data.generalPlaystyle,
		isCrossFactionListing = data.isCrossFactionListing,
		newPlayerFriendly = data.newPlayerFriendly,
	}
end

-- data = {activityID, requiredItemLevel, requiredDungeonScore, isAutoAccept, isPrivateGroup,
--         isCrossFactionListing, newPlayerFriendly, playstyle, generalPlaystyle, questID}
local function BuildCreateData(data, current)
	local function Value(key, currentKey)
		if data[key] ~= nil then return data[key] end
		return current and current[currentKey or key] or nil
	end
	return {
		activityIDs = current and current.activityID == data.activityID and current.activityIDs or { data.activityID },
		questID = Value("questID"),
		isAutoAccept = Value("isAutoAccept", "autoAccept"),
		isCrossFactionListing = Value("isCrossFactionListing"),
		isPrivateGroup = Value("isPrivateGroup", "privateGroup"),
		newPlayerFriendly = Value("newPlayerFriendly"),
		playstyle = Value("playstyle"),
		generalPlaystyle = Value("generalPlaystyle"),
		requiredDungeonScore = Value("requiredDungeonScore"),
		requiredItemLevel = Value("requiredItemLevel"),
		requiredPvpRating = Value("requiredPvpRating"),
	}
end

-- CreateListing → success bool;false 时给本地化错误,不假装成功。
local function Create(createData)
	local ok, created = pcall(C_LFGList.CreateListing, createData)
	return ok and created and true or false
end

function Listing:Publish(data)
	local allowed, reason = G:CanManageListing()
	if not allowed then return false, reason end
	if type(data) ~= "table" or not data.activityID then
		return false, L.invalidActivity
	end
	if not Create(BuildCreateData(data)) then
		if select(2, C_LFGList.GetNumApplications()) > 0 then
			return false, L.publishApplications
		end
		return false, L.publishFailed
	end
	snapshot = NormalizeEntry()
	G.Game:RefreshSubscriptions()
	G:Notify("listing")
	return true
end

function Listing:Update(data)
	local allowed, reason = G:CanManageListing()
	if not allowed then return false, reason end
	if type(data) ~= "table" or not data.activityID then
		return false, L.invalidActivity
	end
	local current = snapshot
	if not current then
		return false, L.noActiveListing
	end
	local createData = BuildCreateData(data, current)
	local success
	if data.isCrossFactionListing ~= nil and current.isCrossFactionListing ~= nil
		and data.isCrossFactionListing ~= current.isCrossFactionListing then
		-- 跨阵营变更不能原地更新:先下架再创建,同一调用链内完成以保持合法时序。
		pcall(C_LFGList.RemoveListing)
		success = Create(createData)
	else
		local ok, updated = pcall(C_LFGList.UpdateListing, createData)
		success = ok and updated and true or false
	end
	if not success then
		return false, L.updateFailed
	end
	snapshot = NormalizeEntry()
	G.Game:RefreshSubscriptions()
	G:Notify("listing")
	return true
end

function Listing:RemoveListing()
	local allowed, reason = G:CanManageListing()
	if not allowed then return false, reason end
	if not C_LFGList.HasActiveEntryInfo() then
		return false, L.noActiveListing
	end
	local ok = pcall(C_LFGList.RemoveListing)
	if not ok then
		return false, L.removeFailed
	end
	snapshot = NormalizeEntry()
	G.Game:RefreshSubscriptions()
	G:Notify("listing")
	return true
end

-- LFG_LIST_ACTIVE_ENTRY_UPDATE also confirms asynchronous listing edits.
function Listing:OnEntryUpdate()
	snapshot = NormalizeEntry()
	G.Game:RefreshSubscriptions()
	G:Notify("listing")
end

function Listing:Restore()
	snapshot = NormalizeEntry()
	G.Game:RefreshSubscriptions()
end

-- 同一事件快照供可见页面、悬浮窗共用，不在每次渲染时重建。
function Listing:GetListing()
	return snapshot
end
