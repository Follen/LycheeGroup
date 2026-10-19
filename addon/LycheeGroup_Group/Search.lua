local A = _G.LycheeGroup
local G,L = A.Group,A.GroupLocale
local Search={filters={},generation=0,state="idle"}
G.Search=Search
function Search:BindInput(lease) self.inputLease=lease end
function Search:ReleaseInput(expected)
 if self.inputLease==expected then self.inputLease=nil end
end
function Search:RequestActivities()
 -- Availability belongs to the session, not a page. Repeating this request
 -- broadcasts a global refresh to every loaded group browser.
 if self.activitiesRequested then return end
 self.activitiesRequested=true
 C_LFGList.RequestAvailableActivities()
end
function Search:GetActivities(key) return G.Catalog:GetActivities(key) end
function Search:OnAvailabilityUpdated()
 self.activitiesRequested=true
 G.Catalog:Invalidate();G:Notify("activities")
end
function Search:CancelTimer()
 if self.timer then self.timer:Cancel();self.timer=nil end
end
function Search:SchedulePending(delay)
 self.state="waiting"
 if not self.timer then
  self.timer=C_Timer.NewTimer(delay,function()
   self.timer=nil
   if not G:HasViews("search") then self:EndBrowse();return end
   local request=self.pending;self.pending=nil
   self:Submit(request)
  end)
 end
 G:Notify("search")
end
-- Only one native request runs at a time; each new selection replaces the pending one.
function Search:Search(categoryKey,activityID,mode,text)
 if not G.Catalog:GetCategory(categoryKey) then return false,L.invalidActivity end
 local lease=self.inputLease
 local revision=lease and lease.revision or 0
 mode=mode or "native"
 local request={categoryKey=categoryKey,activityID=activityID,revision=revision,lease=lease,mode=mode,text=text}
 if self.state=="searching" then
  self.abandoned=nil
  if self.request and self.request.categoryKey==categoryKey and self.request.activityID==activityID and self.request.revision==revision and self.request.lease==lease and self.request.mode==mode and self.request.text==text then
   self.pending=nil;self.error=nil
  else self.pending=request;self.error=L.searchQueued end
  G:Notify("search");return true
 elseif self.state=="waiting" then
  self.pending=request;G:Notify("search");return true
 end
 return self:Submit(request)
end
function Search:Submit(request)
 local categoryKey,activityID=request.categoryKey,request.activityID
 local category=G.Catalog:GetCategory(categoryKey)
 if not category then
  self.state,self.error,self.pending="failed",L.invalidActivity,nil;G:Notify("search")
  return false,self.error
 end
 local filter
 if activityID then filter={activityID}
 elseif category.season then
  filter={}
  for _,activity in ipairs(G.Catalog:GetActivities(categoryKey)) do filter[#filter+1]=activity.id end
  if #filter==0 then
   self.state,self.error,self.pending="failed",L.invalidActivity,nil;G:Notify("search")
   return false,self.error
  end
 end
 self.generation=self.generation+1
 self.request=request
 self.categoryKey,self.error,self.state,self.abandoned=categoryKey,nil,"searching",nil
 G.Results:BeginSearch(self.generation)
 local lease=self.inputLease
 if request.mode=="group" and (not lease or lease~=request.lease or lease.revision~=request.revision) then
  self.state,self.error,self.pending,self.request="failed",L.searchRestricted,nil,nil
  G.Results:FailSearch(self.generation);G:Notify("search");return false,self.error
 end
-- Group mode uses the native text field for group-name and optional M+ level
 -- matching. Leader mode searches the complete returned set locally by public
 -- leaderName; description text remains unavailable to Lua because it is kstring.
 if request.mode=="leader" or request.mode=="native" and not lease then C_LFGList.ClearSearchTextFields() end
 local language=C_LFGList.GetLanguageSearchFilter()
 local ok=pcall(C_LFGList.Search,category.id,G.Catalog:GetSearchFilter(category),0,language,nil,nil,filter)
 if not ok then
  self.state,self.error,self.pending="failed",L.searchRestricted,nil
  G.Results:FailSearch(self.generation)
 end
 G:Notify("search")
 return ok,not ok and self.error or nil
end
function Search:SetFilters(filters)
 wipe(self.filters)
 for key,value in pairs(filters) do self.filters[key]=value end
 if filters.notes and A.db.notesHasRecords then A:Ensure("Notes") end
 G.Results:InvalidateView();G:Notify("results")
end
function Search:OnResultsReceived()
 if self.state~="searching" then return end
 self.backoff=nil;self.error=nil
 if self.abandoned or not G:HasViews("search") then
  self.state,self.request="idle",nil;G.Game:RefreshSubscriptions();G:Notify("search");return
 end
 if self.pending then self:SchedulePending(0);return end
 self.state="done";G.Results:CommitResults(self.generation);G:Notify("search")
end
function Search:OnResultsUpdated()
 if not self.pending and G:HasViews("search") and (self.state=="searching" or self.state=="done") then G.Results:QueueUpdate() end
end
function Search:OnSearchFailed(reason)
 if self.state~="searching" then return end
 G.Results:FailSearch(self.generation)
 if self.abandoned or not G:HasViews("search") then
  self.state,self.error,self.request="idle",nil,nil
 elseif reason=="throttled" then
  -- The pinned native UI exposes failure events but no readable cooldown.
  -- This is a client backoff policy, not an assumed server cooldown duration.
  self.backoff=math.min((self.backoff or 2.5)*2,60)
  self.error=L.searchThrottled:format(self.backoff)
  self.pending=self.pending or self.request
  self:SchedulePending(self.backoff)
 else
  self.state,self.error,self.pending="failed",reason=="timeout" and L.searchTimeout or L.searchFailed,nil
 end
 G.Game:RefreshSubscriptions();G:Notify("search")
end
function Search:EndBrowse()
 -- The native owner releases its input; a category change only ends browsing.
 self:CancelTimer()
 self.pending,self.request,self.backoff=nil,nil,nil
 self.generation=self.generation+1;self.abandoned=true;self.error=nil
 if self.state~="searching" then self.state="idle" end
 G.Results:BeginSearch(self.generation);G:Notify("search")
end
function Search:GetState() return self.state end
function Search:GetGeneration() return self.generation end
function Search:GetSearchError() return self.error end
function Search:GetFilters() return self.filters end
