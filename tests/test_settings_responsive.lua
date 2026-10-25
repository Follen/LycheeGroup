-- Run from LycheeGroup: lua tests/test_settings_responsive.lua.
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b,message) check(math.abs(a-b)<.001,message) end
for _,locale in ipairs({"zhCN","enUS"}) do for _,percent in ipairs({70,100,130}) do
 local fixture=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true,fontScale=percent})
 local A,UI=fixture.A,fixture.U;A:Open("settings",{section="general"})
 local P,T,context=UI.pages.settings,UI.Theme,UI.context
 local panel=P.panels.general
 for _,width in ipairs({639,640,844,639,844}) do
  P:LayoutSize(width+T.settingsMainX+T.settingsContentInset*2+12,UI.content:GetHeight())
  check(context:FlushLayouts(),locale.." conditional layout queue did not settle")
  for _,row in ipairs(panel.rows) do
   check(row.layout.mode=="flex" and row.layout.options.track and row.frame._lycheeBoxLayout==row.layout,"settings row does not retain its declared native Box")
   near(row.frame:GetWidth(),width,"settings row width does not follow its panel")
   near(row.layout.gap,width<640 and 12 or 24,"exclusive static width condition is inconsistent")
   check(row.label:GetWidth()>0 and row.help:GetWidth()>0,"narrow row text lost its available width")
   check(row.frame:GetHeight()+.001>=math.max(row.label:GetStringHeight(),row.help:GetStringHeight())+32,"wrapped settings content overflows its row")
   check(context.elements[row.frame].id=="settings.row","Box replaced the product element identity")
  end
 end
 local writes=0
 for _,row in ipairs(panel.rows) do for _,node in ipairs({row.label,row.help,row.control}) do
  for _,method in ipairs({"SetWidth","SetHeight","ClearAllPoints","SetPoint"}) do
   local original=node[method];node[method]=function(self,...) writes=writes+1;return original(self,...) end
  end
 end end
 local nodes=#fixture.S.nodes
 for index=1,20 do P:LayoutRows();check(context:FlushLayouts(),"stable settings queue failed") end
 check(writes==0 and #fixture.S.nodes==nodes,"stable settings rows repeated native geometry writes or allocated objects")
 UI:Hide(true)
end end
local physical=GetPhysicalScreenSize
GetPhysicalScreenSize=function() return 1920,1080 end
local fixture=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true})
local A,UI,G=fixture.A,fixture.U,fixture.G
for index=1,48 do G.Results:BlockTitle("Responsive "..index,"Leader"..index.."-Silvermoon") end
A:Open("settings",{section="blocks"})
local P,context=UI.pages.settings,UI.context
check(context:FlushLayouts(),"initial block layout failed")
local list,header=P.blocksList,P.blocksHeader
local preferences=0;context.options.onTablePreferenceChanged=function() preferences=preferences+1 end
local function columns()
 local row=list.rows[1]
 for _,entry in ipairs({{"name",row.title},{"realm",row.meta}}) do
  local key,node=entry[1],entry[2]
  near(select(4,node:GetPoint()),header.columns[key].x+select(2,header.labels[key]:GetPoint()),"header and row do not share their cumulative pixel boundary")
  near(node:GetWidth(),header.labels[key]:GetWidth(),"header and row have different snapped text widths")
 end
 check(#list.rows<48 and #list.ids==48,"responsive columns changed the fixed-list pool")
end
columns()
local nodes=#fixture.S.nodes
for index=1,12 do
 P:LayoutBlocks();list:SetPixelOffset(index%2==0 and 0 or 10000,false)
 check(context:FlushLayouts(),"block list queue failed");columns()
end
check(preferences==0 and #fixture.S.nodes==nodes,"programmatic column layout saved preferences or grew the pool")
GetPhysicalScreenSize=physical
print("Responsive settings: "..checks.." checks passed")
