local A=_G.LycheeGroup
local UI=A.UI
local T,L,C=UI.Theme,UI.L,UI.C
local Members={};UI.Members=Members
local NAME_SIZE,NAME_HEIGHT=14,18
local META_SIZE,META_HEIGHT=12,16
local ICON_SIZE,MARK_SIZE,TEXT_GAP=24,12,8
local zh=GetLocale()=="zhCN"
local function Say(cn,en) return zh and cn or en end

function Members:Identity(member)
 if member.nameKey then return A:PlayerKey(member.nameKey) end
 if member.name and ((member.realm and member.realm~="") or member.name:find("-",1,true)) then return A:PlayerKey(member.name,member.realm) end
 return nil,member.name,nil
end
function Members:ID(member) return member.guid or member.nameKey end
function Members:Order(members,ordered,leaderKey)
 wipe(ordered)
 local leader
 for _,member in ipairs(members) do
  if member.isLeader or leaderKey and member.nameKey==leaderKey then leader=member;ordered[1]=member;break end
 end
 for pass=1,4 do for _,member in ipairs(members) do
  local role=member.assignedRole;local rank=role=="TANK" and 1 or role=="HEALER" and 2 or role=="DAMAGER" and 3 or 4
  if member~=leader and rank==pass then ordered[#ordered+1]=member end
 end end
 return ordered,leader
end
local function NoteMark(key)
 if A.db.noteMarks==false or not UI:HasNote(key) then return "" end
 local note=A.Notes:Find(key)
 local color=note.type=="positive" and T.good or note.type=="caution" and T.warning or T.muted
 return " "..UI:Hex(color).."•|r"
end
function Members:Relations(member)
 if not A.db.relations then return "" end
 local labels={}
 if member.isBNetFriend then labels[#labels+1]=UI:Hex(T.blue)..L.friendBnet.."|r" end
 if member.isCharFriend then labels[#labels+1]=UI:Hex(T.blue)..L.friendChar.."|r" end
 if member.isGuildMate then labels[#labels+1]=UI:Hex(T.good)..L.friendGuild.."|r" end
 if #labels==0 and member.relationship and member.relationship~="" then labels[1]=member.relationship end
 return table.concat(labels," · ")
end
local function MemberMeta(member)
 local text=UI:SpecName(member) or member.localizedClass or L.unknown
 local relation=Members:Relations(member)
 return text..(relation~="" and " · "..relation or "")
end
local function LayoutIdentity(icon,title,subtitle,role,faction,width,top,inset)
 local textX=inset+ICON_SIZE+TEXT_GAP
 role:SetSize(MARK_SIZE,MARK_SIZE);role:SetShown(role:GetTexture()~=nil)
 faction:SetSize(MARK_SIZE,MARK_SIZE)
 local marks=(role:IsShown() and MARK_SIZE or 0)+(faction:IsShown() and MARK_SIZE or 0)+(role:IsShown() and faction:IsShown() and 4 or 0)
 local textWidth=width-textX-inset-(marks>0 and marks+6 or 0)
 title:ClearAllPoints();title:SetPoint("TOPLEFT",textX,-top);title:SetWidth(textWidth);title:SetHeight(0);title:SetWordWrap(true)
 local titleHeight=math.max(NAME_HEIGHT,title:GetStringHeight())
 local subtitleTop=top+titleHeight+2
 role:ClearAllPoints();role:SetPoint("RIGHT",icon,"RIGHT",width-2*inset-ICON_SIZE,0)
 faction:ClearAllPoints()
 if role:IsShown() then faction:SetPoint("RIGHT",role,"LEFT",-4,0) else faction:SetPoint("RIGHT",icon,"RIGHT",width-2*inset-ICON_SIZE,0) end
 subtitle:ClearAllPoints();subtitle:SetPoint("TOPLEFT",textX,-subtitleTop);subtitle:SetWidth(textWidth);subtitle:SetHeight(0);subtitle:SetWordWrap(true)
 local height=math.max(ICON_SIZE,titleHeight+2+math.max(META_HEIGHT,subtitle:GetStringHeight()))
 -- Long names grow downward without moving the portrait away from the first line.
 local portraitTop=top+(NAME_HEIGHT+2+META_HEIGHT-ICON_SIZE)/2
 icon:SetSize(ICON_SIZE,ICON_SIZE);icon:ClearAllPoints();icon:SetPoint("TOPLEFT",inset,-portraitTop)
 return height
end
function Members:Create(parent,onClick)
 local button=C.Button(parent,"",250,onClick)
 button:SetHeight(44);button:RegisterForClicks("LeftButtonUp","RightButtonUp");button.fill:SetRadius(8);button.hover:SetRadius(8);button.label:Hide()
 button.icon=C.GameIcon(button,ICON_SIZE)
 button.name=C.Text(button,"",NAME_SIZE,T.text);button.name:SetWordWrap(true);C.SetLineHeight(button.name,NAME_HEIGHT)
 button.leaderIcon=C.Icon(button,10);button.leaderIcon:SetTexture(T.media.."leader.tga");button.leaderIcon:SetPoint("TOPRIGHT",button.icon,"TOPRIGHT",3,3);button.leaderIcon:Hide()
 button.realm=C.Text(button,"",META_SIZE,T.dim);button.realm:SetWordWrap(true);C.SetLineHeight(button.realm,META_HEIGHT)
 button.role=C.Icon(button,MARK_SIZE)
 button.faction=C.Icon(button,MARK_SIZE)
 return button
end
function Members:Bind(button,member,width,isLeader,interactive,inset,padding)
 button.member=member;button.targetKey=self:ID(member) or member.name;button:SetWidth(width)
 button:SetEnabled(interactive==true)
 UI:SetMemberIcon(button.icon,member);UI:SetRoleIcon(button.role,member.assignedRole)
 UI:SetFactionIcon(button.faction,member);button.leaderIcon:SetShown(isLeader==true)
 local key,name,realm=self:Identity(member);local r,g,b=UI:ClassColor(member.class)
 UI:SetText(button.name,(name or member.name or L.unknown)..(realm and UI:Hex(T.muted).."-"..realm.."|r" or "")..NoteMark(key));button.name:SetTextColor(r,g,b)
 UI:SetText(button.realm,MemberMeta(member))
 inset,padding=inset or 6,padding or 4
 local height=math.max(44,LayoutIdentity(button.icon,button.name,button.realm,button.role,button.faction,width,padding,inset)+padding*2)
 button:SetHeight(height);button:Show()
 return height
end

local function RosterPermissions(member)
 if UI.preview or not member.unit or member.isSelf then return false,false,false,false end
 local unit=member.unit;local human=UnitIsHumanPlayer(unit)
 local whisper=human and UnitIsConnected(unit) and UnitCanCooperate("player",unit)
 local restricted=HasLFGRestrictions();local remove=false
 if human then
  if restricted then
   local _,kind=GetInstanceInfo()
   remove=IsInGroup() and kind~="pvp" and kind~="arena" and not IsInActiveWorldPVP()
  elseif IsInRaid() then
   remove=UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") and not UnitIsGroupLeader(unit) and not UnitIsGroupAssistant(unit)
  else
   local _,kind=GetInstanceInfo()
   remove=UnitIsGroupLeader("player") and kind~="pvp" and kind~="arena" and not C_PartyInfo.ChallengeModeRestrictionsActive()
  end
 end
 local inspect=human and not UnitCanAttack("player",unit) and not UnitIsDeadOrGhost("player") and not InCombatLockdown() and CanInspect(unit,true)
 return whisper,remove,inspect,restricted
end
function Members:OpenMenu(button,member,beforeInspect)
 local id=self:ID(member)
 local whisper,remove,inspect,vote=RosterPermissions(member)
 UI.context:OpenMenu(button,{
  {value="whisper",label=Say("私聊","Whisper"),disabled=not whisper},
  {value="remove",label=vote and Say("移出队伍（投票）","Vote to remove") or Say("移出队伍","Remove from group"),color=T.accent,disabled=not remove},
  {value="inspect",label=Say("查看角色信息","Inspect"),disabled=not inspect},
 },function(action)
  local current
  for _,candidate in ipairs(UI:GetGroup():GetRoster()) do if self:ID(candidate)==id then current=candidate;break end end
  if not current or UI.preview or not current.unit or not current.guid or UnitGUID(current.unit)~=current.guid then return end
  local canWhisper,canRemove,canInspect=RosterPermissions(current)
  local _,name,realm=self:Identity(current);local fullName=realm and name.."-"..realm or name
  if action=="whisper" and canWhisper then ChatFrameUtil.SendTell(fullName)
  elseif action=="remove" and canRemove then C_PartyInfo.UninviteUnit(fullName,nil,true)
  elseif action=="inspect" and canInspect then if beforeInspect then beforeInspect() end;InspectUnit(current.unit) end
 end,{cursor=true})
end
