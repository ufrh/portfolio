# Setup

## Roblox experience

Create **one Roblox experience with three distinct places**. Make Outfit Studio the start place. Add Inventory & Equipment and Backrooms Generator as additional places, and note their **PlaceIds**.

You must open the intended place in Roblox Studio before connecting the Rojo plugin. A Rojo session does not switch Studio places or publish them automatically.

## Local prerequisites

- Windows PowerShell, Git, Roblox Studio
- Rojo 7.x on PATH (or installed through Aftman)
- Rojo Studio plugin

## Workflow

From the repository root:

```powershell
.\scripts\start.ps1 -Place outfit-studio
.\scripts\start.ps1 -Place inventory-equipment
.\scripts\start.ps1 -Place backrooms-generator
.\scripts\stop.ps1
.\scripts\push.ps1 -Message "Describe changes"
```

`start.ps1` stops any previously tracked Rojo process before launching the selected project. `stop.ps1` stops only that tracked process. `push.ps1` commits staged changes and pushes the active Git branch; it does not publish Roblox places.

For the first connection, open the matching Studio place and connect the Rojo plugin to `localhost:34872`. When switching projects, disconnect/reconnect Rojo to the newly opened place.

## Place structure

`places/<place>/default.project.json` maps only that place's own scripts into StarterPlayerScripts and ServerScriptService, plus the common `shared/` directory into ReplicatedStorage.

Keep FORGE assets in the Studio place or in locally ignored dependencies until explicitly licensed/published. Each demo's gameplay logic must be usable without FORGE.

## Teleports

Once the three places are published, add their **actual PlaceIds** to `shared/PlaceIds.luau`. Studio testing of cross-place teleports is limited; test in a published experience.

## Notes

This commit establishes project scaffolding only. The outfit, inventory, and procedural systems are not implemented yet.
