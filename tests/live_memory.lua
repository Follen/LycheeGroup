-- LycheeDev probe: product and shared-UI memory with bounded UI lifetimes.
-- Requires a closed, idle Lychee Group UI, no combat/LFG/challenge business,
-- and no unsaved native creation draft. Opening find uses its normal search;
-- the probe does not submit applications, publish listings or change user data.
local probe = ...
local A = _G.LycheeGroup
if not A or not A.db then return probe:Fail("lycheegroup_not_ready") end
if not UpdateAddOnMemoryUsage or not GetAddOnMemoryUsage then return probe:Fail("memory_api_unavailable") end
if InCombatLockdown() then return probe:Fail("combat_active") end

local PACKAGES = { "LycheeGroup", "LycheeGroup_Group", "LycheeGroup_Notes", "LycheeGroup_UI" }
local PAGES = { "settings", "notes", "find", "create" }
local SETTLE, ROUNDS, LIMIT = 1.90, 5, 110
local oldUI, oldPage, oldReturn = A.UI, A.UI and A.UI.page, A.UI and A.UI.settingsReturnPage
local oldPageShown = {}
if oldUI and (oldUI:IsShown() or oldUI.hiding) then return probe:Fail("close_ui_before_test") end
if oldUI and oldUI.Motion and next(oldUI.Motion.jobs) then return probe:Fail("wait_for_animations") end

local function HasBusiness()
  return C_LFGList.HasActiveEntryInfo() or #C_LFGList.GetApplications() > 0
    or C_ChallengeMode.IsChallengeModeActive()
end
if HasBusiness() then return probe:Fail("active_group_business") end

-- Opening the creation page uses the real protected inputs. Never erase a
-- player's existing draft to make the measurement repeatable.
if LFGListFrame and LFGListFrame.EntryCreation then
  local entry = LFGListFrame.EntryCreation
  for _, box in ipairs({ entry.Name, entry.Description.EditBox }) do
    local text = box:GetText()
    if issecretvalue and issecretvalue(text) then return probe:Fail("native_draft_unavailable") end
    if text ~= "" then return probe:Fail("native_creation_draft_present") end
  end
end

local setupHeap = collectgarbage("count")
local started = GetTime()
local version, build, date, interface = GetBuildInfo()
local report = {
  schema = "lycheegroup.memory.v1", units = "KB", packages = PACKAGES,
  client = { version = version, build = build, date = date, interface = interface },
  settings = { reduceMotion = A:GetSetting("reduceMotion"), notesEnabled = A:GetSetting("notesEnabled"),
    notesHasRecords = A.db.notesHasRecords, scriptProfile = GetCVar("scriptProfile") },
  scenario = { settleSeconds = SETTLE, naturalWarmRounds = ROUNDS, retainedWarmRounds = ROUNDS,
    asyncLimitSeconds = LIMIT, explicitGCPolicy = "collect_only; never stop/restart/change GC settings" },
  loadedAtStart = {}, pageBuiltAtStart = {}, samples = {}, checks = {},
  observer = { preallocatedSamples = 32, wrappedCallbacks = 2, periodicDrivers = 1 },
}
for i, name in ipairs(PACKAGES) do
  local _, loaded = C_AddOns.IsAddOnLoaded(name)
  report.loadedAtStart[i] = loaded == true
end
report.coreOnlyAtStart = report.loadedAtStart[1] == true
for i = 2, #PACKAGES do
  if report.loadedAtStart[i] then report.coreOnlyAtStart = false; break end
end
report.businessPagesUnloadedAtStart = not report.loadedAtStart[2]
  and not report.loadedAtStart[3] and not report.loadedAtStart[4]
for _, page in ipairs(PAGES) do
  local p = oldUI and oldUI.pages[page]
  report.pageBuiltAtStart[page] = p and p.frame ~= nil or false
  oldPageShown[page] = p and p.frame and p.frame:IsShown() or false
end

-- Keep report storage constant through the measurements; do not allocate a new
-- frame/timer/closure for each round. Observer and whole-heap bytes are not
-- subtracted from, or attributed to, the addon counters.
for i = 1, 32 do
  local sample = { addonKB = {}, loaded = {} }
  for packageIndex = 1, #PACKAGES do
    sample.addonKB[packageIndex], sample.loaded[packageIndex] = 0, false
  end
  report.samples[i] = sample
end
local used = 0
local ticker, eventFrame, cleaned, touched
local group, oldFindPrefs, oldFindFilters
local function Copy(value)
  if type(value) ~= "table" then return value end
  local result = {}; for key, item in pairs(value) do result[key] = Copy(item) end; return result
end
local function SaveFind()
  if group then return end
  assert(A:Ensure("Group")); group = A.Group
  oldFindPrefs, oldFindFilters = group.prefs.find, Copy(group.Search:GetFilters())
  group.prefs.find = Copy(oldFindPrefs)
  A.UI.pages.find.loaded, A.UI.pages.find.restoredInitial = nil, nil
