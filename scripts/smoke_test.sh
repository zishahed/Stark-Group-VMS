#!/usr/bin/env bash
set -euo pipefail

# Requires curl and jq. This will create a test user and an active vehicle.
API="${API_BASE_URL:-http://localhost:8080}"
SUFFIX="$(date +%s)"
EMAIL="vms.smoke.$SUFFIX@example.com"
PASS="test-password-$SUFFIX"

printf 'Health: '
curl -fsS "$API/api/v1/health" | jq .

printf '\nChecking anonymous requests are blocked (expect 401)...\n'
code="$(curl -s -o /dev/null -w '%{http_code}' "$API/api/v1/vehicles")"
[ "$code" = "401" ] || { echo "Expected 401, got $code"; exit 1; }

printf '\nRegistering a test account...\n'
reg="$(curl -fsS -H 'Content-Type: application/json' -d \
    "{\"fullName\":\"Smoke Test\",\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" \
    "$API/api/v1/auth/register")"
TOKEN="$(echo "$reg" | jq -r '.accessToken')"
[ -n "$TOKEN" ] && [ "$TOKEN" != null ] || exit 1

plate_num="$(printf '%04d' "$((10#$SUFFIX % 10000))")"
PLATE="DHAKA METRO - GHA - 99 - $plate_num"
body="$(jq -n --arg plate "$PLATE" '{
  vehicleName:"QA Demo", manufacturer:"Toyota", model:"Land Cruiser",
  color:"White", seatCapacity:7, numberPlate:$plate, engineCc:2800,
  vehicleType:"SUV", fuelType:"DIESEL", status:"AVAILABLE",
  assignedDepot:"QA Depot", manufactureYear:2020, notes:"Smoke test"
}')"

printf 'Creating vehicle...\n'
created="$(curl -fsS -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "$body" "$API/api/v1/vehicles")"
ID="$(echo "$created" | jq -r '.id')"
[ "$ID" != null ] || exit 1

printf 'Checking database duplicate protection (expect 409)...\n'
code="$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "$body" "$API/api/v1/vehicles")"
[ "$code" = "409" ] || { echo "Expected 409, got $code"; exit 1; }

printf 'Archiving vehicle...\n'
code="$(curl -s -o /dev/null -w '%{http_code}' -X DELETE \
  -H "Authorization: Bearer $TOKEN" "$API/api/v1/vehicles/$ID")"
[ "$code" = "204" ] || { echo "Expected 204, got $code"; exit 1; }

printf 'Checking archived vehicle hidden (expect 404)...\n'
code="$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" "$API/api/v1/vehicles/$ID")"
[ "$code" = "404" ] || { echo "Expected 404, got $code"; exit 1; }

echo 'PASS: health, authentication, add, duplicate, soft-delete, hidden archived row.'
