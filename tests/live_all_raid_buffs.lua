-- Read-only: exercise coverage against every raid in the current native catalog.
local probe=...
local A=assert(LycheeGroup)
local catalog=assert(A.Group and A.Group.Catalog,"Open Create once before checking raid coverage")
local result={raids=0,legacy=0,unsupported=0,worldBosses=0,sizes={}}
local report
local ids=C_LFGList.GetAvailableActivities(3,nil,4) or {}
assert(#ids>0,"Native raid catalog is empty")
for _,id in ipairs(ids) do
 local activity=catalog:GetActivity(id)
 if activity and (activity.mapID or 0)>0 then
  result.raids=result.raids+1
  if not catalog:Matches(activity,"seasonRaid") then result.legacy=result.legacy+1 end
  report=A.RaidBuffs.Get(catalog,id,{},report)
  if not report then
   result.unsupported=result.unsupported+1
  else
   assert(#report.missing==13,"Empty roster must report every class gap")
   result.sizes[tostring(report.maxGroup*5)]=true
   local profile=A.GroupPresentation.Activity(activity)
   assert(profile.rosterMode=="groups" and profile.applicant.canOpenDetails and profile.applicant.showPlayerLinks,
    "Raid member details and player links must remain available")
  end
 elseif activity then
  result.worldBosses=result.worldBosses+1
  assert(A.RaidBuffs.Get(catalog,id,{})==nil,"World bosses are outside instance-raid coverage")
 end
end
probe:Log(("raids=%d nonSeason=%d unsupported=%d worldBosses=%d"):format(result.raids,result.legacy,result.unsupported,result.worldBosses))
assert(result.unsupported==0,"Native non-season raids are missing coverage")
return result
