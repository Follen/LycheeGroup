-- URL construction uses only caller-provided identity, region and locale.
-- It never queries RaiderIO or substitutes the local player's realm.
local Links={};_G.LycheeGroup.UI.PlayerLinks=Links
local regions={"us","kr","eu","tw","cn"}
local function Public(value) return not (issecretvalue and issecretvalue(value)) end
local function Text(value) return Public(value) and type(value)=="string" and value~="" end
local function Trim(value) return value:gsub("^%s+",""):gsub("%s+$","") end
local function FullName(value)
 local name,realm=Trim(value):match("^([^%-]+)%-(.+)$")
 if not name then return end
 name,realm=Trim(name),realm:gsub("%s+","")
 if name=="" or realm=="" then return end
 return name,realm
end
local function Encode(value)
 return (value:gsub("[^A-Za-z0-9%-%_%.~]",function(byte) return ("%%%02X"):format(byte:byte()) end))
end
local function Region(region)
 if not Public(region) or type(region)~="number" then return end
 return regions[region]
end
function Links.GetRaiderIOURL(name,realm,region,locale)
 if not Text(name) or not Text(realm) or not Public(locale) then return end
 region=Region(region);if not region then return end
 local slug=Links.GetRealmSlug(realm);if not slug then return end
 return "https://raider.io"..(locale=="zhCN" and "/cn" or "").."/characters/"..region.."/"..Encode(slug).."/"..Encode(name)
end
function Links.GetWCLURL(name,realm,region)
 if not Text(name) or not Text(realm) then return end
 region=Region(region);if not region then return end
 return "https://"..(region=="cn" and "cn." or "www.").."warcraftlogs.com/character/"..region.."/"..Encode(realm).."/"..Encode(name)
end
function Links.Identity(member)
 if not Public(member) or type(member)~="table" then return end
 local nameKey=member.nameKey;if not Public(nameKey) then return end
 -- PlayerKey normally supplies the local realm for blank input; links only
 -- pass complete, normalized components to the shared identity resolver.
 local name,realm
 if nameKey~=nil then
  if not Text(nameKey) then return end
  name,realm=FullName(nameKey)
 else
  local rawName,rawRealm=member.name,member.realm
  if not Text(rawName) or not Public(rawRealm) or rawRealm~=nil and type(rawRealm)~="string" then return end
  name=Trim(rawName)
  local embedded
  if name:find("-",1,true) then name,embedded=FullName(name) end
  realm=rawRealm and rawRealm~="" and rawRealm:gsub("%s+","") or embedded
 end
 if not name or name=="" or not realm or realm=="" then return end
 local key,cleanName,cleanRealm=_G.LycheeGroup.UI.Members:Identity({name=name,realm=realm})
 if not Public(key) or not Public(cleanName) or not Public(cleanRealm) then return end
 if cleanName~=name or cleanRealm~=realm or key~=name.."-"..realm then return end
 return key,cleanName,cleanRealm
end
