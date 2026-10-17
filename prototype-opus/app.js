/* 荔枝组队 · 交互原型 03
   设计目标：
   1) 创建组队要能一眼看出「位置 / 要求 / 当前小队」，填写时右侧实时预览发布后的队伍行；
   2) 发布后进入等待申请流程：申请者整组呈现、邀请后占位、成员变动记录在案。 */

const $ = (q, root = document) => root.querySelector(q);
const $$ = (q, root = document) => [...root.querySelectorAll(q)];
const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const icon = (name, cls = '') => `<img class="i ${cls}" src="assets/icons/${name}.png" alt="" aria-hidden="true" draggable="false">`;

/* ---------------------------------------------------------------- 语义数据 */

const roleNames = { TANK: '坦克', HEALER: '治疗', DAMAGER: '输出' };
const roleIcons = { TANK: 'tank', HEALER: 'healer', DAMAGER: 'damage' };
const classInfo = {
  WARRIOR: ['战', '#c69b6d'], PALADIN: ['骑', '#f48cba'], MAGE: ['法', '#69ccf0'], PRIEST: ['牧', '#eeeae6'],
  DRUID: ['德', '#ff9b48'], SHAMAN: ['萨', '#659de1'], DEMONHUNTER: ['猎', '#c084d8'], ROGUE: ['贼', '#e6d67f'],
  MONK: ['僧', '#7edbb7'], WARLOCK: ['术', '#a999db'], HUNTER: ['猎', '#aad372'], DEATHKNIGHT: ['死', '#c75e72'],
  EVOKER: ['龙', '#74b5aa']
};
const colorOf = m => classInfo[m.class]?.[1] || '#b6c2d2';
const noteTypes = {
  positive: { label: '推荐', icon: 'heart' },
  neutral: { label: '中性', icon: 'book' },
  caution: { label: '拉黑', icon: 'caution' }
};

const categories = [
  { id: 'season-dungeons', name: '赛季地下城', kind: 'dungeon', icon: 'mountain', season: true },
  { id: 'season-raids', name: '赛季团本', kind: 'raid', icon: 'tower', season: true },
  { id: 'delves', name: '地下堡', kind: 'delve', icon: 'delve', expansion: true },
  { id: 'dungeons', name: '地下城', kind: 'dungeon', icon: 'mountain', expansion: true },
  { id: 'raids', name: '团队副本', kind: 'raid', icon: 'tower', expansion: true },
  { id: 'pvp', name: 'PvP', kind: 'pvp', icon: 'pvp' },
  { id: 'quests', name: '任务', kind: 'quest', icon: 'flag' },
  { id: 'custom', name: '自定义', kind: 'custom', icon: 'plus' }
];
const expansionOrder = ['至暗之夜', '地心之战', '巨龙时代', '暗影国度', '争霸艾泽拉斯', '军团再临', '德拉诺之王', '熊猫人之谜', '大地的裂变', '巫妖王之怒', '燃烧的远征', '经典旧世'];
const activities = [
  { id: 'academy', name: '艾杰斯亚学院', kind: 'dungeon', expansion: '巨龙时代', season: true, art: 'academy.jpg', color: '#8db1cf' },
  { id: 'ruby', name: '红玉新生法池', kind: 'dungeon', expansion: '巨龙时代', season: true, art: 'ruby.jpg', color: '#de8b79' },
  { id: 'bracken', name: '蕨皮山谷', kind: 'dungeon', expansion: '巨龙时代', season: true, art: 'bracken.jpg', color: '#9eb778' },
  { id: 'nokhud', name: '诺库德阻击战', kind: 'dungeon', expansion: '巨龙时代', season: true, art: 'nokhud.jpg', color: '#c3b58b' },
  { id: 'azure', name: '碧蓝魔馆', kind: 'dungeon', expansion: '巨龙时代', season: true, art: 'azure.jpg', color: '#9a9bd7' },
  { id: 'neltharus', name: '奈萨鲁斯', kind: 'dungeon', expansion: '巨龙时代', season: true, art: 'neltharus.jpg', color: '#ce9970' },
  { id: 'palace', name: '尼鲁巴尔王宫', kind: 'raid', expansion: '地心之战', season: true, art: 'palace.jpg', color: '#b494c8' },
  { id: 'undermine', name: '解放安德麦', kind: 'raid', expansion: '地心之战', season: true, art: 'undermine.png', color: '#b6ae73' },
  { id: 'mists', name: '塞兹仙林的迷雾', kind: 'dungeon', expansion: '暗影国度', art: 'mists.png', color: '#9dbbd0' },
  { id: 'fungal', name: '真菌之愚', kind: 'delve', expansion: '地心之战', color: '#b1ba88' },
  { id: 'waterworks', name: '水能堡', kind: 'delve', expansion: '地心之战', color: '#83b8c7' },
  { id: 'arena2', name: '2v2 竞技场', kind: 'pvp', ratedPvp: true, color: '#c98e89' },
  { id: 'arena3', name: '3v3 竞技场', kind: 'pvp', ratedPvp: true, color: '#c98e89' },
  { id: 'battleground', name: '评级战场', kind: 'pvp', ratedPvp: true, color: '#c98e89' },
  { id: 'worldquest', name: '世界任务', kind: 'quest', color: '#cbb577' },
  { id: 'leveling', name: '任务与升级', kind: 'quest', color: '#cbb577' },
  { id: 'custom', name: '自定义 PvE', kind: 'custom', color: '#a7aabd' },
  { id: 'custom-pvp', name: '自定义 PvP', kind: 'custom', color: '#c98e89' }
];
// 样例目录模拟 LFG 层级；正式插件使用客户端原生活动表。
const sampleDungeons = [
  ['nalorakk', '纳洛拉克的洞穴', '至暗之夜'], ['magisters', '魔导师平台', '至暗之夜'],
  ['threads', '千丝之城', '地心之战'], ['priory', '圣焰隐修院', '地心之战'], ['darkflame', '暗焰裂口', '地心之战'],
  ['uldaman', '奥达曼：提尔的遗产', '巨龙时代'], ['atal', '阿塔达萨', '争霸艾泽拉斯'],
  ['blackrook', '黑鸦堡垒', '军团再临'], ['auchindoun', '奥金顿', '德拉诺之王'], ['jade', '青龙寺', '熊猫人之谜'],
  ['stonecore', '巨石之核', '大地的裂变'], ['utgarde', '乌特加德城堡', '巫妖王之怒'],
  ['ramparts', '地狱火城墙', '燃烧的远征'], ['deadmines', '死亡矿井', '经典旧世']
];
activities.push(
  ...sampleDungeons.map(([id, name, expansion]) => ({ id, name, expansion, kind: 'dungeon', color: '#8daabd' })),
  { id: 'vault', name: '化身巨龙牢窟', expansion: '巨龙时代', kind: 'raid', color: '#b494c8' },
  { id: 'nathria', name: '纳斯利亚堡', expansion: '暗影国度', kind: 'raid', color: '#b494c8' },
  { id: 'karazhan', name: '卡拉赞', expansion: '燃烧的远征', kind: 'raid', color: '#b494c8' }
);
const activityVariants = {
  academy: ['normal', 'heroic', 'mythic', 'keystone'], ruby: ['normal', 'heroic', 'mythic', 'keystone'],
  bracken: ['normal', 'heroic', 'mythic', 'keystone'], nokhud: ['normal', 'heroic', 'mythic', 'keystone'],
  azure: ['normal', 'heroic', 'mythic', 'keystone'], neltharus: ['normal', 'heroic', 'mythic', 'keystone'],
  mists: ['normal', 'heroic', 'mythic'], nalorakk: ['normal', 'heroic', 'mythic'], magisters: ['normal', 'heroic', 'mythic'],
  threads: ['normal', 'heroic', 'mythic'], priory: ['normal', 'heroic', 'mythic'], darkflame: ['normal', 'heroic', 'mythic'],
  uldaman: ['normal', 'heroic', 'mythic'], atal: ['normal', 'heroic', 'mythic'], blackrook: ['normal', 'heroic', 'mythic'],
  auchindoun: ['normal', 'heroic', 'mythic'], jade: ['normal', 'heroic'], stonecore: ['normal', 'heroic'],
  utgarde: ['normal', 'heroic'], ramparts: ['normal', 'heroic'], deadmines: ['normal'],
  palace: ['normal', 'heroic', 'mythic'], undermine: ['normal', 'heroic', 'mythic'], vault: ['normal', 'heroic', 'mythic'],
  nathria: ['normal', 'heroic', 'mythic'], karazhan: ['normal']
};
const difficultyNames = { all: '全部难度', normal: '普通', heroic: '英雄', mythic: '史诗', keystone: '史诗钥石', delve: '地下堡' };
const categoryOf = id => categories.find(c => c.id === id);
const act = id => activities.find(a => a.id === id);
const kindIcon = a => a.kind === 'raid' ? 'tower' : a.kind === 'pvp' ? 'pvp' : a.kind === 'delve' ? 'delve' : a.kind === 'quest' ? 'flag' : a.kind === 'custom' ? 'plus' : 'mountain';
const categoryActivities = (id, expansion = 'all') => {
  const c = categoryOf(id);
  return activities.filter(a => a.kind === c.kind && (!c.season || a.season) && (expansion === 'all' || a.expansion === expansion));
};
const difficulties = (category, activityID = 'all', expansion = 'all') => {
  const available = activityID === 'all' ? categoryActivities(category, expansion) : [act(activityID)].filter(Boolean);
  const variants = new Set(available.flatMap(a => activityVariants[a.id] || []));
  return ['normal', 'heroic', 'mythic', 'keystone'].filter(k => variants.has(k)).map(k => [k, difficultyNames[k]]);
};
const expansionOptions = category => expansionOrder.filter(e => categoryActivities(category).some(a => a.expansion === e));
const gradedActivity = a => a && (a.kind === 'dungeon' || a.kind === 'raid' || a.ratedPvp);
const scoreRequirement = (activityID, difficulty) => {
  const a = act(activityID);
  if (!a) return '';
  if (a.ratedPvp) return '最低 PvP 评分';
  if (a.kind === 'dungeon' && difficulty === 'keystone') return '最低钥石评分';
  return '';
};
const playstyles = ['新手上路', '休闲娱乐', '老手带队', '固定频率'];

/* ---------------------------------------------------------------- 玩家与队伍 */

const people = [
  { id: 'wind', name: '晚风听雨', realm: '晨风号角', class: 'WARRIOR', role: 'TANK', spec: '防护', ilvl: 648, score: 3128 },
  { id: 'sugar', name: '糖霜骑士', realm: '白银之手', class: 'PALADIN', role: 'HEALER', spec: '神圣', ilvl: 645, score: 2976 },
  { id: 'star', name: '暮色星河', realm: '晨风号角', class: 'MAGE', role: 'DAMAGER', spec: '冰霜', ilvl: 647, score: 3052 },
  { id: 'bird', name: '云上青鸟', realm: '凤凰之神', class: 'PRIEST', role: 'DAMAGER', spec: '暗影', ilvl: 643, score: 2862 },
  { id: 'tea', name: '柚子茶', realm: '白银之手', class: 'DRUID', role: 'DAMAGER', spec: '平衡', ilvl: 646, score: 3014 },
  { id: 'rain', name: '落雨无声', realm: '晨风号角', class: 'SHAMAN', role: 'HEALER', spec: '恢复', ilvl: 644, score: 2893 },
  { id: 'night', name: '长夜微光', realm: '凤凰之神', class: 'DEMONHUNTER', role: 'TANK', spec: '复仇', ilvl: 650, score: 3280 },
  { id: 'moon', name: '月下行舟', realm: '白银之手', class: 'ROGUE', role: 'DAMAGER', spec: '狂徒', ilvl: 649, score: 3210 },
  { id: 'panda', name: '青竹', realm: '晨风号角', class: 'MONK', role: 'HEALER', spec: '织雾', ilvl: 638, score: 2450 },
  { id: 'leaf', name: '青叶', realm: '白银之手', class: 'HUNTER', role: 'DAMAGER', spec: '野兽控制', ilvl: 646, score: 3021 },
  { id: 'ember', name: '烛火', realm: '晨风号角', class: 'WARLOCK', role: 'DAMAGER', spec: '毁灭', ilvl: 647, score: 2952 },
  { id: 'cloud', name: '云间', realm: '凤凰之神', class: 'MAGE', role: 'DAMAGER', spec: '奥术', ilvl: 645, score: 2988 },
  { id: 'frost', name: '寒汀', realm: '白银之手', class: 'DEATHKNIGHT', role: 'DAMAGER', spec: '冰霜', ilvl: 648, score: 3105 },
  { id: 'stone', name: '山眠', realm: '晨风号角', class: 'WARRIOR', role: 'DAMAGER', spec: '狂怒', ilvl: 646, score: 2930 },
  { id: 'light', name: '浮光', realm: '凤凰之神', class: 'PALADIN', role: 'DAMAGER', spec: '惩戒', ilvl: 648, score: 3023 },
  { id: 'plum', name: '梅子青', realm: '白银之手', class: 'EVOKER', role: 'DAMAGER', spec: '湮灭', ilvl: 645, score: 2910 },
  { id: 'harbor', name: '远港', realm: '晨风号角', class: 'ROGUE', role: 'DAMAGER', spec: '敏锐', ilvl: 647, score: 2975 },
  { id: 'dew', name: '朝露', realm: '白银之手', class: 'PRIEST', role: 'HEALER', spec: '神圣', ilvl: 646, score: 3027 },
  { id: 'cedar', name: '杉月', realm: '晨风号角', class: 'HUNTER', role: 'DAMAGER', spec: '射击', ilvl: 644, score: 2817 },
  { id: 'ash', name: '灰烬', realm: '凤凰之神', class: 'WARLOCK', role: 'DAMAGER', spec: '恶魔学识', ilvl: 645, score: 2834 },
  { id: 'tide', name: '潮生', realm: '白银之手', class: 'MAGE', role: 'DAMAGER', spec: '火焰', ilvl: 646, score: 2851 },
  { id: 'cinder', name: '流萤', realm: '晨风号角', class: 'DEATHKNIGHT', role: 'DAMAGER', spec: '邪恶', ilvl: 647, score: 2868 },
  { id: 'oak', name: '秋橡', realm: '凤凰之神', class: 'WARRIOR', role: 'DAMAGER', spec: '武器', ilvl: 648, score: 2885 },
  { id: 'dawn', name: '晓光', realm: '白银之手', class: 'PALADIN', role: 'DAMAGER', spec: '惩戒', ilvl: 642, score: 2902 },
  { id: 'kite', name: '纸鸢', realm: '晨风号角', class: 'EVOKER', role: 'DAMAGER', spec: '增辉', ilvl: 643, score: 2919 },
  { id: 'shade', name: '竹影', realm: '凤凰之神', class: 'ROGUE', role: 'DAMAGER', spec: '奇袭', ilvl: 644, score: 2936 },
  { id: 'lily', name: '听荷', realm: '白银之手', class: 'DRUID', role: 'DAMAGER', spec: '野性', ilvl: 645, score: 2953 },
  { id: 'sand', name: '沙洲', realm: '晨风号角', class: 'MONK', role: 'DAMAGER', spec: '踏风', ilvl: 646, score: 2970 },
  { id: 'mist', name: '山岚', realm: '凤凰之神', class: 'SHAMAN', role: 'DAMAGER', spec: '元素', ilvl: 647, score: 2987 },
  { id: 'snow', name: '初雪', realm: '白银之手', class: 'PRIEST', role: 'DAMAGER', spec: '暗影', ilvl: 648, score: 3004 }
];
const person = id => people.find(p => p.id === id);
const friendIds = ['wind', 'star', 'moon', 'frost'];
const guildIds = ['sugar', 'tea', 'leaf', 'dew'];
const isFriend = id => friendIds.includes(id);
const isGuild = id => guildIds.includes(id);

