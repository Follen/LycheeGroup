-- Transfer LN- 编解码:往返、与独立工具生成的记录串互通、非法输入与深度守卫。
-- 纯 Lua 无 WoW API,直接装载。
Load.file("addon/LycheeGroup_UI/Transfer.lua")

local Transfer = _G.LycheeGroup.UI.Transfer

-- ---------------------------------------------------------------- 往返

do
	local records = {
		{ name = "艾莉安娜", server = "晨风号角", timestamp = 1730000000, reason = "坦克很强", classSpec = "战士-武器" },
		{ name = "Bob", server = "SilverHand", timestamp = 1, reason = "", classSpec = "" },
	}
	local text = Transfer.Encode(records)
	T.eq(text:sub(1, 3), "LN-", "导出带 LN- 前缀")
	local decoded = Transfer.Decode(text)
	T.eq(type(decoded), "table", "可解回表")
	T.eq(#decoded, 2, "数组长度一致")
	T.eq(decoded[1].name, "艾莉安娜", "中文名往返")
	T.eq(decoded[1].server, "晨风号角", "中文服务器往返")
	T.eq(decoded[1].timestamp, 1730000000, "数字往返")
	T.eq(decoded[2].reason, "", "空字符串往返")
end

do
	-- 特殊字符:引号、反斜杠、换行。
	local tricky = '多行\n带"引号"和\\反斜杠 end'
	local text = Transfer.Encode({ { name = "X", server = "S", timestamp = 5, reason = tricky, classSpec = "c" } })
	local decoded = Transfer.Decode(text)
	T.eq(decoded[1].reason, tricky, "转义字符往返")
end

do
	-- 字面量类型与对象/数组嵌套。
	local text = Transfer.Encode({ { flag = true, off = false, n = 1.5, inner = { "a", "b" } } })
	local decoded = Transfer.Decode(text)
	T.eq(decoded[1].flag, true)
	T.eq(decoded[1].off, false)
	T.eq(decoded[1].n, 1.5)
	T.eq(decoded[1].inner[2], "b", "嵌套数组")
end

-- ---------------------------------------------------------------- 独立互通向量

-- 由 node(JSON.stringify + Buffer.base64)独立生成,非本模块自产,验证与 LN- 生态互通。
do
	local vector = "LN-W3sibmFtZSI6IuiJvuiOieWuieWonCIsInNlcnZlciI6IuaZqOmjjuWPt+inkiIsInRpbWVzdGFtcCI6MTczMDAwMDAwMCwicmVhc29uIjoi5Z2m5YWL5b6I5by6XG7luKblvJXlj7dcInhcIuWSjOWPjeaWnOadoFxcIiwiY2xhc3NTcGVjIjoi5oiY5aOrLeatpuWZqCJ9XQ=="
	local decoded = Transfer.Decode(vector)
	T.eq(type(decoded), "table", "独立向量可解码")
	T.eq(decoded[1].name, "艾莉安娜")
	T.eq(decoded[1].reason, "坦克很强\n带引号\"x\"和反斜杠\\", "转义语义一致")
	T.eq(decoded[1].timestamp, 1730000000)
end

-- ---------------------------------------------------------------- 非法输入

do
	local bad = {
		"",
		"   ",
		"LN-",
		"垃圾文本",
		"LN-!!!!",
		"LN-" .. ("A"):rep(10),     -- base64 合法但解不出 JSON
		"LN-QVxB",                  -- "AxP"? 解出非 JSON 文本
		"W3sibmFtZSI6IkJvYiJ9XQ==", -- 缺少前缀的合法数据
	}
	for index, text in ipairs(bad) do
		local records, err = Transfer.Decode(text)
		T.eq(records, nil, "非法输入#" .. index .. " 返回 nil")
		T.eq(err, "invalidData", "非法输入#" .. index .. " 错误键")
	end
end

do
	-- 截断 JSON:数组未闭合。
	local records, err = Transfer.Decode("LN-W3sibmFtZSI6IkJvYiJ9")
	T.eq(records, nil, "截断 JSON 拒绝")
	T.eq(err, "invalidData")
end

do
	-- 深度守卫:64 层以上嵌套按无效处理,不栈溢出;60 层以内可正常解析。
	-- 两个向量均由 node 独立生成。
	local tooDeep = "LN-W1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW11dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV0="
	local records, err = Transfer.Decode(tooDeep)
	T.eq(records, nil, "100 层嵌套按无效处理")
	T.eq(err, "invalidData")

	local okDepth = "LN-W1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW1tbW11dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV0="
	T.eq(type(Transfer.Decode(okDepth)), "table", "60 层嵌套正常解析")
end

do
	-- 尾随空白容错:整串前后空白不应导致失败。
	local text = "  " .. Transfer.Encode({ { name = "A", server = "B", timestamp = 1, reason = "r", classSpec = "" } }) .. "  "
	local decoded = Transfer.Decode(text)
	T.eq(type(decoded), "table", "前后空白可容忍")
	T.eq(decoded[1].name, "A")
end

do
	-- Independent Base64 padding cases, including the existing unpadded input.
	for _,case in ipairs({{"a","LN-WyJhIl0="},{"ab","LN-WyJhYiJd"},{"abc","LN-WyJhYmMiXQ=="}}) do
		T.eq(Transfer.Encode({case[1]}),case[2],"Base64 尾部字节与独立向量一致")
		T.eq(Transfer.Decode(case[2])[1],case[1],"独立 Base64 向量解码")
	end
	T.eq(Transfer.Decode("LN-WyJhYmMiXQ")[1],"abc","保留无 padding 输入支持")
end

do
	-- Long strings cross multiple Base64 blocks and keep escape boundaries intact.
	local text=string.rep("中文长备注",400)..'\\末尾\\\\带"引号"\n换行\r回车'
	for suffix=0,2 do
		local records={{name="分块测试",reason=text..string.rep("x",suffix)}, {name="结束",reason=""}}
		local decoded=Transfer.Decode(Transfer.Encode(records))
		T.eq(#decoded,2,"长记录完整解码")
		T.eq(decoded[1].reason,records[1].reason,"跨块 UTF-8 与转义字符保持原样")
		T.eq(decoded[2].reason,"","长记录后的空字符串保持原样")
	end
end

do
	-- Python base64 over the exact JSON below supplies an independent wire
	-- vector; the public serialization format remains unchanged.
	local values = { true, false, 1.5, '中文\n"\\\r', {} }
	T.eq(Transfer.Serialize(values), '[true,false,1.5,"中文\\n\\"\\\\\\r",[]]')
	T.eq(Transfer.Encode(values), "LN-W3RydWUsZmFsc2UsMS41LCLkuK3mlodcblwiXFxcciIsW11d")
	local plain, padded = "LN-WyJhYmMiXQ", "LN-WyJhYmMiXQ=="
	for _,text in ipairs({ plain, padded, plain .. "=====", " \t\r\n" .. padded .. " \r\n\t" }) do
		T.eq(Transfer.Decode(text)[1], "abc", "offset decoding preserves whitespace and permissive padding")
	end
	for _,text in ipairs({ plain .. "==A", plain .. "=A=", "LN-WyJh\nYmMiXQ==", plain .. "汉", plain .. "== \n A", " \t LN- == \r\n" }) do
		local records,err = Transfer.Decode(text)
		T.eq(records,nil,"invalid characters inside the payload are not trailing whitespace")
		T.eq(err,"invalidData")
	end
end

do
	-- Plain strings emit three fragments; escaped strings retain the C gsub
	-- path as one fragment. These sizes straddle both 512-slot boundaries.
	local plain,escaped = "中文原文", '中文\n"\\\r'
	for _,case in ipairs({{plain,'"中文原文"'},{escaped,'"中文\\n\\"\\\\\\r"'}}) do
		local value,quoted = case[1],case[2]
		for _,count in ipairs({127,128,129,255,256,257,511,512,513}) do
			local values = {}
			for i=1,count do values[i]=value end
			local expected = "[" .. string.rep(quoted .. ",",count-1) .. quoted .. "]"
			T.eq(Transfer.Serialize(values),expected,"shared serialization blocks preserve exact boundary bytes")
			local decoded = Transfer.Decode(Transfer.Encode(values))
			T.eq(#decoded,count);T.eq(decoded[1],value);T.eq(decoded[count],value)
		end
	end
	local records = {}
	for i=1,128 do records[i]={reason=escaped} end
	local one = '{"reason":"中文\\n\\"\\\\\\r"}'
	T.eq(Transfer.Serialize(records),"["..string.rep(one..",",127)..one.."]","nested tables share the emitter without per-level formatting changes")
end

do
	-- Independent byte/bit accumulator checks the exact wire bytes across the
	-- serialization fragment and numeric output-buffer boundaries.
	local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local function ReferenceBase64(text)
		local out,acc,bits={},0,0
		for index=1,#text do
			acc,bits=acc*256+text:byte(index),bits+8
			while bits>=6 do
				bits=bits-6
				local divisor=2^bits
				local value=math.floor(acc/divisor)
				out[#out+1]=alphabet:sub(value+1,value+1);acc=acc%divisor
			end
		end
		if bits>0 then local value=acc*2^(6-bits);out[#out+1]=alphabet:sub(value+1,value+1) end
		while #out%4~=0 do out[#out+1]="=" end
		return "LN-"..table.concat(out)
	end
	local bytes={};for value=0,255 do bytes[#bytes+1]=string.char(value) end
	local binary=table.concat(bytes)
	for _,length in ipairs({0,1,2,3,127,128,129,255,256,257,383,384,385,511,512,513,1023,1024,1025}) do
		local value=(binary..binary..binary..binary..binary):sub(1,length)
		local records={value,reason="跨块\\\"\n\r",nested={true,false,17.25}}
		T.eq(Transfer.Encode(records),ReferenceBase64(Transfer.Serialize(records)),"binary values preserve exact streamed wire bytes")
		T.eq(Transfer.Decode(Transfer.Encode({value}))[1],value,"binary decode buffer boundary")
	end
	for count=124,132 do
		local records={};for index=1,count do records[index]=index%2==0 and "中文\n" or "plain"..index end
		T.eq(Transfer.Encode(records),ReferenceBase64(Transfer.Serialize(records)),"serialization chunk tail carries between writes")
	end
	local nestedText
	local key=setmetatable({}, {__tostring=function()
		nestedText=Transfer.Encode({"nested"});return "outer"
	end})
	local outer=Transfer.Encode({[key]="value"})
	T.eq(nestedText,ReferenceBase64('["nested"]'),"nested encoding owns independent buffers")
	T.eq(outer,ReferenceBase64('{"outer":"value"}'),"outer buffers survive nested serialization")
	local bad=setmetatable({}, {__tostring=function() error("serialization callback failure") end})
	T.eq(pcall(Transfer.Encode,{[bad]=true}),false,"serialization failure propagates")
	T.eq(Transfer.Encode({"after failure"}),ReferenceBase64('["after failure"]'),"later encoding has no partial prior state")
end

_G.LycheeGroup = nil
