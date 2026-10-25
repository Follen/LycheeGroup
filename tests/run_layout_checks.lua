-- Standalone UI geometry, rendering and lifetime checks, separate from the business runner.
-- Run from the repository root: lua tests/run_layout_checks.lua
local names={"font_layout","find_filter_layout","notes_layout","blocked_layout","settings_sections","settings_responsive","application_notice_layout","find_member_size","product_components","product_layout","element_layout","element_refresh","find_elements","find_pool","floating_pool","result_row_details","applicant_hover"}
local failures=0
for _,name in ipairs(names) do
 local ok,err=pcall(dofile,"tests/test_"..name..".lua")
 if ok then print("[PASS] "..name)
 else failures=failures+1;print("[FAIL] "..name..": "..tostring(err)) end
end
print(("UI geometry: %d scripts passed, %d failed"):format(#names-failures,failures))
os.exit(failures==0 and 0 or 1)
