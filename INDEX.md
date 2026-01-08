# PayLap Relay Server - Complete Guide

## 🚀 Quick Start

### Run Server
```bash
npm start
```

### Test All APIs
```bash
npm test
# or
bash test-api.sh
```

---

## 📝 Files Created

| File | Purpose |
|------|---------|
| `server.js` | Main HTTP server |
| `ecosystem.config.js` | PM2 config |
| `config.json` | Relay credentials |
| `setup-termux.sh` | **Auto-setup for Android** |
| `test-api.sh` | **API testing script** |
| `package.json` | Dependencies + scripts |

---

## ✅ API Endpoints

- **POST /unlock** - Unlock door (3s)
- **POST /lock** - Lock door immediately  
- **GET /status** - Relay + server status
- **GET /health** - Health check

---

## 🧪 Testing

```bash
# Full API test suite
bash test-api.sh

# Or via npm
npm test

# Custom server URL
bash test-api.sh http://192.168.1.51:3000
```

**Output:**
- ✅ Color-coded console output
- 📄 `api-test-results.log` - Detailed log file

---

## 🤖 Termux Deployment

```bash
# One command setup!
bash setup-termux.sh

# That's it! Server runs in background with PM2
```

**What it does:**
- Installs Node.js if needed
- Installs all dependencies
- Tests relay connection
- Starts with PM2 (auto-restart)
- Enables wake lock

---

## 📱 Integration with Expo App

```typescript
// In Expo kiosk app
const response = await fetch('http://192.168.1.51:3000/unlock', {
  method: 'POST'
});
```

---

## 📚 Documentation

- [README.md](README.md) - Full documentation
- [TESTING.md](TESTING.md) - Testing guide
- [QUICKSTART.md](QUICKSTART.md) - Quick reference
- [API-TEST-REPORT.md](API-TEST-REPORT.md) - Latest test results

---

## ✨ Features

✅ RESTful HTTP API  
✅ Offline local WiFi control  
✅ Auto-lock after 3 seconds  
✅ PM2 process management  
✅ Automated Termux setup  
✅ Comprehensive testing  
✅ Full documentation  

**Status: Production Ready!** 🎉
