// Read-only dependency and frozen-library checks. Run from any directory:
// node tests/check_architecture.cjs [path/to/LycheeUI/source]
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '..');
const embedded = path.join(root, 'addon/LycheeGroup/Libs/LycheeUI');
const lock = JSON.parse(fs.readFileSync(path.join(embedded, '.lock'), 'utf8'));
const failures = [];
let checks = 0;
function check(value, message) { checks++; if (!value) failures.push(message); }
function files(directory, prefix = '') {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const name = prefix + entry.name;
    return entry.isDirectory() ? files(path.join(directory, entry.name), name + '/') : [name];
  });
}
function digest(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }
check(lock.status === 'frozen' && Array.isArray(lock.runtimeFiles), 'embedded library must carry its frozen runtime inventory');
const expected = lock.runtimeFiles.map(entry => entry.path).sort();
check(JSON.stringify(files(embedded).filter(name => name !== '.lock').sort()) === JSON.stringify(expected), 'embedded runtime inventory differs from the frozen manifest');
for (const entry of lock.runtimeFiles) {
  const file = path.resolve(embedded, entry.path);
  check(file.startsWith(embedded + path.sep), 'runtime path leaves the embedded library: ' + entry.path);
  check(fs.existsSync(file) && digest(file) === entry.sha256, 'embedded file differs from the frozen digest: ' + entry.path);
}

