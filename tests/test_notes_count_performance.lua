-- Standalone: lua tests/test_notes_count_performance.lua
local checks=0
local function Eq(actual,expected,message) checks=checks+1;assert(actual==expected,(message or '')..' expected '..tostring(expected)..', got '..tostring(actual)) end
local function CountRows(records,operation)
 local previous=pairs;local visits,scans=0,0
 pairs=function(t)
  local iterator,state,key=previous(t)
  if t~=records then return iterator,state,key end
  scans=scans+1
  return function(s,k) local nextKey,value=iterator(s,k);if nextKey~=nil then visits=visits+1 end;return nextKey,value end,state,key
 end
 local ok,err=pcall(operation);pairs=previous;assert(ok,err)
 return scans,visits
end
local f=dofile('tests/ui_fixture.lua')('enUS',nil,{reduceMotion=true})
local a,n=f.A,f.A.Notes
local function Counts()
 local all,positive,neutral,caution=n:GetCounts()
 local expected={0,0,0,0}
 for _,record in pairs(n.db.records) do
  expected[1]=expected[1]+1
  local kind=record.type or 'neutral'
  local index=kind=='positive' and 2 or kind=='neutral' and 3 or kind=='caution' and 4
  if index then expected[index]=expected[index]+1 end
 end
 for index,value in ipairs({all,positive,neutral,caution}) do Eq(value,expected[index],'independent count '..index) end
end
-- The real UI event path must keep single-record edits independent of N.
for i=1,1000 do assert(n:Add('Person'..i,'Home','old',nil,nil,{type='neutral'})) end
a:Open('notes')
local scans,visits=CountRows(n.db.records,function()
 for i=1,10 do assert(n:Edit('Person1-Home','changed '..i,{type='neutral'})) end
end)
Eq(scans,0,'reason-only edits do not enumerate the stored table');Eq(visits,0)
Eq(f.U.pages.notes.tabs.all.count:GetText(),'1000');Eq(f.U.pages.notes.tabs.neutral.count:GetText(),'1000')
f.U:Hide(true);Counts()
local notifications={};local unsub=n:Subscribe(function(kind,key) notifications[#notifications+1]={kind,key};Counts() end)
assert(n:Add('PERSON1','Home','overwrite',nil,nil,{type='positive'}));Counts()
Eq(#notifications,1);Eq(notifications[1][1],'add');Eq(notifications[1][2],'Person1-Home')
assert(n:Edit('person1-home','type change',{type='caution'}));Counts()
assert(n:Edit('Person1-Home','nil type',{type=nil}));Counts()
assert(n:Edit('Person1-Home','unknown type',{type='legacy-unknown'}));Counts()
assert(n:Edit('Person1-Home','unchanged type'));Counts()
local duplicate=#notifications
assert(n:Edit('Person1-Home','unchanged type'));Counts()
Eq(#notifications,duplicate+1,'same-value edits preserve their existing notification')
local before=#notifications
Eq(n:Edit('Missing-Home','missing'),false);Eq(n:Remove('Missing-Home'),false)
Eq(#notifications,before,'missing mutations keep notification semantics')
assert(n:Remove('Person1-Home'));Counts()
-- Every actual replacement in a repeated-key merge adjusts its previous type.
local changed,invalid=n:Merge({
 {name='Merged',server='Home',timestamp=10,type='positive'},
 {name='MERGED',server='Home',timestamp=20,type='caution'},
 {name='Merged',server='Home',timestamp=15,type='neutral'},
 {name='Merged',server='Home',timestamp=30,type='unknown'},
})
Eq(changed,3);Eq(invalid,0);Counts()
Eq(notifications[#notifications][1],'merge');Eq(#notifications[#notifications][2],1,'merge publishes one unique key')
before=#notifications;Eq(n:Merge({{name='Merged',server='Home',timestamp=30,type='caution'}}),0);Eq(#notifications,before);Counts()
unsub()
local function Stored(name,kind,timestamp) return {name=name,server='Home',type=kind,timestamp=timestamp or 1,reason='',classSpec=''} end
-- Bind resets all four scalars and retains independent legacy case collisions.
local raw={schema=3,records={['Mixed-Home']=Stored('Mixed','positive',10),['MIXED-Home']=Stored('MIXED','caution',20),['Unknown-Home']=Stored('Unknown','other'),['Nil-Home']=Stored('Nil',nil)}}
n.db=raw
scans,visits=CountRows(raw.records,function() n.Records.Bind(raw) end)
Eq(scans,1,'Bind counts while building the existing identity index');Eq(visits,4)
Counts()
scans,visits=CountRows(raw.records,function() for i=1,100 do n:GetCounts() end end)
Eq(scans,0,'count reads never scan storage');Eq(visits,0)
local all,positive,neutral,caution=n:GetCounts();Eq(all,4);Eq(positive,1);Eq(neutral,1);Eq(caution,1)
assert(n:Add('mixed','Home','replace preferred',nil,nil,{type='neutral'}));Counts()
assert(n:Edit('Mixed-Home','edit exact',{type='caution'}));Counts()
assert(n:Remove('MIXED-Home'));Counts()
assert(n:Remove('Unknown-Home'));Counts()
changed=n:Merge({{name='mixed',server='Home',timestamp=100,type='positive'},{name='MIXED',server='Home',timestamp=101,type='caution'}});Eq(changed,2);Counts()
-- Initialize normalizes supported old storage before its one Bind count pass.
_G.LycheeGroupNotesDB={schema=3,records={['Nil-Home']=Stored('Nil',nil),['Bad']=false,['Other-Home']=Stored('Other','other')}}
n.db=nil;n:Initialize();Counts();Eq(n.db.records['Nil-Home'].type,'neutral')
all,positive,neutral,caution=n:GetCounts();Eq(all,2);Eq(positive,0);Eq(neutral,1);Eq(caution,0)
_G.LycheeGroupNotesDB={schema=1,records={a=Stored('Old','positive',1),b=Stored('Old','caution',2),c=Stored('Another','unknown',1)}}
n.db=nil;n:Initialize();Counts()
all,positive,neutral,caution=n:GetCounts();Eq(all,2);Eq(positive,0);Eq(neutral,1);Eq(caution,1)
_G.LycheeGroupNotesDB={schema=3,records={}};n.db=nil;n:Initialize();Counts();Eq(n:GetCounts(),0)
print('Notes count performance: '..checks..' checks passed')
