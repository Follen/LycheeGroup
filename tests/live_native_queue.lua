-- Read-only snapshot: no queue actions, settings writes or menu callbacks.
local A, eye = LycheeGroup, QueueStatusButton
assert(A and eye and QueueStatusButtonMixin, "native queue entry is not loaded")
local report = {
    hideSetting = A:GetSetting("nativeLFGEntry"),
    nativeClick = eye:GetScript("OnClick") == QueueStatusButtonMixin.OnClick,
    nativeEnter = eye:GetScript("OnEnter") == QueueStatusButtonMixin.OnEnter,
    nativeLeave = eye:GetScript("OnLeave") == QueueStatusButtonMixin.OnLeave,
    eye = {shown=eye:IsShown(), alpha=eye:GetAlpha(), mouse=eye:IsMouseEnabled()},
    battlefield = {}, world = {}, lfg = {}, leftButtons = {},
}
local role, _, _, _, _, roleBattle = GetLFGRoleUpdate()
local ready, readyBattle = GetLFGReadyCheckUpdate()
report.roleCheck = role and roleBattle or false
report.readyCheck = ready and readyBattle or false
for index = 1, GetMaxBattlefieldID() do
    local status, _, _, _, suspended = GetBattlefieldStatus(index)
    report.battlefield[#report.battlefield+1] = {slot=index, status=status, suspended=suspended}
end
for index = 1, MAX_WORLD_PVP_QUEUES do
    report.world[#report.world+1] = {slot=index, status=GetWorldPVPQueueStatus(index)}
end
for category = 1, NUM_LE_LFG_CATEGORYS do
    local mode, submode = GetLFGMode(category)
    if mode then report.lfg[#report.lfg+1] = {category=category, mode=mode, submode=submode} end
end
local children = {eye:GetChildren()}
for index = 1, math.min(#children, 32) do
    local child = children[index]
    if child:GetObjectType() == "Button" then
        report.leftButtons[#report.leftButtons+1] = {
            shown=child:IsShown(), motion=child:IsMouseMotionEnabled(),
            passthrough={child:GetPassThroughButtons()},
        }
    end
end
report.childrenTruncated = #children > 32
return report
