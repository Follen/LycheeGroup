-- Offline behavior test entry: run with a Lua 5.1 interpreter:
--   lua tests/runner.lua            (runs every known module)
--   lua tests/runner.lua core notes (runs selected modules only)
-- Business logic and UI controllers use offline substitutes; passing these
-- proves nothing about in-game API permissions, rendering or event ordering.
local ALL = { "core", "native_queue", "configuration", "appearance", "theme_reload", "notes", "group", "transfer", "ui", "resize", "table_find", "table_create", "table_notes", "filters", "auto_apply", "party_role_check", "preview", "applicant_time", "floating", "seui", "brand_motion", "minimap", "fonts" }

local requested = {}
local known = {}
for _, name in ipairs(ALL) do known[name] = true end
for i = 1, #arg do
	local name = arg[i]
	if not known[name] then
		io.stderr:write(("Unknown test module: %s\nAvailable modules: %s\n"):format(name, table.concat(ALL, ", ")))
		os.exit(2)
	end
	requested[name] = true
end

local names = {}
for _, name in ipairs(ALL) do
	if next(requested) == nil or requested[name] then names[#names + 1] = name end
end

-- ---------------------------------------------------------------- asserts

local report = { passed = 0, failed = 0, failures = {} }

local function where(info)
	if type(info) == "string" and info ~= "" then return " - " .. info end
	return ""
end

local function tostringDeep(value)
	if type(value) == "table" then
		local parts = {}
		for k, v in pairs(value) do
			parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return tostring(value)
end

T = {}

function T.eq(actual, expected, info)
	if actual ~= expected then
		error(("eq failed: expected %s, got %s%s"):format(tostringDeep(expected), tostringDeep(actual), where(info)), 2)
	end
	report.passed = report.passed + 1
end

function T.same(actual, expected, info)
	if actual == expected then return T.eq(actual, expected, info) end
	if type(actual) ~= "table" or type(expected) ~= "table" then
		return T.eq(actual, expected, info)
	end
	local seen = {}
	for k, v in pairs(expected) do
		seen[k] = true
		T.same(actual[k], v, "key " .. tostring(k) .. where(info))
	end
	for k in pairs(actual) do
		if not seen[k] then
			error(("unexpected key %s%s"):format(tostring(k), where(info)), 2)
		end
	end
	report.passed = report.passed + 1
end

function T.ok(value, info)
	if not value then
		error(("ok failed: got %s%s"):format(tostring(value), where(info)), 2)
	end
	report.passed = report.passed + 1
end

function T.near(actual, expected, tolerance, info)
	if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
		error(("near failed: expected %s+/-%s, got %s%s"):format(tostring(expected), tostring(tolerance), tostring(actual), where(info)), 2)
	end
	report.passed = report.passed + 1
end

-- 加载插件文件(替身已写入 _G)。
Load = {}
function Load.file(path)
	local chunk = assert(loadfile(path), path .. " cannot load")
	chunk()
end

function Load.addon(packageName, file)
	Load.file(("addon/%s/%s"):format(packageName, file))
end

-- ---------------------------------------------------------------- run

dofile("tests/stubs.lua")
assert(type(_G.TestStubs) == "table", "tests/stubs.lua must define TestStubs")

for _, name in ipairs(names) do
	local chunk, err = loadfile(("tests/test_%s.lua"):format(name))
	if not chunk then
		report.failed = report.failed + 1
		report.failures[#report.failures + 1] = ("%s: load failed %s"):format(name, tostring(err))
		print(("[SKIP] %s: %s"):format(name, tostring(err)))
	else
		local ok, runErr = pcall(chunk)
		if ok then
			print(("[PASS] %s"):format(name))
		else
			report.failed = report.failed + 1
			report.failures[#report.failures + 1] = ("%s: %s"):format(name, tostring(runErr))
			print(("[FAIL] %s: %s"):format(name, tostring(runErr)))
		end
	end
end

print(("TOTAL: %d asserts passed, %d modules failed"):format(report.passed, report.failed))
for _, message in ipairs(report.failures) do
	print("  " .. message)
end
os.exit(report.failed == 0 and 0 or 1)
