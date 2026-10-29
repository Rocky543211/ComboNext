# ComboNext

ComboNext is a player-created combo advisor for **The Lord of the Rings Online**. It watches combat activity and displays configured skill suggestions; it never casts skills for you.

## Features

- Create and edit named combos with skill triggers and recommended finishers.
- Match triggers from combat chat, local skill-use events, captured chat phrases, and configured effects.
- Connect individual triggers with AND/OR, using ordered events, any-order events, or current conditions.
- Check effect families, exact raid effects, and health thresholds on yourself or your target.
- Use class resources and states as triggers inside the corresponding class catalog.
- Choose trigger skills from the class skill catalog or drag shortcuts from your action bar.
- Share combo configurations by exporting text to copy or importing text from another player.
- Customize the advisor's opacity, scale, colors, reset timer, and finisher display.
- Use a decorative race/class skin across the advisor, editor, options, and sharing windows, or switch to Classic.
- Optionally hide finishers until ready, using skill cooldowns and player-configured item timers.
- Assign combo priorities from 1 (highest) to 9 (lowest), with equal priorities allowed.
- Use the English, German, or French interface.

## Install

1. Download this repository (for example, choose **Code → Download ZIP** on GitHub) and extract it.
2. Copy the `ComboNext` folder, including `ComboNext.plugin`, all `.lua` files, and the complete `Resources` directory, into your LOTRO plugins folder:

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

### Appearance

Use **Combo Slots** and its **- / +** buttons in **OPTIONS** to decrease or
increase the number of visible recommendation slots, from 1 to 9, without
cycling through every value. Changes apply immediately and are saved.

