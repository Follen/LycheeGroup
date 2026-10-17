# Group third-party libraries

The two Lua files were copied unchanged on 2026-10-17 from the locally installed
EllesmereUI 9.5.5 package, under its `Libs` directory. No framework code is included.

| Library | Embedded version | Bytes | Upstream |
| --- | --- | --- | --- |
| LibSpecialization | minor 28 | 24,091 | [BigWigsMods/LibSpecialization](https://github.com/BigWigsMods/LibSpecialization) |
| LibStub | minor 2 | 1,397 | [LibStub](https://www.wowace.com/projects/libstub) |

LibSpecialization uses the author's published [BSD license](https://www.curseforge.com/wow/addons/libspecialization/license),
reproduced in [LICENSE.txt](LibSpecialization/LICENSE.txt). The publisher's
`<YEAR>`, `<OWNER>` and `<ORGANIZATION>` placeholders are retained verbatim.
LibStub's public-domain notice and author credits remain in its source header.

Load `LibStub/LibStub.lua` before `LibSpecialization/LibSpecialization.lua`.
The latter reuses the shared, versioned `LibStub("LibSpecialization")` singleton.
Its only library dependency is LibStub; it does not require the source package.

Register with `lib.RegisterGroup(owner, callback)` and unregister with
`lib.UnregisterGroup(owner)` (dot calls). The callback receives
`specID, role, position, playerName, talentString`. Registration does not replay
old messages, and the library exposes no peer cache getter. `MySpecialization()`
only describes the local player. The public `RequestGroupSpecialization()` is a
deprecated no-op in minor 28; group communication is automatic.

The library retains its event listener and automatic communications after a
consumer unregisters. Do not stop its shared frame. Keep product caches and any
native inspect fallback scoped to actual Group consumers.

SHA-256 of the unchanged Lua files:

- LibSpecialization: `6396d738c9ef626a88bf0ef28c6f52e86e0dd6505dfc36ebbf19b0d35ffac115`
- LibStub: `6000f58d740eaa2b4a006c1dabb0366f0321fc687bab9e85d97d040a1fd42dab`
