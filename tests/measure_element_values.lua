-- Run from the product worktree: lua tests/measure_element_values.lua
-- Uses the embedded library through ui_fixture; does not contact the game.
local f=dofile('tests/ui_fixture.lua')('zhCN');local A,U=f.A,f.U
A:SetSetting('reduceMotion',true)
for _,page in ipairs({'find','create','notes','settings'}) do A:Open(page) end
local calls,allocated=0,0;local value=U.C.ElementValue
U.C.ElementValue=function(...) local before=collectgarbage('count');local result=value(...);allocated=allocated+collectgarbage('count')-before;calls=calls+1;return result end
collectgarbage('collect');collectgarbage('stop');A:SetSetting('fontScale',130);for _,page in ipairs({'find','create','notes','settings'}) do A:Open(page) end;collectgarbage('restart')
print('ElementValue no-overrides:',calls,'calls',allocated,'KiB')
assert(allocated<1,'default measurement must not create per-read closure/state tables')
