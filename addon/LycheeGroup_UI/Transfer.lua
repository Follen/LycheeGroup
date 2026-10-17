-- LN- 记录文本编解码:Encode(records) → "LN-"..base64(json);Decode(text) → records|nil,错误键。
-- 纯 Lua、零 WoW API,可离线 require 测试。序列化与 Base64 语义对齐 LycheeNote
-- (字符串转义 \\ \" \n \r;数组/对象;标准表 + padding;非法输入返回 nil + "invalidData")。
local A = _G.LycheeGroup
if not A then A = {}; _G.LycheeGroup = A end
local UI = A.UI
if not UI then UI = {}; A.UI = UI end

local Transfer = {}
UI.Transfer = Transfer

local PREFIX = "LN-"
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64BYTES, B64REV = {}, {}
for i = 1, #B64 do
	local byte = B64:byte(i)
	B64BYTES[i - 1], B64REV[byte] = byte, i - 1
end
local BLOCK_SIZE = 512 -- Reuse this many output slots per block, not one per byte.
local MAX_DEPTH = 64 -- 解析深度上限:合法记录只有三层,超出按无效处理

-- ---------------------------------------------------------------- JSON

local function EscapeString(s)
	return '"' .. (s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) .. '"'
end

local function SerializeValue(v)
	local kind = type(v)
	if kind == "string" then
		return EscapeString(v)
	elseif kind == "number" or kind == "boolean" then
		return tostring(v)
	elseif kind == "table" then
		return Transfer.Serialize(v)
	end
	return '""'
end

-- 顺序整数键为 true 时输出数组,否则输出对象;键名按字符串转义。
function Transfer.Serialize(t)
	local isArray, maxIndex, count = true, 0, 0
	for k in pairs(t) do
		count = count + 1
		if type(k) == "number" and k == math.floor(k) and k > 0 then
			if k > maxIndex then maxIndex = k end
		else
			isArray = false
			break
		end
	end
	if isArray and count == maxIndex then
		local out = { "[" }
		for index = 1, maxIndex do
			if index > 1 then out[#out + 1] = "," end
			out[#out + 1] = SerializeValue(t[index])
		end
		out[#out + 1] = "]"
		return table.concat(out)
	end
	local out, first = { "{" }, true
	for k, v in pairs(t) do
		if not first then out[#out + 1] = "," end
		first = false
		out[#out + 1] = EscapeString(tostring(k)) .. ":" .. SerializeValue(v)
	end
	out[#out + 1] = "}"
	return table.concat(out)
end

local function SkipSpace(s, pos)
	return s:find("%S", pos) or #s + 1
end

local ParseValue -- 前置声明:递归下降解析

local function ParseString(s, pos)
	local start = pos + 1
	local stop = s:find('["\\]', start)
	if not stop then return nil, pos end
	-- Most fields contain no escapes. Keep the full UTF-8 slice without a byte table.
	if s:byte(stop) == 34 then return s:sub(start, stop - 1), stop + 1 end
	local value = {}
	while stop do
		if stop > start then value[#value + 1] = s:sub(start, stop - 1) end
		if s:byte(stop) == 34 then return table.concat(value), stop + 1 end
		local nextChar = s:sub(stop + 1, stop + 1)
		if nextChar == "" then return nil, pos end
		value[#value + 1] = (nextChar == "n" and "\n") or (nextChar == "r" and "\r") or nextChar
		start = stop + 2
		stop = s:find('["\\]', start)
	end
	return nil, pos
end

ParseValue = function(s, pos, depth)
	if depth > MAX_DEPTH then return nil, pos end
	pos = SkipSpace(s, pos)
	if pos > #s then return nil, pos end
	local c = s:sub(pos, pos)
	if c == '"' then
		return ParseString(s, pos)
	elseif c == "[" then
		local array = {}
		pos = SkipSpace(s, pos + 1)
		if pos <= #s and s:sub(pos, pos) == "]" then return array, pos + 1 end
		while pos <= #s do
			local value, newPos = ParseValue(s, pos, depth + 1)
			if value == nil then return nil, pos end
			array[#array + 1] = value
			pos = SkipSpace(s, newPos)
			if pos <= #s and s:sub(pos, pos) == "]" then return array, pos + 1 end
			if pos <= #s and s:sub(pos, pos) == "," then
				pos = SkipSpace(s, pos + 1)
			else
				return nil, pos
			end
		end
		return nil, pos
	elseif c == "{" then
		local obj = {}
		pos = SkipSpace(s, pos + 1)
		if pos <= #s and s:sub(pos, pos) == "}" then return obj, pos + 1 end
		while pos <= #s do
			local key, newPos = ParseValue(s, pos, depth + 1)
			if type(key) ~= "string" then return nil, pos end
			pos = SkipSpace(s, newPos)
			if pos > #s or s:sub(pos, pos) ~= ":" then return nil, pos end
			local value, newPos2 = ParseValue(s, pos + 1, depth + 1)
			if value == nil then return nil, pos end
			obj[key] = value
			pos = SkipSpace(s, newPos2)
			if pos <= #s and s:sub(pos, pos) == "}" then return obj, pos + 1 end
			if pos <= #s and s:sub(pos, pos) == "," then
				pos = SkipSpace(s, pos + 1)
			else
				return nil, pos
			end
		end
		return nil, pos
	end
	-- 字面量:true/false/null/数字;其余按原文字符串保留(容错)。
	local endPos = s:find("[%s,}%]]", pos) or #s + 1
	local literal = s:sub(pos, endPos - 1)
	if literal == "true" then return true, endPos end
	if literal == "false" then return false, endPos end
	if literal == "null" then return nil, endPos end
	return tonumber(literal) or literal, endPos
end

-- ---------------------------------------------------------------- Base64

local function EncodeBase64(data)
	local out, block, used = {}, {}, 0
	for i = 1, #data, 3 do
		local b1, b2, b3 = data:byte(i, i + 2)
		local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
		used = used + 1
		block[used] = string.char(B64BYTES[math.floor(n / 262144)], B64BYTES[math.floor(n / 4096) % 64],
			b2 and B64BYTES[math.floor(n / 64) % 64] or 61, b3 and B64BYTES[n % 64] or 61)
		if used == BLOCK_SIZE then
			out[#out + 1] = table.concat(block, "", 1, used)
			used = 0
		end
	end
	if used > 0 then out[#out + 1] = table.concat(block, "", 1, used) end
	return table.concat(out)
end

local function DecodeBase64(payload)
	-- Decode() has already validated the alphabet and trailing padding.
	local length = (payload:find("=", 1, true) or #payload + 1) - 1
	local out, block, used = {}, {}, 0
	local full = length - length % 4
	for i = 1, full, 4 do
		local a, b, c, d = payload:byte(i, i + 3)
		local n = B64REV[a] * 262144 + B64REV[b] * 4096 + B64REV[c] * 64 + B64REV[d]
		used = used + 1
		block[used] = string.char(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256)
		if used == BLOCK_SIZE then
			out[#out + 1] = table.concat(block, "", 1, used)
			used = 0
		end
	end
	local remaining = length - full
	if remaining >= 2 then
		local a, b, c = payload:byte(full + 1, length)
		local first = B64REV[a] * 4 + math.floor(B64REV[b] / 16)
		used = used + 1
		block[used] = remaining == 3 and string.char(first, B64REV[b] % 16 * 16 + math.floor(B64REV[c] / 4)) or string.char(first)
	end
	if used > 0 then out[#out + 1] = table.concat(block, "", 1, used) end
	return table.concat(out)
end

-- ---------------------------------------------------------------- 对外入口

function Transfer.Encode(records)
	if type(records) ~= "table" then records = {} end
	return PREFIX .. EncodeBase64(Transfer.Serialize(records))
end

-- 非法输入统一返回 nil + "invalidData"(UI.L 键),不区分失败细节。
function Transfer.Decode(text)
	if type(text) ~= "string" then return nil, "invalidData" end
	text = text:match("^%s*(.-)%s*$")
	if text:sub(1, #PREFIX) ~= PREFIX then return nil, "invalidData" end
	local payload = text:sub(#PREFIX + 1)
	if payload == "" or not payload:match("^[A-Za-z0-9+/]*=*$") then return nil, "invalidData" end
	local raw = DecodeBase64(payload)
	if not raw or raw == "" then return nil, "invalidData" end
	local records, nextPos = ParseValue(raw, 1, 1)
	if type(records) ~= "table" then return nil, "invalidData" end
	if SkipSpace(raw, nextPos or 1) <= #raw then return nil, "invalidData" end
	return records
end
