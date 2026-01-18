# Clear EMHASS cached configuration files
Write-Host "Clearing EMHASS cached configuration..." -ForegroundColor Yellow

# Stop container
Write-Host "Stopping container..." -ForegroundColor Cyan
docker-compose -f C:\Users\Tom\StudioProjects\emhass-workspace\emhass-ev-add-on\docker-compose.yml down

# Find and remove cached files in the data directory
Write-Host "Removing cached config files..." -ForegroundColor Cyan
$dataPath = "C:\Users\Tom\StudioProjects\emhass-workspace\emhass-ev\data"

if (Test-Path "$dataPath\params.pkl") {
    Remove-Item "$dataPath\params.pkl" -Force
    Write-Host "  Deleted params.pkl" -ForegroundColor Green
}

if (Test-Path "$dataPath\config.json") {
    Remove-Item "$dataPath\config.json" -Force
    Write-Host "  Deleted config.json" -ForegroundColor Green
}

# Start container
Write-Host "Starting container..." -ForegroundColor Cyan
docker-compose -f C:\Users\Tom\StudioProjects\emhass-workspace\emhass-ev-add-on\docker-compose.yml up -d

Write-Host "`nWaiting 10 seconds for container to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "[DONE] Cache cleared and container restarted`n" -ForegroundColor Green
Write-Host "Now run: .\test_phase2_standalone.ps1" -ForegroundColor Cyan
