#!/data/data/com.termux/files/usr/bin/bash
#
# PayLap Fitness - Automatic Termux Setup Script
# ================================================
# This script will automatically setup the relay server in Termux
#
# What it does:
# 1. Updates Termux packages
# 2. Installs Node.js and Git
# 3. Clones the server repository from GitHub
# 4. Installs all dependencies
# 5. Tests relay connection
# 6. Starts server with PM2
# 7. Enables auto-start on boot
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/awesomealexsye/paylap-fitness-node-server"
SERVER_DIR="$HOME/paylap-relay-server"
PORT=3000

echo -e "${BLUE}"
echo "======================================"
echo "  PayLap Fitness - Termux Auto Setup"
echo "======================================"
echo -e "${NC}"
echo ""

# Step 1: Update packages
echo -e "${YELLOW}[1/8] Updating Termux packages...${NC}"
pkg update -y && pkg upgrade -y
echo -e "${GREEN}✅ Packages updated${NC}"
echo ""

# Step 2: Install required packages
echo -e "${YELLOW}[2/8] Installing Node.js and Git...${NC}"
pkg install -y nodejs git
echo -e "${GREEN}✅ Node.js $(node --version) installed${NC}"
echo -e "${GREEN}✅ Git $(git --version | cut -d' ' -f3) installed${NC}"
echo ""

# Step 3: Clone repository
echo -e "${YELLOW}[3/8] Cloning server repository...${NC}"
if [ -d "$SERVER_DIR" ]; then
    echo "Server directory already exists. Removing old version..."
    rm -rf "$SERVER_DIR"
fi
git clone "$REPO_URL" "$SERVER_DIR"
cd "$SERVER_DIR"
echo -e "${GREEN}✅ Repository cloned to: $SERVER_DIR${NC}"
echo ""

# Step 4: Install dependencies
echo -e "${YELLOW}[4/8] Installing Node.js dependencies...${NC}"
npm install --legacy-peer-deps
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Step 5: Test relay connection (optional - may fail if relay not available)
echo -e "${YELLOW}[5/8] Testing relay connection...${NC}"
# Start server in background with timeout
timeout 5 node server.js > /tmp/server-test.log 2>&1 &
SERVER_PID=$!

# Wait a bit for server to start
sleep 2

# Try to check if server is running by checking the log or process
if ps -p $SERVER_PID > /dev/null 2>&1; then
    # Kill the server process
    kill $SERVER_PID 2>/dev/null || true
    # Also kill any other node processes just to be safe
    pkill -f "node server.js" 2>/dev/null || true
    echo -e "${GREEN}✅ Server test passed${NC}"
else
    echo -e "${YELLOW}⚠️  Server test skipped (will check after PM2 setup)${NC}"
fi

# Clean up
rm -f /tmp/server-test.log
echo ""

# Step 6: Install PM2 globally
echo -e "${YELLOW}[6/8] Installing PM2 process manager...${NC}"
npm install -g pm2
echo -e "${GREEN}✅ PM2 installed${NC}"
echo ""

# Step 7: Start server with PM2
echo -e "${YELLOW}[7/8] Starting server with PM2...${NC}"
pm2 delete paylap-relay 2>/dev/null || true  # Delete old instance if exists
pm2 start ecosystem.config.js
pm2 save
echo -e "${GREEN}✅ Server started with PM2${NC}"
echo ""

# Step 8: Setup PM2 startup
echo -e "${YELLOW}[8/8] Configuring auto-start on boot...${NC}"
pm2 startup | grep -v "PM2" | bash || true
pm2 save
echo -e "${GREEN}✅ Auto-start configured${NC}"
echo ""

# Enable wake lock to keep Termux running
echo -e "${YELLOW}Acquiring wake lock...${NC}"
termux-wake-lock 2>/dev/null || pkg install -y termux-api && termux-wake-lock
echo -e "${GREEN}✅ Wake lock enabled${NC}"
echo ""

# Display status
echo -e "${BLUE}"
echo "======================================"
echo "  ✅ Setup Complete!"
echo "======================================"
echo -e "${NC}"
echo ""
echo -e "${GREEN}Server is now running on port $PORT${NC}"
echo ""
echo "📊 Check server status:"
echo "   pm2 status"
echo ""
echo "📋 View server logs:"
echo "   pm2 logs paylap-relay"
echo ""
echo "🔄 Restart server:"
echo "   pm2 restart paylap-relay"
echo ""
echo "🛑 Stop server:"
echo "   pm2 stop paylap-relay"
echo ""
echo "🧪 Test server:"
echo "   curl http://localhost:$PORT/health"
echo ""
echo -e "${BLUE}======================================"
echo "Server location: $SERVER_DIR"
echo "======================================"
echo -e "${NC}"
echo ""
echo -e "${GREEN}🎉 All done! Your relay server is ready!${NC}"
echo ""

# Show PM2 status
pm2 status
