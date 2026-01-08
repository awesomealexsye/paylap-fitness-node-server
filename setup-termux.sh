#!/data/data/com.termux/files/usr/bin/bash
#
# PayLap Relay Server - Termux Auto Setup Script
# ===============================================
# This script automates the complete setup and deployment of the relay server in Termux
#
# Usage:
#   bash setup-termux.sh
#

set -e  # Exit on any error

echo ""
echo "🚀 PayLap Relay Server - Termux Setup"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if running in Termux
if [ ! -d "/data/data/com.termux" ]; then
    print_error "This script must be run in Termux!"
    print_info "Please install Termux from F-Droid (not Play Store)"
    exit 1
fi

print_success "Running in Termux"

# Step 1: Update Termux packages
print_info "Step 1: Updating Termux packages..."
pkg update -y || print_warning "Update failed, continuing anyway..."

# Step 2: Install Node.js if not installed
print_info "Step 2: Checking Node.js installation..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js already installed: $NODE_VERSION"
else
    print_info "Installing Node.js..."
    pkg install nodejs -y
    print_success "Node.js installed: $(node --version)"
fi

# Step 3: Install npm if not installed (should come with Node.js)
print_info "Step 3: Checking npm installation..."
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    print_success "npm already installed: v$NPM_VERSION"
else
    print_error "npm not found! Node.js installation may have failed"
    exit 1
fi

# Step 4: Install project dependencies
print_info "Step 4: Installing project dependencies..."
if [ -f "package.json" ]; then
    npm install
    print_success "Dependencies installed"
else
    print_error "package.json not found! Are you in the correct directory?"
    exit 1
fi

# Step 5: Create logs directory
print_info "Step 5: Creating logs directory..."
mkdir -p logs
print_success "Logs directory created"

# Step 6: Check config.json
print_info "Step 6: Checking configuration..."
if [ -f "config.json" ]; then
    print_success "config.json found"
    
    # Validate JSON
    if node -e "JSON.parse(require('fs').readFileSync('config.json', 'utf8'))" 2>/dev/null; then
        print_success "config.json is valid"
    else
        print_error "config.json is invalid JSON!"
        exit 1
    fi
else
    print_error "config.json not found!"
    print_info "Please create config.json with your relay credentials"
    exit 1
fi

# Step 7: Test relay connection
print_info "Step 7: Testing relay connection..."
print_warning "This will attempt to connect to your relay..."

# Create test script
cat > test-connection.js << 'EOF'
const TuyAPI = require('tuyapi');
const fs = require('fs');

const config = JSON.parse(fs.readFileSync('./config.json', 'utf8'));
const device = new TuyAPI({
    id: config.device_id,
    key: config.local_key,
    ip: config.local_ip,
    version: config.version || '3.5'
});

let connected = false;

device.on('connected', () => {
    console.log('✅ Connected to relay');
});

device.on('data', (data) => {
    if (!connected) {
        connected = true;
        console.log('✅ Relay responding');
        console.log('✅ Connection test PASSED');
        device.disconnect();
        process.exit(0);
    }
});

device.on('error', (err) => {
    console.error('❌ Connection test FAILED:', err.message);
    process.exit(1);
});

setTimeout(() => {
    if (!connected) {
        console.error('❌ Connection timeout');
        process.exit(1);
    }
}, 10000);

device.find().then(() => {
    return device.connect();
}).catch(err => {
    console.error('❌ Connection failed:', err.message);
    process.exit(1);
});
EOF

# Run connection test
if node test-connection.js; then
    print_success "Relay connection successful"
    rm -f test-connection.js
else
    print_error "Relay connection failed!"
    print_info "Please check your config.json settings"
    rm -f test-connection.js
    exit 1
fi

# Step 8: Install PM2 globally
print_info "Step 8: Checking PM2 installation..."
if command -v pm2 &> /dev/null; then
    PM2_VERSION=$(pm2 --version)
    print_success "PM2 already installed: v$PM2_VERSION"
else
    print_info "Installing PM2 globally..."
    npm install -g pm2
    print_success "PM2 installed: v$(pm2 --version)"
fi

# Step 9: Setup PM2 startup
print_info "Step 9: Setting up PM2 for auto-start..."
pm2 startup 2>/dev/null || print_warning "PM2 startup may require manual configuration"

# Step 10: Start server with PM2
print_info "Step 10: Starting relay server with PM2..."

# Stop any existing instance
pm2 delete paylap-relay 2>/dev/null || true

# Start new instance
pm2 start ecosystem.config.js

# Save PM2 process list
pm2 save

print_success "Server started with PM2"

# Step 11: Enable wake lock (prevent Android from killing process)
print_info "Step 11: Setting up wake lock..."
if command -v termux-wake-lock &> /dev/null; then
    termux-wake-lock
    print_success "Wake lock enabled"
else
    print_warning "termux-wake-lock not available"
    print_info "Install 'Termux:API' app for wake lock support"
fi

# Step 12: Display status
echo ""
print_success "======================================"
print_success "🎉 Setup Complete!"
print_success "======================================"
echo ""
print_info "Server Status:"
pm2 status

echo ""
print_info "Useful Commands:"
echo "  pm2 status           - Check server status"
echo "  pm2 logs paylap-relay - View logs"
echo "  pm2 restart paylap-relay - Restart server"
echo "  pm2 stop paylap-relay   - Stop server"
echo "  npm start            - Run server manually"
echo ""

# Step 13: Test API endpoints
print_info "Testing API endpoints..."
sleep 2

# Get local IP
LOCAL_IP=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

if [ -z "$LOCAL_IP" ]; then
    print_warning "Could not detect local IP address"
    print_info "Server should be running on port 3000"
else
    print_success "Server running at: http://$LOCAL_IP:3000"
    echo ""
    print_info "Test with curl:"
    echo "  curl -X GET http://localhost:3000/health"
    echo "  curl -X GET http://localhost:3000/status"
    echo "  curl -X POST http://localhost:3000/unlock"
fi

echo ""
print_success "✅ All done! Relay server is running in background"
print_info "Logs are saved in ./logs/"
echo ""
