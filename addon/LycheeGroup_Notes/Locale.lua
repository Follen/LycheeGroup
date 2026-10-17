-- 玩家记录包文案:仅本包业务(提醒模板、Add 错误)所需的 zhCN/enUS 字符串。
-- 本文件先于 Notes.lua 加载,表挂在 A.NotesLocale,由 Notes.lua 转挂到 Notes.L。
local A = _G.LycheeGroup
local zh = GetLocale() == "zhCN"
local function choose(cn, en) return zh and cn or en end

A.NotesLocale = {
	-- 入队提醒:名字、理由;结尾空格用于衔接"查看记录"链接。
	rosterHit = choose("队伍中的 %s 有记录:%s ", "%s in your group has a note: %s "),
	inviteReceived = choose("邀请你组队的 %s 有记录:%s ", "%s is inviting you to a group and has a note: %s "),
	inviteSent = choose("你邀请的 %s 有记录:%s ", "%s, whom you are inviting, has a note: %s "),
	-- Add 错误文案:作为 errText 返回,由调用方(命令/界面)展示;本包不打印。
	selfRecord = choose("不能记录自己。", "You cannot record yourself."),
	badIdentity = choose("无法解析玩家身份。", "Could not resolve the player's identity."),
}
