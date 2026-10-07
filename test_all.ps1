# test_all.ps1: Automated regression test runner executing all phase test suites in sequence.
$ErrorActionPreference = "Continue"

$godot = "C:\Users\Adarsh\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$projectPath = "d:\Users\HP\THE DUNGEON REMEMBERS"

$suites = @(
    @{ Phase = "Phase 1: Core 3D Prototype"; Scene = "res://scenes/main/Phase1TestScene3D.tscn" },
    @{ Phase = "Phase 2: Memory & Adaptation"; Scene = "res://scenes/main/Phase2TestScene3D.tscn" },
    @{ Phase = "Phase 3: Dungeon System"; Scene = "res://scenes/main/Phase3TestScene3D.tscn" },
    @{ Phase = "Phase 4: Combat & Content"; Scene = "res://scenes/main/Phase4TestScene3D.tscn" },
    @{ Phase = "Phase 5: Boss Wave (Grand Inquisitor)"; Scene = "res://scenes/main/Phase5TestScene3D.tscn" },
    @{ Phase = "Phase 6: Audio & Visual Polish"; Scene = "res://scenes/main/Phase6TestScene3D.tscn" },
    @{ Phase = "Phase 7: Complete Game Loop & Menus"; Scene = "res://scenes/main/Phase7TestScene3D.tscn" },
    @{ Phase = "Master Suite: Full System Package"; Scene = "res://scenes/main/MasterTestSuite.tscn" }
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " RUNNING FULL AUTOMATED REGRESSION SUITE (PHASES 1 TO 7)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$allPassed = $true
$results = @()

foreach ($s in $suites) {
    Write-Host "`n>>> RUNNING $($s.Phase) [$($s.Scene)]..." -ForegroundColor Yellow
    $p = Start-Process -FilePath $godot -ArgumentList "--headless", "--path", "`"$projectPath`"", $s.Scene -NoNewWindow -Wait -PassThru
    $exitCode = $p.ExitCode

    if ($exitCode -eq 0) {
        Write-Host "[SUCCESS] $($s.Phase) PASSED (Exit code: 0)" -ForegroundColor Green
        $results += [PSCustomObject]@{ Phase = $s.Phase; Status = "PASS"; Code = 0 }
    } else {
        Write-Host "[FAILURE] $($s.Phase) FAILED (Exit code: $exitCode)" -ForegroundColor Red
        $allPassed = $false
        $results += [PSCustomObject]@{ Phase = $s.Phase; Status = "FAIL"; Code = $exitCode }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                REGRESSION SUMMARY REPORT                 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize

if ($allPassed) {
    Write-Host ">>> 100% OF ALL TEST SUITES PASSED! PROJECT IS VERIFIED FOR DELIVERY." -ForegroundColor Green
    exit 0
} else {
    Write-Host ">>> ONE OR MORE SUITES FAILED." -ForegroundColor Red
    exit 1
}
