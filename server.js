/**
 * PayLap Fitness - Node.js Relay Server
 * =====================================
 * HTTP API for controlling magnetic door locks via YODE WiFi Relay
 */

const express = require('express');
const TuyAPI = require('tuyapi');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

// Configuration
const PORT = process.env.PORT || 3000;
const DOOR_UNLOCK_DURATION = parseInt(process.env.DOOR_UNLOCK_DURATION) || 3000;
const CONFIG_FILE = process.env.CONFIG_FILE || 'config.json';

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true }));

// Load Configuration
let config = {};
try {
    const configPath = path.join(__dirname, CONFIG_FILE);
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    console.log('✅ Configuration loaded successfully');
} catch (error) {
    console.error('❌ Error: config.json not found!');
    process.exit(1);
}

// Initialize Tuya Device
const device = new TuyAPI({
    id: config.device_id,
    key: config.local_key,
    ip: config.local_ip,
    version: config.version || '3.5',
    issueRefreshOnConnect: true
});

let isConnected = false;
let relayBusy = false;
let autoLockTimer = null;

/**
 * Maintain Persistent Connection
 */
async function connectToRelay() {
    try {
        console.log('📡 Attempting to connect to relay...');
        await device.find();
        await device.connect();
    } catch (err) {
        console.error('❌ Connection failed:', err.message);
        setTimeout(connectToRelay, 5000); // Retry after 5s
    }
}

device.on('connected', () => {
    console.log('✅ Connected to relay');
    isConnected = true;
});

device.on('disconnected', () => {
    console.warn('⚠️  Disconnected from relay');
    isConnected = false;
    setTimeout(connectToRelay, 5000); // Reconnect
});

device.on('error', (err) => {
    console.error('❌ Relay error:', err.message);
    if (!isConnected) {
        setTimeout(connectToRelay, 5000);
    }
});

// Initial connection
connectToRelay();

/**
 * Optimized Trigger Relay using persistent connection
 */
async function triggerRelay(action) {
    if (!isConnected) {
        throw new Error('Relay is offline. Please wait for reconnection.');
    }

    if (relayBusy) {
        throw new Error('Relay is busy processing another request.');
    }

    try {
        if (action === 'unlock') {
            relayBusy = true;

            // Clear existing auto-lock timer if any
            if (autoLockTimer) clearTimeout(autoLockTimer);

            await device.set({ dps: 1, set: true });
            console.log('🔓 Door UNLOCKED');

            // Set auto-lock timer
            autoLockTimer = setTimeout(async () => {
                try {
                    await device.set({ dps: 1, set: false });
                    console.log('🔒 Door LOCKED (auto)');
                } catch (err) {
                    console.error('❌ Auto-lock failed:', err.message);
                } finally {
                    relayBusy = false;
                    autoLockTimer = null;
                }
            }, DOOR_UNLOCK_DURATION);

            return { success: true, state: 'unlocked', duration: DOOR_UNLOCK_DURATION };

        } else if (action === 'lock') {
            if (autoLockTimer) clearTimeout(autoLockTimer);

            await device.set({ dps: 1, set: false });
            console.log('🔒 Door LOCKED (manual)');

            relayBusy = false;
            autoLockTimer = null;
            return { success: true, state: 'locked' };

        } else if (action === 'status') {
            const status = await device.get();
            const state = status?.dps?.['1'];
            return {
                success: true,
                state: state ? 'unlocked' : 'locked',
                online: isConnected
            };
        }
    } catch (error) {
        relayBusy = false;
        throw error;
    }
}

// Endpoints
app.post('/unlock', async (req, res) => {
    try {
        console.log('\n🔓 Unlock request received');
        const result = await triggerRelay('unlock');
        res.json({ success: true, ...result, timestamp: new Date().toISOString() });
    } catch (error) {
        console.error('❌ Unlock failed:', error.message);
        res.status(503).json({ success: false, error: error.message });
    }
});

