# Static shared-runtime allocation diagnosis (2026-10-23)

Historical investigation recorded on 2026-10-23. The original commands, source paths, measurements and hypotheses below are preserved as evidence from that investigation; they are not current run instructions or current acceptance results. Earlier optimization suggestions and withdrawn experiments are historical, not current implementation recommendations.

The maintained product diagnostics now live in `tests/measure_font_cost.lua`, `tests/measure_element_values.lua`, `tests/measure_theme_context.lua` and `tests/measure_static_allocations.lua`; run them from the product worktree with the embedded library. Shared-library storage and native-lease probes remain in the LycheeUI source tests.

This is an offline diagnosis of the current cold-Theme runtime. It does not reproduce or validate the game's four-package natural peak. Product fixture Group data is mocked; it does not represent a real raid result containing 26–30 native member-info records. No runtime source or game files were changed.

## Reproduce

From the product worktree, run:

```powershell
lua D:/Code/wow/addons/LycheeUI/tests/static-allocation-profile.lua
lua D:/Code/wow/addons/LycheeUI/tests/static-allocation-profile.lua stable
lua D:/Code/wow/addons/LycheeUI/tests/static-allocation-profile.lua native
```

The script loads external LycheeUI directly. It measures first Find, first Settings, all four pages, twelve complete navigation cycles, then twelve font cycles (70/100/130/100). Wrappers report inclusive and exclusive allocation; do not add inclusive child costs to parent costs. Collections delimit diagnostic allocated/retained values only. No production collection policy is proposed.

`stable` reuses the test doubles' native field/point storage and native region/child readback arrays. `native` additionally caches the test doubles' glyph-unit counts while retaining their same width/wrapping formulas; it asserts initial width and height equivalence for each replaced text object. The extra diagnostic caches change absolute retained totals and must not be treated as production memory. These modes distinguish library Lua allocations from table/iterator allocations that exist only because native methods are implemented in Lua in the fixture.

From LycheeUI itself, run the smaller reproductions:

```powershell
lua tests/static-storage-probe.lua
lua tests/native_allocations.lua
```

## Results and interpretation

| Phase | Unmodified fixture allocation KiB | Retained KiB | New substitute native objects |
| --- | ---: | ---: | ---: |
| First Find | 2223.302 | 1964.996 | 864 |
| First Settings | 1927.670 | 1704.125 | 782 |
| Remaining first-page builds | 1857.170 | 1529.735 | 707 |
| Twelve warm navigation cycles | 1147.995 | 0.016 | 0 |
| Twelve warm font cycles | 8424.386 | 6.359 | 0 |

Warm navigation therefore reproduces transient allocation, not a steadily retained UI graph. At the four-page checkpoint: 2392 substitute native objects, 414 managed fonts, 178 component controllers, only 27 actual configured slot records and 56 base/applied fields, 25 fixed-rule scan entries, 53 layouts and 155 layout item records. Navigation leaves these counts unchanged. Initial font roundtrips add three warmed layout records, then reuse them.

With native field/point/readback storage and equivalent cached native text metrics, twelve navigation cycles allocate 458.046 KiB and twelve font cycles allocate 825.750 KiB, including product callbacks and remaining fixture costs. In the 48 font updates, `RefreshFonts` allocates 0.375 KiB, `RefreshLayouts` 7.828 KiB and fixed font-rule dispatch 40.500 KiB. The fixture's original 1556.625 KiB font-refresh and 1300.690 KiB layout-refresh allocations are predominantly substitute-native work, not evidence of similarly large game Lua allocation.

The direct storage reproduction gives these controlled results:

- 100 ordinary C.Text controls retain 164.781 KiB versus 145.031 KiB for equivalent native text objects: extra library storage is 19.750 KiB.
- 100 empty style controllers, with their declarations already supplied, retain 56.929 KiB and create no native objects.
- 100 controllers sharing one hover declaration retain 212.859 KiB; hover roundtrip allocates 47.125 KiB, mostly temporary patches, with a 6.500 KiB first-use high water.
- 100 two-item layouts retain 518.984 KiB. One thousand unchanged layout calls allocate and retain 0 KiB.
- 100 plain text controls undergoing 100 font-scale updates allocate 3.125 KiB and retain 0 KiB with native font storage reused. The 3.125 KiB is the empty table-header fallback in Context:SetFont, not per-text state growth.

Reachable table-copy probes put font metadata around 119 KiB, layout metadata around 269 KiB, element metadata around 361 KiB, controller metadata around 403 KiB and Panel metadata around 259 KiB for this fixture. These graphs overlap and include shared declarations. They cannot be added, and shallow copies do not count closure upvalues, native heap or unused hash capacity. They establish scale; they are not a precise ownership census.

## NativeInput lifecycle and possible follow-up

The largest shared transient item during navigation is 36 NativeInput acquisitions: about 194.891 KiB after removing substitute-native setter storage. The isolated three-input test allocates 1761.891 KiB for 300 acquire/refresh/release cycles. A second warmed batch retains exactly 0.000 KiB, adds zero native objects, and ends with no active lease or registered input.

