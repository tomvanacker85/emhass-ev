# Node-RED EV Integration Guide

This guide explains how to integrate EMHASS-EV with Google Calendar using Node-RED for automatic trip planning and EV charging optimization.

## Overview

The integration consists of:

1. **Google Calendar** - Store trip events with destination addresses
2. **Node-RED** - Process calendar events and calculate trip requirements
3. **EMHASS-EV API** - Receive EV availability and range requirements
4. **Home Assistant** - Execute charging automation based on optimization

## Architecture

```
Google Calendar → Home Assistant Calendar Integration → Node-RED
    ↓
Node-RED Flow:
  1. Read calendar events
  2. Parse event locations/addresses
  3. Calculate distance to destination (Google Maps/HERE API)
  4. Convert distance to energy requirements (km → kWh)
  5. Generate availability array (0=away, 1=home)
  6. Generate minimum range array (required km before trip)
  7. POST to EMHASS-EV API
    ↓
EMHASS-EV Optimization → sensor.p_ev0, sensor.soc_ev0 → Home Assistant Automation → EV Charger
```

## Prerequisites

### 1. Home Assistant Calendar Integration

Add Google Calendar integration to Home Assistant:

1. Go to Settings → Devices & Services → Add Integration
2. Search for "Google Calendar"
3. Follow OAuth setup instructions
4. Select calendars to integrate

Your calendar events will appear as entities like `calendar.personal` in Home Assistant.

### 2. Node-RED Add-on

Install and configure Node-RED:

1. Install Node-RED add-on from Home Assistant Add-on Store
2. Enable "Show in sidebar"
3. Install required Node-RED packages:
   - `node-red-contrib-home-assistant-websocket` (Home Assistant integration)
   - `node-red-contrib-http-request` (for API calls)

### 3. Distance Calculation API

Choose one of these APIs for calculating distances:

#### Option A: Google Maps Distance Matrix API
- Sign up: https://console.cloud.google.com/google/maps-apis
- Enable: Distance Matrix API
- Cost: Free tier includes 40,000 elements/month
- API endpoint: `https://maps.googleapis.com/maps/api/distancematrix/json`

#### Option B: HERE Routing API
- Sign up: https://developer.here.com/
- Enable: Routing API v8
- Cost: Free tier includes 250,000 requests/month
- API endpoint: `https://router.hereapi.com/v8/routes`

## Calendar Event Format

Events in Google Calendar should include destination information:

### Basic Format
```
Event Title: "Meeting in Brussels"
Location: "Brussels, Belgium"
Start Time: 2026-01-20 14:00
End Time: 2026-01-20 16:00
```

### Advanced Format with Address
```
Event Title: "Client Visit"
Location: "Rue de la Loi 175, 1000 Brussels, Belgium"
Start Time: 2026-01-20 09:00
End Time: 2026-01-20 11:00
Description: "Return home estimated 12:00"
```

### Tips
- Include complete addresses for accurate distance calculations
- Add return time in description for better planning
- Use consistent location format for easier parsing

## Node-RED Flow Implementation

### Flow 1: Calendar Event Processor (runs every 30 minutes)

This flow reads calendar events and processes them:

```javascript
[Inject: Every 30 min]
    ↓
[Get Calendar Events]
    ↓
[Parse Events Function]
    ↓
[Calculate Distances]
    ↓
[Generate Arrays Function]
    ↓
[POST to EMHASS-EV API]
```

### Key Node Configurations

#### 1. Get Calendar Events Node

Use the Home Assistant Events: calendar node:

```javascript
// Configuration
entity_id: calendar.personal
service: get_events
data: {
  "start_date_time": "{{ now() }}",
  "end_date_time": "{{ now() + timedelta(days=7) }}"
}
```

#### 2. Parse Events Function Node

