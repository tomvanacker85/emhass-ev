# Initialize EMHASS and run EV test
$BaseUrl = "http://localhost:5001"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "EMHASS EV Test - With Initialization" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Initialize by accessing the web interface
Write-Host "Step 1: Initializing EMHASS..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/" -Method Get -TimeoutSec 10
    Write-Host "  [OK] Web interface loaded, system initializing..." -ForegroundColor Green
    Start-Sleep -Seconds 5  # Give it time to initialize
} catch {
    Write-Host "  [WARN] Could not load web interface: $_" -ForegroundColor Yellow
}

# Step 2: Set configuration to ensure params are created
Write-Host "`nStep 2: Setting configuration..." -ForegroundColor Yellow
$config = @{
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
    $response = Invoke-RestMethod -Uri "$BaseUrl/set-config" -Method Post -Body $config -ContentType "application/json" -TimeoutSec 10
    Write-Host "  [OK] Configuration set" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Could not set configuration: $_" -ForegroundColor Red
    exit 1
}

# Step 2.5: Restart container to reload configuration
Write-Host "`nStep 2.5: Restarting container to load new config..." -ForegroundColor Yellow
try {
    docker-compose -f C:\Users\Tom\StudioProjects\emhass-workspace\emhass-ev-add-on\docker-compose.yml restart 2>&1 | Out-Null
    Write-Host "  [OK] Container restarted" -ForegroundColor Green
    Write-Host "  Waiting 15 seconds for initialization..." -ForegroundColor Gray
    Start-Sleep -Seconds 15
} catch {
    Write-Host "  [FAIL] Could not restart container: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Verify configuration
Write-Host "`nStep 3: Verifying configuration..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/get-config" -Method Get -TimeoutSec 10
    Write-Host "  [OK] Configuration verified" -ForegroundColor Green
    Write-Host "    - hass_url: $($response.hass_url)" -ForegroundColor Gray
    Write-Host "    - number_of_ev_loads: $($response.number_of_ev_loads)" -ForegroundColor Gray
} catch {
    Write-Host "  [WARN] Could not verify: $_" -ForegroundColor Yellow
}

# Step 4: Run optimization with EV
Write-Host "`nStep 4: Running perfect optimization with EV (30 seconds)..." -ForegroundColor Yellow

$body = @{
    # 48-hour forecast data
    pv_power_forecast = @(0,0,0,0,0,0,0,50,150,300,500,700,850,950,1000,950,850,700,500,300,150,50,0,0,0,0,0,0,0,0,0,50,150,300,500,700,850,950,1000,950,850,700,500,300,150,50,0,0)
    load_power_forecast = @(300,280,270,260,250,240,250,280,350,450,550,600,620,650,680,700,720,740,700,650,600,550,500,450,400,380,360,340,330,320,310,300,290,280,270,260,250,240,230,220,210,200,190,180,170,160,150,140)
    load_cost_forecast = @(0.12,0.11,0.10,0.10,0.09,0.09,0.10,0.15,0.20,0.25,0.28,0.30,0.32,0.30,0.28,0.27,0.26,0.25,0.24,0.22,0.20,0.18,0.15,0.13,0.12,0.11,0.10,0.10,0.09,0.09,0.10,0.15,0.20,0.25,0.28,0.30,0.32,0.30,0.28,0.27,0.26,0.25,0.24,0.22,0.20,0.18,0.15,0.13)
    prod_price_forecast = @(0.05,0.05,0.04,0.04,0.04,0.04,0.05,0.08,0.10,0.12,0.14,0.15,0.16,0.15,0.14,0.13,0.13,0.12,0.12,0.11,0.10,0.09,0.08,0.06,0.05,0.05,0.04,0.04,0.04,0.04,0.05,0.08,0.10,0.12,0.14,0.15,0.16,0.15,0.14,0.13,0.13,0.12,0.12,0.11,0.10,0.09,0.08,0.06)
    prediction_horizon = 48
    soc_init = 0.5
    soc_final = 0.05
    def_total_hours = @(0,0)
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/perfect-optim" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 60
    Write-Host "  [OK] Optimization completed successfully!" -ForegroundColor Green
    Write-Host "`nResponse:" -ForegroundColor Gray
    Write-Host "$response" -ForegroundColor Gray
    
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "[SUCCESS] EV Optimization Test Passed!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "`nNext: Open http://localhost:5001/ to see results" -ForegroundColor Yellow
    Write-Host "Look for P_EV0 (charging power) and SOC_EV0 (battery state)" -ForegroundColor Yellow
    
} catch {
    Write-Host "  [FAIL] Optimization failed" -ForegroundColor Red
    Write-Host "`nError details:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "[FAILED] Test did not pass" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Cyan
    exit 1
}
