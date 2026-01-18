# Test script for EV API endpoints (PowerShell version)
# Run this after restarting the Docker container to test the new EV functionality

$BaseUrl = "http://localhost:5001"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Testing EV API Endpoints" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check EV status (should show EV optimization disabled by default)
Write-Host "1. GET /action/ev-status - Check EV status" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-status?ev_index=0" -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""
Write-Host ""

# Test 2: Update EV SOC (requires EV to be enabled first)
Write-Host "2. POST /action/ev-soc - Update SOC to 75%" -ForegroundColor Yellow
try {
    $body = @{
        ev_index = 0
        soc_percent = 75.0
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-soc" -Method Post -Body $body -ContentType "application/json"
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""
Write-Host ""

# Test 3: Set EV availability schedule (24 hours, available from hour 18-24)
Write-Host "3. POST /action/ev-availability - Set availability schedule" -ForegroundColor Yellow
try {
    $availability = @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1)
    $body = @{
        ev_index = 0
        availability = $availability
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-availability" -Method Post -Body $body -ContentType "application/json"
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""
Write-Host ""

# Test 4: Set minimum range requirements (need 100km at departure time)
Write-Host "4. POST /action/ev-range-requirements - Set range requirements" -ForegroundColor Yellow
try {
    $rangeKm = @(0,0,0,0,0,0,0,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    $body = @{
        ev_index = 0
        range_km = $rangeKm
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-range-requirements" -Method Post -Body $body -ContentType "application/json"
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""
Write-Host ""

# Test 5: Check EV status again after updates
Write-Host "5. GET /action/ev-status - Check status after updates" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-status?ev_index=0" -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To enable EV optimization:" -ForegroundColor Yellow
Write-Host "1. Edit config.json or use the web UI"
Write-Host "2. Set 'number_of_ev_loads' to 1 (or higher for multiple EVs)"
Write-Host "3. Configure EV parameters (battery capacity, charging power, etc.)"
Write-Host "4. Restart the container or call /set-config endpoint"
Write-Host ""
