-- Offline isolation: production Search/Results/Find, synthetic native replies.
-- No live client; GC stop is only used to count gross offline allocation.
local Fixture=dofile('tests/ui_fixture.lua')
local f=Fixture('enUS',nil,{reduceMotion=true});local A,G,U=f.A,f.G,f.U
local now,allocateNative=100,false
GetTime=function() return now end;GetTimePreciseSec=GetTime
local list,infos,players={},{},{}
local nativeCalls={info=0,member=0,counts=0,list=0};local nativeBytes=0
local setterCalls={point=0,samePoint=0,clear=0,size=0,sameSize=0}
local function Clone(v)
 if type(v)~='table' then return v end
 local out={};for key,item in pairs(v) do out[key]=Clone(item) end;return out
end
local function Reply(value)
 if not allocateNative then return value end
 local before=collectgarbage('count');local result=Clone(value);nativeBytes=nativeBytes+collectgarbage('count')-before;return result
end
for id=1,100 do
 list[id]=id
 infos[id]={activityIDs={2},name='Group '..id,comment='same full note',partyGUID='Party-'..id,leaderName='Leader'..id..'-Away',numMembers=5,age=id,requiredItemLevel=600,requiredDungeonScore=2000,leaderOverallDungeonScore=2700,numBNetFriends=0,numCharFriends=0,numGuildMates=0,isDelisted=false}
 players[id]={}
 for index=1,5 do players[id][index]={name=(index==1 and 'Leader' or 'Member'..index)..id..'-Away',classFilename='MAGE',className='Mage',specName='Frost',assignedRole='DAMAGER',isLeader=index==1,dungeonScore=2700} end
end
local counts={TANK=0,HEALER=0,DAMAGER=5,classesByRole={DAMAGER={MAGE=5}}}
C_LFGList.GetFilteredSearchResults=function() nativeCalls.list=nativeCalls.list+1;return #list,Reply(list) end
C_LFGList.GetSearchResultInfo=function(id) nativeCalls.info=nativeCalls.info+1;return Reply(infos[id]) end
C_LFGList.GetSearchResultPlayerInfo=function(id,index) nativeCalls.member=nativeCalls.member+1;return Reply(players[id][index]) end
C_LFGList.GetSearchResultMemberCounts=function() nativeCalls.counts=nativeCalls.counts+1;return Reply(counts) end
C_LFGList.GetSearchResultFriends=function() return nil,nil,nil end
C_LFGList.Search=function() end
C_LFGList.GetLanguageSearchFilter=function() return 0 end
G.Game={frame=CreateFrame('Frame'),RefreshSubscriptions=function() end}
function G:HasViews(kind) for _,value in pairs(self.views) do if not kind or value==kind then return true end end;return false end
function G:RemotePlayerKey(name) if name and name:find('-',1,true) then return A:PlayerKey(name) end end
G.Applications.AdoptResult=function() return false end
dofile('addon/LycheeGroup_Group/Results.lua');dofile('addon/LycheeGroup_Group/Search.lua')
function G:GetResults() return self.Results:GetResults() end
function G:GetResult(id) return self.Results:GetResult(id) end
function G:GetResultCount() return self.Results:GetCount() end
function G:GetResultDetails(id) return self.Results:GetDetails(id) end
function G:SetFilters(filters) return self.Search:SetFilters(filters) end
function G:GetSearchState() return self.Search:GetState() end
function G:GetSearchError() return self.Search:GetSearchError() end
local function ResetCounters() for key in pairs(nativeCalls) do nativeCalls[key]=0 end;nativeBytes=0 end
local function Measure(label,n,fn)
 fn(0);collectgarbage('collect');ResetCounters();for key in pairs(setterCalls) do setterCalls[key]=0 end;local before=collectgarbage('count');collectgarbage('stop')
 local started=os.clock();for i=1,n do fn(i) end;local ms=(os.clock()-started)*1000
 local gross=collectgarbage('count')-before
 collectgarbage('restart');collectgarbage('collect');local retained=collectgarbage('count')-before
 print(string.format('%s n=%d grossKiB=%.3f perKiB=%.3f nativeKiB=%.3f pluginKiB=%.3f retainedKiB=%.3f ms=%.3f info=%d member=%d counts=%d list=%d',label,n,gross,gross/n,nativeBytes,gross-nativeBytes,retained,ms,nativeCalls.info,nativeCalls.member,nativeCalls.counts,nativeCalls.list))
 if setterCalls.point>0 then print('SETTERS point='..setterCalls.point..' samePoint='..setterCalls.samePoint..' clear='..setterCalls.clear..' size='..setterCalls.size..' sameSize='..setterCalls.sameSize) end
