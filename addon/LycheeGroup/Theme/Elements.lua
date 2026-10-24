-- Static semantic directory only. Live targets remain owned by their pages.
-- Slot maps are shared; defaults stay in Theme/Defaults and component recipes.
local A=_G.LycheeGroup
local kinds={
 box={root="box"},text={root="text"},texture={root="texture"},
 fieldShell={root="box",surface="surface",fill="surface",outline="surface",focus="surface",inner="surface"},
 component={root="box"},
 settingRow={root="box",surface="surface",fill="surface",label="text",help="text",control="box",valueLabel="text",input="text",track="box",thumb="box",thumbVisual="texture",["control/track"]="box",["control/track/bg"]="surface",["control/progress"]="box",["control/knob"]="box",["control/knob/bg"]="surface",["control/label"]="text",["control/box"]="text",["control/thumb"]="box",["control/track/_lycheeVisuals/1"]="surface",["control/progress/_lycheeVisuals/1"]="surface"},
 aboutAddon={root="box",icon="texture",title="text",summary="text"},
 aboutHeader={root="box",icon="texture",name="text",versionLabel="text",version="text",authorLabel="text",author="text"},
 member={root="roundedBox",icon="texture",name="text",realm="text",leaderIcon="texture",role="texture",faction="texture",marks="box",label="text",fill="surface",hover="surface"},
 batch={root="box",bg="surface",comment="text",status="text",invite="roundedBox",decline="roundedBox",["invite/icon"]="texture",["invite/fill"]="surface",["invite/hover"]="surface",["decline/icon"]="texture",["decline/fill"]="surface",["decline/hover"]="surface"},
 applicant={root="box",icon="texture",title="text",factionButton="roundedBox",faction="texture",race="text",marks="box",role="texture",ilvl="text",score="text",mapScore="text",mapScoreButton="box"},
 noteRow={root="box",title="text",meta="text",icon="texture",kind="text",date="text",reason="text",hover="surface",selected="surface",alternate="surface"},
 historyRow={chevron="texture",root="box",title="text",meta="text",icon="texture",level="text",duration="text",roster="box",date="text",hover="surface",selected="surface",alternate="surface"},
 historyMember={root="box",title="text",meta="text",icon="texture",action="text",hover="surface",selected="surface",alternate="surface"},
 relationship={root="box",icon="texture",names="text"},boss={root="box",name="text",status="text"},
 dungeon={root="box",label="text",keyLevel="text",name="text",status="text"},
 rich={root="box",surface="surface",scroll="box",canvas="box",scrollbar="box",icon="texture",title="text",subtitle="text",summary="text",pvpRatings="text",composition="box",raidLeader="text",raidLeaderIcon="texture",comment="text",footer="text",bossTitle="text",bossCount="text",bossText="text",dungeonTitle="text",dungeonEmpty="text",playerRole="texture",playerFaction="texture",noteHeading="text",noteGlyph="texture",noteDate="text",noteDivider="texture",back="roundedBox",wcl="roundedBox",io="roundedBox",note="roundedBox"},
 floatingRow={root="box",background="box",["background/fill"]="surface",icon="texture",name="text",faction="texture",meta="text",score="text",itemLevel="text",leader="text",timer="text",invite="roundedBox",decline="roundedBox",cancel="roundedBox"},
}
local main,floating={},{}
local function Add(target,scope,kind,names)
 for id in names:gmatch("%S+") do target[id]={scope=scope,slotKinds=kinds[kind]} end