const initialNotes = [
  { id: 'wind', type: 'positive', name: '晚风听雨', realm: '晨风号角', classSpec: '战士 · 防护', date: '26/10/15', reason: '路线清楚，会提醒打断；上次学院配合很好。' },
  { id: 'tea', type: 'positive', name: '柚子茶', realm: '白银之手', classSpec: '德鲁伊 · 平衡', date: '26/10/14', reason: '耐心，愿意带新手熟悉机制。一起完成了两次限时。' },
  { id: 'night', type: 'caution', name: '长夜微光', realm: '凤凰之神', classSpec: '恶魔猎手 · 复仇', date: '26/10/13', reason: '上次提前离队；再组之前先确认能否打完整场。' },
  { id: 'bird', type: 'neutral', name: '云上青鸟', realm: '凤凰之神', classSpec: '牧师 · 暗影', date: '26/10/12', reason: '团队沟通顺畅，保留记录便于下次组队。' }
];

const groups = [
  { id: 1, activity: 'academy', difficulty: 'keystone', level: 12, title: '+12 学院 稳定限时 来输出', leader: 'wind', members: ['wind', 'sugar', 'star'], ilvl: 640, minScore: 2800, age: 26, comment: '熟练机制，开打前确认路线。打断分配好，沟通友善，争取限时。' },
  { id: 2, activity: 'ruby', difficulty: 'keystone', level: 10, title: '+10 打完就走，来治疗', leader: 'night', members: ['night', 'moon', 'tea', 'bird'], ilvl: 635, minScore: 2400, age: 50, comment: '来个治疗就出发，正常打完不跳车。' },
  { id: 3, activity: 'bracken', difficulty: 'keystone', level: 13, title: '+13 冲分，熟练队', leader: 'moon', members: ['rain', 'moon'], ilvl: 645, minScore: 3000, age: 92, comment: '有合剂和食物。希望一起配合打断，开怪前说好路线。' },
  { id: 4, activity: 'nokhud', difficulty: 'keystone', level: 11, title: '+11 周常，友好交流', leader: 'sugar', members: ['wind', 'sugar', 'tea'], ilvl: 638, minScore: 2600, age: 120, comment: '打完就好，熟悉机制可以来。' },
  { id: 5, activity: 'ruby', difficulty: 'keystone', level: 12, title: '+12 法池 补一输出', leader: 'tea', members: ['night', 'rain', 'tea', 'bird'], ilvl: 640, minScore: 2800, age: 189, comment: '坦奶已齐，等一位输出。有嗜血更好。' },
  { id: 6, activity: 'azure', difficulty: 'keystone', level: 9, title: '+9 新人练习 一起打', leader: 'panda', members: ['panda', 'bird'], ilvl: 630, minScore: 2200, age: 240, comment: '机制还在练习，会在开怪前确认。欢迎愿意沟通的朋友。' },
  { id: 7, activity: 'neltharus', difficulty: 'keystone', level: 12, title: '+12 最后一把，稳定打完', leader: 'star', members: ['wind', 'sugar', 'star', 'moon'], ilvl: 640, minScore: 2800, age: 302, comment: '不赶时间，正常打完。可以打字沟通。' },
  { id: 8, activity: 'academy', difficulty: 'keystone', level: 14, title: '+14 认真冲分，等一奶', leader: 'night', members: ['night', 'moon', 'tea', 'star'], ilvl: 648, minScore: 3100, age: 370, comment: '目标限时，熟悉路线和首领机制。' },
  { id: 9, activity: 'neltharus', difficulty: 'keystone', level: 10, title: '+10 奈萨鲁斯，稳定打完', leader: 'stone', members: ['stone', 'dew', 'cloud'], ilvl: 635, minScore: 2500, age: 70, comment: '正常打完，开怪前确认路线。' },
  { id: 11, category: 'season-raids', activity: 'palace', difficulty: 'heroic', title: '英雄王宫 5/8，补治疗和输出', leader: 'wind', members: people.slice(0, 17).map(p => p.id), max: 20, counts: [2, 3, 12], progress: '5/8', ilvl: 635, minScore: 0, age: 45, comment: '稳定团队补位，语音指挥。分装前讲清规则，打完大家一起散。' },
  { id: 12, category: 'season-raids', activity: 'palace', difficulty: 'normal', title: '普通全通，欢迎练习机制', leader: 'sugar', members: ['wind', 'night', 'sugar', 'rain', 'star', 'tea', 'moon', 'bird', 'leaf', 'ember', 'cloud', 'frost'], max: 20, counts: [2, 2, 8], progress: '0/8', ilvl: 620, minScore: 0, age: 80, comment: '会讲机制，不赶进度。准备好合剂食物，能打完整。' },
  { id: 13, category: 'season-raids', activity: 'undermine', difficulty: 'heroic', title: '英雄安德麦，周常全通', leader: 'moon', members: people.slice(0, 18).map(p => p.id), max: 20, counts: [2, 4, 12], progress: '3/8', ilvl: 640, minScore: 0, age: 110, comment: '当前三号已过，补两位稳定输出。' },
  { id: 14, category: 'season-raids', activity: 'undermine', difficulty: 'normal', title: '普通团本 清进度一起打', leader: 'tea', members: ['wind', 'night', 'sugar', 'star', 'tea', 'moon', 'bird', 'leaf', 'ember'], max: 20, counts: [2, 1, 6], progress: '1/8', ilvl: 615, minScore: 0, age: 180, comment: '一边讲一边打，态度友好。新手请说明熟悉程度。' },
  { id: 15, category: 'season-raids', activity: 'palace', difficulty: 'mythic', title: '史诗王宫，固定队补位', leader: 'wind', members: people.slice(0, 18).map(p => p.id), max: 20, counts: [2, 4, 12], progress: '2/8', ilvl: 645, minScore: 0, age: 230, comment: '固定时间开团，找愿意长期磨合的队友。' },
  { id: 21, category: 'dungeons', activity: 'academy', difficulty: 'heroic', title: '英雄学院，轻松打完', leader: 'tea', members: ['wind', 'tea', 'bird'], max: 5, ilvl: 600, minScore: 0, age: 40, comment: '练习路线，随时出发。' },
  { id: 22, category: 'dungeons', activity: 'mists', difficulty: 'mythic', title: '史诗迷雾，熟悉机制', leader: 'sugar', members: ['night', 'sugar'], max: 5, ilvl: 610, minScore: 0, age: 75, comment: '会讲迷宫和首领机制。' },
  { id: 23, category: 'dungeons', activity: 'academy', difficulty: 'normal', title: '普通学院，任务一起做', leader: 'panda', members: ['panda', 'bird'], max: 5, ilvl: 0, minScore: 0, age: 90, comment: '任务顺路，有需要的朋友一起。' },
  { id: 24, category: 'dungeons', activity: 'academy', difficulty: 'mythic', title: '史诗学院，熟悉路线', leader: 'rain', members: ['wind', 'rain', 'star'], max: 5, ilvl: 610, minScore: 0, age: 120, comment: '先确认机制，慢慢打完。' },
  { id: 25, category: 'dungeons', activity: 'threads', difficulty: 'heroic', title: '英雄千丝之城，轻松打完', leader: 'tea', members: ['tea', 'bird'], max: 5, ilvl: 600, minScore: 0, age: 60, comment: '一起完成周常。' },
  { id: 31, category: 'delves', activity: 'fungal', difficulty: 'delve', level: 8, title: '真菌之愚 8 层，打完拿箱子', leader: 'rain', members: ['rain', 'tea'], max: 3, ilvl: 620, minScore: 0, age: 60, comment: '一起完成，不赶时间。' },
  { id: 32, category: 'delves', activity: 'waterworks', difficulty: 'delve', level: 8, title: '水能堡，周常同行', leader: 'bird', members: ['wind', 'bird'], max: 3, ilvl: 620, minScore: 0, age: 130, comment: '有钥匙，互相照应。' },
  { id: 41, category: 'pvp', activity: 'arena2', difficulty: 'all', title: '2v2 练习配合，来治疗', leader: 'moon', members: ['moon'], max: 2, ilvl: 630, minScore: 0, age: 50, comment: '以练习为主，能沟通就好。' },
  { id: 42, category: 'pvp', activity: 'battleground', difficulty: 'all', title: '评级战场，来会沟通的队友', leader: 'wind', members: ['wind', 'sugar', 'star', 'tea', 'bird'], max: 10, counts: [1, 1, 3], ilvl: 635, minScore: 0, age: 90, comment: '组满后确认职责与目标。' },
  { id: 51, category: 'quests', activity: 'worldquest', difficulty: 'all', title: '世界任务一起清，顺路同行', leader: 'panda', members: ['panda', 'tea'], max: 5, ilvl: 0, minScore: 0, age: 80, comment: '随做随走，轻松清任务。' },
  { id: 61, category: 'custom', activity: 'custom', difficulty: 'all', title: '旧副本幻化，休闲收集', leader: 'star', members: ['star', 'bird'], max: 5, ilvl: 0, minScore: 0, age: 100, comment: '一起刷外观，有想去的副本可以说。' }
];
groups.forEach(g => { if (!g.category) g.category = act(g.activity).kind === 'raid' ? 'season-raids' : 'season-dungeons'; });

const historyRuns = [
  { id: 'academy', activity: 'academy', level: 12, date: '26/10/15', duration: '28:16', ids: ['wind', 'sugar', 'star', 'bird', 'tea'] },
  { id: 'bracken', activity: 'bracken', level: 11, date: '26/10/14', duration: '31:42', ids: ['night', 'rain', 'tea', 'moon', 'bird'] }
];

// 等待申请阶段使用的申请池（每次“来一组申请”按顺序取一批）。
const applicantPool = [
  { ids: ['dew'], comment: '随时可以出发，正常打完就好。' },
  { ids: ['frost', 'cloud'], comment: '两人一起，有合剂和食物。' },
  { ids: ['harbor'], comment: '熟悉路线，可以负责打断。' },
  { ids: ['leaf', 'ember', 'plum'], comment: '三人小团，愿意听指挥。' },
  { ids: ['panda'], comment: '机制还在练，会提前说明。' },
  { ids: ['stone'], comment: '稳定输出，能打完整场。' },
  { ids: ['light'], comment: '需要的话可以转治疗。' },
  { ids: ['cedar'], comment: '周常打完就走。' }
];

/* ---------------------------------------------------------------- 状态与工具 */

const defaultSettings = {relations:true,noteMarks:true,rememberFilters:true,defaultSort:'newest',defaultNote:'neutral',reminders:'all',history:true,density:'comfortable',motion:false,tooltipDelay:180,raidMembers:'shift'};
const blankForm = () => ({ category: 'season-raids', activity: 'palace', difficulty: 'heroic', title: '', description: '', ilvl: 635, score: 0, playstyle: '老手带队', isPrivate: false, crossFaction: true, autoAccept: false });

let state = {};
let applicantSeq = 100;
function resetState() {
  state = {
    page: 'find', lastMain: 'find',
    // 寻求组队
    category: 'season-dungeons', expansion: 'all', activity: 'all', difficulty: 'keystone',
    query: '', mode: 'results', sort: 'newest', filters: {}, savedFilters: {}, filtersExpanded: false,
    selected: null, personFilter: null, searching: false,
    apps: { 2: 'applied', 4: 'invited' },
    // 创建组队
    form: blankForm(), editingProject: false, pickerOpen: false, pickerQuery: '', pickerCategory: null,
    // 发布后
    listing: null, listingDraft: null, applicants: [], selectedApplicant: null, appRole: '', appSort: 'newest', pendingRound: null, editingListing: false,
    partyRoster: ['wind', 'sugar'],
    // 笔记 / 设置
    notes: structuredClone(initialNotes), noteQuery: '', noteTab: 'all', editNote: null, noteDraft: null,
    settings: { ...defaultSettings }, settingsSection: 'browse',
    sim: true
  };
  state.deadlines = { 2: Date.now() + 300000 };
  state.autoTitle = true;
}
resetState();

