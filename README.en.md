# Lychee LFG

[简体中文](README.md) · English

A group-finding addon for retail World of Warcraft. Find groups, manage recruitment, and keep notes on players you meet, all in one window.

The current version is **1.2.4**, targeting retail **12.1.5** (Interface `120105`) with Chinese and English support. See the [changelog](CHANGELOG.md) for release notes (in Chinese).

## Features

- **Find groups:** browse dungeons, raids, delves, PvP, and other activities. Search and filter listings, exclude groups that already have your class or specialization in seasonal dungeons, read listing descriptions, inspect members, and track applications. Groups that declined you during this session sort last and show how long ago they declined.
- **Manage recruitment:** create and edit listings, inspect applicants' Mythic+ records, listing-specific dungeon scores, and known factions. Click a faction icon to switch to the race name, and invite players from the list. Click the star beside the activity to save the current settings. Applying a favorite preserves your current title and description for you to review and publish; publishing does not save a creation history. Small-group activities show current members directly; raid activities show subgroup rosters on hover. Current-season raids also show class-buff coverage.
- **Character preferences:** save automatic application, application roles, category filters, and sorting per character across reloads. The application dialog and main window share the same automatic-application setting.
- **Table controls:** hover over a header and drag its dividers to resize columns. Right-click a divider to restore that table's default widths. Click numeric or time headers to toggle ascending and descending order; widths and directions are saved per character.
- **Filters and member icons:** an internal filter panel offers rating, item-level, and group-size ranges. Seasonal dungeon role combinations and matching-class/spec filters are selected directly in the panel by default. Enable “Show key filters on the main page” in Appearance to display them in My applications. Search-result member icons offer circle/original rounded-square shapes, class-colored borders, scaling, and a crown on the actual leader.
- **Group blocking:** block matching titles from a listing's context menu and remember their leaders across refreshes and reloads. Remove individual entries or clear the list under Settings → Blocks, independently of player notes.
- **Player notes:** share positive, neutral, or blocked-player records across characters on the account, with reminders when you group again. Import and export your notes.
- **Mythic+ history:** keep a per-character history of runs, key levels, dates, and teammates, then add notes from past runs.
- **Interface settings:** change the main-window key binding, overall scale, and font size; the floating window has its own scale setting. Clicking Settings again returns to the page you came from. Automatically integrate with the RurutiaSuite top bar or place the entry to the left of the skull in SEUI's marker bar when both the floating window and compatibility settings are enabled.

The interface uses native Lua with bundled LycheeUI. Feature modules load on demand; no separate UI library installation is needed.

See the [product document](Product.md) for implementation and verification coverage.

## Installation

1. Download or clone this repository.
2. Copy the four folders in [`addon/`](addon) to `World of Warcraft/_retail_/Interface/AddOns/`:

   ```text
   LycheeGroup
   LycheeGroup_Group
   LycheeGroup_Notes
   LycheeGroup_UI
   ```

3. Start or restart the game, enable Lychee LFG in the addon list, and type `/lg` to open it.

## Commands

| Command | Action |
| --- | --- |
| `/lg` | Toggle the main window |
| `/lg create` | Create and manage a group |
| `/lg notes` | Open player notes |
| `/lg settings` | Open settings |
| `/lg floattest` | Temporarily show the standalone floating window at screen center; run again to restore. Uses the current live floating window. |
| `/lg note` | Record your current player target |
| `/lg note Name-Realm reason` | Record a player by name |

`/lycheegroup` is an alias for `/lg`.

Hold the bottom-right resize grip: drag horizontally to change width, vertically to change height, or diagonally to change both. A minimum size keeps controls usable and increases with larger fonts. Pages rearrange while preserving current input and selections. Releasing saves this character's size for reopening and reloading. Window dimensions, overall scale, and font size are separate controls.

The default main-window key is the English semicolon `;`. It is assigned only when the addon has no binding and the key is free. Change it under Access & shortcuts. Under Appearance, adjust the main window from 75% to 125% and the font size from 70% to 130% (100% is the existing baseline; changes apply immediately), choose the game language, Simplified Chinese or English (applied after reloading), and select a font. The bundled LycheeFont uses the complete YaHei font for the Chinese UI and Inter for the English UI; game and shared fonts remain available.

## Development

Version 1.1.5 exposes `LycheeGroup.API.Floating` for existing top bars and other entry points. It supports status subscriptions, attachment, refresh, release, and the shared popup. See the [interface contract](Architecture.md#92-浮窗公开接口). The bundled [RurutiaSuite adapter](addon/LycheeGroup/Adapters/Rurutia.lua) and [SEUI adapter](addon/LycheeGroup/Adapters/SEUI.lua) live in `Adapters/` and demonstrate the public interface.

Run the offline tests from the repository root with Lua 5.1:

```sh
lua tests/runner.lua
```

Select specific modules by adding their names, for example `lua tests/runner.lua core notes`. Unknown module names produce an error and a nonzero exit code. See the [validation guide](tests/theme_reload.md) for theme reload, layout, pinned-main comparison, and memory checks.

For the local widget-tree preview, run `lua tests/ui_preview.lua`, then open [`tests/ui-preview.html`](tests/ui-preview.html). The generated `tests/preview-data.js` stays local and is not committed. This preview uses sample data and does not verify in-game behavior.

[`tools/Build-Addon.ps1`](tools/Build-Addon.ps1) builds the addon archive. It syncs the bundled library from a sibling `LycheeUI` source directory by default; use `-LibraryPath` to select another location.

Project documents (in Chinese): [Product](Product.md) · [Design](Desgin.md) · [Architecture](Architecture.md) · [Performance](perfermance.md) · [Third-party configuration API](API.md) · [Development rules](Development.md) · [Documentation and changelog rules](Agents.md). The product document describes the current implementation and in-game validation coverage.

The current release is 1.2.4; release notes are in the [changelog](CHANGELOG.md). This release uses [Theme API v2](API.md): account or character themes apply at login or reload, while font size, scale, window size, and table preferences remain live. Business behavior and the default UI are compared against the pinned main commit. See [Development.md](Development.md) for development rules and [theme reload validation](tests/theme_reload.md) for verification methods. Edit LycheeUI in its source directory and use the sync tool to update the embedded copy; [.lock](../LycheeUI/.lock) records its freeze status. Shared-library contracts are in its [README](../LycheeUI/README.md), [API](../LycheeUI/API.md), and [design specification](../LycheeUI/DESIGN.md).

See the [library notes](addon/LycheeGroup_Group/Libs/README.md) for bundled third-party sources and licenses.
