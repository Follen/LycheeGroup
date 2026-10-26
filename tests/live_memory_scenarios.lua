-- Supplementary memory scenarios. Real page/modal lifetimes plus isolated
-- preview data and transfer-codec inputs; no application, listing or note writes.
local probe=...
local A=_G.LycheeGroup
local ui,g=A and A.UI,A and A.Group
if not ui or not g or not A.Notes or ui:IsShown() or ui.hiding or ui.preview then return probe:Fail("requires_warmed_closed_ui") end
local function Idle() return not InCombatLockdown() and not C_ChallengeMode.IsChallengeModeActive() and not C_LFGList.HasActiveEntryInfo() and #C_LFGList.GetApplications()==0 end
if not Idle() then return probe:Fail("requires_idle_business") end
local nativeDraft,hasNativeDraft={},false
if LFGListFrame and LFGListFrame.EntryCreation then
 for _,box in ipairs({LFGListFrame.EntryCreation.Name,LFGListFrame.EntryCreation.Description.EditBox}) do
  local value=box:GetText()
  if issecretvalue and issecretvalue(value) then return probe:Fail("native_creation_draft_unavailable") end
  nativeDraft[#nativeDraft+1]={box=box,text=value};hasNativeDraft=hasNativeDraft or value~=""
 end
end
local packages={"LycheeGroup","LycheeGroup_Group","LycheeGroup_Notes","LycheeGroup_UI","LycheeGroup_Guide"}
local started=GetTime()
local report={schema="lycheegroup.memory-scenarios.v1",packages=packages,units="KB",samples={},peaks={},checks={},fixture={},codec={},operations={pageOpen=0,pageClose=0,transferOpen=0,raidScroll=0,raidTips=0,applicantScroll=0,applicantRefresh=0,applicantTips=0},
 scenario={pageCycles=12,previewGroups=100,previewMembersPerGroup=40,previewApplicants=50,previewMembersPerApplication=5,codecRecords=1000,codecRounds=3,
  gcPolicy="natural until final closed sample; separate collection after all work",
  fixtureScope="private preview data; tests rendering, not native data acquisition; fixture generation heap recorded separately",
  input="page/list/tooltip controllers; synthetic codec records are never merged into saved notes"},peakBytes=0}
for i=1,300 do
 local row={addonKB={},loaded={}};report.samples[i]=row
 for packageIndex=1,#packages do row.addonKB[packageIndex],row.loaded[packageIndex]=0,false end
end
local used,ticker,eventFrame,cleaned=0
local oldPage,oldReturn=ui.page,ui.settingsReturnPage
local oldShown,originalFrames={},{}
for key,p in pairs(ui.pages) do oldShown[key]=p.frame and p.frame:IsShown() or false;originalFrames[key]=p.frame end
local find,create,notes=ui.pages.find,ui.pages.create,ui.pages.notes
local originalFindPool,originalBatchPool=#find.results.rows,#create.batchPool
report.fixture.initialFindPool,report.fixture.initialBatchPool=originalFindPool,originalBatchPool
local function NoteCount() local n=0;for _ in pairs(A.Notes.db.records) do n=n+1 end;return n end
report.notesAtStart=NoteCount()
local provider,records,encoded,decoded
local function Cleanup()
 if cleaned then return end;cleaned=true
 if ticker then ticker:Cancel();ticker=nil end
 if eventFrame then eventFrame:UnregisterAllEvents();eventFrame:SetScript("OnEvent",nil);eventFrame:Hide() end
 ui:Hide(true);ui.Motion:StopAll()
 provider,records,encoded,decoded=nil,nil,nil,nil
 for key,p in pairs(ui.pages) do if p.frame then p.frame:SetShown(oldShown[key]==true) end end
 ui.page,ui.settingsReturnPage=oldPage,oldReturn
 ui:UpdateNav();ui.Motion:FinishRect(ui.underline)
end
assert(probe:Async(110));assert(probe:OnCleanup(Cleanup))
assert(probe:Guard(Idle,{"PLAYER_REGEN_DISABLED","CHALLENGE_MODE_START","LFG_LIST_ACTIVE_ENTRY_UPDATE","LFG_LIST_APPLICATION_STATUS_UPDATED"},"scene_or_business_changed"))
local phase="page_lifetimes"
local function Sample(tag,collect)
 used=used+1;local row=assert(report.samples[used],"sample_capacity")
 row.tag,row.phase,row.atSeconds=tag,phase,GetTime()-started
 row.gcMs=0;if collect then local t=debugprofilestop();collectgarbage("collect");row.gcMs=debugprofilestop()-t end
 row.luaHeapKB=collectgarbage("count")
 local t=debugprofilestop();UpdateAddOnMemoryUsage();row.counterRefreshMs=debugprofilestop()-t
 local total=0
 for i,name in ipairs(packages) do local _,loaded=C_AddOns.IsAddOnLoaded(name);row.loaded[i]=loaded==true;row.addonKB[i]=GetAddOnMemoryUsage(name);total=total+row.addonKB[i] end
 row.addonTotalKB=total
 if not collect then report.peakBytes=math.max(report.peakBytes,total*1024);report.peaks[phase]=math.max(report.peaks[phase] or 0,total*1024) end
 return row
end
Sample("before")
local pages=hasNativeDraft and {"settings","notes"} or {"settings","notes","create"}
report.scenario.pages=pages;report.scenario.skippedNativeCreation=hasNativeDraft
local step,nextAt,phaseAt,lastSample=0,GetTime(),GetTime(),GetTime()
local raidActivity
local function Copy(value) local result={};for k,v in pairs(value) do result[k]=v end;return result end
local function BeginRaidPreview()
 local ok,err=ui:StartPreview("applications");if not ok then error(err) end
 provider=ui.preview.provider
 for _,a in ipairs(g.Catalog:GetActivities("seasonRaid")) do if a.difficultyID==15 then raidActivity=a;break end end
 assert(raidActivity,"raid_activity_missing")
 local template=provider.records[provider.recordIDs[1]]
 local memberTemplates={template.details.members[1],template.details.members[2],provider.roster[3]}
 local heap=collectgarbage("count")
 wipe(provider.records);wipe(provider.recordIDs);wipe(provider.apps)
 for i=1,100 do
  local r=Copy(template);r.id=-10000-i;r.name="模拟团本队伍 "..i;r.comment="40人成员界面容量测试；本地模拟数据。"
  r.activity=raidActivity;r.activityID=raidActivity.id;r.activityName=raidActivity.name;r.categoryID=3;r.numMembers=40;r.maxNumPlayers=40
  r.details={members={},counts={TANK=2,HEALER=8,DAMAGER=30}}
  for j=1,40 do
   local m=Copy(memberTemplates[(j-1)%3+1]);m.name="模拟成员"..i.."号"..j;m.nameKey=m.name.."-模拟服务器";m.realm="模拟服务器"
   m.assignedRole=j<=2 and "TANK" or j<=10 and "HEALER" or "DAMAGER";m.isLeader=j==1;m.dungeonScore=2200+j*7
   r.details.members[j]=m
  end
  r.leaderName=r.details.members[1].nameKey;r.leaderKey=r.leaderName
  provider.records[r.id]=r;provider.recordIDs[i]=r.id
 end
 report.fixture.raidGenerationHeapDeltaKB=collectgarbage("count")-heap
 provider.category="seasonRaid";provider.activity=raidActivity;provider.Search.categoryKey="seasonRaid"
 provider.prefs.find={category="seasonRaid"};find.loaded=nil;find.restoredInitial=nil
 find:Enter();find:SelectCategory("seasonRaid");find:CommitChoice();find:DoSearch()
 report.fixture.visiblePreviewResults=#provider:GetResults();assert(report.fixture.visiblePreviewResults==100,"preview_results_filtered")
 report.fixture.boundPreviewResults=#find.results.ids
 assert(report.fixture.boundPreviewResults==100,"preview_results_not_bound")
 report.checks.raidResultsVisible=not find.emptyPanel:IsShown() and find.results.rows[1].key~=nil
 assert(report.checks.raidResultsVisible,"preview_results_not_visible")
 -- Keep the first binding separate from the first complete scroll traversal:
 -- partially visible edge rows can legitimately expand the pool during scrolling.
 originalFindPool=#find.results.rows;report.fixture.findPoolAtFirstBind=originalFindPool
 report.fixture.raidFirstKey=find.results.rows[1].key
 report.fixture.raidMaximumObservedOffset=0;report.checks.raidFirstRowChanged=false
 phase="preview_100_groups_40_members";phaseAt=GetTime();step=0;Sample("preview_ready")
end
local function BeginApplicants()
 ui:StopPreview(false);provider=nil
 assert(ui:StartPreview("applicants"));provider=ui.preview.provider
 local template=provider.applicants[2];local members=template.members
 local heap=collectgarbage("count")
 wipe(provider.applicants);wipe(provider.applicantIDs)
 for i=1,50 do
  local app={id=i,status="applied",displayOrderID=i,comment="模拟五人同行申请 "..i,members={}}
  for j=1,5 do local m=Copy(members[(j-1)%2+1]);m.name="模拟申请"..i.."号"..j;m.nameKey=m.name.."-模拟服务器";app.members[j]=m end
  provider.applicants[i]=app;provider.applicantIDs[i]=i
 end
 report.fixture.applicantGenerationHeapDeltaKB=collectgarbage("count")-heap
 create:RefreshApplicants();originalBatchPool=#create.batchPool;report.fixture.batchPoolAtFirstBind=originalBatchPool
 phase="preview_50_applicant_batches";phaseAt=GetTime();step=0;Sample("applicants_ready")
end
local function BeginCodec()
 ui:StopPreview(false);provider=nil;phase="notes_codec_1000";phaseAt=GetTime();step=0
 local heap=collectgarbage("count");records={}
 local reason=string.rep("这是用于内存测试的模拟记录，不写入玩家数据。",3)
 for i=1,1000 do records[i]={name="测试玩家"..i,server="模拟服务器",reason=reason..i,timestamp=1700000000+i,classSpec="测试专精",type=i%2==0 and "positive" or "caution",class="MAGE",specID=64} end
 report.fixture.codecGenerationHeapDeltaKB=collectgarbage("count")-heap;report.fixture.reasonBytes=#reason
 Sample("codec_input_ready")
end
local function Finish()
 Cleanup();phase="closed";Sample("closed_final");report.retainedKB=Sample("closed_after_diagnostic_gc",true).addonTotalKB
 report.checks.pageFramesReused=true
 for key,frame in pairs(originalFrames) do if ui.pages[key].frame~=frame then report.checks.pageFramesReused=false end end
 report.checks.poolsReused=report.fixture.findPoolAfterFirstTraversal~=nil and report.fixture.batchPoolAfterFirstTraversal~=nil and #find.results.rows==originalFindPool and #create.batchPool==originalBatchPool
 report.checks.notesUnchanged=NoteCount()==report.notesAtStart
 report.checks.nativeDraftPreserved=true
 if hasNativeDraft then for _,saved in ipairs(nativeDraft) do
  local current=saved.box:GetText()
  if issecretvalue and issecretvalue(current) or current~=saved.text then report.checks.nativeDraftPreserved=false end
 end end
 report.checks.knownOwnersIdle=not ui:IsShown() and not ui.preview and not g:HasViews() and not g.Results.updatePending and g.Game.frame:GetScript("OnUpdate")==nil and not g.Search.timer and not g.Search.pending and next(ui.Motion.jobs)==nil
 report.checks.allPackagesLoaded=true
 for i,name in ipairs(packages) do
  if name~="LycheeGroup_Guide" and not report.samples[used].loaded[i] then report.checks.allPackagesLoaded=false end
 end
 report.checks.under20MB=report.peakBytes<=20000000
 report.ok=report.checks.pageFramesReused and report.checks.poolsReused and report.checks.notesUnchanged and report.checks.nativeDraftPreserved and report.checks.knownOwnersIdle and report.checks.allPackagesLoaded and report.checks.under20MB and report.checks.raidResultsVisible and report.checks.raidScrolled and report.checks.raidFirstRowChanged
 report.elapsedSeconds,report.sampleCount=GetTime()-started,used
 for i=used+1,#report.samples do report.samples[i]=nil end
 return probe:Finish(report)
end
local function Tick()
 if probe:IsCancelled() then return end
 local now=GetTime();if now-started>105 then return probe:Fail("scenario_deadline") end
 if now-lastSample>=.5 then Sample("periodic");lastSample=GetTime() end
 if now<nextAt then return end
 step=step+1
 if phase=="page_lifetimes" then
  if step%2==1 then
   local index=math.floor((step-1)/2);local key=pages[index%#pages+1]
   assert(A:Open(key));report.operations.pageOpen=report.operations.pageOpen+1
   if key=="notes" then
    if math.floor(index/#pages)%2==0 then notes:DoExport() else notes:OpenTransfer("import") end
    report.operations.transferOpen=report.operations.transferOpen+1
   end
   Sample("page_open_"..key)
  else ui:Hide();report.operations.pageClose=report.operations.pageClose+1 end
  if step==12*#pages*2 then ui:Hide(true);BeginRaidPreview() end
  nextAt=GetTime()+.3
 elseif phase=="preview_100_groups_40_members" then
  local list=find.results
  -- Observe the previous animated request after the intervening frame ticks.
  if step==41 then originalFindPool=#list.rows;report.fixture.findPoolAfterFirstTraversal=originalFindPool end
  report.fixture.raidMaximumObservedOffset=math.max(report.fixture.raidMaximumObservedOffset,list.pixelOffset)
  if list.rows[1].key and list.rows[1].key~=report.fixture.raidFirstKey then report.checks.raidFirstRowChanged=true end
  local maximum=math.max(0,(#list.ids-1)*list.rowHeight+list.rows[1]:GetHeight()-list:GetHeight())
  local fraction=step%40/20;if fraction>1 then fraction=2-fraction end
  list:SetPixelOffset(maximum*fraction,true);report.operations.raidScroll=report.operations.raidScroll+1
  if step%2==0 then
   local tip=ui.Tooltip;local id=provider.recordIDs[(step-1)%100+1]
   tip:Hide();tip:ShowGroup(list.rows[1],provider.records[id]);tip.expanded=true;tip:RenderGroup();report.operations.raidTips=report.operations.raidTips+1
  end
  if now-phaseAt>=20 and step>=81 then
   report.checks.raidScrolled=report.fixture.raidMaximumObservedOffset>0
   assert(report.checks.raidScrolled and report.checks.raidFirstRowChanged,"preview_results_did_not_scroll")
   BeginApplicants()
  end
  nextAt=GetTime()+.15
 elseif phase=="preview_50_applicant_batches" then
  if step==41 then originalBatchPool=#create.batchPool;report.fixture.batchPoolAfterFirstTraversal=originalBatchPool end
  if step%4==0 then create:RefreshApplicants();report.operations.applicantRefresh=report.operations.applicantRefresh+1 end
  local maximum=math.max(0,create.batchBody:GetHeight()-create.batchScroll:GetHeight())
  local fraction=step%40/20;if fraction>1 then fraction=2-fraction end
  create:SetBatchOffset(maximum*fraction,true);report.operations.applicantScroll=report.operations.applicantScroll+1
  if step%2==0 then ui.Tooltip:Hide();ui.Tooltip:ShowApplicants(create.manage,provider:GetApplicant(provider.applicantIDs[(step-1)%#provider.applicantIDs+1]));report.operations.applicantTips=report.operations.applicantTips+1 end
  if now-phaseAt>=20 and step>=81 then BeginCodec() end
  nextAt=GetTime()+.15
 elseif phase=="notes_codec_1000" then
  local t=debugprofilestop();encoded=ui.Transfer.Encode(records)
  report.codec[step]={encodeMs=debugprofilestop()-t,encodedBytes=#encoded};Sample("encoded_"..step)
  t=debugprofilestop();decoded=assert(ui.Transfer.Decode(encoded));report.codec[step].decodeMs=debugprofilestop()-t
  assert(#decoded==1000,"codec_count")
  for i=1,1000 do assert(decoded[i].name==records[i].name and decoded[i].reason==records[i].reason,"codec_roundtrip") end
  Sample("decoded_"..step);encoded,decoded=nil,nil
  if step==3 then Finish() end
  nextAt=GetTime()+.5
 end
end
eventFrame=CreateFrame("Frame");eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eventFrame:SetScript("OnEvent",assert(probe:Callback(function() probe:Fail("world_changed") end)))
ticker=C_Timer.NewTicker(.1,assert(probe:Callback(Tick)))
