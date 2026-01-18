#!/bin/bash
# Test script for EV API endpoints
# Run this after restarting the Docker container to test the new EV functionality

BASE_URL="http://localhost:5001"

echo "=========================================="
echo "Testing EV API Endpoints"
echo "=========================================="
echo ""

# Test 1: Check EV status (should show EV optimization disabled by default)
echo "1. GET /action/ev-status - Check EV status"
curl -s "${BASE_URL}/action/ev-status?ev_index=0" | jq .
echo ""
echo ""

# Test 2: Update EV SOC (requires EV to be enabled first)
echo "2. POST /action/ev-soc - Update SOC to 75%"
curl -s -X POST "${BASE_URL}/action/ev-soc" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 0, "soc_percent": 75.0}' | jq .
echo ""
echo ""

# Test 3: Set EV availability schedule (24 hours, available from hour 18-24)
echo "3. POST /action/ev-availability - Set availability schedule"
AVAILABILITY='[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1]'
curl -s -X POST "${BASE_URL}/action/ev-availability" \
  -H "Content-Type: application/json" \
  -d "{\"ev_index\": 0, \"availability\": ${AVAILABILITY}}" | jq .
echo ""
echo ""

# Test 4: Set minimum range requirements (need 100km at departure time)
echo "4. POST /action/ev-range-requirements - Set range requirements"
RANGE='[0,0,0,0,0,0,0,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]'
curl -s -X POST "${BASE_URL}/action/ev-range-requirements" \
  -H "Content-Type: application/json" \
  -d "{\"ev_index\": 0, \"range_km\": ${RANGE}}" | jq .
echo ""
echo ""

# Test 5: Check EV status again after updates
echo "5. GET /action/ev-status - Check status after updates"
curl -s "${BASE_URL}/action/ev-status?ev_index=0" | jq .
echo ""
echo ""

echo "=========================================="
echo "Test complete!"
echo "=========================================="
echo ""
echo "To enable EV optimization:"
echo "1. Edit config.json or use the web UI"
echo "2. Set 'number_of_ev_loads' to 1 (or higher for multiple EVs)"
echo "3. Configure EV parameters (battery capacity, charging power, etc.)"
echo "4. Restart the container or call /set-config endpoint"
echo ""
