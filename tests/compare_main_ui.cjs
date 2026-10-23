// Compare visible layout projections against the pinned main source.
// Usage: node tests/compare_main_ui.cjs [tests/preview-data.js]
// Baseline creation is deliberately separate from candidate verification:
// node tests/compare_main_ui.cjs --capture-main <main-preview.js>
const fs=require('fs'),path=require('path'),vm=require('vm'),crypto=require('crypto'),cp=require('child_process');
const ROOT=path.resolve(__dirname,'..');
const MAIN='5ce215182c15b59e44c573db9a1a6488536bb8bd';
const MANIFEST=path.join(__dirname,'results','main-ui-5ce2151.json');
const rendererPath=path.join(__dirname,'ui-preview.html');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const movedAssets=['role-tank','role-healer','role-dps','tank','healer','damage','leader','invite','friend','guild','pvp','delve','tower','mountain','flag','lychee-logo'];
const equalAssets=new Set();
for(const name of movedAssets){
 const original=cp.execFileSync('git',['show',MAIN+':addon/LycheeGroup/Libs/LycheeUI/Media/'+name+'.tga'],{cwd:ROOT,stdio:['ignore','pipe','pipe']});
 const current=fs.readFileSync(path.join(ROOT,'addon/LycheeGroup/Media',name+'.tga'));
 if(hash(original)===hash(current))equalAssets.add(name);
}
const html=fs.readFileSync(rendererPath,'utf8');
let renderer=html.split('<script>')[1].split('</script>')[0];
if(!renderer.includes('stage.append(el);'))throw new Error('Preview renderer projection hook is missing');
renderer=renderer.replace('stage.append(el);','el.source={kind:n.kind,texture:n.texture,atlas:n.atlas,color:n.color,fill:n.fill,vertex:n.kind==="Texture"?(n.vertex||[1,1,1,1]):n.vertex,coords:n.coords,text:n.text,font:n.font,spacing:n.spacing,justify:n.justify,wrap:n.wrap};stage.append(el);');
function element(){return {style:{},classList:{add(){},toggle(){}},children:[],textContent:'',replaceChildren(){this.children=[];},append(item){this.children.push(item);},insertBefore(){}};}
function normalized(value,css){
 if(typeof value==='number')return Math.round(value*1e6)/1e6;
 if(Array.isArray(value))return value.map(item=>normalized(item,css));
 if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(key=>[key,normalized(value[key],css||key==='style')]));
 if(typeof value==='string'){
  value=value.replace(/Interface\\AddOns\\LycheeGroup\\Libs\\LycheeUI\\Media\\([a-z-]+)\.tga/g,(file,name)=>equalAssets.has(name)?'Interface\\AddOns\\LycheeGroup\\Media\\'+name+'.tga':file);
  return css?value.replace(/-?\d+\.\d+(?=px|rad|\b)/g,n=>String(Math.round(Number(n)*1e6)/1e6)):value;
 }
 return value;
}
function project(file){
 const stage=element(),tabs=element();
 const drawing={font:'14px',measureText(text){const size=parseFloat(this.font);return {width:Array.from(text).reduce((width,char)=>width+(char.codePointAt(0)>127?1:.55)*size,0)};}};
 const sandbox={document:{getElementById:id=>id==='stage'?stage:tabs,createElement:tag=>tag==='canvas'?{getContext:()=>drawing}:element(),querySelectorAll:()=>[]},window:{}};
 vm.createContext(sandbox);vm.runInContext(fs.readFileSync(file,'utf8')+'\n'+renderer+'\nglobalThis.names=SHOTS.map(shot=>shot.name);',sandbox);
 const names=sandbox.names;
 if(new Set(names).size!==names.length)throw new Error('Duplicate scene names');
 return names.map((name,index)=>{
  vm.runInContext('render('+index+')',sandbox);
  const signatures=stage.children.filter(e=>Number(e.style.opacity)!==0&&!(e.source.kind==='FontString'&&!e.source.text)).map(e=>JSON.stringify(normalized({style:e.style,source:e.source}))).sort();
  return {name,visible:signatures.length,sha256:hash(JSON.stringify(signatures))};
  });
}
const capture=process.argv[2]==='--capture-main';
const input=path.resolve(ROOT,process.argv[capture?3:2]||'tests/preview-data.js');
if(capture){
 if(fs.existsSync(MANIFEST))throw new Error('Refusing to overwrite pinned main UI baseline');
 const captureInfo=JSON.parse(fs.readFileSync(input+'.meta.json','utf8'));
 if(captureInfo.commit!==MAIN||captureInfo.captureSha256!==hash(fs.readFileSync(input)))throw new Error('Invalid pinned-main capture provenance');
 const scenes=project(input);
 const sourceFiles=['tests/ui_preview.lua','tests/ui_fixture.lua','tests/ui_stubs.lua'].map(file=>({path:file,sha256:hash(cp.execFileSync('git',['show',MAIN+':'+file],{cwd:ROOT}))}));
 const result={schema:1,commit:MAIN,rendererSha256:hash(html),sourceFiles,substitute:captureInfo.substitute,driverAdaptations:captureInfo.driverAdaptations,normalization:['round numeric and CSS output to 1e-6; preserve literal text','normalize moved material paths only after byte equality verification'],scope:'Visible geometry, text, font, color, material and layout flags in 41 offline fixture scenes; excludes native rendering and hardware input.',scenes};
 fs.writeFileSync(MANIFEST,JSON.stringify(result,null,2)+'\n');
 console.log('Recorded '+scenes.length+' scenes from pinned main '+MAIN);
}else{
 const expected=JSON.parse(fs.readFileSync(MANIFEST,'utf8'));
 if(expected.commit!==MAIN)throw new Error('Unexpected baseline commit');
 if(expected.rendererSha256!==hash(html))throw new Error('Renderer changed; review comparison before updating its fixed source');
 if(expected.substitute.sha256!==hash(fs.readFileSync(path.join(ROOT,expected.substitute.path))))throw new Error('UI substitute changed; recapture main with the same substitute before comparing');
 const actual=project(input),byName=new Map(actual.map(scene=>[scene.name,scene]));
 let failed=0;
 for(const before of expected.scenes){
  const after=byName.get(before.name);byName.delete(before.name);
  if(!after||before.sha256!==after.sha256){failed++;console.log(JSON.stringify({scene:before.name,expected:before.visible,actual:after&&after.visible,status:after?'changed':'missing'}));}
 }
 for(const name of byName.keys()){failed++;console.log(JSON.stringify({scene:name,status:'extra'}));}
 console.log(JSON.stringify({baseline:MAIN,scenes:expected.scenes.length,equal:expected.scenes.length-failed,failed}));
 process.exitCode=failed?1:0;
}
