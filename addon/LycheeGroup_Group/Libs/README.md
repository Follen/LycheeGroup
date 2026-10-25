# Group third-party libraries

The two Lua files were originally copied unchanged on 2026-10-17 from the locally
installed EllesmereUI 9.5.5 package, under its `Libs` directory. LibSpecialization
now includes the local Retail performance patch described below; LibStub remains
unchanged. No framework code is included.

| Library | Embedded version | Bytes | Upstream |
| --- | --- | --- | --- |
| LibSpecialization | minor 28 + local patch | 25,187 | [BigWigsMods/LibSpecialization](https://github.com/BigWigsMods/LibSpecialization) |
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

## Local Retail performance patch (2026-10-25)

Only the automatic group, instance and guild response preparations reuse the
latest successful nonempty talent import string for the current config ID and
specialization ID. The two existing active-config update events invalidate it
before notifying consumers; a config/spec change or unsuccessful direct read
also prevents reuse. `MySpecialization()` and synchronous request callbacks
continue reading native data every time and can refill the same single cache.
Missing/empty strings are retried on the next read. Other client branches retain
their original uncached behavior. The 3-second send throttles, channels, retries
and shared latest prepared payload are unchanged.

The LibStub minor stays 28. An equal or newer provider loaded by another addon
continues to win, so this patch applies only when this embedded copy supplies
the shared library. It does not establish which provider a running game uses.

Independent protocol counters run with
`lua tests/test_libspecialization_performance.lua`: forty unchanged requests
within one frame or 1.95 seconds require one talent serialization instead of
forty, while retaining one immediate and one delayed response. The tests also
cover config/spec changes, reentrant callbacks, both group channels, guild,
send retries, unavailable data, direct reads and LibStub version selection.
These are offline call counts, not measured game CPU timings.

The event contract was checked against wow-ui-source commit
`15881d522c44cd106d3d8660106ec9f9d2f44167`, whose generated
`SharedTraitsDocumentation.lua` marks `TRAIT_CONFIG_UPDATED(configID)` as a
synchronous event. No new event subscription or background task was added.

SHA-256 of the original copies (LibSpecialization was 24,091 bytes):

- LibSpecialization: `6396d738c9ef626a88bf0ef28c6f52e86e0dd6505dfc36ebbf19b0d35ffac115`
- LibStub: `6000f58d740eaa2b4a006c1dabb0366f0321fc687bab9e85d97d040a1fd42dab`

SHA-256 of the locally patched LibSpecialization (25,187 bytes):

- `f9430f20cb78752321e4b46337ea765799037273b199a985e449442620ad5d9e`
