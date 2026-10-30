const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');
const root = path.resolve(__dirname, '../..');
const sources = {
  Catalog: 'src/outfit/ReplicatedStorage/OutfitShared/Catalog.lua',
  Description: 'src/outfit/ReplicatedStorage/OutfitShared/Description.lua',
  Validator: 'src/shared/ReplicatedStorage/FORGE/Network/Validator.lua',
  Types: 'src/shared/ReplicatedStorage/FORGE/Shared/Types.lua',
  Config: 'src/shared/ReplicatedStorage/FORGE/Config.lua',
  Serializer: 'src/shared/ReplicatedStorage/FORGE/Network/Serializer.lua',
  OutfitService: 'src/outfit/ServerScriptService/Services/OutfitService.luau'
};
const fixture = name => fs.readFileSync(path.join(__dirname, name), 'utf8');
let output = fixture('test-outfit-prefix.luau') + '\n';
for (const [name, file] of Object.entries(sources)) {
  if (name === 'OutfitService') output += 'ForgeMock.Types = modules.Types\n';
  output += `loadModule(${JSON.stringify(name)}, [====[${fs.readFileSync(path.join(root, file), 'utf8')}]====])\n`;
}
output += fixture('test-outfit-suffix.luau') + '\n' + fixture('test-outfit-client.luau');
output += `\nloadModule("CatalogController", [====[${fs.readFileSync(path.join(root, 'src/outfit/StarterPlayerScripts/Controllers/CatalogController.luau'), 'utf8')}]====])\n`;
output += fixture('test-outfit-client-suffix.luau');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'outfit-tests-'));
const file = path.join(directory, 'spec.luau');
fs.writeFileSync(file, output);
const result = spawnSync(process.argv[2] || 'luau', [file], { stdio: 'inherit' });
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
