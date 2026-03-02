# Test if NuGet is properly installed and accessible

Write-Host "Testing NuGet installation..." -ForegroundColor Cyan

# Test 1: Check if nuget.exe exists
$nugetPath = "C:\nuget\nuget.exe"
if (Test-Path $nugetPath) {
    Write-Host "✅ NuGet file exists at: $nugetPath" -ForegroundColor Green
} else {
    Write-Host "❌ NuGet file NOT found at: $nugetPath" -ForegroundColor Red
    exit
}

# Test 2: Check if in PATH
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($env:Path -like "*C:\nuget*") {
    Write-Host "✅ C:\nuget is in system PATH" -ForegroundColor Green
} else {
    Write-Host "❌ C:\nuget is NOT in system PATH" -ForegroundColor Red
    Write-Host "Adding to current session..." -ForegroundColor Yellow
    $env:Path += ";C:\nuget"
}

# Test 3: Try to run nuget
Write-Host "`nTrying to run nuget..." -ForegroundColor Yellow
try {
    & $nugetPath help | Select-Object -First 3
    Write-Host "✅ NuGet is working!" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to run NuGet: $_" -ForegroundColor Red
}

Write-Host "`n" -NoNewline
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Close this terminal completely" -ForegroundColor White
Write-Host "2. Open a NEW PowerShell window" -ForegroundColor White
Write-Host "3. Run: nuget help" -ForegroundColor Yellow
Write-Host "4. If that works, run:" -ForegroundColor White
Write-Host "   cd `"d:\New folder\cuisinee\cuisinee\frontend`"" -ForegroundColor Yellow
Write-Host "   flutter clean" -ForegroundColor Yellow
Write-Host "   flutter run -d windows" -ForegroundColor Yellow
