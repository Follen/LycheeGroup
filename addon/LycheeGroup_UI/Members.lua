local A=_G.LycheeGroup
local UI=A.UI
local T,L,C=UI.Theme,UI.L,UI.C
local Members={};UI.Members=Members
local NAME_SIZE,NAME_HEIGHT=14,18
local META_SIZE,META_HEIGHT=12,16
local ICON_SIZE,MARK_SIZE,TEXT_GAP=24,18,8
local zh=A:GetLocale()=="zhCN"
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
local markOrder={"bnet","friend","guild","positive","neutral","caution"}
local markTextures={
 bnet="Interface\\AddOns\\LycheeGroup_UI\\Media\\battlenet-friend.tga",
 friend=T.media.."friend.tga",guild=T.media.."guild.tga",
 positive=T.media.."heart.tga",neutral=T.media.."book.tga",caution=T.media.."caution.tga",
}
Members.relationshipTextures={bnet=markTextures.bnet,character=markTextures.friend,guild=markTextures.guild}
function Members:CreateMarks(parent,clickableNote)
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(1,MARK_SIZE);frame:EnableMouse(false)
 frame.icons={};frame.flags={};frame.clickableNote=clickableNote==true;frame:Hide()
 return frame
end
function Members:ClearMarks(frame)
 for _,icon in pairs(frame.icons) do icon:Hide() end
 if frame.noteButton then frame.noteButton:Hide() end
 wipe(frame.flags);frame.noteKey=nil;frame:Hide()
end
local function CollectNote(frame,key)
 if A.db.noteMarks~=false then
  local note=UI:GetNote(key)
  if note then frame.flags[note.type]=true;if frame.clickableNote then frame.noteKey=key end end
 end
end
local function CollectMarks(frame,member,key)
 local flags=frame.flags
 if A.db.relations then
  if member.isBNetFriend then flags.bnet=true end
  if member.isCharFriend or member.isFriend then flags.friend=true end
  if member.isGuildMate then flags.guild=true end
 end
 CollectNote(frame,key)
end
local function PaintMarks(frame)
 local count=0
 for _,kind in ipairs(markOrder) do if frame.flags[kind] then
  local icon
  if frame.clickableNote and (kind=="positive" or kind=="neutral" or kind=="caution") then
   if not frame.noteButton then
    frame.noteButton=C.IconButton(frame,nil,MARK_SIZE,function()
     if frame.noteKey and not UI.preview then A:Open("notes",{playerKey=frame.noteKey}) end
    end,{iconSize=MARK_SIZE,height=MARK_SIZE,radius=4})
   end
   icon=frame.noteButton;icon.icon:SetTexture(markTextures[kind])
  else
   icon=frame.icons[kind]
   if not icon then icon=C.Icon(frame,MARK_SIZE);frame.icons[kind]=icon end
   icon:SetTexture(markTextures[kind])
  end
  icon:ClearAllPoints();icon:SetPoint("LEFT",count*(MARK_SIZE+4),0);icon:Show();count=count+1
 end end
 local width=count>0 and count*(MARK_SIZE+4)-4 or 0
 frame:SetWidth(math.max(1,width));frame:SetShown(count>0)
 return width
end
function Members:BindMarks(frame,member)
 self:ClearMarks(frame);CollectMarks(frame,member,self:Identity(member))
 return PaintMarks(frame)
end
function Members:BindGroupMarks(frame,record)
 self:ClearMarks(frame)
 if A.db.relations then
  frame.flags.bnet=(record.bnetFriends or 0)>0
  frame.flags.friend=(record.charFriends or 0)>0
  frame.flags.guild=(record.guildMates or 0)>0
 end
 CollectNote(frame,record.leaderKey)
 return PaintMarks(frame)
