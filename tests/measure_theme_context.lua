-- Actual API costs using the product default schema. Diagnostic GC is isolated
-- to this process; no production GC settings or game state are changed.
-- Run from product worktree: lua tests/measure_theme_context.lua
-- Uses the embedded library through ui_fixture.
local f=dofile("tests/ui_fixture.lua")("enUS");local L=LycheeUI
local options={};for key,value in pairs(f.U.context.options) do options[key]=value end
options.theme=f.A.Appearance:GetTheme("main");options.themeDefaults=f.A.StyleDefaults.main
local calls,themeAlloc=0,0;local resolve=L.ResolveTheme
L.ResolveTheme=function(...)
 local before=collectgarbage("count");local value=resolve(...);calls=calls+1;themeAlloc=themeAlloc+collectgarbage("count")-before;return value
end
collectgarbage("collect");collectgarbage("stop");local before=collectgarbage("count")
local ctx=L:CreateContext(options);local allocated=collectgarbage("count")-before
collectgarbage("restart");collectgarbage("collect")
print(string.format("contextAllocatedKiB=%.3f contextRetainedKiB=%.3f ResolveCalls=%d ResolveAllocatedKiB=%.3f",allocated,collectgarbage("count")-before,calls,themeAlloc))
for key,value in pairs(f.U.context.Theme) do
 local actual=ctx.Theme[key]
 if type(value)=="table" then for i=1,#value do assert(actual[i]==value[i],"same color "..key) end
 else assert(actual==value,"same theme token "..key) end
end
assert(ctx.fontPath==f.U.context.fontPath and ctx.fontScale==f.U.context.fontScale,"independent live font policy")
ctx:Hide()
