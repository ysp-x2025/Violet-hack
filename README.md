# Roblox Ultimate All-in-One Toolkit

## Files Included
1. `ToolkitServer.server.lua` -> Place in **Roblox Studio** under `ServerScriptService` as a **Script** named `ToolkitServer`.
2. `UltimateToolkitClient.client.lua` -> Place in **Roblox Studio** under `StarterPlayer -> StarterPlayerScripts` as a **LocalScript** named `UltimateToolkitClient`.

## Image Asset Setup
1. Open **Roblox Studio -> View -> Asset Manager -> Bulk Import** and upload both provided flower images (`logo.png` and `icon.png`).
2. Copy each Asset ID and paste into `CONFIG.ASSETS` inside `UltimateToolkitClient.client.lua`:
   - `MAIN_LOGO_ASSET_ID` -> `rbxassetid://<ID_1>`
   - `FLOATING_ICON_ASSET_ID` -> `rbxassetid://<ID_2>`
