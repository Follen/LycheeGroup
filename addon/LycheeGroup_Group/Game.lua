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
	"PLAYER_ENTERING_WORLD",
	"ZONE_CHANGED_NEW_AREA",
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
local ROSTER_EVENTS = { "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "INSPECT_READY", "PLAYER_REGEN_ENABLED", "UNIT_CONNECTION" }

local RUN_EVENTS = {
	"CHALLENGE_MODE_COMPLETED",
	"CHALLENGE_MODE_RESET",
}

local function SetEvents(frame, events, enabled)
	local update = enabled and frame.RegisterEvent or frame.UnregisterEvent
	for _, event in ipairs(events) do update(frame, event) end
end
local function HasListing()
 local ok,active=pcall(C_LFGList.HasActiveEntryInfo)
 if ok then active=G.Public(active) else active=nil end
 if type(active)=="boolean" then return active end
 return G.Listing:GetListing()~=nil
end

local function RestrictionState(state)
 state=G.Public(state)
 local states=Enum and Enum.AddOnRestrictionState
 if not states then return nil end
 if states.Inactive~=nil and state==states.Inactive then return false end
 if states.Activating~=nil and state==states.Activating or states.Active~=nil and state==states.Active then return true end
end
function Game:IsLfgPaused()
 if self.chatRestricted~=nil then return self.chatRestricted end
 local chat=Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Chat
 local reader=C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState
 if chat~=nil and reader then
  local ok,state=pcall(reader,chat)
  if ok then
   local restricted=RestrictionState(state)
   if restricted~=nil then return restricted end
  end
 end
 reader=C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
 if not reader then return false end
 local ok,locked=pcall(reader)
 return not ok or G.Public(locked)~=false
end
function Game:OnRestrictionChanged(kind,state)
 local chat=Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Chat
 if chat==nil or G.Public(kind)~=chat then return end
 local restricted=RestrictionState(state)
 if restricted==nil then return end
 self.chatRestricted=restricted
 G.Alerts:Sync()
end
function Game:Init()
	if self.frame then return end
	local frame = CreateFrame("Frame")
	self.frame = frame
	frame:SetScript("OnEvent", function(_, event, ...) G:OnEvent(event, ...) end)
	SetEvents(frame, WAKE_EVENTS, true)
	-- Older clients may not expose this event; their LFG/world edges still read
	-- the chat gate directly. Ordinary combat is not a speech restriction.
	pcall(frame.RegisterEvent,frame,"ADDON_RESTRICTION_STATE_CHANGED")
end

function Game:RefreshApplicationSubscriptions()
	local frame = self.frame
	local applications = G.Applications:GetActiveCount()>0
	if G:HasViews("search") or G.Search:GetState()=="searching" or applications then
		frame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
	else frame:UnregisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED") end
	local listing = HasListing()
	local autoJoin = A:GetSetting("autoJoin") and applications
	SetEvents(frame, PERMISSION_EVENTS, listing or G:HasViews("create") or autoJoin)
	if self.runTracking or G:HasViews() or listing or autoJoin then frame:RegisterEvent("GROUP_ROSTER_UPDATE") else frame:UnregisterEvent("GROUP_ROSTER_UPDATE") end
end

function Game:RefreshSubscriptions()
	local frame = self.frame
	if not frame then return end
	local browsing = G:HasViews("search") or G.Search:GetState()=="searching"
	SetEvents(frame, SEARCH_EVENTS, browsing)
	self:RefreshApplicationSubscriptions()
	local listing = HasListing()
	self:RefreshRelations()
	SetEvents(frame, APPLICANT_EVENTS, listing)
	SetEvents(frame, ROSTER_EVENTS, G:HasViews("create"))
	if G:HasViews("search") then frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED") end
	G.Roster:SetActive(G:HasViews("create"))
end

function Game:RefreshRelations()
 local active=G:HasViews("create") or HasListing()
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