end
function Members:Relations(member)
 if not A.db.relations then return "" end
 local labels={}
 if member.isBNetFriend then labels[#labels+1]=UI:Hex(T.blue)..L.friendBnet.."|r" end
 if member.isCharFriend then labels[#labels+1]=UI:Hex(T.blue)..L.friendChar.."|r" end
 if member.isFriend then labels[#labels+1]=UI:Hex(T.blue)..Say("好友","Friend").."|r" end
 if member.isGuildMate then labels[#labels+1]=UI:Hex(T.good)..L.friendGuild.."|r" end
 return table.concat(labels," · ")
end
local function MemberMeta(member)
 return UI:SpecName(member) or member.localizedClass or L.unknown
end
local function LayoutIdentity(icon,title,subtitle,role,faction,marks,marksWidth,width,top,inset)
 local textX=inset+ICON_SIZE+TEXT_GAP
 role:SetSize(MARK_SIZE,MARK_SIZE);role:SetShown(role:GetTexture()~=nil)
 faction:SetSize(MARK_SIZE,MARK_SIZE)
 local markWidth,markGroups=marksWidth,marksWidth>0 and 1 or 0
 if role:IsShown() then markWidth=markWidth+MARK_SIZE;markGroups=markGroups+1 end
 if faction:IsShown() then markWidth=markWidth+MARK_SIZE;markGroups=markGroups+1 end
 markWidth=markWidth+math.max(0,markGroups-1)*4
 local textWidth=width-textX-inset-(markWidth>0 and markWidth+6 or 0)
 title:ClearAllPoints();title:SetPoint("TOPLEFT",textX,-top);title:SetWidth(textWidth);title:SetHeight(0);title:SetWordWrap(true)
 local titleHeight=math.max(title:GetLineHeight(),title:GetStringHeight())
 local subtitleTop=top+titleHeight+2
 role:ClearAllPoints();role:SetPoint("RIGHT",icon,"RIGHT",width-2*inset-ICON_SIZE,0)
 marks:ClearAllPoints()
 faction:ClearAllPoints()
 if role:IsShown() then faction:SetPoint("RIGHT",role,"LEFT",-4,0) else faction:SetPoint("RIGHT",icon,"RIGHT",width-2*inset-ICON_SIZE,0) end
 if faction:IsShown() then marks:SetPoint("RIGHT",faction,"LEFT",-4,0)
 elseif role:IsShown() then marks:SetPoint("RIGHT",role,"LEFT",-4,0)
 else marks:SetPoint("RIGHT",icon,"RIGHT",width-2*inset-ICON_SIZE,0) end
 subtitle:ClearAllPoints();subtitle:SetPoint("TOPLEFT",textX,-subtitleTop);subtitle:SetWidth(textWidth);subtitle:SetHeight(0);subtitle:SetWordWrap(true)
 local height=math.max(ICON_SIZE,titleHeight+2+math.max(subtitle:GetLineHeight(),subtitle:GetStringHeight()))
 -- Portrait and right-side marks share the complete identity block's center,
 -- including wrapped names and specialization text.
 local portraitTop=top+(height-ICON_SIZE)/2
 icon:SetSize(ICON_SIZE,ICON_SIZE);icon:ClearAllPoints();icon:SetPoint("TOPLEFT",inset,-portraitTop)
 return height
end
function Members:Create(parent,onClick)
 local button=C.Button(parent,"",250,onClick,{height=56,radius=8})
 button:RegisterForClicks("LeftButtonUp","RightButtonUp");button.label:Hide()
 button.icon=C.GameIcon(button,ICON_SIZE)
 button.name=C.Text(button,"",NAME_SIZE,T.text);button.name:SetWordWrap(true);C.SetLineHeight(button.name,NAME_HEIGHT)
 button.leaderIcon=C.Icon(button,10);button.leaderIcon:SetTexture(T.media.."leader.tga");button.leaderIcon:SetPoint("TOPRIGHT",button.icon,"TOPRIGHT",3,3);button.leaderIcon:Hide()
 button.realm=C.Text(button,"",META_SIZE,T.dim);button.realm:SetWordWrap(true);C.SetLineHeight(button.realm,META_HEIGHT)
 button.role=C.Icon(button,MARK_SIZE)
 button.faction=C.Icon(button,MARK_SIZE)
 button.marks=self:CreateMarks(button)
 button:HookScript("OnHide",function() Members:ClearMarks(button.marks) end)
 return button
end
local function Bind(self,button,member,key,width,isLeader,interactive,inset,padding,title,search)
 button.member=member;button.targetKey=self:ID(member) or member.name;button:SetWidth(width)
 button:SetEnabled(interactive==true)
 UI:SetMemberIcon(button.icon,member);UI:SetRoleIcon(button.role,member.assignedRole)
 UI:SetFactionIcon(button.faction,member);button.leaderIcon:SetShown(isLeader==true)
 local r,g,b=UI:ClassColor(member.class)
 UI:SetText(button.name,title);button.name:SetTextColor(r,g,b)
 UI:SetText(button.realm,MemberMeta(member))
 self:ClearMarks(button.marks)
 if search then
  if isLeader then CollectNote(button.marks,key) end
 else CollectMarks(button.marks,member,key) end
 local marksWidth=PaintMarks(button.marks)
 inset,padding=inset or 6,padding or 4
 local height=math.max(56,LayoutIdentity(button.icon,button.name,button.realm,button.role,button.faction,button.marks,marksWidth,width,padding,inset)+padding*2)
 button:SetHeight(height);button:Show()
 return height
end
function Members:Bind(button,member,width,isLeader,interactive,inset,padding)
 local key,name,realm=self:Identity(member)
 local title=(name or member.name or L.unknown)..(realm and UI:Hex(T.muted).."-"..realm.."|r" or "")
 return Bind(self,button,member,key,width,isLeader,interactive,inset,padding,title)
end
function Members:BindRoster(button,member,width,isLeader,interactive,inset,padding)
 local key,name=self:Identity(member)
 return Bind(self,button,member,key,width,isLeader,interactive,inset,padding,name or member.name or L.unknown)
end
function Members:BindSearch(button,member,width,isLeader,interactive,inset,padding)
 local key,name=self:Identity(member)
 return Bind(self,button,member,key,width,isLeader,interactive,inset,padding,name or member.name or L.unknown,true)
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
