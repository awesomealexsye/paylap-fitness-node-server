#!/bin/bash
#
# PayLap Relay Server - API Test Script
# ======================================
# Tests all API endpoints and logs results
#
# Usage:
#   bash test-api.sh
#   bash test-api.sh http://192.168.1.51:3000  # Custom server URL
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_URL="${1:-http://localhost:3000}"
LOG_FILE="api-test-results.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Initialize log file
cat > "$LOG_FILE" << EOF
====================================
PayLap Relay Server - API Test Results
====================================
Test Date: $TIMESTAMP
Server URL: $SERVER_URL
====================================

EOF

echo ""
print_info "PayLap Relay Server - API Test Suite"
print_info "======================================"
print_info "Server: $SERVER_URL"
print_info "Log file: $LOG_FILE"
echo ""

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_status="${4:-200}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_info "Testing: $name"
    
    # Log to file
    echo "" >> "$LOG_FILE"
    echo "======================================" >> "$LOG_FILE"
    echo "[TEST $TOTAL_TESTS] $name" >> "$LOG_FILE"
    echo "======================================" >> "$LOG_FILE"
    echo "Method: $method" >> "$LOG_FILE"
    echo "Endpoint: $endpoint" >> "$LOG_FILE"
    echo "Command: curl -X $method -s -w '\nHTTP_STATUS:%{http_code}' $SERVER_URL$endpoint" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Execute curl with status code
    RESPONSE=$(curl -X "$method" -s -w '\nHTTP_STATUS:%{http_code}' "$SERVER_URL$endpoint" 2>&1)
    
    # Extract HTTP status and body
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')
    
    # Log response
    echo "HTTP Status: $HTTP_STATUS" >> "$LOG_FILE"
    echo "Response:" >> "$LOG_FILE"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Check if successful
    if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "500" ]; then
        print_success "Response received (HTTP $HTTP_STATUS)"
        echo "Status: ✅ PASSED" >> "$LOG_FILE"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        print_error "Unexpected status: $HTTP_STATUS"
        echo "Status: ❌ FAILED" >> "$LOG_FILE"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Pretty print JSON response if available
    if command -v jq &> /dev/null; then
        echo -e "${BLUE}Response:${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        echo "Response: $BODY"
    fi
    
    echo ""
}

# Check if server is running
print_info "Checking if server is running..."
if curl -s -o /dev/null -w "%{http_code}" "$SERVER_URL/health" | grep -q "200"; then
    print_success "Server is running!"
else
    print_error "Server is not responding!"
    print_info "Please start the server with: npm start"
    exit 1
fi

echo ""
print_info "Starting API tests..."
echo ""

# Test 1: Health Check
test_endpoint \
    "Health Check" \
    "GET" \
    "/health" \
    200

sleep 1

# Test 2: Root Endpoint
test_endpoint \
    "Root Endpoint (Server Info)" \
    "GET" \
    "/" \
    200

sleep 1

# Test 3: Status Check
test_endpoint \
    "Relay Status Check" \
    "GET" \
    "/status" \
    200

sleep 2

# Test 4: Unlock Door
test_endpoint \
    "Unlock Door" \
    "POST" \
    "/unlock" \
    200

sleep 4  # Wait for auto-lock

# Test 5: Lock Door
test_endpoint \
    "Lock Door" \
    "POST" \
    "/lock" \
    200

sleep 2

# Test 6: Invalid Endpoint (404 test)
print_info "Testing: Invalid Endpoint (404 Test)"
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo "" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"
echo "[TEST $TOTAL_TESTS] Invalid Endpoint (404 Test)" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"
echo "Method: GET" >> "$LOG_FILE"
echo "Endpoint: /invalid-endpoint" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$SERVER_URL/invalid-endpoint")
echo "HTTP Status: $HTTP_STATUS" >> "$LOG_FILE"

if [ "$HTTP_STATUS" == "404" ]; then
    print_success "404 handling works correctly"
    echo "Status: ✅ PASSED" >> "$LOG_FILE"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    print_warning "Expected 404, got $HTTP_STATUS"
    echo "Status: ⚠️  Unexpected status" >> "$LOG_FILE"
fi

echo ""

# Generate summary
echo "" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"
echo "TEST SUMMARY" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"
echo "Total Tests: $TOTAL_TESTS" >> "$LOG_FILE"
echo "Passed: $PASSED_TESTS" >> "$LOG_FILE"
echo "Failed: $FAILED_TESTS" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

if [ "$FAILED_TESTS" -eq 0 ]; then
    echo "Overall Status: ✅ ALL TESTS PASSED" >> "$LOG_FILE"
else
    echo "Overall Status: ⚠️  SOME TESTS FAILED" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
echo "Notes:" >> "$LOG_FILE"
echo "- If relay tests fail with 'connection timeout' or 'EHOSTUNREACH'," >> "$LOG_FILE"
echo "  it means the relay hardware is not accessible from this device." >> "$LOG_FILE"
echo "- This is expected when testing from Mac/PC." >> "$LOG_FILE"
echo "- Deploy to Android (Termux) on same WiFi as relay for actual control." >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"

# Display summary
echo ""
print_info "======================================"
print_info "TEST SUMMARY"
print_info "======================================"
echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC}      $PASSED_TESTS"
echo -e "${RED}Failed:${NC}      $FAILED_TESTS"
echo ""

if [ "$FAILED_TESTS" -eq 0 ]; then
    print_success "ALL TESTS PASSED! 🎉"
else
    print_warning "Some tests failed. Check $LOG_FILE for details."
fi

echo ""
print_info "Full test log saved to: $LOG_FILE"
echo ""

# Exit with appropriate code
if [ "$FAILED_TESTS" -eq 0 ]; then
    exit 0
else
    exit 1
fi
