const $ = (q, root = document) => root.querySelector(q);
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const icon = (name, cls = '') => `<img class="ui-icon ${cls}" src="assets/icons/${name}.png" alt="" aria-hidden="true" draggable="false">`;
const roleNames = {TANK:'坦克',HEALER:'治疗',DAMAGER:'输出',NONE:'未指定'};
const roleIcons = {TANK:'tank',HEALER:'healer',DAMAGER:'damage',NONE:'plus'};
const classInfo = {WARRIOR:['战','#c69b6d'],PALADIN:['骑','#f48cba'],MAGE:['法','#69ccf0'],PRIEST:['牧','#eeeae6'],DRUID:['德','#ff9b48'],SHAMAN:['萨','#659de1'],DEMONHUNTER:['猎','#c084d8'],ROGUE:['贼','#e6d67f'],MONK:['僧','#7edbb7'],WARLOCK:['术','#a999db']};
const colorOf = m => classInfo[m.class]?.[1] || '#b6c2d2';

const categories = [
 {id:'season-dungeons',name:'赛季地下城',kind:'dungeon',icon:'mountain',season:true},
 {id:'season-raids',name:'赛季团本',kind:'raid',icon:'tower',season:true},
 {id:'delves',name:'地下堡',kind:'delve',icon:'delve',expansion:true},
 {id:'dungeons',name:'地下城',kind:'dungeon',icon:'mountain',expansion:true},
 {id:'raids',name:'团队副本',kind:'raid',icon:'tower',expansion:true},
 {id:'pvp',name:'PvP',kind:'pvp',icon:'pvp'},
 {id:'quests',name:'任务',kind:'quest',icon:'flag'},
 {id:'custom',name:'自定义',kind:'custom',icon:'plus'}
];
const activities = [
 {id:'academy',name:'艾杰斯亚学院',kind:'dungeon',expansion:'巨龙时代',season:true,art:'academy.jpg',color:'#8db1cf'},
 {id:'ruby',name:'红玉新生法池',kind:'dungeon',expansion:'巨龙时代',season:true,art:'ruby.jpg',color:'#de8b79'},
 {id:'bracken',name:'蕨皮山谷',kind:'dungeon',expansion:'巨龙时代',season:true,art:'bracken.jpg',color:'#9eb778'},
 {id:'nokhud',name:'诺库德阻击战',kind:'dungeon',expansion:'巨龙时代',season:true,art:'nokhud.jpg',color:'#c3b58b'},
 {id:'azure',name:'碧蓝魔馆',kind:'dungeon',expansion:'巨龙时代',season:true,art:'azure.jpg',color:'#9a9bd7'},
 {id:'neltharus',name:'奈萨鲁斯',kind:'dungeon',expansion:'巨龙时代',season:true,art:'neltharus.jpg',color:'#ce9970'},
 {id:'palace',name:'尼鲁巴尔王宫',kind:'raid',expansion:'地心之战',season:true,art:'palace.jpg',color:'#b494c8'},
 {id:'undermine',name:'解放安德麦',kind:'raid',expansion:'地心之战',season:true,art:'undermine.png',color:'#b6ae73'},
 {id:'mists',name:'塞兹仙林的迷雾',kind:'dungeon',expansion:'暗影国度',art:'mists.png',color:'#9dbbd0'},
 {id:'fungal',name:'真菌之愚',kind:'delve',expansion:'地心之战',color:'#b1ba88'},
 {id:'waterworks',name:'水能堡',kind:'delve',expansion:'地心之战',color:'#83b8c7'},
 {id:'arena2',name:'2v2 竞技场',kind:'pvp',ratedPvp:true,color:'#c98e89'},
 {id:'arena3',name:'3v3 竞技场',kind:'pvp',ratedPvp:true,color:'#c98e89'},
 {id:'battleground',name:'评级战场',kind:'pvp',ratedPvp:true,color:'#c98e89'},
 {id:'worldquest',name:'世界任务',kind:'quest',color:'#cbb577'},
 {id:'leveling',name:'任务与升级',kind:'quest',color:'#cbb577'},
 {id:'custom',name:'自定义 PvE',kind:'custom',color:'#a7aabd'},
 {id:'custom-pvp',name:'自定义 PvP',kind:'custom',color:'#c98e89'}
];
// Sample catalog mirrors the LFG hierarchy; the addon will use its native catalog.
const expansionOrder=['至暗之夜','地心之战','巨龙时代','暗影国度','争霸艾泽拉斯','军团再临','德拉诺之王','熊猫人之谜','大地的裂变','巫妖王之怒','燃烧的远征','经典旧世'];
const sampleDungeons=[
 ['nalorakk','纳洛拉克的洞穴','至暗之夜'],['magisters','魔导师平台','至暗之夜'],
 ['threads','千丝之城','地心之战'],['priory','圣焰隐修院','地心之战'],['darkflame','暗焰裂口','地心之战'],
 ['uldaman','奥达曼：提尔的遗产','巨龙时代'],['atal','阿塔达萨','争霸艾泽拉斯'],
 ['blackrook','黑鸦堡垒','军团再临'],['auchindoun','奥金顿','德拉诺之王'],['jade','青龙寺','熊猫人之谜'],
 ['stonecore','巨石之核','大地的裂变'],['utgarde','乌特加德城堡','巫妖王之怒'],['ramparts','地狱火城墙','燃烧的远征'],['deadmines','死亡矿井','经典旧世']
];
activities.push(...sampleDungeons.map(([id,name,expansion])=>({id,name,expansion,kind:'dungeon',color:'#8daabd'})),
 {id:'vault',name:'化身巨龙牢窟',expansion:'巨龙时代',kind:'raid',color:'#b494c8'},
 {id:'nathria',name:'纳斯利亚堡',expansion:'暗影国度',kind:'raid',color:'#b494c8'},
 {id:'karazhan',name:'卡拉赞',expansion:'燃烧的远征',kind:'raid',color:'#b494c8'});
const categoryOf = id => categories.find(c=>c.id===id);
const act = id => activities.find(a=>a.id===id);
const difficultyNames = {all:'全部难度',normal:'普通',heroic:'英雄',mythic:'史诗',keystone:'史诗钥石',delve:'地下堡'};
// Explicit mock variants stand in for GetAvailableActivities + GetActivityInfoTable.
// These samples describe the prototype, not the current live season catalog.
const activityVariants = {
 academy:['normal','heroic','mythic','keystone'],ruby:['normal','heroic','mythic','keystone'],
 bracken:['normal','heroic','mythic','keystone'],nokhud:['normal','heroic','mythic','keystone'],
 azure:['normal','heroic','mythic','keystone'],neltharus:['normal','heroic','mythic','keystone'],
 mists:['normal','heroic','mythic'],nalorakk:['normal','heroic','mythic'],magisters:['normal','heroic','mythic'],
 threads:['normal','heroic','mythic'],priory:['normal','heroic','mythic'],darkflame:['normal','heroic','mythic'],
 uldaman:['normal','heroic','mythic'],atal:['normal','heroic','mythic'],blackrook:['normal','heroic','mythic'],
 auchindoun:['normal','heroic','mythic'],jade:['normal','heroic'],stonecore:['normal','heroic'],
 utgarde:['normal','heroic'],ramparts:['normal','heroic'],deadmines:['normal'],
 palace:['normal','heroic','mythic'],undermine:['normal','heroic','mythic'],vault:['normal','heroic','mythic'],
 nathria:['normal','heroic','mythic'],karazhan:['normal']
};
const categoryActivities = (id,expansion='all') => {
 const c=categoryOf(id);
 return activities.filter(a=>a.kind===c.kind&&(!c.season||a.season)&&(expansion==='all'||a.expansion===expansion));
};
const difficulties = (category,activityID='all',expansion='all') => {
 const available=activityID==='all'?categoryActivities(category,expansion):[act(activityID)];
 const variants=new Set(available.flatMap(a=>activityVariants[a.id]||[]));
 return ['normal','heroic','mythic','keystone'].filter(key=>variants.has(key)).map(key=>[key,difficultyNames[key]]);
};
const ratingLabel=(activityID,difficulty)=>difficulty==='keystone'?'最低钥石评分':act(activityID)?.ratedPvp?'最低 PvP 评分':'';
const usesKeyFilters=()=>categoryOf(state.category).kind==='dungeon'&&difficulties(state.category,state.activity,state.expansion).some(([id])=>id==='keystone')&&['all','keystone'].includes(state.difficulty);
const expansionOptions=category=>expansionOrder.filter(expansion=>categoryActivities(category).some(a=>a.expansion===expansion)).map(x=>[x,x]);
const activityArt = (a,level,large=false) => `<span class="activity-icon${large?' large':''}" style="--art:${a.color}">${a.art?`<img src="assets/${a.art}" alt="" loading="lazy">`:icon(a.kind==='raid'?'tower':a.kind==='pvp'?'pvp':a.kind==='delve'?'delve':a.kind==='quest'?'flag':'mountain')}${level?`<span class="key-level">+${level}</span>`:''}</span>`;
const people = [
 {id:'wind',name:'晚风听雨',realm:'晨风号角',class:'WARRIOR',role:'TANK',spec:'防护',ilvl:648,score:3128},
 {id:'sugar',name:'糖霜骑士',realm:'白银之手',class:'PALADIN',role:'HEALER',spec:'神圣',ilvl:645,score:2976},
 {id:'star',name:'暮色星河',realm:'晨风号角',class:'MAGE',role:'DAMAGER',spec:'冰霜',ilvl:647,score:3052},
 {id:'bird',name:'云上青鸟',realm:'凤凰之神',class:'PRIEST',role:'DAMAGER',spec:'暗影',ilvl:643,score:2862},
 {id:'tea',name:'柚子茶',realm:'白银之手',class:'DRUID',role:'DAMAGER',spec:'平衡',ilvl:646,score:3014},
 {id:'rain',name:'落雨无声',realm:'晨风号角',class:'SHAMAN',role:'HEALER',spec:'恢复',ilvl:644,score:2893},
 {id:'night',name:'长夜微光',realm:'凤凰之神',class:'DEMONHUNTER',role:'TANK',spec:'复仇',ilvl:650,score:3280},
 {id:'moon',name:'月下行舟',realm:'白银之手',class:'ROGUE',role:'DAMAGER',spec:'狂徒',ilvl:649,score:3210},
 {id:'panda',name:'青竹',realm:'晨风号角',class:'MONK',role:'HEALER',spec:'织雾',ilvl:638,score:2450}
];
const person = id => people.find(p => p.id === id);
const initialNotes = [
 {id:'wind',type:'positive',name:'晚风听雨',realm:'晨风号角',classSpec:'战士 · 防护',date:'26/10/15',reason:'路线清楚，会提醒打断；上次学院配合很好。'},
 {id:'tea',type:'positive',name:'柚子茶',realm:'白银之手',classSpec:'德鲁伊 · 平衡',date:'26/10/14',reason:'耐心，愿意带新手熟悉机制。一起完成了两次限时。'},
 {id:'bird',type:'neutral',name:'云上青鸟',realm:'凤凰之神',classSpec:'牧师 · 暗影',date:'26/10/12',reason:'团队沟通顺畅，保留记录便于下次组队。'}
];
const groups = [
 {id:1,activity:'academy',title:'+12 学院 稳定限时 来输出',leader:'wind',members:['wind','sugar','star'],level:12,ilvl:640,minScore:2800,age:26,comment:'熟练机制，开打前确认路线。打断分配好，沟通友善，争取限时。'},
 {id:2,activity:'ruby',title:'+10 打完就走，来治疗',leader:'night',members:['night','moon','tea','bird'],level:10,ilvl:635,minScore:2400,age:50,comment:'来个治疗就出发，正常打完不跳车。'},
 {id:3,activity:'bracken',title:'+13 冲分，熟练队',leader:'moon',members:['rain','moon'],level:13,ilvl:645,minScore:3000,age:92,comment:'有合剂和食物。希望一起配合打断，开怪前说好路线。'},
 {id:4,activity:'nokhud',title:'+11 周常，友好交流',leader:'sugar',members:['wind','sugar','tea'],level:11,ilvl:638,minScore:2600,age:120,comment:'打完就好，熟悉机制可以来。'},
 {id:5,activity:'ruby',title:'+12 法池 补一输出',leader:'tea',members:['night','rain','tea','bird'],level:12,ilvl:640,minScore:2800,age:189,comment:'坦奶已齐，等一位输出。有嗜血更好。'},
 {id:6,activity:'azure',title:'+9 新人练习 一起打',leader:'panda',members:['panda','bird'],level:9,ilvl:630,minScore:2200,age:240,comment:'机制还在练习，会在开怪前确认。欢迎愿意沟通的朋友。'},
 {id:7,activity:'neltharus',title:'+12 最后一把，稳定打完',leader:'star',members:['wind','sugar','star','moon'],level:12,ilvl:640,minScore:2800,age:302,comment:'不赶时间，正常打完。可以打字沟通。'},
 {id:8,activity:'academy',title:'+14 认真冲分，等一奶',leader:'night',members:['night','moon','tea','star'],level:14,ilvl:648,minScore:3100,age:370,comment:'目标限时，熟悉路线和首领机制。'},
 {id:11,activity:'palace',difficulty:'heroic',title:'英雄王宫 5/8，补治疗和输出',leader:'wind',members:['wind','sugar','star','tea'],size:17,max:20,counts:[2,3,12],ilvl:635,minScore:0,age:45,progress:'5/8',comment:'稳定团队补位，语音指挥。分装前讲清规则，打完大家一起散。'},
 {id:12,activity:'palace',difficulty:'normal',title:'普通全通，欢迎练习机制',leader:'sugar',members:['sugar','night','star'],size:12,max:20,counts:[2,2,8],ilvl:620,minScore:0,age:80,progress:'0/8',comment:'会讲机制，不赶进度。准备好合剂食物，能打完整。'},
 {id:13,activity:'undermine',difficulty:'heroic',title:'英雄安德麦，周常全通',leader:'moon',members:['moon','rain','tea'],size:18,max:20,counts:[2,4,12],ilvl:640,minScore:0,age:110,progress:'3/8',comment:'当前三号已过，补两位稳定输出。'},
 {id:14,activity:'undermine',difficulty:'normal',title:'普通团本 清进度一起打',leader:'tea',members:['wind','tea','bird'],size:9,max:20,counts:[2,1,6],ilvl:615,minScore:0,age:180,progress:'1/8',comment:'一边讲一边打，态度友好。新手请说明熟悉程度。'}
];
const applicants = [
 {id:71,ids:['wind','sugar','star','bird','tea'],comment:'五人一起，语音沟通，熟悉机制。',status:'applied'},
 {id:72,ids:['rain'],comment:'单人治疗，随时可以出发。',status:'applied'},
 {id:73,ids:['night','moon'],comment:'坦和输出一起，有合剂食物。',status:'applied'},
 {id:74,ids:['panda'],comment:'周常打完，机制会。',status:'applied'}
];

