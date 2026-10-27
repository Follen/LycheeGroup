-- Visible production UI projection for before/after comparison. Offline only.
local output=assert(io.open(assert(arg[1],"output path required"),"wb"))
local function Value(v)
 if type(v)=="number" then return string.format("%.6f",v) end
 if type(v)=="string" then return string.format("%q",v) end
 if type(v)=="boolean" then return tostring(v) end
 if type(v)=="table" then local t={};for i=1,#v do t[i]=Value(v[i]) end;return "{"..table.concat(t,",").."}" end
 return "nil"
end
local function Settle(f)
 for _=1,100 do
  f.base.AdvanceClock(.02)
  for _,n in ipairs(f.S.nodes) do local tick=n:GetScript("OnUpdate");if tick and n:IsVisible() then tick(n,.02) end end
 end
end
local count=0
local function Project(f,label)
 Settle(f)
 local rows={}
 for _,n in ipairs(f.S.nodes) do
  if n:IsVisible() and n:GetAlpha()>0 then
   local inside=n
   while inside and inside~=f.U.frame do inside=inside:GetParent() end
   if inside then
    local row={n.kind,n:GetLeft(),n:GetBottom(),n:GetWidth(),n:GetHeight(),n:GetEffectiveScale(),n:GetAlpha(),n.text,n.font,n.color,n.fill,n.vertex,n.texture,n.atlas,n.texCoords,n.drawLayer,n.frameStrata,n.frameLevel,n.enabled}
    local values={};for i=1,20 do values[i]=Value(row[i]) end
    rows[#rows+1]=table.concat(values,"|")
   end
  end
 end
 table.sort(rows);count=count+1
 output:write("SCENE ",label," ",#rows,"\n",table.concat(rows,"\n"),"\n")
end
for _,theme in ipairs({"lycheegroup.default","lycheegroup.frosted"}) do
 for _,locale in ipairs({"zhCN","enUS"}) do
  for _,scale in ipairs({100,130}) do
   local fixture=dofile("tests/ui_fixture.lua")
   local f=fixture(locale)
   if theme~="lycheegroup.default" then assert(f.A.API.Theme:Activate(theme));f=fixture(locale,f.A.charPrefs,f.A.db) end
   f.A:SetSetting("fontScale",scale)
   assert(f.A:GetSetting("reduceMotion")==false,"normal animation required")
   local prefix=theme.."/"..locale.."/"..scale.."/"
   for _,page in ipairs({"find","create","notes","settings"}) do
    assert(f.A:Open(page));Project(f,prefix..page)
   end
   for _,section in ipairs({"general","interface","browse","memberIcons","blocks","notes","floating","about","credits"}) do
    f.U.pages.settings:SelectSection(section);Project(f,prefix.."settings/"..section)
   end
   f.U.pages.settings:SelectSection("general")
   f.U.pages.settings.controls.applicantAlertSound.widget:Fire("OnClick","LeftButton")
   Project(f,prefix.."sound-menu");f.U:CloseMenu()
   f.A:Open("find");assert(f.U.Application:OpenApplicationSettings())
   Project(f,prefix.."application-settings");f.U:CloseModal();f.U:Hide(true)
  end
 end
end
output:close();print("Projected scenes: "..count)
