# Lychee LFG

[简体中文](README.md) · English

A group-finding addon for retail World of Warcraft. Find groups, manage recruitment, and keep notes on players you meet, all in one window.

The current version is **1.2.5**, targeting retail **12.1.5** (Interface `120105`) with Chinese and English support. See the [changelog](CHANGELOG.md) for release notes (in Chinese).

## Features

- **Find groups:** browse dungeons, raids, delves, PvP, and other activities. Search and filter listings, filter seasonal dungeons by matching class, specialization, class and role, or Bloodlust source; view your seasonal timed key level and dungeon score in the keystone picker, read listing descriptions, inspect members, and track applications. Groups that declined you during this session sort last and show how long ago they declined.
- **Manage recruitment:** create and edit listings, inspect applicants' Mythic+ records, listing-specific dungeon scores, and known factions. Click a faction icon to switch to the race name, and invite players from the list. Click the star beside the activity to save the current settings. Applying a favorite preserves your current title and description for you to review and publish; publishing does not save a creation history. Small-group activities show current members directly; raid activities show subgroup rosters and known item levels on hover. Raid leaders and assistants can drag members between subgroups when they and the affected members are out of combat. Current-season raids also show class-buff coverage.
- **Character preferences:** save automatic application, application roles, category filters, and sorting per character across reloads. The application dialog and main window share the same automatic-application setting.
- **Table controls:** hover over a header and drag its dividers to resize columns. Right-click a divider to restore that table's default widths. Click numeric or time headers to toggle ascending and descending order; widths and directions are saved per character.
- **Filters and member icons:** an internal filter panel offers rating, item-level, and group-size ranges. Seasonal dungeon role combinations and matching-class/spec filters are selected directly in the panel by default. Enable “Key filters on main page” under Find groups to display them in My applications. Search-result member icons offer circle/original rounded-square shapes, class-colored borders, scaling, and a crown on the actual leader.
- **Group blocking:** block matching titles from a listing's context menu and remember their leaders across refreshes and reloads. Remove individual entries or clear the list under Settings → Blocked leaders, independently of player notes.
- **Player profiles:** copy WCL and Raider.IO character links from player details.
- **Player notes:** share positive, neutral, or blocked-player records across characters on the account, with reminders when you group again. Import and export your notes.
- **Mythic+ history:** keep a per-character history of runs, key levels, dates, and teammates, then add notes from past runs.
- **Usage guide:** follow one continuous sequence through Find, healer and auto-apply selection, Create, and window controls using real activity information with sample player and group data. The welcome page appears on the account’s first ordinary main-window opening; reopen it from Settings → General → Start guide or `/lg dev guide`. Your live group and saved preferences remain unchanged.
- **Interface settings:** choose Default theme, Frosted glass, or an imported theme, then reload to apply. Change the main-window key binding, overall scale, and font size; the floating window has its own scale setting. Clicking Settings again returns to the page you came from. Automatically integrate with the RurutiaSuite top bar when both the floating window and compatibility settings are enabled. In Ellesmere DataBars, add the `荔枝组队` broker plugin to show the Lychee icon, name, and application status.

