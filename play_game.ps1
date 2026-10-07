# One-click PowerShell launcher for The Dungeon Remembers
$godotBin = "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
$projectDir = $PSScriptRoot
Write-Host "Launching The Dungeon Remembers..." -ForegroundColor Cyan
Start-Process -FilePath $godotBin -ArgumentList "--path `"$projectDir`""
