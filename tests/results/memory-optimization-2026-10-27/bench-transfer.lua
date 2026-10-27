local root='.lycheedev/memory-opt-20261027/'
local records={};local reason=string.rep('这是用于内存测试的模拟记录，不写入玩家数据。',3)
for i=1,1000 do records[i]={name='测试玩家'..i,server='模拟服务器',reason=reason..i,timestamp=1700000000+i,classSpec='测试专精',type=i%2==0 and 'positive' or 'caution',class='MAGE',specID=64} end
local function Measure(label,fn)
 fn();collectgarbage('collect');local heap=collectgarbage('count');collectgarbage('stop')
 local at=os.clock();local result;for i=1,3 do result=fn() end;local elapsed=(os.clock()-at)*1000/3
 local allocated=(collectgarbage('count')-heap)/3;collectgarbage('restart');collectgarbage('collect')
 print(label,'ms',elapsed,'allocatedKiB',allocated,'retainedKiB',collectgarbage('count')-heap)
 return result
end
local selected=assert(arg[1],'before or candidate required; use separate Lua processes to isolate interned strings')
local entries={before={'before',root..'baseline/addon/LycheeGroup_UI/Transfer.lua'},candidate={'candidate',arg[2] or 'addon/LycheeGroup_UI/Transfer.lua'}}
local encoded
for _,entry in ipairs({assert(entries[selected])}) do
 dofile(entry[2]);local t=LycheeGroup.UI.Transfer
 local value=Measure(entry[1]..'.Encode',function() return t.Encode(records) end)
 if encoded then assert(encoded==value,'exact encoded bytes') else encoded=value end
 local decoded=Measure(entry[1]..'.Decode',function() return assert(t.Decode(encoded)) end)
 assert(#decoded==1000)
 for i=1,1000 do assert(decoded[i].reason==records[i].reason and decoded[i].name==records[i].name) end
end
