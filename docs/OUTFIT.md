# Outfit Studio

Outfit Studio uses FORGE services/controllers with the existing StarterGui Catalog and Components templates. Rojo maps code only; the UI and showroom remain authored in Studio.

## Behavior

- Clothing, Accessories, Body, and Animations use Roblox catalog search, sorting, and cursor pagination. Previous pages are cached. Search responses from an older request cannot replace a newer category or query.
- Subcategories are cleared and populated at runtime from OutfitShared.Catalog. Prebuilt Components.SubCategories folders are not required.
- Item cards show thumbnails, names, creators, prices, selection badges, and favorite controls. Runtime clones receive meaningful child names.
- Try-on toggles supported assets; bundles apply supported constituent assets. Gear is browse-only. Unsupported items and failed requests show feedback.
- The server validates remote arguments and resolves asset types from Roblox, never from client metadata. Per-player mutation locks and rate limits prevent overlapping avatar changes.
- Automatic spawning is disabled so the server can explicitly load each player's actual character once. Workspace.Rig supplies the creator position and is moved to ServerStorage during runtime. The Catalog is mounted explicitly, so it can show loading feedback before the character finishes loading.
- The Catalog mount keeps exactly one ScreenGui, removes late automatic StarterGui duplicates, and preserves unrelated screens. The source template and mounted Catalog use ResetOnSpawn=false.
- The actual player character is positioned where the Rig stood. Its root is anchored; walking, jumping, turning, collisions, overhead names, health displays, and character BillboardGuis are disabled. Default controls and the reset button are disabled on the client. Other players' characters are hidden locally to keep their creators from overlapping yours.
- The root is anchored before collisions are disabled, and its lock is reapplied after LoadCharacterAsync completes. A server heartbeat restores the lock if the engine unanchors it; replacement root parts are anchored immediately.
- The equipped strip removes individual items. Try-on applies to the actual character on the server, with rollback if applying an appearance fails. Movement/display locks are reapplied after appearance changes. RESET restores the player's initial appearance. ROTATE turns the locked character.
- The camera is Scriptable and follows Workspace.Terrain.CamLockAngle.WorldCFrame after the default camera update. CamLockAngle must be an Attachment; no positional offset is added.
- Starred, Recents, and My Outfits last for the current server session. Favorites are capped at 24, recents at 20, and saved outfits at 20. SAVE OUTFIT opens a name input; the × on a saved card deletes it. No DataStore persistence or purchases are implemented.
- Roblox Outfits reads the current player's platform outfits. ALLOW ACCESS requests Roblox inventory permission explicitly. No permission prompt occurs on startup. Applying an outfit changes the experience character, not the account avatar.
- The existing interface fits a 1583×864 reference canvas. Buttons use Activated for mouse, touch, and controller activation.

## Checks

Run the behavior tests with Node and the official Luau CLI:

```sh
node tests/outfit/run.cjs /path/to/luau
rojo build outfit.project.json -o outfit.rbxlx
```

The tests execute the actual modules against API fixtures. They cover validation, concurrent requests, item/bundle changes, rollback, outfit ownership, session limits, FORGE response size, pagination failures, stale request cancellation, explicit character loading, character movement/display locks, late StarterGui duplication, post-load unanchoring, and attachment camera locking. They do not replace a Studio Play test of visual layout.

Catalog searches use a supported Roblox page limit of 28. A read-only Studio API query using the production Clothing filters returned items successfully after correcting the earlier unsupported limit of 24.

## Play test

1. Sync the latest GitHub checkout through Rojo to place 135768979013187. Start Play.
2. Search Clothing, change subcategories/sorting, advance a page, and return. Change categories during loading.
3. Try on a classic shirt, accessory, layered clothing, body item, animation, and bundle. Check the preview and equipped strip. Remove an item and RESET.
4. Star/unstar items and inspect Starred/Recents. Save, apply, and delete a session outfit.
5. Open Roblox Outfits. Grant or decline access and check the retry behavior.
6. Check narrow screens and controller activation. Inspect Output for errors and FORGE's boot report.

No live Play test was run during implementation because Studio was designated read-only.
