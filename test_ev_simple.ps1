# Simple EV Test - Update config then test
$BaseUrl = "http://localhost:5001"
Write-Host "==========================================`n" -ForegroundColor Cyan
Write-Host "Simple EV Test - Testing perfect-optim with EV`n" -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan

# Step 1: Update config to bypass HA
Write-Host "Step 1: Updating configuration..." -ForegroundColor Yellow
$configBody = @{
    hass_url = "empty"
    long_lived_token = "empty"
    time_zone = "Europe/Paris"
    Latitude = 45.83
    Longitude = 6.86
    Altitude = 4807.0
    number_of_ev_loads = 1
    ev_battery_capacity = @(77000)
    ev_charging_efficiency = @(0.9)
    ev_nominal_charging_power = @(4600)
    ev_minimum_charging_power = @(1380)
    ev_consumption_efficiency = @(0.15)
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/config" -Method Post -Body $configBody -ContentType "application/json"
    Write-Host "  [OK] Configuration updated" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Could not update config: $_" -ForegroundColor Yellow
}

# Step 2: Run optimization with all data as runtime parameters
Write-Host "`nStep 2: Running perfect-optim with EV..." -ForegroundColor Yellow

$body = @{
    # Forecast data (24 hours)
    pv_power_forecast = @(0,0,0,0,0,0,0,50,150,300,500,700,850,950,1000,950,850,700,500,300,150,50,0,0)
    load_power_forecast = @(300,280,270,260,250,240,250,280,350,450,550,600,620,650,680,700,720,740,700,650,600,550,500,450)
    load_cost_forecast = @(0.12,0.11,0.10,0.10,0.09,0.09,0.10,0.15,0.20,0.25,0.28,0.30,0.32,0.30,0.28,0.27,0.26,0.25,0.24,0.22,0.20,0.18,0.15,0.13)
    prod_price_forecast = @(0.05,0.05,0.04,0.04,0.04,0.04,0.05,0.08,0.10,0.12,0.14,0.15,0.16,0.15,0.14,0.13,0.13,0.12,0.12,0.11,0.10,0.09,0.08,0.06)
    prediction_horizon = 24
    soc_init = 0.5
    soc_final = 0.05
    def_total_hours = @(0,0)
    # EV parameters
    number_of_ev_loads = 1
    ev_battery_capacity = @(77000)
    ev_charging_efficiency = @(0.9)
    ev_nominal_charging_power = @(4600)
    ev_minimum_charging_power = @(1380)
    ev_consumption_efficiency = @(0.15)
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/perfect-optim" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 60
    Write-Host "  [OK] Optimization completed!" -ForegroundColor Green
    Write-Host "`nResponse: $response`n" -ForegroundColor Gray
    
    Write-Host "Step 3: Check web UI at http://localhost:5001/" -ForegroundColor Yellow
    Write-Host "  Look for P_EV0 (charging power) and SOC_EV0 (battery level) in the charts" -ForegroundColor Gray
    Write-Host "`n[SUCCESS] Test completed!`n" -ForegroundColor Green
    
} catch {
    Write-Host "  [FAIL] Optimization failed: $_" -ForegroundColor Red
    Write-Host "`nThis is likely because the system still tries to connect to HA." -ForegroundColor Yellow
    Write-Host "The config update via API may not work for this Docker setup.`n" -ForegroundColor Yellow
}

Write-Host "==========================================`n" -ForegroundColor Cyan