end
Add(main,"application","component","application.autoApply application.cancel application.note application.previewNote application.role application.submit")
Add(main,"application","text","application.error application.group application.noteLabel application.roleLabel")
Add(main,"create","applicant","create.applicantMember")
Add(main,"create","batch","create.applicantBatch")
Add(main,"create","component","create.applicantTable create.autoAccept create.batchBody create.batchScroll create.batchSlider create.buff create.buffArea create.buffList create.cancelListing create.correctionNotice create.crossFaction create.desc create.descriptionShell create.difficulty create.difficultyChoice create.difficultyFixedSurface create.difficultyGroup create.editListing create.favoriteRow create.favoritesBody create.favoritesCard create.favoritesList create.formCancel create.formFrame create.formNotice create.frame create.groupStrip create.groupSummary create.manage create.manageNotice create.picker create.pickerActivity create.pickerCategories create.pickerCategory create.pickerClear create.pickerResults create.pickerSearch create.pickerSurface create.pickerTrigger create.playstyle create.private create.publish create.rail create.req create.roleFilter create.roleFilterSurface create.rosterCard create.rosterList create.rosterList.body create.rosterList.clip create.rosterList.slider create.sortChoice create.surface create.tierChoice create.titleShell")
Add(main,"create","text","create.activityLabel create.appCount create.applicantsHeading create.autoInviteHint create.buffComplete create.buffTitle create.descriptionLabel create.difficultyFixed create.empty create.favoritesEmpty create.heading create.ilvl create.ilvlLabel create.pickerContext create.pickerEmpty create.pickerName create.pickerSearchHint create.requirementsLabel create.rosterCount create.rosterList.empty create.rosterTitle create.sMeta create.sName create.score create.scoreLabel create.styleLabel create.titleLabel")
Add(main,"create","texture","create.favorite create.favoritesChevron create.listingFavorite create.pickerIcon create.sIcon")
Add(main,"host","box","host.window")
Add(main,"host","component","host.blocker host.closeButton host.content host.logoButton host.navigation host.navigation.item host.previewExit host.resize host.settingsButton modal")
Add(main,"host","text","host.brandTitle")
Add(main,"host","texture","host.logo host.underline")
Add(main,"members","component","member.marks")
Add(main,"members","member","member.identity")
Add(main,"native","text","native.application.note native.creation.description native.creation.title native.search")
Add(main,"notes","component","notes.addButton notes.classChoice notes.eCancel notes.eClose notes.eDelete notes.eName notes.eReason notes.eSave notes.editor notes.emptyState notes.exportButton notes.frame notes.historyFrame notes.historyHeader notes.historyList notes.historyModal.header notes.historyModal.list notes.importButton notes.left notes.list notes.main notes.noteHeader notes.rail notes.search notes.specChoice notes.tBox notes.tExport notes.tImport notes.tSelect notes.toolbar notes.typeSwitch")
Add(main,"notes","historyMember","notes.historyMember")
Add(main,"notes","box","notes.actions")
Add(main,"notes","historyRow","notes.history")
Add(main,"notes","noteRow","notes.record")
Add(main,"notes","text","notes.classLabel notes.eDate notes.eIdentity notes.eNameHint notes.eNameLabel notes.eRealm notes.eReasonLabel notes.eStatus notes.eTitle notes.editorEmpty notes.emptyTitle notes.historyCaption notes.historyEmpty notes.historyModal.caption notes.pageTitle notes.searchHint notes.specLabel notes.tHint notes.tLabel notes.tStatus notes.typeLabel")
Add(main,"notes","texture","notes.eAvatar")
Add(main,"settings","aboutAddon","settings.about.addon")
Add(main,"settings","aboutHeader","settings.aboutHeader")
Add(main,"settings","box","settings.panel")
Add(main,"settings","component","settings.about.link settings.aboutBrand settings.bindingNotice settings.block settings.blocksClear settings.blocksHeader settings.blocksList settings.cancelBinding settings.dedicationToast settings.frame settings.main settings.navigation settings.overwriteBinding settings.rail settings.reloadLanguage")
Add(main,"settings","settingRow","settings.row")
Add(main,"settings","text","settings.blocksCount settings.blocksEmpty settings.heading settings.otherAddonsHeading settings.themeReloadHint")
Add(main,"tooltip","boss","tooltip.boss")
Add(main,"tooltip","component","tooltip.back tooltip.canvas tooltip.composition tooltip.copyText.close tooltip.copyText.field tooltip.note tooltip.outside tooltip.plain tooltip.scroll tooltip.scrollbar tooltip.wcl tooltip.io")
Add(main,"tooltip","dungeon","tooltip.dungeon")
Add(main,"tooltip","relationship","tooltip.relationship")
Add(main,"tooltip","rich","tooltip.rich")
Add(main,"tooltip","text","tooltip.bossCount tooltip.bossText tooltip.bossTitle tooltip.comment tooltip.copyText.copyHint tooltip.copyText.fieldLabel tooltip.copyText.help tooltip.dungeonEmpty tooltip.dungeonTitle tooltip.footer tooltip.metric.title tooltip.metric.value tooltip.noteDate tooltip.noteHeading tooltip.pvpRatings tooltip.raidLeader tooltip.rosterGroup tooltip.subtitle tooltip.summary tooltip.title")
Add(main,"tooltip","texture","tooltip.icon tooltip.noteDivider tooltip.noteGlyph tooltip.playerFaction tooltip.playerRole tooltip.raidLeaderIcon")
Add(floating,"floating","batch","floating.batch")
Add(floating,"floating","box","floating.body floating.logoAnchor floating.panel floating.scroll floating.window")
Add(floating,"floating","component","floating.button floating.cancel floating.emptyCard floating.scrollBar")
Add(floating,"floating","floatingRow","floating.application floating.footer floating.member floating.row")
Add(floating,"floating","text","floating.count floating.empty")
Add(floating,"floating","texture","floating.logo")
-- Shared maps describe real compositions, rather than a union of every widget's
-- possible child names. Only template rows legitimately share optional parts.
local function Map(base,extra)
 local result={};for name,kind in pairs(base) do result[name]=kind end
 for name,kind in pairs(extra or {}) do result[name]=kind end;return result