end
local function Cleanup()
  if cleaned then return end
  cleaned = true
  if ticker then ticker:Cancel(); ticker = nil end
  if eventFrame then
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    eventFrame:SetScript("OnUpdate", nil)
    eventFrame:Hide()
  end
  local ui = A.UI
  if touched and ui then
    ui:Hide(true) -- closes only this experiment's UI, preserving real business
    if ui.Motion then ui.Motion:StopAll() end
    if group then
      group.Search:SetFilters(oldFindFilters); group.prefs.find = oldFindPrefs
      ui.pages.find.loaded, ui.pages.find.restoredInitial = nil, nil
    end
    -- Restore hidden navigation without Enter(), which would subscribe a page
    -- while the parent window is closed. Loaded addons cannot be unloaded.
    for _, page in ipairs(PAGES) do
      local p = ui.pages[page]
      if p and p.frame then p.frame:SetShown(oldPageShown[page]) end
    end
    ui.page, ui.settingsReturnPage = oldPage, oldReturn
    ui:UpdateNav(); ui.Motion:FinishRect(ui.underline)
  end
end
assert(probe:Async(LIMIT))
assert(probe:OnCleanup(Cleanup))
assert(probe:Guard(function() return not InCombatLockdown() end,
  { "PLAYER_REGEN_DISABLED" }, "combat_started"))

local function Sample(tag, mode, round, page)
  used = used + 1
  local row = assert(report.samples[used], "sample_limit")
  row.tag, row.mode, row.round, row.page = tag, mode, round, page
  row.atSeconds = GetTime() - started
  row.gcMs = 0
  if mode == "after_gc" then
    local gcStart = debugprofilestop()
    collectgarbage("collect")
    row.gcMs = debugprofilestop() - gcStart
  end
  row.luaHeapKB = collectgarbage("count")
  local refreshStart = debugprofilestop()
  UpdateAddOnMemoryUsage()
  row.counterRefreshMs = debugprofilestop() - refreshStart
  local total = 0
  for i, name in ipairs(PACKAGES) do
    local _, loaded = C_AddOns.IsAddOnLoaded(name)
    row.loaded[i] = loaded == true
    row.addonKB[i] = GetAddOnMemoryUsage(name)
    total = total + row.addonKB[i]
  end
  row.addonTotalKB = total
  row.luaHeapAfterRefreshKB = collectgarbage("count")
end

local EVENTS = {
  "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED",
  "LFG_LIST_UPDATE_SEARCH_RESULTS", "LFG_LIST_SEARCH_FAILED",
  "LFG_LIST_APPLICANT_LIST_UPDATED", "LFG_LIST_APPLICANT_UPDATED",
  "GROUP_ROSTER_UPDATE", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "PLAYER_ENTERING_WORLD",
}
local function ObserveClosedOwners()
  local ui, g = A.UI, A.Group
  local m = ui and ui.Motion
  local jobs = 0
  if m then for _ in pairs(m.jobs) do jobs = jobs + 1 end end
  local state = { uiShown = ui and ui:IsShown() or false, uiHiding = ui and ui.hiding == true or false,
    motionJobs = jobs, motionOnUpdate = m and m.driver and m.driver:GetScript("OnUpdate") ~= nil or false,
    applicationCountdown = ui and ui.pages.find.countdown ~= nil or false,
    rosterTimer = g and (g.Roster.timer ~= nil or g.Roster.refreshTimer ~= nil) or false,
    nativeInputBorrowed = ui and ui.Native and ui.Native.owner ~= nil or false,
    groupViews = g and g:HasViews() or false, results = g and g:GetResultCount() or 0,
    applications = g and #g:GetApplications() or 0, applicants = g and g.Applicants:GetCount() or 0,
    activeListing = C_LFGList.HasActiveEntryInfo(), activeChallenge = C_ChallengeMode.IsChallengeModeActive(),
    searchState = g and g:GetSearchState() or "unloaded", extraGroupEvents = {},
    catalogUpdatesSubscribed = g and g.Game.frame:IsEventRegistered("LFG_LIST_AVAILABILITY_UPDATE") or false,
    expectedNotesReminder = A:GetSetting("notesEnabled") and A.db.notesHasRecords,
  }
  local frame = g and g.Game.frame
  for _, event in ipairs(EVENTS) do
    if frame and frame:IsEventRegistered(event) then state.extraGroupEvents[#state.extraGroupEvents + 1] = event end
  end
  state.knownOwnersIdle = not state.uiShown and not state.uiHiding and jobs == 0 and not state.motionOnUpdate and not state.applicationCountdown and not state.rosterTimer
    and not state.nativeInputBorrowed and not state.groupViews and state.results == 0 and state.applications == 0
    and state.applicants == 0 and not state.activeListing and not state.activeChallenge and #state.extraGroupEvents == 0
  return state
end

local function Open(page)
  if HasBusiness() then return probe:Fail("group_business_started") end
  touched = true
  if page == "find" then SaveFind() end
  local ok, err = A:Open(page)
  if not ok then error("open_" .. page .. ": " .. tostring(err)) end
end

-- One event callback aborts on a real scene change; no real application,
-- listing, invite or ongoing challenge is modified to make the test pass.
eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", assert(probe:Callback(function(_, event)
  if event == "PLAYER_LEAVING_WORLD" or HasBusiness() then probe:Fail("scene_changed_" .. event) end
end)))
for _, event in ipairs({ "PLAYER_LEAVING_WORLD", "LFG_LIST_APPLICATION_STATUS_UPDATED",
  "LFG_LIST_ACTIVE_ENTRY_UPDATE", "CHALLENGE_MODE_START" }) do eventFrame:RegisterEvent(event) end

