# Copies the LockMenu addon into the Forever beta AddOns folder. A new addon needs a full game restart to be seen (a /reload is
# enough for later changes to LockMenu.lua or Data.lua).
$src = Join-Path $PSScriptRoot 'LockMenu'
$dst = 'C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\LockMenu'
New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item "$src\*" $dst -Force
Write-Host "Installed to $dst. Fully restart WoW the first time so it finds the new addon and its key binding."
