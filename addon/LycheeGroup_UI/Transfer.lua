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
local BLOCK_SIZE = 512 -- Bounded reusable fragments instead of a full-output slot array.
local MAX_DEPTH = 64 -- 解析深度上限:合法记录只有三层,超出按无效处理

-- ---------------------------------------------------------------- JSON

local ESCAPES = { ['\\'] = '\\\\', ['"'] = '\\"', ['\n'] = '\\n', ['\r'] = '\\r' }
local function EscapeString(s) return '"' .. s:gsub('[\\"\n\r]', ESCAPES) .. '"' end

-- 顺序整数键为 true 时输出数组,否则输出对象;键名按字符串转义。
local function Serialize(t, write)
	local out, block, used = not write and {}, {}, 0
	local function Flush()
		local chunk = table.concat(block, "", 1, used)
		if write then write(chunk) else out[#out + 1] = chunk end
		used = 0
	end
	local function Emit(value)
		used = used + 1
		block[used] = value
		if used == BLOCK_SIZE then
			Flush()
		end
	end
	local function String(value)
		if value:find('[\\"\n\r]') then Emit(EscapeString(value))
		else Emit('"');Emit(value);Emit('"') end
	end
	local Table
	local function Value(value)
		local kind = type(value)
		if kind == "string" then String(value)
		elseif kind == "number" or kind == "boolean" then Emit(tostring(value))
		elseif kind == "table" then Table(value)
		else Emit('""') end
	end
	Table = function(value)
		local isArray, maxIndex, count = true, 0, 0
		for key in pairs(value) do
			count = count + 1
			if type(key) == "number" and key == math.floor(key) and key > 0 then
				if key > maxIndex then maxIndex = key end
			else isArray = false;break end
		end
		if isArray and count == maxIndex then
			Emit("[")
			for index = 1, maxIndex do
				if index > 1 then Emit(",") end
				Value(value[index])
			end
			Emit("]")
		else
			Emit("{")
			local first = true
			for key, item in pairs(value) do
				if not first then Emit(",") end
				first = false
				String(tostring(key));Emit(":");Value(item)
			end
			Emit("}")
		end
	end
	Table(t)
	if used > 0 then Flush() end
	if not write then return table.concat(out) end
end
function Transfer.Serialize(t) return Serialize(t) end

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

local function EncodeBase64(records)
	local out, block, used = { PREFIX }, {}, 0
	local char, floor, byte = string.char, math.floor, string.byte
	local tail = ""
	local function Write(data, final)
		-- Serialization chunks may end inside a three-byte group. Carry only
		-- its final one or two bytes, and emit padding once at the true end.
		if tail ~= "" then data = tail .. data end
		local limit = final and #data or #data - #data % 3
		for i = 1, limit, 3 do
			local b1, b2, b3 = byte(data, i, i + 2)
			local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
			used = used + 1
			block[used] = char(B64BYTES[floor(n / 262144)], B64BYTES[floor(n / 4096) % 64],
				b2 and B64BYTES[floor(n / 64) % 64] or 61, b3 and B64BYTES[n % 64] or 61)
			if used == BLOCK_SIZE then
				out[#out + 1] = table.concat(block, "", 1, used)
				used = 0
			end
		end
		tail = data:sub(limit + 1)
	end
	Serialize(records, Write)
	if tail ~= "" then Write("", true) end
	if used > 0 then out[#out + 1] = table.concat(block, "", 1, used) end
	return table.concat(out)
end

local function DecodeBase64(payload, first, last)
	-- Decode() has already validated the alphabet and trailing padding.
	local padding = payload:find("=", first, true)
	local length = (padding and padding <= last and padding or last + 1) - first
	local out, block, used = {}, {}, 0
	local char, floor, byte = string.char, math.floor, string.byte
	local full = length - length % 4
	for i = 1, full, 4 do
		local a, b, c, d = byte(payload, first + i - 1, first + i + 2)
		local n = B64REV[a] * 262144 + B64REV[b] * 4096 + B64REV[c] * 64 + B64REV[d]
		block[used + 1], block[used + 2], block[used + 3] = floor(n / 65536), floor(n / 256) % 256, n % 256
		used = used + 3
		if used == 384 then -- 128 input groups, bounded native char/unpack call.
			out[#out + 1] = char(unpack(block, 1, used))
			used = 0
		end
	end
	local remaining = length - full
	if remaining >= 2 then
		local a, b, c = payload:byte(first + full, first + length - 1)
		local first = B64REV[a] * 4 + math.floor(B64REV[b] / 16)
		used = used + 1
		block[used] = first
		if remaining == 3 then used = used + 1;block[used] = B64REV[b] % 16 * 16 + floor(B64REV[c] / 4) end
	end
	if used > 0 then out[#out + 1] = char(unpack(block, 1, used)) end
	return table.concat(out)
end

-- ---------------------------------------------------------------- 对外入口

function Transfer.Encode(records)
	if type(records) ~= "table" then records = {} end
	return EncodeBase64(records)
end

-- 非法输入统一返回 nil + "invalidData"(UI.L 键),不区分失败细节。
function Transfer.Decode(text)
	if type(text) ~= "string" then return nil, "invalidData" end
	-- Validate a slice of the input, avoiding full-size trim/alphabet captures
	-- and the extra payload substring before decoding it into bounded blocks.
	local start = text:find("%S")
	if not start or text:sub(start, start + #PREFIX - 1) ~= PREFIX then return nil, "invalidData" end
	local first = start + #PREFIX
	local _, last = text:find("^[A-Za-z0-9+/]*=*", first)
	if not last or last < first or text:find("%S", last + 1) then return nil, "invalidData" end
	local raw = DecodeBase64(text, first, last)
	if not raw or raw == "" then return nil, "invalidData" end
	local records, nextPos = ParseValue(raw, 1, 1)
	if type(records) ~= "table" then return nil, "invalidData" end
	if SkipSpace(raw, nextPos or 1) <= #raw then return nil, "invalidData" end
	return records
end
