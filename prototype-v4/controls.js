// Native form values, with a shared in-product menu instead of the OS popup.
(() => {
 let owner=null,popup=null;
 const sync=select=>{
  const host=select.parentElement,button=host.querySelector('.select-trigger');
  host.hidden=select.hidden;
  button.disabled=select.disabled;
  button.querySelector('.select-value').textContent=select.selectedOptions[0]?.textContent||'';
 };
 window.enhanceSelects=(root=document)=>{
  root.querySelectorAll('#window select,#search-filters select').forEach(select=>{
   if(!select.parentElement.classList.contains('select-control')){
    const host=document.createElement('span'),button=document.createElement('button');
    host.className='select-control';
    button.type='button';button.className='select-trigger';
    button.setAttribute('role','combobox');button.setAttribute('aria-haspopup','listbox');button.setAttribute('aria-expanded','false');
    const label=select.getAttribute('aria-label')||select.closest('label')?.querySelector('span')?.textContent||select.previousElementSibling?.textContent||'选择';
    button.setAttribute('aria-label',label.trim());
    button.innerHTML='<span class="select-value"></span><span class="select-chevron" aria-hidden="true"></span>';
    select.replaceWith(host);host.append(select,button);select.tabIndex=-1;select.setAttribute('aria-hidden','true');
   }
   sync(select);
  });
 };
 window.closeSelectMenu=(focus=false)=>{
  if(!owner)return;
  const button=owner.parentElement?.querySelector('.select-trigger');
  button?.setAttribute('aria-expanded','false');
  popup.hidden=true;owner=null;
  if(focus&&button?.isConnected)button.focus({preventScroll:true});
 };
 const open=select=>{
  closeSelectMenu();owner=select;
  if(!popup){popup=document.createElement('div');popup.className='select-menu';popup.id='select-menu';popup.setAttribute('role','listbox');document.body.append(popup);}
  const button=select.parentElement.querySelector('.select-trigger'),rect=button.getBoundingClientRect();
  popup.replaceChildren();
  Array.from(select.options).forEach(option=>{
   const item=document.createElement('button');item.type='button';item.className='select-option';
   item.dataset.value=option.value;item.textContent=option.textContent;item.disabled=option.disabled;
   item.setAttribute('role','option');item.setAttribute('aria-selected',String(option.selected));popup.append(item);
  });
  popup.hidden=false;popup.style.width='max-content';
  popup.style.minWidth=Math.min(innerWidth-16,Math.max(168,rect.width))+'px';
  const menuWidth=popup.getBoundingClientRect().width;
  popup.style.left=Math.max(8,Math.min(rect.left,innerWidth-menuWidth-8))+'px';
  const wanted=Math.min(260,popup.scrollHeight),below=innerHeight-rect.bottom-12;
  const upward=below<wanted&&rect.top>below;
  popup.style.maxHeight=Math.min(260,Math.max(90,upward?rect.top-12:below))+'px';
  popup.style.top=(upward?rect.top-Math.min(wanted,rect.top-12)-5:rect.bottom+5)+'px';
  button.setAttribute('aria-expanded','true');button.setAttribute('aria-controls','select-menu');
  popup.querySelector('[aria-selected=true]')?.focus({preventScroll:true});
  popup.querySelector('[aria-selected=true]')?.scrollIntoView({block:'nearest'});
 };
 document.addEventListener('click',event=>{
  const trigger=event.target.closest('.select-trigger');
  if(trigger){event.preventDefault();event.stopPropagation();const select=trigger.parentElement.querySelector('select');if(owner===select)closeSelectMenu(true);else open(select);return;}
  const option=event.target.closest('.select-option');
  if(option&&owner){
   event.preventDefault();event.stopPropagation();
   const select=owner,id=select.id,value=option.dataset.value;
   closeSelectMenu();select.value=value;sync(select);select.dispatchEvent(new Event('change',{bubbles:true}));
   const current=id?document.getElementById(id):select;
   current?.parentElement.querySelector('.select-trigger')?.focus({preventScroll:true});return;
  }
  closeSelectMenu();
 },true);
 document.addEventListener('keydown',event=>{
  const trigger=event.target.closest('.select-trigger');
  if(trigger&&!owner&&['ArrowDown','ArrowUp'].includes(event.key)){event.preventDefault();event.stopImmediatePropagation();open(trigger.parentElement.querySelector('select'));return;}
  if(!owner)return;
  if(event.key==='Escape'){event.preventDefault();event.stopImmediatePropagation();closeSelectMenu(true);return;}
  if(event.key==='Tab'){closeSelectMenu();return;}
  if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)){
   event.preventDefault();event.stopImmediatePropagation();
   const items=Array.from(popup.querySelectorAll('button:not(:disabled)')),index=items.indexOf(document.activeElement);
   const next=event.key==='Home'?0:event.key==='End'?items.length-1:(index+(event.key==='ArrowDown'?1:-1)+items.length)%items.length;
   items[next]?.focus();
  }
 },true);
 addEventListener('resize',()=>closeSelectMenu());
 document.addEventListener('scroll',event=>{if(owner&&!popup.contains(event.target))closeSelectMenu();},true);
})();

// One short-lived driver for scroll input; no work remains after the gesture.
(() => {
 const jobs=new Map();let frame=0;
 const reduced=()=>document.body.classList.contains('reduce-motion')||matchMedia('(prefers-reduced-motion: reduce)').matches;
 function tick(now){
  frame=0;
  for(const [element,job] of jobs){
   if(!element.isConnected||!element.getClientRects().length){jobs.delete(element);continue;}
   const t=Math.min(1,(now-job.start)/140),ease=1-Math.pow(1-t,3);
   element.scrollTop=job.from+(job.to-job.from)*ease;
   if(t===1)jobs.delete(element);
  }
  if(jobs.size)frame=requestAnimationFrame(tick);
 }
 window.cancelScrollMotion=()=>{if(frame)cancelAnimationFrame(frame);frame=0;jobs.clear();};
 document.addEventListener('wheel',event=>{
  if(event.ctrlKey||event.deltaY===0||reduced())return;
  let element=event.target instanceof Element?event.target:null;
  for(;element&&element!==document.body;element=element.parentElement){
   if(!/(auto|scroll)/.test(getComputedStyle(element).overflowY))continue;
   const maximum=element.scrollHeight-element.clientHeight;
   if(maximum<1)continue;
   const previous=jobs.get(element),from=element.scrollTop,base=previous?previous.to:from;
   const delta=event.deltaY*(event.deltaMode===1?18:event.deltaMode===2?element.clientHeight:1);
   const to=Math.max(0,Math.min(maximum,base+delta));
   if(to===base&&!previous)continue;
   event.preventDefault();jobs.set(element,{from,to,start:performance.now()});
   if(!frame)frame=requestAnimationFrame(tick);
   return;
  }
 },{passive:false});
 document.addEventListener('pointerdown',()=>cancelScrollMotion(),{capture:true,passive:true});
 document.addEventListener('visibilitychange',()=>{if(document.hidden)cancelScrollMotion();});
})();
