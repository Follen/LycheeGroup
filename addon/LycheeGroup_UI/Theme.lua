local A = _G.LycheeGroup
local UI = A.UI
UI.inputs = {}
UI.context = _G.LycheeUI:CreateContext({
 font=A.Fonts:GetPath(),
 fontScale=A.Fonts:GetScale(),
 ownsText=function(region)
  return A.Fonts:IsOwned(region,UI.frame,UI.context and UI.context:GetMenu(),UI.Tooltip and UI.Tooltip.interactive)
 end,
 themeDefaults=A.StyleDefaults.main,
 theme=A.Appearance:GetTheme("main"),
 recipeDefaults=A.ThemeDefaults.appearance.main.components,
 recipes=A.Appearance:GetRecipes("main"),
 elementDefaults=A.ThemeDefaults.appearance.main.elements,
 elements=A.Appearance:GetElements("main"),
 utilities=A.Appearance:GetUtilities("main"),
 parent=UIParent, inputs=UI.inputs, text=UI.L,
 reducedMotion=function() return A:GetSetting("reduceMotion") end,
 isHiding=function() return UI.hiding end,
 onRowRelease=function(row)
  if UI.Tooltip and UI.Tooltip:IsOwned(row) then UI.Tooltip:Hide() end
 end,
 onRowLeave=function(row)
  if UI.Tooltip then UI.Tooltip:LeaveOwner(row) end
 end,
})
UI.Theme = UI.context.Theme
function UI:RefreshBrandText()
 local color=self.Theme.brand
 local prefix=("|cff%02X%02X%02X"):format(math.floor(color[1]*255+.5),math.floor(color[2]*255+.5),math.floor(color[3]*255+.5))
 self.brandText=prefix..(A:GetLocale()=="zhCN" and "荔枝|r 组队" or "Lychee|r LFG")
 if self.brandTitle then self:SetText(self.brandTitle,self.brandText) end
end
UI:RefreshBrandText()
function UI:SetText(region,text) return self.context:SetText(region,text) end
function UI:Color(region,color)
 if type(color)=="string" then color=self.Theme[color] end
 return self.context:Color(region,color)
end
function UI:Hex(color) return self.context:Hex(color) end
local productImages={}
for file in ("role-tank role-healer role-dps tank healer damage leader invite friend guild pvp delve tower mountain flag lychee-logo"):gmatch("%S+") do productImages[file..".tga"]=true end
function UI:MediaPath(file) return (productImages[file] and self.Theme.productMedia or self.Theme.media)..file end
function UI:SetMediaTexture(texture,file)
 texture:SetTexture(self:MediaPath(file))
end
function UI:CreateGlyph(parent,kind,size,color)
 local glyph=self.C.Glyph(parent,kind,size,color)
 if productImages[kind..".tga"] then glyph:SetTexture(self:MediaPath(kind..".tga"));self:SetMediaTexture(glyph.texture,kind..".tga") end
 return glyph
end

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
 if score==0 then self:SetText(region,mapScore and "0" or A:GetLocale()=="zhCN" and "暂无" or "Unrated");self:Color(region,self.Theme.muted);return end
 self:SetText(region,math.floor(score))
 if kind=="pvp" then self:Color(region,self.Theme.text);return end
 if region._score~=score or region._scoreKind~=kind or region._color~=nil then
  local color
  if mapScore then color=C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score) else color=self:ScoreColor(score) end
  if color then region:SetTextColor(A.GroupPresentation.GameTextColor(self.Theme,color)) else region:SetTextColor(unpack(self.Theme.muted)) end
  region._score,region._scoreKind,region._color=score,kind,nil
 end
end
function UI:ScoreText(score,kind)
 if type(score)~="number" or score<0 then return A:GetLocale()=="zhCN" and "未知分数" or "Unknown" end
 if score==0 then return A:GetLocale()=="zhCN" and "暂无" or "Unrated" end
 if kind=="pvp" then return tostring(math.floor(score)) end
 local color=self:ScoreColor(score);local tint=self.Theme.gameTextTint
 if tint[1]==1 and tint[2]==1 and tint[3]==1 then return color:WrapTextInColorCode(tostring(math.floor(score))) end
 local r,g,b=A.GroupPresentation.GameTextColor(self.Theme,color)
 return ("|cff%02x%02x%02x%d|r"):format(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor(score))
end
function UI:MemberCountText(record)
 local maximum=record.maxNumPlayers
 return (record.numMembers==nil and "—" or tostring(record.numMembers))..(maximum and maximum>0 and "/"..maximum or "")
end
