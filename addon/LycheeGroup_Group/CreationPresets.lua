-- Explicitly saved recruitment settings. Protected text is never read or stored.
local A=_G.LycheeGroup
local Presets={}
A.CreationPresets=Presets
local fields={"activityID","requiredItemLevel","requiredDungeonScore","requiredPvpRating","autoAccept","privateGroup","isCrossFactionListing","newPlayerFriendly","playstyle","generalPlaystyle","questID"}
local requirements={"requiredItemLevel","requiredDungeonScore","requiredPvpRating"}
local flags={"isAutoAccept","autoAccept","autoInvite","isPrivateGroup","privateGroup","isCrossFactionListing","newPlayerFriendly"}
local options={"playstyle","generalPlaystyle","questID"}
local function Public(value)
 if issecretvalue and issecretvalue(value) then return nil end
 return value
end
local function Flag(source,key,alias)
 local value=Public(source[key])
 if value==nil and alias then value=Public(source[alias]) end
 return value==true
end
local function Number(value)
 local number=tonumber(Public(value))
 if number and number==number and number>=0 and number<math.huge then return number end
end
local function Normalize(source)
 if type(source)~="table" then return nil end
 local id=Number(source.activityID)
 if not id or id<=0 or id%1~=0 then return nil end
 for _,key in ipairs(flags) do
  local value=Public(source[key])
  if value~=nil and type(value)~="boolean" then return nil end
 end
 local entry={activityID=id,autoAccept=Flag(source,"isAutoAccept","autoAccept"),privateGroup=Flag(source,"isPrivateGroup","privateGroup"),isCrossFactionListing=Flag(source,"isCrossFactionListing"),newPlayerFriendly=Flag(source,"newPlayerFriendly")}
 if source.autoInvite~=nil then entry.autoAccept=Flag(source,"autoInvite") end
 for _,key in ipairs(requirements) do
  local raw=Public(source[key]);local value=raw==nil and 0 or Number(raw)
  if not value then return nil end
  entry[key]=value
 end
 for _,key in ipairs(options) do
  local raw=Public(source[key]);local value=raw==nil and 0 or Number(raw)
  if not value or value%1~=0 then return nil end
  if value~=0 then entry[key]=value end
 end
 return entry
end
local function Equal(a,b)
 for _,key in ipairs(fields) do if a[key]~=b[key] then return false end end
 return true
end
local function Find(store,settings,count)
 for i=1,count or #store do if Equal(store[i],settings) then return store[i],i end end
end
local function Preserve(store,key,value)
 local recovery=store.invalidEntries
 if type(recovery)~="table" then
  recovery={previous=recovery};store.invalidEntries=recovery
 end
 recovery[#recovery+1]={key=key,value=value}
end
function Presets.New(store,changed)
 -- Quarantine malformed records before compaction; preserve exact objects for
 -- recovery. Normal history-only entries still follow the retired-list contract.
 local candidates,invalid={},{}
 for key,entry in pairs(store) do
  if type(key)=="number" then
   if key<1 or key%1~=0 or type(entry)~="table" then invalid[#invalid+1]={key=key,value=entry}
   elseif Public(entry.favorite)==true then
    local normalized=Normalize(entry)
    local usedAt=Public(entry.usedAt)
    if normalized and (usedAt==nil or Number(usedAt)) then candidates[#candidates+1]={entry=entry,normalized=normalized,order=key,usedAt=Number(usedAt) or 0}
    else invalid[#invalid+1]={key=key,value=entry} end
   elseif entry.favorite~=nil and type(Public(entry.favorite))~="boolean" then invalid[#invalid+1]={key=key,value=entry} end
  end
 end
 for key in pairs(store) do if type(key)=="number" then store[key]=nil end end
 table.sort(invalid,function(a,b) return a.key<b.key end)
 for _,entry in ipairs(invalid) do Preserve(store,entry.key,entry.value) end
 table.sort(candidates,function(a,b) if a.usedAt~=b.usedAt then return a.usedAt>b.usedAt end;return a.order<b.order end)
 for _,candidate in ipairs(candidates) do
  local entry,normalized=candidate.entry,candidate.normalized
  if not Find(store,normalized) then
   wipe(entry);for key,value in pairs(normalized) do entry[key]=value end;entry.favorite=true
   store[#store+1]=entry
  end
 end
 return setmetatable({store=store,changed=changed},{__index=Presets})
end
function Presets:Get() return self.store end
function Presets:Find(settings)
 local normalized=Normalize(settings)
 if normalized then return Find(self.store,normalized) end
end
function Presets:ToggleFavorite(settings)
 local entry=Normalize(settings)
 if not entry then return end
 local saved,index=Find(self.store,entry)
 if saved then
  saved.favorite=nil;table.remove(self.store,index);self.changed();return nil
 end
 if not A.Group.Catalog:GetActivity(entry.activityID) then return end
 entry.favorite=true;table.insert(self.store,1,entry);self.changed()
 return entry
end
function Presets:Remove(entry)
 for i,saved in ipairs(self.store) do
  if saved==entry then saved.favorite=nil;table.remove(self.store,i);self.changed();return end
 end
end
