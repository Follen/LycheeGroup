const fs=require('fs');
const path=require('path');
const root=__dirname;
let s=fs.readFileSync(path.join(root,'app.js'),'utf8').replace(/\r\n/g,'\n');
function rep(old,value){if(!s.includes(old))throw Error('Missing: '+old.slice(0,100));s=s.replace(old,()=>value);}
function section(start,end,value){const a=s.indexOf(start),b=s.indexOf(end,a+start.length);if(a<0||b<0)throw Error('Missing section '+start);s=s.slice(0,a)+value+'\n'+s.slice(b);}
rep("const icon = (name, cls = '') =>", "const assetSrc = path => 'assets/'+path;\nconst icon = (name, cls = '') =>");
rep('src="assets/icons/${name}.png"','src="${assetSrc(\'icons/\'+name+\'.png\')}"');
rep('src="assets/${a.art}"','src="${assetSrc(a.art)}"');
rep("player.src='assets/sounds/'+tone.file", "player.src=assetSrc('sounds/'+tone.file)");
rep('src="assets/lychee-logo.png"','src="${assetSrc(\'lychee-logo.png\')}"');
rep("rememberFilters:true,defaultSort", "rememberFilters:true,reuseApplicationNote:true,keywordFilters:{global:'',dungeon:'',raid:''},defaultSort");
rep("apps:{2:'applied',4:'invited'}", "apps:{1:'applied',2:'applied',3:'applied',4:'invited',5:'applied'}");
rep('settings:{...defaultSettings}', 'settings:structuredClone(defaultSettings)');
rep('state.applicationDeadlines={2:Date.now()+300000};', 'state.applicationDeadlines=Object.fromEntries([1,2,3,5].map((id,i)=>[id,Date.now()+300000-i*23000]));');
rep(' state.reuseApplicationNote=true;\n','');
rep('state.reuseApplicationNote?esc(state.lastApplicationNote)', 'state.settings.reuseApplicationNote?esc(state.lastApplicationNote)');
rep('<button class="search-refresh" aria-label="刷新队伍" title="刷新队伍" ${state.searching?\'disabled\':\'\'}>${icon(\'refresh\')}</button>', '');
rep('<div id="application-note-preference"></div>', '<button type="button" class="search-refresh" data-action="refresh-search" aria-label="刷新队伍" title="刷新队伍" ${state.searching?\'disabled\':\'\'}>${icon(\'refresh\')}</button>');
rep(' renderApplicationNotePreference();renderFloatingWidget();',' renderFloatingWidget();');
section('function applicationCard(g){','function renderCreate(){',`function applicationCard(g){
 const invited=state.apps[g.id]==='invited',m=person(g.leader),a=act(g.activity);
 return `+'`'+`<article class="application-card \${invited?'invited':''}" id="application-\${g.id}" data-application-id="\${g.id}"><button class="browse-identity" data-group="\${g.id}" data-tip-group="\${g.id}" aria-label="已申请队伍：\${esc(g.title)}">\${activityArt(a)}<span class="browse-copy"><strong>\${esc(g.title)}</strong><small>\${a.name}<span style="color:\${colorOf(m)}">\${m.name}</span></small></span></button><div class="application-composition">\${roster(g.members,g.max||5,g.counts)}<small>\${g.size||g.members.length}/\${g.max||5}</small></div>\${invited?'<span class="application-invite-state">已收到邀请</span>':`+'`'+`<div class="application-waiting">\${status('applied','',g.id)}<button class="text-action" data-action="cancel-application" data-id="\${g.id}">取消申请</button></div>`+'`'+`}</article>`+'`'+`;
}`);
rep("${state.selectedApplicant?renderApplicantDetail():`<div class=\"own-party-rail-list\">${ownPartyIds().map(id=>ownPartyMember(id)).join('')}</div>`}","<div class=\"own-party-rail-list\">${ownPartyIds().map(id=>ownPartyMember(id)).join('')}</div>");
section('function renderListingActivity(){','function creationActivityRows(){',`function renderListingActivity(){
 const f=state.form,c=categoryOf(f.category),searching=!!state.createActivityQuery.trim(),a=act(f.activity);
 return `+'`'+`<div class="creation-picker" id="creation-picker"><button type="button" class="creation-picker-trigger" data-action="toggle-creation-picker" aria-expanded="\${!!state.createPickerOpen}" aria-controls="creation-picker-panel" aria-label="选择活动：\${esc(a.name)}">\${activityArt(a)}<span class="picker-current truncate">\${a.name}<small>\${a.expansion||c.name}</small></span>\${icon('chevron')}</button>
 \${state.createPickerOpen?`+'`'+`<div class="creation-picker-panel" id="creation-picker-panel">
 <div class="creation-search">\${icon('search')}<input id="create-activity-query" aria-label="搜索全部活动" placeholder="搜索全部活动" value="\${esc(state.createActivityQuery)}"><button type="button" class="icon-button" data-action="clear-create-search" aria-label="清空活动搜索" \${searching?'':'hidden'}>\${icon('close')}</button></div>
 <div class="creation-picker-columns \${searching?'is-searching':''}"><nav class="creation-category-picker" aria-label="招募分类" \${searching?'hidden':''}>\${categories.map(category=>`+'`'+`<button type="button" class="\${category.id===c.id?'active':''}" data-form-category="\${category.id}" aria-pressed="\${category.id===c.id}">\${icon(category.icon)}<span>\${category.name}</span></button>`+'`'+`).join('')}</nav><div class="creation-picker-results">
 \${c.expansion?`+'`'+`<select id="listing-expansion" name="expansion" aria-label="招募资料片" \${searching?'hidden':''}>\${options(expansionOptions(c.id),f.expansion||a.expansion)}</select>`+'`'+`:''}<div id="creation-activity-list" class="creation-activity-list" aria-label="招募副本">\${creationActivityRows()}</div></div></div>
 </div>`+'`'+`:''}</div>`+'`'+`;
}`);
section('function groupNotesModal(id){','const applicantTones=', '');
rep("browse:['search','队伍浏览'],notes:","browse:['search','队伍浏览'],keywords:['','关键词过滤'],notes:");
rep("'切换活动后，恢复该分类上次选择的副本、难度和条件。'", "'切换活动后恢复筛选条件；赛季分类默认查看全部活动。'");
rep("+switchSetting('relations','好友与公会标记'", "+switchSetting('reuseApplicationNote','沿用上次备注','申请队伍时，自动填入上一次提交的备注。')+switchSetting('relations','好友与公会标记'");
rep(" if(state.settingsSection==='notes')content=",` if(state.settingsSection==='keywords')content=`+'`'+`<div class="keyword-intro">队伍名称或说明包含以下关键词时，隐藏该搜索结果。全局与对应分类同时生效，已提交的申请不受影响。</div><div class="keyword-fields">\${[['global','全局','适用于所有活动'],['dungeon','地下城','包括赛季地下城与其他地下城'],['raid','团本','包括赛季团本与其他团队副本']].map(([key,label,hint])=>`+'`'+`<label class="keyword-field" for="keywords-\${key}"><span><b>\${label}</b><small>\${hint}</small></span><textarea id="keywords-\${key}" data-keyword-scope="\${key}" placeholder="每行一个关键词，也可以用逗号分隔">\${esc(state.settings.keywordFilters[key])}</textarea></label>`+'`'+`).join('')}</div><p class="keyword-hint">输入后立即生效，英文不区分大小写。清空对应输入框即可停用。</p>`+'`'+`;\n if(state.settingsSection==='notes')content=`);
rep('function filteredGroups(){',`const keywordWords=text=>text.toLowerCase().split(/[\\n,，;；]+/).map(word=>word.trim()).filter(Boolean);
function keywordHidden(g){
 const kind=act(g.activity).kind,filters=state.settings.keywordFilters;
 const words=keywordWords(filters.global+'\\n'+(['dungeon','raid'].includes(kind)?filters[kind]:''));
 const text=(g.title+' '+g.comment).toLowerCase();
 return words.some(word=>text.includes(word));
}
function filteredGroups(){`);
rep('if(state.blockedTitles.includes(g.title))return false;', 'if(state.blockedTitles.includes(g.title)||keywordHidden(g))return false;');
rep(" if(activeApplication(id)){groupInfoModal(id);return;}"," if(activeApplication(id))return;");
rep(" const g=groups.find(g=>g.id===id);\n openModal(`<form class=\"modal\" id=\"apply-form\"", " const g=groups.find(g=>g.id===id);\n if((g.size||g.members.length)>=(g.max||5)){toast('这支队伍已满员。');return;}\n openModal(`<form class=\"modal\" id=\"apply-form\"");
rep("s==='invited'?['details','查看邀请状态']", "s==='invited'?['invite-state','已收到邀请']");
rep("${action==='apply'&&(full||countActive()>=5)?'disabled':''}", "${action==='invite-state'||action==='apply'&&(full||countActive()>=5)?'disabled':''}");
rep(" else if(action==='details')groupInfoModal(g.id);\n",'');
rep("if(state.category===b.dataset.category){state.categoryMenuOpen=!state.categoryMenuOpen;renderPage();}", "if(state.category===b.dataset.category){state.categoryMenuOpen=!state.categoryMenuOpen;if(categoryOf(state.category).season){state.activity='all';state.browseScroll=0;}renderPage();}");
rep(" if(b.dataset.group){groupInfoModal(Number(b.dataset.group));return;}\n",'');
rep(" if(b.dataset.applicant){state.selectedApplicant=Number(b.dataset.applicant);state.newApplicantIds=state.newApplicantIds.filter(id=>id!==state.selectedApplicant);renderPage();return;}\n",'');
rep(" if(b.dataset.formActivity){", " if(b.dataset.formCategory){readForm();const id=b.dataset.formCategory;state.form.category=id;state.form.expansion=categoryOf(id).expansion?expansionOptions(id)[0][0]:'all';state.form.activity=categoryActivities(id,state.form.expansion)[0].id;state.form.difficulty=id==='season-dungeons'?'keystone':difficulties(id,state.form.activity)[0]?.[0]||'';updateCreationTitle();renderPage();return;}\n if(b.dataset.formActivity){");
rep("  case 'toggle-application-note':state.reuseApplicationNote=!state.reuseApplicationNote;renderApplicationNotePreference();break;", "  case 'refresh-search':refreshGroups();break;");
rep("  case 'group-notes':groupNotesModal(Number(b.dataset.id));break;\n",'');
rep("  case 'close-applicant':state.selectedApplicant=null;renderPage();break;\n",'');
rep("  case 'invite-applicant':state.appStatus[state.selectedApplicant]='invited';renderPage();toast('已发出邀请，等待对方接受。');break;", "  case 'invite-applicant':respondToApplicant(Number(b.dataset.id),'invited');break;");
rep("  case 'decline-applicant':state.appStatus[state.selectedApplicant]='declined';renderPage();toast('已拒绝这组申请。');break;", "  case 'decline-applicant':respondToApplicant(Number(b.dataset.id),'declined');break;");
rep(" const b=event.target.closest('button');if(!b||b.disabled)return;", " const result=event.target.closest('[data-result-id]');if(result){state.selected=Number(result.dataset.resultId);document.querySelectorAll('[data-result-id]').forEach(row=>row.classList.toggle('selected',row===result));}\n const b=event.target.closest('button');if(!b||b.disabled)return;");
rep("document.addEventListener('contextmenu',event=>{", "document.addEventListener('dblclick',event=>{const row=event.target.closest('[data-result-id]');if(row&&$('#modal').hidden)applyModal(Number(row.dataset.resultId));});\ndocument.addEventListener('contextmenu',event=>{");
rep(" const el=event.target;\n if(el.dataset.settingRange)"," const el=event.target;\n if(el.dataset.keywordScope){state.settings.keywordFilters[el.dataset.keywordScope]=el.value;return;}\n if(el.dataset.settingRange)");
rep("$('.creation-category-picker').hidden=!!el.value.trim();$('[data-action=clear-create-search]').hidden=!el.value.trim();", "const searching=!!el.value.trim();$('.creation-category-picker').hidden=searching;$('.creation-picker-columns').classList.toggle('is-searching',searching);if($('#listing-expansion'))$('#listing-expansion').hidden=searching;$('[data-action=clear-create-search]').hidden=!searching;");
rep(" else if(el.name==='category'&&el.form?.id==='listing-form'){readForm();state.form.expansion=categoryOf(el.value).expansion?expansionOptions(el.value)[0][0]:'all';state.form.activity=categoryActivities(el.value,state.form.expansion)[0].id;state.form.difficulty=el.value==='season-dungeons'?'keystone':difficulties(el.value,state.form.activity)[0]?.[0]||'';updateCreationTitle();renderPage();}\n",'');
rep("  if(state.searching)return;state.searching=true;renderPage();clearTimeout(searchTimer);\n  searchTimer=setTimeout(()=>{state.searching=false;if(state.page==='find'){renderPage();toast(`已更新 ${filteredGroups().length} 支队伍。`);}},650);", "  refreshGroups();");
rep("document.addEventListener('submit',event=>{", "function refreshGroups(){\n if(state.searching)return;state.searching=true;renderPage();clearTimeout(searchTimer);\n searchTimer=setTimeout(()=>{state.searching=false;if(state.page==='find'){renderPage();toast(`已更新 ${filteredGroups().length} 支队伍。`);}},650);\n}\ndocument.addEventListener('submit',event=>{");
rep(" if(event.key==='Enter'&&event.target.id==='create-activity-query')", " if(event.key==='Enter'&&event.target.closest('[data-result-id]')){event.preventDefault();applyModal(Number(event.target.closest('[data-result-id]').dataset.resultId));return;}\n if(event.key==='Enter'&&event.target.id==='create-activity-query')");
rep("$('#application-demo').value='two'", "$('#application-demo').value='five'");
rep("(760*scale+46)","(840*scale+46)");rep("-(760*(1-scale))","-(840*(1-scale))");
fs.writeFileSync(path.join(root,'app.js'),s);
let html=fs.readFileSync(path.join(root,'index.html'),'utf8');html=html.replace('<option value="two" selected>','<option value="two">').replace('<option value="five">','<option value="five" selected>');fs.writeFileSync(path.join(root,'index.html'),html);
console.log('Applied v3 browse, picker, keyword settings and five-application mock changes.');
