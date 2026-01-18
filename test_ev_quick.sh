#!/bin/bash
# Simple EV API test - test with minimal EV configuration

BASE_URL="http://localhost:5001"

echo "=========================================="
echo "EMHASS-EV Quick API Test"
echo "=========================================="
echo ""

# Test 1: Try to set SOC (this should init EV manager and tell us if it's enabled)
echo "Test 1: Setting EV SOC to 50%..."
RESPONSE=$(curl -s -X POST "${BASE_URL}/action/ev-soc" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 0, "soc_percent": 50.0}')
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Test 2: Check EV status
echo "Test 2: Checking EV status..."
curl -s "${BASE_URL}/action/ev-status?ev_index=0" | python3 -m json.tool
echo ""

# Test 3: Set availability
echo "Test 3: Setting availability schedule..."
curl -s -X POST "${BASE_URL}/action/ev-availability" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 0, "availability": [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]}' \
  | python3 -m json.tool
echo ""

# Test 4: Set range requirements
echo "Test 4: Setting range requirements..."
curl -s -X POST "${BASE_URL}/action/ev-range-requirements" \
  -H "Content-Type: application/json" \
  -d '{"ev_index": 0, "range_km": [0,0,0,0,0,0,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]}' \
  | python3 -m json.tool
echo ""

echo "=========================================="
echo "Test complete!"
echo "=========================================="
