-- Semantic identities exist before the optional UI addon is loaded. The shared
-- maps describe actual compositions; business-key templates do not copy rows.
local main=_G.LycheeGroup.ElementDefaults.main
local function Map(base,extra)
 local result={};for name,kind in pairs(base) do result[name]=kind end
 for name,kind in pairs(extra or {}) do result[name]=kind end;return result
end
local kinds={
 box={root="box"},panel={root="box",surface="surface"},text={root="text"},texture={root="texture"},
 button={root="roundedBox",label="text",surface="surface",fill="surface",hover="surface"},
 check={root="box",label="text",track="box",knob="box",surface="surface",knobSurface="surface",["track/bg"]="surface",["knob/bg"]="surface"},
 number={root="box",surface="surface",fill="surface",outline="surface",focus="surface",inner="surface",box="text",input="text",placeholder="text"},
 list={root="box",clip="box",canvas="box",slider="box",["slider/thumb"]="texture",indicator="box",["indicator/fill"]="surface"},
 row={root="box",title="text",label="text",meta="text",surface="surface",alternate="surface",hover="surface",selected="surface",mark="texture",noteDot="texture"},
 search={root="box",surface="surface",hover="surface",focus="surface",icon="texture"},
 selection={root="box",surface="surface",fill="surface"},
}
kinds.iconButton=Map(kinds.button,{icon="texture"})
kinds.ownIconButton=Map(kinds.button,{icon="texture",elementIcon="texture"})
kinds.choice=Map(kinds.button,{focus="surface",focusInner="surface",["arrows/1"]="texture",["arrows/2"]="texture"})
kinds.notice={root="box",surface="surface",fill="surface",text="text",close="roundedBox",["close/icon"]="texture",["close/label"]="text",["close/fill"]="surface",["close/hover"]="surface"}
kinds.category=Map(kinds.row,{symbol="texture",chevron="texture"})
kinds.activity=Map(kinds.row,{icon="texture",seasonLevel="text",seasonScore="text",multiSelect="box",["multiSelect/fill"]="surface",["multiSelect/mark"]="shape",["multiSelect/mark/strokes/1"]="texture",["multiSelect/mark/strokes/2"]="texture"})
local members={icon="texture",leaderIcon="texture",leader="text",count="text",membersButton="roundedBox",["membersButton/label"]="text",["membersButton/fill"]="surface",["membersButton/hover"]="surface",roster="box",tooltipArea="box"}
for index=1,5 do
 members["roster/slots/"..index.."/icon"]="texture"
 members["roster/slots/"..index.."/role"]="texture"
end
for index=1,3 do
 members["roster/counts/"..index.."/icon"]="texture"
 members["roster/counts/"..index.."/text"]="text"
end
kinds.result=Map(Map(kinds.row,members),{declined="text",description="text",score="text",ilvl="text",age="text",marks="box"})
kinds.application=Map(Map(kinds.row,members),{status="text",cancel="roundedBox",["cancel/label"]="text",["cancel/fill"]="surface",["cancel/hover"]="surface"})
local function Header(columns)
 local slots={root="box"}
 for key in columns:gmatch("%S+") do
  slots["columns:"..key]="text";slots["columnButton:"..key]="box";slots["columnHandle:"..key]="box";slots["columnLine:"..key]="texture"
 end
 return slots
end
kinds.resultsHeader=Header("title activity leader members ilvl rating description age")
kinds.applicationHeader=Header("title activity leader members status actions")
local function Add(kind,names,template)
 for name in names:gmatch("%S+") do main["find."..name]={scope="find",slotKinds=kinds[kind],template=template or nil} end
end
Add("box","frame rail main appsBadge quickFilters emptyPanel importantFilters filterViewport filterBody filterFooter")
Add("panel","surface applicationPanel filterPanel picker difficultySurface")
Add("list","seasonCategories categories appList results activities")
Add("button","filterToggle searchModeToggle scopeToggle applicationSettings start sidebarToggle quickLogic quickIdentity clearFilters filterDone pickerConfirm")
Add("ownIconButton","searchClear")
Add("ownIconButton","quickRole",true)
Add("iconButton","refresh filterClose pickerClose")
Add("check","autoJoin autoApply hideZeroScore hideSameClassRole requireBloodlust")
Add("choice","roleChoice socialChoice sortChoice tierChoice")
Add("number","filterField",true)
Add("box","filterRange",true)
Add("button","difficulty",true)
Add("text","searchHint appsTitle appsCount appsEmpty context resultCount emptyText emptyHelp filterTitle filterStatus ratingLabel ilvlLabel membersLabel roleLabel socialLabel sortLabel filterError picker.title searchInput")
Add("texture","searchIcon filterChevron sidebarIcon quickIdentityIcon quickIdentityFunnel busyIcon")
Add("search","search")
Add("category","category",true)
Add("activity","activity",true)
Add("result","result",true)
Add("application","application",true)
Add("resultsHeader","resultsHeader")
Add("applicationHeader","applicationHeader")
Add("selection","difficultySelection")
Add("notice","limitNotice")
main["find.filterScrim"]={scope="find",slotKinds={root="box",fill="texture"}}
main["find.filterScrollBar"]={scope="find",slotKinds={root="box",thumb="texture"}}
