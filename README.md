  # PayLap Node Server - Relay Control API
  
Production-ready Node.js HTTP server for controlling magnetic door locks via YODE WiFi Relay.

## Features

- ✅ RESTful HTTP API
- ✅ Offline local WiFi control
- ✅ Auto-lock after configurable duration
- ✅ PM2 process management
- ✅ **Termux auto-setup script**
- ✅ Health monitoring
- ✅ Error handling

## Quick Start

### On Computer (Development/Testing)

```bash
cd paylap-node-server
npm install
npm start
```

### On Android (Termux - Production)

```bash
# Transfer files to Android device
# Then in Termux:
cd paylap-node-server
bash setup-termux.sh
```

**That's it!** The script handles everything automatically.

## API Endpoints

### POST /unlock
Unlock door for configured duration (default 3 seconds)

**Request:**
```bash
curl -X POST http://192.168.1.51:3000/unlock
```

**Response:**
```json
{
  "success": true,
  "message": "Door unlocked",
  "state": "unlocked",
  "duration": 3000,
  "timestamp": "2026-01-08T14:30:00.000Z"
}
```

### POST /lock
Lock door immediately

**Request:**
```bash
curl -X POST http://192.168.1.51:3000/lock
```

**Response:**
```json
{
  "success": true,
  "message": "Door locked",
  "state": "locked",
  "timestamp": "2026-01-08T14:30:00.000Z"
}
```

### GET /status
Check relay and server status

**Request:**
```bash
curl -X GET http://192.168.1.51:3000/status
```

**Response:**
```json
{
  "success": true,
  "relay": {
    "state": "locked",
    "online": true,
    "ip": "192.168.0.127"
  },
  "server": {
    "status": "online",
    "uptime": 3600,
    "port": 3000
  },
  "timestamp": "2026-01-08T14:30:00.000Z"
}
```

### GET /health
Simple health check

**Request:**
```bash
curl http://192.168.1.51:3000/health
```

**Response:**
```json
{
  "status": "online",
  "service": "paylap-relay-server",
  "timestamp": "2026-01-08T14:30:00.000Z"
}
```

## Configuration

Edit `config.json` with your relay credentials:

```json
{
  "device_id": "your_device_id",
  "local_key": "your_local_key",
  "local_ip": "192.168.1.100",
  "version": "3.5"
}
```

### Environment Variables

- `PORT` - Server port (default: 3000)
- `DOOR_UNLOCK_DURATION` - Unlock duration in ms (default: 3000)

## PM2 Commands

```bash
pm2 start ecosystem.config.js  # Start server
pm2 stop paylap-relay          # Stop server
pm2 restart paylap-relay       # Restart server
pm2 logs paylap-relay          # View logs
pm2 status                     # Check status
```

## Termux Setup Script

The `setup-termux.sh` script automatically:

1. ✅ Updates Termux packages
2. ✅ Installs Node.js if needed
3. ✅ Installs npm dependencies
4. ✅ Creates logs directory
5. ✅ Validates config.json
6. ✅ Tests relay connection
7. ✅ Installs PM2 globally
8. ✅ Configures PM2 auto-start
9. ✅ Starts server in background
10. ✅ Enables wake lock
11. ✅ Displays status

**Usage:**
```bash
bash setup-termux.sh
```

## File Structure

```
paylap-node-server/
├── server.js              # Main HTTP server
├── ecosystem.config.js     # PM2 configuration
├── config.json            # Relay credentials
├── package.json           # Dependencies
├── setup-termux.sh        # Auto-setup script
├── logs/                  # Log files (created by PM2)
└── README.md              # This file
```

## Integration with Expo App

Update your Expo kiosk app config:

```typescript
// constants/config.ts
relay: {
  ip: '192.168.1.51',  // Android device IP running this server
  port: 3000
}
```

Then in your app:
```typescript
await fetch('http://192.168.1.51:3000/unlock', { method: 'POST' });
```

## Troubleshooting

### Server won't start
```bash
# Check if port 3000 is in use
pm2 logs paylap-relay

# Kill any process using port 3000
pm2 delete paylap-relay
pm2 start ecosystem.config.js
```

### Relay connection fails
- Check WiFi connection
- Verify `config.json` credentials
- Ensure relay is on same network
- Test with: `curl http://192.168.1.51:3000/status`

### PM2 not persisting
```bash
pm2 save
pm2 startup
```

### Termux kills process
```bash
# Enable wake lock
termux-wake-lock

# Disable battery optimization for Termux
# Settings → Apps → Termux → Battery → Unrestricted
```

## Production Deployment

### Per Gym Setup

1. Install Termux on Android device (from F-Droid)
2. Transfer `paylap-node-server` folder to device
3. Run: `bash setup-termux.sh`
4. Note the local IP address
5. Update Expo app config with this IP
6. Test: Open Expo app, try face scan

**Setup time: ~5 minutes per gym**

## Dependencies

- **express**: HTTP server framework
- **tuyapi**: Tuya device control
- **cors**: Cross-origin requests
- **pm2**: Process manager

## License

MIT - PayLap Fitness
