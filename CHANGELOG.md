# Changelog

Notable changes to ComboNext are documented here.

## [Unreleased]

- No unreleased changes yet.

## [1.37] - 2026-10-25

- "Health below N%" triggers now work on your target: set the "Effect on" button to target before choosing the trigger. Target health is checked twice a second and re-arms when the target changes.

## [1.36] - 2026-10-25

- Added effect family triggers (Wound, Poison, Disease, Fear, Corruption, Cry, Song, Elemental, Physical, Tactical) alongside exact-name effect triggers.
- Added "Health below N%" triggers (10/20/30/50/75%) that re-arm once health recovers.
- Items (for example potions) can now be used as triggers and finishers.
- Family and health triggers are supported in combo import/export.
- Fixed the verify command failing on skills that cannot report a name and on unused finisher slots.

## [1.35] - 2026-10-25

- Published the initial public GitHub repository for ComboNext.
- Includes the combo advisor, sequence editor, class skill and effect catalogs, settings, localization, and combo text import/export.

## Earlier versions (1.0-1.34, reconstructed)

These notes were reconstructed from the final feature set, not from per-release records, so the grouping into versions is approximate. Each entry includes the incremental updates made along the way (for example 1.30-1.34 belong to 1.3).

### [1.3]

- Effect triggers: react to effects gained or lost on yourself or your target, with an effects catalog and search.
- Triggers from captured chat phrases and NPC speech.
- Any-order sequences, multi-step combos with several finisher rules, and a combo chooser with rename and delete.
- Combo import/export (text sharing) with undo for imports.
- Interface scale, color themes, finisher slot count, reset timer and "always offer first finisher" options.
- Localization in English, German and French.
- `/combnext verify` self-checks.

### [1.2]

- Class skill catalog with localized skill names, so triggers are matched by name instead of raw hex IDs.
- Detection of local skill use from trained-skill cooldown events, in addition to combat chat parsing.
- Multiple visible finishers, including items dropped from the action bar.
- Fixes for skill identity matching and duplicate event handling.

### [1.1]

- Player-created combo editor with numbered slots, drag and drop from the action bar, and a skill catalog browser.
- Finisher quickslots that clear once the recommended skill is used.

### [1.0]

- First player-controlled combo advisor: you define skill sequences, ComboNext observes the skills you use and shows the recommended next skill. It never casts anything automatically.
- Movable advisor window with EDIT, OPTIONS and HIDE controls and the `/combnext` command.