app.post('/lock', async (req, res) => {
    try {
        console.log('\n🔒 Lock request received');
        const result = await triggerRelay('lock');
        res.json({ success: true, ...result, timestamp: new Date().toISOString() });
    } catch (error) {
        console.error('❌ Lock failed:', error.message);
        res.status(503).json({ success: false, error: error.message });
    }
});

app.get('/status', async (req, res) => {
    try {
        const result = await triggerRelay('status');
        res.json({
            success: true,
            relay: { state: result.state, online: result.online, ip: config.local_ip },
            server: { status: 'online', uptime: process.uptime() },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.json({
            success: false,
            relay: { online: isConnected, error: error.message },
            server: { status: 'online' }
        });
    }
});

app.get('/config', (req, res) => {
    res.json({
        success: true,
        config: {
            device_id: config.device_id,
            local_key: config.local_key,  // Added local_key
            local_ip: config.local_ip,
            version: config.version || '3.5'
        },
        server: { port: PORT, unlock_duration: DOOR_UNLOCK_DURATION }
    });
});

// Update Config Endpoint
app.put('/config', async (req, res) => {
    try {
        const { device_id, local_key, local_ip } = req.body;

        // Validation
        const errors = [];

        if (device_id !== undefined) {
            if (typeof device_id !== 'string' || device_id.trim().length === 0) {
                errors.push('device_id must be a non-empty string');
            }
        }

        if (local_key !== undefined) {
            if (typeof local_key !== 'string' || local_key.trim().length === 0) {
                errors.push('local_key must be a non-empty string');
            }
        }

        if (local_ip !== undefined) {
            // Validate IP address format
            const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
            if (typeof local_ip !== 'string' || !ipRegex.test(local_ip)) {
                errors.push('local_ip must be a valid IP address (e.g., 192.168.0.127)');
            } else {
                // Check each octet is 0-255
                const octets = local_ip.split('.');
                const invalidOctet = octets.some(octet => parseInt(octet) > 255);
                if (invalidOctet) {
                    errors.push('local_ip octets must be between 0 and 255');
                }
            }
        }

        if (errors.length > 0) {
            return res.status(400).json({
                success: false,
                error: 'Validation failed',
                errors: errors
            });
        }

        // Check if at least one field is being updated
        if (!device_id && !local_key && !local_ip) {
            return res.status(400).json({
                success: false,
                error: 'At least one field (device_id, local_key, or local_ip) must be provided'
            });
        }

        // Update config object
        const oldConfig = { ...config };
        if (device_id) config.device_id = device_id.trim();
        if (local_key) config.local_key = local_key.trim();
        if (local_ip) config.local_ip = local_ip.trim();

        // Save to config.json file
        const configPath = path.join(__dirname, CONFIG_FILE);
        fs.writeFileSync(configPath, JSON.stringify(config, null, 4), 'utf8');

        console.log('✅ Configuration updated successfully');
        console.log('Updated fields:', { device_id, local_key, local_ip });

        // Check if device settings changed - if so, reconnect
        const deviceChanged = device_id || local_key || local_ip;
        if (deviceChanged) {
            console.log('⚠️  Device settings changed - reconnecting to relay...');

            // Disconnect current device
            try {
                await device.disconnect();
            } catch (err) {
                console.log('Note: Error disconnecting old device (expected if already disconnected)');
            }

            // Reinitialize device with new config
            device.device = {
                id: config.device_id,
                key: config.local_key,
                ip: config.local_ip,
                version: config.version || '3.5'
            };

            // Reconnect
            setTimeout(() => connectToRelay(), 1000);
        }

        res.json({
            success: true,
            message: 'Configuration updated successfully',
            config: {
                device_id: config.device_id,
                local_key: '***' + config.local_key.slice(-4), // Mask key for security
                local_ip: config.local_ip,
                version: config.version
            },
            reconnecting: deviceChanged
        });

    } catch (error) {
        console.error('❌ Error updating config:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to update configuration: ' + error.message
        });
    }
});

app.get('/health', (req, res) => res.json({ status: 'online', relay_connected: isConnected }));

app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n🚀 Relay Server (Persistent) Running on port ${PORT}`);
});
