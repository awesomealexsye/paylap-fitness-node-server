/**
 * PayLap Fitness - Node.js Relay Server
 * =====================================
 * HTTP API for controlling magnetic door locks via YODE WiFi Relay
 * 
 * Endpoints:
 * - POST /unlock      - Unlock door for configured duration
 * - POST /lock        - Lock door immediately
 * - GET  /status      - Check relay and server status
 * - GET  /config      - Get relay configuration
 * - GET  /health      - Health check
 */

const express = require('express');
const TuyAPI = require('tuyapi');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

// Configuration
const PORT = process.env.PORT || 3000;
const DOOR_UNLOCK_DURATION = parseInt(process.env.DOOR_UNLOCK_DURATION) || 3000; // 3 seconds
const CONFIG_FILE = process.env.CONFIG_FILE || 'config.json';

const app = express();

// Middleware
app.use(cors()); // Allow requests from Expo app
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true }));

// Load Relay Configuration
let config = {};
try {
    const configPath = path.join(__dirname, CONFIG_FILE);
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    console.log('✅ Configuration loaded successfully');
} catch (error) {
    console.error('❌ Error: config.json not found!');
    console.error('   Please create config.json with your relay credentials');
    process.exit(1);
}

// Initialize Tuya Device
const device = new TuyAPI({
    id: config.device_id,
    key: config.local_key,
    ip: config.local_ip,
    version: config.version || '3.5'
});

// Track relay state
let relayBusy = false;

/**
 * Helper: Trigger Relay with timeout protection
 */
async function triggerRelay(action, duration = DOOR_UNLOCK_DURATION) {
    return new Promise(async (resolve, reject) => {
        if (relayBusy) {
            return reject(new Error('Relay is busy, please wait'));
        }

        relayBusy = true;
        let connected = false;

        const timeout = setTimeout(() => {
            if (!connected) {
                device.disconnect();
                relayBusy = false;
                reject(new Error('Relay connection timeout'));
            }
        }, 10000);

        device.on('error', (err) => {
            clearTimeout(timeout);
            device.disconnect();
            relayBusy = false;
            reject(err);
        });

        device.on('data', async (data) => {
            if (connected) return;

            const currentState = data?.dps?.['1'];
            if (currentState !== undefined) {
                connected = true;
                clearTimeout(timeout);

                try {
                    if (action === 'unlock') {
                        // Turn ON (unlock)
                        await device.set({ dps: 1, set: true });
                        console.log('🔓 Door UNLOCKED');

                        // Auto-lock after duration
                        setTimeout(async () => {
                            try {
                                await device.set({ dps: 1, set: false });
                                console.log('🔒 Door LOCKED (auto)');
                                device.disconnect();
                                relayBusy = false;
                            } catch (err) {
                                console.error('❌ Auto-lock failed:', err.message);
                                device.disconnect();
                                relayBusy = false;
                            }
                        }, duration);

                        resolve({ success: true, state: 'unlocked', duration });
                    } else if (action === 'lock') {
                        // Turn OFF (lock)
                        await device.set({ dps: 1, set: false });
                        console.log('🔒 Door LOCKED');
                        device.disconnect();
                        relayBusy = false;
                        resolve({ success: true, state: 'locked' });
                    } else if (action === 'status') {
                        // Just get status
                        console.log(`📊 Relay Status: ${currentState ? 'UNLOCKED' : 'LOCKED'}`);
                        device.disconnect();
                        relayBusy = false;
                        resolve({
                            success: true,
                            state: currentState ? 'unlocked' : 'locked',
                            relay_online: true
                        });
                    }
                } catch (error) {
                    device.disconnect();
                    relayBusy = false;
                    reject(error);
                }
            }
        });

        try {
            await device.find();
            await device.connect();
        } catch (error) {
            clearTimeout(timeout);
            relayBusy = false;
            reject(error);
        }
    });
}

/**
 * POST /unlock - Unlock door for configured duration
 */
