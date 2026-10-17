// Fluent System Icons, Microsoft, MIT. Kept locally for an offline prototype.
const fs=require('fs'),path=require('path');
const entries={
 search:['Search','search'],plus:['Add','add'],book:['Notebook','notebook'],
 mountain:['Door Arrow Right','door_arrow_right'],tower:['People Team','people_team'],
 delve:['Cube','cube'],pvp:['Trophy','trophy'],flag:['Flag','flag'],
 chevron:['Chevron Right','chevron_right'],close:['Dismiss','dismiss'],refresh:['Arrow Clockwise','arrow_clockwise'],
 heart:['Heart','heart'],caution:['Prohibited','prohibited'],friend:['Person','person'],
 guild:['People Community','people_community'],users:['People','people'],clock:['History','history'],
 settings:['Settings','settings'],check:['Checkmark','checkmark'],copy:['Copy','copy'],
 trash:['Delete','delete'],edit:['Edit','edit'],link:['Link','link'],arrow:['Arrow Left','arrow_left'],
 volume:['Speaker 2','speaker_2'],filter:['Filter','filter'],chevronDown:['Chevron Down','chevron_down'],
 bell:['Alert','alert']
};
(async()=>{
 const dir=path.join(__dirname,'assets','fluent');fs.mkdirSync(dir,{recursive:true});
 const icons={},results=await Promise.allSettled(Object.entries(entries).map(async([name,[folder,file]])=>{
  const url=`https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/${encodeURIComponent(folder)}/SVG/ic_fluent_${file}_20_regular.svg`;
  const filePath=path.join(dir,name+'.svg');
  let svg;
  if(fs.existsSync(filePath))svg=fs.readFileSync(filePath,'utf8');
  else {const response=await fetch(url);if(!response.ok)throw Error(name+': '+response.status);svg=await response.text();if(!svg.includes('<svg'))throw Error(name+': invalid SVG');fs.writeFileSync(filePath,svg);}
  icons[name]=svg.replace(/<svg[^>]*>/,'').replace('</svg>','').replace(/fill="[^"]*"/g,'fill="currentColor"');
  return name;
 }));
 for(const result of results)console.log(result.status==='fulfilled'?'OK '+result.value:result.reason.message);
 if(results.some(result=>result.status==='rejected'))throw Error('Missing Fluent icon');
 icons.history=icons.clock;
 if(!fs.existsSync(path.join(dir,'LICENSE.txt'))){const license=await fetch('https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/LICENSE');fs.writeFileSync(path.join(dir,'LICENSE.txt'),await license.text());}
 fs.writeFileSync(path.join(__dirname,'icons.js'),'// Microsoft Fluent System Icons · MIT · assets/fluent/LICENSE.txt\nwindow.LYCHEE_ICONS='+JSON.stringify(icons)+';\n');
})();