```javascript
// Extract upcoming trips from calendar events
const events = msg.payload;
const trips = [];
const homeLocation = {
    lat: 50.8503,  // Your home latitude
    lon: 4.3517    // Your home longitude
};

for (let event of events) {
    if (event.location) {
        trips.push({
            start: new Date(event.start.dateTime),
            end: new Date(event.end.dateTime),
            location: event.location,
            summary: event.summary
        });
    }
}

msg.trips = trips;
msg.homeLocation = homeLocation;
return msg;
```

#### 3. Calculate Distance Function (Google Maps)

```javascript
// For each trip, calculate distance to destination
const trips = msg.trips;
const apiKey = "YOUR_GOOGLE_MAPS_API_KEY";
const origin = `${msg.homeLocation.lat},${msg.homeLocation.lon}`;

// Build requests for each destination
let requests = [];
for (let trip of trips) {
    const destination = encodeURIComponent(trip.location);
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origin}&destinations=${destination}&key=${apiKey}`;
    
    requests.push({
        url: url,
        trip: trip
    });
}

msg.distanceRequests = requests;
return msg;
```

#### 4. Calculate Distance Function (HERE API)

```javascript
// Alternative using HERE API
const trips = msg.trips;
const apiKey = "YOUR_HERE_API_KEY";
const origin = `${msg.homeLocation.lat},${msg.homeLocation.lon}`;

let requests = [];
for (let trip of trips) {
    // Geocode destination first or use coordinates
    const url = `https://router.hereapi.com/v8/routes?transportMode=car&origin=${origin}&destination=${encodeURIComponent(trip.location)}&return=summary&apiKey=${apiKey}`;
    
    requests.push({
        url: url,
        trip: trip
    });
}

msg.distanceRequests = requests;
return msg;
```

#### 5. Generate Arrays Function

This is the core logic that generates availability and range requirement arrays:

```javascript
// Generate availability and minimum range arrays
const trips = msg.trips;  // Now includes distance in km
const optimizationHorizon = 48;  // 48 hours = 2 days
const timeStep = 30;  // 30 minutes per step
const totalSteps = (optimizationHorizon * 60) / timeStep;  // 96 steps

// Initialize arrays (all available, no range requirement)
let availability = new Array(totalSteps).fill(1);
let minRangeKm = new Array(totalSteps).fill(0);

// Current time
const now = new Date();

// EV parameters (should match EMHASS-EV config)
const evConsumption = 0.15;  // kWh/km
const safetyMargin = 1.2;     // 20% extra range for safety

// Process each trip
for (let trip of trips) {
    const tripStart = new Date(trip.start);
    const tripEnd = new Date(trip.end);
    const distanceKm = trip.distanceKm;
    const roundTripKm = distanceKm * 2 * safetyMargin;  // Round trip with margin
    
    // Calculate time steps for this trip
    const startStep = Math.floor((tripStart - now) / (timeStep * 60 * 1000));
    const endStep = Math.floor((tripEnd - now) / (timeStep * 60 * 1000));
    
    if (startStep >= 0 && startStep < totalSteps) {
        // Set availability to 0 during trip (vehicle away)
        for (let i = startStep; i < Math.min(endStep, totalSteps); i++) {
            if (i >= 0) {
                availability[i] = 0;
            }
        }
        
        // Set minimum range requirement before trip starts
        for (let i = 0; i <= startStep && i < totalSteps; i++) {
            minRangeKm[i] = Math.max(minRangeKm[i], roundTripKm);
        }
    }
}

msg.payload = {
    availability: availability,
    min_range_km: minRangeKm,
    ev_id: 0  // First EV (0-indexed)
};

return msg;
```

#### 6. POST to EMHASS-EV API

```javascript
// HTTP Request node configuration
Method: POST
URL: http://homeassistant.local:5001/action/ev-availability
Headers: {
    "Content-Type": "application/json"
}
Body: {
    "availability": {{payload.availability}}
}

