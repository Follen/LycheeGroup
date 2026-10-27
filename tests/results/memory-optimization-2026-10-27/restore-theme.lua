local A=assert(LycheeGroup);assert(not InCombatLockdown() and not A.UI:IsShown() and not (A.Guide and A.Guide.active))
local api=A.API.Theme;local before=api:GetStatus();assert(before.current.id=='lycheegroup.frosted' and before.next.id=='lycheegroup.frosted' and not before.reloadRequired)
assert(api:Activate(false,{storage='account'}));local after=api:GetStatus();assert(after.next.id==false and after.next.activationStorage=='account' and after.reloadRequired)
return {before=before,after=after,originalSelectionRestored=true}
