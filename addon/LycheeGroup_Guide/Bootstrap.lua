-- Loaded by the main package. The UI entry and complete tour stay demand-loaded.
local A=_G.LycheeGroup
local Entry={}
A.GuideEntry=Entry
local function S(cn,en) return A:GetLocale()=="zhCN" and cn or en end
function Entry:HasSeen()
 local saved=A.db and A.db.guide
 return type(saved)=="table" and (saved.welcomeShown==true or saved.dismissed==true or saved.completed==true) or false
end
local function Open(self)
 A:LoadDB()
 local UI,err=A:Ensure("UI");if not UI then return false,err end
 if self.ReleaseShow then self:ReleaseShow() end
 if not self.loadAttempted then
  self.loadAttempted=true
  if not A.Guide then
   local ran,ok,reason=pcall(C_AddOns.LoadAddOn,"LycheeGroup_Guide")
   if not ran then self.loadError=ok;error(ok,0) end
   if not ok then self.loadError=reason or S("无法加载引导。","Unable to load the guide.") end
  end
  if not self.loadError and (not A.Guide or type(A.Guide.Open)~="function") then
   self.loadError=S("引导模块尚未就绪。","The guide module is not ready.")
  end
 end
 if self.loadError then return false,self.loadError end
 local opened,reason=A.Guide:Open()
 if opened then
  local saved=type(A.db.guide)=="table" and A.db.guide or {}
  A.db.guide=saved;saved.welcomeShown=true
 end
 return opened,reason
end
function Entry:Open()
 if self.opening then return false,S("引导正在加载。","The guide is loading.") end
 self.opening=true
 local ok,result,err=pcall(Open,self)
 self.opening=nil
 if not ok then error(result,0) end
 return result,err
end
A.DevCommands=A.DevCommands or {}
A.DevCommands.guide={usage="/lg dev guide",run=function(message)
 if (message or ""):match("%S") then A:Print(S("用法：/lg dev guide","Usage: /lg dev guide"));return end
 local ok,err=Entry:Open()
 if not ok then A:Print(err) end
end}
