# Roblox Portfolio

Playable Roblox development showcases: Outfit Studio, Inventory & Equipment, and Backrooms Generator.

This repository uses separate Rojo projects for three places in one Roblox experience. See `docs/SETUP.md` for Studio setup, place publishing, and the local start/stop workflow.

## Places

- `places/outfit-studio` — avatar outfit creator
- `places/inventory-equipment` — inventory and equipment demo
- `places/backrooms-generator` — procedural architecture demo

## Local development

From repository root, run `scripts/start.ps1 -Place outfit-studio` (or `inventory-equipment` / `backrooms-generator`). To end the Rojo session, use `scripts/stop.ps1`. For each place, connect the Rojo Studio plugin to localhost while that place is open in Studio.

FORGE can power the showcase interfaces, but is kept as a private/local dependency; the functional systems should remain portable.