end
-- First capture must own fresh API tables because Normalize legitimately reuses
-- its initial return. After this, all record updates preserve record identity.
allocateNative=true;G.Results:BeginSearch(1);G.Results:CommitResults(1);allocateNative=false
local baseFilters={category='seasonDungeon',sort='newest'}
G.Search:SetFilters(baseFilters)
Measure('service-bulk-shared-native',100,function() now=now+.2;G.Results:QueueUpdate();G.Game.frame:GetScript('OnUpdate')() end)
allocateNative=true
Measure('service-bulk-fresh-native',100,function() now=now+.2;G.Results:QueueUpdate();G.Game.frame:GetScript('OnUpdate')() end)
allocateNative=false
Measure('service-setfilters-shared-native',500,function() G.Search:SetFilters(baseFilters);assert(#G:GetResults()==100) end)
Measure('service-getresults-cache-hit',5000,function() assert(#G:GetResults()==100) end)
-- Native setter stand-ins allocate tables in the regular UI fixture. Replace
-- only their storage implementation, retaining values and callback semantics.
local N=getmetatable(U.frame or UIParent).__index
function N:ClearAllPoints() setterCalls.clear=setterCalls.clear+1;self.pointPool=self.pointPool or {};for i=#self.points,1,-1 do self.pointPool[i]=self.points[i];self.points[i]=nil end;self.allPoints=nil end
function N:SetPoint(a,b,c,d,e)
 local p;for _,old in ipairs(self.points) do if old[1]==a then p=old;break end end
 if not p then local i=#self.points+1;p=self.pointPool and self.pointPool[i] or {};self.points[i]=p end
 setterCalls.point=setterCalls.point+1
 if p[1]==a and p[2]==b and p[3]==c and p[4]==d and p[5]==e then setterCalls.samePoint=setterCalls.samePoint+1 end
 p[1],p[2],p[3],p[4],p[5]=a,b,c,d,e
end
function N:SetVertexColor(r,g,b,a) local v=self.vertex or {};self.vertex=v;v[1],v[2],v[3],v[4]=r,g,b,a or 1;self.alpha=a or 1 end
function N:SetTextColor(r,g,b,a) local v=self.color or {};self.color=v;v[1],v[2],v[3],v[4]=r,g,b,a or 1 end
function N:SetTexCoord(a,b,c,d) local v=self.texCoords or {};self.texCoords=v;v[1],v[2],v[3],v[4]=a,b,c,d end
function N:SetFont(a,b,c) local v=self.font or {};self.font=v;v[1],v[2],v[3]=a,b,c;return true end
function N:GetVertexColor() if self.vertex then return unpack(self.vertex) end;return 1,1,1,1 end
function N:GetTextColor() if self.color then return unpack(self.color) end;return 1,1,1,1 end
function N:GetTexCoord() if self.texCoords then return unpack(self.texCoords) end;return 0,1,0,1 end
function N:GetPoint(i) local p=self.points[i or 1];if p then return unpack(p) end end
local setSize=N.SetSize
function N:SetSize(w,h) setterCalls.size=setterCalls.size+1;if self.w==w and self.h==h then setterCalls.sameSize=setterCalls.sameSize+1 end;return setSize(self,w,h) end
local textWidth,textHeight=N.GetUnboundedStringWidth,N.GetStringHeight
local function TextMetric(self,key,original)
 local metric=self[key]
 local size=self.font and self.font[2]
 if metric and metric.text==self.text and metric.size==size and metric.width==self.w and metric.spacing==self.spacing and metric.wrap==self.wrap and metric.lines==self.maxLines then return metric.value end
 metric=metric or {};self[key]=metric
 metric.text,metric.size,metric.width,metric.spacing,metric.wrap,metric.lines=self.text,size,self.w,self.spacing,self.wrap,self.maxLines
 metric.value=original(self);return metric.value
end
function N:GetUnboundedStringWidth() return TextMetric(self,'offlineWidth',textWidth) end
function N:GetStringHeight() return TextMetric(self,'offlineHeight',textHeight) end
assert(A.Configuration:Set({[A.FindPreferences:Key('seasonDungeon','selected')]=true}))
allocateNative=true;A:Open('find');G.Search:OnResultsReceived();allocateNative=false;local page=U.pages.find
assert(G:GetResultCount()==100);assert(page.results.ids and #page.results.ids==100)
for _,row in ipairs(page.results.rows) do if row.key then G.Results:GetDetails(row.key) end end
Measure('ui-stable-refresh-shared-native',100,function() page:RefreshResults() end)
local apply=U.ApplyElementScope;U.ApplyElementScope=function() end
Measure('ui-stable-refresh-without-scopeapply',100,function() page:RefreshResults() end)
U.ApplyElementScope=apply
local function Upvalue(fn,name)
 for i=1,30 do local key,value=debug.getupvalue(fn,i);if not key then break end;if key==name then return i,value end end
 error('missing upvalue '..name)
end
local _,render=Upvalue(page.RefreshResults,'RenderResult');local layoutIndex,layout=Upvalue(render,'LayoutResultRow')
debug.setupvalue(render,layoutIndex,function() end)
Measure('ui-stable-refresh-without-rowlayout',100,function() page:RefreshResults() end)
debug.setupvalue(render,layoutIndex,layout)
Measure('ui-setfilters-shared-native',100,function() G.Search:SetFilters(baseFilters) end)
Measure('ui-bulk-shared-native',100,function() now=now+.2;G.Results:QueueUpdate();G.Game.frame:GetScript('OnUpdate')() end)
allocateNative=true
Measure('ui-bulk-fresh-native',100,function() now=now+.2;G.Results:QueueUpdate();G.Game.frame:GetScript('OnUpdate')() end)
allocateNative=false
Measure('ui-eight-dirty-shared-native',100,function(i)
 for id=1,8 do G.Results:QueueUpdate(id) end;G.Game.frame:GetScript('OnUpdate')();U.Motion:Tick(1)
end)
allocateNative=true
Measure('ui-eight-dirty-fresh-native',100,function(i)
 for id=1,8 do G.Results:QueueUpdate(id) end;G.Game.frame:GetScript('OnUpdate')();U.Motion:Tick(1)
end)
allocateNative=false
for i=0,8 do page.results:SetPixelOffset(i*64,false) end;page.results:SetPixelOffset(0,false)
local before=#f.S.nodes
Measure('ui-scroll-cache-shared-native',100,function(i) page.results:SetPixelOffset(i%8*64,false) end)
print('nodes-before='..before..' nodes-after='..#f.S.nodes..' rows='..#page.results.rows..' fullResults='..G:GetResultCount())
U:Hide(true)
