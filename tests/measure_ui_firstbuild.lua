-- Natural offline first-build attribution; no GC control and no source changes.
-- Native object substitutions dominate KiB. Counts identify construction scope;
-- they do not establish WoW object bytes or a client saving.
local f=dofile("tests/ui_fixture.lua")("enUS")
local A,U,S=f.A,f.U,f.S
local groups={}
local function Sample(name,run,...)
 local memory,first=collectgarbage("count"),#S.nodes
 local a,b,c=run(...)
 local allocated=collectgarbage("count")-memory
 local row=groups[name] or {calls=0,KiB=0,nodes=0,fonts=0,textures=0,frames=0};groups[name]=row
 row.calls=row.calls+1;row.KiB=row.KiB+allocated;row.nodes=row.nodes+#S.nodes-first
 for index=first+1,#S.nodes do local kind=S.nodes[index]._objectType
  if kind=="FontString" then row.fonts=row.fonts+1 elseif kind=="Texture" or kind=="MaskTexture" then row.textures=row.textures+1 else row.frames=row.frames+1 end
 end
 return a,b,c
end
local function Wrap(owner,key,name)
 local original=owner[key]
 owner[key]=function(...) return Sample(name,original,...) end
end
local settings=U.pages.settings
local build=settings.BuildRow
settings.BuildRow=function(self,parent,row,index)
 local section="unknown";for key,panel in pairs(self.panels) do if panel==parent then section=key;break end end
 return Sample("settings.rows."..section,build,self,parent,row,index)
end
for _,page in ipairs({"find","create","notes","settings"}) do Wrap(U.pages[page],"Build",page..".Build") end
for _,entry in ipairs({{U.pages.find,"BuildFilters"},{U.pages.find,"BuildQuickFilters"},{U.pages.settings,"BuildAbout"}}) do Wrap(entry[1],entry[2],entry[2]) end
for _,page in ipairs({"find","create","notes","settings"}) do
 A:Open(page)
 local visible,hidden=0,0
 for _,node in ipairs(S.nodes) do if node:IsVisible() then visible=visible+1 else hidden=hidden+1 end end
 print(string.format("after.%s totalNodes=%d visible=%d hidden=%d",page,#S.nodes,visible,hidden))
end
local names={};for name in pairs(groups) do names[#names+1]=name end;table.sort(names)
for _,name in ipairs(names) do local r=groups[name]
 print(string.format("%s calls=%d KiB=%.3f nodes=%d fonts=%d textures=%d frames=%d",name,r.calls,r.KiB,r.nodes,r.fonts,r.textures,r.frames))
end
local inactiveRows,inactiveNodes=0,0
local function Descendant(node,parent) while node do if node==parent then return true end;node=node.parent end end
for _,row in pairs(settings.controls) do
 if not row.frame:IsVisible() then inactiveRows=inactiveRows+1
  for _,node in ipairs(S.nodes) do if Descendant(node,row.frame) then inactiveNodes=inactiveNodes+1 end end
 end
end
print(string.format("settings.firstGeneral inactiveRows=%d inactiveDescendantNodes=%d",inactiveRows,inactiveNodes))
for _,entry in ipairs({
 {"find.filters",U.pages.find.filterPanel},{"find.quickFilters",U.pages.find.quickFilters},
 {"create.form",U.pages.create.formFrame},{"create.manage",U.pages.create.manage},
 {"notes.editor",U.pages.notes.editor},{"notes.history",U.pages.notes.historyFrame},
 {"settings.about",settings.panels.about},
}) do
 local nodes,fonts,frames=0,0,0
 for _,node in ipairs(S.nodes) do if Descendant(node,entry[2]) then
  nodes=nodes+1;if node._objectType=="FontString" then fonts=fonts+1 elseif node._objectType~="Texture" and node._objectType~="MaskTexture" then frames=frames+1 end
 end end
 print(string.format("branch.%s nodes=%d fonts=%d frames=%d",entry[1],nodes,fonts,frames))
end
