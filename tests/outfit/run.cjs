const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');
const root = path.resolve(__dirname, '../..');
const sources = {
  Catalog: 'src/outfit/ReplicatedStorage/OutfitShared/Catalog.lua',
  Description: 'src/outfit/ReplicatedStorage/OutfitShared/Description.lua',
  Character: 'src/outfit/ReplicatedStorage/OutfitShared/Character.lua',
  Gui: 'src/outfit/StarterPlayerScripts/Outfit/Gui.lua',
  Validator: 'src/shared/ReplicatedStorage/FORGE/Network/Validator.lua',
  Types: 'src/shared/ReplicatedStorage/FORGE/Shared/Types.lua',
  Config: 'src/shared/ReplicatedStorage/FORGE/Config.lua',
  Serializer: 'src/shared/ReplicatedStorage/FORGE/Network/Serializer.lua',
  OutfitService: 'src/outfit/ServerScriptService/Services/OutfitService.lua'
};
const fixture = name => fs.readFileSync(path.join(__dirname, name), 'utf8');
let output = fixture('test-outfit-prefix.lua') + '\n';
for (const [name, file] of Object.entries(sources)) {
  if (name === 'OutfitService') output += 'ForgeMock.Types = modules.Types\n';
  output += `loadModule(${JSON.stringify(name)}, [====[${fs.readFileSync(path.join(root, file), 'utf8')}]====])\n`;
}
output += fixture('test-outfit-suffix.lua') + '\n' + fixture('test-gui.lua') + '\n' + fixture('test-outfit-client.lua');
output += `\nloadModule("CatalogController", [====[${fs.readFileSync(path.join(root, 'src/outfit/StarterPlayerScripts/Controllers/CatalogController.lua'), 'utf8')}]====])\n`;
output += fixture('test-outfit-client-suffix.lua');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'outfit-tests-'));
const file = path.join(directory, 'spec.lua');
fs.writeFileSync(file, output);
const result = spawnSync(process.argv[2] || 'luau', [file], { stdio: 'inherit' });
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