const $page = $('#page');
const ownPartyIds = () => state.partyRoster.slice();
const partySizeLabel = () => ownPartyIds().length;
const listName = () => partySizeLabel() > 5 ? '当前团队' : '当前队伍';
const roleCount = ids => ['TANK', 'HEALER', 'DAMAGER'].map(r => ids.filter(id => person(id)?.role === r).length);
const latest = ids => Math.max(...ids.map(id => person(id).score));
const lowest = (ids, key) => Math.min(...ids.map(id => person(id)[key]));

function classIcon(m, withRole = true, extra = '') {
  if (!m) return `<span class="class-icon empty">${icon('plus')}</span>`;
  return `<span class="class-icon ${extra}" style="--class:${colorOf(m)}">${classInfo[m.class]?.[0] || '?'}${withRole ? roleIcon(m.role) : ''}</span>`;
}
const roleIcon = role => `<span class="role-icon" title="${roleNames[role]}" aria-label="${roleNames[role]}">${icon(roleIcons[role])}</span>`;
function activityArt(a, level, large = false) {
  if (!a) return '';
  return `<span class="activity-icon${large ? ' large' : ''}" style="--art:${a.color}">${a.art ? `<img class="art" src="assets/${a.art}" alt="" loading="lazy">` : icon(kindIcon(a))}${level ? `<span class="key-level">+${level}</span>` : ''}</span>`;
}
const roster = (ids, max = 5) => ids.length > max
  ? `<div class="composition">${['TANK', 'HEALER', 'DAMAGER'].map((r, i) => `<span>${roleIcon(r)}<b>${roleCount(ids)[i]}</b></span>`).join('')}</div>`
  : `<div class="roster-strip">${Array.from({ length: max }, (_, i) => classIcon(ids[i] ? person(ids[i]) : null)).join('')}</div>`;
const noteOf = id => state.notes.find(n => n.id === id);
const noted = id => !!noteOf(id);
function noteBadge(id, compact = true) {
  const n = noteOf(id);
  if (!n || !state.settings.noteMarks) return '';
  return `<span class="person-tag note-${n.type}">${icon(noteTypes[n.type].icon)}${compact ? '' : noteTypes[n.type].label}</span>`;
}
function personRelations(id) {
  if (!state.settings.relations) return '';
  return (isFriend(id) ? `<span class="person-tag friend">${icon('friend')}好友</span>` : '') + (isGuild(id) ? `<span class="person-tag guild">${icon('guild')}同公会</span>` : '');
}
function groupSignals(ids) {
  const chips = [];
  if (state.settings.relations) {
    const f = ids.filter(isFriend).length, g = ids.filter(isGuild).length;
    if (f) chips.push(`<span class="friend">${icon('friend')}好友 ${f}</span>`);
    if (g) chips.push(`<span class="guild">${icon('guild')}公会 ${g}</span>`);
  }
  if (state.settings.noteMarks) {
    for (const [type, info] of Object.entries(noteTypes)) {
      const c = ids.filter(id => noteOf(id)?.type === type).length;
      if (c) chips.push(`<span class="note-${type}">${icon(info.icon)}${info.label} ${c}</span>`);
    }
  }
  return chips.length ? `<div class="group-signals">${chips.join('')}</div>` : '';
}
const ageText = min => min < 1 ? '刚刚' : min < 60 ? `${min} 分钟前` : `${Math.floor(min / 60)} 小时前`;
const appStatusName = s => ({ applied: '待处理', invited: '已邀请', declined: '已拒绝' }[s] || '');
const browseStatusName = s => ({ invited: '收到邀请', accepted: '已接受', cancelled: '已取消', declined: '已拒绝', timedout: '申请已过期' }[s] || '');
const countdown = id => {
  const sec = Math.max(0, Math.ceil((state.deadlines[id] - Date.now()) / 1000));
  return `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`;
};
const activeApplication = id => ['applied', 'invited'].includes(state.apps[id]);
const statusCell = (s, fallback, id) => s === 'applied'
  ? `<span class="status applied num" data-countdown="${id}">${countdown(id)}</span>`
  : `<span class="status ${esc(s || '')}">${esc(browseStatusName(s) || fallback)}</span>`;

let toastTimer, searchTimer, applicationTimer, tipTimer, tipOwner, pendingTipOwner, tipPoint, shiftDown = false, simTimer, simIndex = 0;
function toast(msg) { clearTimeout(toastTimer); const t = $('#toast'); t.textContent = msg; t.classList.add('visible'); toastTimer = setTimeout(() => t.classList.remove('visible'), 3200); }
function options(entries, selected) { return entries.map(([v, l]) => `<option value="${esc(v)}" ${String(v) === String(selected) ? 'selected' : ''}>${esc(l)}</option>`).join(''); }

function refreshCountdowns() {
  clearTimeout(applicationTimer);
  let pending = false, expired = false;
  for (const [id, s] of Object.entries(state.apps)) if (s === 'applied') {
    if (Date.now() >= (state.deadlines[id] || 0)) { state.apps[id] = 'timedout'; delete state.deadlines[id]; expired = true; }
    else pending = true;
  }
  $$('[data-countdown]').forEach(el => { el.textContent = countdown(el.dataset.countdown); });
  if (expired && state.page === 'find') renderResults();
  if (pending) applicationTimer = setTimeout(refreshCountdowns, 1000);
}

/* ---------------------------------------------------------------- 导航与外壳 */

function nav() {
  const entries = [['find', 'search', '寻求组队'], ['create', 'plus', '创建组队'], ['notes', 'book', '荔枝笔记']];
  $('#main-nav').innerHTML = entries.map(([key, glyph, label]) =>
    `<button class="nav-button ${state.page === key ? 'active' : ''}" data-page="${key}" aria-current="${state.page === key ? 'page' : 'false'}">${icon(glyph)}${label}</button>`).join('');
  $('.settings-button').classList.toggle('active', state.page === 'settings');
}
function navigate(page) {
  if (page !== 'settings') state.lastMain = page;
  state.page = page;
  hideTip(); closeModal();
  renderPage(true);
}
function renderPage(animate = false) {
  hideTip();
  nav();
  document.body.classList.toggle('reduce-motion', state.settings.motion);
  document.body.classList.toggle('density-compact', state.settings.density === 'compact');
  $page.classList.remove('enter');
  $page.innerHTML = ({ find: renderFind, create: renderCreate, notes: renderNotes, settings: renderSettings }[state.page])();
  if (state.page === 'find') renderResults();
  if (state.page === 'create' && state.listing) renderApplicants();
  if (animate && !state.settings.motion) { void $page.offsetWidth; $page.classList.add('enter'); }
}
function rerender(part) {
  const scrollTop = $('.form-scroll')?.scrollTop || 0;
  renderPage(part === 'animate');
  const box = $('.form-scroll');
  if (box) box.scrollTop = scrollTop;
}

/* ================================================================
   寻求组队
   ================================================================ */

const sortOptions = v => options([['newest', '最新'], ['rating', '队长评分'], ['ilvl', '要求装等'], ['members', '队伍人数']], v);
const usesKeyFilters = () => categoryOf(state.category).kind === 'dungeon'
  && difficulties(state.category, state.activity, state.expansion).some(([id]) => id === 'keystone')
  && ['all', 'keystone'].includes(state.difficulty);
const filterKeys = () => ['rating', 'ilvl', 'members', ...(usesKeyFilters() ? ['min', 'max', 'role'] : [])];
const filterCount = () => filterKeys().filter(k => state.filters[k]).length;

function renderSideRail() {
  return `<aside class="side" aria-label="活动分类">
    <p class="side-title">活动</p>
    <div class="side-scroll">${categories.map((c, i) =>
      `${i === 2 ? '<p class="side-section">更多活动</p>' : ''}
       <button class="side-item ${state.category === c.id ? 'active' : ''}" data-category="${c.id}" aria-pressed="${state.category === c.id}">${icon(c.icon)}<span>${c.name}</span></button>`).join('')}</div>
  </aside>`;
}
function renderCategoryHeader() {
  const c = categoryOf(state.category);
  const expansions = c.expansion ? expansionOptions(c.id) : [];
  const activityEntries = categoryActivities(c.id, state.expansion).map(a => [a.id, a.name]);
  const choices = difficulties(c.id, state.activity, state.expansion);
  return `<div class="context-row">
    ${expansions.length ? `<select id="expansion-filter" aria-label="资料片">${options([['all', '全部资料片'], ...expansions.map(e => [e, e])], state.expansion)}</select>` : ''}
    <div class="context-select">${state.activity === 'all' ? icon(c.icon) : activityArt(act(state.activity))}
      <select id="activity-filter" aria-label="副本或活动">${options([['all', c.kind === 'raid' ? '全部团本' : c.kind === 'dungeon' ? '全部地下城' : '全部活动'], ...activityEntries], state.activity)}</select>
    </div>
    ${choices.length === 1 ? `<span class="difficulty-fixed">${choices[0][1]}</span>` : `<div class="difficulty-switch" role="group" aria-label="难度">${[['all', '全部'], ...choices].map(([k, l]) => `<button data-difficulty="${k}" class="${state.difficulty === k ? 'active' : ''}" aria-pressed="${state.difficulty === k}">${l}</button>`).join('')}</div>`}
  </div>`;
}
const numberFilter = (key, label) => `<label class="number-filter"><span>${label}</span><input type="number" min="0" data-filter="${key}" aria-label="${label}" value="${state.filters[key] || ''}"></label>`;
function renderFind() {
  const c = categoryOf(state.category), keys = usesKeyFilters();
  return `<div class="layout-split">${renderSideRail()}
    <div class="find-main">
      <div class="page-head"><div><h1>${c.name}</h1><p class="sub">选择活动与难度后浏览当前队伍；选中一行查看详情与申请操作。</p></div></div>
      ${renderCategoryHeader()}
      <form class="search-bar ${state.searching ? 'searching' : ''}" id="search-form">
        <div class="search-field">${icon('search')}<input id="group-query" placeholder="队伍名称、说明或队长" aria-label="搜索队伍" value="${esc(state.query)}"></div>
        <button class="button primary" ${state.searching ? 'disabled' : ''}>${icon('refresh')}${state.searching ? '搜索中' : '刷新'}</button>
        <button type="button" class="filter-toggle ${state.filtersExpanded ? 'expanded' : ''}" data-action="toggle-filters" aria-expanded="${state.filtersExpanded}" aria-controls="search-filters" aria-label="${state.filtersExpanded ? '收起' : '展开'}筛选条件">${icon('chevron')}<span class="filter-count" ${filterCount() ? '' : 'hidden'}>${filterCount()}</span></button>
      </form>
      <div class="filter-drawer ${state.filtersExpanded ? 'open' : ''}" id="search-filters" ${state.filtersExpanded ? '' : 'inert'}>
        <div class="filter-inner">
          ${numberFilter('rating', '评分 ≥')}${numberFilter('ilvl', '装等 ≥')}${numberFilter('members', '人数 ≤')}
          ${keys ? numberFilter('min', '层数 ≥') + numberFilter('max', '层数 ≤') + `<select id="role-filter" aria-label="队伍缺少职责">${options([['', '不限职责'], ['TANK', '缺坦克'], ['HEALER', '缺治疗'], ['DAMAGER', '缺输出']], state.filters.role || '')}</select>` : ''}
          <button type="button" class="reset-filters" data-action="clear-filters">清空条件</button>
        </div>
      </div>
      <div class="list-toolbar">
        <div class="list-tabs">
          <button data-mode="results" class="${state.mode === 'results' ? 'active' : ''}">队伍<span class="count" id="result-count"></span></button>
          <button data-mode="applications" class="${state.mode === 'applications' ? 'active' : ''}">我的申请<span class="count">${groups.filter(g => activeApplication(g.id)).length}</span></button>
        </div>
        <div class="list-tools">
          <select id="social-filter" aria-label="关系与笔记筛选">${options([['', '全部关系'], ['friend', '好友在队'], ['guild', '同公会成员'], ['noted', '含笔记记录'], ['positive', '含推荐玩家'], ['caution', '含拉黑记录']], state.filters.social || '')}</select>
          <select id="sort-results" aria-label="队伍排序">${sortOptions(state.sort)}</select>
        </div>
      </div>
      <div class="table-head list-head"><span>队伍 / 成员标记</span><span>队伍构成</span><span class="num">队长评分</span><span class="num">要求装等</span><span class="num">人数</span><span class="num">状态</span></div>
      <div class="group-list" id="group-list"></div>
      <div id="selected-group"></div>
    </div>
  </div>`;
}
function groupInCategory(g) {
  const c = categoryOf(state.category);
  if (c.season) return act(g.activity).season && act(g.activity).kind === c.kind;
  if (['dungeons', 'raids', 'delves'].includes(c.id)) return act(g.activity).kind === c.kind;
  return g.category === c.id;
}
function filteredGroups() {
  let list = groups.filter(g => state.mode === 'applications'
    ? activeApplication(g.id)
    : groupInCategory(g) && (state.activity === 'all' || g.activity === state.activity)
      && (state.expansion === 'all' || act(g.activity).expansion === state.expansion)
      && (state.difficulty === 'all' || g.difficulty === state.difficulty));
  if (state.mode === 'results') list = list.filter(g => {
    const f = state.filters, m = person(g.leader), q = state.query.trim();
    if (state.personFilter) { if (!g.members.includes(state.personFilter)) return false; }
    else if (q && !`${g.title}${g.comment}${m.name}`.includes(q)) return false;
    if (f.rating && m.score < f.rating) return false;
    if (f.ilvl && g.ilvl < f.ilvl) return false;
    if (f.members && (g.members.length) > f.members) return false;
    if (usesKeyFilters()) {
      if ((f.min || f.max) && g.difficulty !== 'keystone') return false;
      if (f.min && (g.level || 0) < f.min) return false;
      if (f.max && (g.level || 0) > f.max) return false;
      if (f.role) {
        const idx = ['TANK', 'HEALER', 'DAMAGER'].indexOf(f.role);
        if (roleCount(g.members)[idx] >= (idx === 2 ? 3 : 1)) return false;
      }
    }
    if (f.social === 'friend' && !g.members.some(isFriend)) return false;
    if (f.social === 'guild' && !g.members.some(isGuild)) return false;
    if (f.social === 'noted' && !g.members.some(noted)) return false;
    if (['positive', 'caution'].includes(f.social) && !g.members.some(id => noteOf(id)?.type === f.social)) return false;
    return true;
  });
  const size = g => g.members.length;
  return list.sort((a, b) => state.sort === 'rating' ? person(b.leader).score - person(a.leader).score
    : state.sort === 'ilvl' ? b.ilvl - a.ilvl
      : state.sort === 'members' ? size(b) - size(a)
        : a.age - b.age);
}
function renderResults() {
  if (state.page !== 'find') return;
  hideTip();
  const list = filteredGroups();
  if (!list.some(g => g.id === state.selected)) state.selected = null;
  const count = $('#result-count');
  if (count) count.textContent = state.mode === 'applications' ? groups.filter(groupInCategory).length : list.length;
  $('#group-list').innerHTML = list.length ? list.map(groupRow).join('') : `<div class="empty-state">${icon('search')}<h2>${state.mode === 'applications' ? '暂无待处理的申请' : '没有符合条件的队伍'}</h2><p>${state.mode === 'applications' ? '在队伍列表中选择合适的队伍并提交申请。' : '可以切换副本或难度，也可以放宽筛选条件。'}</p><button class="button primary" data-action="${state.mode === 'applications' ? 'back-results' : 'clear-filters'}">${state.mode === 'applications' ? '浏览队伍' : '清空条件'}</button></div>`;
  $('#selected-group').innerHTML = state.selected ? groupDetail(groups.find(g => g.id === state.selected)) : '';
  const tabs = $$('.list-tabs .count');
  if (tabs[1]) tabs[1].textContent = groups.filter(g => activeApplication(g.id)).length;
  const fc = $('.filter-count');
  if (fc) { fc.textContent = filterCount(); fc.hidden = !filterCount(); }
}
function groupRow(g) {
  const m = person(g.leader), a = act(g.activity), s = state.apps[g.id], raid = a.kind === 'raid';
  return `<button class="group-row row ${state.selected === g.id ? 'selected' : ''}" data-group="${g.id}" data-tip-group="${g.id}">
    <span class="group-name-cell">${activityArt(a, g.level, true)}
      <span class="group-copy">
        <span class="title truncate">${noteBadge(m.id)}${esc(g.title)}</span>
        <small class="truncate">${raid ? `已击败 ${g.progress} · ` : ''}${a.name} · ${difficultyNames[g.difficulty] || ''} · ${m.name}</small>
        ${groupSignals(g.members)}
      </span>
    </span>
    <span>${roster(g.members, g.max || 5)}</span>
    <span class="number">${m.score}</span>
    <span class="number">${g.ilvl || '不限'}</span>
    <span class="number">${g.members.length}/${g.max || 5}</span>
    <span class="status-cell">${statusCell(s, ageText(g.age), g.id)}</span>
  </button>`;
}
function groupDetail(g) {
  const m = person(g.leader), s = state.apps[g.id], a = act(g.activity);
  const actions = s === 'invited'
    ? `<button class="button primary" data-action="accept-invite" data-id="${g.id}">接受邀请</button><button class="button secondary" data-action="decline-invite" data-id="${g.id}">婉拒邀请</button>`
    : s === 'applied'
      ? `<span class="status applied">等待队长处理</span><button class="button secondary" data-action="cancel-application" data-id="${g.id}">取消申请</button>`
      : `<button class="button primary" data-action="apply" data-id="${g.id}">申请加入</button>`;
  return `<section class="group-detail">
    <div>
      <h2 class="truncate">${esc(g.title)}</h2>
      <p class="leader-line">队长：<span style="color:${colorOf(m)}">${m.name}</span>${personRelations(m.id)}${noteBadge(m.id)}<span class="dim">${ageText(g.age)}发布</span></p>
      <p class="description">${esc(g.comment)}</p>
      <div class="detail-facts">
        <span>要求装等<b>${g.ilvl || '不限'}</b></span>
        <span>${scoreRequirement(g.activity, g.difficulty) || '队伍评分'}<b>${g.minScore || '不限'}</b></span>
        <span>${g.level ? '钥石层数' : '队伍人数'}<b>${g.level ? '+' + g.level : g.members.length + '/' + (g.max || 5)}</b></span>
        <span>${a.kind === 'raid' ? '首领进度' : '队长评分'}<b>${a.kind === 'raid' ? g.progress : m.score}</b></span>
      </div>
    </div>
    <div class="detail-actions">
      ${actions}
      <button class="button quiet" data-action="group-notes" data-id="${g.id}">${icon('book')}队伍中的笔记</button>
      <button class="button quiet" data-note-person="${m.id}">${icon(noted(m.id) ? 'book' : 'plus')}${noted(m.id) ? '查看队长笔记' : '记到荔枝笔记'}</button>
      <p class="hint">悬停队伍行可查看成员与说明</p>
    </div>
  </section>`;
}

