local oldPath='.lycheedev/memory-opt-20261027/baseline/addon/LycheeGroup_UI/Transfer.lua'
dofile(oldPath);local before=LycheeGroup.UI.Transfer
dofile('addon/LycheeGroup_UI/Transfer.lua');local after=LycheeGroup.UI.Transfer
local checks=0
local function Same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for key,value in pairs(a) do if not Same(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end;return true
end
local function Check(value,label) assert(value,label);checks=checks+1 end
local function Decode(text)
 local a,ae=before.Decode(text);local b,be=after.Decode(text)
 Check(ae==be and Same(a,b),'decoder differential')
end
local bytes={};for i=0,255 do bytes[#bytes+1]=string.char(i) end
local all=table.concat(bytes)
for i=0,1025 do
 local values={all:sub(1,i%257),string.rep('字',i),i,true,false,{i,nil,i+2},empty={}}
 Check(before.Serialize(values)==after.Serialize(values),'serializer byte equality')
 local encoded=before.Encode(values)
 Check(encoded==after.Encode(values),'encoder byte equality')
 Decode(encoded);Decode(' \n'..encoded..' \r');Decode(encoded:sub(1,-2));Decode(encoded..'==')
end
math.randomseed(271027)
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=! \t\n-'
for i=1,3000 do
 local parts={'LN-'};for _=1,math.random(0,120) do local n=math.random(#alphabet);parts[#parts+1]=alphabet:sub(n,n) end
 Decode(table.concat(parts))
end
print('Codec baseline differential: '..checks..' checks passed')