The interface uses native Lua with bundled [LycheeUI V1.0.0](https://github.com/Follen/LycheeUI/tree/v1.0.0). Feature modules load on demand; no separate UI library installation is needed.

See the [product document](Product.md) for implementation and verification coverage.

## Installation

1. Download or clone this repository.
2. Copy the five folders in [`addon/`](addon) to `World of Warcraft/_retail_/Interface/AddOns/`:

   ```text
   LycheeGroup
   LycheeGroup_Group
   LycheeGroup_Notes
   LycheeGroup_UI
   LycheeGroup_Guide
   ```

3. Start or restart the game, enable Lychee LFG in the addon list, and type `/lg` to open it.

## Commands

| Command | Action |
| --- | --- |
| `/lg` | Toggle the main window |

Use the interface to find or create groups, open notes or settings, and record players. Development checks use these commands; `/lg dev` lists them:

| Command | Action |
| --- | --- |
| `/lg dev floattest` | Temporarily center the current live floating window; run again to restore |
| `/lg dev test [applications\|create\|applicants\|off]` | Open a sample applications, create, or applicants scene; `off` exits |
| `/lg dev guide` | Open the continuous guide welcome page; no route argument |

The game's green queue eye opens Lychee's Create page for an active premade listing, or Find with the active application selected. This also works while matchmaking is queued. With matchmaking alone, left-click keeps the game's queue menu; right-click retains its native behavior.

Hold the bottom-right resize grip: drag horizontally to change width, vertically to change height, or diagonally to change both. A minimum size keeps controls usable and increases with larger fonts. Pages rearrange while preserving current input and selections. Releasing saves this character's size for reopening and reloading. Window dimensions, overall scale, and font size are separate controls.

The default main-window key is the English semicolon `;`. It is assigned only when the addon has no binding and the key is free. Change it under General, where you can also choose the game language, Simplified Chinese, or English (applied after reloading). Under Appearance, select a font, adjust font size from 70% to 130%, and scale the main window from 75% to 125%; both use 100% as the baseline and apply immediately. The bundled LycheeFont uses the complete YaHei font for the Chinese UI and Inter for the English UI; game and shared fonts remain available.

The account’s first ordinary main-window opening shows only the existing welcome page; teaching starts after Start guide is clicked. It does not reopen automatically after a reload, character change, or later opening on the same account, while manual entry remains available. The compact dark card centers the Lychee logo, thank-you text, and Start guide, with Don’t show again at the top right. Real activities and sample data are prepared only after starting the continuous Find and Create guide. This first-open behavior is implemented, passes offline validation, and has been copied to the game directory for reload and in-game acceptance; native visuals, natural memory, and CPU measurements remain pending.

## Development

Version 1.1.5 exposes `LycheeGroup.API.Floating` for existing top bars and other entry points. It supports status subscriptions, attachment, refresh, release, and the shared popup. See the [interface contract](Architecture.md#92-浮窗公开接口). The bundled [RurutiaSuite adapter](addon/LycheeGroup/Adapters/Rurutia.lua) and [DataBroker adapter](addon/LycheeGroup/Adapters/DataBroker.lua) live in `Adapters/` and demonstrate the public interface.

Run the offline tests from the repository root with Lua 5.1:

```sh
lua tests/runner.lua
```

Select specific modules by adding their names, for example `lua tests/runner.lua core notes`. Unknown module names produce an error and a nonzero exit code. See the [validation guide](tests/theme_reload.md) for theme reload, layout, pinned-main comparison, and memory checks.

For the local widget-tree preview, run `lua tests/ui_preview.lua`, then open [`tests/ui-preview.html`](tests/ui-preview.html). The generated `tests/preview-data.js` stays local and is not committed. This preview uses sample data and does not verify in-game behavior.

[`tools/Build-Addon.ps1`](tools/Build-Addon.ps1) builds the addon archive. It syncs the bundled library from a sibling `LycheeUI` source directory by default; use `-LibraryPath` to select another location. Clone `https://github.com/Follen/LycheeUI.git` and check out `v1.0.0`; the sync script verifies the frozen file inventory and hashes.

Project documents (in Chinese): [Product](Product.md) · [Design](Desgin.md) · [Architecture](Architecture.md) · [Performance](perfermance.md) · [Third-party configuration API](API.md) · [Development rules](Development.md) · [Documentation and changelog rules](Agents.md). The product document describes the current implementation and in-game validation coverage.

The current release is 1.2.5; release notes are in the [changelog](CHANGELOG.md). This release uses [Theme API v2](API.md): account or character themes apply at login or reload, while font size, scale, window size, and table preferences remain live. The pinned main commit is the historical equivalence reference for the architecture migration; current behavior and UI follow the documented product and design changes. See [Development.md](Development.md) for development rules and [theme reload validation](tests/theme_reload.md) for verification methods. Edit LycheeUI in its source directory and use the sync tool to update the embedded copy; [.lock](https://github.com/Follen/LycheeUI/blob/v1.0.0/.lock) records its freeze status. Shared-library contracts are in its [README](https://github.com/Follen/LycheeUI/blob/v1.0.0/README.md), [API](https://github.com/Follen/LycheeUI/blob/v1.0.0/API.md), and [design specification](https://github.com/Follen/LycheeUI/blob/v1.0.0/DESIGN.md).

See the [library notes](addon/LycheeGroup_Group/Libs/README.md) for bundled third-party sources and licenses.
