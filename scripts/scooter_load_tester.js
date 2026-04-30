const admin = require("firebase-admin");
const geohash = require("ngeohash");

// Initialize with your service account or if running locally with emulator
// For this environment, we assume admin is already configured or we can use local RTDB
const serviceAccount = require("../functions/service-account.json"); // Provide path if needed

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://lemon-app-default-rtdb.firebaseio.com" // Replace with actual
});

const db = admin.database();

async function simulateScooters(count = 1000) {
    const centerLat = -36.85361;
    const centerLon = 174.766481;
    const radius = 0.5; // degrees (~50km)

    console.log(`Simulating ${count} scooters...`);

    const updates = {};
    for (let i = 0; i < count; i++) {
        const id = `sim_scooter_${i}`;
        const lat = centerLat + (Math.random() - 0.5) * radius;
        const lon = centerLon + (Math.random() - 0.5) * radius;
        const hash = geohash.encode(lat, lon, 9);

        updates[`scooters/${id}`] = {
            id: id,
            name: `Lemon #${i}`,
            latitude: lat,
            longitude: lon,
            geohash: hash,
            battery_percentage: Math.floor(Math.random() * 100),
            is_locked: true,
            is_available: true,
            status: "idle",
            last_updated: admin.database.ServerValue.TIMESTAMP
        };
    }

    await db.ref().update(updates);
    console.log("Simulation data pushed successfully!");
    process.exit(0);
}

simulateScooters(1000).catch(console.error);
