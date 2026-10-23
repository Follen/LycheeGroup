-- Run from the LycheeGroup product worktree with Lua 5.1:
-- lua tests/measure_font_cost.lua
-- Uses the embedded library through ui_fixture; does not contact the game.
-- GC is stopped only inside each measured transaction, then restarted.
-- Nested counters are inclusive and must not be added to the transaction total.
-- Native substitutes also allocate tables; these are not native-client heap sizes.
local f=dofile('tests/ui_fixture.lua')('enUS');local A,U=f.A,f.U
A:SetSetting('reduceMotion',true)
for _,page in ipairs({'find','create','notes','settings'}) do A:Open(page) end
local ctx,C=U.context,U.C
local stats={};local function spy(object,key)
 local fn=object[key];object[key]=function(...)
  local before=collectgarbage('count');local result=fn(...)
  local row=stats[key] or {n=0,kb=0};stats[key]=row;row.n=row.n+1;row.kb=row.kb+collectgarbage('count')-before
  return result
 end
end
for _,key in ipairs({'RefreshFontRules','SetFont'}) do spy(ctx,key) end
for _,key in ipairs({'RefreshFonts','RefreshLayouts'}) do spy(C,key) end
local function measure(label,fn)
 stats={};collectgarbage('collect');collectgarbage('stop');local before=collectgarbage('count');fn();local delta=collectgarbage('count')-before;collectgarbage('restart')
 print(label,string.format('%.2f KiB',delta));local keys={};for key in pairs(stats) do keys[#keys+1]=key end;table.sort(keys);for _,key in ipairs(keys) do print(key,stats[key].n,string.format('%.2f',stats[key].kb)) end
end
measure('direct SetFont 100-130-100',function() ctx:SetFont(ctx.Theme.font,1.3);ctx:SetFont(ctx.Theme.font,1) end)
measure('public setting 100-130-100',function() A:SetSetting('fontScale',130);A:SetSetting('fontScale',100) end)
