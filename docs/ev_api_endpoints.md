# EV API Endpoints Documentation

## Overview

EMHASS-EV extends the original EMHASS with Electric Vehicle (EV) charging optimization capabilities. This document describes the new API endpoints for managing EV state and requirements.

## Prerequisites

To use EV optimization, you must first enable it in your configuration:

```json
{
  "number_of_ev_loads": 1,
  "ev_battery_capacity": [77000],
  "ev_charging_efficiency": [0.9],
  "ev_nominal_charging_power": [4600],
  "ev_minimum_charging_power": [1380],
  "ev_consumption_efficiency": [0.15]
}
```

- `number_of_ev_loads`: Number of EVs to manage (0 = disabled)
- `ev_battery_capacity`: Battery capacity in Wh (e.g., 77000 = 77 kWh)
- `ev_charging_efficiency`: Charging efficiency (0.0-1.0)
- `ev_nominal_charging_power`: Maximum charging power in W
- `ev_minimum_charging_power`: Minimum charging power in W
- `ev_consumption_efficiency`: Energy consumption in kWh/km

## API Endpoints

### 1. Get EV Status

**Endpoint:** `GET /action/ev-status`

**Query Parameters:**
- `ev_index` (optional): EV index (default: 0)

**Response:**
```json
{
  "enabled": true,
  "ev_index": 0,
  "soc_percent": 75.5,
  "energy_level_wh": 58135,
  "current_range_km": 387.6,
  "battery_capacity_wh": 77000,
  "charging_efficiency": 0.9,
  "nominal_charging_power_w": 4600,
  "minimum_charging_power_w": 1380,
  "consumption_efficiency_kwh_per_km": 0.15
}
```

**Example:**
```bash
curl "http://localhost:5001/action/ev-status?ev_index=0"
```

### 2. Update EV State of Charge

**Endpoint:** `POST /action/ev-soc`

**Request Body:**
```json
{
  "ev_index": 0,
  "soc_percent": 75.5
}
```

**Response:**
```json
{
  "message": "Successfully updated SOC for EV 0",
  "ev_index": 0,
  "soc_percent": 75.5,
  "energy_level_wh": 58135,
  "current_range_km": 387.6
}
```

**Example:**
```bash
curl -X POST "http://localhost:5001/action/ev-soc" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 0, "soc_percent": 75.5}'
```

**Use Case:** Update the EV's current state of charge from a Home Assistant sensor or Node-RED flow.

### 3. Set EV Availability Schedule

**Endpoint:** `POST /action/ev-availability`

**Request Body:**
```json
{
  "ev_index": 0,
  "availability": [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1]
}
```

- `availability`: Array where 0 = vehicle absent, 1 = vehicle available for charging
- Length should match the optimization horizon (typically 24-48 hours)

**Response:**
```json
{
  "message": "Successfully set availability schedule for EV 0",
  "ev_index": 0,
  "timesteps": 24
}
```

**Example:**
```bash
# EV available at home from 18:00-24:00 and 06:00-12:00
curl -X POST "http://localhost:5001/action/ev-availability" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 0, "availability": [0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1]}'
```

**Use Case:** Based on Google Calendar events from Node-RED, determine when the EV will be parked at home and available for charging.

### 4. Set Minimum Range Requirements

**Endpoint:** `POST /action/ev-range-requirements`

**Request Body:**
```json
{
  "ev_index": 0,
  "range_km": [0, 0, 0, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
}
```

- `range_km`: Array of minimum required range in km at each timestep
- Set to desired range at departure times (when availability changes from 1 to 0)

**Response:**
```json
{
  "message": "Successfully set range requirements for EV 0",
  "ev_index": 0,
  "timesteps": 24
}
```

**Example:**
```bash
# Need 100km range at 07:00 for morning commute
curl -X POST "http://localhost:5001/action/ev-range-requirements" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 0, "range_km": [0,0,0,0,0,0,0,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]}'
```

**Use Case:** Calculate required range from Google Calendar events (trip distance) via Node-RED.

## Integration Workflow

### Node-RED Flow Example

1. **Fetch Google Calendar Events** → Parse trip information
2. **Calculate Availability Array** → 0 during trips, 1 when parked at home
3. **Calculate Range Requirements** → Distance for each trip + safety margin
4. **Send to EMHASS-EV** → POST to `/action/ev-availability` and `/action/ev-range-requirements`
5. **Run Optimization** → POST to `/action/dayahead-optim` or `/action/naive-mpc-optim`
6. **Retrieve Results** → Use optimized `P_EV` schedule for smart charging

### Home Assistant Integration

```yaml
# automation.yaml
- alias: "Update EV SOC in EMHASS"
  trigger:
    - platform: state
      entity_id: sensor.ev_battery_level
  action:
    - service: rest_command.update_ev_soc
      data:
        soc_percent: "{{ states('sensor.ev_battery_level') }}"

# configuration.yaml
rest_command:
  update_ev_soc:
    url: "http://localhost:5001/action/ev-soc"
    method: POST
    headers:
      Content-Type: application/json
    payload: '{"ev_index": 0, "soc_percent": {{ soc_percent }}}'
```

## Error Handling

All endpoints return appropriate HTTP status codes:

- `200 OK`: GET request successful
- `201 Created`: POST request successful
- `400 Bad Request`: Invalid input data
- `404 Not Found`: EV index not found
- `500 Internal Server Error`: Server-side error

**Example Error Response:**
```json
{
  "error": "EV optimization is not enabled"
}
```

## Multi-EV Support

All endpoints support multiple EVs via the `ev_index` parameter:

```bash
# Configure second EV (index 1)
curl -X POST "http://localhost:5001/action/ev-soc" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 1, "soc_percent": 65.0}'
```

Set `number_of_ev_loads` to 2 or higher in your configuration to enable multiple EVs.

## Notes

- The EV manager is initialized lazily on the first API call
- Configuration changes require container restart or calling `/set-config`
- Availability and range requirement arrays should cover the full optimization horizon
- Range requirements are converted to energy internally using `consumption_efficiency`
- SOC updates are typically received from Home Assistant sensors
- Availability schedules should be updated before each optimization run