end
kinds.panel={root="box",surface="surface"}
kinds.button={root="roundedBox",label="text",surface="surface",fill="surface",hover="surface"}
kinds.iconButton=Map(kinds.button,{icon="texture"})
kinds.choice=Map(kinds.button,{focus="surface",focusInner="surface",["arrows/1"]="texture",["arrows/2"]="texture"})
kinds.edit=Map(kinds.fieldShell,{box="text",input="text"})
kinds.multiline=Map(kinds.edit,{scroll="box"})
kinds.number=Map(kinds.edit,{placeholder="text"})
kinds.check={root="box",label="text",track="box",knob="box",surface="surface",knobSurface="surface",["track/bg"]="surface",["knob/bg"]="surface"}
kinds.scrollbar={root="box",thumb="texture"}
kinds.list={root="box",clip="box",canvas="box",slider="box",["slider/thumb"]="texture",indicator="box",["indicator/fill"]="surface"}
kinds.row={root="box",title="text",label="text",meta="text",surface="surface",alternate="surface",hover="surface",selected="surface",mark="texture",noteDot="texture"}
kinds.notice={root="box",surface="surface",fill="surface",text="text",close="roundedBox",["close/icon"]="texture",["close/label"]="text",["close/fill"]="surface",["close/hover"]="surface"}
main["tooltip.rosterNotice"]={scope="tooltip",slotKinds=kinds.notice}
main["tooltip.rosterDrop"]={scope="tooltip",template=true,slotKinds={root="box",surface="surface"}}
main["tooltip.rosterDragGhost"]={scope="tooltip",slotKinds={root="box",surface="surface",card="box",status="text"}}
main["tooltip.rosterDropHighlight"]={scope="tooltip",slotKinds={root="box",surface="surface"}}
main["tooltip.emptyRosterGroups"]={scope="tooltip",slotKinds={root="box",surface="surface"}}
main["tooltip.emptyRosterGroup"]={scope="tooltip",template=true,slotKinds=kinds.button}
kinds.selection={root="box",fill="surface",surface="surface"}
kinds.header={root="box"}
local function Assign(target,kind,names)
 for id in names:gmatch("%S+") do assert(target[id],"unknown element declaration: "..id);target[id].slotKinds=kind end
end
Assign(main,kinds.button,"application.cancel application.submit host.navigation.item host.previewExit notes.addButton notes.eCancel notes.eDelete notes.eSave notes.exportButton notes.importButton notes.tExport notes.tImport notes.tSelect settings.about.link settings.blocksClear settings.cancelBinding settings.overwriteBinding settings.reloadLanguage create.cancelListing create.editListing create.formCancel create.publish create.difficulty create.roleFilter")
Assign(main,kinds.iconButton,"host.closeButton host.settingsButton create.favorite create.listingFavorite")
Assign(main,kinds.button,"tooltip.back tooltip.note tooltip.wcl tooltip.io tooltip.copyText.close")
Assign(main,kinds.choice,"create.pickerTrigger create.difficultyChoice create.playstyle create.sortChoice create.tierChoice notes.classChoice notes.specChoice")
Assign(main,kinds.check,"create.autoAccept create.crossFaction create.private")
Assign(main,kinds.number,"create.ilvl create.score")
Assign(main,kinds.edit,"notes.search notes.eName create.pickerSearch")
Assign(main,kinds.multiline,"notes.eReason notes.tBox application.previewNote tooltip.copyText.field")
Assign(main,kinds.scrollbar,"create.batchSlider create.rosterList.slider tooltip.scrollbar")
Assign(main,kinds.list,"create.buffList create.favoritesList create.pickerCategories create.pickerResults notes.list notes.historyList notes.historyModal.list settings.blocksList")
Assign(main,kinds.header,"create.applicantTable notes.noteHeader notes.historyHeader notes.historyModal.header settings.blocksHeader")
Assign(main,kinds.notice,"create.formNotice create.correctionNotice create.manageNotice settings.bindingNotice settings.dedicationToast")
Assign(main,kinds.panel,"host.window create.surface create.difficultyFixedSurface create.difficultyGroup create.roleFilterSurface create.favoritesCard create.rosterCard create.picker create.pickerSurface notes.main notes.editor notes.typeSwitch settings.main")
Assign(main,kinds.texture,"create.favoritesChevron")
Assign(main,kinds.text,"create.pickerSearchHint")
Assign(main,kinds.row,"create.favoriteRow create.pickerCategory create.pickerActivity create.buff settings.block")
Assign(floating,kinds.button,"floating.cancel")
Assign(floating,kinds.scrollbar,"floating.scrollBar")
Assign(floating,{root="box",background="box",["background/fill"]="surface"},"floating.batch floating.emptyCard")
for _,id in ipairs({"create.titleShell","create.descriptionShell","application.note"}) do main[id].slotKinds=kinds.fieldShell end
-- Indexed component parts use shared slot paths, not one registry row per part.
local function Extend(id,slots)
 local entry=main[id];if not entry then return end
 local map={};for name,kind in pairs(entry.slotKinds) do map[name]=kind end
 for name,kind in pairs(slots) do map[name]=kind end
 entry.slotKinds=map