// UI mechanisms may receive arbitrary data and callbacks. These product names,
// data fields, game services and events must remain in the consuming addon.
const business = /\b(?:LycheeGroup[A-Za-z0-9_]*|C_LFGList|C_MythicPlus|C_ChallengeMode|C_SpecializationInfo|C_PlayerInfo|C_PvP|C_FriendList|C_GuildInfo|C_BattleNet|UnitClass|UnitRace|UnitFactionGroup|UnitAffectingCombat|SetRaidSubgroup|SwapRaidSubgroup|GetRaidRosterInfo|GetSpecializationInfo|ActivityLabels|SeasonScores|PlayerLinks|RealmSlugs|RaidGroups|MatchesPartyFilters|ApplicantCard|RoleButton|Roster|SetRoleIcon|SetMemberIcon|SetActivityIcon|StyleMemberIcon|dungeonScore|assignedRole|leaderKey|creationPresets|LFG_[A-Z_]+|CHALLENGE_MODE_[A-Z_]+|GROUP_ROSTER_UPDATE|PLAYER_SPECIALIZATION_CHANGED)\b/;
function withoutLuaComments(source) {
  let output = '', index = 0;
  while (index < source.length) {
    const comment = source.startsWith('--', index);
    const long = source.slice(index + (comment ? 2 : 0)).match(/^\[(=*)\[/);
    if (comment || long) {
      let end;
      if (long) {
        const close = ']' + long[1] + ']';
        const found = source.indexOf(close, index + (comment ? 2 : 0) + long[0].length);
        end = found < 0 ? source.length : found + close.length;
      } else {
        end = source.indexOf('\n', index);
        if (end < 0) end = source.length;
      }
      const part = source.slice(index, end);
      output += comment ? part.replace(/[^\r\n]/g, ' ') : part;
      index = end;
    } else if (source[index] === '"' || source[index] === "'") {
      const start = index++, quote = source[start];
      while (index < source.length) {
        if (source[index] === '\\') index += 2;
        else if (source[index++] === quote) break;
      }
      output += source.slice(start, index);
    } else output += source[index++];
  }
  return output;
}
for (const name of expected.filter(name => name.endsWith('.lua'))) {
  const lines = withoutLuaComments(fs.readFileSync(path.join(embedded, name), 'utf8')).split(/\r?\n/);
  for (let index = 0; index < lines.length; index++) {
    const match = lines[index].match(business);
    check(!match, `${name}:${index + 1} contains product dependency ${match && match[0]}`);
  }
}
function fileKey(file) {
  const absolute = path.resolve(file);
  const real = fs.existsSync(absolute) ? fs.realpathSync(absolute) : absolute;
  return process.platform === 'win32' ? real.toLowerCase() : real;
}
function references(file, source) {
  if (path.extname(file).toLowerCase() === '.toc') {
    return source.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('#'));
  }
  return [...source.replace(/<!--[\s\S]*?-->/g, '').matchAll(/<(?:Script|Include)\b[^>]*?\bfile\s*=\s*(["'])(.*?)\1/gi)].map(match => match[2]);
}
function loadedFiles(entry, read = file => fs.readFileSync(file, 'utf8')) {
  const loaded = new Set();
  function visit(file) {
    const key = fileKey(file);
    if (loaded.has(key)) return;
    loaded.add(key);
    if (/\.(?:toc|xml)$/i.test(file)) {
      for (const reference of references(file, read(file))) {
        visit(path.resolve(path.dirname(file), reference.replace(/[\\/]/g, path.sep)));
      }
    }
  }
  visit(entry);
  return loaded;
}
const frozenPaths = new Set(expected.map(name => fileKey(path.join(embedded, name))));
for (const file of loadedFiles(path.join(embedded, 'embeds.xml'))) {
  check(frozenPaths.has(file), 'shared manifest loads an unfrozen source: ' + file);
}
const owners = {
  LycheeGroup: ['ActivityLabels.lua'],
  LycheeGroup_Group: ['SeasonScores.lua', 'RaidGroups.lua'],
  LycheeGroup_UI: ['PlayerLinks.lua', 'RealmSlugs.lua'],
};
for (const name of ['LycheeGroup', 'LycheeGroup_Group', 'LycheeGroup_Notes', 'LycheeGroup_UI']) {
  const toc = fs.readFileSync(path.join(root, 'addon', name, name + '.toc'), 'utf8');
  if (name !== 'LycheeGroup') check(/^## LoadOnDemand:\s*1\s*$/m.test(toc), name + ' must remain load-on-demand');
  const loaded = loadedFiles(path.join(root, 'addon', name, name + '.toc'));
  for (const file of loaded) check(fs.existsSync(file), name + ' loads a missing runtime file: ' + file);
  for (const [owner, names] of Object.entries(owners)) {
    for (const file of names) check(loaded.has(fileKey(path.join(root, 'addon', owner, file))) === (name === owner), `${file} must load only in ${owner}`);
  }
}

// Small in-memory regressions exercise the same scanners without altering files.
for (const name of ['LycheeGroupDB', 'LycheeGroupGroupDB', 'LycheeGroupPrefsDB', 'LycheeGroup_Notes', 'LycheeGroupFutureState', 'RaidGroups', 'SetRaidSubgroup', 'SwapRaidSubgroup', 'UnitAffectingCombat']) {
  check(business.test(withoutLuaComments('local value = _G.' + name)), 'namespace dependency must be detected: ' + name);
}
check(!business.test(withoutLuaComments('-- C_LFGList\n--[=[ LycheeGroupDB\nSeasonScores ]=]\nlocal value = 1')), 'Lua comments must not be classified as dependencies');
for (const code of [`local api = _G['C_LFGList']`, `local text = "--"; local api = C_MythicPlus`, `local text = [=[-- C_ChallengeMode]=]`]) {
  check(business.test(withoutLuaComments(code)), 'Lua strings must remain visible to dependency checks: ' + code);
}
const fixtureRoot = path.join(root, '.architecture-memory-fixture');
const fixtureTOC = path.join(fixtureRoot, 'Core', 'Core.toc');
const fixtureOwned = path.join(fixtureRoot, 'UI', 'PlayerLinks.lua');
const memory = new Map([
  [fileKey(fixtureTOC), '# ignored\n..\\UI\\nested.xml'],
  [fileKey(path.join(fixtureRoot, 'UI', 'nested.xml')), `<Ui><!-- <Script file="ignored.lua"/> --><Include file='sub/inner.xml'/></Ui>`],
  [fileKey(path.join(fixtureRoot, 'UI', 'sub', 'inner.xml')), `<Ui><Script file="../PlayerLinks.lua"/><Include file="../nested.xml"/></Ui>`],
]);
check(loadedFiles(fixtureTOC, file => memory.get(fileKey(file))).has(fileKey(fixtureOwned)), 'cross-package TOC/XML loads, mixed separators and include cycles must resolve to the owned file');
check(loadedFiles(fixtureTOC, () => '../UI/./PlayerLinks.lua').has(fileKey(fixtureOwned)), 'a direct cross-package TOC alias must resolve to the owned file');

// An explicit source directory also verifies both copies against the same lock;
// the ordinary check remains self-contained for clones without a sibling repo.
if (process.argv[2]) {
  const source = path.resolve(process.argv[2]);
  const sourceLock = JSON.parse(fs.readFileSync(path.join(source, '.lock'), 'utf8'));
  check(JSON.stringify(sourceLock) === JSON.stringify(lock), 'source and embedded freeze manifests differ');
  for (const entry of lock.runtimeFiles) {
    const file = path.resolve(source, entry.path);
    check(file.startsWith(source + path.sep) && fs.existsSync(file) && digest(file) === entry.sha256, 'source file differs from the frozen digest: ' + entry.path);
  }
}
for (const message of failures) console.error('[FAIL] ' + message);
console.log(`Architecture boundary: ${checks} checks, ${failures.length} failures; ${expected.length} frozen files`);
process.exitCode = failures.length ? 1 : 0;
