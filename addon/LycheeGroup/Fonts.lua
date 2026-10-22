-- Product fonts belong to our two contexts; Blizzard and other addons keep theirs.
local A = _G.LycheeGroup
local F = {}; A.Fonts = F
function F:GetDefaultPath()
 return "Interface\\AddOns\\LycheeGroup\\Media\\Fonts\\LycheeFont-"..A:GetLocale()..".ttf"
end

function F:GetPath()
 local selected = A.db.font
 if selected == "default" then return self:GetDefaultPath() end
 if selected == "game" then return STANDARD_TEXT_FONT end
 if self.selected ~= selected then
  self.check = self.check or CreateFont("LycheeGroupFontCheck")
  self.check:SetFont(selected, 14, "")
  if self.check:GetFont() ~= selected then
   A.db.font = "default"
   return self:GetDefaultPath()
  end
  self.selected = selected
 end
 return selected
end

function F:Choices()
 local zh = A:GetLocale() == "zhCN"
 local choices = {{value="default", label=zh and "荔枝字体" or "LycheeFont"}, {value="game", label=zh and "游戏默认" or "Game default"}}
 local seen = {[self:GetDefaultPath()]=true,[STANDARD_TEXT_FONT]=true}
 local function Add(path, name)
  if path and not seen[path] then
   seen[path] = true
   choices[#choices+1] = {value=path, label=name}
  end
 end
 Add(ChatFontNormal and ChatFontNormal:GetFont(), zh and "聊天字体" or "Chat font")
 Add(UNIT_NAME_FONT, zh and "姓名字体" or "Name font")
 Add(DAMAGE_TEXT_FONT, zh and "伤害数字字体" or "Damage font")
 local media = LibStub and LibStub("LibSharedMedia-3.0", true)
 if media then
  for _, name in ipairs(media:List("font")) do Add(media:Fetch("font",name,true), name) end
 end
 local current=self:GetPath()
 Add(current,current:match("([^\\/]+)%.[^%.]+$") or current)
 return choices
end

function F:GetScale() return A.db.fontScale/100 end

function F:IsOwned(region,window,menu,tooltip)
 while region do
  if region==window or region==menu or region==tooltip then return true end
  region=region:GetParent()
 end
 return false
end

function F:Apply()
 local path,scale = self:GetPath(),self:GetScale()
 if A.UI then A.UI:ApplyFont(path,scale) end
 if A.Floating then A.Floating:ApplyFont(path,scale) end
end
