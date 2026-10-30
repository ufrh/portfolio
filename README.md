# Outfit Studio

This repository is now scoped to Outfit Studio only. The previous three-showcase workspace is preserved on branch `archive/portfolio-before-clean-slate-2026-10-30` for later reference and porting.

## Setup (Windows)

1. From this repository directory, run `rokit install`. The root `rokit.toml` pins Rojo 7.7.1.
2. Verify with `rojo --version`.
3. Run `START.bat` to launch the Outfit Studio Rojo server on `localhost:34876`.
4. Open the Outfit Studio place in Roblox Studio, then connect the Rojo plugin to port 34876.
5. Run `STOP.bat` to stop the tracked server.

Rojo diagnostics are in `.run/rojo.log` and `.run/rojo.err.log`. Source code and shared FORGE dependencies are in `src/outfit/` and `src/shared/`. The authored Studio UI and mannequin remain in the Roblox place, not in Rojo source. There is no background Git watcher or automatic pull.

The older Inventory and Backrooms showcases and all former launch scripts are available on the archive branch. Outfit service and scripts have been retained for selective porting/refinement; no Studio play test is implied.