end
local function Header(id,columns)
 local slots={}
 for key in columns:gmatch("%S+") do slots["columns:"..key]="text";slots["columnButton:"..key]="box";slots["columnHandle:"..key]="box";slots["columnLine:"..key]="texture" end
 Extend(id,slots)
end
Header("create.applicantTable","name role faction rating mapScore ilvl comment actions")
Header("notes.noteHeader","player timestamp")
Header("notes.historyHeader","activity level duration teammates completed")
Header("notes.historyModal.header","player actions")
Header("settings.blocksHeader","name realm actions")
local rosterSlots={}
for index=1,5 do rosterSlots["member:"..index]="texture";rosterSlots["memberRole:"..index]="texture" end
for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do rosterSlots["countIcon:"..role]="texture";rosterSlots["countText:"..role]="text" end
Extend("create.groupStrip",rosterSlots);Extend("tooltip.composition",rosterSlots)
Extend("notes.record",{["kindIcons/positive"]="texture",["kindIcons/neutral"]="texture",["kindIcons/caution"]="texture"})
Extend("create.applicantMember",{["roles/1"]="texture",["roles/2"]="texture",["roles/3"]="texture"})
Extend("create.buff",{["cells/1/icon"]="texture",["cells/1/label"]="text",["cells/2/icon"]="texture",["cells/2/label"]="text"})
local historyRoster={}
for index=1,5 do historyRoster["roster/slots/"..index.."/icon"]="texture";historyRoster["roster/slots/"..index.."/role"]="texture" end
Extend("notes.history",historyRoster)
main["tooltip.member"]={scope="tooltip",slotKinds=kinds.member}
main["create.rosterMember"]={scope="create",slotKinds=kinds.member}
Extend("member.marks",{["icons/bnet"]="texture",["icons/friend"]="texture",["icons/guild"]="texture",["icons/positive"]="texture",["icons/neutral"]="texture",["icons/caution"]="texture",noteButton="box",["noteButton/icon"]="texture"})
main["minimap.entry"]={scope="minimap",slotKinds={root="box",background="texture",icon="texture"}}
main["minimap.background"]={scope="minimap",slotKinds=kinds.texture}
main["minimap.icon"]={scope="minimap",slotKinds=kinds.texture}
main["create.favoritesToggle"]={scope="create",slotKinds=kinds.button}
Extend("tooltip.plain",{["lines/1"]="text"})
main["create.difficultySelection"]={scope="create",slotKinds=kinds.selection}
main["notes.tabSelection"]={scope="notes",slotKinds=Map(kinds.selection,{mark="texture"})}
for id,definition in pairs(_G.LycheeUI.ElementDefinitions or {}) do main[id]=definition;floating[id]=definition end
main["notes.navigation"]={scope="notes",slotKinds={root="roundedBox",label="text",icon="texture",glyph="texture",count="text",surface="surface",hover="surface"}}
main["notes.type"]={scope="notes",slotKinds=kinds.iconButton}
main["modal"].slotKinds={root="box",surface="surface",title="text",content="box",scrim="box",scrimFill="texture",close="box",["close/icon"]="texture",["close/label"]="text",["close/fill"]="surface",["close/hover"]="surface"}
-- Composite parts retain the original objects and stable list business keys.
main["application.role"].slotKinds=Map(kinds.button,{roleIcon="texture"})
main["application.autoApply"].slotKinds=Map(kinds.button,{box="box",["box/fill"]="surface",["box/mark"]="shape"})
main["notes.eClose"].slotKinds=Map(kinds.button,{elementIcon="texture"})
main["create.pickerSearch"].slotKinds=Map(kinds.edit,{elementIcon="texture"})
main["create.pickerClear"].slotKinds=Map(kinds.button,{elementIcon="texture"})
main["create.favoriteRow"].slotKinds=Map(kinds.row,{icon="texture",conditions="text",unavailable="text",create="roundedBox",["create/label"]="text",["create/fill"]="surface",["create/hover"]="surface",remove="roundedBox",["remove/label"]="text",["remove/fill"]="surface",["remove/hover"]="surface",["remove/elementIcon"]="texture"})
main["settings.block"].slotKinds=Map(kinds.row,{remove="roundedBox",["remove/label"]="text",["remove/fill"]="surface",["remove/hover"]="surface"})
main["settings.navigation"].slotKinds=Map(kinds.button,{mark="texture"})
main["create.pickerCategory"].slotKinds=Map(kinds.row,{symbol="texture"})
main["create.pickerActivity"].slotKinds=Map(kinds.row,{icon="texture"})
main["tooltip.plain"].slotKinds={root="box",surface="surface",["lines/1"]="text"}
main["create.rosterList"].slotKinds={root="box",clip="box",body="box",slider="box",["slider/thumb"]="texture",empty="text"}
main["tooltip.scroll"].slotKinds=kinds.box;main["tooltip.canvas"].slotKinds=kinds.box
main["tooltip.composition"].slotKinds=Map(kinds.box,rosterSlots)
main["create.groupStrip"].slotKinds=Map(kinds.box,rosterSlots)
main["settings.row"].slotKinds=Map(kinds.settingRow,{["control/arrows/1"]="texture",["control/arrows/2"]="texture",["control/fill"]="surface",["control/hover"]="surface",["control/focus"]="surface",["control/focusInner"]="surface"})
main["notes.record"].slotKinds=Map(kinds.row,main["notes.record"].slotKinds)
main["notes.history"].slotKinds=Map(kinds.row,main["notes.history"].slotKinds)
main["notes.historyMember"].slotKinds=Map(kinds.row,main["notes.historyMember"].slotKinds)
main["create.buff"].slotKinds=Map(kinds.row,main["create.buff"].slotKinds)
main["host.navigation.item"].slotKinds={root="box",label="text",icon="texture"}
main["host.resize"].slotKinds={root="box",icon="texture"}
main["notes.addButton"].slotKinds=kinds.iconButton
main["notes.eReason"].slotKinds=Map(kinds.multiline,{placeholder="text"})
main["notes.navigation"].slotKinds=Map(main["notes.navigation"].slotKinds,{fill="surface"})
main["settings.about.addon"].slotKinds=Map(kinds.aboutAddon,{surface="surface"})
main["tooltip.back"].slotKinds=Map(kinds.button,{elementIcon="texture"})
main["create.groupSummary"].slotKinds={root="box",surface="surface",hover="surface"}
main["create.applicantBatch"].slotKinds=Map(kinds.batch,{surface="surface"})
main["create.roleFilter"].slotKinds=Map(kinds.button,{roleIcon="texture"})
for _,id in ipairs({"member.identity","create.rosterMember","tooltip.member"}) do main[id].slotKinds=Map(kinds.member,{surface="surface"}) end
local floatingActions={}
for _,name in ipairs({"invite","decline","cancel"}) do
 floatingActions[name.."/label"]="text";floatingActions[name.."/fill"]="surface";floatingActions[name.."/hover"]="surface"
 floatingActions[name..(name=="cancel" and "/elementIcon" or "/icon")]="texture"
end
for _,id in ipairs({"floating.row","floating.application","floating.member","floating.footer"}) do floating[id].slotKinds=Map(kinds.floatingRow,floatingActions) end
local function Templates(target,names)
 for id in names:gmatch("%S+") do assert(target[id],"unknown element template: "..id);target[id].template=true end
end
Templates(main,"modal application.role host.navigation.item member.identity member.marks create.applicantBatch create.applicantMember create.rosterMember create.favoriteRow create.buff create.pickerCategory create.pickerActivity create.roleFilter create.difficulty notes.record notes.history notes.historyMember notes.navigation notes.type settings.row settings.navigation settings.panel settings.about.addon settings.about.link settings.block tooltip.member tooltip.boss tooltip.dungeon tooltip.relationship tooltip.metric.title tooltip.metric.value tooltip.rosterGroup")
Templates(floating,"floating.batch floating.row floating.application floating.member floating.footer")
A.ElementDefaults={main=main,floating=floating}
A.ThemeDefaults.appearance.main.elements=main
A.ThemeDefaults.appearance.floating.elements=floating
