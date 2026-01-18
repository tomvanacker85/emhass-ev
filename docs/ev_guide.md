# Electric Vehicle (EV) Optimization Guide

EMHASS now includes advanced Electric Vehicle charging optimization capabilities. This feature allows you to optimize your EV charging schedule based on electricity prices, solar production, and your driving schedule.

## Table of Contents
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [API Endpoints](#api-endpoints)
- [Integration Methods](#integration-methods)
- [Use Cases](#use-cases)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is EV Optimization?

EMHASS EV optimization intelligently schedules your electric vehicle charging to:
- **Minimize costs**: Charge during off-peak hours when electricity is cheapest
- **Maximize solar usage**: Prioritize charging when your solar panels are producing
- **Ensure availability**: Guarantee sufficient charge for your planned trips
- **Respect constraints**: Work within your charger's power limits and EV availability

### Key Features

✅ **Smart Scheduling**: Automatically determines optimal charging times  
✅ **Calendar Integration**: Uses your Google Calendar for trip planning  
✅ **Multi-Vehicle Support**: Optimize up to multiple EVs independently  
✅ **Flexible Power Control**: Supports variable charging power (not just on/off)  
✅ **Real-Time Updates**: Adjust plans based on current battery state  
✅ **Range Requirements**: Ensure minimum range for upcoming trips  

---

## Quick Start

### 1. Enable EV Optimization

In your EMHASS configuration, set:
```yaml
number_of_ev_loads: 1  # Enable for one EV
```

### 2. Configure EV Parameters

Set your EV specifications:
```yaml
ev_battery_capacity: [77000]           # Wh (e.g., 77 kWh battery)
ev_charging_efficiency: [0.9]          # 90% charging efficiency
ev_nominal_charging_power: [4600]      # W (e.g., 4.6 kW charger)
ev_minimum_charging_power: [1380]      # W (minimum when active)
ev_consumption_efficiency: [0.15]      # kWh/km (e.g., 150 Wh/km)
```

### 3. Update EV State via API

Before each optimization, update your EV's current state:
```bash
# Set current battery state of charge
curl -X POST http://localhost:5001/action/ev-soc \
  -H "Content-Type: application/json" \
  -d '{"ev_id": 0, "soc_percent": 65.0}'

# Set availability schedule (1 = available for charging, 0 = away)
curl -X POST http://localhost:5001/action/ev-availability \
  -H "Content-Type: application/json" \
  -d '{"ev_id": 0, "availability": [1,1,1,0,0,1,1,1]}'

# Set minimum range requirements (km needed at each time step)
curl -X POST http://localhost:5001/action/ev-range-requirements \
  -H "Content-Type: application/json" \
  -d '{"ev_id": 0, "min_range_km": [0,0,100,150,150,0,0,0]}'
```

### 4. Run Optimization

```bash
curl -X POST http://localhost:5001/action/dayahead-optim
```

### 5. Use the Results

EMHASS publishes the charging schedule to Home Assistant sensors:
- `sensor.p_ev0`: Charging power schedule (W)
- `sensor.soc_ev0`: Predicted state of charge (%)

Use these in automations to control your EV charger.

---

## Configuration

### Basic EV Parameters

| Parameter | Description | Example | Unit |
|-----------|-------------|---------|------|
| `number_of_ev_loads` | Number of EVs to optimize (0 = disabled) | `1` | - |
| `ev_battery_capacity` | Total battery capacity | `[77000]` | Wh |
| `ev_charging_efficiency` | Charging efficiency (losses) | `[0.9]` | 0-1 |
| `ev_nominal_charging_power` | Maximum charging power | `[4600]` | W |
| `ev_minimum_charging_power` | Minimum power when charging | `[1380]` | W |
| `ev_consumption_efficiency` | Energy consumption per km | `[0.15]` | kWh/km |

### Finding Your EV's Parameters

#### Battery Capacity
Your EV manual or manufacturer website. Common values:
- Nissan Leaf (40 kWh): `40000`
- Tesla Model 3 Standard Range: `60000`
- Hyundai Kona Electric: `64000`
- Tesla Model 3 Long Range: `82000`

#### Charging Power
Depends on your home charger (EVSE):
- Standard outlet (Level 1): `1500-2000` W
- Level 2 charger (7 kW): `7000` W
- Level 2 charger (11 kW): `11000` W
- Three-phase 16A: `11000` W
- Three-phase 32A: `22000` W

**Note**: Use the **lower** of your charger's maximum and your EV's AC charging limit.

#### Consumption Efficiency
Monitor your EV's average consumption:
- Efficient driving: `0.12-0.15` kWh/km
- Normal driving: `0.15-0.18` kWh/km
- Highway/winter: `0.18-0.25` kWh/km

### Multiple EVs

To optimize multiple vehicles:
```yaml
number_of_ev_loads: 2
ev_battery_capacity: [77000, 64000]          # EV 0: 77kWh, EV 1: 64kWh
ev_charging_efficiency: [0.9, 0.88]
ev_nominal_charging_power: [4600, 7000]      # Different chargers
ev_minimum_charging_power: [1380, 2000]
ev_consumption_efficiency: [0.15, 0.16]
```

Each EV has independent:
- State of charge tracking
- Availability schedule
- Range requirements
- Charging schedule

---

## API Endpoints

### GET `/action/ev-status`

Check EV status and current state.

**Parameters:**
- `ev_id`: EV index (0 for first EV)

**Example:**
```bash
curl "http://localhost:5001/action/ev-status?ev_id=0"
```

**Response:**
```json
{
  "enabled": true,
  "ev_id": 0,
  "soc_percent": 65.0,
  "soc_kwh": 50.05,
  "range_km": 333.67,
  "battery_capacity_kwh": 77.0,
  "availability_schedule": [1, 1, 1, 0, 0, 1, 1, 1],
  "range_requirements_km": [0, 0, 100, 150, 150, 0, 0, 0]
}
```

### POST `/action/ev-soc`

Update the current battery state of charge.

**Body:**
```json
{
  "ev_id": 0,
  "soc_percent": 65.0
}
```

**When to use**: 
- Before each optimization
- When you plug in/unplug
- After external charging (outside EMHASS control)

### POST `/action/ev-availability`

Set when the EV is available for charging.

**Body:**
```json
{
  "ev_id": 0,
  "availability": [1, 1, 1, 0, 0, 1, 1, 1]
}
```

**Values:**
- `1`: EV is plugged in and available for charging
- `0`: EV is away (unplugged, driving, etc.)

**Array length**: Must match your optimization horizon (typically 24 or 48 hours)

### POST `/action/ev-range-requirements`

Set minimum range needed at each time step.

**Body:**
```json
{
  "ev_id": 0,
  "min_range_km": [0, 0, 100, 150, 150, 0, 0, 0]
}
```

**Use case**: You need 150 km range by 7:00 AM for a trip.

**Array length**: Must match your optimization horizon

---

## Integration Methods

### Method 1: Node-RED + Google Calendar (Recommended)

Fully automated trip planning using your calendar.

**Advantages:**
- ✅ Fully automated
- ✅ Natural trip planning (just add calendar events)
- ✅ Handles complex schedules
- ✅ Automatic distance calculation

**Setup**: See [Node-RED EV Integration Guide](nodered_ev_integration.md)

### Method 2: Manual API Calls

Set availability and range manually via API.

**Advantages:**
- ✅ Simple setup
- ✅ No external dependencies
- ✅ Full control

**Use case**: Fixed schedule (e.g., commute to work daily)

**Example automation:**
```yaml
automation:
  - alias: "Update EV for work commute"
    trigger:
      - platform: time
        at: "22:00:00"
    action:
      - service: rest_command.emhass_ev_soc
        data:
          ev_id: 0
          soc_percent: "{{ states('sensor.my_ev_battery') }}"
      - service: rest_command.emhass_ev_availability
        data:
          ev_id: 0
          # Home all night, away 7-18, home evening
          availability: [1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1]
      - service: rest_command.emhass_ev_range
        data:
          ev_id: 0
          # Need 80 km by 7 AM for work commute
          min_range_km: [0,0,0,0,0,0,0,80,80,80,80,80,80,80,80,80,80,80,0,0,0,0,0,0]
```

### Method 3: Input Helpers + Automations

Use Home Assistant input helpers for manual control.

**Setup:**
```yaml
input_number:
  ev_current_soc:
    name: "EV Current Battery %"
    min: 0
    max: 100
    step: 1
    unit_of_measurement: "%"
    
  ev_required_range:
    name: "Required Range Tomorrow"
    min: 0
    max: 500
    step: 10
    unit_of_measurement: "km"

automation:
  - alias: "Update EMHASS EV data"
    trigger:
      - platform: time
        at: "22:30:00"
    action:
      - service: rest_command.emhass_ev_soc
        data:
          ev_id: 0
          soc_percent: "{{ states('input_number.ev_current_soc') }}"
```

---

## Use Cases

### Use Case 1: Daily Commute

**Scenario**: Drive to work every weekday, need 80 km range.

**Setup:**
```yaml
automation:
  - alias: "Weekday EV charging"
    trigger:
      - platform: time
        at: "22:00:00"
    condition:
      - condition: time
        weekday: [mon, tue, wed, thu, fri]
    action:
      # Update current SOC from your EV integration
      - service: rest_command.emhass_ev_soc
        data:
          ev_id: 0
          soc_percent: "{{ states('sensor.my_ev_battery') }}"
      # Available all night
      - service: rest_command.emhass_ev_availability
        data:
          ev_id: 0
          availability: [1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1]
      # Need 80 km by 7 AM
      - service: rest_command.emhass_ev_range
        data:
          ev_id: 0
          min_range_km: [0,0,0,0,0,0,0,80,80,80,80,80,80,80,80,80,80,80,0,0,0,0,0,0]
      - delay: 5
      - service: rest_command.emhass_dayahead
```

### Use Case 2: Weekend Trip

**Scenario**: Plan a 200 km trip on Saturday morning.

**Using Google Calendar** (automated):
1. Create calendar event: "Trip to mountains" at 9:00 AM
2. Set location in calendar event
3. Node-RED calculates distance and updates EMHASS
4. EMHASS ensures 200 km range by 9:00 AM

**Manual approach**:
```yaml
automation:
  - alias: "Weekend trip charging"
    trigger:
      - platform: time
        at: "21:00:00"
    condition:
      - condition: time
        weekday: [fri]
    action:
      - service: rest_command.emhass_ev_range
        data:
          ev_id: 0
          # Need 200 km by 9 AM Saturday (hour 9)
          min_range_km: [0,0,0,0,0,0,0,0,0,200,200,200,200,200,200,200,200,200,0,0,0,0,0,0]
```

### Use Case 3: Maximize Solar Charging

**Scenario**: Charge from solar during the day when possible.

EMHASS automatically prioritizes solar charging when:
- `set_use_battery` is `false` (or you have no home battery)
- Electricity prices are high during the day
- Your EV is available during solar production hours

**Tips:**
- Set availability to include daytime hours when home
- Use "opportunistic" charging by not requiring full charge immediately
- Let EMHASS decide optimal charging times based on solar forecast

### Use Case 4: Variable Schedule (Calendar Integration)

**Scenario**: Irregular schedule with different trips each week.

**Best approach**: Node-RED + Google Calendar integration

1. Add any trip to Google Calendar
2. Include destination address in event location
3. Node-RED automatically:
   - Calculates driving distance
   - Generates availability schedule (0 during trip)
   - Sets range requirements
   - Updates EMHASS

No manual updates needed!

---

## Troubleshooting

### EV optimization is not enabled

**Symptoms**: API returns `"error": "EV optimization is not enabled"`

**Solutions:**
1. Check configuration: `number_of_ev_loads` must be ≥ 1
2. Restart EMHASS after configuration changes
3. Verify configuration loaded: Check logs or web UI

### Optimization doesn't charge enough

**Possible causes:**
1. **Range requirements too low**: Increase minimum range values
2. **Availability wrong**: EV marked as away when it should be charging
3. **Power constraints**: Charger power too low to reach target in time
4. **Cost priorities**: EMHASS prioritizes cost over charging (adjust cost function weight)

**Debug steps:**
1. Check `sensor.soc_ev0` final value - is it sufficient?
2. Review `sensor.p_ev0` - is charging power reasonable?
3. Verify availability schedule matches reality
4. Check range requirement matches actual needs

### EV charges more than needed

**Causes:**
1. **Range requirements too high**: Reduce minimum range values
2. **Cheap electricity**: EMHASS sees low prices and charges opportunistically
3. **Wrong consumption efficiency**: Set realistic kWh/km value

**Solutions:**
- Lower range requirements to actual needs
- Increase `weight_battery_discharge` to discourage excess charging
- Verify consumption efficiency matches your EV's actual usage

### SOC doesn't match reality

**Issue**: EMHASS predictions diverge from actual battery level.

**Causes:**
1. External charging (not through EMHASS)
2. Actual consumption different from configured efficiency
3. SOC not updated before optimization

**Solutions:**
- Always update SOC via API before optimization
- Calibrate consumption efficiency based on real data
- Account for external charging by updating SOC

### Array length mismatch errors

**Error**: `"availability must have X elements"`

**Cause**: Array length doesn't match optimization horizon.

**Solution**: 
- Check your optimization horizon (typically 24 or 48 hours)
- Divide by your time step (typically 30 minutes = 0.5 hours)
- Example: 24 hours / 0.5 = 48 timesteps needed

```python
# Generate 48 half-hour timesteps
availability = [1] * 48  # Available for 24 hours
```

### Multiple EVs configuration

**Issue**: Second EV not optimizing correctly.

**Checklist:**
1. All EV parameter arrays have same length as `number_of_ev_loads`
2. Each EV has independent API calls (different `ev_id`)
3. Each EV has separate sensors (`sensor.p_ev0`, `sensor.p_ev1`)

---

## Advanced Topics

### Understanding the Optimization

EMHASS minimizes the objective function:
```
minimize: electricity_cost + battery_wear - solar_usage_value
```

For EVs, this means:
- Charges during low electricity prices
- Prefers solar production times
- Respects all constraints (SOC, availability, range)
- Balances competing objectives

### Charging Power Modulation

Unlike simple on/off chargers, EMHASS can vary charging power between minimum and maximum:
- **Advantage**: Better integration with home power management
- **Requirement**: Your charger/EV must support power modulation
- **Home Assistant integration**: Use a template to set charger power:

```yaml
automation:
  - alias: "Set EV charger power"
    trigger:
      - platform: state
        entity_id: sensor.p_ev0
    action:
      - service: number.set_value
        target:
          entity_id: number.ev_charger_max_current
        data:
          value: "{{ (states('sensor.p_ev0') | float / 230) | round(0) }}"  # Convert W to A
```

### Battery Degradation (Future Feature)

Planned for future releases:
- SOC cycling cost
- Prefer partial charging over full cycles
- Temperature-aware charging

Currently not implemented, but framework exists in code.

---

## Examples Repository

More examples available at:
- [EMHASS Documentation](https://emhass.readthedocs.io/)
- [Community Forum](https://community.home-assistant.io/t/emhass-an-energy-management-for-home-assistant/)
- [Node-RED Integration Guide](nodered_ev_integration.md)

---

## Getting Help

- **Documentation**: [emhass.readthedocs.io](https://emhass.readthedocs.io/)
- **Community Forum**: [Home Assistant Community](https://community.home-assistant.io/t/emhass-an-energy-management-for-home-assistant/)
- **Issues**: [GitHub Issues](https://github.com/davidusb-geek/emhass/issues)

## Contributing

Found a bug or have a feature request? Please open an issue on GitHub!

Pull requests are welcome for:
- Bug fixes
- Documentation improvements
- New features (discuss first in an issue)
- Example automations and use cases
