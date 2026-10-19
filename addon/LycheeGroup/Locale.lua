-- 微核心文案:仅入口、加载失败与记录命令所需的少量字符串。
-- 业务包与界面的文案由各自 Locale 维护,不提前进入主包。
local A = _G.LycheeGroup
if not A then
	A = {}
	_G.LycheeGroup = A
end
function A:ResolveLocale(value)
	if value == "zhCN" or value == "enUS" then return value end
	return GetLocale() == "zhCN" and "zhCN" or "enUS"
end
function A:GetLocale() return self.locale end
function A:NeedsLanguageReload() return self:ResolveLocale(self.db.language) ~= self.locale end
-- SavedVariables are available at ADDON_LOADED, after these files execute.
function A:InitializeLocale()
	self.locale = self:ResolveLocale(self.db.language)
	local zh = self.locale == "zhCN"
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
		bindingToggle = choose("打开／关闭荔枝组队", "Toggle Lychee LFG"),
		bindingCurrent = choose("当前按键：%s", "Current key: %s"),
		bindingUnbound = choose("未绑定", "Not bound"),
		bindingChange = choose("修改按键", "Change key"),
		bindingListen = choose("按下新按键，可使用组合键。Esc 取消。", "Press a new key or key combination. Esc cancels."),
		bindingDefaultConflict = choose("默认分号已用于“%s”，已保留原绑定。", "The default semicolon is bound to “%s”; its binding was kept."),
		bindingCancel = choose("取消", "Cancel"),
		bindingCombat = choose("战斗中无法修改按键，请脱战后重试。", "Key bindings cannot be changed in combat. Try again afterward."),
		bindingFailed = choose("无法保存此按键，请选择其他按键。", "Could not save this binding. Choose another key."),
	}

	BINDING_HEADER_LYCHEEGROUP = A.L.reminder
	BINDING_NAME_LYCHEEGROUP_TOGGLE = A.L.bindingToggle
end