/* ================================================================
   创建组队（填写 → 实时预览 → 发布 → 等待申请）
   ================================================================ */

const formActivity = () => act(state.form.activity);
function suggestedTitle() {
  const a = formActivity();
  if (!a) return '';
  const d = difficultyNames[state.form.difficulty];
  const prefix = state.form.difficulty === 'keystone' ? '' : (d && d !== '全部难度' ? d : '');
  return `${prefix}${a.name}`;
}
function syncTitle(force = false) {
  if (force || state.autoTitle) state.form.title = suggestedTitle();
}
function renderCreate() {
  return state.listing ? renderManage() : renderCompose();
}
function renderCompose() {
  const editing = state.editingProject;
  return `<div class="create-layout">
    <div class="create-main">
      <div class="page-head">
        <div><h1>${editing ? '修改组队' : '创建组队'}</h1>
          <p class="sub">选择活动与难度后填写招募条件；右侧随时预览别人看到的队伍行。</p></div>
      </div>
      <form id="listing-form" class="form-body">
        <div class="form-scroll">${formSections()}</div>
        <div class="form-actions">
          <div class="left">${editing ? `<span>发布时间与已有申请者保留。</span>` : `<span>发布后进入等待申请，可随时编辑或结束招募。</span>`}
            <span class="switch-preview"><span class="switch ${state.form.crossFaction ? 'on' : ''}"></span>跨阵营 ${state.form.crossFaction ? '开启' : '关闭'}</span>
          </div>
          <div class="right">
            ${editing ? `<button type="button" class="button secondary" data-action="cancel-edit-listing">取消</button>` : ''}
            <button class="button primary large" type="submit">${editing ? '更新组队' : '发布组队'}</button>
          </div>
        </div>
      </form>
    </div>
    <aside class="preview-side">${previewCard()}${partyPreviewCard()}</aside>
  </div>`;
}
function formSections() {
  const f = state.form, c = categoryOf(f.category), a = formActivity();
  const scoreLabel = scoreRequirement(f.activity, f.difficulty);
  const choices = difficulties(f.category, f.activity);
  return `
  <section class="form-section">
    <h3>活动与难度</h3>
    <div class="activity-context">
      <div class="picker ${state.pickerOpen ? 'open' : ''}" id="activity-picker">
        <button type="button" class="picker-trigger" data-action="toggle-picker" aria-expanded="${state.pickerOpen}">
          ${activityArt(a)}<span class="label truncate"><b>${esc(a.name)}</b><small>${a.expansion || categoryOf(creationCategory(a)).name}</small></span>${icon('chevron', 'chev')}
        </button>
        ${state.pickerOpen ? pickerPanel() : ''}
      </div>
      ${choices.length > 1 ? `<div class="difficulty-switch" role="group" aria-label="难度">${choices.map(([k, l]) => `<button type="button" data-form-difficulty="${k}" class="${f.difficulty === k ? 'active' : ''}" aria-pressed="${f.difficulty === k}">${l}</button>`).join('')}</div>` : `<span class="difficulty-fixed">${choices[0]?.[1] || categoryOf(f.category).name}</span>`}
    </div>
    <p class="field-note" style="margin-top:12px">${icon('caution')}${a.kind === 'raid' ? '团本按难度展示首领进度，不要求钥石评分。' : scoreLabel ? '该活动会要求' + scoreLabel + '。' : '该活动不显示评分要求。'}</p>
  </section>

  <section class="form-section">
    <h3>队伍名称与说明</h3>
    <div class="field-stack">
      <div class="form-field">
        <label for="listing-title">队伍名称</label>
        <div class="title-row">
          <input id="listing-title" name="title" required maxlength="100" placeholder="${esc(suggestedTitle())}" value="${esc(f.title)}">
          <button type="button" class="button secondary" data-action="suggest-title" title="按活动与难度重新生成名称">${icon('refresh')}用活动名称</button>
        </div>
        <span class="field-note">${state.autoTitle ? '跟随活动与难度自动更新，手动编辑后保留你的输入。' : '已保留手动输入；点左侧按钮可恢复自动名称。'}</span>
      </div>
      <div class="form-field">
        <label for="listing-description">说明</label>
        <textarea id="listing-description" name="description" maxlength="500" placeholder="开打前确认分工、语音要求、节奏安排等（选填）">${esc(f.description)}</textarea>
      </div>
    </div>
  </section>

  <section class="form-section">
    <h3>招募要求</h3>
    <div class="requirement-grid ${scoreLabel ? '' : 'no-score'}">
      <div class="form-field"><label for="listing-ilvl">${c.kind === 'pvp' ? '最低 PvP 装等' : '最低装等'}</label><input id="listing-ilvl" name="ilvl" type="number" min="0" value="${f.ilvl}"></div>
      ${scoreLabel ? `<div class="form-field"><label for="listing-score">${scoreLabel}</label><input id="listing-score" name="score" type="number" min="0" value="${f.score}"></div>` : ''}
      <div class="form-field"><label for="listing-style">玩法风格</label><select id="listing-style" name="playstyle">${options(playstyles.map(x => [x, x]), f.playstyle)}</select></div>
    </div>
    <div class="switch-grid">
      ${[['isPrivate', '私人队伍', '只对受邀成员可见'], ['crossFaction', '跨阵营', '允许对立阵营玩家加入'], ['autoAccept', '自动接受', '满足条件的申请直接组成队伍']]
      .map(([k, label]) => `<button type="button" class="switch-line" data-form-switch="${k}" role="switch" aria-checked="${f[k]}" aria-label="${label}"><span class="switch ${f[k] ? 'on' : ''}"></span>${label}</button>`).join('')}
    </div>
  </section>`;
}
function pickerPanel() {
  const q = state.pickerQuery.trim().toLowerCase();
  const cid = state.pickerCategory || state.form.category;
  const c = categoryOf(cid);
  const searchList = q ? activities.filter(a => `${a.name}${a.expansion || ''}`.toLowerCase().includes(q)) : null;
  const list = searchList || categoryActivities(cid, 'all');
  const shown = list.slice(0, 40);
  return `<div class="picker-panel">
    <div class="search-field">${icon('search')}<input id="picker-query" placeholder="搜索全部活动" aria-label="搜索活动" value="${esc(state.pickerQuery)}"></div>
    ${q ? '' : `<div class="picker-tabs">${categories.map(x => `<button type="button" data-picker-category="${x.id}" class="${cid === x.id ? 'active' : ''}">${x.name}</button>`).join('')}</div>`}
    <div class="picker-list">${shown.length ? shown.map(a => `<button type="button" class="picker-item ${state.form.activity === a.id ? 'active' : ''}" data-form-activity="${a.id}">${icon(kindIcon(a))}<span class="truncate">${esc(a.name)}</span><small>${a.expansion || categoryOf(creationCategory(a)).name}</small></button>`).join('') : '<p class="field-note" style="padding:8px 10px">没有匹配的活动</p>'}</div>
    <div class="picker-foot"><span>${shown.length} 项，长列表可用滚轮浏览</span><span>选中后自动回到对应分类</span></div>
  </div>`;
}
function creationCategory(a) {
  return a.kind === 'dungeon' ? (a.season ? 'season-dungeons' : 'dungeons')
    : a.kind === 'raid' ? (a.season ? 'season-raids' : 'raids')
      : ({ delve: 'delves', pvp: 'pvp', quest: 'quests', custom: 'custom' }[a.kind]);
}
// 预览卡片：与队伍行同一阅读顺序（名称 → 活动/难度 → 要求 → 队内情况）。
function previewCard() {
  const f = state.form, a = formActivity(), label = scoreRequirement(f.activity, f.difficulty);
  const flags = [f.isPrivate && '私人队伍', f.crossFaction && '跨阵营', f.autoAccept && '自动接受'].filter(Boolean);
  return `<section class="preview-card" id="preview-summary">
    <h3 class="preview-label">别人看到的队伍行</h3>
    <div class="preview-title ${f.title.trim() ? '' : 'placeholder'}">${esc(f.title.trim() || suggestedTitle() || '队伍名称')}</div>
    <div class="preview-meta">${a.name} · ${difficultyNames[f.difficulty]} · ${esc(f.playstyle)}${f.description.trim() ? `<br>${esc(f.description.trim().slice(0, 80))}${f.description.trim().length > 80 ? '…' : ''}` : ''}</div>
    <div class="preview-facts">
      <span>最低装等<b>${f.ilvl || '不限'}</b></span>
      <span>${label || '评分要求'}<b>${label ? (f.score || '不限') : '不限'}</b></span>
      <span>队伍上限<b>${a.kind === 'raid' ? 20 : 5} 人</b></span>
      <span>还需补位<b>${Math.max(0, (a.kind === 'raid' ? 20 : 5) - partySizeLabel())} 人</b></span>
    </div>
    <div class="preview-flags">${flags.length ? flags.map(x => `<span>${icon(x === '私人队伍' ? 'book' : x === '跨阵营' ? 'flag' : 'plus')}${x}</span>`).join('') : '<span>未设置额外选项</span>'}</div>
  </section>`;
}
function partyPreviewCard() {
  const ids = ownPartyIds();
  return `<section class="preview-party">
    <div class="party-head"><h3>${listName()} <b>${ids.length} 人</b></h3><button type="button" class="text-action" data-action="view-own-party">查看名单${icon('chevron')}</button></div>
    <div class="composition-row">${roster(ids, ids.length > 5 ? ids.length : 5)}</div>
    <div class="party-list">${ids.map(id => { const m = person(id); return `<button type="button" class="member" data-note-person="${id}">${classIcon(m)}<span class="copy"><b style="color:${colorOf(m)}">${m.name}${id === ids[0] ? '<span class="dim"> · 队长</span>' : ''}</b><small>${m.realm} · ${roleNames[m.role]} ${m.spec} · ${m.ilvl}</small></span></button>`; }).join('')}</div>
    <div class="party-summary">${groupSignals(ids) || '<span class="dim">队内暂无好友或笔记标记</span>'}</div>
  </section>`;
}

