// Run the fixed main product under the same UI substitute as the candidate.
// Usage: node tests/capture_main_ui.cjs <clean checkout of pinned main> [output.js]
const fs=require('fs'),path=require('path'),cp=require('child_process'),crypto=require('crypto');
const ROOT=path.resolve(__dirname,'..');
const MAIN='5ce215182c15b59e44c573db9a1a6488536bb8bd';
if(!process.argv[2])throw new Error('Provide the clean checkout of pinned main');
const checkout=path.resolve(process.argv[2]);
const output=path.resolve(ROOT,process.argv[3]||'.lycheedev/equivalence/main-5ce2151-common-fixture.js');
const git=(...args)=>cp.execFileSync('git',args,{cwd:checkout,encoding:'utf8'}).trim();
if(git('rev-parse','HEAD')!==MAIN)throw new Error('Main checkout is not at the pinned commit');
if(git('status','--porcelain','--untracked-files=no'))throw new Error('Main checkout has tracked changes');
if(fs.existsSync(output)||fs.existsSync(output+'.meta.json'))throw new Error('Refusing to overwrite an existing main capture');
fs.mkdirSync(path.dirname(output),{recursive:true});
const stub=path.join(__dirname,'ui_stubs.lua');
const driver=output+'.driver.lua';
const luaString=value=>JSON.stringify(value.replace(/\\/g,'/'));
const harness=`local originalDofile=dofile
dofile=function(file)
 if file=="tests/ui_stubs.lua" then return originalDofile(${luaString(stub)}) end
 return originalDofile(file)
end
local input=assert(io.open("tests/ui_preview.lua","rb"))
local source=input:read("*a");input:close()
local n
source,n=source:gsub('local A,U,G,S=f%%.A,f%%.U,f%%.G,f%%.S','f.base.SetTime(os.time({year=2026,month=10,day=23,hour=12,min=0,sec=0}))\\nlocal A,U,G,S=f.A,f.U,f.G,f.S');assert(n==1)
source,n=source:gsub('io%%.open%%("tests/preview%%-data%%.js","wb"%%)','io.open('..${luaString(output)}..',"wb")')
assert(n==1,"preview output path changed")
source,n=source:gsub('rolePresenceChoices%%.TANK','presenceChoices.tankPresence');assert(n==1)
source,n=source:gsub('rolePresenceChoices%%.DAMAGER','presenceChoices.damagePresence');assert(n==1)
source,n=source:gsub('hideSameSpec:Fire%%("OnClick"%%)','identityChoice.buttons[3]:Fire("OnClick")');assert(n==1)
source,n=source:gsub('level=n%%.level,','level=type(n.level)=="number" and n.level or nil,');assert(n==1)
assert(loadstring(source,"@pinned-main-ui-preview"))()
`.replace(/%%/g,'%');
// output paths are data inside a Lua quoted string, not executable shell text.
const safeHarness=harness.replace("'io.open('.."+luaString(output)+"..',\"wb\")'","'io.open(\"'.."+luaString(output)+"..'\",\"wb\")'");
fs.writeFileSync(driver,safeHarness);
const result=cp.execFileSync(process.env.LUA||'lua',[driver],{cwd:checkout,encoding:'utf8',maxBuffer:1024*1024});
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
fs.writeFileSync(output+'.meta.json',JSON.stringify({schema:1,commit:MAIN,substitute:{path:'tests/ui_stubs.lua',sha256:hash(fs.readFileSync(stub))},driverSha256:hash(safeHarness),captureSha256:hash(fs.readFileSync(output)),driverAdaptations:['same current UI substitute for main and candidate','fix sample note dates to 2026-10-23','three obsolete filter controller names mapped to the same current main actions','serialize numeric frame level only']},null,2)+'\n');
console.log(result.trim());
console.log('Main capture saved without changing its checkout: '+output);
