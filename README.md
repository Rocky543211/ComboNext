# ComboNext

ComboNext is a player-created combo advisor for **The Lord of the Rings Online**. It watches combat activity and displays configured skill suggestions; it never casts skills for you.

## Features

- Create and edit named combos with skill triggers and recommended finishers.
- Match triggers from combat chat, local skill-use events, captured chat phrases, and configured effects.
- Connect individual triggers with AND/OR, using ordered events, any-order events, or current conditions.
- Check effect families, exact raid effects, and health thresholds on yourself or your target.
- Choose trigger skills from the class skill catalog or drag shortcuts from your action bar.
- Share combo configurations by exporting text to copy or importing text from another player.
- Customize the advisor's opacity, scale, colors, reset timer, and finisher display.
- Optionally hide finishers until ready, using skill cooldowns and player-configured item timers.
- Use the English, German, or French interface.

## Install

1. Download this repository (for example, choose **Code → Download ZIP** on GitHub) and extract it.
2. Copy the `ComboNext` folder, including `ComboNext.plugin` and all `.lua` files, into your LOTRO plugins folder:

   `Documents/The Lord of the Rings Online/Plugins/ComboNext`

   If your LOTRO documents folder is in a different location, use that folder's `Plugins` directory instead.
3. In LOTRO, open the plugin manager and load **ComboNext**.

## Use

Open the combo editor in-game with `/combnext edit` or click **EDIT** on the advisor. Create a combo, set its trigger skills, then add a finisher by choosing a catalog skill or dragging a skill or item shortcut from your action bar into a finisher slot.

Useful slash commands:

| Command | Action |
| --- | --- |
| `/combnext` or `/cn` | Show available command usage |
| `/combnext show` | Show the advisor |
| `/combnext hide` | Hide the advisor |
| `/combnext edit` | Open the combo editor |
| `/combnext options` | Open advisor options |
| `/combnext quiet` | Toggle quiet mode |
| `/combnext verify` | Run plugin checks |
| `/combnext verify catalog` | Also verify the skill catalog |

Use **Share combos** in the editor to export or import combo text. Imports can be added to the current combos or replace them; the editor also offers an undo option for an import.

### Trigger logic

**AND is the default between triggers.** Click the AND/OR label on a trigger slot
to toggle its connection to the previous trigger. Alternatively, select that trigger
and use the connection button above its details. The first trigger has no preceding
connection; finishers are not connectors.

For example, add **Health below 50%**, then **Poison**, and set the Poison trigger's
connection to **OR**. Either low health or poison can recommend that rule's skill.
Use **AND** instead to require both.

AND binds before OR: `Poison OR Health below 50% AND Wound` means
`Poison OR (Health below 50% AND Wound)`. Different trigger/finisher rules inside
one combo keep their own connections.

The trigger-mode button below **Share combos** now only chooses how triggers are
observed; there are no combo-wide OR choices:

| Mode | Meaning |
| --- | --- |
| Ordered events | Events within an AND group must happen in order; OR separates alternative groups. |
| Any-order events | All events within an AND group must happen, in any order; OR separates alternatives. |
| Current conditions | Check each condition now, combining them with its individual AND/OR connection. |

For "poisoned OR health below 50%", choose **Current conditions** to check your
current state rather than waiting for poison/health events.
Existing combos keep their ordered/any-order behavior and default AND connections.
Former combo-wide OR rules are automatically converted to individual OR connections.
In current-condition mode, an effect set to **gained** means currently active and **lost**
means currently absent. Health means currently below the threshold. Skill, item-use,
and chat triggers count as recent events for the configured reset time. For example,
an active Poison AND health below 20% works whichever became true first, and stops
qualifying if the poison clears or health recovers. A missing target or unreadable
condition is unknown, not proof that an effect is absent.

Conditions are refreshed twice per second. After using a finisher, a continuously
true condition rule must stop qualifying before it can recommend again. Switching
targets resets rules that depend on the old target.

The advisor status explains the next missing event or unmet current condition.
An effect family and an individual effect remain independent selections. A single
effect event can satisfy either in separate rules, but advances at most one step
per event-based rule. In condition modes, both can be true simultaneously.
**A generic Wound rule still matches special raid wounds:** a separate exact-effect
rule does not automatically exclude those wounds from the generic rule. Do not
configure a generic potion rule where that would be unsafe.

### Finisher readiness

In **OPTIONS**, choose **ready only** or **show even on cooldown**. The default
keeps the previous show-always behavior. Ready-only hides unavailable skills,
missing items, and unknown readiness; hiding a finisher does not consume it or
discard its completed event progress. A condition-based rule must still qualify
when the finisher becomes ready.

Skills use the game's trained-skill cooldown and usability information. For an item,
select its slot in the editor, enter its cooldown in seconds (1-3600), then **Save**.
If you know the item is ready, click **Mark ready**. This explicitly initializes
the timer; otherwise its readiness remains unknown until observed use.

Item timers start when ComboNext recognizes the item's use in combat chat. They are
estimates, not the game's actual item cooldowns. Use the show-always setting if your
item does not produce a recognizable chat message. Timers for the same item name
are shared across its combo entries, but shared cooldowns between different items
are not detected. After reloading the plugin, item readiness is unknown again.
Mark ready only after checking the actual cooldown in-game.

New exports use `CN3` to preserve each trigger's AND/OR connection, trigger modes
and item timer durations. Existing `CN1` and `CN2` exports can still be imported;
older combo-wide OR modes are converted automatically. `CN3` requires ComboNext
1.39 or later.

### Verification

`/combnext verify` and `/combnext verify catalog` report **PASS**, **FAIL**, or
**NOT CHECKED**. Not checked means LOTRO did not expose enough information, rather
than that the configuration passed. The summary includes all three counts.
Unobserved item timers and unreadable skill shortcuts are explicitly reported.

For local regression checks without LOTRO, run `lua tests/run.lua` from this
folder. These use mocked game APIs; they do not replace in-game checks.

## Updating

Download the latest repository files and replace the installed `ComboNext` plugin files. Keep a copy of your LOTRO plugin data if you want to preserve a backup of your settings.

## Compatibility and support

ComboNext runs as a LOTRO client plugin and uses LOTRO's plugin APIs. For problems, open an issue in this repository and include the command output from `/combnext verify` when possible.

## License

No license is currently specified. Unless a license is added, the default copyright restrictions apply; ask the author for permission before redistributing or modifying the code.