/* ---------- 发布后：等待申请 ---------- */
function renderManage() {
  const l = state.listing, a = act(l.activity);
  const rounds = state.applicants.filter(x => x.round);
  return `<div class="create-layout managing">
    <div class="create-main">
      <div class="page-head">
        <div><h1 class="truncate">${esc(l.title)}</h1>
          <p class="sub">${a.name} · ${difficultyNames[l.difficulty]} · 要求装等 ${l.ilvl || '不限'}${scoreRequirement(l.activity, l.difficulty) ? ` · ${scoreRequirement(l.activity, l.difficulty)} ${l.score || '不限'}` : ''} · ${esc(l.playstyle)}</p></div>
        <div class="head-tools">
          <span class="status-pill">正在招募</span>
          <button class="button secondary" data-action="edit-listing">${icon('pen')}编辑组队</button>
          <button class="button secondary" data-action="end-listing">结束招募</button>
        </div>
      </div>
      ${state.editingListing ? editDrawer() : ''}
      <div id="listing-flow">${flowCard()}</div>
      <div class="manage-head">
        <h2>申请者 <small>${state.applicants.filter(x => x.status === 'applied').length} 组待处理 · 共 ${state.applicants.length} 组</small></h2>
        <div class="applicant-tools">
          <div class="role-filters">${[['', '全部'], ['TANK', '坦克'], ['HEALER', '治疗'], ['DAMAGER', '输出']].map(([r, label]) => `<button data-app-role="${r}" class="${state.appRole === r ? 'active' : ''}">${r ? roleIcon(r) : ''}${label}</button>`).join('')}</div>
          <select id="sort-applicants" aria-label="申请者排序">${options([['newest', '最新申请'], ['score', '评分'], ['ilvl', '装等']], state.appSort)}</select>
        </div>
      </div>
      <div class="applicant-head list-head"><span>申请者 / 成员标记</span><span>同行成员</span><span class="num">最低装等</span><span class="num">最低评分</span><span class="num">状态</span></div>
      <div class="applicant-list" id="applicant-list"></div>
    </div>
    <aside class="preview-side">
      <section class="preview-party">
        <div class="party-head"><h3>已确认成员 <b>${ownPartyIds().length} 人</b></h3><button type="button" class="text-action" data-action="view-own-party">查看名单${icon('chevron')}</button></div>
        <div class="composition-row">${roster(ownPartyIds(), 30)}</div>
        <div class="party-list">${ownPartyIds().map(ownMemberRow).join('')}</div>
        <button class="button" data-action="invite-all-pending">邀请全部待处理</button>
      </section>
      ${selectedApplicantCard()}
    </aside>
  </div>`;
}
function ownMemberRow(id) {
  const m = person(id);
  return `<button type="button" class="member" data-note-person="${id}">${classIcon(m)}<span class="copy"><b style="color:${colorOf(m)}">${m.name}</b><small>${m.realm} · ${m.spec} · ${m.ilvl}</small></span></button>`;
}
function flowCard() {
  const batch = state.pendingRound;
  const pending = state.applicants.filter(x => x.status === 'applied').length;
  const invited = state.applicants.filter(x => x.status === 'invited').length;
  const target = act(state.listing.activity).kind === 'raid' ? 20 : 5;
  const steps = [
    ['发布组队', '已完成', true],
    [batch ? `收到 ${batch.count} 组申请` : '等待申请到达', pending ? `${pending} 组待处理` : '新申请会出现在下方列表', !!batch],
    ['邀请成员', invited ? `已发出 ${invited} 组邀请` : '未发出邀请', !!invited],
    ['组队完成', `${ownPartyIds().length}/${target} 人已确认`, ownPartyIds().length >= target]
  ];
  const alertBar = batch ? `<div class="round-alert">
      <div><h3>新的申请到达 · ${batch.count} 组</h3><p class="field-note">${esc(batch.text)}</p></div>
      <button class="button quiet" data-action="dismiss-rounds">知道了</button>
    </div>` : '';
  return `${alertBar}<div class="flow">${steps.map(([label, detail, done]) => `<span class="flow-step ${done ? 'done' : 'now'}">${label} · ${detail}</span>`).join('')}</div>`;
}
function renderApplicants() {
  if (state.page !== 'create' || !state.listing) return;
  let list = state.applicants.filter(x => !state.appRole || x.ids.some(id => person(id).role === state.appRole));
  if (state.appSort !== 'newest') {
    const key = state.appSort === 'score' ? 'score' : 'ilvl';
    list = [...list].sort((a, b) => lowest(b.ids, key) - lowest(a.ids, key));
  }
  const box = $('#applicant-list');
  if (box) box.innerHTML = list.length ? list.map(applicantRow).join('') : `<div class="empty-state">${icon('search')}<h2>没有该职责的申请</h2><p>切换到“全部”继续比较其他队友，或稍等新的申请。</p></div>`;
  const flow = $('#listing-flow');
  if (flow) flow.innerHTML = flowCard();
  const side = $('.preview-side .preview-party .party-list');
  if (side) side.innerHTML = ownPartyIds().map(ownMemberRow).join('');
  const aside = $('.preview-side');
  if (aside) {
    const existing = $('#applicant-detail');
    if (existing) existing.outerHTML = selectedApplicantCard();
    else if (state.selectedApplicant) aside.insertAdjacentHTML('beforeend', selectedApplicantCard());
  }
}
function applicantRow(t) {
  const m = person(t.ids[0]);
  return `<button class="applicant-row row ${state.selectedApplicant === t.id ? 'selected' : ''} ${t.fresh ? 'new' : ''}" data-applicant="${t.id}" data-tip-applicant="${t.id}">
    <span class="applicant-name">${classIcon(m, false)}
      <span class="copy"><p style="color:${colorOf(m)}">${m.name}${t.ids.length > 1 ? ` <em>+${t.ids.length - 1}</em>` : ''}${noteBadge(m.id)}</p>
      <small class="truncate">${esc(t.comment)}</small>${groupSignals(t.ids)}</span>
    </span>
    <span>${roster(t.ids)}</span>
    <span class="number">${lowest(t.ids, 'ilvl')}</span>
    <span class="number">${lowest(t.ids, 'score')}</span>
    <span class="status-badge ${t.status}">${appStatusName(t.status)}</span>
  </button>`;
}
function selectedApplicantCard() {
  const t = state.applicants.find(x => x.id === state.selectedApplicant);
  if (!t) return '';
  const open = t.status === 'applied';
  const recommended = t.ids.some(id => noteOf(id)?.type === 'positive');
  const blocked = t.ids.some(id => noteOf(id)?.type === 'caution');
  return `<section class="preview-party" id="applicant-detail">
    <div class="party-head"><h3>申请详情 <b>${t.ids.length} 人</b></h3><button class="icon-button" data-action="close-applicant" aria-label="关闭申请详情">${icon('close')}</button></div>
    <p class="field-note">${esc(t.comment)}</p>
    ${recommended ? `<p class="field-note" style="color:var(--green)">${icon('heart')}组内有你的推荐玩家</p>` : ''}
    ${blocked ? `<p class="field-note" style="color:var(--gold)">${icon('caution')}组内有拉黑记录，邀请前请确认</p>` : ''}
    <div class="party-list">${t.ids.map(id => { const m = person(id); return `<button type="button" class="member" data-note-person="${id}" data-tip-member="${id}">${classIcon(m, false)}<span class="copy"><b style="color:${colorOf(m)}">${m.name}</b><small>${m.realm} · ${roleNames[m.role]} ${m.spec} · 装等 ${m.ilvl} · 评分 ${m.score}</small>${personRelations(id)}${noteBadge(id)}</span></button>`; }).join('')}</div>
    <div class="right" style="display:flex;gap:8px">
      <button class="button primary" data-action="invite-applicant" ${open ? '' : 'disabled'} style="flex:1">${t.status === 'invited' ? '已发出邀请' : t.ids.length > 1 ? '邀请整组' : '邀请加入'}</button>
      <button class="button secondary" data-action="decline-applicant" ${open ? '' : 'disabled'}>拒绝</button>
    </div>
    <p class="field-note">${t.status === 'invited' ? '等待对方接受邀请。接受后计入当前队伍人数。' : t.status === 'declined' ? '已拒绝这组申请。' : '邀请以整组为单位发出，不拆分同行成员。'}</p>
  </section>`;
}
function editDrawer() {
  const l = state.listingDraft;
  return `<div class="edit-drawer">
    <div class="fields">
      <div><label for="edit-title">队伍名称</label><input id="edit-title" value="${esc(l.title)}"></div>
      <div><label for="edit-description">说明</label><textarea id="edit-description">${esc(l.description)}</textarea></div>
      <div><label for="edit-ilvl">最低装等</label><input id="edit-ilvl" type="number" min="0" value="${l.ilvl}"></div>
      <div><label for="edit-score">${scoreRequirement(l.activity, l.difficulty) || '评分要求'}</label><input id="edit-score" type="number" min="0" value="${l.score}" ${scoreRequirement(l.activity, l.difficulty) ? '' : 'disabled'}></div>
    </div>
    <div class="edit-actions">
      <button class="button quiet" data-action="edit-listing-in-form">在表单中编辑</button>
      <button class="button secondary" data-action="cancel-edit-listing">取消</button>
      <button class="button primary" data-action="save-listing">更新组队</button>
    </div>
  </div>`;
}
function spawnRound(count = 1, text) {
  const batch = [];
  for (let i = 0; i < count; i++) {
    const seed = applicantPool[(simIndex++) % applicantPool.length];
    batch.push({ id: ++applicantSeq, ids: [...seed.ids], comment: seed.comment, status: 'applied', fresh: true, round: true });
  }
  state.applicants = [...batch, ...state.applicants];
  state.pendingRound = { count, text: text || `${batch.map(t => person(t.ids[0]).name + (t.ids.length > 1 ? ` 等 ${t.ids.length} 人` : '')).join('、')} 提交了申请。` };
  if (state.page === 'create' && state.listing) rerender();
  toast(`收到 ${count} 组新申请。`);
}
function scheduleSim() {
  clearInterval(simTimer);
  if (!state.sim) return;
  simTimer = setInterval(() => {
    if (state.page === 'create' && state.listing && !state.editingListing) {
      spawnRound(1 + Math.floor(Math.random() * 2));
    } else if (state.page === 'find') {
      // 浏览队列队时刷新队伍刷新时间，体现列表是活的。
      groups.forEach(g => g.age += 1);
      if (state.mode === 'results') renderResults();
    }
  }, 8000);
}
function openManage(listing) {
  state.listing = listing;
  state.applicants = [];
  state.selectedApplicant = null;
  state.editingListing = false;
  state.pendingRound = null;
  simIndex = 0;
  renderPage(true);
  spawnRound(2, '演示数据：两组申请已经到达，可以比较后邀请。');
}

/* ================================================================
   荔枝笔记
   ================================================================ */