people.push(
 {id:'leaf',name:'青叶',realm:'白银之手',class:'HUNTER',role:'DAMAGER',spec:'野兽控制',ilvl:646,score:3021},
 {id:'ember',name:'烛火',realm:'晨风号角',class:'WARLOCK',role:'DAMAGER',spec:'毁灭',ilvl:647,score:2952},
 {id:'cloud',name:'云间',realm:'凤凰之神',class:'MAGE',role:'DAMAGER',spec:'奥术',ilvl:645,score:2988},
 {id:'frost',name:'寒汀',realm:'白银之手',class:'DEATHKNIGHT',role:'DAMAGER',spec:'冰霜',ilvl:648,score:3105},
 {id:'stone',name:'山眠',realm:'晨风号角',class:'WARRIOR',role:'DAMAGER',spec:'狂怒',ilvl:646,score:2930},
 {id:'light',name:'浮光',realm:'凤凰之神',class:'PALADIN',role:'DAMAGER',spec:'惩戒',ilvl:648,score:3023},
 {id:'plum',name:'梅子青',realm:'白银之手',class:'EVOKER',role:'DAMAGER',spec:'湮灭',ilvl:645,score:2910},
 {id:'harbor',name:'远港',realm:'晨风号角',class:'ROGUE',role:'DAMAGER',spec:'敏锐',ilvl:647,score:2975},
 {id:'dew',name:'朝露',realm:'白银之手',class:'PRIEST',role:'HEALER',spec:'神圣',ilvl:646,score:3027}
);
Object.assign(classInfo,{HUNTER:['猎','#aad372'],DEATHKNIGHT:['死','#c75e72'],EVOKER:['龙','#74b5aa']});
person('wind').friend=true;
person('star').friend=true;
person('sugar').guild=true;
person('tea').guild=true;
person('leaf').guild=true;
person('moon').friend=true;
initialNotes.push({id:'night',type:'caution',name:'长夜微光',realm:'凤凰之神',classSpec:'恶魔猎手 · 复仇',date:'26/10/13',reason:'上次提前离队；再组之前先确认能否打完整场。'});
groups.forEach(g=>{g.category=act(g.activity).kind==='raid'?'season-raids':'season-dungeons';g.difficulty=g.difficulty||'keystone';});
groups.find(g=>g.id===11).members=people.slice(0,17).map(p=>p.id);
groups.find(g=>g.id===12).members=['wind','night','sugar','rain','star','tea','moon','bird','leaf','ember','cloud','frost'];
groups.find(g=>g.id===13).members=people.slice(0,18).map(p=>p.id);
groups.find(g=>g.id===14).members=['wind','night','sugar','star','tea','moon','bird','leaf','ember'];
groups.push(
 {id:9,category:'season-dungeons',activity:'neltharus',difficulty:'keystone',title:'+10 奈萨鲁斯，稳定打完',leader:'stone',members:['stone','dew','cloud'],level:10,ilvl:635,minScore:2500,age:70,comment:'正常打完，开怪前确认路线。'},
 {id:15,category:'season-raids',activity:'palace',difficulty:'mythic',title:'史诗王宫，固定队补位',leader:'wind',members:people.slice(0,18).map(p=>p.id),size:18,max:20,counts:[2,4,12],ilvl:645,minScore:0,age:230,progress:'2/8',comment:'固定时间开团，找愿意长期磨合的队友。'},
 {id:21,category:'dungeons',activity:'academy',difficulty:'heroic',title:'英雄学院，轻松打完',leader:'tea',members:['wind','tea','bird'],ilvl:600,minScore:0,age:40,comment:'练习路线，随时出发。'},
 {id:22,category:'dungeons',activity:'mists',difficulty:'mythic',title:'史诗迷雾，熟悉机制',leader:'sugar',members:['night','sugar'],ilvl:610,minScore:0,age:75,comment:'会讲迷宫和首领机制。'},
 {id:23,category:'dungeons',activity:'academy',difficulty:'normal',title:'普通学院，任务一起做',leader:'panda',members:['panda','bird'],ilvl:0,minScore:0,age:90,comment:'任务顺路，有需要的朋友一起。'},
 {id:24,category:'dungeons',activity:'academy',difficulty:'mythic',title:'史诗学院，熟悉路线',leader:'rain',members:['wind','rain','star'],ilvl:610,minScore:0,age:120,comment:'先确认机制，慢慢打完。'},
 {id:25,category:'dungeons',activity:'threads',difficulty:'heroic',title:'英雄千丝之城，轻松打完',leader:'tea',members:['tea','bird'],ilvl:600,minScore:0,age:60,comment:'一起完成周常。'},
 {id:31,category:'delves',activity:'fungal',difficulty:'delve',title:'真菌之愚 8 层，打完拿箱子',leader:'rain',members:['rain','tea'],level:8,ilvl:620,minScore:0,age:60,comment:'一起完成，不赶时间。'},
 {id:32,category:'delves',activity:'waterworks',difficulty:'delve',title:'水能堡，周常同行',leader:'bird',members:['wind','bird'],level:8,ilvl:620,minScore:0,age:130,comment:'有钥匙，互相照应。'},
 {id:41,category:'pvp',activity:'arena2',title:'2v2 练习配合，来治疗',leader:'moon',members:['moon'],max:2,ilvl:630,minScore:0,age:50,comment:'以练习为主，能沟通就好。'},
 {id:42,category:'pvp',activity:'battleground',title:'评级战场，来会沟通的队友',leader:'wind',members:['wind','sugar','star','tea','bird'],max:10,counts:[1,1,3],ilvl:635,minScore:0,age:90,comment:'组满后确认职责与目标。'},
 {id:51,category:'quests',activity:'worldquest',title:'世界任务一起清，顺路同行',leader:'panda',members:['panda','tea'],ilvl:0,minScore:0,age:80,comment:'随做随走，轻松清任务。'},
 {id:61,category:'custom',activity:'custom',title:'旧副本幻化，休闲收集',leader:'star',members:['star','bird'],ilvl:0,minScore:0,age:100,comment:'一起刷外观，有想去的副本可以说。'}
);
people.push(...[
 ['cedar','杉月','HUNTER','射击'],['ash','灰烬','WARLOCK','恶魔学识'],['tide','潮生','MAGE','火焰'],
 ['cinder','流萤','DEATHKNIGHT','邪恶'],['oak','秋橡','WARRIOR','武器'],['dawn','晓光','PALADIN','惩戒'],
 ['kite','纸鸢','EVOKER','增辉'],['shade','竹影','ROGUE','奇袭'],['lily','听荷','DRUID','野性'],
 ['sand','沙洲','MONK','踏风'],['mist','山岚','SHAMAN','元素'],['snow','初雪','PRIEST','暗影']
].map(([id,name,playerClass,spec],i)=>({id,name,class:playerClass,spec,realm:['白银之手','晨风号角','凤凰之神'][i%3],role:'DAMAGER',ilvl:640+i%8,score:2800+i*17})));
const ownPartyIds=()=>state.partyMode==='raid'?people.map(p=>p.id):['wind','sugar','star'];
const ownPartyName=()=>state.partyMode==='raid'?'当前团队':'当前队伍';
const noteTypes={positive:{label:'推荐',icon:'heart',hint:'想再一起组队，把好队友留在笔记里。'},neutral:{label:'中性',icon:'book',hint:'记下见过的人、约定或其他背景。'},caution:{label:'拉黑',icon:'caution',hint:'记录拉黑原因，再次遇到时提醒。'}};
const defaultSettings={relations:true,noteMarks:true,rememberFilters:true,defaultSort:'newest',defaultNote:'neutral',reminders:'all',history:true,density:'comfortable',motion:false,tooltipDelay:180,raidMembers:'shift'};
const defaultForm={category:'season-raids',activity:'palace',difficulty:'heroic',title:'英雄尼鲁巴尔王宫',description:'',ilvl:635,score:0,playstyle:'高阶挑战',private:false,cross:true,auto:false};
let state={};
function resetState(){
 state={createActivityQuery:'',autoTitle:true,partyMode:'raid',page:'find',lastMain:'find',category:'season-dungeons',expansion:'all',activity:'all',difficulty:'keystone',activityQuery:'',query:'',personFilter:null,sort:'newest',mode:'results',selected:null,filters:{},savedFilters:{},apps:{2:'applied',4:'invited'},notes:structuredClone(initialNotes),noteQuery:'',noteTab:'all',editNote:null,noteDraft:null,settings:{...defaultSettings},settingsSection:'browse',filtersExpanded:false,listing:null,editing:false,form:{...defaultForm},selectedApplicant:null,appRole:'',appSort:'newest',appStatus:Object.fromEntries(applicants.map(a=>[a.id,a.status])),searching:false};
 state.applicationDeadlines={2:Date.now()+300000};
}
resetState();
const noteOf=id=>state.notes.find(n=>n.id===id);
const noted=id=>!!noteOf(id);
const classIcon=(m,withRole=true)=>m?`<span class="class-icon" style="--class:${colorOf(m)}">${classInfo[m.class]?.[0]||'?'}${withRole?roleIcon(m.role):''}</span>`:`<span class="class-icon empty">${icon('plus')}</span>`;
const roleIcon=role=>`<span class="role-icon" title="${roleNames[role]}" aria-label="${roleNames[role]}">${icon(roleIcons[role])}</span>`;
const roleCount=ids=>['TANK','HEALER','DAMAGER'].map(r=>ids.filter(id=>person(id).role===r).length);
function roster(ids,max=5,counts){
 if(max>5){counts=counts||roleCount(ids);return `<div class="raid-composition">${['TANK','HEALER','DAMAGER'].map((r,i)=>`<span>${roleIcon(r)}${counts[i]}</span>`).join('')}</div>`;}
 return `<div class="roster-strip">${Array.from({length:Math.min(max,5)},(_,i)=>classIcon(ids[i]?person(ids[i]):null)).join('')}</div>`;
}
const age=n=>n<60?'刚刚':`${Math.floor(n/60)} 分钟前`;
const statusName=s=>({invited:'收到邀请',accepted:'已接受',cancelled:'已取消',declined:'已拒绝',timedout:'申请已过期'}[s]||'');
const applicantStatus=s=>({applied:'待处理',invited:'已邀请',declined:'已拒绝'}[s]||'');
const applicationCountdown=id=>{const seconds=Math.max(0,Math.ceil((state.applicationDeadlines[id]-Date.now())/1000));return `${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;};
const status=(s,fallback='',id)=>s==='applied'?`<span class="status applied" data-application-countdown="${id}" title="申请剩余时间" aria-label="申请剩余 ${applicationCountdown(id)}">${applicationCountdown(id)}</span>`:`<span class="status ${esc(s)}">${esc(statusName(s)||fallback)}</span>`;
const activeApplication=id=>['applied','invited'].includes(state.apps[id]);
const countActive=()=>groups.filter(g=>activeApplication(g.id)).length;
const $page=$('#page');
let toastTimer,searchTimer,tipOwner,tipTimer,tipPoint,shiftDown=false;
let applicationTimer;
function refreshApplicationCountdowns(){
 clearTimeout(applicationTimer);
 let expired=false,pending=false;
 for(const [id,s] of Object.entries(state.apps))if(s==='applied'){
  if(Date.now()>=state.applicationDeadlines[id]){state.apps[id]='timedout';delete state.applicationDeadlines[id];expired=true;}
  else pending=true;
 }
 if(expired&&state.page==='find')renderFindResults();
 document.querySelectorAll('[data-application-countdown]').forEach(el=>{const text=applicationCountdown(el.dataset.applicationCountdown);el.textContent=text;el.setAttribute('aria-label',`申请剩余 ${text}`);});
 if(pending)applicationTimer=setTimeout(refreshApplicationCountdowns,1000);
}
function toast(message){clearTimeout(toastTimer);$('#toast').textContent=message;$('#toast').classList.add('visible');toastTimer=setTimeout(()=>$('#toast').classList.remove('visible'),3000);}
function options(entries,selected){return entries.map(([v,l])=>`<option value="${esc(v)}" ${String(v)===String(selected)?'selected':''}>${esc(l)}</option>`).join('');}
function noteBadge(id,compact=false){const n=noteOf(id);if(!n||!state.settings.noteMarks)return '';const t=noteTypes[n.type];return `<span class="person-tag note-${n.type}" title="荔枝笔记 · ${t.label}">${icon(t.icon)}${compact?'':t.label}</span>`;}
function personRelations(id,compact=false){if(!state.settings.relations)return '';const p=person(id);return (p.friend?`<span class="person-tag friend" title="好友">${icon('friend')}${compact?'':'好友'}</span>`:'')+(p.guild?`<span class="person-tag guild" title="同公会">${icon('guild')}${compact?'':'同公会'}</span>`:'');}
function groupSignals(ids){const chips=[];if(state.settings.relations){const friends=ids.filter(id=>person(id).friend).length,guild=ids.filter(id=>person(id).guild).length;if(friends)chips.push(`<span class="signal friend">${icon('friend')}好友 ${friends}</span>`);if(guild)chips.push(`<span class="signal guild">${icon('guild')}公会 ${guild}</span>`);}if(state.settings.noteMarks)for(const [type,info] of Object.entries(noteTypes)){const count=ids.filter(id=>noteOf(id)?.type===type).length;if(count)chips.push(`<span class="signal note-${type}">${icon(info.icon)}${info.label} ${count}</span>`);}return chips.length?`<span class="group-signals">${chips.join('')}</span>`:'';}
function nav(){const labels={find:['search','寻求组队'],create:['plus','创建组队'],notes:['book','荔枝笔记']};$('#main-nav').innerHTML=Object.entries(labels).map(([key,[glyph,label]])=>`<button class="nav-button ${state.page===key?'active':''}" data-page="${key}" aria-current="${state.page===key?'page':'false'}">${icon(glyph)}${label}</button>`).join('');$('.settings-button').textContent='设置';$('.settings-button').classList.toggle('active',state.page==='settings');$('#close-window').innerHTML=icon('close');}
function navigate(page){if(page!=='settings')state.lastMain=page;state.page=page;hideTip();closeModal();renderPage(true);}
function renderPage(animate=false){
 hideTip();nav();document.body.classList.toggle('reduce-motion',state.settings.motion);document.body.classList.toggle('density-compact',state.settings.density==='compact');$page.classList.remove('enter');
 $page.innerHTML=({find:renderFind,create:renderCreate,notes:renderNotes,settings:renderSettings}[state.page])();
 if(state.page==='find')renderFindResults();
 if(animate&&!state.settings.motion){void $page.offsetWidth;$page.classList.add('enter');}
}
function changeCategory(id){
 if(state.settings.rememberFilters)state.savedFilters[state.category]={filters:{...state.filters},sort:state.sort,activity:state.activity,difficulty:state.difficulty,expansion:state.expansion};
 state.category=id;state.activity='all';state.difficulty=id==='season-dungeons'?'keystone':'all';state.expansion='all';state.sort=state.settings.defaultSort;state.filters={};
 if(state.settings.rememberFilters&&state.savedFilters[id])Object.assign(state,structuredClone(state.savedFilters[id]));
 state.query='';state.personFilter=null;state.selected=null;state.mode='results';renderPage(true);
}
function renderCategoryRail(){return `<aside class="category-rail surface"><p class="rail-label">活动</p>${categories.map((c,i)=>`${i===2?'<div class="category-divider"><span>更多活动</span></div>':''}<button class="category-item ${state.category===c.id?'active':''}" data-category="${c.id}" aria-pressed="${state.category===c.id}">${icon(c.icon)}<span>${c.name}</span>${state.category===c.id?icon('chevron'):''}</button>`).join('')}</aside>`;}
function difficultySwitch(category,value,attribute,includeAll=false,activityID='all',expansion='all'){
 const choices=difficulties(category,activityID,expansion);if(!choices.length)return '';
 if(choices.length===1)return `<span class="difficulty-fixed">${choices[0][1]}</span>`;
 return `<div class="difficulty-switch" role="group" aria-label="难度">${(includeAll?[['all','全部'],...choices]:choices).map(([key,label])=>`<button type="button" ${attribute}="${key}" class="${value===key?'active':''}" aria-pressed="${value===key}">${label}</button>`).join('')}</div>`;
}
function renderActivityPicker(){const c=categoryOf(state.category);return `<div class="activity-picker">${c.expansion?`<select id="expansion-filter" aria-label="资料片">${options([['all','全部资料片'],...expansionOptions(c.id)],state.expansion)}</select>`:''}<div class="activity-select-field">${state.activity==='all'?icon(c.icon):activityArt(act(state.activity))}<select id="activity-filter" aria-label="副本或活动">${options([['all',c.kind==='raid'?'全部团本':c.kind==='dungeon'?'全部地下城':'全部活动'],...categoryActivities(c.id,state.expansion).map(a=>[a.id,a.name])],state.activity)}</select></div>${difficultySwitch(c.id,state.difficulty,'data-difficulty',true,state.activity,state.expansion)}</div>`;}
function renderFind(){
 const c=categoryOf(state.category),keys=usesKeyFilters(),raid=c.kind==='raid';
 return `<div class="find-layout">${renderCategoryRail()}<div class="find-main"><div class="find-heading"><h1>${c.name}</h1></div>${renderActivityPicker()}<form class="search-bar ${state.searching?'searching':''}" id="search-form"><div class="search-field">${icon('search')}<input id="group-query" aria-label="搜索队伍" placeholder="队伍名称、说明或队长" value="${esc(state.query)}"></div><button class="button primary" ${state.searching?'disabled':''}>${icon('refresh')}${state.searching?'搜索中':'刷新'}</button>${renderFilterToggle()}</form><div id="search-filters" class="filter-drawer ${state.filtersExpanded?'open':''}" ${state.filtersExpanded?'':'inert'}><div class="filter-inner"><div class="filters">${numberFilter('rating','评分 ≥')}${numberFilter('ilvl','装等 ≥')}${numberFilter('members','人数 ≤')}${keys?numberFilter('min','层数 ≥')+numberFilter('max','层数 ≤')+`<select id="role-filter" aria-label="队伍缺少职责">${options([['','不限职责'],['TANK','缺坦克'],['HEALER','缺治疗'],['DAMAGER','缺输出']],state.filters.role||'')}</select>`:''}<button class="reset-filters" data-action="clear-filters">清空条件</button></div></div></div><div class="list-toolbar"><div class="list-tabs"><button data-mode="results" class="${state.mode==='results'?'active':''}">队伍 <span class="count" id="result-count"></span></button><button data-mode="applications" class="${state.mode==='applications'?'active':''}">我的申请 <span class="count">${countActive()}</span></button></div><div class="list-tools"><select id="social-filter" aria-label="关系与笔记筛选">${options([['','全部关系'],['friend','好友在队'],['guild','同公会成员'],['noted','含笔记记录'],['positive','含推荐玩家'],['caution','含拉黑记录']],state.filters.social||'')}</select><select id="sort-results" aria-label="队伍排序">${sortOptions(state.sort)}</select></div></div><div class="table-head"><span>队伍 / 成员标记</span><span>${raid?'职责 / 进度':'队伍构成'}</span><span class="number">队长评分</span><span class="number">要求装等</span><span class="number">人数</span><span class="number">状态</span></div><div class="group-list" id="group-list"></div><div id="selected-group"></div></div></div>`;
}
const filterCount=()=>['rating','ilvl','members',...(usesKeyFilters()?['min','max','role']:[])].filter(key=>state.filters[key]).length;
function renderFilterToggle(){const count=filterCount();return `<button type="button" class="filter-toggle ${state.filtersExpanded?'expanded':''}" data-action="toggle-filters" aria-label="${state.filtersExpanded?'收起':'展开'}筛选条件" aria-expanded="${state.filtersExpanded}" aria-controls="search-filters">${icon('chevron')}<span class="filter-count" ${count?'':'hidden'}>${count}</span></button>`;}
function numberFilter(key,label){return `<label class="number-filter"><span>${label}</span><input type="number" min="0" data-filter="${key}" aria-label="${label}" value="${state.filters[key]||''}"></label>`;}
const sortOptions=value=>options([['newest','最新'],['rating','队长评分'],['ilvl','要求装等'],['members','队伍人数']],value);
function groupInCategory(g){const c=categoryOf(state.category);return c.season?act(g.activity).season&&act(g.activity).kind===c.kind:['dungeons','raids'].includes(c.id)?act(g.activity).kind===c.kind:g.category===c.id;}
function filteredGroups(){
 let list=groups.filter(g=>state.mode==='applications'?activeApplication(g.id):groupInCategory(g)&&(state.activity==='all'||g.activity===state.activity)&&(state.expansion==='all'||act(g.activity).expansion===state.expansion)&&(state.difficulty==='all'||g.difficulty===state.difficulty));
 if(state.mode==='results')list=list.filter(g=>{const f=state.filters,m=person(g.leader),q=state.query.trim();
 if(state.personFilter){if(!g.members.includes(state.personFilter))return false;}else if(q&&!`${g.title}${g.comment}${m.name}`.includes(q))return false;
 if(f.rating&&m.score<f.rating||f.ilvl&&g.ilvl<f.ilvl||f.members&&(g.size||g.members.length)>f.members)return false;
 if(usesKeyFilters()){if((f.min||f.max)&&g.difficulty!=='keystone')return false;if(f.min&&g.level<f.min||f.max&&g.level>f.max)return false;if(f.role){const idx=['TANK','HEALER','DAMAGER'].indexOf(f.role);if(roleCount(g.members)[idx]>=(idx===2?3:1))return false;}}
 if(f.social==='friend'&&!g.members.some(id=>person(id).friend))return false;
 if(f.social==='guild'&&!g.members.some(id=>person(id).guild))return false;
 if(f.social==='noted'&&!g.members.some(noted))return false;
 if(['positive','caution'].includes(f.social)&&!g.members.some(id=>noteOf(id)?.type===f.social))return false;
 return true;});
 return list.sort((a,b)=>state.sort==='rating'?person(b.leader).score-person(a.leader).score:state.sort==='ilvl'?b.ilvl-a.ilvl:state.sort==='members'?(b.size||b.members.length)-(a.size||a.members.length):a.age-b.age);
}
function renderFindResults(){
 hideTip();const list=filteredGroups();if(!list.some(g=>g.id===state.selected))state.selected=null;
 $('#result-count').textContent=state.mode==='applications'?groups.filter(groupInCategory).length:list.length;
 $('#group-list').innerHTML=list.length?list.map(groupRow).join(''):`<div class="empty-state">${icon('search')}<h2>${state.mode==='applications'?'暂无待处理的申请':'没有符合条件的队伍'}</h2><p>${state.mode==='applications'?'选中合适的队伍，申请加入。':'可以切换副本或难度，也可以放宽筛选。'}</p><button class="button primary" data-action="${state.mode==='applications'?'back-results':'clear-filters'}">${state.mode==='applications'?'浏览队伍':'清空条件'}</button></div>`;
 $('#selected-group').innerHTML=state.selected?groupDetail(groups.find(g=>g.id===state.selected)):'';
 document.querySelectorAll('.list-tabs .count')[1].textContent=countActive();$('.filter-count').textContent=filterCount();$('.filter-count').hidden=!filterCount();
}
function groupRow(g){
 const m=person(g.leader),a=act(g.activity),s=state.apps[g.id];
 return `<button class="group-row ${state.selected===g.id?'selected':''}" data-group="${g.id}" data-tip-group="${g.id}" aria-label="${esc(g.title)}"><span class="group-name-cell">${activityArt(a,g.level,true)}<span class="group-copy"><strong class="group-title truncate">${esc(g.title)}</strong><small class="truncate">${a.name}${g.difficulty&&g.difficulty!=='keystone'?' · '+difficultyNames[g.difficulty]:''} · ${m.name}</small>${groupSignals(g.members)}</span></span><span>${roster(g.members,g.max||5,g.counts)}${g.progress?`<span class="raid-progress">已击败 ${g.progress}</span>`:''}</span><span class="number">${m.score}</span><span class="number">${g.ilvl||'不限'}</span><span class="number">${g.size||g.members.length}/${g.max||5}</span>${status(s,age(g.age),g.id)}</button>`;
}
function groupDetail(g){
 const m=person(g.leader),s=state.apps[g.id];
 const actions=s==='invited'?`<button class="button primary" data-action="accept-invite" data-id="${g.id}">接受邀请</button><button class="button" data-action="decline-invite" data-id="${g.id}">婉拒邀请</button>`:s==='applied'?`<button class="button secondary" data-action="cancel-application" data-id="${g.id}">取消申请</button><span class="status applied">等待队长处理</span>`:`<button class="button primary" data-action="apply" data-id="${g.id}">申请加入</button>`;
 return `<section class="group-detail"><div><h2 class="truncate">${esc(g.title)}</h2><p class="leader-line">队长：<span style="color:${colorOf(m)}">${m.name}</span>${personRelations(m.id)}${noteBadge(m.id)}</p><p class="description">${esc(g.comment)}</p><div class="detail-bottom"><button class="text-action" data-action="group-notes" data-id="${g.id}">${icon('book')}查看成员笔记</button><span>最低评分 ${g.minScore||'不限'}${g.level?`　·　标题层数 +${g.level}`:''}</span></div></div><div class="detail-actions">${actions}<button class="button secondary" data-note-person="${m.id}">${icon('book')}${noted(m.id)?'查看队长笔记':'记到荔枝笔记'}</button></div></section>`;
}
function renderCreate(){
 const editing=!state.listing||state.editing;
 if(editing)return `<div class="create-layout is-editing">${renderListingActivity()}<div class="create-main">${renderForm()}</div></div>`;
 return `<div class="create-layout"><div class="create-main">${renderManagement()}</div><aside class="group-rail surface"><div class="rail-title"><h2>${ownPartyName()}</h2><small>${ownPartyIds().length} 人</small></div>${roster(ownPartyIds(),30)}${state.selectedApplicant?renderApplicantDetail():`<div class="own-party-rail-list">${ownPartyIds().map(id=>ownPartyMember(id)).join('')}</div>`}</aside></div>`;
}
function renderListingActivity(){
 const f=state.form,c=categoryOf(f.category),searching=!!state.createActivityQuery.trim();
 return `<aside class="create-activity-rail surface"><p class="rail-label">活动</p>
  <div class="creation-search">${icon('search')}<input id="create-activity-query" aria-label="搜索全部活动" placeholder="搜索全部活动" value="${esc(state.createActivityQuery)}"><button type="button" class="icon-button" data-action="clear-create-search" aria-label="清空活动搜索" ${searching?'':'hidden'}>${icon('close')}</button></div>
  <div class="creation-category-picker" ${searching?'hidden':''}><select id="listing-category" form="listing-form" name="category" aria-label="招募分类">${options(categories.map(c=>[c.id,c.name]),f.category)}</select>
  ${c.expansion?`<select id="listing-expansion" form="listing-form" name="expansion" aria-label="招募资料片">${options(expansionOptions(c.id),f.expansion||act(f.activity).expansion)}</select>`:''}</div>
  <input type="hidden" id="listing-activity" form="listing-form" name="activity" value="${f.activity}">
  <div id="creation-activity-list" class="creation-activity-list" aria-label="招募副本">${creationActivityRows()}</div>
 </aside>`;
}
function creationActivityRows(){
 const f=state.form,c=categoryOf(f.category),q=state.createActivityQuery.trim().toLowerCase();
 const list=q?activities.filter(a=>`${a.name} ${a.expansion||''}`.toLowerCase().includes(q)):categoryActivities(f.category,c.expansion?(f.expansion||act(f.activity).expansion):'all');
 return list.length?list.map(a=>`<button type="button" class="category-item creation-activity-option ${f.activity===a.id?'active':''}" data-form-activity="${a.id}" aria-pressed="${f.activity===a.id}" title="${a.name}"><span class="truncate">${a.name}</span>${q?`<small class="truncate">${a.expansion||categoryOf(creationCategory(a)).name}</small>`:''}</button>`).join(''):'<p class="creation-search-empty">没有匹配的活动</p>';
}
function creationCategory(a){return a.kind==='dungeon'?(a.season?'season-dungeons':'dungeons'):a.kind==='raid'?(a.season?'season-raids':'raids'):({delve:'delves',pvp:'pvp',quest:'quests',custom:'custom'}[a.kind]);}
function updateCreationTitle(){if(state.autoTitle)state.form.title=`${difficultyNames[state.form.difficulty]||''}${act(state.form.activity).name}`;}
function renderForm(){
 const f=state.form,c=categoryOf(f.category),scoreLabel=ratingLabel(f.activity,f.difficulty),isPvp=c.kind==='pvp'||f.activity==='custom-pvp';
 return `<form class="create-form" id="listing-form">
  <div class="page-title"><h1>${state.editing?'修改组队':'创建组队'}</h1></div>
  <div class="listing-activity-context"><span>${act(f.activity).name}</span>${difficulties(f.category,f.activity).length?difficultySwitch(f.category,f.difficulty,'data-form-difficulty',false,f.activity):''}</div>
  <div class="form-surface">
   <div class="form-section description-section">
   <div class="form-field"><label for="listing-title">队伍名称</label><input id="listing-title" name="title" class="field form-title" required maxlength="100" placeholder="队伍名称" value="${esc(f.title)}"></div>
   <div class="form-field"><label for="listing-description">说明</label><textarea id="listing-description" name="description" class="field form-description" placeholder="组队说明（选填）">${esc(f.description)}</textarea></div>
   </div>
   <div class="form-section requirements-section">
   <div class="requirements-grid ${scoreLabel?'':'without-score'}">
    <div><label for="listing-ilvl">${isPvp?'最低 PvP 装等':'最低装等'}</label><input id="listing-ilvl" name="ilvl" type="number" min="0" value="${f.ilvl}"></div>
    ${scoreLabel?`<div><label for="listing-score">${scoreLabel}</label><input id="listing-score" name="score" type="number" min="0" value="${f.score}"></div>`:''}
    <div><label for="listing-style">玩法风格</label><select id="listing-style" name="playstyle">${options(['新手上路','休闲娱乐','高阶挑战','老手带队'].map(x=>[x,x]),f.playstyle)}</select></div>
   </div>
   <div class="form-options">${[['private','私人队伍'],['cross','跨阵营'],['auto','自动接受']].map(([k,l])=>`<button type="button" class="switch-line" data-form-switch="${k}" role="switch" aria-label="${l}" aria-checked="${f[k]}"><span class="switch ${f[k]?'on':''}"></span>${l}</button>`).join('')}</div>
   </div>
  </div>
  <div class="form-footer">${renderOwnPartySummary()}<div class="creation-submit">${state.editing?'<button type="button" class="button" data-action="cancel-edit-listing">取消</button>':''}<button class="button primary" type="submit">${state.editing?'更新组队':'发布组队'}</button></div></div>
 </form>`;
}
function renderOwnPartySummary(){
 const ids=ownPartyIds();
 return `<div class="creation-party"><div class="creation-party-label">${ownPartyName()} <strong>${ids.length} 人</strong></div><div class="creation-party-summary">${roster(ids,30)}${groupSignals(ids)}<button type="button" class="text-action" data-action="view-own-party">查看成员 ${icon('chevron')}</button></div></div>`;
}
function ownPartyMember(id){
 const m=person(id);
 return `<button type="button" class="own-party-member" data-note-person="${id}">${classIcon(m)}<span class="own-party-copy"><b style="color:${colorOf(m)}">${m.name}${id==='wind'?'<small>队长</small>':''}</b><small>${m.realm} · ${m.spec}</small><span class="member-tags">${personRelations(id)}${noteBadge(id)}</span></span></button>`;
}
function ownPartyModal(){
 const ids=ownPartyIds(),ordered=['TANK','HEALER','DAMAGER'].flatMap(role=>ids.filter(id=>person(id).role===role));
 openModal(`<section class="modal own-party-modal"><header><h2>${ownPartyName()} <span>${ids.length} 人</span></h2><button class="icon-button" data-action="close-modal" aria-label="关闭成员名单">${icon('close')}</button></header><div class="own-party-overview">${roster(ids,30)}${groupSignals(ids)}</div><div class="own-party-list">${ordered.map(id=>ownPartyMember(id)).join('')}</div></section>`);
}
function readForm(){Object.assign(state.form,Object.fromEntries(new FormData($('#listing-form'))));state.form.ilvl=Number(state.form.ilvl)||0;state.form.score=$('#listing-score')?Number(state.form.score)||0:0;}
function renderManagement(){
 const l=state.listing,a=act(l.activity);let list=applicants.filter(x=>!state.appRole||x.ids.some(id=>person(id).role===state.appRole));
 if(state.appSort!=='newest')list.sort((a,b)=>minimum(b,state.appSort)-minimum(a,state.appSort));
 return `<section class="listing-summary">${activityArt(a,null,true)}<div class="summary-copy"><div class="live-label">正在招募</div><h2 class="truncate">${esc(l.title)}</h2><p>${a.name} · ${difficultyNames[l.difficulty]||categoryOf(l.category).name} · 装等 ${l.ilvl} · ${esc(l.playstyle)}</p></div><div class="summary-actions"><button data-action="edit-listing">编辑</button><button data-action="end-listing">结束招募</button></div></section><div class="applicants-heading"><h2>管理申请者</h2><small>${list.length} 组申请</small></div><div class="applicant-controls"><div class="role-filters">${[['','全部'],['TANK','坦克'],['HEALER','治疗'],['DAMAGER','输出']].map(([r,l])=>`<button data-app-role="${r}" class="${state.appRole===r?'active':''}">${r?roleIcon(r):''}${l}</button>`).join('')}</div><select id="sort-applicants" aria-label="申请者排序">${options([['newest','最新'],['score','评分'],['ilvl','装等']],state.appSort)}</select></div><div class="applicant-head"><span>申请者 / 成员标记</span><span>同行成员</span><span class="number">最低装等</span><span class="number">最低评分</span><span class="number">状态</span></div><div class="applicant-list">${list.map(applicantRow).join('')||'<div class="empty-state"><h2>没有该职责的申请</h2><p>切换到全部，继续比较其他队友。</p></div>'}</div>`;
}
function minimum(a,key){return Math.min(...a.ids.map(id=>person(id)[key]));}
function applicantRow(a){
 const m=person(a.ids[0]),s=state.appStatus[a.id];
 return `<button class="applicant-row ${state.selectedApplicant===a.id?'selected':''}" data-applicant="${a.id}" data-tip-applicant="${a.id}"><span class="applicant-name">${classIcon(m,false)}<div><p class="truncate" style="color:${colorOf(m)}">${m.name}${a.ids.length>1?` +${a.ids.length-1}`:''}</p><small class="truncate">${esc(a.comment)}</small>${groupSignals(a.ids)}</div></span>${roster(a.ids)}<span class="number">${minimum(a,'ilvl')}</span><span class="number">${minimum(a,'score')}</span><span class="status ${s} number">${applicantStatus(s)}</span></button>`;
}
function renderApplicantDetail(){
 const a=applicants.find(a=>a.id===state.selectedApplicant),s=state.appStatus[a.id];
 return `<section class="applicant-detail"><header><h3>申请者与同行成员</h3><button class="icon-button" data-action="close-applicant" aria-label="关闭申请详情">${icon('close')}</button></header><p>${esc(a.comment)}</p><div class="party-members">${a.ids.map(id=>{const m=person(id);return `<button class="party-member" data-note-person="${id}" data-tip-member="${id}">${classIcon(m,false)}<div><p class="truncate" style="color:${colorOf(m)}">${m.name}</p><small>${roleIcon(m.role)}${m.spec} · 装等 ${m.ilvl} · 评分 ${m.score}</small><span class="member-tags">${personRelations(id)}${noteBadge(id)}</span></div></button>`;}).join('')}</div><div class="party-actions"><button class="button primary" data-action="invite-applicant" ${s!=='applied'?'disabled':''}>${s==='invited'?'已发出邀请':a.ids.length>1?'邀请整组':'邀请加入'}</button><button class="button" data-action="decline-applicant" ${s!=='applied'?'disabled':''}>拒绝</button></div><p class="party-state">${s==='invited'?'等待对方接受邀请。':s==='declined'?'已拒绝这组申请。':''}</p></section>`;
}
const historyRuns=[
 {id:'academy',activity:'academy',level:12,date:'26/10/15',duration:'28:16',ids:['wind','sugar','star','bird','tea']},
 {id:'bracken',activity:'bracken',level:11,date:'26/10/14',duration:'31:42',ids:['night','rain','tea','moon','bird']}
];
function visibleNotes(){return state.notes.filter(n=>(state.noteTab==='all'||n.type===state.noteTab)&&`${n.name}${n.realm}${n.reason}`.includes(state.noteQuery));}
function renderNotes(){
 const history=state.noteTab==='history';
 const tabs=[['all','全部记录'],['positive','推荐'],['neutral','中性'],['caution','拉黑'],['history','历史队友']];
 return `<section class="notes-page">
  <aside class="category-rail notes-rail surface" aria-label="笔记分类"><p class="rail-label">记录</p>${tabs.map(([key,label])=>`<button data-note-tab="${key}" aria-pressed="${state.noteTab===key}" class="category-item ${state.noteTab===key?'active':''} ${key==='history'?'history-nav':''}">${key==='history'?icon('history'):key==='all'?icon('book'):icon(noteTypes[key].icon)}<span>${label}</span><small>${key==='history'?historyRuns.length:key==='all'?state.notes.length:state.notes.filter(n=>n.type===key).length}</small></button>`).join('')}</aside>
  <div class="notes-main"><div class="notes-heading"><div class="page-title"><h1>${history?'历史队友':'荔枝笔记'}</h1></div><span class="reminder-state">${icon('bell')}${{all:'全部记录提醒',positive:'推荐玩家提醒',caution:'仅拉黑记录提醒',off:'重逢提醒已关闭'}[state.settings.reminders]}</span></div>
  ${history?renderHistory():`<div class="notes-toolbar"><input id="notes-query" placeholder="搜索玩家或理由" aria-label="搜索笔记" value="${esc(state.noteQuery)}"><div><button class="button" data-action="import-notes">导入</button><button class="button" data-action="export-notes">导出</button><button class="button primary" data-action="add-note">${icon('plus')}添加记录</button></div></div><div class="notes-workspace ${state.editNote?'has-drawer':''}"><div class="notes-list-area"><div class="notes-head"><span>记录</span><span>玩家</span><span>理由</span><span></span></div><div id="notes-list">${notesRows()}</div><div class="notes-count">${visibleNotes().length} 条记录</div></div>${state.editNote?renderNoteDrawer():''}</div>`}
  </div></section>`;
}
function notesRows(){const list=visibleNotes();return list.length?list.map(noteRow).join(''):'<div class="empty-state"><h2>这里还没有记录</h2></div>';}
function noteRow(n){
 const info=noteTypes[n.type];
 return `<div class="note-row ${state.editNote===n.id?'selected':''}"><button class="note-row-main" data-edit-note="${esc(n.id)}" data-tip-note="${esc(n.id)}"><span class="note-type note-${n.type}">${icon(info.icon)}${info.label}</span><span class="note-player"><p>${esc(n.name)}</p><small class="truncate">${esc(n.realm)} · ${esc(n.classSpec)}</small></span><span class="note-reason">${esc(n.reason||'无理由')}<small>${n.date}</small></span></button><button class="find-person" data-find-person="${esc(n.id)}" aria-label="查找${esc(n.name)}的队伍" title="查找队伍">${icon('search')}<span>查找队伍</span></button></div>`;
}
function renderNoteDrawer(){
 const n=state.editNote==='new'?state.noteDraft:noteOf(state.editNote),adding=state.editNote==='new';
 return `<aside class="notes-drawer"><header><h2>${adding?'添加记录':'编辑记录'}</h2><button class="icon-button" data-action="close-note" aria-label="关闭编辑">${icon('close')}</button></header><label for="note-identity">玩家</label>${adding?`<input class="identity-input" id="note-identity" placeholder="名字-服务器" value="${esc(n.name+(n.realm?'-'+n.realm:''))}">`:`<p class="identity truncate">${esc(n.name)}-${esc(n.realm)}</p>`}<p class="spec-line">记录时：${esc(n.classSpec||'未知')}</p><label>这段组队经历</label><div class="note-type-switch" role="group" aria-label="记录类型">${Object.entries(noteTypes).map(([type,t])=>`<button class="note-${type} ${n.type===type?'active':''}" data-note-type="${type}" aria-pressed="${n.type===type}">${icon(t.icon)}${t.label}</button>`).join('')}</div><label for="note-reason">记录理由</label><textarea id="note-reason" placeholder="写下当时发生的事">${esc(n.reason)}</textarea><div class="drawer-actions">${!adding?'<button class="danger" data-action="delete-note">删除</button>':'<span style="margin-right:auto"></span>'}<button class="button" data-action="close-note">取消</button><button class="button primary" data-action="save-note">保存</button></div></aside>`;
}
function openPersonNote(id){
 state.page='notes';state.lastMain='notes';state.noteTab='all';state.noteQuery='';state.editNote=noteOf(id)?id:'new';state.noteDraft=null;
 if(state.editNote==='new'){const m=person(id);state.noteDraft={id,name:m.name,realm:m.realm,classSpec:`${classInfo[m.class]?.[0]||''} · ${m.spec}`,reason:'',type:state.settings.defaultNote};}
 hideTip();closeModal();renderPage(true);
}
function saveNote(){
 const reason=$('#note-reason').value,type=$('[data-note-type].active').dataset.noteType;
 if(state.editNote==='new'){
  const parts=$('#note-identity').value.trim().split('-'),name=parts.shift(),realm=parts.join('-');
  if(!name||!realm){toast('填写玩家名和服务器，便于区分同名玩家。');$('#note-identity').focus();return;}
  const m=people.find(m=>m.name===name&&m.realm===realm),existing=state.notes.find(n=>n.name===name&&n.realm===realm);
  const n={id:m?.id||state.noteDraft?.id||`note-${Date.now()}`,name,realm,reason,type,classSpec:state.noteDraft?.classSpec||'未知',date:'26/10/15'};
  if(existing)Object.assign(existing,n);else state.notes.unshift(n);state.editNote=n.id;state.noteDraft=null;
 }else Object.assign(noteOf(state.editNote),{reason,type});
 state.noteTab='all';renderPage();toast('荔枝组队提醒：记录已保存。');
}
function renderHistory(){
 return `<div class="history-page"><div class="history-caption"><span>当前角色完成的大秘境</span><span>${state.settings.history?'自动记录已开启':'自动记录已关闭，已有历史保留'}</span></div><div class="history-run-head"><span>活动</span><span>队友</span><span>完成时间</span><span></span></div>${historyRuns.map(run=>`<button class="history-run" data-action="history" data-run="${run.id}"><span class="history-activity">${activityArt(act(run.activity),run.level,true)}<span><b>${act(run.activity).name}</b><small>+${run.level} · ${run.duration}</small></span></span><span>${roster(run.ids)}${groupSignals(run.ids)}</span><span>${run.date}</span>${icon('chevron')}</button>`).join('')}</div>`;
}
function historyModal(id){
 const run=historyRuns.find(r=>r.id===id);
 openModal(`<section class="modal"><header><h2>历史队友</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${act(run.activity).name} · +${run.level} · ${run.date}</p><div class="history-members">${run.ids.map(id=>{const m=person(id);return `<button data-note-person="${id}">${classIcon(m,false)}<span class="history-member-copy"><b style="color:${colorOf(m)}">${m.name}-${m.realm}</b><small>${personRelations(id)}${noteBadge(id)}</small></span><span class="dim">${noted(id)?'查看笔记':'记一笔'}</span></button>`;}).join('')}</div></section>`);
}
function findPerson(id){
 const n=noteOf(id),matches=groups.filter(g=>g.members.includes(id)),g=matches.find(groupInCategory)||matches[0];
 state.page='find';state.lastMain='find';state.mode='results';state.category=g?.category||'season-dungeons';state.activity='all';state.difficulty='all';state.expansion='all';state.filters={};state.selected=null;state.personFilter=id;state.query=n.name;renderPage(true);
}
function groupNotesModal(id){
 const g=groups.find(g=>g.id===id),known=g.members.filter(noted);
 openModal(`<section class="modal group-notes-modal"><header><h2>队伍中的荔枝笔记</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${esc(g.title)}</p><div class="group-note-list">${known.length?known.map(id=>{const n=noteOf(id);return `<button data-note-person="${id}"><span class="group-note-name">${noteBadge(id)}<b>${n.name}-${n.realm}</b>${id===g.leader?'<small>队长</small>':''}</span><p>${esc(n.reason)}</p></button>`;}).join(''):'<p class="dim">这支队伍暂无记录。可以先记录队长。</p>'}</div></section>`);
}

const settingsSections={browse:['search','队伍浏览'],notes:['book','笔记与提醒'],interface:['settings','界面与提示']};
function switchSetting(key,label,hint){return `<div class="setting-row"><div><h3>${label}</h3><p>${hint}</p></div><button class="setting-control" role="switch" aria-label="${label}" aria-checked="${state.settings[key]}" data-setting="${key}"><span>${state.settings[key]?'开启':'关闭'}</span><span class="switch ${state.settings[key]?'on':''}"></span></button></div>`;}
function selectSetting(key,label,hint,choices){return `<div class="setting-row"><div><h3>${label}</h3><p>${hint}</p></div><select data-setting-select="${key}" aria-label="${label}">${options(choices,state.settings[key])}</select></div>`;}
function renderSettings(){
 let content='';
 if(state.settingsSection==='browse')content=selectSetting('defaultSort','默认排序','进入其他活动分类时采用的排序。',[['newest','最新'],['rating','队长评分'],['ilvl','要求装等'],['members','队伍人数']])+switchSetting('rememberFilters','记住各分类的筛选','切换活动后，恢复该分类上次选择的副本、难度和条件。')+switchSetting('relations','好友与公会标记','在队伍、申请者和成员提示中显示关系。')+switchSetting('noteMarks','荔枝笔记标记','分别显示推荐、中性和拉黑记录；包含队伍成员。');
 if(state.settingsSection==='notes')content=selectSetting('defaultNote','新记录的默认类型','每次记笔记时仍可选择其他类型。',Object.entries(noteTypes).map(([id,t])=>[id,t.label]))+selectSetting('reminders','再次组队时提醒','遇到已记录玩家时，按你选择的范围提醒。',[['all','全部记录'],['positive','仅推荐'],['caution','仅拉黑'],['off','不提醒']])+switchSetting('history','记录大秘境历史队友','完成后保留活动与成员，便于回顾和补充笔记。')+`<div class="setting-preview"><div><h3>看看提醒是什么样</h3></div><button class="button secondary" data-action="preview-reminder">${icon('bell')}演示提醒</button></div>`;
 if(state.settingsSection==='interface')content=selectSetting('density','队伍列表密度','标准保留更多留白；紧凑能同时浏览更多队伍。',[['comfortable','标准'],['compact','紧凑']])+switchSetting('motion','减少动态效果','关闭开窗位移、Logo 动作和局部过渡。')+selectSetting('tooltipDelay','悬停提示延迟','快速掠过队伍时，减少提示框频繁出现。',[[0,'立即显示'],[180,'稍作停留'],[400,'停留更久']])+selectSetting('raidMembers','团本成员列表','控制团本悬停提示中何时展开成员。',[['shift','按住 Shift 展开'],['always','始终展开']]);
 return `<section class="settings-page"><div class="settings-layout"><nav class="settings-nav category-rail surface" aria-label="设置分类"><p class="rail-label">设置</p>${Object.entries(settingsSections).map(([id,[glyph,label]])=>`<button data-settings-section="${id}" class="category-item ${state.settingsSection===id?'active':''}"><span>${label}</span></button>`).join('')}</nav><div class="settings-main"><div class="page-title"><h1>${settingsSections[state.settingsSection][1]}</h1><button class="button" data-page="${state.lastMain}">${icon('arrow')}返回</button></div><div class="settings-body"><div class="settings-stack">${content}</div></div></div></div></section>`;
}
function previewReminder(){
 const chosen=state.notes.filter(n=>state.settings.reminders==='all'||n.type===state.settings.reminders);
 openModal(`<section class="modal"><header><h2>荔枝组队提醒</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${state.settings.reminders==='off'?'已关闭重逢提醒，本次入队不会显示提示。':'演示：这几位已记录的玩家加入了队伍。'}</p><div class="reminder-preview">${state.settings.reminders==='off'?'':chosen.map(n=>`<div class="reminder-item note-${n.type}"><b>${icon(noteTypes[n.type].icon)}${noteTypes[n.type].label} · ${n.name}-${n.realm}</b><p>${esc(n.reason)}</p></div>`).join('')}</div><footer><button class="button primary" data-action="close-modal">知道了</button></footer></section>`);
}
function tipMembers(ids,leader){
 return `<div class="tip-members">${ids.map(id=>{const m=person(id);return `<div class="tip-member">${classIcon(m,false)}<span class="tip-member-identity"><b style="color:${colorOf(m)}">${m.name}<em class="member-realm">-${m.realm}</em>${id===leader?'<span class="leader-badge">队长</span>':''}</b><span class="member-tags"><small>${m.spec}</small>${personRelations(id)}${noteBadge(id)}</span></span>${roleIcon(m.role)}</div>`;}).join('')}</div>`;
}
function tipNote(id,force=false){
 const n=noteOf(id);return n&&(force||state.settings.noteMarks)?`<div class="tip-note note-${n.type}"><b>${icon(noteTypes[n.type].icon)}荔枝笔记 · ${noteTypes[n.type].label}</b><p>${esc(n.reason||'无理由')}</p><small>${esc(n.classSpec)} · ${n.date}</small></div>`:'';
}
function tipNotes(ids){
 const list=state.settings.noteMarks?ids.map(noteOf).filter(Boolean):[];
 return list.length?`<div class="tip-notes"><p class="tip-notes-title">${icon('book')}队伍中的荔枝笔记 · ${list.length}</p>${list.map(n=>`<div class="tip-note-summary"><span class="note-${n.type}">${icon(noteTypes[n.type].icon)}${n.name}</span><p>${esc(n.reason||'无理由')}</p></div>`).join('')}</div>`:'';
}
let pendingTipOwner;
function queueTip(owner,event){
 if(owner.dataset.tipNote&&owner.dataset.tipNote===state.editNote)return;
 if(tipOwner===owner||pendingTipOwner===owner)return;
 hideTip();pendingTipOwner=owner;tipPoint=event?{clientX:event.clientX,clientY:event.clientY}:null;
 tipTimer=setTimeout(()=>{pendingTipOwner=null;showTip(owner);},Number(state.settings.tooltipDelay));
}
function showTip(owner){
 if(!owner.isConnected||!$('#modal').hidden)return;
 let html='',expanded=false;
 if(owner.dataset.tipGroup){
  const g=groups.find(g=>g.id===Number(owner.dataset.tipGroup)),m=person(g.leader),a=act(g.activity),raid=a.kind==='raid';
  expanded=raid&&(shiftDown||state.settings.raidMembers==='always');
  html=`<div class="tip-heading">${activityArt(a,g.level)}<div><h3>${esc(g.title)}</h3><p class="tip-activity">${a.name} · ${difficultyNames[g.difficulty]||categoryOf(g.category).name}</p></div></div><div class="tip-stats"><div><span>队长评分</span><b>${m.score}</b></div><div><span>要求装等</span><b>${g.ilvl||'不限'}</b></div><div><span>最低评分</span><b>${g.minScore||'不限'}</b></div><div><span>人数</span><b>${g.size||g.members.length}/${g.max||5}</b></div></div>${expanded?`<div class="tip-members-heading"><b>队伍成员</b><span>${g.members.length} 人 · 姓名与服务器</span></div>${tipMembers(g.members,g.leader)}`:`<p class="tip-comment">${esc(g.comment)}</p>${raid?`<div class="tip-raid-summary"><span class="good">首领进度 ${g.progress}</span>${roster(g.members,g.max,g.counts)}</div>${groupSignals(g.members)}`:tipMembers(g.members,g.leader)}${tipNotes(g.members)}`}<p class="tip-footer">${raid?(expanded?(state.settings.raidMembers==='always'?'已显示全部成员。':'松开 Shift 返回队伍概要。'):`按住 <kbd>Shift</kbd> 查看 ${g.members.length} 名成员。`):'点击队伍查看申请操作。'}</p>`;
 }else if(owner.dataset.tipApplicant){
  const a=applicants.find(a=>a.id===Number(owner.dataset.tipApplicant));html=`<h3>${a.ids.length>1?'同行申请':'单人申请'} · ${a.ids.length} 名成员</h3><p class="tip-comment top-gap">${esc(a.comment)}</p>${tipMembers(a.ids)}<div class="tip-stats"><div><span>整组最低装等</span><b>${minimum(a,'ilvl')}</b></div><div><span>整组最低评分</span><b>${minimum(a,'score')}</b></div></div>${tipNotes(a.ids)}`;
 }else if(owner.dataset.tipMember){
  const m=person(owner.dataset.tipMember);html=`<h3 style="color:${colorOf(m)}">${m.name}<em class="member-realm">-${m.realm}</em></h3><p class="tip-member-sub">${roleIcon(m.role)}${m.spec}${personRelations(m.id)}</p><div class="tip-stats"><div><span>装等</span><b>${m.ilvl}</b></div><div><span>评分</span><b>${m.score}</b></div></div>${tipNote(m.id)}<p class="tip-footer">点击查看或添加荔枝笔记。</p>`;
 }else if(owner.dataset.tipNote){
  const n=noteOf(owner.dataset.tipNote);html=`<h3>${esc(n.name)}-${esc(n.realm)}</h3>${tipNote(n.id,true)}<p class="tip-footer">点击编辑记录。</p>`;
 }
 if(!html)return;
 tipOwner=owner;const tip=$('#tooltip');tip.classList.toggle('expanded',expanded);tip.innerHTML=html;tip.hidden=false;
 const frame=$('#fit-frame').getBoundingClientRect(),scale=frame.width/1160,box=owner.getBoundingClientRect(),width=expanded?656:410;
 const px=((tipPoint?.clientX||box.right)-frame.left)/scale,py=((tipPoint?.clientY||box.top)-frame.top)/scale;
 let x=px+18;if(x+width>1150)x=px-width-18;x=Math.max(10,Math.min(1150-width,x));
 tip.style.left=x+'px';tip.style.top=Math.max(10,Math.min(750-tip.offsetHeight,py+8))+'px';
}
function hideTip(){clearTimeout(tipTimer);pendingTipOwner=null;tipOwner=null;tipPoint=null;$('#tooltip').hidden=true;}
function openModal(html){hideTip();$('#modal').innerHTML=html;$('#modal').hidden=false;$('#modal').querySelector('input,textarea,button')?.focus();}
function closeModal(){$('#modal').hidden=true;$('#modal').innerHTML='';}
function applyModal(id){
 const g=groups.find(g=>g.id===id);
 openModal(`<form class="modal" id="apply-form" data-group-id="${id}"><header><h2>申请加入</h2><button type="button" class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${esc(g.title)}</p><label>选择你可以承担的职责</label><div class="modal-roles">${['TANK','HEALER','DAMAGER'].map(r=>`<button type="button" class="modal-role ${r==='DAMAGER'?'active':''}" data-apply-role="${r}" aria-pressed="${r==='DAMAGER'}">${icon(roleIcons[r])}${roleNames[r]}</button>`).join('')}</div><label for="application-note">给队长的备注</label><textarea id="application-note" placeholder="简短说明经验或同行情况（选填）"></textarea><p id="role-message" class="tip-footer"></p><footer><button class="button" type="button" data-action="close-modal">取消</button><button class="button primary">提交申请</button></footer></form>`);
}
function transferModal(importing){openModal(`<section class="modal"><header><h2>${importing?'导入记录':'导出记录'}</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${importing?'粘贴 LN- 记录文本，按玩家身份合并。':'导出完整名单，包括记录类型与理由。'}</p><label for="transfer-text">记录文本</label><textarea id="transfer-text" style="height:190px" placeholder="粘贴 LN- 文本">${importing?'':'LN-PROTOTYPE-DEMO · 荔枝笔记演示文本'}</textarea><p class="tip-footer">这里只演示操作流程，演示文本不能导入游戏。</p><footer><button class="button" data-action="close-modal">关闭</button><button class="button primary" data-action="${importing?'demo-import':'select-export'}">${importing?'导入记录':'全选文本'}</button></footer></section>`);}

document.addEventListener('click',event=>{
 const b=event.target.closest('button');if(!b||b.disabled)return;
 if(b.dataset.page){navigate(b.dataset.page);return;}
 if(b.dataset.category){changeCategory(b.dataset.category);return;}
 if(b.dataset.activity){state.activity=b.dataset.activity;state.selected=null;closeModal();renderPage();return;}
 if(b.dataset.difficulty){state.difficulty=b.dataset.difficulty;state.selected=null;renderPage();return;}
 if(b.dataset.mode){state.mode=b.dataset.mode;state.selected=null;renderPage();return;}
 if(b.dataset.group){state.selected=Number(b.dataset.group);renderFindResults();return;}
 if(b.dataset.applicant){state.selectedApplicant=Number(b.dataset.applicant);renderPage();return;}
 if(b.hasAttribute('data-app-role')){state.appRole=b.dataset.appRole;state.selectedApplicant=null;renderPage();return;}
 if(b.dataset.noteTab){state.noteTab=b.dataset.noteTab;state.editNote=null;state.noteQuery='';renderPage();return;}
 if(b.dataset.editNote){state.editNote=b.dataset.editNote;renderPage();return;}
 if(b.dataset.notePerson){openPersonNote(b.dataset.notePerson);return;}
 if(b.dataset.findPerson){findPerson(b.dataset.findPerson);return;}
 if(b.dataset.noteType){document.querySelectorAll('[data-note-type]').forEach(el=>{el.classList.toggle('active',el===b);el.setAttribute('aria-pressed',el===b);});return;}
 if(b.dataset.settingsSection){state.settingsSection=b.dataset.settingsSection;renderPage();return;}
 if(b.dataset.setting){const key=b.dataset.setting;state.settings[key]=!state.settings[key];renderPage();return;}
 if(b.dataset.formSwitch){readForm();const key=b.dataset.formSwitch;state.form[key]=!state.form[key];b.querySelector('.switch').classList.toggle('on',state.form[key]);b.setAttribute('aria-checked',state.form[key]);return;}
 if(b.dataset.formActivity){readForm();const a=act(b.dataset.formActivity);state.form.activity=a.id;if(state.createActivityQuery.trim()){state.form.category=creationCategory(a);state.form.expansion=a.expansion||'all';state.createActivityQuery='';}const choices=difficulties(state.form.category,state.form.activity);if(!choices.some(([id])=>id===state.form.difficulty))state.form.difficulty=state.form.category==='season-dungeons'?'keystone':choices[0]?.[0]||'';updateCreationTitle();renderPage();return;}
 if(b.dataset.formDifficulty){readForm();state.form.difficulty=b.dataset.formDifficulty;updateCreationTitle();renderPage();return;}
 if(b.dataset.applyRole){b.classList.toggle('active');b.setAttribute('aria-pressed',b.classList.contains('active'));return;}
 switch(b.dataset.action){
  case 'clear-create-search':readForm();state.createActivityQuery='';renderPage();$('#create-activity-query').focus();break;
  case 'view-own-party':ownPartyModal();break;
  case 'toggle-filters':state.filtersExpanded=!state.filtersExpanded;$('#search-filters').classList.toggle('open',state.filtersExpanded);$('#search-filters').inert=!state.filtersExpanded;b.classList.toggle('expanded',state.filtersExpanded);b.setAttribute('aria-expanded',state.filtersExpanded);b.setAttribute('aria-label',(state.filtersExpanded?'收起':'展开')+'筛选条件');break;
  case 'clear-filters':state.filters={};state.query='';state.personFilter=null;state.selected=null;renderPage();break;
  case 'back-results':state.mode='results';renderPage();break;
  case 'apply':applyModal(Number(b.dataset.id));break;
  case 'cancel-application':state.apps[b.dataset.id]='cancelled';delete state.applicationDeadlines[b.dataset.id];renderFindResults();refreshApplicationCountdowns();toast('已取消申请。');break;
  case 'accept-invite':state.apps[b.dataset.id]='accepted';renderFindResults();toast('已演示接受邀请状态。');break;
  case 'decline-invite':state.apps[b.dataset.id]='declined';renderFindResults();toast('已婉拒邀请。');break;
  case 'group-notes':groupNotesModal(Number(b.dataset.id));break;
  case 'edit-listing':state.autoTitle=false;state.form={...state.listing};state.editing=true;renderPage(true);break;
  case 'cancel-edit-listing':state.editing=false;renderPage(true);break;
  case 'end-listing':state.listing=null;state.selectedApplicant=null;state.editing=false;renderPage(true);toast('招募已结束。');break;
  case 'close-applicant':state.selectedApplicant=null;renderPage();break;
  case 'invite-applicant':state.appStatus[state.selectedApplicant]='invited';renderPage();toast('已发出邀请，等待对方接受。');break;
  case 'decline-applicant':state.appStatus[state.selectedApplicant]='declined';renderPage();toast('已拒绝这组申请。');break;
  case 'add-note':state.noteTab='all';state.editNote='new';state.noteDraft={name:'',realm:'',reason:'',classSpec:'未知',type:state.settings.defaultNote};renderPage();$('#note-identity').focus();break;
  case 'close-note':state.editNote=null;state.noteDraft=null;renderPage();break;
  case 'save-note':saveNote();break;
  case 'delete-note':state.notes=state.notes.filter(n=>n.id!==state.editNote);state.editNote=null;renderPage();toast('荔枝组队提醒：记录已删除。');break;
  case 'close-modal':closeModal();break;
  case 'import-notes':transferModal(true);break;
  case 'export-notes':transferModal(false);break;
  case 'demo-import':if(!$('#transfer-text').value.trim()){toast('先粘贴记录文本。');break;}closeModal();toast('已演示导入流程，演示文本未写入名单。');break;
  case 'select-export':$('#transfer-text').select();toast('已全选演示文本，可复制。');break;
  case 'history':historyModal(b.dataset.run);break;
  case 'preview-reminder':previewReminder();break;
 }
});
document.addEventListener('input',event=>{
 const el=event.target;
 if(el.form?.id==='listing-form'&&el.name){state.form[el.name]=el.type==='number'?Number(el.value)||0:el.value;if(el.name==='title')state.autoTitle=false;}
 else if(el.id==='create-activity-query'){state.createActivityQuery=el.value;$('#creation-activity-list').innerHTML=creationActivityRows();$('.creation-category-picker').hidden=!!el.value.trim();$('[data-action=clear-create-search]').hidden=!el.value.trim();}
 else if(el.id==='group-query'){state.query=el.value;state.personFilter=null;renderFindResults();}
 else if(el.dataset.filter){state.filters[el.dataset.filter]=Number(el.value)||0;renderFindResults();}
 else if(el.id==='notes-query'){state.noteQuery=el.value;$('#notes-list').innerHTML=notesRows();$('.notes-count').textContent=`${visibleNotes().length} 条记录`;}
});
document.addEventListener('change',event=>{
 const el=event.target;
 if(el.id==='party-demo'){if($('#listing-form'))readForm();state.partyMode=el.value;if(state.page==='create')renderPage();}
 else if(el.id==='role-filter'){state.filters.role=el.value;renderFindResults();}
 else if(el.id==='social-filter'){state.filters.social=el.value;renderFindResults();}
 else if(el.id==='sort-results'){state.sort=el.value;renderFindResults();}
 else if(el.id==='sort-applicants'){state.appSort=el.value;renderPage();}
 else if(el.id==='activity-filter'){state.activity=el.value;if(!difficulties(state.category,state.activity,state.expansion).some(([id])=>id===state.difficulty))state.difficulty='all';state.selected=null;renderPage();}
 else if(el.id==='expansion-filter'){state.expansion=el.value;state.activity='all';state.difficulty='all';state.selected=null;renderPage();}
 else if(el.dataset.settingSelect){const key=el.dataset.settingSelect;state.settings[key]=key==='tooltipDelay'?Number(el.value):el.value;if(key==='defaultSort')state.sort=el.value;renderPage();}
 else if(el.name==='expansion'&&el.form?.id==='listing-form'){readForm();state.form.activity=categoryActivities(state.form.category,el.value)[0].id;const choices=difficulties(state.form.category,state.form.activity);if(!choices.some(([id])=>id===state.form.difficulty))state.form.difficulty=choices[0]?.[0]||'';updateCreationTitle();renderPage();}
 else if(el.name==='activity'&&el.form?.id==='listing-form'){readForm();const choices=difficulties(state.form.category,el.value);if(!choices.some(([id])=>id===state.form.difficulty))state.form.difficulty=choices[0]?.[0]||'';updateCreationTitle();renderPage();}
 else if(el.name==='category'&&el.form?.id==='listing-form'){readForm();state.form.expansion=categoryOf(el.value).expansion?expansionOptions(el.value)[0][0]:'all';state.form.activity=categoryActivities(el.value,state.form.expansion)[0].id;state.form.difficulty=el.value==='season-dungeons'?'keystone':difficulties(el.value,state.form.activity)[0]?.[0]||'';updateCreationTitle();renderPage();}
});
document.addEventListener('submit',event=>{
 event.preventDefault();
 if(event.target.id==='search-form'){
  if(state.searching)return;state.searching=true;renderPage();clearTimeout(searchTimer);
  searchTimer=setTimeout(()=>{state.searching=false;if(state.page==='find'){renderPage();toast(`已更新 ${filteredGroups().length} 支队伍。`);}},650);
 }else if(event.target.id==='listing-form'){
  readForm();if(!state.form.title.trim())return;state.listing={...state.form};state.editing=false;state.selectedApplicant=null;renderPage(true);toast('组队已发布，可以开始查看申请。');
 }else if(event.target.id==='apply-form'){
  if(!$('.modal-role.active')){$('#role-message').textContent='至少选择一个职责。';$('#role-message').style.color='var(--gold)';return;}
  state.apps[event.target.dataset.groupId]='applied';state.applicationDeadlines[event.target.dataset.groupId]=Date.now()+300000;closeModal();renderFindResults();refreshApplicationCountdowns();toast('申请已提交，等待队长处理。');
 }
});
const tipSelector='[data-tip-group],[data-tip-applicant],[data-tip-member],[data-tip-note]';
document.addEventListener('mouseover',event=>{const owner=event.target.closest(tipSelector);if(owner&&$('#modal').hidden)queueTip(owner,event);else if(!owner)hideTip();});
document.addEventListener('mouseout',event=>{const owner=tipOwner||pendingTipOwner;if(owner&&!owner.contains(event.relatedTarget))hideTip();});
document.addEventListener('focusin',event=>{const owner=event.target.closest(tipSelector);if(owner&&$('#modal').hidden)queueTip(owner);});
document.addEventListener('focusout',hideTip);
document.addEventListener('wheel',hideTip,{passive:true});
document.addEventListener('keydown',event=>{
 if(event.key==='Shift'&&!shiftDown){shiftDown=true;if(tipOwner?.dataset.tipGroup)showTip(tipOwner);}
 if(event.key==='Escape'){hideTip();if(!$('#modal').hidden)closeModal();else presence(false);}
});
document.addEventListener('keyup',event=>{if(event.key==='Shift'){shiftDown=false;if(tipOwner?.dataset.tipGroup)showTip(tipOwner);}});
addEventListener('blur',()=>{shiftDown=false;hideTip();});
$('#modal').addEventListener('click',event=>{if(event.target===$('#modal'))closeModal();});
const logo=$('#logo');function brandMotion(){if(state.settings.motion||logo.classList.contains('logo-motion'))return;logo.classList.add('logo-motion');}logo.addEventListener('animationend',()=>logo.classList.remove('logo-motion'));$('#brand').addEventListener('mouseenter',brandMotion);$('#brand').addEventListener('click',brandMotion);
let phase=0,target=1,presenceFrame,lastTime,afterPresence;
function drawPresence(){const q=phase*(2-phase),u=Math.min(1,phase*4.2);$('#window').style.transform=`translateY(${64*(1-q)}px)`;$('#window').style.opacity=u*(2-u);}
function presence(open,done){target=open?1:0;afterPresence=done;hideTip();if(open){$('#window').style.visibility='visible';$('#open-window').hidden=true;brandMotion();}if(state.settings.motion){phase=target;drawPresence();finishPresence();return;}if(!presenceFrame){lastTime=performance.now();presenceFrame=requestAnimationFrame(tickPresence);}}
function tickPresence(now){const dt=(now-lastTime)/420;lastTime=now;phase=target===1?Math.min(1,phase+dt):Math.max(0,phase-dt);drawPresence();if(phase===target){presenceFrame=null;finishPresence();}else presenceFrame=requestAnimationFrame(tickPresence);}
function finishPresence(){if(target===0){$('#window').style.visibility='hidden';$('#open-window').hidden=false;logo.classList.remove('logo-motion');}const callback=afterPresence;afterPresence=null;callback?.();}
$('#close-window').onclick=()=>presence(false);$('#open-window').onclick=()=>presence(true);$('#replay').onclick=()=>presence(false,()=>presence(true));$('#reset').onclick=()=>{clearTimeout(searchTimer);resetState();$('#party-demo').value=state.partyMode;renderPage();refreshApplicationCountdowns();presence(true);toast('演示已重置。');};
function fit(){const scale=Math.min(1,(innerWidth-32)/1160);$('#fit-frame').style.transform=`scale(${scale})`;$('.stage').style.height=(760*scale+46)+'px';$('.stage').style.minHeight='0';$('#fit-frame').style.marginBottom=-(760*(1-scale))+'px';}
addEventListener('resize',()=>{hideTip();fit();});
renderPage();fit();drawPresence();presence(true);refreshApplicationCountdowns();
