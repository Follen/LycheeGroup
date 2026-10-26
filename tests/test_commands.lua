-- Command dispatch must not retain removed player actions or write notes.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true})
 local A=f.A;local calls={toggle=0,open=0,note=0,float=0,preview={},guide={}};local messages={}
 A.ToggleWindow=function() calls.toggle=calls.toggle+1 end
 A.Open=function() calls.open=calls.open+1 end
 A.Print=function(_,message) messages[#messages+1]=message end
 A.Preview=function(_,scenario) calls.preview[#calls.preview+1]=scenario;return true end
 A.Floating={ToggleStandaloneTest=function() calls.float=calls.float+1;return calls.float%2==1 end}
 dofile("addon/LycheeGroup/Entrypoints.lua")
 A.RecordPlayer=function() calls.note=calls.note+1 end
 local command=SlashCmdList.LYCHEEGROUP
 T.eq(SLASH_LYCHEEGROUP1,"/lg");T.eq(SLASH_LYCHEEGROUP2,nil)
 T.eq(SlashCmdList.LYCHEEGROUPGUIDE,nil)
 command("");command("   ");T.eq(calls.toggle,2)
 for _,removed in ipairs({"find","create","notes","settings","note","note Player-Realm reason","test","test applicants","floattest","guide","guide find"}) do
  command(removed);T.eq(messages[#messages],A.L.cmdUsage)
 end
 T.eq(calls.toggle,2);T.eq(calls.open,0);T.eq(calls.note,0);T.eq(calls.float,0);T.eq(#calls.preview,0);T.eq(A.Guide,nil)
 command("dev test");command(" dev  test  create  ");command("dev test applicants");command("dev test off")
 T.same(calls.preview,{"applications","create","applicants","off"})
 command("dev floattest");T.eq(calls.float,1);T.eq(messages[#messages],A.L.floatingTestOn)
 command("dev floattest");T.eq(calls.float,2);T.eq(messages[#messages],A.L.floatingTestOff)
 command("dev floattest extra");T.eq(calls.float,2);T.eq(messages[#messages],"/lg dev floattest")
 local loads=0
 C_AddOns.LoadAddOn=function(name)
  T.eq(name,"LycheeGroup_Guide");loads=loads+1
  A.Guide={Open=function() calls.guide[#calls.guide+1]="intro";return true end};return true
 end
 command("dev guide");command("dev guide find");command("dev guide create")
 T.same(calls.guide,{"intro"});T.eq(loads,1)
 command("dev guide invalid");T.eq(#calls.guide,1);T.ok(messages[#messages]:find("/lg dev guide",1,true))
 messages={};command("dev")
 T.same(messages,{"/lg dev floattest","/lg dev guide","/lg dev test [applications|create|applicants|off]"})
 local expected=messages;messages={};command("dev unknown");T.same(messages,expected)
 T.eq(calls.open,0);T.eq(calls.note,0)
end
