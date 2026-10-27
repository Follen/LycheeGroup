-- Public theme tokens affect semantic game text in both product contexts.
local Fixture=dofile("tests/ui_fixture.lua")
local function Color(region,base,tint,label)
 local r,g,b=region:GetTextColor()
 T.near(r,base.r*tint[1],.000001,label);T.near(g,base.g*tint[2],.000001,label);T.near(b,base.b*tint[3],.000001,label)
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local mainTint,floatingTint={.5,.75,.25,1},{.25,.5,.75,1}
 local theme={schema=1,id="audit.game-colors",revision=1,appearance={main={tokens={gameTextTint=mainTint}},floating={tokens={gameTextTint=floatingTint}}}}
 local f=Fixture(locale,nil,{reduceMotion=true},theme);local a,u,g=f.A,f.U,f.G
 local oldClassColors=RAID_CLASS_COLORS
 RAID_CLASS_COLORS={MAGE={r=.25,g=.75,b=1}}
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 local builtins=a.API.Theme:List({includeBuiltins=true});local count=0
 for _,entry in ipairs(builtins) do if entry.builtin then count=count+1;T.ok(entry.id=="lycheegroup.default" or entry.id=="lycheegroup.frosted","only the two retained built-in themes are exposed") end end
 T.eq(count,2)
 a:Open("create")
 local native=RAID_CLASS_COLORS.MAGE
 local r,gc,b=u:ClassColor("MAGE")
 T.near(r,native.r*mainTint[1],.000001);T.near(gc,native.g*mainTint[2],.000001);T.near(b,native.b*mainTint[3],.000001)
 local score=u.C.Text(u.frame,"",14,"text")
 u:SetScore(score,2345);Color(score,C_ChallengeMode.GetDungeonScoreRarityColor(2345),mainTint,"main score inherits its own theme tint")
 u:SetScore(score,456,"map");Color(score,C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(456),mainTint,"map score inherits the main theme tint")
 local c=C_ChallengeMode.GetDungeonScoreRarityColor(2345)
 T.eq(u:ScoreText(2345),("|cff%02x%02x%02x2345|r"):format(math.floor(c.r*mainTint[1]*255+.5),math.floor(c.g*mainTint[2]*255+.5),math.floor(c.b*mainTint[3]*255+.5)))
 g.listing={activityID=2,name="Listing"}
 local member={name="Applicant-Away",nameKey="Applicant-Away",class="MAGE",assignedRole="DAMAGER",applicantID=91,itemLevel=326,dungeonScore=2345,dungeonScores={mapScore=456,current={name="Dungeon",level=18,timed=true}}}
 g.applicants[91]={id=91,status="applied",activityID=2,members={member}};g:Notify("listing");g:Notify("applicants")
 u.Tooltip:ShowPlayer(u.frame,member)
 local tip=u.Tooltip.interactive
 Color(tip.title,native,mainTint,"player tooltip uses main class tint")
 Color(tip.dungeonRows[1].keyLevel,C_ChallengeMode.GetKeystoneLevelRarityColor(18),mainTint,"keystone tooltip uses main rarity tint")
 local floating=a.Floating;floating:Bind(g);floating:UpdateSettings();floating:ShowPanel()
 local found
 for _,row in ipairs(floating.rows) do if row:IsShown() and row.name:GetText()==member.name then found=row;break end end
 T.ok(found,"floating applicant is rendered through the real product path")
 Color(found.name,native,floatingTint,"floating class text uses its separate context")
 Color(found.score,c,floatingTint,"floating score uses its separate context")
 T.same(RAID_CLASS_COLORS.MAGE,native,"semantic source colors remain unchanged")
 floating.panel:Hide();u:Hide(true);RAID_CLASS_COLORS=oldClassColors
end
