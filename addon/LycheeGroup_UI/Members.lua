local A=_G.LycheeGroup
local UI=A.UI
local T,L,C=UI.Theme,UI.L,UI.C
local Members={};UI.Members=Members
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
function Members:RefreshAppearance()
 for kind,file in pairs({friend="friend",guild="guild",positive="heart",neutral="book",caution="caution"}) do markTextures[kind]=T.media..file..".tga" end
 self.relationshipTextures.character,self.relationshipTextures.guild=markTextures.friend,markTextures.guild
end
function Members:CreateMarks(parent,clickableNote)
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(1,T.memberMarkSize);frame:EnableMouse(false)
 frame.icons={};frame.flags={};frame.clickableNote=clickableNote==true;frame:Hide()
 return frame
end
function Members:ClearMarks(frame)
 for _,icon in pairs(frame.icons) do icon:Hide() end
 if frame.noteButton then frame.noteButton:Hide() end
 wipe(frame.flags);frame.noteKey=nil;frame:Hide()
end
local function CollectNote(frame,key)
 if A:GetSetting("noteMarks")~=false then
  local note=UI:GetNote(key)
  if note then frame.flags[note.type]=true;if frame.clickableNote then frame.noteKey=key end end
 end
end
local function CollectMarks(frame,member,key)
 local flags=frame.flags
 if A:GetSetting("relations") then
  if member.isBNetFriend then flags.bnet=true end
  if member.isCharFriend or member.isFriend then flags.friend=true end
  if member.isGuildMate then flags.guild=true end
 end
 CollectNote(frame,key)
end
local function PaintMarks(frame)
 frame:SetHeight(T.memberMarkSize)
 local count=0
 for _,kind in ipairs(markOrder) do if frame.flags[kind] then
  local icon
  if frame.clickableNote and (kind=="positive" or kind=="neutral" or kind=="caution") then
   if not frame.noteButton then
    frame.noteButton=C.IconButton(frame,nil,T.memberMarkSize,function()
     if frame.noteKey and not UI.preview then A:Open("notes",{playerKey=frame.noteKey}) end
    end,{iconSize=T.memberMarkSize,height=T.memberMarkSize,radius=4})
   end
   icon=frame.noteButton;icon:SetSize(T.memberMarkSize,T.memberMarkSize);icon.icon:SetSize(T.memberMarkSize,T.memberMarkSize);icon.icon:SetTexture(markTextures[kind])
  else
   icon=frame.icons[kind]
   if not icon then icon=C.Icon(frame,T.memberMarkSize);frame.icons[kind]=icon end
   icon:SetSize(T.memberMarkSize,T.memberMarkSize);icon:SetTexture(markTextures[kind])
  end
  icon:ClearAllPoints();icon:SetPoint("LEFT",count*(T.memberMarkSize+4),0);icon:Show();count=count+1
 end end
 local width=count>0 and count*(T.memberMarkSize+4)-4 or 0
 frame:SetWidth(math.max(1,width));frame:SetShown(count>0)
 return width
end
function Members:BindMarks(frame,member)
 self:ClearMarks(frame);CollectMarks(frame,member,self:Identity(member))
 return PaintMarks(frame)
end
function Members:BindGroupMarks(frame,record)
 self:ClearMarks(frame)
 if A:GetSetting("relations") then
  frame.flags.bnet=(record.bnetFriends or 0)>0
  frame.flags.friend=(record.charFriends or 0)>0
  frame.flags.guild=(record.guildMates or 0)>0
 end
 CollectNote(frame,record.leaderKey)
 return PaintMarks(frame)
