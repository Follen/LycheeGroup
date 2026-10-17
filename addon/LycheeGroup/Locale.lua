-- 微核心文案:仅入口、加载失败与记录命令所需的少量字符串。
-- 业务包与界面的文案由各自 Locale 维护,不提前进入主包。
local A = _G.LycheeGroup
if not A then
	A = {}
	_G.LycheeGroup = A
end
local zh = GetLocale() == "zhCN"
local function choose(cn, en) return zh and cn or en end

A.L = {
	brand = choose("|cffD53C49荔枝|r组队", "|cffD53C49Lychee|r LFG"),
	reminder = choose("荔枝组队", "Lychee LFG"),
	viewNote = choose("查看记录", "View note"),
	loadFailed = choose("无法加载模块:%s。请检查插件安装。", "Could not load module: %s. Check the addon installation."),
	openFailed = choose("无法打开界面:%s。", "Could not open the interface: %s."),
	selfRecord = choose("不能记录自己。", "You cannot record yourself."),
	invalidName = choose("没有可记录的玩家。", "No player to record."),
	recorded = choose("已记录 %s。", "Recorded %s."),
	recordFailed = choose("记录失败:%s。", "Could not record: %s."),
	noReason = choose("无理由", "No reason"),
	unknownModule = choose("未知模块：%s", "Unknown module: %s"),
	moduleLoading = choose("模块正在加载：%s", "Module is loading: %s"),
	moduleMissing = choose("模块尚未就绪：%s", "Module did not register: %s"),
	recordPlayer = choose("记录玩家", "Record player"),
	removeRecord = choose("取消记录", "Remove note"),
	removed = choose("已移除 %s 的记录。", "Removed the note for %s."),
	cmdUsage = choose("用法:/lg [find|create|notes|settings] 或 /lg note <玩家名> [理由]", "Usage: /lg [find|create|notes|settings] or /lg note <player> [reason]"),
}
