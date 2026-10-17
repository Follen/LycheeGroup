-- Narrow engine substitute for the pinned LFGListApplicationDialog contract.
-- Install after ui_fixture builds C_LFGList, before loading the UI controllers.
return function(S)
 local dialog=S.New("Frame","LFGListApplicationDialog",UIParent);dialog:SetSize(306,203);dialog:Hide();dialog:EnableMouse(true)
 dialog.Border=S.New("Frame",nil,dialog);dialog.Label=dialog:CreateFontString(nil,"ARTWORK");dialog.Label:SetText("Choose roles")
 dialog.Description=S.New("ScrollFrame","LFGListApplicationDialogDescription",dialog);dialog.Description:SetSize(210,28)
 dialog.Description.EditBox=S.New("EditBox",nil,dialog.Description);dialog.Description.EditBox:SetSize(190,28);dialog.Description.EditBox.secureText=true
 dialog.Description.EditBox:SetScript("OnEnterPressed",function() end)
 for _,key in ipairs({"TankButton","HealerButton","DamagerButton"}) do
  local button=S.New("Button",nil,dialog);button:SetSize(70,70);button:EnableMouse(true)
  button.CheckButton=S.New("CheckButton",nil,button);button.CheckButton:EnableMouse(true);dialog[key]=button
 end
 local function NativeButton(key,text)
  local button=S.New("Button",nil,dialog);button:SetSize(100,22)
  local label=button:CreateFontString(nil,"ARTWORK");label:SetText(text);button.text=text
  function button:GetFontString() return label end
  function button:SetText(value) self.text=tostring(value);label:SetText(value) end
  dialog[key]=button;return button
 end
 NativeButton("SignUpButton","Sign Up");NativeButton("CancelButton","Cancel")
 dialog.available={TANK=true,HEALER=false,DAMAGER=true};dialog.chosen={leader=false,tank=false,healer=false,damage=true};dialog.submissions=0
 _G.GetLFGRoles=function() local r=dialog.chosen;return r.leader,r.tank,r.healer,r.damage end
 _G.SetLFGRoles=function(leader,tank,healer,damage)
  dialog.chosen={leader=leader,tank=tank,healer=healer,damage=damage}
  dialog:Fire("OnEvent","LFG_ROLE_UPDATE")
 end
 C_LFGList.GetSearchResultInfo=function(id) local record=LycheeGroup.Group:GetResult(id);if not record then return nil end;return {activityIDs={record.activityID},isDelisted=record.isDelisted} end
 C_LFGList.GetAvailableRoles=function() local a=dialog.available;return a.TANK,a.HEALER,a.DAMAGER end
 local clear=C_LFGList.ClearApplicationTextFields
 C_LFGList.ClearApplicationTextFields=function() clear();dialog.Description.EditBox:UserType("") end
 C_LFGList.ApplyToGroup=function(id,tank,healer,damage)
  dialog.submissions=dialog.submissions+1
  dialog.submitted={resultID=id,tank=tank,healer=healer,damage=damage,note=dialog.Description.EditBox.text}
 end
 _G.StaticPopupSpecial_Show=function(frame) frame:Show() end
 _G.StaticPopupSpecial_Hide=function(frame) frame:Hide() end
 _G.LFG_LIST_MUST_SELECT_ROLE="You must select a role"
 _G.LFGListApplicationDialog_UpdateValidState=function(frame)
  local valid=(frame.TankButton:IsShown() and frame.TankButton.CheckButton:GetChecked()) or (frame.HealerButton:IsShown() and frame.HealerButton.CheckButton:GetChecked()) or (frame.DamagerButton:IsShown() and frame.DamagerButton.CheckButton:GetChecked())
  frame.SignUpButton:SetEnabled(valid==true);frame.SignUpButton.errorText=not valid and LFG_LIST_MUST_SELECT_ROLE or nil
 end
 _G.LFGListApplicationDialog_UpdateRoles=function(frame)
  local tank,healer,damage=C_LFGList.GetAvailableRoles();local _,t,h,d=GetLFGRoles()
  frame.TankButton:SetShown(tank);frame.HealerButton:SetShown(healer);frame.DamagerButton:SetShown(damage)
  frame.TankButton.CheckButton:SetChecked(t);frame.HealerButton.CheckButton:SetChecked(h);frame.DamagerButton.CheckButton:SetChecked(d)
  LFGListApplicationDialog_UpdateValidState(frame)
 end
 _G.LFGListApplicationDialog_Show=function(frame,resultID)
  local record=LycheeGroup.Group:GetResult(resultID);local activityID=record and record.activityID
  if activityID~=frame.activityID then C_LFGList.ClearApplicationTextFields() end
  frame.resultID=resultID;frame.activityID=activityID
  LFGListApplicationDialog_UpdateRoles(frame);StaticPopupSpecial_Show(frame)
 end
 _G.LFGListApplicationDialogSignUpButton_OnClick=function(button)
  local frame=button:GetParent();assert(frame==dialog,"native submit keeps its original dialog parent")
  C_LFGList.ApplyToGroup(frame.resultID,frame.TankButton:IsShown() and frame.TankButton.CheckButton:GetChecked(),frame.HealerButton:IsShown() and frame.HealerButton.CheckButton:GetChecked(),frame.DamagerButton:IsShown() and frame.DamagerButton.CheckButton:GetChecked())
  StaticPopupSpecial_Hide(frame)
 end
 dialog.SignUpButton:SetScript("OnClick",LFGListApplicationDialogSignUpButton_OnClick)
 dialog.CancelButton:SetScript("OnClick",function(button) StaticPopupSpecial_Hide(button:GetParent()) end)
 dialog:SetScript("OnEvent",function(frame,event) if event=="LFG_ROLE_UPDATE" then LFGListApplicationDialog_UpdateRoles(frame) end end)
 dialog:RegisterEvent("LFG_ROLE_UPDATE")
 return dialog
end
