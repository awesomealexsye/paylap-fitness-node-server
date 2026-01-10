#!/data/data/com.termux/files/usr/bin/bash
#
# PayLap Relay Server - Termux One-Click Update/Setup Script
# ==========================================================
# This script performs a clean installation or update of the relay server.
#
# Usage:
#   bash setup-termux.sh
#

set -e  # Exit on any error

echo ""
echo "🚀 PayLap Relay Server - Termux Smart Setup"
echo "=========================================="
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
    exit 1
fi

# Step 0: Clean Up Existing Setup (User requested fresh reinstall flow)
print_info "Cleaning up existing processes..."
if command -v pm2 &> /dev/null; then
    pm2 delete all 2>/dev/null || true
    pm2 kill 2>/dev/null || true
fi

# Step 1: Update Termux Core
print_info "Step 1: Updating Termux packages..."
pkg update -y && pkg upgrade -y || print_warning "Update failed, continuing anyway..."

# Step 2: Install Essentials
print_info "Step 2: Installing Node.js and Git..."
pkg install nodejs git -y

# Step 3: Install Dependencies
print_info "Step 3: Installing project dependencies..."
if [ -f "package.json" ]; then
    npm install
    print_success "Dependencies installed"
else
    print_error "package.json not found! Please run this script inside the project folder."
    exit 1
fi

# Step 4: Install PM2 Globally
print_info "Step 4: Ensuring PM2 is installed..."
npm install -g pm2

# Step 5: Verify Config
print_info "Step 5: Verifying config.json..."
if [ ! -f "config.json" ]; then
    print_error "config.json missing! Creating a template..."
    cat > config.json << 'EOF'
{
    "device_id": "YOUR_DEVICE_ID",
    "local_key": "YOUR_LOCAL_KEY",
    "local_ip": "192.168.1.XX",
    "version": "3.5"
}
EOF
    print_warning "Template config.json created. PLEASE EDIT IT with your credentials."
    exit 1
fi

# Step 6: Start Server (Persistent Mode)
print_info "Step 6: Starting relay server in background..."

# Check if ecosystem.config.js exists, otherwise start server.js directly
if [ -f "ecosystem.config.js" ]; then
    pm2 start ecosystem.config.js
else
    pm2 start server.js --name "paylap-relay"
fi

# Save PM2 list so it starts on boot
pm2 save

# Enable wake lock
termux-wake-lock || print_warning "Wake lock failed. Ensure Termux:API is installed."

echo ""
print_success "======================================"
print_success "🎉 Update Complete & Server Running!"
print_success "======================================"
echo ""
print_info "Server Status:"
pm2 status

echo ""
print_info "Useful Commands:"
echo "  pm2 logs paylap-relay    - Watch live logs"
echo "  pm2 restart paylap-relay - Apply changes after editing config.json"
echo "  pm2 status               - Check if server is running"
echo ""

# Test health locally
print_info "Testing health check..."
sleep 2
curl -s http://localhost:3000/health || print_error "Relay server is not responding!"

echo ""
print_success "✅ Setup finished. Your door is ready for instant unlocking."
echo ""