// Then another HTTP Request for range requirements
Method: POST
URL: http://homeassistant.local:5001/action/ev-range-requirements
Headers: {
    "Content-Type": "application/json"
}
Body: {
    "min_range_km": {{payload.min_range_km}}
}
```

## Complete Example Flow (JSON)

Save this as a JSON file and import into Node-RED:

```json
[
    {
        "id": "calendar_processor",
        "type": "inject",
        "name": "Every 30 minutes",
        "props": [],
        "repeat": "1800",
        "crontab": "",
        "once": true,
        "x": 150,
        "y": 100,
        "wires": [["get_calendar"]]
    },
    {
        "id": "get_calendar",
        "type": "api-current-state",
        "name": "Get Calendar Events",
        "server": "home_assistant",
        "outputs": 1,
        "halt_if": "",
        "halt_if_type": "str",
        "halt_if_compare": "is",
        "entity_id": "calendar.personal",
        "state_type": "str",
        "state_location": "payload",
        "override_topic": false,
        "x": 350,
        "y": 100,
        "wires": [["parse_events"]]
    },
    {
        "id": "parse_events",
        "type": "function",
        "name": "Parse Calendar Events",
        "func": "// Use the function code from section above",
        "x": 550,
        "y": 100,
        "wires": [["calc_distance"]]
    },
    {
        "id": "calc_distance",
        "type": "function",
        "name": "Calculate Distances",
        "func": "// Use distance calculation code from above",
        "x": 750,
        "y": 100,
        "wires": [["generate_arrays"]]
    },
    {
        "id": "generate_arrays",
        "type": "function",
        "name": "Generate Arrays",
        "func": "// Use array generation code from above",
        "x": 950,
        "y": 100,
        "wires": [["post_availability", "post_range"]]
    },
    {
        "id": "post_availability",
        "type": "http request",
        "name": "POST Availability",
        "method": "POST",
        "url": "http://homeassistant.local:5001/action/ev-availability",
        "x": 1150,
        "y": 80,
        "wires": [[]]
    },
    {
        "id": "post_range",
        "type": "http request",
        "name": "POST Range Requirements",
        "method": "POST",
        "url": "http://homeassistant.local:5001/action/ev-range-requirements",
        "x": 1150,
        "y": 120,
        "wires": [[]]
    }
]
```

## Flow 2: SOC Sync (runs every 5 minutes)

Keep EMHASS-EV synchronized with your actual EV battery state:

```javascript
[Inject: Every 5 min]
    ↓
[Get EV SOC Sensor]
    ↓
[POST to EMHASS-EV SOC API]
```

### SOC Sync Function

```javascript
// Get current SOC from your EV integration
const socPercent = parseFloat(msg.payload);

// POST to EMHASS-EV
msg.payload = {
    "ev_id": 0,
    "soc_percent": socPercent
};
msg.headers = {
    "Content-Type": "application/json"
};
msg.method = "POST";
msg.url = "http://homeassistant.local:5001/action/ev-soc";

return msg;
```

## Testing and Validation

### 1. Test Calendar Integration

Create a test event:
```
Title: "Test Trip"
Location: "City 50km away"
Start: Tomorrow 10:00
Duration: 2 hours
```

### 2. Monitor Node-RED Debug

Add debug nodes after each function to verify:
- Calendar events are retrieved correctly
- Distances are calculated accurately
- Arrays are generated with correct values
- API calls return HTTP 200 status

### 3. Verify EMHASS-EV Reception

Check EMHASS-EV API status:
```bash
curl http://homeassistant.local:5001/action/ev-status?ev_id=0
```

Expected response:
```json
{
    "ev_id": 0,
    "soc_percent": 65.5,
    "soc_kwh": 50.4,
    "range_km": 336,
    "availability": [1,1,1,0,0,0,1,1,...],
    "min_range_km": [100,100,100,100,100,0,0,...]
}
```

### 4. Run Optimization

Trigger EMHASS optimization and check results:
```bash
curl -X POST http://homeassistant.local:5001/action/dayahead-optim
```

Check sensor values in Home Assistant:
- `sensor.p_ev0` - Should show charging power schedule
- `sensor.soc_ev0` - Should show predicted SOC

## Troubleshooting

### Issue: No calendar events retrieved

**Solution:**
- Verify calendar integration is working in Home Assistant
- Check calendar entity ID in Node-RED matches HA
- Ensure events have locations filled in

### Issue: Distance calculation fails

**Solution:**
- Verify API key is valid
- Check API quota hasn't been exceeded
- Test API endpoint manually with curl
- Ensure location format is geocodable

### Issue: Arrays have wrong length

**Solution:**
- Verify `optimizationHorizon` matches EMHASS config (default 48 hours)
- Verify `timeStep` matches EMHASS config (default 30 minutes)
- Check calculation: totalSteps = (horizon * 60) / timeStep

### Issue: EMHASS-EV doesn't receive data

**Solution:**
- Check EMHASS-EV is running: `http://homeassistant.local:5001`
- Verify firewall allows communication
- Check API endpoint URLs are correct
- Verify JSON payload format with debug node

