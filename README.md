# Synergy Loadout Master - Stat Export

`Synergy Loadout Master - Stat Export` is a small World of Warcraft addon that exports your current character stats for use in the Synergy Loadout Master website.

It is intended for the Echo Planner and Echo Admin tools, where imported stats are used to evaluate dynamic echo formulas more accurately.

## Installation

1. Copy the folder [SynStatExport] into your WoW `Interface/AddOns/` directory.
2. Start the game or run `/reload`.
3. Make sure the addon is enabled on the character selection screen.

## Commands

- `/slmstats`
  Exports your current character stats and opens a popup with the share string.

- `/slmshow`
  Reopens the most recent exported share string.

- `/slmstats help`
  Shows the available commands in chat.

## How To Use

1. Log into the character whose stats you want to export.
2. Run `/slmstats`.
3. A popup window will appear with the export string already selected.
4. Copy the string.
5. Open the Synergy Loadout Master website.
6. Go to the Echo Planner.
7. Use the `Import Stats` action and paste the exported string.

## What Gets Exported

The addon exports the stats currently used by the website formula system, including:

- Level
- Spell Power
- Attack Power
- Armor
- Strength
- Agility
- Stamina
- Intellect
- Spirit
- Crit
- Haste
- Hit
- Resilience

## Notes

- The addon does not automatically copy to the system clipboard. WoW does not reliably allow that.
- The popup selects the full export string automatically so it can be copied manually.
- The export is also stored in `SavedVariables` under `SynStatExportDB.lastExport`.
