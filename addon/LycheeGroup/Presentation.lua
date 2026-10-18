-- Product display rules shared by every package, including Notes without Group.
-- Profiles contain no widgets, mutable business state, native actions or timers.
local A=_G.LycheeGroup
local P={};A.GroupPresentation=P
local empty={}
local function Profile(kind,rosterMode,showRating,dungeons,requirement)
 return {kind=kind,rosterMode=rosterMode,groupMetric=kind=="raid" and "progress" or "rating",
  requirementRatingKind=requirement,
  applicant={source="applicant",canOpenDetails=true,showRating=showRating,showDungeonRecords=dungeons,menu="applicant"}}
end
local raid=Profile("raid","groups",false,false)
local dungeon=Profile("dungeon","list",true,false)
local mythic=Profile("dungeon","list",true,true,"dungeon")
local other=Profile("other","list",true,false)
local large=Profile("other","groups",true,false)
local pvp=Profile("pvp","list",true,false)
local largePvp=Profile("pvp","groups",true,false)
local ratedPvp=Profile("pvp","list",true,false,"pvp")
local largeRatedPvp=Profile("pvp","groups",true,false,"pvp")
local sources={
 roster={source="roster",canOpenDetails=true,showRating=true,showDungeonRecords=false,menu="roster"},
 search={source="search",canOpenDetails=false,showRating=false,showDungeonRecords=false},
 note={source="note",canOpenDetails=true,showRating=true,showDungeonRecords=false},
}
local function Resolve(category,capacity,isMythic,isPvp,isRated)
 if category==3 then return raid end
 if isMythic then return mythic end
 local grouped=(capacity or 0)>5 or category==9 and capacity==0
 if isPvp or isRated then
  if isRated then return grouped and largeRatedPvp or ratedPvp end
  return grouped and largePvp or pvp
 end
 if category==2 then return dungeon end
 return grouped and large or other
end
function P.Activity(activity)
 if not activity then return other end
 return Resolve(activity.categoryID,activity.maxNumPlayers,activity.isMythicPlusActivity,activity.isPvpActivity,activity.isRatedPvpActivity)
end
function P.Result(record)
 local activity=record.activity or empty
 return Resolve(record.categoryID or activity.categoryID,record.maxNumPlayers or activity.maxNumPlayers,
  activity.isMythicPlusActivity,record.ratingKind=="pvp" or activity.isPvpActivity,activity.isRatedPvpActivity)
end
function P.Member(source,activity)
 return source=="applicant" and P.Activity(activity).applicant or sources[source]
end
