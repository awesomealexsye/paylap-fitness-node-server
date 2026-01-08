# GET /config - Configuration Details

## New Endpoint Added ✅

Returns relay configuration details without exposing sensitive information.

## Request

```bash
curl http://localhost:3000/config
```

## Response

```json
{
  "success": true,
  "config": {
    "device_id": "d76e48f1800c31b712cjgj",
    "local_ip": "192.168.0.127",
    "version": "3.5",
    "local_key_configured": true
  },
  "server": {
    "port": 3000,
    "unlock_duration": 3000,
    "uptime": 1234.567
  },
  "timestamp": "2026-01-08T15:20:00.000Z"
}
```

## Security

- ✅ **local_key** is NOT exposed (security protection)
- ✅ Only shows if local_key is configured (boolean)
- ✅ Safe to expose to Expo app

## Use Case

Perfect for the Expo kiosk app to:
- Verify relay configuration
- Display relay IP in settings
- Confirm server connection
- Debug connectivity issues
