# Outfit Studio

Outfit Studio uses FORGE services/controllers with the existing StarterGui Catalog and Components templates. Rojo maps code only; the UI and showroom remain authored in Studio.

## Behavior

- Clothing, Accessories, Body, and Animations use Roblox catalog search, sorting, and cursor pagination. Previous pages are cached. Search responses from an older request cannot replace a newer category or query.
- Subcategories are cleared and populated at runtime from OutfitShared.Catalog. Prebuilt Components.SubCategories folders are not required.
- Item cards show names, creators, prices, and selection badges. Accessories, body assets, bundles, and outfits use rotating 3D mannequin previews in the authored ViewportFrames; 2D clothing keeps Roblox thumbnails.
- Try-on toggles supported assets; bundles apply supported constituent assets. Gear is browse-only.
- The server validates remote arguments and resolves asset types from Roblox, never from client metadata. Per-player mutation locks and rate limits prevent overlapping avatar changes.
- Automatic player spawning is disabled. Workspace.Rig stays in Workspace, is stripped to a bare baseline during server initialization, and is the creator mannequin.
- The Catalog mount keeps exactly one ScreenGui, removes late automatic StarterGui duplicates, and preserves unrelated screens. The source template and mounted Catalog use ResetOnSpawn=false.
- Workspace.Rig is held at Terrain.HRPPosition by AlignPosition and rotated by AlignOrientation. Walking, jumping, falling states, automatic turning, collisions, overhead names, health displays, and character BillboardGuis are disabled. The active player owns its physics so local mouse or touch dragging remains responsive.
- Workspace.Rig uses persistent model streaming and becomes each player's ReplicationFocus, so character-free clients still receive its full R15 assembly. The controller rebinds if its root or orientation constraint arrives late.
- A server heartbeat restores missing position or orientation constraints. Mouse and touch dragging rotate the local mannequin without fighting the position constraint.
- The equipped strip removes individual items. Try-on applies to Workspace.Rig on the server, with rollback if applying an appearance fails. Movement/display constraints are reapplied after appearance changes.
- The camera is Scriptable and follows Workspace.Terrain.CamLockAngle.WorldCFrame after the default camera update. CamLockAngle must be an Attachment; no positional offset is added.
- Favorites, saved outfits, reset, sort selection, Roblox outfit permission, and status messaging remain available in the service layer but have no generated controls. Their UI is intentionally deferred to the authored Studio interface.
- The existing interface fits a 1583×864 reference canvas. Buttons use Activated for mouse, touch, and controller activation.

## Checks

Run the behavior tests with Node and the official Luau CLI:

```sh
node tests/outfit/run.cjs /path/to/luau
rojo build outfit.project.json -o outfit.rbxlx
```

The tests execute the actual modules against API fixtures. They cover validation, concurrent requests, item/bundle changes, rollback, outfit ownership, session limits, FORGE response size, pagination failures, stale request cancellation, character-free player sessions, rig movement/display constraints, late StarterGui duplication, constraint restoration, and attachment camera locking. They do not replace a Studio Play test of visual layout.

Catalog searches use a supported Roblox page limit of 28. A read-only Studio API query using the production Clothing filters returned items successfully after correcting the earlier unsupported limit of 24.

## Play test

1. Sync the latest GitHub checkout through Rojo to place 135768979013187. Start Play.
2. Search Clothing, change subcategories, advance a page, and return. Change categories during loading.
3. Confirm accessories, body assets, bundles, and outfits rotate inside item ViewportFrames while classic clothing uses thumbnails.
4. Try on a classic shirt, accessory, layered clothing, body item, animation, and bundle. Check the rig and equipped strip, then remove an item.
5. Open Roblox Outfits. Grant or decline access and check the retry behavior.
6. Check narrow screens and controller activation. Inspect Output for errors and FORGE's boot report.

No live Play test was run during implementation because Studio was designated read-only.
