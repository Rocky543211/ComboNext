# ComboNext

ComboNext is a player-created combo advisor for **The Lord of the Rings Online**. It watches combat activity and displays configured skill suggestions; it never casts skills for you.

## Features

- Create and edit named combos with skill triggers and recommended finishers.
- Match triggers from combat chat, local skill-use events, captured chat phrases, and configured effects.
- Choose trigger skills from the class skill catalog or drag shortcuts from your action bar.
- Share combo configurations by exporting text to copy or importing text from another player.
- Customize the advisor's opacity, scale, colors, reset timer, and finisher display.
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

## Updating

Download the latest repository files and replace the installed `ComboNext` plugin files. Keep a copy of your LOTRO plugin data if you want to preserve a backup of your settings.

## Compatibility and support

ComboNext runs as a LOTRO client plugin and uses LOTRO's plugin APIs. For problems, open an issue in this repository and include the command output from `/combnext verify` when possible.

## License

No license is currently specified. Unless a license is added, the default copyright restrictions apply; ask the author for permission before redistributing or modifying the code.
