# Local setup

The Portfolio is **one Roblox experience with three places**, not three separate experiences.

1. Create the three places in the same experience in Roblox Creator Hub.
2. Clone with dependencies: `git clone --recurse-submodules https://github.com/ufrh/portfolio.git` (requires GitHub access to private `ufrh/Ruckus`).
3. Install Rojo 7.x and Rojo Studio plugin.
4. Double-click `START_PORTFOLIO.bat` and choose one place.
5. Open that matching place in Roblox Studio and connect the Rojo plugin at `localhost:34876`.
6. To switch places, disconnect Rojo, open the other Studio place, and restart using `START_PORTFOLIO.bat` with the other selection.
7. Stop with `STOP_PORTFOLIO.bat`; commit/push using `PUSH_PORTFOLIO.bat`.

The start launcher leaves its console running to pull GitHub changes from `origin/main` safely. It will **not** pull over uncommitted local changes, ahead commits, or branch divergence. The watcher doesn't push automatically.

You can use a downloaded ZIP to run Rojo, but the live Git watcher and push shortcut require a real Git clone with a `.git` directory.

## Place mapping

`outfit.project.json` => `src/outfit/`
`inventory.project.json` => `src/inventory/`
`backrooms.project.json` => `src/backrooms/`

All three share `src/shared/`. Insert actual PlaceIds in `src/shared/ReplicatedStorage/PortfolioShared/PlaceIds.luau` after publishing.

## FORGE for Outfit Studio

For an existing clone, run `git submodule update --init --recursive` before starting Outfit Studio. Repeat after pulling a commit that updates the dependency. The live Git watcher does not initialize submodules automatically.

`outfit.project.json` maps the pinned framework from `vendor/ruckus/src/shared/` into ReplicatedStorage.FORGE, ServerScriptService.FORGE, and StarterPlayerScripts.FORGE. The supplied bootstraps start the server/client runtime. Services and Controllers can be added later; no Outfit behavior is implemented by this installation.

The dependency is pinned to Ruckus commit `f23e36f7448fd98fb91657aca5e191cf662af97e` (FORGE v3.2.0). Ruckus source remains private. Inventory and Backrooms do not load FORGE in their current project mappings.

GitHub edits reach Studio only through your existing local Git/Rojo workflow. This installation does not directly modify Studio.
