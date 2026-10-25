# Changelog

Notable changes to ComboNext are documented here.

Entries are grouped by release family (1.3 includes 1.30-1.39). Version groupings
before 1.35 were reconstructed from the feature set and are approximate.

## [Unreleased]

- No unreleased changes yet.

## [1.3] - through 1.39 (2026-10-25)

- Individual AND/OR connections between triggers replace combo-wide OR modes (1.39). AND is the default and binds before OR; clickable slot labels and a selected-trigger button change each connection.
- Ordered events, any-order events and current-condition modes respect the per-trigger connections. Existing 1.38 OR rules migrate automatically without changing their meaning.
- CN3 exports preserve the individual connections; CN1/CN2 imports remain supported.
- Live conditions check current health and active/absent effects rather than requiring threshold/effect events in a particular order. Skills and chat can be combined as recent events.
- Clearer progress messages show which event or condition is missing.
- Optional ready-only finisher display, using skill cooldowns/usability and configurable item timers with an explicit Mark ready action. Unknown readiness is hidden in ready-only mode.
- Exact effects and effect families remain independent; one physical effect event advances at most one step of each event-based rule.
- Verification distinguishes PASS, FAIL and NOT CHECKED, including unreadable skills and unknown item readiness.
- New CN2 exports preserve trigger modes and item timer durations; older CN1 text remains importable.
- Added mocked-game regression coverage for trigger modes, readiness, target changes, sharing, editor controls and verification.
- Effect triggers: gained/lost on yourself or your target, with an effects catalog and search.
- Effect family triggers: Wound, Poison, Disease, Fear, Corruption, Cry, Song, Elemental, Physical and Tactical, alongside exact-name effects.
- Health-below triggers at 10/20/30/50/75% on yourself or your target. Target health is checked twice a second and re-arms on target changes (1.37).
- Items, including potions, supported as triggers and finishers.
- Triggers from captured chat phrases and NPC speech.
- Multi-step combos with several finisher rules, and a combo chooser with rename and delete.
- Combo import/export (text sharing) with undo for imports.
- Interface scale, color themes, finisher slot count, reset timer and "always offer first finisher" options.
- Localization in English, German and French.
- `/combnext verify` self-checks; fixed crashes on unavailable skill-name APIs and false failures for unused finisher slots.
- Initial public GitHub repository, README and changelog (1.35).

## [1.2] - reconstructed

- Class skill catalog with localized skill names, so triggers are matched by name instead of raw hex IDs.
- Detection of local skill use from trained-skill cooldown events, in addition to combat chat parsing.
- Multiple visible finishers, including items dropped from the action bar.
- Fixes for skill identity matching and duplicate event handling.

## [1.1] - reconstructed

- Player-created combo editor with numbered slots, drag and drop from the action bar, and a skill catalog browser.
- Finisher quickslots that clear once the recommended skill is used.

## [1.0] - reconstructed

- First player-controlled combo advisor: you define skill sequences, ComboNext observes the skills you use and shows the recommended next skill. It never casts anything automatically.
- Movable advisor window with EDIT, OPTIONS and HIDE controls and the `/combnext` command.
