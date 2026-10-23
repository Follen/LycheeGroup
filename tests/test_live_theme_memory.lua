-- Probe lifecycle checks with the product UI fixture; fake counters are not performance evidence.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
local function Copy(value)
 if type(value)~="table" then return value end
 local result={};for key,item in pairs(value) do result[key]=Copy(item) end;return result
end
local function Same(a,b)
 if type(a)~="table" or type(b)~="table" then return a==b end
 for key,value in pairs(a) do if not Same(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end
 return true
end
for _,mode in ipairs({"complete","cancel","observer_error","search_timeout","search_complete","warm_cancel","warm_complete","warm_observer_error","warm_open_failure"}) do
 local f=dofile("tests/live_probe_fixture.lua")()
 local A,U,G=f.A,f.U,f.G
 local searching=mode:match("^search_")~=nil
 if not searching then G.listing={activityID=2} end
 A.Floating:Bind(G);A.Floating:UpdateSettings()
 G.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}},filters={sort="rating",maxMembers=4,selected=true,difficultyID=8}}
 G.Search:SetFilters({sort="rating",maxMembers=4})
 if searching then
  G.Public=function(value) return value end
  if mode=="search_timeout" then
   local originalCount=G.GetResultCount
   function G:GetResultCount() return f.now<10 and originalCount(self) or 0 end
  end
 end
 if mode:match("^warm_") then A:Open("create");A:Open("settings");U:Hide(true) end
 if mode=="warm_complete" then A.Floating:ShowPanel();Check(A.Floating.panel:IsShown(),"floating initially expanded") end
 local floatingShown=A.Floating.panel and A.Floating.panel:IsShown() or false
 local oldPage,oldReturn,oldShown=U.page,U.settingsReturnPage,{}
 for key,page in pairs(U.pages) do oldShown[key]=page.frame and page.frame:IsShown() or false end
 local oldPrefs,oldPrefsValue=G.prefs.find,Copy(G.prefs.find)
 if mode=="observer_error" or mode=="warm_observer_error" then f.failRead=12 end
 getmetatable(UIParent).Click=function(self) self:Fire("OnClick","LeftButton") end
 local savedFont,savedMotion=A:GetSetting("fontScale"),A:GetSetting("reduceMotion")
 local open=A.Open
 if mode=="warm_open_failure" then
  A.Open=function(self,page,...)
   local result=open(self,page,...)
   if page=="create" then error("simulated open failure") end
   return result
  end
 end
 local probe=f:Start("tests/live_theme_memory.lua")
 A.Open=open
 for tick=1,115 do
  if (mode=="cancel" and tick==15) or (mode=="warm_cancel" and tick==12) then probe:Close() end
  f:Advance(1)
  if not probe.active then break end
 end
 Check(not probe.active,mode.." bounded completion")
 if mode=="complete" or mode=="search_complete" or mode=="warm_complete" then
  Check(probe.result~=nil,tostring(probe.error))
  Check(probe.result.fontChanges==12 and probe.result.nativeClicks==57,"full operation sequence")
  Check(probe.result.accountUnchanged and probe.result.characterUnchanged and probe.result.sessionRestored,"stores restored")
  Check(probe.result.resourcesReleased and probe.result.listingUnchanged,"resources and business preserved")
  if searching then Check(#probe.result.cycles==12 and probe.result.cycles[12].visible>0,"all twelve cycles include rendered search results") end
 elseif mode=="search_timeout" then
  Check(probe.error=="cycle_search_results_unavailable",tostring(probe.error))
 elseif mode=="observer_error" or mode=="warm_observer_error" then
  Check(probe.error and probe.error:find("simulated observer failure",1,true),tostring(probe.error))
 elseif mode=="warm_open_failure" then Check(probe.error and probe.error:find("simulated open failure",1,true),tostring(probe.error))
 else Check(probe.result==nil,"cancellation must not report completion") end
 Check(A:GetSetting("fontScale")==savedFont and A:GetSetting("reduceMotion")==savedMotion,mode.." live preferences restored")
 Check(G.prefs.find==oldPrefs and Same(G.prefs.find,oldPrefsValue),mode.." role filter preferences restored without mutating their source")
 local filters=G.Search:GetFilters()
 Check(filters.sort=="rating" and filters.maxMembers==4 and filters.category==nil,mode.." runtime filters restored")
 Check(not U:IsShown() and not U.Native.searchLease and U.Motion:Count()==0,mode.." UI owners released")
 Check(searching and not G:GetListing() or G:GetListing() and G:GetListing().activityID==2,mode.." listing retained")
 if mode:match("^warm_") then
  Check((A.Floating.panel and A.Floating.panel:IsShown() or false)==floatingShown,mode.." floating visibility restored")
  Check(U.page==oldPage and U.settingsReturnPage==oldReturn,"hidden route restored")
  for key,page in pairs(U.pages) do Check((page.frame and page.frame:IsShown() or false)==oldShown[key],"hidden page frame restored: "..key) end
  Check(U._nav==oldPage and U.settingsButton.active,"hidden navigation presentation restored")
  A:Open(oldPage)
  for key,page in pairs(U.pages) do if page.frame then Check(page.frame:IsVisible()==(key==oldPage),"reopen displays only the original page: "..key) end end
  U:Hide(true)
 end
 local finalReads=f.reads
 for tick=1,3 do f:Advance(1) end
 Check(f.reads==finalReads,mode.." late callbacks inactive")
end
print("Theme memory probe lifecycle: "..checks.." checks passed")
