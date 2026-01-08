# PayLap Relay Server - Quick Reference

## Start in Termux

```bash
cd paylap-node-server
bash setup-termux.sh
```

## API Endpoints

- `POST /unlock` - Unlock door
- `POST /lock` - Lock door  
- `GET /status` - Check status
- `GET /health` - Health check

## Quick Test

```bash
# Health check
curl http://localhost:3000/health

# Get status
curl http://localhost:3000/status

# Unlock door
curl -X POST http://localhost:3000/unlock
```

## PM2 Commands

```bash
pm2 status          # Check status
pm2 logs            # View logs
pm2 restart all     # Restart
```

## From Expo App

```typescript
const response = await fetch('http://192.168.1.51:3000/unlock', {
  method: 'POST'
});
```

## Troubleshoot

If server stops:
```bash
pm2 restart paylap-relay
termux-wake-lock
```
