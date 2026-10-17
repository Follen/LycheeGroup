const $ = (q, root = document) => root.querySelector(q);
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const assetSrc = path => '../prototype-v3/assets/'+path;
const icon = (name, cls = '') => `<img class="ui-icon ${name.startsWith('role-')||name==='leader'?'':'lychee-art-icon'} ${cls}" src="${assetSrc('icons/'+name+'.png')}" alt="" aria-hidden="true" draggable="false">`;
const leaderIcon = () => `<span class="leader-icon" aria-label="队长">${icon('leader')}</span>`;
const roleNames = {TANK:'坦克',HEALER:'治疗',DAMAGER:'输出',NONE:'未指定'};
const classInfo = {WARRIOR:['战士','#c69b6d'],PALADIN:['圣骑士','#f48cba'],MAGE:['法师','#69ccf0'],PRIEST:['牧师','#eeeae6'],DRUID:['德鲁伊','#ff9b48'],SHAMAN:['萨满','#659de1'],DEMONHUNTER:['恶魔猎手','#c084d8'],ROGUE:['潜行者','#e6d67f'],MONK:['武僧','#7edbb7'],WARLOCK:['术士','#a999db'],HUNTER:['猎人','#aad372'],DEATHKNIGHT:['死亡骑士','#c44d65'],EVOKER:['唤魔师','#66b59c']};
const specsByClass={WARRIOR:['武器','狂怒','防护'],PALADIN:['神圣','防护','惩戒'],MAGE:['奥术','火焰','冰霜'],PRIEST:['戒律','神圣','暗影'],DRUID:['平衡','野性','守护','恢复'],SHAMAN:['元素','增强','恢复'],DEMONHUNTER:['浩劫','复仇','噬灭'],ROGUE:['奇袭','狂徒','敏锐'],MONK:['酒仙','织雾','踏风'],WARLOCK:['痛苦','恶魔学识','毁灭'],HUNTER:['野兽控制','射击','生存'],DEATHKNIGHT:['鲜血','冰霜','邪恶'],EVOKER:['湮灭','恩护','增辉']};
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
 {id:'shadow-enclave',name:'聚影领地',kind:'delve',expansion:'至暗之夜',color:'#ad91c7'},
 {id:'collegiate',name:'学府骚动',kind:'delve',expansion:'至暗之夜',color:'#a497cc'},
 {id:'parhelion',name:'幻日广场',kind:'delve',expansion:'至暗之夜',color:'#c8b47a'},
 {id:'darkway',name:'黑暗回廊',kind:'delve',expansion:'至暗之夜',color:'#9382bb'},
 {id:'twilight',name:'暮光地穴',kind:'delve',expansion:'至暗之夜',color:'#a58cb8'},
 {id:'atalaman',name:'阿塔阿曼',kind:'delve',expansion:'至暗之夜',color:'#99b58a'},
 {id:'grudge',name:'憎怨斗坑',kind:'delve',expansion:'至暗之夜',color:'#b89b78'},
 {id:'memory',name:'回忆深沟',kind:'delve',expansion:'至暗之夜',color:'#91b3a7'},
 {id:'sunkiller',name:'戮日圣殿',kind:'delve',expansion:'至暗之夜',color:'#bd9e75'},
 {id:'shadowguard',name:'影卫营',kind:'delve',expansion:'至暗之夜',color:'#a189c2'},
 {id:'torments-rise',name:'磨难高地',kind:'delve',expansion:'至暗之夜',color:'#b190bb'},
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
 if(!['dungeon','raid'].includes(categoryOf(category).kind))return [];
 const available=activityID==='all'?categoryActivities(category,expansion):[act(activityID)];
 const variants=new Set(available.flatMap(a=>(activityVariants[a.id]||[]).filter(id=>category==='dungeons'?id!=='keystone':true)));
 return ['normal','heroic','mythic','keystone'].filter(key=>variants.has(key)).map(key=>[key,difficultyNames[key]]);
};
const ratingLabel=(activityID,difficulty)=>difficulty==='keystone'?'最低钥石评分':act(activityID)?.ratedPvp?'最低 PvP 评分':'';
const usesKeyFilters=()=>categoryOf(state.category).kind==='dungeon'&&difficulties(state.category,state.activity,state.expansion).some(([id])=>id==='keystone')&&['all','keystone'].includes(state.difficulty);
const expansionOptions=category=>expansionOrder.filter(expansion=>categoryActivities(category).some(a=>a.expansion===expansion)).map(x=>[x,x]);
const activityArt = (a,large=false) => `<span class="activity-icon${large?' large':''}" style="--art:${a.color}">${a.art?`<img src="${assetSrc(a.art)}" alt="" loading="lazy">`:icon(categories.find(c=>c.kind===a.kind).icon)}</span>`;
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
 {id:71,ids:['wind','dew','cloud','harbor','frost'],comment:'五人一起，语音沟通，熟悉机制。',status:'applied'},
 {id:72,ids:['rain'],comment:'单人治疗，随时可以出发。',status:'applied'},
 {id:73,ids:['night','moon'],comment:'坦和输出一起，有合剂食物。',status:'applied'},
 {id:74,ids:['panda'],comment:'周常打完，机制会。',status:'applied'},
 {id:75,ids:['cedar','ash'],comment:'两位输出一起，时间充足。',status:'applied'},
 {id:76,ids:['ember'],comment:'熟悉机制，可以随时出发。',status:'applied'}
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
 {id:33,category:'delves',activity:'collegiate',difficulty:'delve',title:'学府骚动 8 层，丰裕一起打',leader:'sugar',members:['sugar','star'],level:8,ilvl:620,minScore:0,age:42,comment:'正常打完，来一位同行。'},
 {id:34,category:'delves',activity:'shadowguard',difficulty:'delve',title:'影卫营，来人一起拿箱子',leader:'night',members:['night','tea','rain'],level:8,ilvl:620,minScore:0,age:88,comment:'不赶时间，互相照应。'},
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
groups.push({id:16,category:'season-raids',activity:'palace',difficulty:'normal',title:'普通王宫 30人团队，准备出发',leader:'wind',members:people.map(p=>p.id),size:30,max:30,counts:[2,4,24],ilvl:620,minScore:0,age:260,progress:'0/8',comment:'人员已经到齐，开打前确认分工。'});
const raidEncounters={
 palace:['噬灭者乌格拉克斯','血缚恐魔','席克兰','拉夏南','虫巢扭曲者欧维纳克斯','节点女亲王凯威扎','流丝之庭','安苏雷克女王'],
 undermine:['维克茜和磨轮','血腥大熔炉','里克·混响','斯提克斯·堆渣','链齿狂人洛肯斯多','独臂盗匪','穆格·兹伊','铬武大王加里维克斯']
};
// Explicit sample kills; the live adapter will join the journal catalog with result encounter names.
const sampleRaidKills={11:[0,1,2,3,4],12:[],13:[0,1,2],14:[0],15:[0,1],16:[]};
Object.entries(sampleRaidKills).forEach(([id,indices])=>{const g=groups.find(g=>g.id===Number(id));g.completedEncounters=indices.map(index=>raidEncounters[g.activity][index]);});
groups.push(...[
 [201,'academy','+11 学院，补一位远程','wind',['wind','rain','leaf','cloud'],11,640,2800,145,'坦奶齐，正常限时。'],
 [202,'azure','+10 魔馆周常，来输出','sugar',['night','sugar','tea'],10,635,2500,164,'熟悉路线，打完这一把。'],
 [203,'bracken','+12 蕨皮，沟通打断','moon',['wind','moon','bird'],12,640,2800,212,'需要治疗，愿意一起沟通。'],
 [204,'nokhud','+9 诺库德，轻松周常','panda',['panda','leaf'],9,630,2300,280,'可以讲机制，不赶时间。'],
 [205,'neltharus','+13 奈萨鲁斯，补治疗','night',['night','moon','star','tea'],13,645,3000,340,'路线已确认，准备好消耗品。'],
 [206,'ruby','+11 法池，一把结束','rain',['wind','rain','cloud'],11,638,2700,410,'熟练打完，等两位输出。'],
 [207,'academy','+8 学院，欢迎练习','leaf',['sugar','leaf'],8,625,2000,450,'正常组队，愿意等熟悉机制。'],
 [208,'azure','+12 魔馆，目标限时','star',['night','sugar','star'],12,640,2900,480,'固定路线，打断分工明确。']
].map(([id,activity,title,leader,members,level,ilvl,minScore,age,comment])=>({id,category:'season-dungeons',difficulty:'keystone',activity,title,leader,members,level,ilvl,minScore,age,comment})));
// Most people encountered in premade groups are strangers; keep a few tagged cases for comparison.
people.push(
 {id:'brook',name:'溪行',realm:'白银之手',class:'DEATHKNIGHT',role:'TANK',spec:'鲜血',ilvl:646,score:3024},
 {id:'breeze',name:'清风',realm:'凤凰之神',class:'PALADIN',role:'HEALER',spec:'神圣',ilvl:642,score:2870}
);
const ordinaryRaidIds=['brook','breeze','rain','panda','dew','cloud','harbor','frost','ember','stone','light','plum','cedar','ash','tide','cinder','oak','dawn','kite','shade'];
const ordinaryGroups={
 2:['brook',['brook','cloud','harbor','frost']],3:['harbor',['rain','harbor']],6:['panda',['panda','ember']],7:['cloud',['brook','rain','cloud','plum']],8:['brook',['brook','harbor','ember','frost']],
 12:['breeze',ordinaryRaidIds.slice(0,12)],13:['harbor',ordinaryRaidIds.slice(0,18)],15:['brook',ordinaryRaidIds.slice(0,18)],
 22:['breeze',['brook','breeze']],23:['panda',['panda','ember']],24:['rain',['brook','rain','cloud']],25:['plum',['plum','ember']],
 32:['cloud',['brook','cloud']],33:['breeze',['breeze','plum']],34:['brook',['brook','plum','rain']],
 41:['harbor',['harbor']],51:['panda',['panda','ember']],61:['cloud',['cloud','harbor']],
 201:['brook',['brook','rain','cloud','frost']],202:['breeze',['brook','breeze','plum']],203:['harbor',['brook','harbor','ember']],204:['panda',['panda','frost']],206:['rain',['brook','rain','cloud']],207:['plum',['breeze','plum']]
};
Object.entries(ordinaryGroups).forEach(([id,[leader,members]])=>{const g=groups.find(g=>g.id===Number(id));Object.assign(g,{leader,members});if(g.size){g.counts=[0,0,0];members.forEach(id=>{const role=person(id).role;g.counts[role==='TANK'?0:role==='HEALER'?1:2]++;});}});
groups.push(
 {id:17,category:'season-raids',activity:'undermine',difficulty:'normal',title:'普通安德麦，休闲清进度',leader:'brook',members:ordinaryRaidIds.slice(0,10),size:10,max:30,counts:[1,4,5],ilvl:615,minScore:0,age:130,progress:'0/8',completedEncounters:[],comment:'来有时间的队友，开打前讲机制。'},
 {id:18,category:'season-raids',activity:'palace',difficulty:'heroic',title:'英雄王宫，稳定补位',leader:'rain',members:ordinaryRaidIds.slice(0,15),size:15,max:30,counts:[1,4,10],ilvl:635,minScore:0,age:170,progress:'0/8',completedEncounters:[],comment:'正常打完，愿意听指挥就好。'},
 {id:43,category:'pvp',activity:'arena2',title:'2v2 轻松练习',leader:'frost',members:['frost'],max:2,ilvl:630,minScore:0,age:120,comment:'不赶分，一起练配合。'},
 {id:52,category:'quests',activity:'worldquest',title:'世界任务，随意同行',leader:'tea',members:['tea','rain'],ilvl:0,minScore:0,age:100,comment:'把这片任务一起清掉。'},
 {id:53,category:'quests',activity:'worldquest',title:'任务补人，一起打',leader:'ember',members:['ember','cloud'],ilvl:0,minScore:0,age:130,comment:'做完各自继续。'},
 {id:62,category:'custom',activity:'custom',title:'幻化收集，来一起刷',leader:'bird',members:['bird','tea'],ilvl:0,minScore:0,age:120,comment:'休闲收集外观。'},
 {id:63,category:'custom',activity:'custom',title:'旧副本成就，一起完成',leader:'cedar',members:['cedar','ash'],ilvl:0,minScore:0,age:145,comment:'提前确认成就步骤。'}
);
const ownPartyIds=()=>state.partyMode==='raid'?people.slice(0,30).map(p=>p.id):['brook','rain','cloud'];
const ownPartyName=()=>state.partyMode==='raid'?'当前团队':'当前队伍';
const noteTypes={positive:{label:'推荐',icon:'heart',hint:'想再一起组队，把好队友留在笔记里。'},neutral:{label:'中性',icon:'book',hint:'记下见过的人、约定或其他背景。'},caution:{label:'拉黑',icon:'caution',hint:'记录拉黑原因，再次遇到时提醒。'}};
const defaultSettings={relations:true,noteMarks:true,rememberFilters:true,autoJoin:false,defaultSort:'newest',defaultNote:'neutral',reminders:'all',history:true,motion:false,raidMembers:'shift',floating:true,floatingLocked:false,floatingScale:100};
const defaultForm={category:'season-raids',activity:'palace',difficulty:'heroic',title:'英雄尼鲁巴尔王宫',description:'',ilvl:635,score:0,playstyle:'高阶挑战',private:false,cross:true,auto:false};
const mixedApplicationIDs=[1,11,51,33,61];
let state={};
function resetState(){
 state={createActivityQuery:'',autoTitle:true,partyMode:'party',page:'find',lastMain:'find',category:'season-dungeons',expansion:'all',activity:'all',difficulty:'keystone',activityQuery:'',query:'',personFilter:null,sort:'newest',mode:'results',selected:null,filters:{},savedFilters:{},apps:{},notes:structuredClone(initialNotes),noteQuery:'',noteTab:'all',editNote:null,noteDraft:null,settings:structuredClone(defaultSettings),settingsSection:'browse',filtersExpanded:false,listing:null,editing:false,form:{...defaultForm},selectedApplicant:null,appRole:'',appSort:'newest',appStatus:Object.fromEntries(applicants.map(a=>[a.id,a.status])),searching:false};
 state.apps=Object.fromEntries([1,2].map(id=>[id,'applied']));
 state.applicationDeadlines=Object.fromEntries([1,2].map((id,i)=>[id,Date.now()+300000-i*23000]));
 state.previewApplicationDeadlines={...state.applicationDeadlines};
 state.floatingMineCancelled=false;
 state.floatingRecruitCancelled=false;
 state.showAllApplications=false;
 state.applicationLimitTarget=null;
 state.createPickerOpen=false;
 state.applicationNotes={};
 state.browseScroll=0;
 state.categoryMenuOpen=false;
 state.extraApplicants=[];
 state.newApplicantIds=[];
 state.floatingPosition=null;
 state.floatingRecruitPosition=null;
}
resetState();
const allApplicants=()=>[...applicants,...state.extraApplicants];
const noteOf=id=>state.notes.find(n=>n.id===id);
const noted=id=>!!noteOf(id);
const classSpriteCoords={WARRIOR:[0,0],MAGE:[1,0],ROGUE:[2,0],DRUID:[3,0],HUNTER:[0,1],SHAMAN:[1,1],PRIEST:[2,1],WARLOCK:[3,1],PALADIN:[0,2],DEATHKNIGHT:[1,2],MONK:[2,2],DEMONHUNTER:[3,2]};
function nativeSprite(file,x,y,w,h,fw,fh){return `<span class="native-sprite" style="background-image:url('${assetSrc('wow/'+file)}');background-size:${fw/w*100}% ${fh/h*100}%;background-position:${fw===w?0:x/(fw-w)*100}% ${fh===h?0:y/(fh-h)*100}%"></span>`;}
function classIcon(m,withRole=true){
 if(!m)return '';
 const coords=classSpriteCoords[m.class],art=m.class==='EVOKER'?`<img class="native-class-image" src="${assetSrc('wow/evoker.jpg')}" alt="">`:nativeSprite('classes.png',coords[0]*64,coords[1]*64,64,64,256,256);
 return `<span class="class-icon" style="--class:${colorOf(m)}" title="${classInfo[m.class][0]}"><span class="game-art-clip">${art}</span>${withRole?roleIcon(m.role):''}</span>`;
}
const roleIcon=role=>`<span class="role-icon" title="${roleNames[role]}" aria-label="${roleNames[role]}">${role==='NONE'?'':icon('role-'+({TANK:'tank-silver',HEALER:'healer-flat',DAMAGER:'dps-flat'}[role]))}</span>`;
const roleCount=ids=>['TANK','HEALER','DAMAGER'].map(r=>ids.filter(id=>person(id).role===r).length);
function roster(ids,max=5,counts){
 if(max>5){counts=counts||roleCount(ids);return `<div class="raid-composition">${['TANK','HEALER','DAMAGER'].map((r,i)=>`<span>${roleIcon(r)}${counts[i]}</span>`).join('')}</div>`;}
 return `<div class="roster-strip">${ids.map(id=>classIcon(person(id))).join('')}</div>`;
}
const age=n=>n<60?'刚刚':`${Math.floor(n/60)} 分钟前`;
const statusName=s=>({invited:'收到邀请',accepted:'已接受',cancelled:'已取消',declined:'已拒绝',timedout:'已过期'}[s]||'');
const applicantStatus=s=>({applied:'待处理',invited:'已邀请',declined:'已拒绝'}[s]||'');
const applicationCountdown=id=>{const seconds=Math.max(0,Math.ceil((state.applicationDeadlines[id]-Date.now())/1000));return `${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;};
const status=(s,fallback='',id)=>s==='applied'?`<span class="status applied" data-application-countdown="${id}" title="申请剩余时间" aria-label="申请剩余 ${applicationCountdown(id)}">${applicationCountdown(id)}</span>`:`<span class="status ${esc(s)}">${esc(statusName(s)||fallback)}</span>`;
const activeApplication=id=>['applied','invited'].includes(state.apps[id]);
const countActive=()=>groups.filter(g=>activeApplication(g.id)).length;
const $page=$('#page');
let toastTimer,applicationNoticeTimer,searchTimer,tipOwner,tipTimer,tipHideTimer,tipPoint,tipMemberId=null,tipExpanded=false,tipPinned=false,shiftDown=false;
let applicationTimer;
function refreshApplicationCountdowns(){
 clearTimeout(applicationTimer);
 let expired=false,pending=false;
 for(const [id,s] of Object.entries(state.apps))if(s==='applied'){
  if(Date.now()>=state.applicationDeadlines[id]){state.apps[id]='timedout';delete state.applicationDeadlines[id];expired=true;}
  else pending=true;
 }
 if(expired){if(state.page==='find')renderFindResults();else renderFloatingWidget();}
 document.querySelectorAll('[data-application-countdown]').forEach(el=>{const text=applicationCountdown(el.dataset.applicationCountdown);el.textContent=text;el.setAttribute('aria-label',`申请剩余 ${text}`);});
 document.querySelectorAll('[data-preview-countdown]').forEach(el=>{el.textContent=formatCountdown(state.previewApplicationDeadlines[el.dataset.previewCountdown]);});
 if(pending||state.listing&&!state.floatingMineCancelled&&Object.values(state.previewApplicationDeadlines).some(time=>time>Date.now()))applicationTimer=setTimeout(refreshApplicationCountdowns,1000);
}
function toast(message){clearTimeout(toastTimer);$('#toast').textContent=message;$('#toast').classList.add('visible');toastTimer=setTimeout(()=>$('#toast').classList.remove('visible'),3000);}
function options(entries,selected){return entries.map(([v,l])=>`<option value="${esc(v)}" ${String(v)===String(selected)?'selected':''}>${esc(l)}</option>`).join('');}
function noteBadge(id,compact=false){const n=noteOf(id);if(!n||!state.settings.noteMarks)return '';const t=noteTypes[n.type];return `<span class="person-tag note-${n.type}" title="荔枝笔记 · ${t.label}">${icon(t.icon)}${compact?'':t.label}</span>`;}
function personRelations(id,compact=false){if(!state.settings.relations)return '';const p=person(id);return (p.friend?`<span class="person-tag friend" title="好友">${icon('friend')}${compact?'':'好友'}</span>`:'')+(p.guild?`<span class="person-tag guild" title="同公会">${icon('guild')}${compact?'':'同公会'}</span>`:'');}
function groupSignals(ids){const chips=[];if(state.settings.relations){const friends=ids.filter(id=>person(id).friend).length,guild=ids.filter(id=>person(id).guild).length;if(friends)chips.push(`<span class="signal friend">${icon('friend')}好友 ${friends}</span>`);if(guild)chips.push(`<span class="signal guild">${icon('guild')}公会 ${guild}</span>`);}if(state.settings.noteMarks)for(const [type,info] of Object.entries(noteTypes)){const count=ids.filter(id=>noteOf(id)?.type===type).length;if(count)chips.push(`<span class="signal note-${type}">${icon(info.icon)}${info.label} ${count}</span>`);}return chips.length?`<span class="group-signals">${chips.join('')}</span>`:'';}
function nav(){const labels={find:['search','寻求组队'],create:['plus','创建组队'],notes:['book','荔枝笔记']};$('#main-nav').innerHTML=Object.entries(labels).map(([key,[glyph,label]])=>`<button class="nav-button ${state.page===key?'active':''}" data-page="${key}" aria-current="${state.page===key?'page':'false'}">${icon(glyph)}<span class="nav-label">${label}</span></button>`).join('');$('.settings-button').textContent='设置';$('.settings-button').classList.toggle('active',state.page==='settings');$('#close-window').innerHTML=icon('close');}
function navigate(page){if(page!=='settings')state.lastMain=page;state.page=page;state.categoryMenuOpen=false;hideTip();closeModal();renderPage(true);}
function renderPage(animate=false){
 cancelScrollMotion();closeSelectMenu();hideTip();closeGroupMenu();nav();document.body.classList.toggle('reduce-motion',state.settings.motion);$page.classList.remove('enter');
 $page.innerHTML=({find:renderFind,create:renderCreate,notes:renderNotes,settings:renderSettings}[state.page])();
 if(state.page==='find')renderFindResults();else renderFloatingWidget();
 renderSearchSidebar();enhanceSelects();fit();positionCategorySubmenu();
 if(animate&&!state.settings.motion){void $page.offsetWidth;$page.classList.add('enter');}
}
function changeCategory(id){
 if(state.settings.rememberFilters)state.savedFilters[state.category]={filters:{...state.filters},sort:state.sort,activity:state.activity,difficulty:state.difficulty,expansion:state.expansion};
 state.category=id;state.activity='all';state.difficulty=id==='season-dungeons'?'keystone':'all';state.expansion='all';state.sort=state.settings.defaultSort;state.filters={};
 if(state.settings.rememberFilters&&state.savedFilters[id])Object.assign(state,structuredClone(state.savedFilters[id]));
 if(categoryOf(id).season){state.activity='all';state.expansion='all';}
 state.query='';state.personFilter=null;state.selected=null;state.mode='results';state.browseScroll=0;renderPage(true);
}
function renderCategoryRail(){return `<aside class="category-rail find-category-rail surface">${categories.map((c,i)=>`${i===2?'<div class="category-gap" aria-hidden="true"></div>':''}<button class="category-item ${state.category===c.id?'active':''}" data-category="${c.id}" aria-pressed="${state.category===c.id}" aria-expanded="${state.category===c.id&&state.categoryMenuOpen}" aria-controls="category-submenu">${icon(c.icon)}<span>${c.name}</span>${icon('chevron')}</button>`).join('')}${state.categoryMenuOpen?renderCategorySubmenu():''}</aside>`;}
function browseContext(){
 const category=categoryOf(state.category),activity=state.activity==='all'?null:act(state.activity);
 const choices=difficulties(state.category,state.activity,state.expansion);
 const name=activity?activity.name:category.name+(state.expansion==='all'?'':' · '+state.expansion);
 const difficulty=choices.length===1?choices[0][1]:choices.length?difficultyNames[state.difficulty]:'';
 return `<span>${esc(name)}</span>${difficulty?`<span class="result-difficulty">${difficulty}</span>`:''}`;
}
function renderCategorySubmenu(){
 const c=categoryOf(state.category),list=categoryActivities(c.id,state.expansion),difficulty= difficultySwitch(c.id,state.difficulty,'data-difficulty',true,state.activity,state.expansion),allLabel=c.kind==='dungeon'?'全部地下城':c.kind==='raid'?'全部团本':'全部活动';
 return `<section class="category-submenu" id="category-submenu" aria-label="${c.name}的活动"><header><b>${c.name}</b><button class="icon-button" data-action="close-category-menu" aria-label="关闭活动菜单">${icon('close')}</button></header>${c.expansion?`<select id="expansion-filter" aria-label="资料片">${options([['all','全部资料片'],...expansionOptions(c.id)],state.expansion)}</select>`:''}${difficulty?`<div class="category-menu-difficulty">${difficulty}</div>`:''}<div class="category-submenu-list">${c.season?'':`<button class="activity-option ${state.activity==='all'?'active':''}" data-activity="all" aria-pressed="${state.activity==='all'}">${icon(c.icon)}<span>${allLabel}</span></button>`}${list.map(a=>`<button class="activity-option ${state.activity===a.id?'active':''}" data-activity="${a.id}" aria-pressed="${state.activity===a.id}">${activityArt(a)}<span>${a.name}</span>${state.activity===a.id?'<span class="activity-check">✓</span>':''}</button>`).join('')}</div></section>`;
}
function closeCategoryMenu(){state.categoryMenuOpen=false;$('#category-submenu')?.remove();$('.find-category-rail [aria-expanded=true]')?.setAttribute('aria-expanded','false');}
function positionCategorySubmenu(){const menu=$('#category-submenu');if(menu){const rail=$('.find-category-rail'),button=rail.querySelector('.category-item.active');menu.style.top=Math.max(10,Math.min(button.offsetTop,rail.clientHeight-menu.offsetHeight-10))+'px';}}
function difficultySwitch(category,value,attribute,includeAll=false,activityID='all',expansion='all'){
 const choices=difficulties(category,activityID,expansion);if(!choices.length)return '';
 if(choices.length===1)return `<span class="difficulty-fixed">${choices[0][1]}</span>`;
 return `<div class="difficulty-switch" role="group" aria-label="难度">${(includeAll?[['all','全部'],...choices]:choices).map(([key,label])=>`<button type="button" ${attribute}="${key}" class="${value===key?'active':''}" aria-pressed="${value===key}">${label}</button>`).join('')}</div>`;
}
function renderFind(){
 return `<div class="find-layout find-v3">${renderCategoryRail()}<div class="find-main"><div class="search-row"><form class="search-bar ${state.searching?'searching':''}" id="search-form"><div class="search-field">${icon('search')}<input id="group-query" aria-label="搜索队伍" placeholder="队伍名称或钥石范围，如 12-15" value="${esc(state.query)}"></div>${renderFilterToggle()}</form><button type="button" class="search-refresh" data-action="refresh-search" aria-label="刷新队伍" title="刷新队伍" ${state.searching?'disabled':''}>${icon('refresh')}</button></div><section class="applications-pinned" aria-label="置顶的我的申请"><div class="application-topline"><div id="application-header"></div><div class="application-tools"><button type="button" class="auto-join-toggle" data-action="toggle-auto-join" role="switch" aria-label="自动进组" aria-checked="${state.settings.autoJoin}" title="自动接受已申请队伍的邀请"><span>自动进组</span><span class="switch ${state.settings.autoJoin?'on':''}"></span></button></div></div><div id="application-notice" class="application-notice" role="status" hidden></div><div id="application-list" class="application-list"></div></section><div class="list-toolbar"><div class="result-context" id="result-context">${browseContext()}</div><span class="results-label">队伍 <span id="result-count"></span></span></div><div class="group-list" id="group-list"></div></div></div>`;
}
const filterCount=()=>['members','social',...(usesKeyFilters()?['role']:[])].filter(key=>state.filters[key]).length;
function renderFilterToggle(){const count=filterCount();return `<button type="button" class="filter-toggle ${state.filtersExpanded?'expanded':''}" data-action="toggle-filters" aria-label="${state.filtersExpanded?'收起':'展开'}筛选条件" aria-expanded="${state.filtersExpanded}" aria-controls="search-filters"><span>筛选</span><span class="filter-count" ${count?'':'hidden'}>${count}</span>${icon('chevron')}</button>`;}
function numberFilter(key,label){return `<label class="sidebar-field"><span>${label}</span><input type="number" min="0" data-filter="${key}" placeholder="不限" aria-label="${label}" value="${state.filters[key]||''}"></label>`;}
function renderSearchSidebar(){
 const sidebar=$('#search-filters'),open=state.page==='find'&&state.filtersExpanded;
 sidebar.hidden=!open;if(!open){sidebar.innerHTML='';return;}
 const keys=usesKeyFilters();
 sidebar.innerHTML=`<header class="search-sidebar-heading"><h2>筛选队伍</h2><button class="icon-button" data-action="toggle-filters" aria-label="收起筛选条件">${icon('close')}</button></header><div class="search-sidebar-content"><section class="sidebar-section"><h3>队伍要求</h3><div class="sidebar-number-grid">${numberFilter('members','队伍人数 ≤')}${keys?`<label class="sidebar-field"><span>队伍缺少职责</span><select id="role-filter">${options([['','不限职责'],['TANK','坦克'],['HEALER','治疗'],['DAMAGER','输出']],state.filters.role||'')}</select></label>`:''}</div></section><section class="sidebar-section"><label class="sidebar-field"><span>关系与笔记</span><select id="social-filter" aria-label="关系与笔记筛选">${options([['','全部关系'],['friend','好友在队'],['guild','同公会成员'],['noted','含笔记记录'],['positive','含推荐玩家'],['caution','含拉黑记录']],state.filters.social||'')}</select></label><label class="sidebar-field"><span>排序</span><select id="sort-results" aria-label="队伍排序">${sortOptions(state.sort)}</select></label></section></div><footer><button class="text-action" data-action="clear-filters">清空筛选</button></footer>`;
}
function setFiltersExpanded(open){state.filtersExpanded=open;hideTip();closeCategoryMenu();closeGroupMenu();renderSearchSidebar();enhanceSelects();const button=$('.search-bar .filter-toggle');if(button)button.outerHTML=renderFilterToggle();fit();}
const sortOptions=value=>options([['newest','最新'],['rating','队长评分'],['ilvl','要求装等'],['members','队伍人数']],value);
function groupInCategory(g){const c=categoryOf(state.category);return c.season?act(g.activity).season&&act(g.activity).kind===c.kind:['dungeons','raids'].includes(c.id)?act(g.activity).kind===c.kind:g.category===c.id;}
function matchesGroupQuery(g,query){
 const range=usesKeyFilters()&&/^(\d{1,2})\s*-\s*(\d{1,2})$/.exec(query);
 if(range)return g.difficulty==='keystone'&&g.level>=Number(range[1])&&g.level<=Number(range[2]);
 const level=usesKeyFilters()&&/^(?:\+(\d{1,2})|(\d{1,2})\+?)$/.exec(query);
 if(level)return g.difficulty==='keystone'&&g.level===Number(level[1]||level[2]);
 return `${g.title} ${g.comment} ${person(g.leader).name}`.toLowerCase().includes(query.toLowerCase());
}
function filteredGroups(){
 let list=groups.filter(g=>groupInCategory(g)&&(state.activity==='all'||g.activity===state.activity)&&(state.expansion==='all'||act(g.activity).expansion===state.expansion)&&(state.difficulty==='all'||g.difficulty===state.difficulty));
 list=list.filter(g=>{const f=state.filters,m=person(g.leader),q=state.query.trim();
 if(state.personFilter){if(!g.members.includes(state.personFilter))return false;}else if(q&&!matchesGroupQuery(g,q))return false;
 if(f.members&&(g.size||g.members.length)>f.members)return false;
 if(usesKeyFilters()&&f.role){const idx=['TANK','HEALER','DAMAGER'].indexOf(f.role);if(roleCount(g.members)[idx]>=(idx===2?3:1))return false;}
 if(f.social==='friend'&&!g.members.some(id=>person(id).friend))return false;
 if(f.social==='guild'&&!g.members.some(id=>person(id).guild))return false;
 if(f.social==='noted'&&!g.members.some(noted))return false;
 if(['positive','caution'].includes(f.social)&&!g.members.some(id=>noteOf(id)?.type===f.social))return false;
 return true;});
 return list.sort((a,b)=>state.sort==='rating'?person(b.leader).score-person(a.leader).score:state.sort==='ilvl'?b.ilvl-a.ilvl:state.sort==='members'?(b.size||b.members.length)-(a.size||a.members.length):a.age-b.age);
}
function renderFindResults(){
 hideTip();closeGroupMenu();const list=filteredGroups().filter(g=>!activeApplication(g.id));if(!list.some(g=>g.id===state.selected))state.selected=null;
 $('#result-count').textContent=list.length;$('#result-context').innerHTML=browseContext();
 const container=$('#group-list');
 container.innerHTML=list.length?list.map(groupRow).join(''):`<div class="empty-state">${icon('search')}<h2>没有符合条件的队伍</h2><p>可以切换副本或难度，也可以放宽筛选。</p><button class="button primary" data-action="${state.query?'clear-search':filterCount()?'clear-filters':'open-category-menu'}">${state.query?'清空搜索':filterCount()?'清空筛选':'选择活动'}</button></div>`;
 container.scrollTop=state.browseScroll;
 container.onscroll=()=>{state.browseScroll=container.scrollTop;closeGroupMenu();};
 renderApplications();
 $('.filter-count').textContent=filterCount();$('.filter-count').hidden=!filterCount();
}
function groupRow(g){
 const m=person(g.leader),a=act(g.activity),s=state.apps[g.id];
 return `<article class="browse-row ${state.selected===g.id?'selected':''}" data-result-id="${g.id}"><button class="browse-identity" data-group="${g.id}" data-tip-group="${g.id}" aria-label="队伍：${esc(g.title)}" aria-description="双击或按 Enter 申请加入，右键查看更多操作">${activityArt(a)}<span class="browse-copy"><strong>${esc(g.title)}</strong><small>${a.name}${g.difficulty&&g.difficulty!=='keystone'?' · '+difficultyNames[g.difficulty]:''}${groupSignals(g.members)}</small></span></button><span class="browse-leader" style="color:${colorOf(m)}" title="队长：${esc(m.name)}-${esc(m.realm)}">${leaderIcon()}<span>${esc(m.name)}</span></span><div class="browse-side"><div class="browse-stats">${a.kind==='raid'?`<span title="团队首领进度">进度 <b class="good">${g.progress}</b></span>`:`<span title="队长评分">评分 <b>${m.score}</b></span>`}<span title="要求装等">装等 <b>${g.ilvl||'不限'}</b></span></div><div class="browse-composition">${roster(g.members,g.max||5,g.counts)}<span>${g.size||g.members.length}/${g.max||5}</span></div></div><span class="browse-age">${statusName(s)||age(g.age)}</span></article>`;
}
function renderApplications(){
 const all=groups.filter(g=>activeApplication(g.id)),localCount=all.filter(groupInCategory).length;
 const list=all.filter(g=>state.showAllApplications||groupInCategory(g)).sort((a,b)=>(state.apps[b.id]==='invited')-(state.apps[a.id]==='invited'));
 $('#application-header').innerHTML=`<div class="application-heading"><h2>我的申请</h2><span class="application-count ${all.length===5?'at-limit':''}">${all.length}<small>/5</small></span>${all.length>localCount?`<button class="application-scope-toggle" data-action="toggle-all-applications">${state.showAllApplications?'仅看本分类':'查看全部申请'}</button>`:!localCount?'<span class="application-scope">本分类暂无申请</span>':''}</div>`;
 const container=$('#application-list'),scroll=container.scrollTop;
 container.innerHTML=list.map(applicationCard).join('');container.hidden=!list.length;container.scrollTop=scroll;
 container.onscroll=()=>{hideTip();closeGroupMenu();};
 const notice=$('#application-notice');
 if(state.applicationLimitTarget){const available=all.length<5;notice.hidden=false;notice.innerHTML=`<span>${available?'已有空余名额，可以继续申请。':'当前最多同时申请 5 支队伍，取消一项后再试。'}</span>${available?`<button data-action="continue-limit-application" data-id="${state.applicationLimitTarget}">继续申请</button>`:''}<button class="notice-close" data-action="close-application-notice" aria-label="关闭满额提示">${icon('close')}</button>`;}else notice.hidden=true;
 renderFloatingWidget();
}

function applicationCard(g){
 const invited=state.apps[g.id]==='invited',a=act(g.activity),leader=person(g.leader);
 return `<article class="application-card ${invited?'invited':''}" id="application-${g.id}" data-application-id="${g.id}"><button class="browse-identity" data-group="${g.id}" data-tip-group="${g.id}" aria-label="已申请队伍：${esc(g.title)}">${activityArt(a)}<span class="browse-copy"><strong>${esc(g.title)}</strong></span></button><span class="application-leader" style="color:${colorOf(leader)}" title="队长：${esc(leader.name)}-${esc(leader.realm)}">${esc(leader.name)}</span><div class="application-composition">${roster(g.members,g.max||5,g.counts)}<small>${g.size||g.members.length}/${g.max||5}</small></div>${invited?'<span class="application-invite-state">已收到邀请</span>':`<div class="application-waiting">${status('applied','',g.id)}<button class="text-action" data-action="cancel-application" data-id="${g.id}">取消申请</button></div>`}</article>`;
}
function renderCreate(){
 const editing=!state.listing||state.editing;
 if(editing)return `<div class="create-layout is-editing"><div class="create-main">${renderForm()}</div>${renderCreationParty()}</div>`;
 return `<div class="create-layout"><div class="create-main">${renderManagement()}</div><aside class="group-rail surface"><div class="rail-title"><h2>${ownPartyName()}</h2><small>${ownPartyIds().length} 人</small></div>${roster(ownPartyIds(),30)}<div class="own-party-rail-list">${ownPartyIds().map(id=>ownPartyMember(id)).join('')}</div></aside></div>`;
}
function renderListingActivity(){
 const f=state.form,c=categoryOf(f.category),searching=!!state.createActivityQuery.trim(),a=act(f.activity);
 return `<div class="creation-picker" id="creation-picker"><button type="button" class="creation-picker-trigger" data-action="toggle-creation-picker" aria-expanded="${!!state.createPickerOpen}" aria-controls="creation-picker-panel" aria-label="选择活动：${esc(a.name)}">${activityArt(a)}<span class="picker-current truncate">${a.name}<small>${c.season?'本赛季':a.expansion||c.name}</small></span>${icon('chevron')}</button>
 ${state.createPickerOpen?`<div class="creation-picker-panel" id="creation-picker-panel">
 <div class="creation-search">${icon('search')}<input id="create-activity-query" aria-label="搜索全部活动" placeholder="搜索全部活动" value="${esc(state.createActivityQuery)}"><button type="button" class="icon-button" data-action="clear-create-search" aria-label="清空活动搜索" ${searching?'':'hidden'}>${icon('close')}</button></div>
 <div class="creation-picker-columns ${searching?'is-searching':''}"><nav class="creation-category-picker" aria-label="招募分类" ${searching?'hidden':''}>${categories.map(category=>`<button type="button" class="${category.id===c.id?'active':''}" data-form-category="${category.id}" aria-pressed="${category.id===c.id}">${icon(category.icon)}<span>${category.name}</span></button>`).join('')}</nav><div class="creation-picker-results">
 ${c.expansion?`<select id="listing-expansion" name="expansion" aria-label="招募资料片" ${searching?'hidden':''}>${options(expansionOptions(c.id),f.expansion||a.expansion)}</select>`:''}<div id="creation-activity-list" class="creation-activity-list" aria-label="招募副本">${creationActivityRows()}</div></div></div>
 </div>`:''}</div>`;
}
function creationActivityRows(){
 const f=state.form,c=categoryOf(f.category),q=state.createActivityQuery.trim().toLowerCase();
 const list=q?categories.flatMap(category=>categoryActivities(category.id).filter(a=>`${a.name} ${a.expansion||''} ${category.season?'本赛季':''}`.toLowerCase().includes(q)).map(a=>({a,category}))):categoryActivities(f.category,c.expansion?(f.expansion||act(f.activity).expansion):'all').map(a=>({a,category:c}));
 return list.length?list.map(({a,category})=>{const selected=f.activity===a.id&&f.category===category.id;return `<button type="button" class="category-item creation-activity-option ${selected?'active':''}" data-form-activity="${a.id}" data-activity-category="${category.id}" aria-pressed="${selected}" title="${a.name}">${activityArt(a)}<span class="truncate">${a.name}</span>${q?`<small class="truncate">${category.season?'本赛季':a.expansion||category.name}</small>`:''}</button>`;}).join(''):'<p class="creation-search-empty">没有匹配的活动</p>';
}
function creationCategory(a){return a.kind==='dungeon'?(a.season?'season-dungeons':'dungeons'):a.kind==='raid'?(a.season?'season-raids':'raids'):({delve:'delves',pvp:'pvp',quest:'quests',custom:'custom'}[a.kind]);}
function updateCreationTitle(){if(state.autoTitle)state.form.title=`${difficultyNames[state.form.difficulty]||''}${act(state.form.activity).name}`;}
function renderForm(){
 const f=state.form,c=categoryOf(f.category),scoreLabel=ratingLabel(f.activity,f.difficulty),isPvp=c.kind==='pvp'||f.activity==='custom-pvp';
 return `<form class="create-form" id="listing-form">
  <div class="page-title"><h1>${state.editing?'修改组队':'创建组队'}</h1></div>
  <div class="form-surface">
   <section class="form-section description-section">
    <div class="form-field"><h3 class="form-section-label">活动与难度</h3><div class="listing-activity-context">${renderListingActivity()}${difficultySwitch(f.category,f.difficulty,'data-form-difficulty',false,f.activity)}</div></div>
    <input type="hidden" id="listing-activity" name="activity" value="${f.activity}">
    <div class="form-field"><label for="listing-title">队伍名称</label><input id="listing-title" name="title" class="field form-title" required maxlength="100" placeholder="队伍名称" value="${esc(f.title)}"></div>
    <div class="form-field"><label for="listing-description">说明</label><textarea id="listing-description" name="description" class="field form-description" placeholder="开打前确认分工、语音要求、节奏安排等（选填）">${esc(f.description)}</textarea></div>
   </section>
   <section class="form-section requirements-section">
   <h3 class="form-section-label">招募要求</h3>
   <div class="requirements-grid ${scoreLabel?'':'without-score'}">
    <div><label for="listing-ilvl">${isPvp?'最低 PvP 装等':'最低装等'}</label><input id="listing-ilvl" name="ilvl" type="number" min="0" value="${f.ilvl}"></div>
    ${scoreLabel?`<div><label for="listing-score">${scoreLabel}</label><input id="listing-score" name="score" type="number" min="0" value="${f.score}"></div>`:''}
    <div><label for="listing-style">玩法风格</label><select id="listing-style" name="playstyle">${options(['新手上路','休闲娱乐','高阶挑战','老手带队'].map(x=>[x,x]),f.playstyle)}</select></div>
   </div>
   <div class="form-options">${[['private','私人队伍'],['cross','跨阵营'],['auto','自动接受']].map(([k,l])=>`<button type="button" class="switch-line" data-form-switch="${k}" role="switch" aria-label="${l}" aria-checked="${f[k]}"><span class="switch ${f[k]?'on':''}"></span>${l}</button>`).join('')}</div>
   </section>
  </div>
  <div class="form-footer"><div class="creation-submit">${state.editing?'<button type="button" class="button" data-action="cancel-edit-listing">取消</button>':''}<button class="button primary" type="submit">${state.editing?'更新组队':'发布组队'}</button></div></div>
 </form>`;
}
function renderCreationParty(){
 const ids=ownPartyIds(),ordered=['TANK','HEALER','DAMAGER'].flatMap(role=>ids.filter(id=>person(id).role===role));
 return `<aside class="creation-team surface"><header class="creation-team-heading"><h2>${ownPartyName()} <span>${ids.length} 人</span></h2></header><div class="creation-team-composition">${roster(ids,30)}</div><div class="creation-team-list" aria-label="当前队伍成员">${ordered.map(ownPartyMember).join('')}</div><div class="creation-team-signals">${groupSignals(ids)}</div></aside>`;
}
function closeCreationPicker(){
 state.createPickerOpen=false;state.createActivityQuery='';
 $('#creation-picker-panel')?.remove();
 $('[data-action=toggle-creation-picker]')?.setAttribute('aria-expanded','false');
}
function ownPartyMember(id){
 const m=person(id);
 return `<button type="button" class="own-party-member" data-note-person="${id}">${classIcon(m)}<span class="own-party-copy"><b style="color:${colorOf(m)}">${id===(state.partyMode==='raid'?'wind':'brook')?leaderIcon():''}${m.name}-${m.realm}</b><small>${classInfo[m.class][0]} · ${m.spec}</small><span class="member-tags">${personRelations(id)}${noteBadge(id)}</span></span></button>`;
}
function readForm(){Object.assign(state.form,Object.fromEntries(new FormData($('#listing-form'))));state.form.ilvl=Number(state.form.ilvl)||0;state.form.score=$('#listing-score')?Number(state.form.score)||0:0;}
function renderManagement(){
 const l=state.listing,a=act(l.activity);let list=allApplicants().filter(x=>!state.appRole||x.ids.some(id=>person(id).role===state.appRole));
 if(state.appSort==='newest')list.sort((a,b)=>b.id-a.id);
 if(state.appSort!=='newest')list.sort((a,b)=>minimum(b,state.appSort)-minimum(a,state.appSort));
 return `<section class="listing-summary">${activityArt(a,true)}<div class="summary-copy"><div class="listing-meta"><span>${esc(a.name)}</span><span>${difficultyNames[l.difficulty]||categoryOf(l.category).name}</span>${l.ilvl?`<span>装等 ${l.ilvl}</span>`:''}</div><h2 class="truncate">${esc(l.title)}</h2></div><div class="summary-actions"><button data-action="edit-listing">编辑</button><button class="cancel-listing" data-action="end-listing">取消招募</button></div></section><div class="applicants-heading"><h2>管理申请者</h2><small>${list.length} 组申请</small></div><div class="applicant-controls"><div class="role-filters">${[['','全部'],['TANK','坦克'],['HEALER','治疗'],['DAMAGER','输出']].map(([r,l])=>`<button data-app-role="${r}" class="${state.appRole===r?'active':''}">${r?roleIcon(r):''}${l}</button>`).join('')}</div><select id="sort-applicants" aria-label="申请者排序">${options([['newest','最新'],['score','评分'],['ilvl','装等']],state.appSort)}</select></div><div class="applicant-head"><span>申请者 / 成员标记</span><span>申请备注</span><span>职责</span><span class="number">装等</span><span class="number">评分</span><span class="number">操作</span></div><div class="applicant-list">${list.map(applicantRow).join('')||'<div class="empty-state"><h2>没有该职责的申请</h2><p>切换到全部，继续比较其他队友。</p></div>'}</div>`;
}
function minimum(a,key){return Math.min(...a.ids.map(id=>person(id)[key]));}
function applicantRow(a){
 const s=state.appStatus[a.id],isNew=state.newApplicantIds.includes(a.id),label=a.ids.length>1?`这组 ${a.ids.length} 人`:person(a.ids[0]).name;
 const start=1;
 return `<article class="applicant-batch ${isNew?'is-new':''} ${s}" data-applicant-id="${a.id}" style="--member-start:${start};--member-count:${a.ids.length}">
 <p class="applicant-comment">${esc(a.comment)}</p>
 ${a.ids.map((id,i)=>{const m=person(id);return `<div class="applicant-person" data-member-id="${id}" style="--member-row:${start+i}"><button class="applicant-person-name" data-note-person="${id}" data-tip-member="${id}">${classIcon(m,false)}<span><b style="color:${colorOf(m)}">${m.name}<small>-${m.realm}</small></b><span class="member-tags">${personRelations(id)}${noteBadge(id)}</span></span></button><span class="applicant-person-role" title="${m.spec}">${roleIcon(m.role)}${roleNames[m.role]}</span><span class="number">${m.ilvl}</span><span class="number">${m.score}</span></div>`;}).join('')}
 <div class="applicant-decision">${s==='applied'?`<div><button class="applicant-accept" data-action="invite-applicant" data-id="${a.id}" aria-label="邀请${label}" title="邀请${label}"><span class="decision-check" aria-hidden="true"></span></button><button class="applicant-reject" data-action="decline-applicant" data-id="${a.id}" aria-label="拒绝${label}" title="拒绝${label}"><span class="decision-cross" aria-hidden="true"></span></button></div>${isNew?'<small class="good">新申请</small>':''}`:`<span class="status ${s}">${applicantStatus(s)}</span>`}</div></article>`;
}
function respondToApplicant(id,next){
 const list=$('.applicant-list'),scroll=list?.scrollTop;state.appStatus[id]=next;state.newApplicantIds=state.newApplicantIds.filter(value=>value!==id);
 if(list){renderPage();$('.applicant-list').scrollTop=scroll;}else renderFloatingWidget();
 toast(next==='invited'?'已向这组申请者发出邀请，等待对方接受。':'已拒绝这组申请。');
}
const historyRuns=[
 {id:'academy',activity:'academy',level:12,date:'26/10/15',duration:'28:16',ids:['wind','sugar','star','bird','tea']},
 {id:'bracken',activity:'bracken',level:11,date:'26/10/14',duration:'31:42',ids:['night','rain','tea','moon','bird']},
 {id:'azure',activity:'azure',level:10,date:'26/10/14',duration:'27:35',ids:['brook','rain','cloud','harbor','frost']},
 {id:'ruby',activity:'ruby',level:11,date:'26/10/13',duration:'25:18',ids:['brook','breeze','ember','plum','cedar']},
 {id:'nokhud',activity:'nokhud',level:9,date:'26/10/12',duration:'30:06',ids:['brook','panda','ash','tide','shade']}
];
function visibleNotes(){return state.notes.filter(n=>(state.noteTab==='all'||n.type===state.noteTab)&&`${n.name}${n.realm}${n.reason}`.includes(state.noteQuery)).sort((a,b)=>b.date.localeCompare(a.date));}
function renderNotes(){
 const history=state.noteTab==='history';
 const list=visibleNotes();
 if(!history&&state.editNote!=='new'&&!list.some(n=>n.id===state.editNote))state.editNote=list[0]?.id||null;
 const tabs=[['all','全部记录'],['positive','推荐'],['neutral','中性'],['caution','拉黑'],['history','历史队友']];
 return `<section class="notes-page">
  <aside class="category-rail notes-rail surface" aria-label="笔记分类">${tabs.map(([key,label])=>`<button data-note-tab="${key}" aria-pressed="${state.noteTab===key}" class="category-item ${state.noteTab===key?'active':''} ${key==='history'?'history-nav':''}">${key==='history'?icon('history'):key==='all'?icon('friend'):icon(noteTypes[key].icon)}<span>${label}</span><small>${key==='history'?historyRuns.length:key==='all'?state.notes.length:state.notes.filter(n=>n.type===key).length}</small></button>`).join('')}</aside>
  <div class="notes-main"><div class="notes-heading"><div class="page-title"><h1>${history?'历史队友':'荔枝笔记'}</h1></div><span class="reminder-state">${icon('bell')}${{all:'全部记录提醒',positive:'推荐玩家提醒',caution:'仅拉黑记录提醒',off:'重逢提醒已关闭'}[state.settings.reminders]}</span></div>
  ${history?renderHistory():`<div class="notes-toolbar"><div class="notes-search"><input id="notes-query" placeholder="搜索玩家或理由" aria-label="搜索笔记" value="${esc(state.noteQuery)}"></div><div class="notes-actions"><button class="button" data-action="import-notes">导入</button><button class="button" data-action="export-notes">导出</button><button class="button primary" data-action="add-note">${icon('plus')}添加记录</button></div></div><div class="notes-workspace"><div class="notes-list-area"><div class="notes-list-heading"><span>玩家记录</span><span class="notes-count">${list.length} 条记录</span></div><div id="notes-list">${notesRows()}</div></div>${state.editNote?renderNoteDrawer():'<div class="notes-detail-empty"><h2>选择玩家查看记录</h2></div>'}</div>`}
  </div></section>`;
}
function notesRows(){const list=visibleNotes();return list.length?list.map(noteRow).join(''):`<div class="empty-state"><h2>${state.noteQuery?'没有匹配的记录':'这里还没有记录'}</h2></div>`;}
const noteClass=n=>Object.keys(classInfo).find(key=>classInfo[key][0]===n.classSpec?.split(' · ')[0])||'';
const noteSpecOptions=(key,selected='')=>options([['','未知'],...(specsByClass[key]||[]).map(spec=>[spec,spec])],selected);
function noteSpecFields(n){const key=noteClass(n);return `<div class="note-spec-fields"><label for="note-class">职业<select id="note-class">${options([['','未知'],...Object.entries(classInfo).map(([id,info])=>[id,info[0]])],key)}</select></label><label for="note-spec">专精<select id="note-spec" ${key?'':'disabled'}>${noteSpecOptions(key,n.classSpec?.split(' · ')[1])}</select></label></div>`;}
function noteRow(n){
 const info=noteTypes[n.type],key=noteClass(n);
 return `<div class="note-row ${state.editNote===n.id?'selected':''}"><button class="note-row-main" data-edit-note="${esc(n.id)}" aria-pressed="${state.editNote===n.id}"><span class="note-row-identity">${key?classIcon({class:key},false):`<span class="note-unknown-avatar">${icon('book')}</span>`}<span class="note-player"><b style="color:${key?classInfo[key][1]:'var(--text)'}">${esc(n.name)}-${esc(n.realm)}</b><small>${esc(n.classSpec)}</small></span><span class="note-row-meta"><span class="note-type note-${n.type}">${icon(info.icon)}${info.label}</span><small>${n.date}</small></span></span><span class="note-reason-text">${esc(n.reason||'无理由')}</span></button></div>`;
}
function renderNoteDrawer(){
 const n=state.editNote==='new'?state.noteDraft:noteOf(state.editNote),adding=state.editNote==='new';
 const key=noteClass(n);
 return `<aside class="notes-drawer"><header><h2>${adding?'添加记录':'玩家记录'}</h2>${adding?`<button class="icon-button" data-action="close-note" aria-label="取消添加">${icon('close')}</button>`:''}</header>${adding?`<label for="note-identity">玩家</label><input class="identity-input" id="note-identity" placeholder="名字-服务器" value="${esc(n.name+(n.realm?'-'+n.realm:''))}">`:`<div class="note-editor-person">${key?classIcon({class:key},false):`<span class="note-unknown-avatar">${icon('book')}</span>`}<div><p class="identity">${esc(n.name)}</p><small>${esc(n.realm)}</small></div></div>`}${noteSpecFields(n)}<label>记录类型</label><div class="note-type-switch" role="group" aria-label="记录类型">${Object.entries(noteTypes).map(([type,t])=>`<button class="note-${type} ${n.type===type?'active':''}" data-note-type="${type}" aria-pressed="${n.type===type}">${icon(t.icon)}${t.label}</button>`).join('')}</div><label for="note-reason">记录理由</label><textarea id="note-reason" placeholder="写下当时发生的事">${esc(n.reason)}</textarea>${!adding?`<p class="note-recorded-date">记录于 ${n.date}</p>`:''}<div class="drawer-actions">${!adding?'<button class="danger" data-action="delete-note">删除记录</button>':'<span style="margin-right:auto"></span>'}<button class="button" data-action="close-note">取消</button><button class="button primary" data-action="save-note">保存</button></div></aside>`;
}
function openPersonNote(id){
 state.page='notes';state.lastMain='notes';state.noteTab='all';state.noteQuery='';state.editNote=noteOf(id)?id:'new';state.noteDraft=null;
 if(state.editNote==='new'){const m=person(id);state.noteDraft={id,name:m.name,realm:m.realm,classSpec:`${classInfo[m.class]?.[0]||''} · ${m.spec}`,reason:'',type:state.settings.defaultNote};}
 hideTip();closeModal();renderPage(true);
}
function saveNote(){
 const reason=$('#note-reason').value,type=$('[data-note-type].active').dataset.noteType,key=$('#note-class').value,spec=$('#note-spec').value,classSpec=key?classInfo[key][0]+(spec?' · '+spec:''):'未知';
 if(state.editNote==='new'){
  const parts=$('#note-identity').value.trim().split('-'),name=parts.shift(),realm=parts.join('-');
  if(!name||!realm){toast('填写玩家名和服务器，便于区分同名玩家。');$('#note-identity').focus();return;}
  const m=people.find(m=>m.name===name&&m.realm===realm),existing=state.notes.find(n=>n.name===name&&n.realm===realm);
  const now=new Date(),date=[String(now.getFullYear()).slice(-2),String(now.getMonth()+1).padStart(2,'0'),String(now.getDate()).padStart(2,'0')].join('/');
  const n={id:m?.id||state.noteDraft?.id||`note-${Date.now()}`,name,realm,reason,type,classSpec,date};
  if(existing)Object.assign(existing,n);else state.notes.unshift(n);state.editNote=n.id;state.noteDraft=null;
 }else Object.assign(noteOf(state.editNote),{reason,type,classSpec});
 state.noteTab='all';renderPage();toast('荔枝组队：记录已保存。');
}
function renderHistory(){
 return `<div class="history-page"><div class="history-caption"><span>当前角色完成的大秘境</span><span>${state.settings.history?'自动记录已开启':'自动记录已关闭，已有历史保留'}</span></div><div class="history-run-head"><span>活动</span><span>队友</span><span>完成时间</span><span></span></div>${historyRuns.map(run=>`<button class="history-run" data-action="history" data-run="${run.id}"><span class="history-activity">${activityArt(act(run.activity),true)}<span><b>${act(run.activity).name}</b><small>+${run.level} · ${run.duration}</small></span></span><span>${roster(run.ids)}${groupSignals(run.ids)}</span><span>${run.date}</span>${icon('chevron')}</button>`).join('')}</div>`;
}
function historyModal(id){
 const run=historyRuns.find(r=>r.id===id);
 openModal(`<section class="modal"><header><h2>历史队友</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${act(run.activity).name} · +${run.level} · ${run.date}</p><div class="history-members">${run.ids.map(id=>{const m=person(id);return `<button data-note-person="${id}">${classIcon(m,false)}<span class="history-member-copy"><b style="color:${colorOf(m)}">${m.name}-${m.realm}</b><small>${personRelations(id)}${noteBadge(id)}</small></span><span class="dim">${noted(id)?'查看笔记':'记一笔'}</span></button>`;}).join('')}</div></section>`);
}
function playApplicantTone(){
 const player=$('#applicant-audio');
 player.pause();player.currentTime=0;player.src=assetSrc('sounds/native-application.ogg');player.volume=1;
 player.play().catch(()=>toast('点击演示事件可播放原生申请提示音。'));
}
function simulateNewApplicant(){
 state.floatingRecruitCancelled=false;
 if(!state.listing){toast('发布组队后，可以模拟收到新申请。');return;}
 const samples=[{ids:['dew'],comment:'治疗一位，熟悉机制，可以打完整场。'},{ids:['harbor','leaf'],comment:'两位输出一起，随时准备。'},{ids:['night'],comment:'坦克一位，可以配合队伍节奏。'}];
 const source=samples[state.extraApplicants.length%samples.length],id=100+state.extraApplicants.length;
 state.extraApplicants.push({...source,id,status:'applied'});state.appStatus[id]='applied';state.newApplicantIds.push(id);
 if(state.page==='create'&&!state.editing)renderPage();else renderFloatingWidget();
 playApplicantTone();toast('收到新的入队申请 · '+source.ids.length+' 人');
}
function pendingApplicantCount(){return state.listing?allApplicants().filter(a=>state.appStatus[a.id]==='applied').length:0;}
function renderFloatingWidget(){
 const mine=groups.filter(g=>state.listing?!state.floatingMineCancelled&&mixedApplicationIDs.includes(g.id)&&state.previewApplicationDeadlines[g.id]>Date.now():state.apps[g.id]==='applied');
 const incoming=state.floatingRecruitCancelled?[]:allApplicants().filter(a=>state.appStatus[a.id]==='applied');
 for(const recruiting of [false,true]){
  const root=$(recruiting?'#floating-recruit-widget':'#floating-widget');root.hidden=!state.settings.floating;
  if(root.hidden)continue;
  const count=recruiting?incoming.reduce((n,a)=>n+a.ids.length,0):mine.length;
  const action=recruiting?'floating-create':'floating-find';
  const rows=recruiting?incoming.map(a=>`<section class="floating-applicant-group ${a.ids.length>1?'is-party':''}">${a.ids.map(id=>{
   const m=person(id);
   return `<button class="floating-list-row" data-floating-applicant="${a.id}">${classIcon(m,false)}<span class="floating-list-copy"><b style="color:${colorOf(m)}">${esc(m.name)}-${esc(m.realm)}</b><small>${classInfo[m.class][0]} · ${esc(m.spec)}</small></span><span class="floating-list-stats"><b style="color:${scoreColor(m.score)}">${m.score||'—'}</b><small>装等 ${m.ilvl}</small></span></button>`;
  }).join('')}<div class="floating-group-footer">${a.comment?`<p class="floating-group-comment">${esc(a.comment)}</p>`:''}<div class="floating-group-actions"><button class="floating-invite" data-action="invite-applicant" data-id="${a.id}" aria-label="邀请这组申请者" title="邀请这组申请者"><span class="decision-check" aria-hidden="true"></span></button><button class="floating-reject" data-action="decline-applicant" data-id="${a.id}" aria-label="拒绝这组申请者" title="拒绝这组申请者"><span class="decision-cross" aria-hidden="true"></span></button></div></div></section>`).join(''):mine.map(g=>{
   const leader=person(g.leader),activity=act(g.activity),detail='· '+(g.difficulty==='keystone'?`+${g.level}`:g.difficulty==='delve'?`${g.level} 层`:difficultyNames[g.difficulty]||categoryOf(g.category).name);
   const timer=state.listing?`<span class="floating-countdown" data-preview-countdown="${g.id}">${formatCountdown(state.previewApplicationDeadlines[g.id])}</span>`:`<span class="floating-countdown" data-application-countdown="${g.id}" aria-label="申请剩余 ${applicationCountdown(g.id)}">${applicationCountdown(g.id)}</span>`;
   return `<div class="floating-application-item"><button class="floating-application-row" data-floating-application="${g.id}">${activityArt(activity)}<span class="floating-application-copy"><span class="floating-activity"><b>${esc(activity.name)}</b><small>${esc(detail)}</small></span><span class="floating-group-title">${esc(g.title)}</span><span class="floating-application-bottom"><span style="color:${colorOf(leader)}">${esc(leader.name)}-${esc(leader.realm)}</span>${timer}</span></span></button><button class="floating-item-cancel" data-action="floating-cancel-one" data-id="${g.id}" aria-label="取消对${esc(activity.name)}队伍的申请" title="取消这支队伍的申请">${icon('close')}</button></div>`;
  }).join('');
  root.classList.toggle('is-locked',state.settings.floatingLocked);
  root.innerHTML=`<div class="floating-panel"><header><button class="floating-cancel" data-action="${recruiting?'floating-cancel-recruit':'floating-cancel-applications'}" ${!count?'disabled':''}>${recruiting?'取消招募':'取消全部申请'}</button></header><div class="floating-list">${rows||'<p class="floating-empty">暂无申请</p>'}</div></div><div class="floating-bar"><button class="floating-brand" data-floating-drag data-action="floating-open" aria-label="${recruiting?'查看入队申请':'查看已申请队伍'}"><img src="${assetSrc('lychee-logo.png')}" alt=""></button><button class="floating-counter ${recruiting&&state.newApplicantIds.length?'has-new':''}" data-action="${action}" aria-label="${recruiting?'入队申请人数':'已申请队伍数'}"><b>${count}</b></button></div>`;
 }
 positionFloatingWidget();
}
function formatCountdown(deadline){const seconds=Math.max(0,Math.ceil((deadline-Date.now())/1000));return `${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;}
// Mock palette only; the game UI uses GetDungeonScoreRarityColor.
function scoreColor(score){return score>=3200?'#ff8000':score>=2800?'#b577f2':score>=2200?'#4094ef':score>0?'#62c786':'#787980';}
function positionFloatingWidget(){
 for(const recruiting of [false,true]){
  const root=$(recruiting?'#floating-recruit-widget':'#floating-widget');if(root.hidden)continue;
  const scale=state.settings.floatingScale/100,width=root.offsetWidth*scale,height=48*scale;
  const p=state[recruiting?'floatingRecruitPosition':'floatingPosition']||{x:recruiting?innerWidth-width-24:24,y:innerHeight-height-24};
  root.style.left=Math.max(8,Math.min(innerWidth-width-8,p.x))+'px';root.style.top=Math.max(8,Math.min(innerHeight-height-8,p.y))+'px';
  root.style.transform='scale('+scale+')';const top=parseFloat(root.style.top),above=(top-8)/scale-8,below=(innerHeight-top-8)/scale-54;root.classList.toggle('opens-down',below>above);root.style.setProperty('--floating-list-max-height',Math.max(44,Math.max(above,below)-62)+'px');
  root.classList.toggle('opens-left',parseFloat(root.style.left)+348*scale>innerWidth-8);
 }
}
function openFloatingApplication(id){
 if(state.listing){state.listing=null;state.apps=Object.fromEntries((state.floatingMineCancelled?[]:mixedApplicationIDs).map(id=>[id,'applied']));state.applicationDeadlines={...state.previewApplicationDeadlines};}
 const g=groups.find(g=>g.id===id);state.page=state.lastMain='find';state.categoryMenuOpen=false;
 if(g)changeCategory(g.category);else renderPage();presence(true);
 const row=id&&$('#application-'+id);row?.scrollIntoView({block:'nearest'});row?.classList.add('highlight');refreshApplicationCountdowns();
}
function openFloatingApplicant(id){
 if(!state.listing){state.listing={...defaultForm};state.apps={};state.applicationDeadlines={};closeNativeInvite();}
 state.selectedApplicant=id;state.editing=false;openFloatingPage('create');
}
function openFloatingPage(page){
 presence(true);
 if(page==='create'&&state.listing)state.editing=false;
 navigate(page);
}
function autoJoinPending(){
 if(!state.settings.autoJoin||state.listing)return;
 const group=groups.find(g=>state.apps[g.id]==='invited');
 if(!group)return;
 state.apps[group.id]='accepted';delete state.applicationDeadlines[group.id];closeNativeInvite();
 if(state.page==='find')renderFindResults();else renderFloatingWidget();
 toast('已自动接受邀请：'+group.title);
}
function nativeInvitePreview(){
 hideTip();
 const g=groups.find(g=>state.apps[g.id]==='invited');
 if(!g){toast('当前没有待回应的邀请。');return;}
 if(state.settings.autoJoin){autoJoinPending();return;}
 const layer=$('#native-invite-layer');layer.innerHTML=`<section class="modal native-invite-demo" role="dialog" aria-label="队伍邀请流程示意"><header><h2>队伍邀请</h2><button class="icon-button" data-action="close-native-invite" aria-label="关闭邀请演示">${icon('close')}</button></header><p class="native-invite-caption">游戏原生弹窗 · 流程示意</p><h3>${esc(g.title)}</h3><p>${act(g.activity).name}</p><div class="native-invite-role">${roleIcon('DAMAGER')}你的职责：输出</div><footer><button class="button" data-action="decline-invite" data-id="${g.id}">拒绝</button><button class="button primary" data-action="accept-invite" data-id="${g.id}">接受</button></footer></section>`;layer.hidden=false;layer.querySelector('button').focus();
}
const settingsSections={browse:['search','队伍浏览'],notes:['book','笔记与提醒'],floating:['','悬浮窗'],interface:['settings','界面与提示']};
function switchSetting(key,label,hint){return `<div class="setting-row"><h3>${label}</h3><p>${hint}</p><button class="setting-control" role="switch" aria-label="${label}" aria-checked="${state.settings[key]}" data-setting="${key}"><span>${state.settings[key]?'已开启':'已关闭'}</span><span class="switch ${state.settings[key]?'on':''}"></span></button></div>`;}
function selectSetting(key,label,hint,choices){return `<div class="setting-row"><h3>${label}</h3><p>${hint}</p><select data-setting-select="${key}" aria-label="${label}">${options(choices,state.settings[key])}</select></div>`;}
function rangeSetting(key,label,hint,min,max,step=5){return `<div class="setting-row"><h3>${label}</h3><p>${hint}</p><div class="setting-range"><input type="range" data-setting-range="${key}" aria-label="${label}" min="${min}" max="${max}" step="${step}" value="${state.settings[key]}"><output>${state.settings[key]}%</output></div></div>`;}
function renderSettings(){
 let content='';
 if(state.settingsSection==='browse')content=selectSetting('defaultSort','默认排序','进入其他活动分类时采用的排序。',[['newest','最新'],['rating','队长评分'],['ilvl','要求装等'],['members','队伍人数']])+switchSetting('rememberFilters','记住各分类的筛选','切换活动后恢复筛选条件；赛季分类默认查看全部活动。')+switchSetting('relations','好友与公会标记','在队伍、申请者和成员提示中显示关系。')+switchSetting('noteMarks','荔枝笔记标记','分别显示推荐、中性和拉黑记录；包含队伍成员。');
 if(state.settingsSection==='notes')content=selectSetting('defaultNote','新记录的默认类型','每次记笔记时仍可选择其他类型。',Object.entries(noteTypes).map(([id,t])=>[id,t.label]))+selectSetting('reminders','再次组队时提醒','遇到已记录玩家时，按你选择的范围提醒。',[['all','全部记录'],['positive','仅推荐'],['caution','仅拉黑'],['off','不提醒']])+switchSetting('history','记录大秘境历史队友','完成后保留活动与成员，便于回顾和补充笔记。');
 if(state.settingsSection==='floating')content=switchSetting('floating','显示悬浮窗','查看申请与招募状态，关闭主窗口后仍然显示。')+switchSetting('floatingLocked','锁定位置','锁定后不能拖动，查看状态和点击入口不受影响。')+
 rangeSetting('floatingScale','悬浮窗缩放','单独调整悬浮窗大小，不影响主窗口。',50,150)+
 '<div class="setting-row"><h3>悬浮窗位置</h3><p>未锁定时拖动荔枝标志，可放在屏幕内任意位置。</p><button class="button secondary setting-reset-position" data-action="reset-floating-position">重置位置</button></div>';
 if(state.settingsSection==='interface')content=switchSetting('motion','减少动态效果','关闭开窗位移、Logo 动作和局部过渡。')+selectSetting('raidMembers','团本成员列表','控制团本悬停提示中何时展开成员。',[['shift','按 Shift 切换展开'],['always','始终展开']]);
 return `<section class="settings-page"><div class="settings-layout"><nav class="settings-nav category-rail surface" aria-label="设置分类">${Object.entries(settingsSections).map(([id,[glyph,label]])=>`<button data-settings-section="${id}" class="category-item ${state.settingsSection===id?'active':''}"><span>${label}</span></button>`).join('')}</nav><div class="settings-main"><div class="page-title"><h1>${settingsSections[state.settingsSection][1]}</h1><button class="button" data-page="${state.lastMain}">${icon('arrow')}返回</button></div><div class="settings-body"><div class="settings-stack">${content}</div></div></div></div></section>`;
}
function previewReminder(){
 const chosen=state.notes.filter(n=>state.settings.reminders==='all'||n.type===state.settings.reminders);
 openModal(`<section class="modal"><header><h2>荔枝组队</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${state.settings.reminders==='off'?'已关闭重逢提醒，本次入队不会显示提示。':'演示：这几位已记录的玩家加入了队伍。'}</p><div class="reminder-preview">${state.settings.reminders==='off'?'':chosen.map(n=>`<div class="reminder-item note-${n.type}"><b>${icon(noteTypes[n.type].icon)}${noteTypes[n.type].label} · ${n.name}-${n.realm}</b><p>${esc(n.reason)}</p></div>`).join('')}</div><footer><button class="button primary" data-action="close-modal">知道了</button></footer></section>`);
}
function tipMembers(ids,leader){
 return `<div class="tip-members">${ids.map(id=>{const m=person(id);return `<button type="button" class="tip-member" data-tip-player="${id}" aria-label="查看${m.name}的详情">${classIcon(m,false)}<span class="tip-member-identity"><b style="color:${colorOf(m)}">${id===leader?leaderIcon():''}<span class="tip-member-name">${esc(m.name)}<em class="member-realm">-${esc(m.realm)}</em></span></b><span class="member-tags"><small>${m.spec}</small>${personRelations(id)}${noteBadge(id)}</span></span>${roleIcon(m.role)}</button>`;}).join('')}</div>`;
}
function tipNote(id,force=false){
 const n=noteOf(id);return n&&(force||state.settings.noteMarks)?`<div class="tip-note note-${n.type}"><b>${icon(noteTypes[n.type].icon)}荔枝笔记 · ${noteTypes[n.type].label}</b><p>${esc(n.reason||'无理由')}</p><small>${esc(n.classSpec)} · ${n.date}</small></div>`:'';
}
function playerTooltip(id,fromGroup=false){
 const m=person(id),n=noteOf(id);
 return `${fromGroup?`<button class="tip-back text-action" data-action="tip-back">${icon('arrow')}返回队伍</button>`:''}<div class="tip-player-heading">${classIcon(m,false)}<div><h3 style="color:${colorOf(m)}">${m.name}</h3><p class="member-realm">${m.realm}</p></div>${roleIcon(m.role)}</div><p class="tip-member-sub">${classInfo[m.class][0]} · ${m.spec}${personRelations(id)}</p><div class="tip-stats"><div><span>装等</span><b>${m.ilvl}</b></div><div><span>评分</span><b>${m.score}</b></div></div>${tipNote(id,fromGroup)}<div class="tip-player-actions"><button class="text-action" data-copy-wcl="${id}">复制 WCL 链接</button><button class="text-action" data-note-person="${id}">${n?'编辑笔记':'记录玩家'}</button></div>`;
}
function copyWclLink(id){
 const m=person(id),url=`https://cn.warcraftlogs.com/character/cn/${encodeURIComponent(m.realm)}/${encodeURIComponent(m.name)}`;
 openModal(`<section class="modal"><header><h2>复制 WCL 链接</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${esc(m.name+'-'+m.realm)}</p><label for="wcl-url">角色链接</label><input id="wcl-url" class="field" aria-label="WCL 链接" value="${esc(url)}" readonly><p class="tip-footer">链接已选中，按 Ctrl+C 复制。</p><footer><button class="button" data-action="close-modal">关闭</button></footer></section>`);
 const input=$('#wcl-url');input.focus();input.select();
}
function raidBossProgress(g){
 const encounters=raidEncounters[g.activity],completed=g.completedEncounters;
 return `<aside class="raid-boss-progress"><h4>首领进度${encounters&&completed?`<span>${completed.length}/${encounters.length}</span>`:''}</h4>${encounters&&completed?`<ul>${encounters.map(name=>{const defeated=completed.includes(name);return `<li class="${defeated?'defeated':''}"><span>${name}</span><small>${defeated?'已击败':'未击败'}</small></li>`;}).join('')}</ul>`:`<p class="dim">${encounters?'队伍未提供首领进度':'暂无首领目录'}</p>`}</aside>`;
}
function raidTooltip(g,expanded){
 const a=act(g.activity),leader=person(g.leader),counts=g.counts||['TANK','HEALER','DAMAGER'].map(role=>g.members.filter(id=>person(id).role===role).length);
 const social=state.settings.relations?[['friend','好友'],['guild','同公会']].map(([key,label])=>{const count=g.members.filter(id=>person(id)[key]).length;return count?label+' '+count:'';}).filter(Boolean).join(' · '):'';
 const ordered=[...g.members].sort((x,y)=>x===g.leader?-1:y===g.leader?1:['TANK','HEALER','DAMAGER'].indexOf(person(x).role)-['TANK','HEALER','DAMAGER'].indexOf(person(y).role));
 return `<div class="raid-tip-columns"><div class="raid-tip-main"><header class="raid-tip-heading"><div class="raid-tip-title">${activityArt(a)}<div><h3>${esc(g.title)}</h3><p>${a.name}<span>${difficultyNames[g.difficulty]}</span></p></div></div><div class="raid-tip-leader">${leaderIcon()}<span style="color:${colorOf(leader)}">${leader.name}-${leader.realm}</span></div></header>
 <p class="raid-comment">${esc(g.comment)}</p>
 <div class="raid-summary-line"><span><small>进度</small><b class="good">${g.progress}</b></span><span><small>要求装等</small><b>${g.ilvl||'不限'}</b></span><span><small>人数</small><b>${g.size||g.members.length}/${g.max}</b></span></div>
 <div class="raid-role-line">${roster(g.members,g.max,counts)}${social?`<small>${social}</small>`:''}</div>
 ${expanded?`<section class="raid-tip-roster">${tipMembers(ordered,g.leader)}</section>`:''}
 <p class="raid-tip-footer">${expanded?(state.settings.raidMembers==='always'?'点击成员查看详情':'点击成员查看详情 · 再按 Shift 收起'):`按 <kbd>Shift</kbd> 查看 ${g.members.length} 名成员`}</p></div>${raidBossProgress(g)}</div>`;
}
let pendingTipOwner;
function queueTip(owner,event){
 clearTimeout(tipHideTimer);
 if(tipPinned)return;
 if(owner.dataset.tipNote&&owner.dataset.tipNote===state.editNote)return;
 if(tipOwner===owner||pendingTipOwner===owner)return;
 hideTip();pendingTipOwner=owner;tipPoint=event?{clientX:event.clientX,clientY:event.clientY}:null;
 tipTimer=setTimeout(()=>{pendingTipOwner=null;showTip(owner);},180);
}
function showTip(owner,event){
 if(!owner.isConnected||!$('#modal').hidden)return;
 const tip=$('#tooltip'),keepPosition=tipPinned&&!tip.hidden,previous={x:parseFloat(tip.style.left),y:parseFloat(tip.style.top)};
 let html='',expanded=false,isRaid=false;
 if(tipMemberId){html=playerTooltip(tipMemberId,true);}
 else if(owner.dataset.tipGroup){
  const g=groups.find(g=>g.id===Number(owner.dataset.tipGroup)),m=person(g.leader),a=act(g.activity),raid=a.kind==='raid';
  expanded=raid&&(tipExpanded||state.settings.raidMembers==='always');isRaid=raid;
  html=raid?raidTooltip(g,expanded):`<div class="tip-heading">${activityArt(a)}<div><h3>${esc(g.title)}</h3><p class="tip-activity">${a.name} · ${difficultyNames[g.difficulty]||categoryOf(g.category).name}</p></div></div><div class="tip-stats"><div><span>队长评分</span><b>${m.score}</b></div><div><span>要求装等</span><b>${g.ilvl||'不限'}</b></div><div><span>最低评分</span><b>${g.minScore||'不限'}</b></div><div><span>人数</span><b>${g.size||g.members.length}/${g.max||5}</b></div></div><p class="tip-comment">${esc(g.comment)}</p>${tipMembers(g.members,g.leader)}`;
 }else if(owner.dataset.tipApplicant){
  const a=allApplicants().find(a=>a.id===Number(owner.dataset.tipApplicant));html=`<h3>申请详情</h3><p class="tip-comment top-gap">${esc(a.comment)}</p>${tipMembers(a.ids)}<div class="tip-stats"><div><span>整组最低装等</span><b>${minimum(a,'ilvl')}</b></div><div><span>整组最低评分</span><b>${minimum(a,'score')}</b></div></div>`;
 }else if(owner.dataset.tipMember){html=playerTooltip(owner.dataset.tipMember);}
 else if(owner.dataset.tipNote){
  const n=noteOf(owner.dataset.tipNote);html=`<h3>${esc(n.name)}-${esc(n.realm)}</h3>${tipNote(n.id,true)}<p class="tip-footer">点击编辑记录。</p>`;
 }
 if(!html)return;
 tipOwner=owner;tip.classList.toggle('expanded',expanded);tip.classList.toggle('raid-tooltip',isRaid);tip.classList.toggle('player-tooltip',!!tipMemberId||!!owner.dataset.tipMember);tip.setAttribute('role',owner.dataset.tipNote?'tooltip':'dialog');tip.setAttribute('aria-label',tipMemberId||owner.dataset.tipMember?'玩家详情':'队伍信息');tip.innerHTML=html;tip.hidden=false;
 const frame=$('#fit-frame').getBoundingClientRect(),scale=frame.width/$('#fit-frame').offsetWidth,box=owner.getBoundingClientRect(),width=tip.offsetWidth;
 const topLimit=Math.max(10,(10-frame.top)/scale),bottomLimit=Math.min($('#window').offsetHeight-10,(innerHeight-10-frame.top)/scale);
 tip.style.maxHeight=Math.min(760,bottomLimit-topLimit)+'px';
 const px=((tipPoint?.clientX||box.right)-frame.left)/scale,py=((tipPoint?.clientY||box.top)-frame.top)/scale;
 let x=keepPosition?previous.x:px+18,y=keepPosition?previous.y:py+8;
 if(!keepPosition&&x+width>1150)x=px-width-18;
 if(keepPosition&&event?.detail){const cursorX=(event.clientX-frame.left)/scale,cursorY=(event.clientY-frame.top)/scale;x=Math.max(cursorX-width+24,Math.min(x,cursorX-12));y=Math.max(cursorY-tip.offsetHeight+24,Math.min(y,cursorY-12));}
 tip.style.left=Math.max(10,Math.min(1150-width,x))+'px';tip.style.top=Math.max(topLimit,Math.min(bottomLimit-tip.offsetHeight,y))+'px';
}
function scheduleHideTip(){clearTimeout(tipHideTimer);if(!tipPinned)tipHideTimer=setTimeout(hideTip,220);}
function hideTip(){clearTimeout(tipTimer);clearTimeout(tipHideTimer);pendingTipOwner=null;tipOwner=null;tipPoint=null;tipMemberId=null;tipExpanded=false;tipPinned=false;$('#tooltip').hidden=true;}
function openModal(html){hideTip();closeGroupMenu();closeCategoryMenu();$('#modal').innerHTML=html;$('#modal').hidden=false;$('#modal').querySelector('input,textarea,button')?.focus();}
function closeModal(){$('#modal').hidden=true;$('#modal').innerHTML='';}
function closeNativeInvite(){$('#native-invite-layer').hidden=true;$('#native-invite-layer').innerHTML='';}
function showApplicationLimit(targetID){
 closeModal();closeGroupMenu();state.applicationLimitTarget=targetID;state.showAllApplications=true;
 if(state.page!=='find'){state.page=state.lastMain='find';renderPage();}else renderApplications();
 const notice=$('#application-notice');notice.classList.remove('notice-enter');void notice.offsetWidth;notice.classList.add('notice-enter');
 clearTimeout(applicationNoticeTimer);applicationNoticeTimer=setTimeout(()=>{state.applicationLimitTarget=null;const current=$('#application-notice');if(current)current.hidden=true;},6500);
}
function demoApplicationLimit(){
 state.listing=null;state.floatingMineCancelled=false;state.apps=Object.fromEntries(mixedApplicationIDs.map(id=>[id,'applied']));
 state.applicationDeadlines=Object.fromEntries(mixedApplicationIDs.map((id,i)=>[id,Date.now()+300000-i*23000]));
 state.page=state.lastMain='find';state.category='season-dungeons';state.categoryMenuOpen=false;state.activity='all';state.difficulty='keystone';
 $('#application-demo').value='mixed';renderPage();presence(true);showApplicationLimit(2);refreshApplicationCountdowns();
}

function applyModal(id){
 if(state.listing){toast('正在招募，结束招募后可申请其他队伍。');return;}
 if(activeApplication(id))return;
 if(countActive()>=5){showApplicationLimit(id);return;}
 const g=groups.find(g=>g.id===id);
 if((g.size||g.members.length)>=(g.max||5)){toast('这支队伍已满员。');return;}
 openModal(`<form class="modal" id="apply-form" data-group-id="${id}"><header><h2>申请加入</h2><button type="button" class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${esc(g.title)}</p><label>选择本次申请的职责</label><div class="modal-roles">${['TANK','HEALER','DAMAGER'].map(r=>`<button type="button" class="modal-role ${r==='DAMAGER'?'active':''}" data-apply-role="${r}" aria-pressed="${r==='DAMAGER'}">${roleIcon(r)}${roleNames[r]}</button>`).join('')}</div><label for="application-note">给队长的备注</label><textarea id="application-note" placeholder="简短说明经验或同行情况（选填）"></textarea><p id="role-message" class="tip-footer"></p><footer><button class="button" type="button" data-action="close-modal">取消</button><button class="button primary">提交申请</button></footer></form>`);
}
function transferModal(importing){openModal(`<section class="modal"><header><h2>${importing?'导入记录':'导出记录'}</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${importing?'粘贴 LN- 记录文本，按玩家身份合并。':'导出完整名单，包括记录类型与理由。'}</p><label for="transfer-text">记录文本</label><textarea id="transfer-text" style="height:190px" placeholder="粘贴 LN- 文本">${importing?'':'LN-PROTOTYPE-DEMO · 荔枝笔记演示文本'}</textarea><p class="tip-footer">这里只演示操作流程，演示文本不能导入游戏。</p><footer><button class="button" data-action="close-modal">关闭</button><button class="button primary" data-action="${importing?'demo-import':'select-export'}">${importing?'导入记录':'全选文本'}</button></footer></section>`);}

let contextGroupId=null,contextOwner=null;
function closeGroupMenu(restoreFocus=false){const owner=contextOwner;$('#group-context-menu').hidden=true;contextGroupId=null;contextOwner=null;if(restoreFocus&&owner?.isConnected)owner.focus({preventScroll:true});}
function openGroupMenu(id,x,y,owner){
 hideTip();closeCategoryMenu();contextGroupId=id;contextOwner=owner;
 const g=groups.find(g=>g.id===id),s=state.apps[id],full=(g.size||g.members.length)>=(g.max||5);
 const first=s==='applied'?['cancel','取消申请']:s==='invited'?['invite-state','已收到邀请']:['apply',state.listing?'正在招募':full?'队伍已满员':countActive()>=5?'申请已达上限':'申请加入'];
 const items=[first,['whisper','与队长密聊'],['copy','复制队长名称'],['block-leader','拉黑队长'],['close','取消']];
 const menu=$('#group-context-menu');
 menu.innerHTML=items.map(([action,label])=>`<button role="menuitem" data-context-action="${action}" class="${action==='close'?'menu-gap':''}" ${action==='invite-state'||action==='apply'&&(state.listing||full)?'disabled':''}>${label}</button>`).join('');
 menu.hidden=false;
 menu.style.left=Math.max(8,Math.min(innerWidth-menu.offsetWidth-8,x))+'px';
 menu.style.top=Math.max(8,Math.min(innerHeight-menu.offsetHeight-8,y))+'px';
 menu.querySelector('button:not(:disabled)').focus({preventScroll:true});
}
function groupMenuAction(action){
 const g=groups.find(g=>g.id===contextGroupId),m=person(g.leader);closeGroupMenu(action==='close');
 if(action==='apply')applyModal(g.id);
 else if(action==='cancel'){state.apps[g.id]='cancelled';delete state.applicationDeadlines[g.id];renderFindResults();refreshApplicationCountdowns();toast('已取消申请。');}
 else if(action==='copy'){
  const name=m.name+'-'+m.realm;
  openModal(`<section class="modal"><header><h2>复制队长名称</h2><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><input class="field" id="copy-leader-name" aria-label="队长名称" value="${esc(name)}" readonly><p class="tip-footer">名称已选中，按 Ctrl+C 复制。</p></section>`);
  const input=$('#copy-leader-name');input.focus();input.select();
 }else if(action==='block-leader'){
  openPersonNote(m.id);document.querySelectorAll('[data-note-type]').forEach(el=>{el.classList.toggle('active',el.dataset.noteType==='caution');el.setAttribute('aria-pressed',el.dataset.noteType==='caution');});$('#note-reason').focus();
 }else if(action==='whisper'){
  openModal(`<form class="modal" id="group-action-demo"><header><h2>与队长密聊</h2><button type="button" class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header><p>${esc(m.name+'-'+m.realm)}</p><label for="group-action-text">消息</label><textarea id="group-action-text" required placeholder="输入消息"></textarea><p class="tip-footer">网页仅演示此入口，不会发送聊天消息。</p><footer><button type="button" class="button" data-action="close-modal">取消</button><button class="button primary">演示发送</button></footer></form>`);
 }
}
document.addEventListener('dblclick',event=>{const row=event.target.closest('[data-result-id]');if(row&&$('#modal').hidden)applyModal(Number(row.dataset.resultId));});
document.addEventListener('contextmenu',event=>{
 const row=event.target.closest('[data-result-id],[data-application-id]');if(!row||!$('#modal').hidden)return;
 event.preventDefault();openGroupMenu(Number(row.dataset.resultId||row.dataset.applicationId),event.clientX,event.clientY,row.querySelector('[data-group]'));
});

document.addEventListener('click',event=>{
 if(!event.target.closest('#tooltip')&&tipOwner&&!tipOwner.contains(event.target))hideTip();
 if(!event.target.closest('#group-context-menu'))closeGroupMenu();
 if(state.categoryMenuOpen&&!event.target.closest('.find-category-rail'))closeCategoryMenu();
 if(state.createPickerOpen&&!event.target.closest('#creation-picker'))closeCreationPicker();
 const result=event.target.closest('[data-result-id]');if(result){state.selected=Number(result.dataset.resultId);document.querySelectorAll('[data-result-id]').forEach(row=>row.classList.toggle('selected',row===result));}
 const b=event.target.closest('button');if(!b||b.disabled)return;
 if(b.dataset.limitLocate){closeModal();openFloatingApplication(Number(b.dataset.limitLocate));return;}
 if(b.dataset.floatingApplication){openFloatingApplication(Number(b.dataset.floatingApplication));return;}
 if(b.dataset.floatingApplicant){openFloatingApplicant(Number(b.dataset.floatingApplicant));return;}
 if(b.dataset.page){navigate(b.dataset.page);return;}
 if(b.dataset.contextAction){groupMenuAction(b.dataset.contextAction);return;}
 if(b.dataset.copyWcl){copyWclLink(b.dataset.copyWcl);return;}
 if(b.dataset.tipPlayer){clearTimeout(tipHideTimer);tipExpanded=$('#tooltip').classList.contains('expanded');tipMemberId=b.dataset.tipPlayer;tipPinned=true;showTip(tipOwner,event);return;}
 if(b.dataset.category){if(state.category===b.dataset.category){state.categoryMenuOpen=!state.categoryMenuOpen;if(categoryOf(state.category).season){state.activity='all';state.browseScroll=0;}renderPage();}else{state.categoryMenuOpen=true;changeCategory(b.dataset.category);}return;}
 if(b.dataset.activity){state.activity=b.dataset.activity;if(!difficulties(state.category,state.activity,state.expansion).some(([id])=>id===state.difficulty))state.difficulty='all';state.selected=null;state.browseScroll=0;closeCategoryMenu();renderPage();return;}
 if(b.dataset.difficulty){state.difficulty=b.dataset.difficulty;state.selected=null;state.browseScroll=0;renderPage();return;}
 if(b.dataset.mode){state.mode=b.dataset.mode;state.selected=null;renderPage();return;}
 if(b.hasAttribute('data-app-role')){state.appRole=b.dataset.appRole;state.selectedApplicant=null;renderPage();return;}
 if(b.dataset.noteTab){state.noteTab=b.dataset.noteTab;state.editNote=null;state.noteQuery='';renderPage(true);return;}
 if(b.dataset.editNote){state.editNote=b.dataset.editNote;renderPage();return;}
 if(b.dataset.notePerson){openPersonNote(b.dataset.notePerson);return;}
 if(b.dataset.noteType){document.querySelectorAll('[data-note-type]').forEach(el=>{el.classList.toggle('active',el===b);el.setAttribute('aria-pressed',el===b);});return;}
 if(b.dataset.settingsSection){state.settingsSection=b.dataset.settingsSection;renderPage(true);return;}
 if(b.dataset.setting){const key=b.dataset.setting;state.settings[key]=!state.settings[key];renderPage();return;}
 if(b.dataset.formSwitch){readForm();const key=b.dataset.formSwitch;state.form[key]=!state.form[key];b.querySelector('.switch').classList.toggle('on',state.form[key]);b.setAttribute('aria-checked',state.form[key]);return;}
 if(b.dataset.formCategory){readForm();const id=b.dataset.formCategory;state.form.category=id;state.form.expansion=categoryOf(id).expansion?expansionOptions(id)[0][0]:'all';state.form.activity=categoryActivities(id,state.form.expansion)[0].id;state.form.difficulty=id==='season-dungeons'?'keystone':difficulties(id,state.form.activity)[0]?.[0]||'';updateCreationTitle();renderPage();return;}
 if(b.dataset.formActivity){readForm();const a=act(b.dataset.formActivity);state.form.activity=a.id;state.form.category=b.dataset.activityCategory||state.form.category;state.form.expansion=a.expansion||'all';const choices=difficulties(state.form.category,state.form.activity);if(!choices.some(([id])=>id===state.form.difficulty))state.form.difficulty=state.form.category==='season-dungeons'?'keystone':choices[0]?.[0]||'';closeCreationPicker();updateCreationTitle();renderPage();return;}
 if(b.dataset.formDifficulty){readForm();state.form.difficulty=b.dataset.formDifficulty;updateCreationTitle();renderPage();return;}
 if(b.dataset.applyRole){b.closest('.modal-roles').querySelectorAll('[data-apply-role]').forEach(option=>{const selected=option===b;option.classList.toggle('active',selected);option.setAttribute('aria-pressed',selected);});return;}
 switch(b.dataset.action){
  case 'continue-limit-application':{const id=Number(b.dataset.id);state.applicationLimitTarget=null;clearTimeout(applicationNoticeTimer);renderApplications();applyModal(id);break;}
  case 'toggle-all-applications':state.showAllApplications=!state.showAllApplications;renderApplications();break;
  case 'close-application-notice':state.applicationLimitTarget=null;clearTimeout(applicationNoticeTimer);renderApplications();break;
  case 'tip-back':tipMemberId=null;showTip(tipOwner,event);break;
  case 'floating-open':if(!suppressFloatingClick){if(b.closest('#floating-recruit-widget'))openFloatingApplicant();else openFloatingApplication();}suppressFloatingClick=false;break;
  case 'floating-find':openFloatingApplication();break;
  case 'floating-create':openFloatingApplicant();break;
  case 'floating-cancel-one':state.apps[b.dataset.id]='cancelled';delete state.applicationDeadlines[b.dataset.id];delete state.previewApplicationDeadlines[b.dataset.id];if(state.page==='find')renderFindResults();else renderFloatingWidget();refreshApplicationCountdowns();break;
  case 'floating-cancel-applications':state.floatingMineCancelled=true;for(const [id,s] of Object.entries(state.apps))if(s==='applied'){state.apps[id]='cancelled';delete state.applicationDeadlines[id];}if(state.page==='find')renderFindResults();else renderFloatingWidget();refreshApplicationCountdowns();toast('已取消等待中的申请。');break;
  case 'floating-cancel-recruit':state.floatingRecruitCancelled=true;state.listing=null;state.editing=false;state.newApplicantIds=[];$('#applicant-audio').pause();if(state.page==='create')renderPage();else renderFloatingWidget();toast('招募已取消。');break;
  case 'reset-floating-position':state.floatingPosition=null;state.floatingRecruitPosition=null;positionFloatingWidget();toast('悬浮窗已回到默认位置。');break;
  case 'toggle-creation-picker':readForm();state.createPickerOpen=!state.createPickerOpen;state.createActivityQuery='';renderPage();if(state.createPickerOpen)$('#create-activity-query').focus();break;
  case 'clear-create-search':readForm();state.createActivityQuery='';renderPage();$('#create-activity-query').focus();break;
  case 'close-category-menu':closeCategoryMenu();break;
  case 'open-category-menu':state.categoryMenuOpen=true;renderPage();break;
  case 'toggle-filters':setFiltersExpanded(!state.filtersExpanded);break;
  case 'clear-search':state.query='';state.personFilter=null;state.browseScroll=0;renderPage();break;
  case 'clear-filters':state.filters={};state.sort=state.settings.defaultSort;state.selected=null;state.browseScroll=0;renderPage();break;
  case 'back-results':state.mode='results';renderPage();break;
  case 'apply':applyModal(Number(b.dataset.id));break;
  case 'locate-application':{const card=$('#application-'+b.dataset.id);card.scrollIntoView({block:'nearest'});card.classList.remove('highlight');void card.offsetWidth;card.classList.add('highlight');card.querySelector('button').focus({preventScroll:true});break;}
  case 'refresh-search':refreshGroups();break;
  case 'toggle-auto-join':state.settings.autoJoin=!state.settings.autoJoin;renderPage();if(state.settings.autoJoin)autoJoinPending();break;
  case 'cancel-application':state.apps[b.dataset.id]='cancelled';delete state.applicationDeadlines[b.dataset.id];closeModal();renderFindResults();refreshApplicationCountdowns();toast('已取消申请。');break;
  case 'accept-invite':state.apps[b.dataset.id]='accepted';closeNativeInvite();if(state.page==='find')renderFindResults();else renderFloatingWidget();toast('已在邀请弹窗中接受。');break;
  case 'decline-invite':state.apps[b.dataset.id]='declined';closeNativeInvite();if(state.page==='find')renderFindResults();else renderFloatingWidget();toast('已在邀请弹窗中拒绝。');break;
  case 'edit-listing':state.autoTitle=false;state.form={...state.listing};state.editing=true;renderPage(true);break;
  case 'cancel-edit-listing':state.editing=false;renderPage(true);break;
  case 'end-listing':state.listing=null;state.selectedApplicant=null;state.editing=false;state.extraApplicants=[];state.newApplicantIds=[];$('#applicant-audio').pause();renderPage(true);toast('招募已结束。');break;
  case 'invite-applicant':respondToApplicant(Number(b.dataset.id),'invited');break;
  case 'decline-applicant':respondToApplicant(Number(b.dataset.id),'declined');break;
  case 'add-note':state.noteTab='all';state.editNote='new';state.noteDraft={name:'',realm:'',reason:'',classSpec:'未知',type:state.settings.defaultNote};renderPage();$('#note-identity').focus();break;
  case 'close-note':if(state.editNote==='new')state.editNote=null;state.noteDraft=null;renderPage();break;
  case 'save-note':saveNote();break;
  case 'delete-note':state.notes=state.notes.filter(n=>n.id!==state.editNote);state.editNote=null;renderPage();toast('荔枝组队：记录已删除。');break;
  case 'close-modal':closeModal();break;
  case 'close-native-invite':closeNativeInvite();break;
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
 if(el.dataset.settingRange){const key=el.dataset.settingRange;state.settings[key]=Number(el.value);el.nextElementSibling.value=el.value+'%';positionFloatingWidget();return;}
 if(el.form?.id==='listing-form'&&el.name){state.form[el.name]=el.type==='number'?Number(el.value)||0:el.value;if(el.name==='title')state.autoTitle=false;}
 else if(el.id==='create-activity-query'){state.createActivityQuery=el.value;$('#creation-activity-list').innerHTML=creationActivityRows();const searching=!!el.value.trim();$('.creation-category-picker').hidden=searching;$('.creation-picker-columns').classList.toggle('is-searching',searching);if($('#listing-expansion'))$('#listing-expansion').hidden=searching;$('[data-action=clear-create-search]').hidden=!searching;enhanceSelects();}
 else if(el.id==='group-query'){state.query=el.value;state.personFilter=null;state.browseScroll=0;renderFindResults();}
 else if(el.dataset.filter){state.filters[el.dataset.filter]=Number(el.value)||0;state.browseScroll=0;renderFindResults();}
 else if(el.id==='notes-query'){state.noteQuery=el.value;$('#notes-list').innerHTML=notesRows();$('.notes-count').textContent=`${visibleNotes().length} 条记录`;}
});
document.addEventListener('change',event=>{
 const el=event.target;
 if(el.id==='event-demo'){const value=el.value;el.value='';if(value==='applicant')simulateNewApplicant();else if(value==='invite')nativeInvitePreview();return;}
 if(el.id==='note-class'){$('#note-spec').innerHTML=noteSpecOptions(el.value);$('#note-spec').disabled=!el.value;enhanceSelects();return;}
 if(el.id==='party-demo'){if($('#listing-form'))readForm();state.partyMode=el.value;if(state.page==='create')renderPage();}
 else if(el.id==='application-demo'){
  closeNativeInvite();
  state.listing=null;state.newApplicantIds=[];state.extraApplicants=[];state.selectedApplicant=null;state.editing=false;
  $('#applicant-audio').pause();
  state.apps={};state.applicationDeadlines={};state.applicationNotes={};
  state.floatingMineCancelled=false;
  const scenarios={none:[],mixed:mixedApplicationIDs,two:[2,4],five:[1,2,3,4,5],'raid-two':[11,12],'raid-five':[11,12,13,14,15]};
  const ids=scenarios[el.value],raid=el.value.startsWith('raid-'),invitedID=raid?(ids.length===5?14:12):4;
  ids.forEach((id,i)=>{state.apps[id]=id===invitedID?'invited':'applied';if(id!==invitedID)state.applicationDeadlines[id]=Date.now()+300000-i*23000;});
  if(ids.length){state.page=state.lastMain='find';state.categoryMenuOpen=false;changeCategory(raid?'season-raids':'season-dungeons');}
  else if(state.page==='find')renderFindResults();else if(state.page==='create')renderPage();else renderFloatingWidget();
 refreshApplicationCountdowns();if(state.settings.autoJoin)autoJoinPending();
 }
 else if(el.id==='role-filter'){state.filters.role=el.value;renderFindResults();}
 else if(el.id==='social-filter'){state.filters.social=el.value;renderFindResults();}
 else if(el.id==='sort-results'){state.sort=el.value;renderFindResults();}
 else if(el.id==='sort-applicants'){state.appSort=el.value;renderPage();}
 else if(el.id==='activity-filter'){state.activity=el.value;if(!difficulties(state.category,state.activity,state.expansion).some(([id])=>id===state.difficulty))state.difficulty='all';state.selected=null;renderPage();}
 else if(el.id==='expansion-filter'){state.expansion=el.value;state.activity='all';state.difficulty='all';state.selected=null;state.browseScroll=0;renderPage();}
 else if(el.dataset.settingSelect){const key=el.dataset.settingSelect;state.settings[key]=el.value;if(key==='defaultSort')state.sort=el.value;renderPage();}
 else if(el.name==='expansion'&&el.form?.id==='listing-form'){readForm();state.form.activity=categoryActivities(state.form.category,el.value)[0].id;const choices=difficulties(state.form.category,state.form.activity);if(!choices.some(([id])=>id===state.form.difficulty))state.form.difficulty=choices[0]?.[0]||'';updateCreationTitle();renderPage();}
 else if(el.name==='activity'&&el.form?.id==='listing-form'){readForm();const choices=difficulties(state.form.category,el.value);if(!choices.some(([id])=>id===state.form.difficulty))state.form.difficulty=choices[0]?.[0]||'';updateCreationTitle();renderPage();}
});
function refreshGroups(){
 if(state.searching)return;state.searching=true;renderPage();clearTimeout(searchTimer);
 searchTimer=setTimeout(()=>{state.searching=false;if(state.page==='find'){renderPage();toast(`已更新 ${filteredGroups().length} 支队伍。`);}},650);
}
document.addEventListener('submit',event=>{
 event.preventDefault();
 if(event.target.id==='search-form'){
  refreshGroups();
 }else if(event.target.id==='listing-form'){
  readForm();if(!state.form.title.trim())return;state.floatingRecruitCancelled=false;state.listing={...state.form};$('#application-demo').value='none';state.apps={};state.applicationDeadlines={};state.applicationNotes={};closeNativeInvite();refreshApplicationCountdowns();state.editing=false;state.selectedApplicant=null;renderPage(true);toast('组队已发布，可以开始查看申请。');
 }else if(event.target.id==='group-action-demo'){
  closeModal();toast('已演示密聊流程，未发送消息。');
 }else if(event.target.id==='apply-form'){
  if(countActive()>=5){showApplicationLimit(Number(event.target.dataset.groupId));return;}
  if(!$('.modal-role.active')){$('#role-message').textContent='请选择一个职责。';$('#role-message').style.color='var(--gold)';return;}
  const id=event.target.dataset.groupId,note=$('#application-note').value;
  state.apps[id]='applied';state.applicationDeadlines[id]=Date.now()+300000;state.applicationNotes[id]=note;closeModal();renderFindResults();refreshApplicationCountdowns();toast('申请已提交，等待队长处理。');
 }
});
const tipSelector='[data-tip-group],[data-tip-applicant],[data-tip-member],[data-tip-note]';
let floatingDrag,suppressFloatingClick=false;
document.addEventListener('pointerdown',event=>{
 const handle=event.target.closest('[data-floating-drag]');
 if(!handle||state.settings.floatingLocked||event.button!==0)return;
 const root=handle.closest('.floating-widget'),rect=root.getBoundingClientRect();
 suppressFloatingClick=false;floatingDrag={handle,key:root.id==='floating-recruit-widget'?'floatingRecruitPosition':'floatingPosition',id:event.pointerId,x:event.clientX,y:event.clientY,left:rect.left,top:rect.top,moved:false};
 handle.setPointerCapture(event.pointerId);
});
document.addEventListener('pointermove',event=>{
 if(!floatingDrag||event.pointerId!==floatingDrag.id)return;
 const dx=event.clientX-floatingDrag.x,dy=event.clientY-floatingDrag.y;
 if(!floatingDrag.moved&&Math.hypot(dx,dy)<4)return;
 floatingDrag.moved=true;state[floatingDrag.key]={x:floatingDrag.left+dx,y:floatingDrag.top+dy};positionFloatingWidget();
});
function finishFloatingDrag(){if(floatingDrag){suppressFloatingClick=floatingDrag.moved;floatingDrag=null;}}
document.addEventListener('pointerup',finishFloatingDrag);
document.addEventListener('pointercancel',finishFloatingDrag);
document.addEventListener('mouseover',event=>{
 if(event.target.closest('#tooltip')){clearTimeout(tipHideTimer);return;}
 const owner=event.target.closest(tipSelector);if(owner&&$('#modal').hidden&&$('#group-context-menu').hidden)queueTip(owner,event);else if(tipOwner||pendingTipOwner)scheduleHideTip();
});
document.addEventListener('mouseout',event=>{
 const owner=tipOwner||pendingTipOwner;if(!owner)return;
 const next=event.relatedTarget;if(next&&(owner.contains(next)||$('#tooltip').contains(next))){clearTimeout(tipHideTimer);return;}
 scheduleHideTip();
});
document.addEventListener('focusin',event=>{if(event.target.closest('#tooltip')){clearTimeout(tipHideTimer);return;}const owner=event.target.closest(tipSelector);if(owner&&$('#modal').hidden&&$('#group-context-menu').hidden)queueTip(owner);});
document.addEventListener('focusout',event=>{const next=event.relatedTarget;if(next&&($('#tooltip').contains(next)||tipOwner?.contains(next)))return;scheduleHideTip();});
document.addEventListener('wheel',event=>{if(!event.target.closest('#tooltip'))hideTip();closeGroupMenu();},{passive:true});
document.addEventListener('keydown',event=>{
 const menu=$('#group-context-menu');
 if(!menu.hidden){
  if(event.key==='Escape'){event.preventDefault();closeGroupMenu(true);return;}
  if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)){event.preventDefault();const items=[...menu.querySelectorAll('button:not(:disabled)')],current=items.indexOf(document.activeElement),next=event.key==='Home'?0:event.key==='End'?items.length-1:(current+(event.key==='ArrowDown'?1:-1)+items.length)%items.length;items[next].focus();return;}
 }
 if(event.key==='ContextMenu'||event.key==='F10'&&event.shiftKey){const row=event.target.closest('[data-result-id],[data-application-id]');if(row){event.preventDefault();const box=row.getBoundingClientRect();openGroupMenu(Number(row.dataset.resultId||row.dataset.applicationId),box.left+50,box.top+20,row.querySelector('[data-group]'));return;}}
 if(event.key==='Enter'&&event.target.closest('[data-result-id]')){event.preventDefault();applyModal(Number(event.target.closest('[data-result-id]').dataset.resultId));return;}
 if(event.key==='Enter'&&event.target.id==='create-activity-query'){event.preventDefault();$('#creation-activity-list [data-form-activity]')?.click();return;}
 if(event.key==='Shift'&&!shiftDown){shiftDown=true;if(tipOwner?.dataset.tipGroup&&!tipMemberId){tipExpanded=!tipExpanded;showTip(tipOwner);}}
 if(event.key==='Escape'){if(!$('#tooltip').hidden){event.preventDefault();hideTip();return;}hideTip();if(!$('#native-invite-layer').hidden)closeNativeInvite();else if(!$('#modal').hidden)closeModal();else if(state.categoryMenuOpen)closeCategoryMenu();else if(state.page==='find'&&state.filtersExpanded)setFiltersExpanded(false);else if(state.createPickerOpen){closeCreationPicker();$('[data-action=toggle-creation-picker]').focus();}else presence(false);}
});
document.addEventListener('keyup',event=>{if(event.key==='Shift')shiftDown=false;});
addEventListener('blur',()=>{shiftDown=false;hideTip();closeGroupMenu();});
$('#modal').addEventListener('click',event=>{if(event.target===$('#modal'))closeModal();});
const logo=$('#logo');function brandMotion(){if(state.settings.motion||logo.classList.contains('logo-motion'))return;logo.classList.add('logo-motion');}logo.addEventListener('animationend',()=>logo.classList.remove('logo-motion'));$('#brand').addEventListener('mouseenter',brandMotion);$('#brand').addEventListener('click',brandMotion);
let phase=0,target=1,presenceFrame,lastTime,afterPresence;
function drawPresence(){const q=phase*(2-phase),u=Math.min(1,phase*4.2);for(const el of [$('#window'),$('#search-filters')]){el.style.transform=`translateY(${64*(1-q)}px)`;el.style.opacity=u*(2-u);}}
function presence(open,done){target=open?1:0;afterPresence=done;hideTip();closeGroupMenu();closeCategoryMenu();if(open){$('#window').style.visibility='visible';$('#search-filters').style.visibility='visible';$('#open-window').hidden=true;brandMotion();}if(state.settings.motion){phase=target;drawPresence();finishPresence();return;}if(!presenceFrame){lastTime=performance.now();presenceFrame=requestAnimationFrame(tickPresence);}}
function tickPresence(now){const dt=(now-lastTime)/420;lastTime=now;phase=target===1?Math.min(1,phase+dt):Math.max(0,phase-dt);drawPresence();if(phase===target){presenceFrame=null;finishPresence();}else presenceFrame=requestAnimationFrame(tickPresence);}
function finishPresence(){if(target===0){$('#window').style.visibility='hidden';$('#search-filters').style.visibility='hidden';$('#open-window').hidden=state.settings.floating;logo.classList.remove('logo-motion');}const callback=afterPresence;afterPresence=null;callback?.();}
$('#demo-limit').onclick=demoApplicationLimit;
const demoScenarios = $('.review-controls');
demoScenarios.addEventListener('change',()=>{demoScenarios.open=false;});
demoScenarios.addEventListener('click',event=>{if(event.target.closest('button'))demoScenarios.open=false;});
$('#close-window').onclick=()=>presence(false);$('#open-window').onclick=()=>presence(true);$('#replay').onclick=()=>presence(false,()=>presence(true));$('#reset').onclick=()=>{clearTimeout(searchTimer);$('#applicant-audio').pause();closeModal();closeNativeInvite();resetState();$('#party-demo').value=state.partyMode;$('#application-demo').value='two';renderPage();refreshApplicationCountdowns();presence(true);toast('演示已重置。');};
function fit(){const width=state.page==='find'&&state.filtersExpanded?1440:1160,scale=Math.min(1,(innerWidth-32)/width),frame=$('#fit-frame');frame.style.width=width+'px';frame.style.transform=`scale(${scale})`;$('.stage').style.height=(840*scale+46)+'px';$('.stage').style.minHeight='0';frame.style.marginBottom=-(840*(1-scale))+'px';}
addEventListener('resize',()=>{hideTip();closeGroupMenu();fit();positionFloatingWidget();});
renderPage();fit();drawPresence();presence(true);refreshApplicationCountdowns();