These allocations come from fresh lease/layout/font/script snapshots, script wrappers, and per-lease RefreshStyle/finish/resize closures. They serve real ownership and restoration requirements. Reusing the same public lease object would violate stale-handle isolation; discarding the snapshots would violate native restoration. If later measurement justifies optimization, shared lease methods and carefully reused private storage can reduce transient cost, while preserving fresh lease identity and all existing native lifecycle tests. The current evidence does not make this a multi-megabyte retained leak.

Other bounded opportunities are a shared layout prototype/compact per-item snapshots, and skipping font-only dispatch for rules with no font properties. Layout input mutation, independent instances, cross-element anchors, current business baselines and active-state geometry must remain supported. Existing TableHeader cells are already reused in place; there is no finding of per-layout column-record replacement.

Do not change shared runtime based on this diagnosis alone. Ordinary Text and default controllers are no longer a plausible source of several megabytes of avoidable metadata in this fixture. The separate real Group raid-details path and actual client natural peak remain the next acceptance evidence.

## Follow-up after the completed 105-result live run

The completed live run remains a failure: approximately 21.64 MB total, including UI 8,525,949 bytes, Core about 2.84 MB and Group about 10.18 MB. The earlier no-wait 12.85 MB run is not acceptance evidence. The following is a bounded shared-library investigation, not a proposed substitute budget.

To test whether cold recipe duplication still hides a large cost, the profiler accepts an optional second argument:

```powershell
lua D:/Code/wow/addons/LycheeUI/tests/static-allocation-profile.lua native cow
```

This changes only the diagnostic VM's private AttachStyles recipe composition to immutable structural sharing. Public ResolveRecipes, production files and configuration contracts are untouched. Four-page retained fixture total changes from 7668.089 to 7652.019 KiB, saving 16.070 KiB. Native/font/controller/actual-slot counts remain the same, and warm navigation/font allocations are unchanged. The experiment falsifies a multi-megabyte recipe-copy hypothesis; it is not worth landing for the present gap.

Current source already compiles legacy component rules as differences from the shared component recipe, caches compiled combinations, shares state orders, and shares empty directories for inert controllers. Ordinary text has no full controller. Actual baseline/applied fields exist only on configured native slots for state exit, key rebinding and Native ownership. Removing those remaining fields would break required behavior and would save only a small amount in this fixture.

The prior table-copy probes overlap, but even their uncorrected sum is only about 1.4 MiB, before considering that most of this metadata is required. This is not a precise native-client upper bound: it excludes native objects, closure upvalues and hash capacity. It does establish that the measured shared metadata cannot credibly be presented as the full 6.7 MB solution.

No production patch is recommended from this pass. NativeInput private storage/closure reuse, compact layout snapshots and skipping font-only work on paint-only rules remain bounded follow-ups, not the primary budget fix. The profiler confirms that fonts and layout readback mostly allocate in the Lua native substitutes; those costs must not be extrapolated into game bytes. A change large enough to meet the budget needs new evidence outside these already sparse shared rule paths, while preserving current data freshness, native ownership and visual behavior.


## Authorized cold-path changes after the later construction report

The later live construction report identified C.Element (480 calls, roughly 761 KiB net including natural-GC negative samples), C.Text (535 calls, 369 KiB), ResolveTheme (3 calls, 311 KiB), and inclusive ValidateTheme (2 calls, 210 KiB). ResolveTheme cost is nested inside validation, so those rows must not be summed.

The conservative catalog fast path is now implemented. It keeps every actual element identity record, but skips Compile/Merge and no-op Apply bookkeeping when neither its fixed declaration nor its instance/variant/class branches contain rules. Structured classes and cross-element anchor targets still use the normal rule path. The controlled four-page fixture saved about 214.8 KiB allocation and 115.5 KiB retained; exclusive C.Element construction allocation fell from about 377.8 to 151.97 KiB. Warm navigation saved 33.375 KiB. Native object counts were unchanged. These are 32-bit offline fixture numbers, not measured game savings.

Raw Context creation now reuses successful ValidateTheme's third result instead of resolving a third time. Defaults and overrides still undergo the same validation, with no new cache, backing copy, or token API.

Run the actual API measurement from the product worktree:

```powershell
lua D:/Code/wow/addons/LycheeUI/tests/theme-context-profile.lua
```

With the product default schema, raw Context allocation was 315.781 KiB, retained 122.617 KiB, with two ResolveTheme calls allocating 129.578 KiB in total. The historical raw baseline before third-result reuse was 380.574 KiB allocation and 122.621 KiB retained. Reusing the existing validation result therefore saved about 64.8 KiB cold Context allocation, without an additional retained projection. No production GC behavior changed.

A separately measured startup token experiment reduced full controlled lifecycle allocation by only 46.691 KiB while increasing retained storage by 17.689 KiB. It was withdrawn. No compiled-theme API or Context option remains. These are offline diagnostic measurements, not a claim of satisfying the natural game budget.

Shared regressions directly cover the third validation result, the exact two resolutions at ordinary Context construction, independent top-level Context tables, invalid raw defaults and effective font sizes, alongside the existing font, state, anchors and Native contracts. Product/main visual equivalence and the natural 15,000,000-byte budget remain the integrating agent's acceptance checks.
