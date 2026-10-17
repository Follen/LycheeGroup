# Lychee LFG

[简体中文](README.md) · English

A group-finding addon for retail World of Warcraft. Find groups, manage recruitment, and keep notes on players you meet, all in one window.

Version **1.0.0** targets retail **12.1.5** (Interface `120105`) and supports Chinese and English.

## Features

- **Find groups:** browse dungeons, raids, delves, PvP, and other activities. Search and filter listings, inspect members, and track applications.
- **Manage recruitment:** create and edit listings, review applicants, and invite players.
- **Player notes:** save positive, neutral, or blocked-player records, with reminders when you group again. Import and export your notes.
- **Mythic+ history:** keep a per-character history of runs, key levels, dates, and teammates, then add notes from past runs.

The interface uses native Lua with bundled LycheeUI. Feature modules load on demand; no separate UI library installation is needed.

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

## Development

Run the offline tests from the repository root with Lua 5.1:

```sh
lua tests/runner.lua
```

[`tools/Build-Addon.ps1`](tools/Build-Addon.ps1) builds the addon archive. It syncs the bundled library from a sibling `LycheeUI` source directory by default; use `-LibraryPath` to select another location.

Project documents (in Chinese): [Product](Product.md) · [Design](Desgin.md) · [Architecture](Architecture.md) · [Performance](perfermance.md). The product document describes the current implementation and in-game validation coverage.

See the [library notes](addon/LycheeGroup_Group/Libs/README.md) for bundled third-party sources and licenses.