function visibleNotes() {
  return state.notes.filter(n => (state.noteTab === 'all' || n.type === state.noteTab) && `${n.name}${n.realm}${n.reason}`.includes(state.noteQuery));
}
function renderNotes() {
  const history = state.noteTab === 'history';
  const tabs = [['all', '全部记录'], ['positive', '推荐'], ['neutral', '中性'], ['caution', '拉黑'], ['history', '历史队友']];
  return `<div class="layout-split">
    <aside class="side" aria-label="记录分类">
      <p class="side-title">记录</p>
      <div class="side-scroll">${tabs.map(([key, label]) => `<button class="side-item ${state.noteTab === key ? 'active' : ''}" data-note-tab="${key}" aria-pressed="${state.noteTab === key}">${icon(key === 'history' ? 'history' : key === 'all' ? 'book' : noteTypes[key].icon)}<span>${label}</span><small>${key === 'history' ? historyRuns.length : key === 'all' ? state.notes.length : state.notes.filter(n => n.type === key).length}</small></button>`).join('')}</div>
    </aside>
    <div class="notes-main">
      <div class="page-head">
        <div><h1>${history ? '历史队友' : '荔枝笔记'}</h1><p class="sub">${history ? '当前角色完成的大秘境会自动记录队友与层数。' : '记录玩家经历，再次组队时在队伍与申请者列表显示标记。'}</p></div>
        <span class="reminder-state">${icon('bell')}${{ all: '全部记录提醒', positive: '推荐玩家提醒', caution: '仅拉黑记录提醒', off: '重逢提醒已关闭' }[state.settings.reminders]}</span>
      </div>
      ${history ? renderHistory() : `
      <div class="notes-toolbar">
        <div class="search-field">${icon('search')}<input id="notes-query" placeholder="搜索玩家或理由" aria-label="搜索笔记" value="${esc(state.noteQuery)}"></div>
        <div class="tools"><button class="button secondary" data-action="import-notes">导入</button><button class="button secondary" data-action="export-notes">导出</button><button class="button primary" data-action="add-note">${icon('plus')}添加记录</button></div>
      </div>
      <div class="notes-workspace">
        <div class="notes-list-area">
          <div class="notes-head list-head"><span>记录</span><span>玩家</span><span>理由</span><span></span></div>
          <div class="note-list" id="notes-list">${notesRows()}</div>
          <div class="notes-count">${visibleNotes().length} 条记录</div>
        </div>
        ${state.editNote ? renderNoteDrawer() : ''}
      </div>`}
    </div>
  </div>`;
}
function notesRows() {
  const list = visibleNotes();
  return list.length ? list.map(noteRow).join('') : `<div class="empty-state">${icon('book')}<h2>这里还没有记录</h2><p>记录好队友后，再次遇到时会在这里与队伍列表中显示。</p><button class="button primary" data-action="add-note">${icon('plus')}添加记录</button></div>`;
}
function noteRow(n) {
  const info = noteTypes[n.type];
  return `<div class="note-row row ${state.editNote === n.id ? 'selected' : ''}">
    <button class="note-row-main" data-edit-note="${esc(n.id)}" data-tip-note="${esc(n.id)}" style="display:contents">
      <span class="kind note-${n.type}">${icon(info.icon)}${info.label}</span>
      <span class="player"><b>${esc(n.name)}</b><small>${esc(n.realm)} · ${esc(n.classSpec)}</small></span>
      <span class="reason">${esc(n.reason || '无理由')}<small>${n.date}</small></span>
    </button>
    <button class="text-action row-action" data-find-person="${esc(n.id)}" aria-label="查找${esc(n.name)}的队伍">${icon('search')}查找队伍</button>
  </div>`;
}
function renderNoteDrawer() {
  const adding = state.editNote === 'new';
  const n = adding ? state.noteDraft : noteOf(state.editNote);
  return `<aside class="drawer">
    <header><h2>${adding ? '添加记录' : '编辑记录'}</h2><button class="icon-button" data-action="close-note" aria-label="关闭编辑">${icon('close')}</button></header>
    <div class="block"><label for="note-identity">玩家</label>
      ${adding ? `<input id="note-identity" placeholder="名字-服务器" value="${esc(n.name)}${n.realm ? '-' + esc(n.realm) : ''}">` : `<span class="identity">${esc(n.name)}-${esc(n.realm)}</span>`}
      <p class="field-note" style="margin-top:7px">记录时：${esc(n.classSpec || '未知')}</p>
    </div>
    <div class="block"><label>这段组队经历</label>
      <div class="note-type-switch" role="group" aria-label="记录类型">${Object.entries(noteTypes).map(([type, t]) => `<button class="note-${type} ${n.type === type ? 'active' : ''}" data-note-type="${type}" aria-pressed="${n.type === type}">${icon(t.icon)}${t.label}</button>`).join('')}</div>
    </div>
    <div class="block" style="flex:1;display:flex;flex-direction:column;min-height:0"><label for="note-reason">记录理由</label><textarea id="note-reason" placeholder="写下当时发生的事">${esc(n.reason)}</textarea></div>
    <div class="drawer-actions">
      ${adding ? '' : '<button class="danger" data-action="delete-note">删除记录</button>'}
      <button class="button secondary" data-action="close-note">取消</button>
      <button class="button primary" data-action="save-note">保存</button>
    </div>
  </aside>`;
}
function renderHistory() {
  return `<div class="history-page">
    <div class="history-caption"><span>${historyRuns.length} 次记录</span><span>${state.settings.history ? '自动记录已开启' : '自动记录已关闭，已有历史保留'}</span></div>
    <div class="note-list">${historyRuns.map(run => `<button class="history-run row" data-action="history" data-run="${run.id}">
      <span class="history-activity">${activityArt(act(run.activity), run.level, true)}<span><b>${act(run.activity).name}</b><small>+${run.level} · 用时 ${run.duration}</small></span></span>
      <span class="roster-cell">${roster(run.ids)}${groupSignals(run.ids)}</span>
      <span class="date">${run.date}</span>${icon('chevron')}
    </button>`).join('')}</div>
  </div>`;
}
function openPersonNote(id) {
  state.page = 'notes'; state.lastMain = 'notes'; state.noteTab = 'all'; state.noteQuery = '';
  state.noteDraft = null;
  if (noteOf(id)) state.editNote = id;
  else {
    const m = person(id);
    state.editNote = 'new';
    state.noteDraft = { id, name: m.name, realm: m.realm, classSpec: `${classInfo[m.class]?.[0] || ''} · ${m.spec}`, reason: '', type: state.settings.defaultNote };
  }
  hideTip(); closeModal(); renderPage(true);
}
function saveNote() {
  const reason = $('#note-reason').value;
  const type = $('[data-note-type].active').dataset.noteType;
  if (state.editNote === 'new') {
    const raw = $('#note-identity').value.trim();
    const idx = raw.indexOf('-');
    if (idx < 1) { toast('按“名字-服务器”填写，便于区分同名玩家。'); $('#note-identity').focus(); return; }
    const name = raw.slice(0, idx), realm = raw.slice(idx + 1);
    const known = people.find(m => m.name === name && m.realm === realm);
    const existing = state.notes.find(n => n.name === name && n.realm === realm);
    const rec = { id: known?.id || `note-${Date.now()}`, name, realm, reason, type, classSpec: state.noteDraft?.classSpec || '未知', date: '26/10/16' };
    if (existing) Object.assign(existing, rec); else state.notes.unshift(rec);
    state.editNote = rec.id; state.noteDraft = null;
  } else Object.assign(noteOf(state.editNote), { reason, type });
  state.noteTab = 'all';
  renderPage();
  toast('荔枝组队提醒：记录已保存。');
}

/* ================================================================
   设置
   ================================================================ */
const settingSections = { browse: '队伍浏览', notes: '笔记与提醒', interface: '界面与提示' };
// 设置采用“标签列 / 值列 / 操作列”，与主 Lychee 设置页一致：不堆卡片、不加行间长横线。
const switchRow = (key, label, hint) => `<div class="setting-line">
  <p class="label">${label}</p>
  <p class="help">${hint}</p>
  <div class="control">
    <span class="state">${state.settings[key] ? '已开启' : '已关闭'}</span>
    <button class="switch-button" role="switch" aria-checked="${state.settings[key]}" aria-label="${label}" data-setting="${key}"><span class="switch ${state.settings[key] ? 'on' : ''}"></span></button>
  </div></div>`;
const selectRow = (key, label, hint, choices) => `<div class="setting-line">
  <p class="label">${label}</p>
  <p class="help">${hint}</p>
  <div class="control"><select data-setting-select="${key}" aria-label="${label}">${options(choices, state.settings[key])}</select></div></div>`;
function renderSettings() {
  let body = '';
  if (state.settingsSection === 'browse') body =
    selectRow('defaultSort', '默认排序', '切换到其他活动分类时采用的排序方式。', [['newest', '最新'], ['rating', '队长评分'], ['ilvl', '要求装等'], ['members', '队伍人数']])
    + switchRow('rememberFilters', '记住各分类的筛选', '切换活动后恢复该分类上次选择的副本、难度与条件。')
    + switchRow('relations', '好友与公会标记', '在队伍、申请者和成员提示中显示关系标记。')
    + switchRow('noteMarks', '荔枝笔记标记', '显示推荐、中性和拉黑记录，包含队伍全部成员。');
  if (state.settingsSection === 'notes') body =
    selectRow('defaultNote', '新记录的默认类型', '每次记录时仍可选择其他类型。', Object.entries(noteTypes).map(([id, t]) => [id, t.label]))
    + selectRow('reminders', '再次组队时提醒', '遇到已记录玩家时按选择的范围提醒。', [['all', '全部记录'], ['positive', '仅推荐'], ['caution', '仅拉黑'], ['off', '不提醒']])
    + switchRow('history', '记录大秘境历史队友', '完成后保留活动与成员，便于回顾和补充笔记。')
    + `<div class="setting-line"><p class="label">提醒预览</p><p class="help">按当前设置演示一次入队提醒的样子。</p><div class="control"><button class="button secondary" data-action="preview-reminder">${icon('bell')}演示提醒</button></div></div>`;
  if (state.settingsSection === 'interface') body =
    selectRow('density', '队伍列表密度', '标准保留更多留白；紧凑能同时浏览更多队伍。', [['comfortable', '标准'], ['compact', '紧凑']])
    + switchRow('motion', '减少动态效果', '关闭开窗位移、Logo 动作与局部过渡。')
    + selectRow('tooltipDelay', '悬停提示延迟', '快速掠过队伍时减少提示框出现。', [[0, '立即显示'], [180, '稍作停留'], [400, '停留更久']])
    + selectRow('raidMembers', '团本成员列表', '控制团本悬停提示中何时展开成员。', [['shift', '按住 Shift 展开'], ['always', '始终展开']]);
  return `<div class="layout-split">
    <aside class="side" aria-label="设置分类"><p class="side-title">设置</p><div class="side-scroll">${Object.entries(settingSections).map(([id, label]) => `<button class="side-item ${state.settingsSection === id ? 'active' : ''}" data-settings-section="${id}"><span>${label}</span></button>`).join('')}</div></aside>
    <div class="settings-main">
      <div class="page-head"><div><h1>${settingSections[state.settingsSection]}</h1><p class="sub">设置立即生效，只影响当前演示会话。</p></div><button class="button secondary" data-page="${state.lastMain}">${icon('arrow')}返回</button></div>
      <div class="settings-body">${body}</div>
    </div>
  </div>`;
}
function previewReminder() {
  const chosen = state.notes.filter(n => state.settings.reminders === 'all' || n.type === state.settings.reminders);
  openModal(`<section class="modal"><header><div><h2>荔枝组队提醒</h2><p class="sub">${state.settings.reminders === 'off' ? '已关闭重逢提醒，本次入队不会显示提示。' : '这几位已记录的玩家加入了队伍。'}</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header>
    <div>${state.settings.reminders === 'off' ? '' : chosen.map(n => `<div class="reminder-item note-${n.type}">${icon(noteTypes[n.type].icon)}<span class="copy"><b>${noteTypes[n.type].label} · ${n.name}-${n.realm}</b><p>${esc(n.reason)}</p></span></div>`).join('')}</div>
    <footer><button class="button primary" data-action="close-modal">知道了</button></footer></section>`);
}

/* ================================================================
   提示框（悬停）
   ================================================================ */
function tipMemberRow(id, leader) {
  const m = person(id);
  return `<div class="tip-member">${classIcon(m, false)}<span class="copy"><b style="color:${colorOf(m)}">${m.name}<em>-${m.realm}</em>${id === leader ? '<span class="leader">队长</span>' : ''}</b><small>${m.spec}${state.settings.relations && (isFriend(id) || isGuild(id)) ? ' · ' + [isFriend(id) ? '好友' : '', isGuild(id) ? '同公会' : ''].filter(Boolean).join(' · ') : ''}</small></span><span class="trailing">${roleIcon(m.role)}${noteBadge(id)}</span></div>`;
}
function tipNoteBlock(id, force = false) {
  const n = noteOf(id);
  if (!n || (!force && !state.settings.noteMarks)) return '';
  return `<div class="tip-note note-${n.type}"><b>${noteTypes[n.type].label} · 荔枝组队提醒</b><p>${esc(n.reason || '无理由')}</p><small>${esc(n.classSpec)} · 记录于 ${n.date}</small></div>`;
}
function tipNotesList(ids) {
  const list = state.settings.noteMarks ? ids.map(noteOf).filter(Boolean) : [];
  if (!list.length) return '';
  return `<div class="tip-notes-list"><p class="tip-section">队伍中的荔枝笔记 · ${list.length}</p>${list.map(n => `<div class="item"><span class="note-${n.type}">${icon(noteTypes[n.type].icon)}${n.name}</span><p>${esc(n.reason || '无理由')}</p></div>`).join('')}</div>`;
}
function queueTip(owner, event) {
  if (tipOwner === owner || pendingTipOwner === owner) return;
  hideTip(); pendingTipOwner = owner;
  tipPoint = event ? { x: event.clientX, y: event.clientY } : null;
  tipTimer = setTimeout(() => { pendingTipOwner = null; showTip(owner); }, Number(state.settings.tooltipDelay));
}
function showTip(owner) {
  if (!owner.isConnected || !$('#modal').hidden) return;
  let html = '', expanded = false, width = 410;
  if (owner.dataset.tipGroup) {
    const g = groups.find(x => x.id === Number(owner.dataset.tipGroup));
    const m = person(g.leader), a = act(g.activity), raid = a.kind === 'raid';
    expanded = raid && (shiftDown || state.settings.raidMembers === 'always');
    if (expanded) width = 656;
    html = `<div class="tip-heading">${activityArt(a, g.level)}<div><h3>${esc(g.title)}</h3><p class="tip-line">${a.name} · ${difficultyNames[g.difficulty]} · ${ageText(g.age)}发布</p></div></div>
      <div class="tip-rows"><span>队长评分<b>${m.score}</b></span><span>要求装等<b>${g.ilvl || '不限'}</b></span><span>最低评分<b>${g.minScore || '不限'}</b></span><span>人数<b>${g.members.length}/${g.max || 5}</b></span></div>
      ${expanded
        ? `<p class="tip-section">队伍成员 · ${g.members.length} 人</p>${g.members.map(id => tipMemberRow(id, g.leader)).join('')}`
        : `<p class="tip-comment">${esc(g.comment)}</p>${raid ? `<div class="tip-rows"><span>首领进度<b>${g.progress}</b></span></div>${groupSignals(g.members)}` : g.members.slice(0, 5).map(id => tipMemberRow(id, g.leader)).join('')}${tipNotesList(g.members)}`}
      <p class="tip-foot">${raid ? (expanded ? (state.settings.raidMembers === 'always' ? '已按设置始终展开成员。' : '松开 Shift 返回概要。') : `按住 <kbd>Shift</kbd> 查看 ${g.members.length} 名成员。`) : '单击选中后查看申请操作。'}</p>`;
  } else if (owner.dataset.tipApplicant) {
    const t = state.applicants.find(x => x.id === Number(owner.dataset.tipApplicant));
    if (!t) return;
    html = `<div class="tip-heading"><div><h3>${t.ids.length > 1 ? `同行申请 · ${t.ids.length} 人` : '单人申请'}</h3><p class="tip-line">${esc(t.comment)}</p></div></div>
      ${t.ids.map(id => tipMemberRow(id)).join('')}
      <div class="tip-rows"><span>整组最低装等<b>${lowest(t.ids, 'ilvl')}</b></span><span>整组最低评分<b>${lowest(t.ids, 'score')}</b></span></div>
      ${t.ids.map(id => tipNoteBlock(id)).join('')}`;
  } else if (owner.dataset.tipMember) {
    const m = person(owner.dataset.tipMember);
    html = `<div class="tip-heading"><div><h3 style="color:${colorOf(m)}">${m.name}<span class="dim">-${m.realm}</span></h3><p class="tip-line">${roleNames[m.role]} · ${m.spec}</p></div></div>
      <div class="tip-rows"><span>装等<b>${m.ilvl}</b></span><span>评分<b>${m.score}</b></span></div>
      ${tipNoteBlock(m.id)}<p class="tip-foot">单击查看或添加荔枝笔记。</p>`;
  } else if (owner.dataset.tipNote) {
    const n = noteOf(owner.dataset.tipNote);
    if (!n) return;
    html = `<div class="tip-heading"><div><h3>${esc(n.name)}<span class="dim">-${esc(n.realm)}</span></h3><p class="tip-line">${esc(n.classSpec)} · ${n.date}</p></div></div>${tipNoteBlock(n.id, true)}<p class="tip-foot">单击编辑这条记录。</p>`;
  }
  if (!html) return;
  tipOwner = owner;
  const tip = $('#tooltip');
  tip.classList.toggle('expanded', expanded);
  tip.innerHTML = html;
  tip.hidden = false;
  const frame = $('#fit-frame').getBoundingClientRect(), scale = frame.width / 1160;
  const box = owner.getBoundingClientRect();
  const px = ((tipPoint?.x || box.right) - frame.left) / scale;
  const py = ((tipPoint?.y || box.top) - frame.top) / scale;
  let x = px + 18;
  if (x + width > 1148) x = px - width - 18;
  x = Math.max(12, Math.min(1148 - width, x));
  const h = tip.offsetHeight;
  tip.style.left = x + 'px';
  tip.style.top = Math.max(10, Math.min(752 - h, py + 8)) + 'px';
}
function hideTip() { clearTimeout(tipTimer); pendingTipOwner = null; tipOwner = null; tipPoint = null; $('#tooltip').hidden = true; }

