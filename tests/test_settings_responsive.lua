-- Run from LycheeGroup: lua tests/test_settings_responsive.lua.
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b,message) check(math.abs(a-b)<.001,message) end
local function position(region,root)
 if region==root then return 0,0 end
 local point={region:GetPoint()};local relative,anchor,x,y
 if type(point[2])=="table" then relative,anchor,x,y=point[2],point[3],point[4] or 0,point[5] or 0
 else relative,anchor,x,y=region:GetParent(),point[1],point[2] or 0,point[3] or 0 end
 local function part(value,low,high) return value:find(low) and 0 or value:find(high) and 1 or .5 end
 local px,py=position(relative,root)
 return px+relative:GetWidth()*part(anchor,"LEFT","RIGHT")+x-region:GetWidth()*part(point[1],"LEFT","RIGHT"),py+relative:GetHeight()*part(anchor,"TOP","BOTTOM")-y-region:GetHeight()*part(point[1],"TOP","BOTTOM")
end
local function themeFeedback(page,tag,checkPanelBottom)
 local panel=page.panels.interface;local theme=page.controls.theme.widget
 check(theme.label:GetUnboundedStringWidth()<=theme.label:GetWidth()+.001,tag..": the selected built-in theme label is clipped")
 local hint,reload=page.themeReloadHint,page.reloadLanguage
 check(hint and hint:IsVisible() and reload:IsVisible(),tag..": Appearance is missing its pending theme feedback")
 local hintX,hintY=position(hint,panel);local reloadX,reloadY=position(reload,panel)
 near(hintY,panel.nextRowY+16,tag..": pending feedback overlaps an Appearance setting row")
 near(reloadY,hintY,tag..": pending feedback and reload action are not aligned")
 check(hintX>=0 and hintX+hint:GetWidth()+24<=reloadX+.001,tag..": pending feedback overlaps the reload action")
 check(reloadX+reload:GetWidth()<=panel:GetWidth()+.001,tag..": the reload action overflows the Appearance panel")
 if checkPanelBottom then
  check(hintY+hint:GetStringHeight()<=panel:GetHeight()+.001 and reloadY+reload:GetHeight()<=panel:GetHeight()+.001,tag..": pending feedback falls below the Appearance panel")
 end
end
for _,locale in ipairs({"zhCN","enUS"}) do for _,percent in ipairs({70,100,130}) do
 local fixture=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true,fontScale=percent})
 local A,UI=fixture.A,fixture.U;A:Open("settings",{section="general"})
 local P,T,context=UI.pages.settings,UI.Theme,UI.context
 check(A.API.Theme:Activate("lycheegroup.frosted"),"the pending theme fixture failed")
 for _,section in ipairs({"general","interface","notifications"}) do
  P:SelectSection(section)
  local panel=P.panels[section]
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
   if section=="interface" then
    local theme=P.controls.theme.widget
    check(theme.label:GetText()==(locale=="zhCN" and "透明毛玻璃" or "Frosted glass"),"the theme Choice lost its localized selected label")
    -- These synthetic widths exercise the row's 640-unit branch, including
    -- widths below the real window minimum. Check vertical fit at that minimum.
    themeFeedback(P,locale.."/"..percent.."/"..width,false)
   end
  end
 end
 P:SelectSection("interface");UI:SetWindowSize(1,1)
 check(context:FlushLayouts(),"minimum-window settings layout did not settle")
 themeFeedback(P,locale.."/"..percent.." minimum window",true)
 -- The final width change also invalidates the hidden General rows. Settle
 -- their first measurement before checking repeated stable layouts.
 P:LayoutRows();check(context:FlushLayouts(),"hidden settings rows did not settle")
 local writes=0;local writeDetails={}
 for _,section in ipairs({"general","interface","notifications"}) do for rowIndex,row in ipairs(P.panels[section].rows) do for nodeIndex,node in ipairs({row.label,row.help,row.control}) do
  for _,method in ipairs({"SetWidth","SetHeight","ClearAllPoints","SetPoint"}) do
   local key=section..rowIndex.."/"..nodeIndex.."/"..method
   local original=node[method];node[method]=function(self,...) writes=writes+1;writeDetails[key]=(writeDetails[key] or 0)+1;return original(self,...) end
  end
 end end end
 local nodes=#fixture.S.nodes
 for index=1,20 do P:LayoutRows();check(context:FlushLayouts(),"stable settings queue failed") end
 local details={};for key,count in pairs(writeDetails) do details[#details+1]=key.."="..count end
 check(writes==0 and #fixture.S.nodes==nodes,"stable settings rows repeated native geometry writes or allocated objects: "..table.concat(details,", "))
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