report.observer.setupHeapDeltaKB = collectgarbage("count") - setupHeap
Sample("start", "natural")
Sample("start", "after_gc")
report.initialClosedOwners = ObserveClosedOwners()

local phase, index, nextAt = "first_open", 1, GetTime() + 0.1
local function Tick()
  if probe:IsCancelled() or GetTime() < nextAt then return end
  local page = PAGES[(index - 1) % #PAGES + 1]
  if phase == "first_open" then
    Open(page); phase = "first_sample"
  elseif phase == "first_sample" then
    Sample("first_observed_open", "natural", index, page)
    A.UI:Hide(); phase = "first_closed"
  elseif phase == "first_closed" then
    Sample("first_observed_closed", "natural", index, page)
    index = index + 1
    if index <= #PAGES then phase = "first_open" else
      Sample("warmed_closed_baseline", "after_gc")
      phase, index = "natural_open", 1
    end
  elseif phase == "natural_open" or phase == "retained_open" then
    Open(page); phase = phase == "natural_open" and "natural_hide" or "retained_hide"
  elseif phase == "natural_hide" or phase == "retained_hide" then
    A.UI:Hide(); phase = phase == "natural_hide" and "natural_closed" or "retained_closed"
  elseif phase == "natural_closed" then
    Sample("warm_closed", "natural", index, page)
    index = index + 1
    if index <= ROUNDS then phase = "natural_open" else
      Sample("natural_phase_retained", "after_gc")
      phase, index = "retained_open", 1
    end
  elseif phase == "retained_closed" then
    Sample("warm_closed", "natural", index, page)
    Sample("warm_closed", "after_gc", index, page)
    index = index + 1
    if index <= ROUNDS then phase = "retained_open" else phase = "finish" end
  elseif phase == "finish" then
    Sample("final_closed", "natural")
    Sample("final_closed", "after_gc")
    report.closedOwnersBeforeCleanup = ObserveClosedOwners()
    -- Build the readable delta only after the last measurement. Keep raw
    -- samples and negative deltas; neither a threshold nor a leak verdict.
    local baselineIndex
    for i = 1, used do
      if report.samples[i].tag == "warmed_closed_baseline" then baselineIndex = i; break end
    end
    local baseline, final = report.samples[baselineIndex], report.samples[used]
    report.summary = {
      baselineTag = baseline.tag, baselineSample = baselineIndex,
      finalTag = final.tag, finalSample = used, mode = "after_gc",
      addonDeltaKB = {}, addonTotalDeltaKB = final.addonTotalKB - baseline.addonTotalKB,
      wholeClientLuaHeapDeltaKB = final.luaHeapKB - baseline.luaHeapKB,
    }
    for i = 1, #PACKAGES do report.summary.addonDeltaKB[i] = final.addonKB[i] - baseline.addonKB[i] end
    Cleanup()
    report.closedOwnersAfterCleanup = ObserveClosedOwners()
    report.checks.knownOwnersIdleBeforeCleanup = report.closedOwnersBeforeCleanup.knownOwnersIdle
    report.checks.probeResourcesReleased = ticker == nil and eventFrame:GetScript("OnEvent") == nil
      and eventFrame:GetScript("OnUpdate") == nil
    report.checks.originalHiddenPageRestored = not A.UI:IsShown() and A.UI.page == oldPage and A.UI.settingsReturnPage == oldReturn
    report.loadedAtEnd = {}
    for i, name in ipairs(PACKAGES) do local _, loaded = C_AddOns.IsAddOnLoaded(name); report.loadedAtEnd[i] = loaded == true end
    report.elapsedSeconds, report.sampleCount = GetTime() - started, used
    for i = used + 1, #report.samples do report.samples[i] = nil end
    return probe:Finish(report)
  end
  -- Both open and close boundaries receive a full quiet interval. No sample is
  -- taken during the 420ms presence or 1.386s logo animation.
  nextAt = GetTime() + SETTLE
end
ticker = C_Timer.NewTicker(0.1, assert(probe:Callback(Tick)))