end
function Members:Relations(member)
 if not A:GetSetting("relations") then return "" end
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
local function LayoutIdentity(icon,title,subtitle,role,faction,marks,marksWidth,width,top,inset,inlineMarks)
 local textX=inset+T.memberIconSize+T.memberTextGap
 role:SetSize(T.memberMarkSize,T.memberMarkSize);role:SetShown(role:GetTexture()~=nil)
 faction:SetSize(T.memberMarkSize,T.memberMarkSize)
 local markWidth,markGroups=marksWidth,marksWidth>0 and 1 or 0
 if role:IsShown() then markWidth=markWidth+T.memberMarkSize;markGroups=markGroups+1 end
 if faction:IsShown() then markWidth=markWidth+T.memberMarkSize;markGroups=markGroups+1 end
 markWidth=markWidth+math.max(0,markGroups-1)*4
 local textWidth=width-textX-inset-(markWidth>0 and markWidth+6 or 0)
 title:SetWidth(textWidth);title:SetHeight(0);title:SetWordWrap(true)
 local titleHeight=math.max(title:GetLineHeight(),title:GetStringHeight())
 subtitle:SetWidth(textWidth);subtitle:SetHeight(0);subtitle:SetWordWrap(true)
 local height=math.max(T.memberIconSize,titleHeight+2+math.max(subtitle:GetLineHeight(),subtitle:GetStringHeight()))
 local crownSpace=math.max(0,T.memberLeaderSize+T.memberLeaderGap-top-(height-T.memberIconSize)/2)
 top=top+crownSpace
 title:ClearAllPoints();title:SetPoint("TOPLEFT",textX,-top)
 subtitle:ClearAllPoints();subtitle:SetPoint("TOPLEFT",textX,-top-titleHeight-2)
 -- Portrait and right-side marks share the complete identity block's center,
 -- including wrapped names and specialization text.
 local portraitTop=top+(height-T.memberIconSize)/2
 icon:SetSize(T.memberIconSize,T.memberIconSize);icon:ClearAllPoints();icon:SetPoint("TOPLEFT",inset,-portraitTop)
 local markRight=width-inset
 if inlineMarks then markRight=textX+math.min(textWidth,math.max(title:GetStringWidth(),subtitle:GetStringWidth()))+6+markWidth end
 local markOffset=markRight-inset-T.memberIconSize
 role:ClearAllPoints();role:SetPoint("RIGHT",icon,"RIGHT",markOffset,0)
 marks:ClearAllPoints();faction:ClearAllPoints()
 if role:IsShown() then C.SetPoint(faction,"RIGHT",role,"LEFT","membersFactionRightX",0) else faction:SetPoint("RIGHT",icon,"RIGHT",markOffset,0) end
 if faction:IsShown() then C.SetPoint(marks,"RIGHT",faction,"LEFT","membersMarksRightX",0)
 elseif role:IsShown() then C.SetPoint(marks,"RIGHT",role,"LEFT","membersMarksRightX",0)
 else marks:SetPoint("RIGHT",icon,"RIGHT",markOffset,0) end
 return height+crownSpace
end
function Members:Create(parent,onClick)
 local button=C.Button(parent,"",T.membersButtonWidth,onClick,{height=56,radius=8});C.ApplyStyle(button,{width="membersButtonWidth"})
 button:RegisterForClicks("LeftButtonUp","RightButtonUp");button.label:Hide()
 button.icon=C.GameIcon(button,T.memberIconSize)
 button.name=C.Text(button,"","memberNameFont","text");button.name:SetWordWrap(true);C.SetLineHeight(button.name,"memberNameLine")
 button.leaderIcon=C.Icon(button,T.memberLeaderSize);C.ApplyStyle(button.leaderIcon,{width="memberLeaderSize",height="memberLeaderSize"});button.leaderIcon:SetDrawLayer("OVERLAY",1);UI:SetMediaTexture(button.leaderIcon,"leader.tga");C.SetPoint(button.leaderIcon,"BOTTOM",button.icon,"TOP",0,"memberLeaderGap");button.leaderIcon:Hide()
 button.realm=C.Text(button,"","memberMetaFont","dim");button.realm:SetWordWrap(true);C.SetLineHeight(button.realm,"memberMetaLine")
 button.role=C.Icon(button,T.memberMarkSize)
 button.faction=C.Icon(button,T.memberMarkSize)
 button.marks=self:CreateMarks(button)
 button:HookScript("OnHide",function() Members:ClearMarks(button.marks) end)
 return button
end
local function Bind(self,button,member,key,width,isLeader,interactive,inset,padding,title,search)
 button.member=member;button.targetKey=self:ID(member) or member.name;button:SetWidth(width)
 button:SetEnabled(interactive==true)
 UI:SetMemberIcon(button.icon,member);UI:SetRoleIcon(button.role,member.assignedRole)
 if search then button.faction:Hide() else UI:SetFactionIcon(button.faction,member) end
 button.leaderIcon:SetShown(isLeader==true)
 local r,g,b=UI:ClassColor(member.class)
 UI:SetText(button.name,title);button.name:SetTextColor(r,g,b)
 UI:SetText(button.realm,MemberMeta(member))
 self:ClearMarks(button.marks)
 if search then
  if isLeader then CollectNote(button.marks,key) end
 else CollectMarks(button.marks,member,key) end
 local marksWidth=PaintMarks(button.marks)
 inset,padding=inset or 6,padding or 4
 local height=math.max(56,LayoutIdentity(button.icon,button.name,button.realm,button.role,button.faction,button.marks,marksWidth,width,padding,inset,search)+padding*2)
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
