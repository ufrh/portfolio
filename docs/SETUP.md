# Local setup

The Portfolio is **one Roblox experience with three places**, not three separate experiences.

1. Create the three places in the same experience in Roblox Creator Hub.
2. Clone: `git clone https://github.com/ufrh/portfolio.git`
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

FORGE can be installed locally in Studio; this repo does not expose the framework source.
