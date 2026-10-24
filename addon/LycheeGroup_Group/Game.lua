-- 最小唤醒常驻;浏览、申请者与秘境过程事件由实际消费者启停。
local A = _G.LycheeGroup
local G = A.Group
local Game = {}
G.Game = Game

local WAKE_EVENTS = {
	"LFG_LIST_APPLICATION_STATUS_UPDATED",
	"LFG_LIST_ACTIVE_ENTRY_UPDATE",
	"CHALLENGE_MODE_START",
	-- Keep the session catalog current even while all browser windows are closed.
	"LFG_LIST_AVAILABILITY_UPDATE",
}

local SEARCH_EVENTS = {
	"LFG_LIST_SEARCH_RESULTS_RECEIVED",
	"LFG_LIST_UPDATE_SEARCH_RESULTS",
	"LFG_LIST_SEARCH_FAILED",
}

local APPLICANT_EVENTS = {
	"LFG_LIST_APPLICANT_LIST_UPDATED",
	"LFG_LIST_APPLICANT_UPDATED",
}

local PERMISSION_EVENTS = { "PARTY_LEADER_CHANGED" }
local RELATION_EVENTS = {
 "FRIENDLIST_UPDATE", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_INFO_CHANGED",
 "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_DISCONNECTED",
 "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CLUB_ADDED", "CLUB_MEMBER_ADDED",
 "CLUB_MEMBER_REMOVED", "CLUB_MEMBER_UPDATED", "CLUB_MEMBERS_UPDATED",
}
local ROSTER_EVENTS = { "PLAYER_ROLES_ASSIGNED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "INSPECT_READY", "PLAYER_REGEN_ENABLED", "UNIT_CONNECTION" }

local RUN_EVENTS = {
	"CHALLENGE_MODE_COMPLETED",
	"CHALLENGE_MODE_RESET",
	"PLAYER_ENTERING_WORLD",
}

local function SetEvents(frame, events, enabled)
	local update = enabled and frame.RegisterEvent or frame.UnregisterEvent
	for _, event in ipairs(events) do update(frame, event) end
end

function Game:Init()
	if self.frame then return end
	local frame = CreateFrame("Frame")
	self.frame = frame
	frame:SetScript("OnEvent", function(_, event, ...) G:OnEvent(event, ...) end)
	SetEvents(frame, WAKE_EVENTS, true)
end

function Game:RefreshApplicationSubscriptions()
	local frame = self.frame
	local applications = G.Applications:GetActiveCount()>0
	if G:HasViews("search") or G.Search:GetState()=="searching" or applications then
		frame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
	else frame:UnregisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED") end
	local listing = C_LFGList.HasActiveEntryInfo()
	local autoJoin = A:GetSetting("autoJoin") and applications
	SetEvents(frame, PERMISSION_EVENTS, listing or G:HasViews("create") or autoJoin)
	if self.runTracking or G:HasViews() or listing or autoJoin or G.Roster:NeedsRosterEvents() then frame:RegisterEvent("GROUP_ROSTER_UPDATE") else frame:UnregisterEvent("GROUP_ROSTER_UPDATE") end
end

function Game:RefreshSubscriptions()
	local frame = self.frame
	if not frame then return end
	local browsing = G:HasViews("search") or G.Search:GetState()=="searching"
	SetEvents(frame, SEARCH_EVENTS, browsing)
	self:RefreshApplicationSubscriptions()
	local listing = C_LFGList.HasActiveEntryInfo()
	self:RefreshRelations()
	SetEvents(frame, APPLICANT_EVENTS, listing)
	SetEvents(frame, ROSTER_EVENTS, G:HasViews("create"))
	if G:HasViews("search") then frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED") end
	G.Roster:SetActive(G:HasViews("create"))
end

function Game:RefreshRelations()
 local active=G:HasViews("create") or C_LFGList.HasActiveEntryInfo()
 if G.Relations.active==active then return end
 SetEvents(self.frame,RELATION_EVENTS,active)
 G.Relations:SetActive(active)
end

function Game:EnableRunTracking()
	if self.runTracking then return end
	self.runTracking = true
	SetEvents(self.frame, RUN_EVENTS, true)
	self:RefreshSubscriptions()
end

function Game:DisableRunTracking()
	if not self.runTracking then return end
	self.runTracking = false
	SetEvents(self.frame, RUN_EVENTS, false)
	self:RefreshSubscriptions()
end