app.post('/unlock', async (req, res) => {
    const duration = req.body.duration || DOOR_UNLOCK_DURATION;

    try {
        console.log('\n🔓 Unlock request received');
        const result = await triggerRelay('unlock', duration);

        res.json({
            success: true,
            message: 'Door unlocked',
            state: result.state,
            duration: result.duration,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('❌ Unlock failed:', error.message);
        res.status(500).json({
            success: false,
            message: 'Failed to unlock door',
            error: error.message
        });
    }
});

/**
 * POST /lock - Lock door immediately
 */
app.post('/lock', async (req, res) => {
    try {
        console.log('\n🔒 Lock request received');
        const result = await triggerRelay('lock');

        res.json({
            success: true,
            message: 'Door locked',
            state: result.state,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('❌ Lock failed:', error.message);
        res.status(500).json({
            success: false,
            message: 'Failed to lock door',
            error: error.message
        });
    }
});

/**
 * GET /status - Check relay status
 */
app.get('/status', async (req, res) => {
    try {
        console.log('\n📊 Status check requested');
        const result = await triggerRelay('status');

        res.json({
            success: true,
            relay: {
                state: result.state,
                online: result.relay_online,
                ip: config.local_ip
            },
            server: {
                status: 'online',
                uptime: process.uptime(),
                port: PORT
            },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('❌ Status check failed:', error.message);
        res.status(500).json({
            success: false,
            relay: {
                online: false,
                error: error.message
            },
            server: {
                status: 'online',
                port: PORT
            }
        });
    }
});

/**
 * GET /health - Simple health check
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'online',
        service: 'paylap-relay-server',
        timestamp: new Date().toISOString()
    });
});

/**
 * GET /config - Get relay configuration
 */
app.get('/config', (req, res) => {
    console.log('\n⚙️  Config request received');

    res.json({
        success: true,
        config: {
            device_id: config.device_id,
            local_ip: config.local_ip,
            version: config.version || '3.5',
            // Don't expose the local_key for security
            local_key_configured: !!config.local_key
        },
        server: {
            port: PORT,
            unlock_duration: DOOR_UNLOCK_DURATION,
            uptime: process.uptime()
        },
        timestamp: new Date().toISOString()
    });
});

/**
 * GET / - Welcome page
 */
app.get('/', (req, res) => {
    res.json({
        service: 'PayLap Fitness - Relay Server',
        version: '1.0.0',
        endpoints: {
            'POST /unlock': 'Unlock door for duration (default 3s)',
            'POST /lock': 'Lock door immediately',
            'GET /status': 'Get relay and server status',
            'GET /config': 'Get relay configuration',
            'GET /health': 'Health check'
        },
        relay: {
            ip: config.local_ip,
            device_id: config.device_id
        }
    });
});

// Error handling
app.use((err, req, res, next) => {
    console.error('❌ Unhandled error:', err);
    res.status(500).json({
        success: false,
        error: 'Internal server error'
    });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log('\n🚀 PayLap Relay Server Started');
    console.log('================================');
    console.log(`📍 Port:         ${PORT}`);
    console.log(`🔌 Relay IP:     ${config.local_ip}`);
    console.log(`⏱️  Lock Duration: ${DOOR_UNLOCK_DURATION}ms`);
    console.log(`✅ Status:       READY`);
    console.log('\nEndpoints:');
    console.log(`  POST /unlock - Unlock door`);
    console.log(`  POST /lock   - Lock door`);
    console.log(`  GET  /status - Check status`);
    console.log(`  GET  /config - Get config`);
    console.log(`  GET  /health - Health check`);
    console.log('================================\n');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('\n⏹️  Shutting down gracefully...');
    server.close(() => {
        device.disconnect();
        console.log('✅ Server closed');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('\n⏹️  Shutting down gracefully...');
    server.close(() => {
        device.disconnect();
        console.log('✅ Server closed');
        process.exit(0);
    });
});
