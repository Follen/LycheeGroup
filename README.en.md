# Lychee LFG

[简体中文](README.md) · English

A group-finding addon for retail World of Warcraft. Find groups, manage recruitment, and keep notes on players you meet, all in one window.

Version **1.0.2** targets retail **12.1.5** (Interface `120105`) and supports Chinese and English. See the [changelog](CHANGELOG.md) (in Chinese) for version changes.

## Features

- **Find groups:** browse dungeons, raids, delves, PvP, and other activities. Search and filter listings, read listing descriptions, inspect members, and track applications.
- **Manage recruitment:** create and edit listings, inspect applicants' Mythic+ records and known factions, and invite players. Click the star beside the activity to save the current settings. Applying a favorite preserves your current title and description for you to review and publish; publishing does not save a creation history. Small-group activities show current members directly; raid activities show subgroup rosters on hover. Current-season raids also show class-buff coverage.
- **Player notes:** save positive, neutral, or blocked-player records, with reminders when you group again. Import and export your notes.
- **Mythic+ history:** keep a per-character history of runs, key levels, dates, and teammates, then add notes from past runs.
- **Interface settings:** change the main-window key binding and overall scale; the floating window has its own scale setting.

The interface uses native Lua with bundled LycheeUI. Feature modules load on demand; no separate UI library installation is needed.

The changes in 1.0.2 have passed offline regression checks and have been installed in the local game addon directory. This version has not yet been reloaded or verified in game; see the [product document](Product.md) for coverage.

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
| `/lg note` | Record your current player target |
| `/lg note Name-Realm reason` | Record a player by name |

`/lycheegroup` is an alias for `/lg`.

The default main-window key is the English semicolon `;`. It is assigned only when the addon has no binding and the key is free. The first settings category, Interface & Tooltips, lets you change it and scale the whole main window from 75% to 125%.

## Development

Run the offline tests from the repository root with Lua 5.1:

```sh
lua tests/runner.lua
```

[`tools/Build-Addon.ps1`](tools/Build-Addon.ps1) builds the addon archive. It syncs the bundled library from a sibling `LycheeUI` source directory by default; use `-LibraryPath` to select another location.

Project documents (in Chinese): [Product](Product.md) · [Design](Desgin.md) · [Architecture](Architecture.md) · [Performance](perfermance.md) · [Documentation and changelog rules](Agents.md). The product document describes the current implementation and in-game validation coverage.

See the [library notes](addon/LycheeGroup_Group/Libs/README.md) for bundled third-party sources and licenses.
