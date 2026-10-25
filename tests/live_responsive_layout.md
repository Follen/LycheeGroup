# Private responsive-layout acceptance probe

The probe uses a private off-screen host and Context. It requires the installed
library to advertise `LycheeUI.layoutModes.flex == true`, so it follows the
candidate capability rather than a hard-coded library revision. It does not
open LycheeGroup pages or change saved settings, search data, filters, or global
hooks.

Run the offline lifecycle regression from the repository root:

```text
lua tests/test_live_responsive_layout.lua ../LycheeUI
```

Register the probe source and execute the returned immutable PRB revision in an
already authorized native session:

```text
lycheedev live probe put --name private-responsive-layout --file tests/live_responsive_layout.lua --format json
lycheedev live execute --project . --session <CON-id> --probe <PRB-revision> --request <stable-request-key> --budget-seconds 70 --policy observation --wait-seconds 120 --format json
```

The report covers nearest and named container conditions, the 600-unit
inclusive/exclusive boundary, hidden Context resume, four direct-layout metadata regressions (partial state/condition rules actively change minWidth and alignment then restore the item defaults; late maxWidth applies and restores with a separately resized ancestor and fixed-size Row parent; late participate=false excludes and restores using that same split-container setup without an intervening child read or flush; a disabled-state padding style on the Row parent overrides and restores the options fallback without a container or parent-size event), a private EditBox, native
FontString identity, different effective scales, callback hide/release, a
programmatic A-to-B pooled-row rebind, tracked `Column` and `Row` layouts that
reflow after native child size changes (including omitted dimensions and
`includeHidden=true`), and a conditional list-height prefix. The list case
checks a width-dependent row height, an offscreen `item:100` instance whose
`checked` state raises its height, the resulting scroll range, and restoration
when the condition stops matching. A final direct scheduler flush records the
queue, work arrays, deferred jobs, active work, and driver state. The
1,000-item text-flow list rebuild runs at most 128 index records per step with `timeBudgetMs=2` and
records step durations, measurement/index counts, the visible row-pool size,
the scroll-anchor key, natural whole-client Lua heap deltas, and private-subtree
native-object counts. The outer probe also stops any work segment exceeding
100 ms. A single resolver/native operation cannot be preempted by the library's
time budget.

Scenario failures log a bounded string before raising the error. The nearest
container case includes measured and expected widths, width deltas, actual and
cached container widths, and relevant effective scales. Cleanup logs use the
same string format so native probe logs retain failure and release details.
Every private root whose size changes drive conditions or flex layouts is
anchored to the private host. Geometry checks allow only a small scale-aware
binary32 readback error, including dimensions derived by subtracting absolute
native edges, capped at one hundredth of a physical pixel; the
600-unit min/max predicates remain exact. The offline fixtures accept a
float32-sized width difference and a height edge-subtraction difference, reject
one-pixel differences even at large absolute coordinates, simulate a
native unanchored frame that suppresses its size notification, and inject a
late failure after the four metadata scenarios to check cleanup. Success, failure,
and cancellation cases all invoke a late callback and verify it creates no objects. Resize checks read the changed width or height before either `FlushLayouts` or
the direct `Layout` call, allowing the client to settle the native rectangle and
emit its pending size event in the same tick. The four metadata regression cases
call `Layout` directly without `FlushLayouts` so a scheduler pass cannot mask a
stale layout-input cache. The padding case changes only the parent element state;
its native and named-container dimensions stay fixed. An offline fixture delays `OnSizeChanged` until the
getter and checks the immediate condition result.

The four metadata cases activate their 60-unit conditions at width 72 and exit
at width 48 or 45. This keeps their lifecycle checks away from a boundary that
native edge subtraction can read as 59.999992 for a requested width of 60.
The separate original 600-unit boundary case retains its exact predicates.

The pinned Retail source marks `GetCursorPosition` results as secret and
`SetCursorPosition` as limited-input restricted. The pinned EditBox API has no
selection-read method. The probe therefore reports cursor and selection as
untested, counts `SetText` calls, and compares only its own program-set text
when `issecretvalue` confirms the returned value is public. It changes focus
only when no control already owns keyboard focus, then restores the empty
focus state before continuing. The input and list press/rebind cases are
programmatic checks; they do not simulate physical keyboard, IME, mouse, or
protected action dispatch.

The native-object and heap values describe this private probe scope, including
observer allocations and unrelated client Lua activity. They are not the four
package product peak or an addon-attributed natural-memory baseline. The probe
does not force garbage collection or disable normal animations.
