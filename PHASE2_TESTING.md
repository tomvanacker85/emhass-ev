# Phase 2 Testing Guide

## What was implemented in Phase 2

Phase 2 implemented the **Core EV Logic** for EMHASS-EV:

### ✅ 2.1 EV Configuration Schema (COMPLETE)
- EV parameters in `options.json`, `config_defaults.json`, `associations.csv`
- Home Assistant add-on schema with EV fields
- Configuration: `number_of_ev_loads`, `ev_battery_capacity`, `ev_charging_efficiency`, etc.

### ✅ 2.2 EV Data Model (COMPLETE)
- `ElectricVehicle` class with SOC tracking, range calculations, charging constraints
- `EVManager` class for multi-EV coordination
- Energy/range conversions (km ↔ kWh)

### ✅ 2.3 EV Input Data Handling (COMPLETE)
- API endpoints for EV data:
  - `POST /action/ev-soc` - Update state of charge
  - `POST /action/ev-availability` - Set availability schedule
  - `POST /action/ev-range-requirements` - Set minimum range requirements
  - `GET /action/ev-status` - Query current EV status

### ✅ 2.4 EV Optimization Logic (COMPLETE)
- EV integrated as deferrable load in optimization
- P_EV decision variables (charging power 0 to nominal_power)
- SOC_EV decision variables (state of charge 0 to 1)
- SOC balance equation: `SOC[t+1] = SOC[t] + (P_EV[t] * dt * eff) / capacity`
- Minimum charging power constraint (binary on/off)
- P_EV included in power balance
- EV results in optimization output

### ✅ 2.5 EV Output Generation (COMPLETE)
- P_EV and SOC_EV columns in optimization results
- Automatic visualization in web UI (get_injection_dict)
- Home Assistant sensor publishing (sensor.p_ev0, sensor.soc_ev0)
- Custom sensor IDs supported

## Testing Phase 2

### Prerequisites

1. **Container must be running:**
   ```powershell
   cd C:\Users\Tom\StudioProjects\emhass-workspace
   docker-compose up -d
   ```

2. **EV configuration must be enabled:**
   - Run `.\enable_ev_config.ps1` if not done yet
   - Restart container: `docker-compose restart emhass-ev`

### Run the comprehensive test

```powershell
cd C:\Users\Tom\StudioProjects\emhass-workspace\emhass-ev
.\test_phase2_complete.ps1
```

### What the test does

The test script performs an end-to-end validation of all Phase 2 functionality:

1. **Verifies EV configuration** - Checks if EV optimization is enabled
2. **Sets initial EV state** - Sets SOC to 50% (38.5 kWh)
3. **Configures availability** - EV available from 18:00 to 08:00 (overnight charging)
4. **Sets range requirements** - Need 100km at 08:00 (for morning commute)
5. **Runs optimization** - Executes day-ahead optimization with EV constraints
6. **Checks web UI** - Verifies results are displayed
7. **Validates final state** - Confirms EV status after optimization

### Expected results

✅ **All tests should PASS** showing:
- EV configuration enabled
- SOC successfully updated
- Availability schedule set (48 timesteps)
- Range requirements configured
- Optimization completes without errors
- Web UI displays EV data
- Final EV status shows updated SOC and range

### Manual verification

After running the test:

1. **Open web UI:** http://localhost:5001/
   - Look for "Systems powers schedule" chart
   - Should see `P_EV0` line showing charging schedule
   - Should see `SOC_EV0` in battery SOC chart

2. **Check optimization results table:**
   - Should have `P_EV0` column (charging power in W)
   - Should have `SOC_EV0` column (state of charge in %)

3. **Verify Home Assistant sensors** (if connected):
   - `sensor.p_ev0` - EV charging power
   - `sensor.soc_ev0` - EV state of charge

## Troubleshooting

### Test fails with "EV optimization not enabled"
```powershell
cd C:\Users\Tom\StudioProjects\emhass-workspace\emhass-ev
.\enable_ev_config.ps1
cd ..
docker-compose restart emhass-ev
# Wait 10 seconds, then retry test
```

### Optimization fails or times out
- Check container logs: `docker-compose logs -f emhass-ev`
- Look for errors in `/data/emhass-ev/action_logs.txt`
- Verify PuLP solver is working

### Web UI doesn't show EV data
- Ensure optimization completed successfully
- Check that `injection_dict.pkl` was created in `/data/emhass-ev/`
- Try running optimization again

### No sensor data in Home Assistant
- Verify `continual_publish` is enabled in configuration
- Check Home Assistant long-lived token is valid
- Review logs for HTTP errors when posting to Home Assistant

## What's next: Phase 3

After Phase 2 is validated, Phase 3 will add:
- Web UI configuration page for EV parameters
- Enhanced visualization with EV-specific charts
- EV availability indicators in results table

## Understanding the optimization

The optimization considers:
- **Energy cost** - Charge when electricity is cheapest
- **Availability** - Only charge when vehicle is plugged in
- **Range requirements** - Ensure sufficient charge before departure
- **Charging constraints** - Respect minimum/maximum charging power
- **Battery efficiency** - Account for charging losses (10% default)

Example scenario:
- EV arrives home at 18:00 with 50% SOC (~39 kWh, 260 km range)
- Need 100 km range at 08:00 departure (~15 kWh required)
- Optimization will charge during cheapest hours while ensuring target is met
- Charging rate: 1.38 kW minimum, 4.6 kW maximum (adjustable)
