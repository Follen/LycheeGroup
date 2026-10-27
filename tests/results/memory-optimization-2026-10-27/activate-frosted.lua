local A=assert(LycheeGroup);assert(not InCombatLockdown() and not A.UI:IsShown() and not (A.Guide and A.Guide.active))
local api=A.API.Theme;local before=api:GetStatus()
assert(before.current.id==false and before.next.id==false and before.next.activationStorage=='account' and not before.reloadRequired,'unexpected_initial_theme')
assert(api:Activate('lycheegroup.frosted',{storage='account'}))
local after=api:GetStatus();assert(after.current.id==false and after.next.id=='lycheegroup.frosted' and after.reloadRequired)
return {before=before,after=after,pendingTheme='lycheegroup.frosted',restore={id=false,storage='account'},currentUnchanged=true}