/* ---------------------------------------------------------------- 模态 */
function openModal(html, focusSelector = 'input,textarea,button') {
  hideTip();
  const layer = $('#modal');
  layer.innerHTML = html;
  layer.hidden = false;
  layer.querySelector(focusSelector)?.focus();
}
function closeModal() { const l = $('#modal'); l.hidden = true; l.innerHTML = ''; }
function applyModal(id) {
  const g = groups.find(x => x.id === id);
  openModal(`<form class="modal" id="apply-form" data-group-id="${id}">
    <header><div><h2>申请加入</h2><p class="sub">${esc(g.title)}</p></div><button type="button" class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header>
    <label>你可以承担的职责</label>
    <div class="role-picker">${['TANK', 'HEALER', 'DAMAGER'].map(r => `<button type="button" class="modal-role ${r === person('wind').role ? 'active' : ''}" data-apply-role="${r}" aria-pressed="${r === person('wind').role}">${icon(roleIcons[r])}${roleNames[r]}</button>`).join('')}</div>
    <label for="application-note">给队长的备注</label>
    <textarea id="application-note" placeholder="简短说明经验或同行情况（选填）"></textarea>
    <p class="error" id="role-message" hidden></p>
    <footer><button class="button secondary" type="button" data-action="close-modal">取消</button><button class="button primary" type="submit">提交申请</button></footer>
  </form>`);
}
function transferModal(importing) {
  openModal(`<section class="modal">
    <header><div><h2>${importing ? '导入记录' : '导出记录'}</h2><p class="sub">${importing ? '粘贴 LN- 记录文本，按玩家身份合并。' : '导出完整名单，包括记录类型与理由。'}</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header>
    <label for="transfer-text">记录文本</label>
    <textarea id="transfer-text" style="height:180px" placeholder="粘贴 LN- 文本">${importing ? '' : 'LN-PROTOTYPE-DEMO · 荔枝笔记演示文本'}</textarea>
    <p class="field-note" style="margin-top:10px">演示只走流程，这里的文本不会写入游戏数据。</p>
    <footer><button class="button secondary" data-action="close-modal">关闭</button><button class="button primary" data-action="${importing ? 'demo-import' : 'select-export'}">${importing ? '导入记录' : '全选文本'}</button></footer>
  </section>`, 'textarea');
}
function ownPartyModal() {
  const ids = ownPartyIds();
  const ordered = ['TANK', 'HEALER', 'DAMAGER'].flatMap(r => ids.filter(id => person(id).role === r));
  openModal(`<section class="modal wide">
    <header><div><h2>${listName()} <span class="dim">${ids.length} 人</span></h2><p class="sub">发布与招募期间都以这份名单为准。</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header>
    <div class="overview">${roster(ids, 30)}${groupSignals(ids) || `<span class="dim">队内暂无好友或笔记标记</span>`}</div>
    <div class="member-grid">${ordered.map(id => { const m = person(id); return `<button class="member" data-note-person="${id}" data-tip-member="${id}">${classIcon(m, false)}<span class="copy"><b style="color:${colorOf(m)}">${m.name}</b><small>${m.realm} · ${roleNames[m.role]} ${m.spec}</small><span class="member-tags">${personRelations(id)}${noteBadge(id, false)}</span></span></button>`; }).join('')}</div>
    <footer><button class="button primary" data-action="close-modal">关闭</button></footer>
  </section>`, 'button');
}
function historyModal(id) {
  const run = historyRuns.find(r => r.id === id);
  openModal(`<section class="modal">
    <header><div><h2>历史队友</h2><p class="sub">${act(run.activity).name} · +${run.level} · ${run.date}</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header>
    <div class="member-grid" style="grid-template-columns:1fr 1fr">${run.ids.map(id => { const m = person(id); return `<button class="member" data-note-person="${id}">${classIcon(m, false)}<span class="copy"><b style="color:${colorOf(m)}">${m.name}<span class="dim">-${m.realm}</span></b><small>${m.spec} · 装等 ${m.ilvl}</small><span class="member-tags">${personRelations(id)}${noteBadge(id, false)}</span></span><span class="dim" style="font-size:12px">${noted(id) ? '查看笔记' : '记一笔'}</span></button>`; }).join('')}</div>
    <footer><button class="button primary" data-action="close-modal">关闭</button></footer>
  </section>`, 'button');
}
function groupNotesModal(id) {
  const g = groups.find(x => x.id === id);
  const known = g.members.filter(noted);
  openModal(`<section class="modal">
    <header><div><h2>队伍中的荔枝笔记</h2><p class="sub">${esc(g.title)}</p></div><button class="icon-button" data-action="close-modal" aria-label="关闭">${icon('close')}</button></header>
    ${known.length ? known.map(id => { const n = noteOf(id); return `<button class="member" data-note-person="${id}" style="display:flex;gap:12px;align-items:flex-start;width:100%;text-align:left;padding:10px;border-radius:6px">${classIcon(person(id), false)}<span class="copy"><b class="note-${n.type}" style="color:${n.type === 'positive' ? 'var(--green)' : n.type === 'caution' ? 'var(--gold)' : 'var(--text)'}">${noteTypes[n.type].label} · ${n.name}-${n.realm}${id === g.leader ? ' · 队长' : ''}</b><p style="font-size:12px;color:var(--muted);line-height:1.65;margin-top:4px">${esc(n.reason)}</p></span></button>`; }).join('') : '<p class="dim">这支队伍暂无记录，可以先记录队长。</p>'}
    <footer><button class="button secondary" data-action="close-modal">关闭</button><button class="button primary" data-note-person="${g.leader}">${icon('book')}记录队长</button></footer>
  </section>`, 'button');
}

/* ================================================================
   事件处理
   ================================================================ */
function changeCategory(id) {
  if (state.settings.rememberFilters) state.savedFilters[state.category] = { filters: { ...state.filters }, sort: state.sort, activity: state.activity, difficulty: state.difficulty, expansion: state.expansion };
  state.category = id;
  state.activity = 'all';
  state.difficulty = id === 'season-dungeons' ? 'keystone' : 'all';
  state.expansion = 'all';
  state.sort = state.settings.defaultSort;
  state.filters = {};
  state.query = ''; state.personFilter = null; state.selected = null; state.mode = 'results';
  if (state.settings.rememberFilters && state.savedFilters[id]) Object.assign(state, structuredClone(state.savedFilters[id]));
  renderPage(true);
}
function pickActivity(id) {
  const a = act(id);
  state.form.activity = id;
  state.form.category = creationCategory(a);
  state.pickerOpen = false;
  state.pickerQuery = '';
  const choices = difficulties(state.form.category, id);
  if (!choices.some(([k]) => k === state.form.difficulty)) state.form.difficulty = state.form.category === 'season-dungeons' ? 'keystone' : choices[0]?.[0] || 'all';
  syncTitle();
  renderPage();
}
function readForm() {
  const f = state.form;
  const t = $('#listing-title'), d = $('#listing-description'), i = $('#listing-ilvl'), s = $('#listing-score'), p = $('#listing-style');
  if (t) f.title = t.value;
  if (d) f.description = d.value;
  if (i) f.ilvl = Number(i.value) || 0;
  if (s) f.score = Number(s.value) || 0;
  if (p) f.playstyle = p.value;
}

