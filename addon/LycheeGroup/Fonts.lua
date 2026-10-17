-- Product fonts belong to our two contexts; Blizzard and other addons keep theirs.
local A = _G.LycheeGroup
local F = {}; A.Fonts = F
local zh = GetLocale() == "zhCN"

function F:GetPath()
 local selected = A.db.font
 if selected == "default" then return STANDARD_TEXT_FONT end
 if self.selected ~= selected then
  self.check = self.check or CreateFont("LycheeGroupFontCheck")
  self.check:SetFont(selected, 14, "")
  if self.check:GetFont() ~= selected then
   A.db.font = "default"
   return STANDARD_TEXT_FONT
  end
  self.selected = selected
 end
 return selected
end

function F:Choices()
 local choices = {{value="default", label=zh and "游戏默认" or "Game default"}}
 local seen = {[STANDARD_TEXT_FONT]=true}
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

-- Walk only the addon's retained widget trees, once per explicit font change.
function F:ApplyTree(frame, path)
 if not frame then return end
 if frame:GetObjectType() == "EditBox" then
  local _, size, flags = frame:GetFont()
  frame:SetFont(path, size, flags)
 end
 for _, region in ipairs({frame:GetRegions()}) do
  if region:GetObjectType() == "FontString" then
   local _, size, flags = region:GetFont()
   local height = region:GetLineHeight() + region:GetSpacing()
   region:SetFont(path, size, flags)
   region:SetSpacing(height-region:GetLineHeight())
  end
 end
 for _, child in ipairs({frame:GetChildren()}) do self:ApplyTree(child,path) end
end

function F:Apply()
 local path = self:GetPath()
 if A.UI then A.UI:ApplyFont(path) end
 if A.Floating then A.Floating:ApplyFont(path) end
end