### Issue: Optimization doesn't charge enough

**Solution:**
- Increase safety margin in array generation (e.g., 1.3 = 30%)
- Check EV consumption efficiency is accurate
- Verify minimum range requirements are set correctly
- Check that availability array correctly reflects vehicle presence

## Advanced Features

### Multi-Vehicle Support

For multiple EVs, run separate flows or modify the function to handle multiple vehicles:

```javascript
// In generate arrays function
const evConfig = [
    { id: 0, consumption: 0.15, safetyMargin: 1.2 },
    { id: 1, consumption: 0.18, safetyMargin: 1.15 }
];

// Generate arrays for each vehicle
for (let ev of evConfig) {
    // ... array generation logic for ev.id
    // POST to API with ev_id parameter
}
```

### Dynamic Pricing Integration

Combine with energy price data for cost-optimized charging:

```javascript
// Get electricity prices from Home Assistant
const prices = msg.prices;  // Array of prices per time step

// Add to EMHASS optimization via API
// EMHASS will optimize charging during low-price periods
// while meeting range requirements
```

### Smart Departure Time

Extract departure time from calendar and adjust optimization:

```javascript
// Parse calendar description for "Departure: HH:MM"
const description = event.description;
const departureMatch = description.match(/Departure: (\\d{2}):(\\d{2})/);

if (departureMatch) {
    const departureTime = new Date(event.start);
    departureTime.setHours(departureMatch[1], departureMatch[2]);
    // Adjust availability array based on actual departure time
}
```

### Return Time Estimation

If return time is in calendar description:

```javascript
const returnMatch = description.match(/Return: (\\d{2}):(\\d{2})/);
if (returnMatch) {
    // Adjust end time for availability array
    tripEnd.setHours(returnMatch[1], returnMatch[2]);
}
```

## Best Practices

1. **Regular SOC Sync**: Update SOC every 5 minutes for accurate optimization
2. **Safety Margins**: Always add 15-20% extra range for unexpected detours
3. **Calendar Hygiene**: Keep locations accurate and up-to-date
4. **API Quota Management**: Monitor API usage to avoid exceeding free tier
5. **Error Handling**: Add try-catch blocks and fallback values
6. **Logging**: Use debug nodes to track flow execution
7. **Testing**: Test with fake events before relying on automation

## Security Considerations

1. **API Keys**: Store in Node-RED configuration nodes, not in function code
2. **HTTPS**: Use HTTPS for external API calls when possible
3. **Authentication**: Consider adding authentication to EMHASS-EV API in production
4. **Data Privacy**: Be mindful of location data sent to external APIs

## Next Steps

1. Set up the Node-RED flow using this guide
2. Test with a few calendar events
3. Monitor results and tune parameters (safety margin, consumption)
4. Add Home Assistant automation to control charger
5. Expand with additional features as needed

## Support and Resources

- **EMHASS-EV Documentation**: https://github.com/tomvanacker85/emhass-ev
- **Node-RED Docs**: https://nodered.org/docs/
- **Home Assistant Community**: https://community.home-assistant.io/
- **Google Maps API**: https://developers.google.com/maps/documentation/distance-matrix
- **HERE API**: https://developer.here.com/documentation

---

**Last Updated**: January 2026
**Version**: 1.0