document.addEventListener('click', event => {
  const b = event.target.closest('button');
  const insidePicker = event.target.closest('#activity-picker');
  if (!insidePicker && state.pickerOpen && !event.target.closest('#picker-query')) state.pickerOpen = false;
  if (!b || b.disabled) { if (state.pickerOpen) renderPage(); return; }
  if (b.dataset.page) { navigate(b.dataset.page); return; }
  if (b.dataset.category) { changeCategory(b.dataset.category); return; }
  if (b.dataset.difficulty) { state.difficulty = b.dataset.difficulty; state.selected = null; renderPage(); return; }
  if (b.dataset.mode) { state.mode = b.dataset.mode; state.selected = null; renderPage(); return; }
  if (b.dataset.group) { state.selected = Number(b.dataset.group); renderResults(); return; }
  if (b.dataset.applicant) { state.selectedApplicant = Number(b.dataset.applicant); renderApplicants(); return; }
  if (b.hasAttribute('data-app-role')) { state.appRole = b.dataset.appRole; state.selectedApplicant = null; renderApplicants(); return; }
  if (b.dataset.noteTab) { state.noteTab = b.dataset.noteTab; state.editNote = null; state.noteQuery = ''; renderPage(); return; }
  if (b.dataset.editNote) { state.editNote = b.dataset.editNote; renderPage(); return; }
  if (b.dataset.notePerson) { openPersonNote(b.dataset.notePerson); return; }
  if (b.dataset.findPerson) { findPerson(b.dataset.findPerson); return; }
  if (b.dataset.noteType) {
    $$('[data-note-type]').forEach(el => { el.classList.toggle('active', el === b); el.setAttribute('aria-pressed', el === b); });
    return;
  }
  if (b.dataset.settingsSection) { state.settingsSection = b.dataset.settingsSection; renderPage(); return; }
  if (b.dataset.setting) { const k = b.dataset.setting; state.settings[k] = !state.settings[k]; renderPage(); return; }
  if (b.dataset.pickerCategory) { state.pickerCategory = b.dataset.pickerCategory; renderPage(); return; }
  if (b.dataset.formActivity) { readForm(); pickActivity(b.dataset.formActivity); return; }
  if (b.dataset.formDifficulty) { readForm(); state.form.difficulty = b.dataset.formDifficulty; syncTitle(); renderPage(); return; }
  if (b.dataset.formSwitch) {
    const k = b.dataset.formSwitch;
    state.form[k] = !state.form[k];
    b.classList.toggle('on', false);
    b.querySelector('.switch').classList.toggle('on', state.form[k]);
    b.setAttribute('aria-checked', state.form[k]);
    return;
  }
  if (b.dataset.applyRole) {
    $$('[data-apply-role]').forEach(el => { el.classList.toggle('active', el === b); el.setAttribute('aria-pressed', el === b); });
    return;
  }
  switch (b.dataset.action) {
    case 'toggle-filters': state.filtersExpanded = !state.filtersExpanded; renderPage(); break;
    case 'clear-filters': state.filters = {}; state.query = ''; state.personFilter = null; state.selected = null; renderPage(); break;
    case 'back-results': state.mode = 'results'; renderPage(); break;
    case 'apply': applyModal(Number(b.dataset.id)); break;
    case 'cancel-application':
      state.apps[b.dataset.id] = 'cancelled'; delete state.deadlines[b.dataset.id];
      renderResults(); refreshCountdowns(); toast('已取消申请。'); break;
    case 'accept-invite': state.apps[b.dataset.id] = 'accepted'; renderResults(); toast('已接受邀请。'); break;
    case 'decline-invite': state.apps[b.dataset.id] = 'declined'; renderResults(); toast('已婉拒邀请。'); break;
    case 'group-notes': groupNotesModal(Number(b.dataset.id)); break;
    case 'toggle-picker': readForm(); state.pickerOpen = !state.pickerOpen; state.pickerCategory = state.form.category; renderPage(); if (state.pickerOpen) $('#picker-query')?.focus(); break;
    case 'suggest-title': readForm(); state.autoTitle = true; syncTitle(true); renderPage(); break;
    case 'view-own-party': ownPartyModal(); break;
    case 'edit-listing':
      state.listingDraft = { ...state.listing };
      state.editingListing = true;
      renderPage();
      break;
    case 'cancel-edit-listing': state.editingListing = false; state.listingDraft = null; renderPage(); break;
    case 'edit-listing-in-form':
      state.form = { ...state.listing };
      state.editingProject = true;
      state.listing = null; state.applicants = []; state.selectedApplicant = null;
      state.editingListing = false; state.listingDraft = null; state.pendingRound = null;
      renderPage(true);
      toast('已回到表单，发布后会替换原招募。');
      break;
    case 'save-listing': {
      const l = state.listingDraft;
      l.title = $('#edit-title').value.trim() || l.title;
      l.description = $('#edit-description').value;
      l.ilvl = Number($('#edit-ilvl').value) || 0;
      const s = $('#edit-score');
      if (s && !s.disabled) l.score = Number(s.value) || 0;
      state.listing = { ...l };
      state.editingListing = false; state.listingDraft = null;
      renderPage(); toast('组队信息已更新。');
      break;
    }
    case 'end-listing': {
      const kept = ownPartyIds().length;
      state.listing = null; state.applicants = []; state.selectedApplicant = null;
      state.editingListing = false; state.editingProject = false;
      renderPage(true);
      toast(`招募已结束，${kept} 人队伍保留，回到创建组队。`);
      break;
    }
    case 'close-applicant': state.selectedApplicant = null; renderApplicants(); break;
    case 'invite-applicant': {
      const t = state.applicants.find(x => x.id === state.selectedApplicant);
      if (!t) break;
      t.status = 'invited';
      t.ids.forEach(id => { if (!state.partyRoster.includes(id)) state.partyRoster.push(id); });
      renderPage(); toast(t.ids.length > 1 ? '已邀请整组，等待对方接受。' : '已发出邀请，等待对方接受。');
      break;
    }
    case 'decline-applicant': {
      const t = state.applicants.find(x => x.id === state.selectedApplicant);
      if (!t) break;
      t.status = 'declined';
      renderApplicants(); toast('已拒绝这组申请。');
      break;
    }
    case 'invite-all-pending': {
      const pending = state.applicants.filter(x => x.status === 'applied');
      if (!pending.length) { toast('当前没有待处理的申请。'); break; }
      pending.forEach(t => { t.status = 'invited'; t.ids.forEach(id => { if (!state.partyRoster.includes(id)) state.partyRoster.push(id); }); });
      renderPage(); toast(`已向 ${pending.length} 组申请发出邀请。`);
      break;
    }
    case 'dismiss-rounds': state.applicants.forEach(x => delete x.round); state.pendingRound = null; renderApplicants(); break;
    case 'add-note':
      state.noteTab = 'all'; state.editNote = 'new';
      state.noteDraft = { name: '', realm: '', reason: '', classSpec: '未知', type: state.settings.defaultNote };
      renderPage(); $('#note-identity')?.focus(); break;
    case 'close-note': state.editNote = null; state.noteDraft = null; renderPage(); break;
    case 'save-note': saveNote(); break;
    case 'delete-note': { const n = noteOf(state.editNote); state.notes = state.notes.filter(x => x.id !== state.editNote); state.editNote = null; renderPage(); toast(`荔枝组队提醒：已删除 ${n ? n.name : ''} 的记录。`); break; }
    case 'close-modal': closeModal(); break;
    case 'import-notes': transferModal(true); break;
    case 'export-notes': transferModal(false); break;
    case 'demo-import':
      if (!$('#transfer-text').value.trim()) { toast('先粘贴记录文本。'); break; }
      closeModal(); toast('已演示导入流程，演示文本未写入名单。'); break;
    case 'select-export': $('#transfer-text').select(); toast('已全选演示文本，可复制。'); break;
    case 'history': historyModal(b.dataset.run); break;
    case 'preview-reminder': previewReminder(); break;
    default: if (state.pickerOpen) renderPage();
  }
});

document.addEventListener('input', event => {
  const el = event.target;
  if (el.id === 'group-query') { state.query = el.value; state.personFilter = null; renderResults(); }
  else if (el.dataset.filter) { state.filters[el.dataset.filter] = Number(el.value) || 0; renderResults(); }
  else if (el.id === 'notes-query') { state.noteQuery = el.value; $('#notes-list').innerHTML = notesRows(); const c = $('.notes-count'); if (c) c.textContent = `${visibleNotes().length} 条记录`; }
  else if (el.id === 'picker-query') { state.pickerQuery = el.value; const list = $('.picker-list'); if (list) list.outerHTML = `<div class="picker-list">${pickerItems()}</div>`; }
  else if (el.id === 'listing-title' && state.page === 'create') { readForm(); state.autoTitle = !el.value.trim() ? true : false; const t = $('#preview-summary .preview-title'); if (t) { t.textContent = el.value.trim() || suggestedTitle(); t.classList.toggle('placeholder', !el.value.trim()); } }
  else if (el.id === 'listing-description') { readForm(); }
  else if (el.id === 'listing-ilvl') { readForm(); refreshPreviewFacts(); }
  else if (el.id === 'listing-score') { readForm(); refreshPreviewFacts(); }
});
function pickerItems() {
  const q = state.pickerQuery.trim().toLowerCase();
  const cid = state.pickerCategory || state.form.category;
  const searchList = q ? activities.filter(a => `${a.name}${a.expansion || ''}`.toLowerCase().includes(q)) : null;
  const shown = (searchList || categoryActivities(cid, 'all')).slice(0, 40);
  return shown.length ? shown.map(a => `<button type="button" class="picker-item ${state.form.activity === a.id ? 'active' : ''}" data-form-activity="${a.id}">${icon(kindIcon(a))}<span class="truncate">${esc(a.name)}</span><small>${a.expansion || categoryOf(creationCategory(a)).name}</small></button>`).join('') : '<p class="field-note" style="padding:8px 10px">没有匹配的活动</p>';
}
function refreshPreviewFacts() {
  const f = state.form, a = formActivity(), label = scoreRequirement(f.activity, f.difficulty);
  const facts = $$('#preview-summary .preview-facts b');
  if (facts.length < 4) return;
  facts[0].textContent = f.ilvl || '不限';
  facts[1].textContent = label ? (f.score || '不限') : '不限';
  const meta = $('#preview-summary .preview-meta');
  if (meta) meta.innerHTML = `${a.name} · ${difficultyNames[f.difficulty]} · ${esc(f.playstyle)}${f.description.trim() ? `<br>${esc(f.description.trim().slice(0, 80))}${f.description.trim().length > 80 ? '…' : ''}` : ''}`;
}

document.addEventListener('change', event => {
  const el = event.target;
  if (el.id === 'party-demo') { readForm(); state.partyRoster = el.value === 'solo' ? ['wind'] : el.value === 'raid' ? people.slice(0, 30).map(p => p.id) : ['wind', 'sugar']; if (state.page === 'create') renderPage(); }
  else if (el.id === 'sim-toggle') { state.sim = el.checked; scheduleSim(); if (state.settings) { } }
  else if (el.id === 'role-filter') { state.filters.role = el.value; renderResults(); }
  else if (el.id === 'social-filter') { state.filters.social = el.value; renderResults(); }
  else if (el.id === 'sort-results') { state.sort = el.value; renderResults(); }
  else if (el.id === 'sort-applicants') { state.appSort = el.value; renderApplicants(); }
  else if (el.id === 'activity-filter') { state.activity = el.value; if (!difficulties(state.category, state.activity, state.expansion).some(([k]) => k === state.difficulty)) state.difficulty = 'all'; state.selected = null; renderPage(); }
  else if (el.id === 'expansion-filter') { state.expansion = el.value; state.activity = 'all'; state.difficulty = 'all'; state.selected = null; renderPage(); }
  else if (el.dataset.settingSelect) { const k = el.dataset.settingSelect; state.settings[k] = k === 'tooltipDelay' ? Number(el.value) : el.value; if (k === 'defaultSort') state.sort = el.value; renderPage(); }
});

document.addEventListener('submit', event => {
  event.preventDefault();
  if (event.target.id === 'search-form') {
    if (state.searching) return;
    state.searching = true; renderPage();
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { state.searching = false; if (state.page === 'find') { renderPage(); toast(`已更新 ${filteredGroups().length} 支队伍。`); } }, 650);
  } else if (event.target.id === 'listing-form') {
    readForm();
    if (!state.form.title.trim()) { toast('先填写队伍名称。'); $('#listing-title')?.focus(); return; }
    if (state.editingProject) {
      state.listing = { ...state.form };
      state.editingProject = false;
      renderPage(true);
      toast('组队信息已更新。');
      return;
    }
    const replaced = state.editingProject;
    const listing = { ...state.form };
    if (replaced) {
      state.listing = listing;
      state.editingProject = false;
      renderPage(true);
      toast('组队已更新，等待申请继续。');
      return;
    }
    openManage(listing);
    toast('组队已发布，进入等待申请。');
  } else if (event.target.id === 'apply-form') {
    if (!$('.modal-role.active')) { const m = $('#role-message'); m.hidden = false; m.textContent = '至少选择一个职责。'; return; }
    const id = event.target.dataset.groupId;
    state.apps[id] = 'applied';
    state.deadlines[id] = Date.now() + 300000;
    closeModal(); renderResults(); refreshCountdowns();
    toast('申请已提交，等待队长处理。');
  }
});

const tipSelector = '[data-tip-group],[data-tip-applicant],[data-tip-member],[data-tip-note]';
document.addEventListener('mouseover', event => {
  const owner = event.target.closest(tipSelector);
  if (owner && $('#modal').hidden) queueTip(owner, event);
  else if (!owner) hideTip();
});
document.addEventListener('mouseout', event => {
  const owner = tipOwner || pendingTipOwner;
  if (owner && !owner.contains(event.relatedTarget)) hideTip();
});
document.addEventListener('focusin', event => { const o = event.target.closest(tipSelector); if (o && $('#modal').hidden) queueTip(o); });
document.addEventListener('focusout', hideTip);
document.addEventListener('wheel', hideTip, { passive: true });
document.addEventListener('keydown', event => {
  if (event.key === 'Shift' && !shiftDown) { shiftDown = true; if (tipOwner?.dataset.tipGroup) showTip(tipOwner); }
  if (event.key === 'Escape') { if (!$('#modal').hidden) closeModal(); else if (state.pickerOpen) { state.pickerOpen = false; renderPage(); } else presence(false); }
});
document.addEventListener('keyup', event => { if (event.key === 'Shift') { shiftDown = false; if (tipOwner?.dataset.tipGroup) showTip(tipOwner); } });
addEventListener('blur', () => { shiftDown = false; hideTip(); });
$('#modal').addEventListener('click', event => { if (event.target === $('#modal')) closeModal(); });

/* ---------------------------------------------------------------- 品牌动作与开窗轨迹 */
const logo = $('#logo');
function brandMotion() { if (state.settings.motion || logo.classList.contains('logo-motion')) return; logo.classList.add('logo-motion'); }
logo.addEventListener('animationend', () => logo.classList.remove('logo-motion'));
$('#brand').addEventListener('mouseenter', brandMotion);
$('#brand').addEventListener('click', brandMotion);

let phase = 0, target = 1, presenceFrame, lastTime, afterPresence;
function drawPresence() {
  const q = phase * (2 - phase), u = Math.min(1, phase * 4.2);
  $('#window').style.transform = `translateY(${64 * (1 - q)}px)`;
  $('#window').style.opacity = u * (2 - u);
}
function presence(open, done) {
  target = open ? 1 : 0; afterPresence = done; hideTip(); closeModal();
  if (open) { $('#window').style.visibility = 'visible'; $('#open-window').hidden = true; brandMotion(); }
  if (state.settings.motion) { phase = target; drawPresence(); finishPresence(); return; }
  if (!presenceFrame) { lastTime = performance.now(); presenceFrame = requestAnimationFrame(tickPresence); }
}
function tickPresence(now) {
  const dt = (now - lastTime) / 420; lastTime = now;
  phase = target === 1 ? Math.min(1, phase + dt) : Math.max(0, phase - dt);
  drawPresence();
  if (phase === target) { presenceFrame = null; finishPresence(); }
  else presenceFrame = requestAnimationFrame(tickPresence);
}
function finishPresence() {
  if (target === 0) { $('#window').style.visibility = 'hidden'; $('#open-window').hidden = false; logo.classList.remove('logo-motion'); }
  const cb = afterPresence; afterPresence = null; cb?.();
}
$('#close-window').onclick = () => presence(false);
$('#open-window').onclick = () => presence(true);
$('#replay').onclick = () => presence(false, () => presence(true));
$('#sim-now').onclick = () => { if (state.page === 'create' && state.listing) spawnRound(1 + Math.floor(Math.random() * 2)); else toast('先发布一支队伍，申请者会出现在这里。'); };
$('#reset').onclick = () => {
  clearTimeout(searchTimer); clearInterval(simTimer);
  resetState();
  $('#party-demo').value = 'party';
  renderPage(); refreshCountdowns(); presence(true); scheduleSim();
  toast('演示已重置。');
};

function fit() {
  const scale = Math.min(1, (innerWidth - 32) / 1160);
  $('#fit-frame').style.transform = `scale(${scale})`;
  $('.stage').style.height = (760 * scale + 40) + 'px';
  $('#fit-frame').style.marginBottom = -(760 * (1 - scale)) + 'px';
}
addEventListener('resize', () => { hideTip(); fit(); });

renderPage(); fit(); drawPresence(); presence(true); refreshCountdowns(); scheduleSim();
