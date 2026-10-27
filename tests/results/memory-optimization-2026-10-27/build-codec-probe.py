from pathlib import Path
import hashlib
import sys

root = Path.cwd()
folder = root / '.lycheedev/memory-opt-20261027'
old = (folder / 'baseline/addon/LycheeGroup_UI/Transfer.lua').read_text(encoding='utf-8-sig')
new = (root / (sys.argv[1] if len(sys.argv)>1 else 'addon/LycheeGroup_UI/Transfer.lua')).read_text(encoding='utf-8-sig')
template = r'''-- Private pure-Lua codec comparison; no product methods or saved records are changed.
local probe=...
local installed=assert(LycheeGroup.UI.Transfer)
local report={schema='lycheegroup.codec-comparison.v1',sourceSHA256={before='@OLD_HASH@',candidate='@NEW_HASH@'},records=1000,rounds=3,samples={},scope='private source copies; one Encode or Decode per callback; debugprofilestop ms; natural GC unchanged'}
local function Load(source)
 local private={LycheeGroup={UI={}}}
 local env=setmetatable({_G=private},{__index=_G})
 local chunk=assert(loadstring(source,'private-codec'));setfenv(chunk,env);chunk()
 return private.LycheeGroup.UI.Transfer
end
local before=Load([====[@OLD@]====])
local candidate=Load([====[@NEW@]====])
local records,encoded,driver
local index,cleaned=0,false
local function Cleanup()
 if cleaned then return end;cleaned=true
 if driver then driver:SetScript('OnUpdate',nil);driver:Hide() end
 records,encoded,before,candidate=nil,nil,nil,nil
 report.cleanup={driverStopped=not driver or driver:GetScript('OnUpdate')==nil,privateDataReleased=true,installedUnchanged=LycheeGroup.UI.Transfer==installed}
end
assert(probe:OnCleanup(Cleanup))
assert(probe:Guard(function() return not InCombatLockdown() and not LycheeGroup.UI:IsShown() and not LycheeGroup.UI.preview end,{'PLAYER_REGEN_DISABLED'},'scene_changed'))
assert(probe:Async(25))
driver=CreateFrame('Frame')
driver:SetScript('OnUpdate',assert(probe:Callback(function()
 if probe:IsCancelled() then return end
 if not records then
  records={};local reason=string.rep('这是用于内存测试的模拟记录，不写入玩家数据。',3)
  for i=1,1000 do records[i]={name='测试玩家'..i,server='模拟服务器',reason=reason..i,timestamp=1700000000+i,classSpec='测试专精',type=i%2==0 and 'positive' or 'caution',class='MAGE',specID=64} end
  local start=debugprofilestop();encoded=before.Encode(records);report.preparationEncodeMs=debugprofilestop()-start
  report.encodedBytes=#encoded;return
 end
 index=index+1
 local round=math.floor((index-1)/4)+1
 local position=(index-1)%4+1
 local name=position%2==1 and 'before' or 'candidate'
 local codec=name=='before' and before or candidate
 local method=position<=2 and 'Encode' or 'Decode'
 local start=debugprofilestop();local result=codec[method](method=='Encode' and records or encoded);local elapsed=debugprofilestop()-start
 local sample={round=round,variant=name,method=method,elapsedMs=elapsed}
 if method=='Encode' then sample.equal=result==encoded;assert(sample.equal,'wire_bytes_changed')
 else
  assert(type(result)=='table' and #result==1000,'record_count_changed')
  for i=1,1000 do for key,value in pairs(records[i]) do assert(result[i][key]==value,'record_field_changed') end end
  sample.equal=true
 end
 report.samples[#report.samples+1]=sample
 if index==12 then Cleanup();report.ok=true;probe:Finish(report) end
end)))
driver:Show()
'''
assert ']====]' not in old and ']====]' not in new
script = template.replace('@OLD_HASH@', hashlib.sha256(old.encode()).hexdigest()).replace('@NEW_HASH@', hashlib.sha256(new.encode()).hexdigest()).replace('@OLD@', old).replace('@NEW@', new)
(folder / (sys.argv[2] if len(sys.argv)>2 else 'live-codec-comparison.lua')).write_text(script, encoding='utf-8')
print({'bytes': len(script.encode()), 'before': hashlib.sha256(old.encode()).hexdigest(), 'candidate': hashlib.sha256(new.encode()).hexdigest()})
