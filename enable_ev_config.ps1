# Helper script to enable EV optimization in EMHASS-EV
# This script updates the configuration via the API

$BaseUrl = "http://localhost:5001"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Enabling EV Optimization in EMHASS-EV" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration to enable EV optimization
$config = @{
    number_of_ev_loads = 1
    ev_battery_capacity = @(77000)
    ev_charging_efficiency = @(0.9)
    ev_nominal_charging_power = @(4600)
    ev_minimum_charging_power = @(1380)
    ev_consumption_efficiency = @(0.15)
}

Write-Host "Configuration to be set:" -ForegroundColor Yellow
$config | ConvertTo-Json -Depth 10
Write-Host ""

try {
    Write-Host "Sending configuration to EMHASS-EV..." -ForegroundColor Yellow
    $body = $config | ConvertTo-Json -Depth 10
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/set-config" -Method Post -Body $body -ContentType "application/json"
    
    Write-Host "Success! Configuration saved." -ForegroundColor Green
    Write-Host ""
    Write-Host "Please restart the Docker container:" -ForegroundColor Yellow
    Write-Host "  docker-compose restart emhass-ev" -ForegroundColor White
    Write-Host ""
    Write-Host "Then run the test script again:" -ForegroundColor Yellow
    Write-Host "  .\test_ev_endpoints.ps1" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Manually create config.json" -ForegroundColor Yellow
    Write-Host "Location: ../data/emhass-ev/config.json" -ForegroundColor White
    Write-Host ""
    Write-Host "Content:" -ForegroundColor Yellow
    $config | ConvertTo-Json -Depth 10
    Write-Host ""
}
