-- Focused reproduction of the 1,000-record codec allocation peak.
-- No saved data changes or GC intervention until all three rounds finish.
local probe=...
local A=_G.LycheeGroup
assert(A and A.UI and A.UI.Transfer and A.Notes and A.Group,"requires_all_business_packages_loaded")
assert(not A.UI:IsShown() and not A.UI.preview and not InCombatLockdown(),"requires_closed_idle_ui")
local packages={"LycheeGroup","LycheeGroup_Group","LycheeGroup_Notes","LycheeGroup_UI"}
local version,build,_,interface=GetBuildInfo()
local report={schema="lycheegroup.transfer-memory.v1",packages=packages,units="KB",samples={},rounds={},peakBytes=0,
 client={version=version,build=build,interface=interface},scenario={records=1000,rounds=3,reasonBytes=198,gcPolicy="natural until all rounds finish; separate final collection",samplePolicy="before and after each synchronous encode/decode"}}
local function Sample(tag,collected)
 local row={tag=tag,addonKB={},loaded={}}
 if collected then collectgarbage("collect") end
 row.luaHeapKB=collectgarbage("count")
 local t=debugprofilestop();UpdateAddOnMemoryUsage();row.counterRefreshMs=debugprofilestop()-t
 local total=0
 for i,name in ipairs(packages) do local _,loaded=C_AddOns.IsAddOnLoaded(name);assert(loaded,"package_not_loaded");row.loaded[i]=loaded;row.addonKB[i]=GetAddOnMemoryUsage(name);total=total+row.addonKB[i] end
 row.addonTotalKB=total;report.samples[#report.samples+1]=row
 if not collected then report.peakBytes=math.max(report.peakBytes,total*1024) end
 return row
end
-- Run outside slot loading: counters observed during synchronous slot execution
-- stayed flat despite the codec work and cannot establish its addon attribution.
local records,ticker,round=nil,nil,0
assert(probe:Async(20))
assert(probe:OnCleanup(function() if ticker then ticker:Cancel();ticker=nil end;records=nil end))
assert(probe:Guard(function() return not InCombatLockdown() and not A.UI:IsShown() end,{"PLAYER_REGEN_DISABLED"},"scene_changed"))
local function Tick()
 if probe:IsCancelled() then return end
 if not records then
  Sample("before");records={}
  local reason=string.rep("这是用于内存测试的模拟记录，不写入玩家数据。",3)
  for i=1,1000 do records[i]={name="测试玩家"..i,server="模拟服务器",reason=reason..i,timestamp=1700000000+i,classSpec="测试专精",type=i%2==0 and "positive" or "caution",class="MAGE",specID=64} end
 end
 round=round+1
 local t=debugprofilestop();local encoded=A.UI.Transfer.Encode(records)
 local stat={encodeMs=debugprofilestop()-t,encodedBytes=#encoded};report.rounds[round]=stat;Sample("encoded_"..round)
 t=debugprofilestop();local decoded=assert(A.UI.Transfer.Decode(encoded));stat.decodeMs=debugprofilestop()-t
 assert(#decoded==1000,"codec_count")
 for i=1,1000 do assert(decoded[i].name==records[i].name and decoded[i].reason==records[i].reason,"codec_roundtrip") end
 Sample("decoded_"..round)
 if round==3 then
  records,encoded,decoded=nil,nil,nil
  report.retainedKB=Sample("after_diagnostic_gc",true).addonTotalKB
  report.ok=report.peakBytes<=20000000
  return probe:Finish(report)
 end
end
ticker=C_Timer.NewTicker(.6,assert(probe:Callback(Tick)))