Open **OPTIONS** (or the plugin manager's options panel). **Window style** switches
between the new **Decorative** skin and **Classic** LOTRO controls immediately,
including windows already open. Appearance settings are saved per character;
switching styles does not change combos, priorities, triggers, or matched progress.

The decorative skin uses dark opaque panels, ornamental headers, warm text,
race accents and an optional class badge. It includes its own original artwork
and does **not** require StatCaps.

| Appearance | Result |
| --- | --- |
| Automatic race + class | Detect your character's race for the accent/emblem and class for the badge. |
| Race theme | Choose a race accent/emblem, without a class badge. |
| Class theme | Choose a class accent/badge with the neutral Gondorian emblem. |
| Race theme + class badge | Select the race and class independently; either selector can remain Automatic. |
| Colour only | Use the existing gold, blue, violet, or green colour selection, with a neutral emblem and no class badge. |

The existing **Colors** button switches to Colour only. Previously selected
non-default colors are retained on update. Manual choices include all twelve
classes and Gondorian, Man, Elf, Dwarf, Hobbit, Beorning, High Elf, Stout-axe, and
River Hobbit race themes. Gondorian is a decorative theme, not a separate detected
game race.

If LOTRO does not expose a recognized race or class, the options status explains
the fallback: the neutral Gondorian theme and/or no class badge. Choose a manual
mode to override unavailable detection. Manual decorative choices are retained
when Classic is selected. Window headers remain draggable; auxiliary windows
have a close button and support Escape. Interface scaling keeps the editor within
the available screen height, including 1280x720 displays.

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

### Combo priority

In **EDIT**, choose a combo and click **Prio: None** beside **CLEAR ALL**. Select
**Priority 1** (highest) through **Priority 9** (lowest), or **No priority** (the
default). The setting applies to the whole combo, including all of its finisher
rules, and is saved immediately. The combo chooser marks assigned priorities
with `(P1)` through `(P9)`.

When several combos qualify, recommendations appear in priority order:
**1, 2, ... 9, then no priority**. Multiple combos can share the same priority.
Ties use the combo list's order (normally the older combo first), with each
combo's finishers keeping their own order. Priority does not rearrange the combo
list itself and does not let an unmet combo block one that qualifies.

This applies whether you display one finisher or several. Ready-only mode still
skips unavailable or unknown finishers, so a lower-priority ready finisher can
appear before a higher-priority one on cooldown. With show-on-cooldown enabled,
the higher-priority recommendation stays first. Changing priority does not clear
matched progress. New combos and imports from older share formats have no priority.

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

### Class resource and state triggers

Open **EDIT**, select a trigger slot, then choose the corresponding class in the
catalog selector. Class conditions appear before that class's skills, **not under
Effects**. Select one, then use the comparison button and value field at the bottom
and click **Save**. Comparisons are `<`, `<=`, `=`, `>=`, and `>`; values must be
whole numbers within the displayed range. Yes/no states use `= 1` or `= 0`.

Bounded resources have a separate **`>=` entry for every tier**: Focus 1-9,
Fervour 1-5, Wrath 1-100, battle/healing attunement 1-9 each, Mettle 1-9,
Fortification 1-5, and Advanced Technique 1-5. Use the catalog search or page
buttons to find the required tier. Each preset remains editable, including zero
and other comparisons; existing combos keep their saved values. Mariner balance
keeps one editable raw-value entry because its in-game scale is not verified.
Stances, forms, charged states, and gambit builder identities are not resource tiers.

| Class | Conditions |
| --- | --- |
| Hunter | Focus (0-9); Endurance, Precision, Strength stances |
| Champion | Fervour (0-5) |
| Beorning | Wrath (0-100); bear form |
| Rune-keeper | Battle/healing attunement (0-9 each); charged state if exposed by LOTRO |
| Mariner | Balance, using the raw value returned by LOTRO |
| Brawler | Mettle (0-9), derived from Battle Flow effects |
| Guardian | Fortification stacks (0-5), derived from Improved Fortification effects |
| Warden | Advanced Technique stacks (0-5); individual gambit slots; Assailment/Determination stances |
| Minstrel | Melody, Dissonance, Resonance stances |

No dedicated resource reader is added for Burglar, Captain, or Lore-master.
Their existing skill and effect triggers remain available.

For example, choose **Hunter > Focus >= 5** for a skill that requires five Focus.
In **Current conditions**, it qualifies while you have at least five Focus. You can
combine it with health, effects, skills, or other class conditions using the
existing per-trigger AND/OR connections. Conditions cannot be finishers and do
not activate anything.

A `Focus >= 3` trigger still qualifies at three Focus even if its finisher costs
five. ComboNext does not infer a skill's resource cost: choose the matching tier
and **Current conditions** to require that resource amount right now. Event modes
remember a threshold crossing and can retain it after the resource falls again.

In event modes, a class comparison fires when it first becomes true, including
the first available reading. It must become false before firing again; reloading
or editing the combo resets that tracking. Multiple thresholds becoming true
together advance at most one step of an event-based rule. Direct resource, stance,
and gambit notifications refresh immediately when available; polling every 0.5
seconds also covers missed notifications, bear/charged states, and effect stacks.
Unobserved changes between polls cannot be reconstructed.

Rune-keeper attunement is converted from the API's neutral value of 10: lower
values become battle attunement, higher values become healing attunement.
Mariner balance intentionally has no guessed fore/aft or neutral mapping; consult
the progress message for its current raw value. Its editable -1000 to 1000 range
is an input limit, not a claimed in-game resource scale.
Warden gambit values are `0 = empty`, `1 = spear`, `2 = shield`, `3 = fist`;
unverified builder types or unavailable slots are unknown, not empty.

Stance readings remain unknown until you explicitly select a stance after loading
the plugin or a detected trait/skill-list change, because LOTRO can otherwise
report stale stance values. Unsupported APIs, wrong-class conditions, and unreadable
values stay **unknown** and cannot satisfy a condition. Mettle effect names are
supported in English, German, and French. Fortification and Advanced Technique
effect names are currently verified only in English; other languages report
unknown rather than guessing zero stacks. These integrations have mocked-API
coverage, not live validation for every class.

### Sharing compatibility

New exports use `CN5` to preserve combo priorities and class conditions as well as each trigger's
AND/OR connection, trigger modes, and item timer durations. Existing `CN1`, `CN2`,
`CN3`, and `CN4` exports can still be imported; they default to no priority, and
older combo-wide OR modes are converted automatically. `CN5` requires the updated
ComboNext 1.4 with priority support (2026-10-25) or a subsequent release.
Invalid priorities or class conditions reject an import rather than silently
changing its ordering or weakening its trigger requirements.

### Verification

`/combnext verify` and `/combnext verify catalog` report **PASS**, **FAIL**, or
**NOT CHECKED**. Not checked means LOTRO did not expose enough information, rather
than that the configuration passed. The summary includes all three counts.
Unobserved item timers and unreadable skill shortcuts are explicitly reported.
Class-trigger coverage also reports wrong-class, unavailable API, unconfirmed
stance, and unsupported effect-language readings as **NOT CHECKED**.

For local regression checks without LOTRO, run `lua tests/run.lua` from this
folder. `luajit tests/run.lua` also checks Lua 5.1 compatibility.
Run `python -B -m unittest discover -s tests -p 'test_*.py'` for packaged-artwork
reproducibility, dimensions, and button-text contrast checks. The optional
`python build_skin.py` command regenerates the bundled TGA artwork using only the
Python standard library; `--preview /path/to/preview.png` also produces an artwork
contact sheet, not a screenshot of the running plugin.

These checks use mocked game APIs or inspect generated files; they do not replace
in-game checks of fonts, skin layering, textures, and mouse/keyboard interaction.

## Updating

Download the latest repository files and replace the installed `ComboNext` plugin files. Keep a copy of your LOTRO plugin data if you want to preserve a backup of your settings.

### Versioning policy

Use at most one new version number per calendar day, using the maintainer's local
date. All changes on 2026-10-25 belong to **1.4**; the graphical update on
2026-10-29 is **1.5**. Additional commits or uploads on the same day keep the existing
version and update its dated changelog entry. On the next day with changes, advance
to the next version (1.6, then 1.7, and so on); days without changes do not create releases.
Keep `Constants.lua`, `ComboNext.plugin`, and the changelog consistent. This replaces
the earlier per-update version numbering; existing Git history is left unchanged.

## Compatibility and support

ComboNext runs as a LOTRO client plugin and uses LOTRO's plugin APIs. For problems, open an issue in this repository and include the command output from `/combnext verify` when possible.

## License

No license is currently specified. Unless a license is added, the default copyright restrictions apply; ask the author for permission before redistributing or modifying the code.
