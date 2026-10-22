local A = _G.LycheeGroup
local UI = A.UI
UI.inputs = {}
UI.context = _G.LycheeUI:CreateContext({
 font=A.Fonts:GetPath(),
 fontScale=A.Fonts:GetScale(),
 ownsText=function(region)
  return A.Fonts:IsOwned(region,UI.frame,UI.context and UI.context:GetMenu(),UI.Tooltip and UI.Tooltip.interactive)
 end,
 theme={width=1299.2,contentWidth=1267.2,fontSizeDelta=3,lineHeightDelta=4},
 parent=UIParent, inputs=UI.inputs, text=UI.L,
 reducedMotion=function() return A.db.reduceMotion end,
 isHiding=function() return UI.hiding end,
 onRowRelease=function(row)
  if UI.Tooltip and UI.Tooltip:IsOwned(row) then UI.Tooltip:Hide() end
 end,
 onRowLeave=function(row)
  if UI.Tooltip then UI.Tooltip:LeaveOwner(row) end
 end,
})
UI.Theme = UI.context.Theme
UI.brandText = A:GetLocale()=="zhCN" and "|cffE87983荔枝|r 组队" or "|cffE87983Lychee|r LFG"
function UI:SetText(region,text) return self.context:SetText(region,text) end
function UI:Color(region,color) return self.context:Color(region,color) end
function UI:Hex(color) return self.context:Hex(color) end

local scoreColors,scoreOrder={},{}
function UI:ScoreColor(score)
 local color=scoreColors[score]
 if not color then
  color=C_ChallengeMode.GetDungeonScoreRarityColor(score);scoreColors[score]=color
  scoreOrder[#scoreOrder+1]=score
  if #scoreOrder>128 then scoreColors[table.remove(scoreOrder,1)]=nil end
 end
 return color
end
function UI:SetScore(region,score,kind)
 local mapScore=kind=="map"
 if type(score)~="number" or score<0 then self:SetText(region,mapScore and "—" or A:GetLocale()=="zhCN" and "未知分数" or "Unknown");self:Color(region,mapScore and self.Theme.muted or self.Theme.dim);return end
 if score==0 then self:SetText(region,mapScore and "0" or A:GetLocale()=="zhCN" and "暂无分数" or "Unrated");self:Color(region,self.Theme.muted);return end
 self:SetText(region,math.floor(score))
 if kind=="pvp" then self:Color(region,self.Theme.text);return end
 if region._score~=score or region._scoreKind~=kind or region._color~=nil then
  local color
  if mapScore then color=C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score) else color=self:ScoreColor(score) end
  if color then region:SetTextColor(color.r,color.g,color.b) else region:SetTextColor(unpack(self.Theme.muted)) end
  region._score,region._scoreKind,region._color=score,kind,nil
 end
end
function UI:ScoreText(score,kind)
 if type(score)~="number" or score<0 then return A:GetLocale()=="zhCN" and "未知分数" or "Unknown" end
 if score==0 then return A:GetLocale()=="zhCN" and "暂无分数" or "Unrated" end
 if kind=="pvp" then return tostring(math.floor(score)) end
 return self:ScoreColor(score):WrapTextInColorCode(tostring(math.floor(score)))
end
function UI:MemberCountText(record)
 local maximum=record.maxNumPlayers
 return tostring(record.numMembers or 0)..(maximum and maximum>0 and "/"..maximum or "")
end
