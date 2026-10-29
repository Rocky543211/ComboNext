# Changelog

Notable changes to ComboNext are documented here.

One version covers all changes made on the same calendar day in the maintainer's
local time. All changes on 2026-10-25, including further updates that day, are
version 1.4. Advance the version only on a later day with changes.
Earlier 1.0-1.2 entries were reconstructed from the feature set and are approximate.
The 2026-10-25 intermediate version labels are consolidated below; Git history is unchanged.

## [Unreleased]

- No unreleased changes yet.

## [1.5] - 2026-10-29

- Removed Window style and Appearance mode controls. The decorative skin remains enabled, with independent Race and Class selectors always available and Automatic as each selector's default. Existing manual choices are retained; obsolete style/mode settings no longer lock or change them.
- Renamed the options' NEXT slots control to Combo Slots and replaced cycling with separate minus/plus buttons. Values stay within 1-9, with unavailable directions disabled; both options surfaces update and save immediately.
- Themes now own panel tints, borders, button accents, and advisor highlights. Removed the separate Colors button and Colour only mode; old standalone color selections migrate to Automatic without modifying combos.
- Fixed ready-only filtering treating an expired cooldown as sufficient when skill usability was not exposed. Missing, failed, or non-boolean usability is now unknown and hidden, while show-even-on-cooldown remains unchanged.
- Restyled the advisor, combo editor, options, and sharing windows with standalone dark decorative panels, ornamental headers, race emblems, and class badges. Original bundled TGA artwork has no StatCaps dependency.
- Added live race/class appearance selection in both options surfaces. Manual choices cover nine race themes and all twelve classes.
- Unavailable race/class detection is explained in the options status instead of guessing a character identity.
- Added consistent button hover, pressed, disabled, and keyboard-focus states, native text input, draggable headers, close buttons, and Escape support for auxiliary windows.
- Kept combo configuration, priorities, trigger logic, readiness filtering, sharing, and matched progress unchanged by appearance settings.
- Adjusted automatic UI fitting to account for the full editor height on smaller screens.
- Localized appearance controls in English, German, and French. Added mocked appearance/control/layout regressions and standalone artwork reproducibility, format, and text-contrast checks; in-game rendering still requires validation in LOTRO.

## [1.4] - 2026-10-25

- Added combo-wide priority selection in the editor: 1 highest through 9 lowest, with no priority as the default after level 9. Multiple combos can share a level; ties keep combo-list order and each combo's finisher order.
- Priorities order single- and multi-finisher recommendations without clearing matched progress or bypassing readiness filtering. Priority survives chain editing and is saved for every rule in the combo.
- Added class resource/state triggers at the start of each corresponding class's catalog, separate from Effects: Hunter Focus/stances, Champion Fervour, Beorning Wrath/bear form, Rune-keeper attunement/charged state, Mariner raw balance, Brawler Mettle, Guardian Fortification, Warden Advanced Technique/gambit slots/stances, and Minstrel stances.
- Added individual `>=` catalog presets for every bounded resource tier: Focus 1-9, Fervour 1-5, Wrath 1-100, battle/healing attunement 1-9 each, Mettle 1-9, Fortification 1-5, and Advanced Technique 1-5. Presets remain editable and do not alter existing combo thresholds; unverified Mariner balance retains a configurable raw-value entry.
- Selected class triggers have comparison/value controls in the editor, support individual AND/OR connections, and work in current-condition and event modes. They cannot be finishers.
- Class notifications update immediately where available, with a half-second polling fallback. Event comparisons re-arm after becoming false; simultaneous thresholds are batched.
- Unsupported class APIs, wrong-class readings, unconfirmed stances, and unverified effect languages remain unknown, with progress details and honest verification coverage. Stances require explicit selection after loading or a detected trait/skill-list change.
- Mettle effect names support English/German/French. Fortification and Advanced Technique currently use verified English names only. Other localized effect triggers remain unchanged.
- CN5 sharing preserves combo priorities and class conditions and rejects malformed priorities/class records; CN1/CN2/CN3/CN4 imports remain supported and default to no priority.
- Expanded mocked-API regressions for class readers, boundaries, event re-arming, editor configuration, AND/OR integration, sharing, and verification.
- Added priority regressions for all nine levels, no-priority defaults, tied and grouped finishers, readiness, immediate editor updates, persistence, share imports/exports, and import undo.

- Individual AND/OR connections between triggers replace combo-wide OR modes. AND is the default and binds before OR; clickable slot labels and a selected-trigger button change each connection.
- Ordered events, any-order events and current-condition modes respect the per-trigger connections. Previous combo-wide OR rules migrate automatically without changing their meaning.
- Live conditions check current health and active/absent effects rather than requiring threshold/effect events in a particular order. Skills and chat can be combined as recent events.
- Clearer progress messages show which event or condition is missing.
- Optional ready-only finisher display, using skill cooldowns/usability and configurable item timers with an explicit Mark ready action. Unknown readiness is hidden in ready-only mode.
- Exact effects and effect families remain independent; one physical effect event advances at most one step of each event-based rule.
- Verification distinguishes PASS, FAIL and NOT CHECKED, including unreadable skills and unknown item readiness.
- Added mocked-game regression coverage for trigger modes, readiness, target changes, sharing, editor controls and verification.
- Effect triggers: gained/lost on yourself or your target, with an effects catalog and search.
- Effect family triggers: Wound, Poison, Disease, Fear, Corruption, Cry, Song, Elemental, Physical and Tactical, alongside exact-name effects.
- Health-below triggers at 10/20/30/50/75% on yourself or your target. Target health is checked twice a second and re-arms on target changes.
- Items, including potions, supported as triggers and finishers.
- Triggers from captured chat phrases and NPC speech.
- Multi-step combos with several finisher rules, and a combo chooser with rename and delete.
- Combo import/export (text sharing) with undo for imports.
- Interface scale, color themes, finisher slot count, reset timer and "always offer first finisher" options.
- Localization in English, German and French.
- `/combnext verify` self-checks; fixed crashes on unavailable skill-name APIs and false failures for unused finisher slots.
- Initial public GitHub repository, README and changelog.
- Adopted one version per day: all of today's updates use 1.4 rather than separate per-update version numbers.

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
