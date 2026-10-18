-- Recruitment coverage derived from the current roster, not aura or cooldown state.
-- Independently implemented after reviewing NSRT's class-coverage behavior;
-- reference and scope are documented in Architecture.md.
local A=_G.LycheeGroup
local Buffs={}
A.RaidBuffs=Buffs
local definitions={
 {key="attackPower",class="WARRIOR",cn="战斗怒吼",en="Attack power"},
 {key="devotion",class="PALADIN",cn="虔诚光环",en="Devotion Aura"},
 {key="huntersMark",class="HUNTER",cn="猎人印记",en="Hunter's Mark"},
 {key="poisons",class="ROGUE",cn="盗贼毒药",en="Rogue poisons",required=2},
 {key="stamina",class="PRIEST",cn="耐力",en="Stamina"},
 {key="grip",class="DEATHKNIGHT",cn="拉拽／减速",en="Grip / slow"},
 {key="skyfury",class="SHAMAN",cn="天怒",en="Skyfury"},
 {key="intellect",class="MAGE",cn="智力",en="Intellect"},
 {key="warlock",class="WARLOCK",cn="术士",en="Warlock"},
 {key="physical",class="MONK",cn="物理易伤",en="Physical debuff"},
 {key="versatility",class="DRUID",cn="野性印记",en="Versatility"},
 {key="magic",class="DEMONHUNTER",cn="魔法易伤",en="Magic debuff"},
 {key="evoker",class="EVOKER",cn="唤魔师",en="Evoker"},
}

function Buffs.Get(catalog,activityID,members,report)
 local activity=catalog:GetActivity(activityID)
 if not activity or activity.categoryID~=3 or not catalog:Matches(activity,"seasonRaid") then return end
 report=report or {counts={},missing={}}
 local counts,missing=report.counts,report.missing
 wipe(counts);wipe(missing)
 report.maxGroup=activity.difficultyID==16 and 4 or 6
 report.memberCount,report.unknown=0,0
 for _,member in ipairs(members) do
  if (member.subgroup or 1)<=report.maxGroup then
   report.memberCount=report.memberCount+1
   if member.class then counts[member.class]=(counts[member.class] or 0)+1 else report.unknown=report.unknown+1 end
  end
 end
 for _,definition in ipairs(definitions) do
  if (counts[definition.class] or 0)<(definition.required or 1) then missing[#missing+1]=definition end
 end
 return report
end
