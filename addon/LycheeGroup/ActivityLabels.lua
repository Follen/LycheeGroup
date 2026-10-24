-- Display aliases for native activity and difficulty text only. Callers retain
-- original catalog names, IDs and search values, and never pass player text.
local A=_G.LycheeGroup
local Labels={};A.ActivityLabels=Labels
local aliases={
 {"史诗钥石","M+"},
 {"史诗钥匙","M+"},
 {"Mythic Keystone","M+"},
}
function Labels.Display(value)
 if issecretvalue and issecretvalue(value) then return end
 if type(value)~="string" then return end
 for _,alias in ipairs(aliases) do value=value:gsub(alias[1],alias[2]) end
 return value
end
