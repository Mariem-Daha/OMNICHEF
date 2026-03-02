# Install NuGet for Flutter Windows Build
# Run this script as Administrator

Write-Host "Installing NuGet..." -ForegroundColor Green

# Create directory
$nugetPath = "C:\nuget"
New-Item -ItemType Directory -Path $nugetPath -Force | Out-Null

# Download NuGet
Write-Host "Downloading nuget.exe..." -ForegroundColor Yellow
$nugetExe = "$nugetPath\nuget.exe"
Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetExe

# Add to PATH
Write-Host "Adding to PATH..." -ForegroundColor Yellow
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$nugetPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$nugetPath", "Machine")
    Write-Host "Added to PATH" -ForegroundColor Green
}

# Also add to current session
$env:Path += ";$nugetPath"
# Verify
Write-Host "`nVerifying installation..." -ForegroundColor Yellow
& $nugetExe help

Write-Host "`n✅ NuGet installed successfully!" -ForegroundColor Green
Write-Host "📍 Location: $nugetExe" -ForegroundColor Cyan
Write-Host "`n⚠️  IMPORTANT: Close this terminal and open a new one for PATH changes to take effect" -ForegroundColor Yellow
Write-Host "`nThen run:" -ForegroundColor Cyan
Write-Host "  cd `"d:\New folder\cuisinee\cuisinee\frontend`"" -ForegroundColor White
Write-Host "  flutter clean" -ForegroundColor White
Write-Host "  flutter run -d windows" -ForegroundColor White
