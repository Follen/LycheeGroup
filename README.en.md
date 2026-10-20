# Lychee LFG

[简体中文](README.md) · English

A group-finding addon for retail World of Warcraft. Find groups, manage recruitment, and keep notes on players you meet, all in one window.

The current version is **1.1.5**, targeting retail **12.1.5** (Interface `120105`) with Chinese and English support. See the [changelog](CHANGELOG.md) for release notes (in Chinese).

## Features

- **Find groups:** browse dungeons, raids, delves, PvP, and other activities. Search and filter listings, read listing descriptions, inspect members, and track applications.
- **Manage recruitment:** create and edit listings, inspect applicants' Mythic+ records and known factions, and invite players. Click the star beside the activity to save the current settings. Applying a favorite preserves your current title and description for you to review and publish; publishing does not save a creation history. Small-group activities show current members directly; raid activities show subgroup rosters on hover. Current-season raids also show class-buff coverage.
- **Character preferences:** keep application roles, category filters, and sorting separately for each character across reloads. Enable automatic application separately for each session.
- **Player notes:** share positive, neutral, or blocked-player records across characters on the account, with reminders when you group again. Import and export your notes.
- **Mythic+ history:** keep a per-character history of runs, key levels, dates, and teammates, then add notes from past runs.
- **Interface settings:** change the main-window key binding and overall scale; the floating window has its own scale setting. RurutiaSuite top bar integration is detected automatically and can be toggled in the floating window settings.

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

The default main-window key is the English semicolon `;`. It is assigned only when the addon has no binding and the key is free. Change it under Access & shortcuts. Under Appearance, adjust the main window from 75% to 125%, choose the game language, Simplified Chinese or English (applied after reloading), and select a font. The bundled LycheeFont uses the complete YaHei font for the Chinese UI and Inter for the English UI; game and shared fonts remain available.

## Development

Version 1.1.5 exposes `LycheeGroup.API.Floating` for existing top bars and other entry points. It supports status subscriptions, attachment, refresh, release, and the shared popup. See the [interface contract](Architecture.md#92-浮窗公开接口). The bundled RurutiaSuite adapter lives in [`Adapters/Rurutia.lua`](addon/LycheeGroup/Adapters/Rurutia.lua) and demonstrates the public interface.

Run the offline tests from the repository root with Lua 5.1:

```sh
lua tests/runner.lua
```

Select specific modules by adding their names, for example `lua tests/runner.lua core notes`. Unknown module names produce an error and a nonzero exit code.

For the local widget-tree preview, run `lua tests/ui_preview.lua`, then open [`tests/ui-preview.html`](tests/ui-preview.html). The generated `tests/preview-data.js` stays local and is not committed. This preview uses sample data and does not verify in-game behavior.

[`tools/Build-Addon.ps1`](tools/Build-Addon.ps1) builds the addon archive. It syncs the bundled library from a sibling `LycheeUI` source directory by default; use `-LibraryPath` to select another location.

Project documents (in Chinese): [Product](Product.md) · [Design](Desgin.md) · [Architecture](Architecture.md) · [Performance](perfermance.md) · [Documentation and changelog rules](Agents.md). The product document describes the current implementation and in-game validation coverage.

Version 1.1.5 bundles LycheeUI 1.2.0 (revision 22), with shared selection and menu transitions. The source library and embedded copy match. The user has lifted the freeze recorded in [.lock](../LycheeUI/.lock). See the [integration guide](../LycheeUI/README.md), [API](../LycheeUI/API.md), and [component design specification](../LycheeUI/DESIGN.md).

See the [library notes](addon/LycheeGroup_Group/Libs/README.md) for bundled third-party sources and licenses.
