# API Testing

## Quick Test

```bash
bash test-api.sh
```

## Test with Custom URL

```bash
bash test-api.sh http://192.168.1.51:3000
```

## What Gets Tested

1. ✅ Health check endpoint
2. ✅ Root endpoint (server info)
3. ✅ Relay status check
4. ✅ Unlock door
5. ✅ Lock door
6. ✅ 404 error handling

## Output

- Color-coded console output
- Detailed log file: `api-test-results.log`
- Test summary with pass/fail counts

## Requirements

- Server must be running (`npm start`)
- Optional: `jq` for pretty JSON formatting

```bash
# Install jq (optional)
# Mac:
brew install jq

# Termux:
pkg install jq
```
