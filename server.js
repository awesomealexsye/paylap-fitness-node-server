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
        config: { device_id: config.device_id, local_ip: config.local_ip, version: config.version || '3.5' },
        server: { port: PORT, unlock_duration: DOOR_UNLOCK_DURATION }
    });
});

app.get('/health', (req, res) => res.json({ status: 'online', relay_connected: isConnected }));

app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n🚀 Relay Server (Persistent) Running on port ${PORT}`);
});
