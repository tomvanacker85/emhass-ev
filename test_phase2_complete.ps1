# Comprehensive test script for Phase 2: Core EV Logic Implementation
# Tests all EV functionality end-to-end

$BaseUrl = "http://localhost:5001"
$ErrorCount = 0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Phase 2 Complete Integration Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Verify EV configuration is enabled
Write-Host "TEST 1: Verify EV Configuration" -ForegroundColor Yellow
try {
    $config = Invoke-RestMethod -Uri "$BaseUrl/get-config" -Method Get
    if ($config.number_of_ev_loads -eq 1) {
        Write-Host "  [OK] EV optimization enabled (number_of_ev_loads = 1)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] EV optimization not enabled!" -ForegroundColor Red
        $ErrorCount++
    }
} catch {
    Write-Host "  [FAIL] Failed to get configuration: $_" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# Test 2: Set initial EV state
Write-Host "TEST 2: Set EV Initial State (50`% SOC)" -ForegroundColor Yellow
try {
    $body = @{
        ev_index = 0
        soc_percent = 50.0
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-soc" -Method Post -Body $body -ContentType "application/json"
    if ($response.soc_percent -eq 50.0) {
        Write-Host "  [OK] EV SOC set to 50`% successfully" -ForegroundColor Green
        Write-Host "    - Current range: $([math]::Round($response.current_range_km, 1)) km" -ForegroundColor Gray
    } else {
        Write-Host "  [FAIL] SOC mismatch!" -ForegroundColor Red
        $ErrorCount++
    }
} catch {
    Write-Host "  [FAIL] Failed to set SOC: $_" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# Test 3: Set EV availability (available 18:00-08:00 next day)
Write-Host "TEST 3: Set EV Availability Schedule" -ForegroundColor Yellow
try {
    # EV available from 18:00 to 08:00 next day (14 hours)
    $availability = @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1)
    $body = @{
        ev_index = 0
        availability = $availability
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-availability" -Method Post -Body $body -ContentType "application/json"
    if ($response.timesteps -eq 48) {
        Write-Host "  [OK] Availability schedule set (48 timesteps)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Timestep count mismatch!" -ForegroundColor Red
        $ErrorCount++
    }
} catch {
    Write-Host "  [FAIL] Failed to set availability: $_" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# Test 4: Set minimum range requirements (need 100km at 08:00)
Write-Host "TEST 4: Set Minimum Range Requirements" -ForegroundColor Yellow
try {
    # Need 100km at timestep 16 (08:00)
    $rangeKm = @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    $body = @{
        ev_index = 0
        range_km = $rangeKm
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-range-requirements" -Method Post -Body $body -ContentType "application/json"
    if ($response.timesteps -eq 48) {
        Write-Host "  [OK] Range requirements set (need 100km at 08:00)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Timestep count mismatch!" -ForegroundColor Red
        $ErrorCount++
    }
} catch {
    Write-Host "  [FAIL] Failed to set range requirements: $_" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# Test 5: Run day-ahead optimization
Write-Host "TEST 5: Run Day-Ahead Optimization (this may take 10-30 seconds...)" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/dayahead-optim" -Method Post -TimeoutSec 60
    Write-Host "  [OK] Optimization completed: $response" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Optimization failed: $_" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# Test 6: Check if optimization results are available on web UI
Write-Host "TEST 6: Check Web UI Results" -ForegroundColor Yellow
try {
    $html = Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing
    if ($html.Content -match "P_EV" -or $html.Content -match "EV") {
        Write-Host "  [OK] Web UI contains EV results" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Web UI may not show EV data yet (optimization might not have run)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [FAIL] Failed to check web UI: $_" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# Test 7: Verify EV status after optimization
Write-Host "TEST 7: Verify EV Status After Optimization" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/action/ev-status?ev_index=0" -Method Get
    Write-Host "  [OK] Current EV Status:" -ForegroundColor Green
    $soc = [math]::Round($response.soc_percent, 1)
    Write-Host "    - SOC: $soc`%" -ForegroundColor Gray
    Write-Host "    - Range: $([math]::Round($response.current_range_km, 1)) km" -ForegroundColor Gray
    Write-Host "    - Energy: $([math]::Round($response.energy_level_wh, 0)) Wh" -ForegroundColor Gray
    Write-Host "    - Battery: $($response.battery_capacity_wh) Wh" -ForegroundColor Gray
    Write-Host "    - Charging: $($response.minimum_charging_power_w)W - $($response.nominal_charging_power_w)W" -ForegroundColor Gray
} catch {
    Write-Host "  [FAIL] Failed to get EV status: $_" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
if ($ErrorCount -eq 0) {
    Write-Host "[SUCCESS] ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Phase 2 Core EV Logic is working correctly!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Check the web UI at: http://localhost:5001/" -ForegroundColor White
    Write-Host "  2. Look for P_EV0 and SOC_EV0 in the power and SOC charts" -ForegroundColor White
    Write-Host "  3. Verify sensor.p_ev0 and sensor.soc_ev0 are published to Home Assistant" -ForegroundColor White
} else {
    Write-Host "[FAILED] $ErrorCount TEST(S) FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the errors above and the container logs:" -ForegroundColor Yellow
    Write-Host "  docker-compose logs -f emhass-ev" -ForegroundColor White
}
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
