-- Explicitly saved recruitment settings. Protected text is never read or stored.
local A=_G.LycheeGroup
local Presets={}
A.CreationPresets=Presets
local fields={"activityID","requiredItemLevel","requiredDungeonScore","requiredPvpRating","autoAccept","privateGroup","isCrossFactionListing","newPlayerFriendly","playstyle","generalPlaystyle","questID"}
local requirements={"requiredItemLevel","requiredDungeonScore","requiredPvpRating"}
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
local function Normalize(source)
 local id=tonumber(Public(source.activityID))
 if not id or id<=0 or id%1~=0 then return nil end
 local entry={activityID=id,autoAccept=Flag(source,"isAutoAccept","autoAccept"),privateGroup=Flag(source,"isPrivateGroup","privateGroup"),isCrossFactionListing=Flag(source,"isCrossFactionListing"),newPlayerFriendly=Flag(source,"newPlayerFriendly")}
 for _,key in ipairs(requirements) do entry[key]=tonumber(Public(source[key])) or 0 end
 for _,key in ipairs(options) do local value=tonumber(Public(source[key]));if value and value~=0 then entry[key]=value end end
 return entry
end
local function Equal(a,b)
 for _,key in ipairs(fields) do if a[key]~=b[key] then return false end end
 return true
end
local function Find(store,settings,count)
 for i=1,count or #store do if Equal(store[i],settings) then return store[i],i end end
end
function Presets.New(store,changed)
 for i=#store,1,-1 do if Public(store[i].favorite)~=true then table.remove(store,i) end end
 local order={}
 for i,entry in ipairs(store) do order[entry]=i end
 table.sort(store,function(a,b)
  local at,bt=tonumber(Public(a.usedAt)) or 0,tonumber(Public(b.usedAt)) or 0
  if at~=bt then return at>bt end
  return order[a]<order[b]
 end)
 local count,total=0,#store
 for i=1,total do
  local entry=store[i];local normalized=Normalize(entry)
  if normalized and not Find(store,normalized,count) then
   wipe(entry);for key,value in pairs(normalized) do entry[key]=value end;entry.favorite=true
   count=count+1;store[count]=entry
  end
 end
 for i=total,count+1,-1 do store[i]=nil end
 local self={store=store,changed=changed}
 return setmetatable(self,{__index=Presets})
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
