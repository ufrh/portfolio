# Roblox Portfolio

One Roblox experience with three showcase places, sharing a single `src/` source tree.

- Outfit Studio — `outfit.project.json`
- Inventory & Equipment — `inventory.project.json`
- Backrooms Generator — `backrooms.project.json`

## Windows workflow

Double-click `START_PORTFOLIO.bat` and choose a place (1–3), or launch it with an argument: `START_PORTFOLIO.bat outfit`. Only the selected Rojo server runs at a time. Connect the Rojo Studio plugin at `localhost:34876` while the matching Roblox Studio place is open.

- `STOP_PORTFOLIO.bat`: stop Rojo and the optional Git watcher.
- `PUSH_PORTFOLIO.bat`: prompt for a commit message, then commit and push `main`.
- `START_PORTFOLIO.bat`: starts the Rojo server and a safe Git watcher (if Git is initialized).

## Source

- `src/shared/`: code used by all three places
- `src/outfit/`: Outfit Studio scripts
- `src/inventory/`: Inventory & Equipment scripts
- `src/backrooms/`: Backrooms Generator scripts

Every place lives **inside the same published Roblox experience**, but has its own PlaceId. Set your actual place IDs in `src/shared/ReplicatedStorage/PortfolioShared/PlaceIds.luau` after publishing.

Outfit Studio uses FORGE v3.2.0 from the private `ufrh/Ruckus` Git submodule at `vendor/ruckus`. Initialize it with `git submodule update --init --recursive` before starting Outfit Studio. GitHub access to Ruckus is required; its source is not published in this repository. Functional gameplay modules should remain portable.

See `docs/SETUP.md`. This commit is scaffolding only.
