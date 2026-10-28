# Roblox Portfolio

Three independent, playable showcase places inside one Roblox experience.

- **Outfit Studio** — avatar outfit creator
- **Inventory & Equipment** — inventory, equipment and persistence
- **Backrooms Generator** — procedural room and corridor generation

## Quick start

Install Rojo 7.x and the Rojo Studio plugin, clone the repo, then open the corresponding Roblox place in Studio.

```powershell
.\scripts\start.ps1 -Place outfit-studio
.\scripts\stop.ps1
.\scripts\push.ps1 -Message "Add outfit showcase"
```

Available places: `outfit-studio`, `inventory-equipment`, `backrooms-generator`.

Each place has its own `default.project.json` and server/client scripts. Shared helpers live in `shared/`. FORGE remains a local/private UI dependency and is not copied into this public repository. The game features should remain independent of FORGE so they can be commissioned separately.

See [setup guide](docs/SETUP.md).
