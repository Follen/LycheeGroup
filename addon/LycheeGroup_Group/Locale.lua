-- 组队业务文案:错误文本与供 UI 呈现的业务字符串;仅构造当前语言一份。
local A = _G.LycheeGroup
local zh = A:GetLocale() == "zhCN"
local function choose(cn, en) return zh and cn or en end

A.GroupLocale = {
	-- 通用
	invalidAction = choose("当前状态无法执行此操作。", "This action is not available right now."),
	actionBusy = choose("上一个操作仍在等待游戏确认。", "The previous action is still awaiting confirmation."),
	invalidActivity = choose("请选择有效的活动。", "Choose a valid activity."),
	callbackError = choose("界面回调出错:%s", "Interface callback error: %s"),

	-- 搜索
	searchRestricted = choose("搜索需要在直接点击操作中发起。", "Search must be started from a direct click."),
	searchQueued = choose("已保留最新选择，等待当前搜索结束。", "Your latest selection will be searched after the current request finishes."),
	searchThrottled = choose("搜索过于频繁，等待 %d 秒后自动继续最新选择。", "Search is being throttled. Your latest selection will resume automatically after %d seconds."),
	searchTimeout = choose("搜索响应超时，请稍后重试。", "The search timed out. Please try again later."),
	searchFailed = choose("本次搜索未完成，请稍后重试。", "The search did not complete. Please try again later."),
	seasonDungeon = choose("赛季地下城", "Season Dungeons"),
	seasonRaid = choose("赛季团本", "Season Raids"),
	recruiting = choose("正在招募，结束招募后可申请其他队伍。", "End your listing before applying to another group."),
	applicationLimit = choose("已有 5 个有效申请，请先处理其中一个。", "You have 5 active applications. Resolve one before applying again."),

	-- 申请
	alreadyApplied = choose("已经申请过这支队伍。", "You have already applied to this group."),
	applicationCancelled = choose("这条申请已取消，请刷新队伍列表后再次申请。", "This application was cancelled. Refresh the group list before applying again."),
	applyFailed = choose("申请提交失败。", "Could not submit the application."),
	cancelFailed = choose("取消申请失败。", "Could not cancel the application."),
	acceptFailed = choose("接受邀请失败。", "Could not accept the invite."),
	declineFailed = choose("拒绝邀请失败。", "Could not decline the invite."),

	-- 招募
	publishApplications = choose("你还有有效的组队申请，处理完成后才能发布组队。", "You still have active group applications. Resolve them before listing your group."),
	publishFailed = choose("发布组队失败,请检查活动选择与游戏提示。", "Could not list the group; check the activity selection and any game messages."),
	updateFailed = choose("更新组队失败,请检查活动选择与游戏提示。", "Could not update the group; check the activity selection and any game messages."),
	removeFailed = choose("结束招募失败。", "Could not delist the group."),
	noActiveListing = choose("当前没有进行中的招募。", "You have no active listing."),
	listingPermission = choose("只有队长或团长可以发布、修改或结束招募。", "Only the group leader can list, edit or delist the group."),

	-- 申请者
	groupFull = choose("当前队伍没有足够名额邀请整批申请者。", "There is not enough room for this applicant party."),
	inviteFailed = choose("邀请失败。", "Could not invite."),
	declineApplicantFailed = choose("拒绝申请失败。", "Could not decline the applicant."),
	applicantPermission = choose("只有队长、团长或团队助理可以邀请或拒绝申请者。", "Only the group leader or raid assistants can invite or decline applicants."),
}
