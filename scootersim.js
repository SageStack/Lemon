const admin = require("firebase-admin");
require('dotenv').config();

// Note: To use this in production, you should provide a service-account-key.json
// or use environment variables. For this simulation, we'll try to use
// Application Default Credentials or look for a local key.
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT || "./service-account-key.json";

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://lemon-app-final-prod-1-default-rtdb.firebasedatabase.app"
  });
} catch (e) {
  console.warn("Service account not found, trying default initialization...");
  admin.initializeApp({
    databaseURL: "https://lemon-app-final-prod-1-default-rtdb.firebasedatabase.app"
  });
}

const db = admin.database();

const SCOOTERS_TO_SIMULATE = [
  { name: "Lemon S1 #1024", lat: 6.9270, lng: 79.8440 },
  { name: "Lemon S1 #4402", lat: 6.8960, lng: 79.8550 },
  { name: "Lemon S2 Lite #99", lat: 6.9050, lng: 79.8700 },
  { name: "Lemon S1 Pro #501", lat: 6.9150, lng: 79.8600 }
];

let activeScooterIds = [];

async function initializeScooters() {
  console.log("Initializing scooters in Firebase Realtime Database...");
  
  const scootersRef = db.ref("scooters");
  const snapshot = await scootersRef.once("value");
  const existingScooters = snapshot.val() || {};
  
  const existingNames = Object.values(existingScooters).map(s => s.name);

  for (const s of SCOOTERS_TO_SIMULATE) {
    if (!existingNames.includes(s.name)) {
      console.log(`Creating scooter: ${s.name}`);
      const newScooterRef = scootersRef.push();
      const newScooter = {
        id: newScooterRef.key,
        name: s.name,
        latitude: s.lat,
        longitude: s.lng,
        battery_percentage: 100,
        is_locked: true,
        is_available: true,
        status: 'idle',
        last_updated: admin.database.ServerValue.TIMESTAMP
      };
      await newScooterRef.set(newScooter);
      activeScooterIds.push(newScooterRef.key);
    } else {
      // Find the ID of the existing one
      const id = Object.keys(existingScooters).find(key => existingScooters[key].name === s.name);
      console.log(`Scooter exists: ${s.name} (${id})`);
      activeScooterIds.push(id);
    }
  }
}

function moveRandomly(lat, lng) {
  const deltaLat = (Math.random() - 0.5) * 0.0002;
  const deltaLng = (Math.random() - 0.5) * 0.0002;
  return { lat: lat + deltaLat, lng: lng + deltaLng };
}

async function updateScooterStates() {
  for (const id of activeScooterIds) {
    const scooterRef = db.ref(`scooters/${id}`);
    const snapshot = await scooterRef.once("value");
    const scooter = snapshot.val();

    if (!scooter) continue;
    
    const newPos = moveRandomly(scooter.latitude, scooter.longitude);
    const newBattery = Math.max(0, scooter.battery_percentage - (Math.random() > 0.8 ? 1 : 0));
    
    await scooterRef.update({
      latitude: newPos.lat,
      longitude: newPos.lng,
      battery_percentage: newBattery,
      last_updated: admin.database.ServerValue.TIMESTAMP
    });
    
    console.log(`Updated ${scooter.name}: Lat ${newPos.lat.toFixed(5)}, Lng ${newPos.lng.toFixed(5)}, Battery ${newBattery}%`);
  }
}

async function start() {
  await initializeScooters();
  console.log("Starting simulation loop (every 3 seconds)...");
  setInterval(updateScooterStates, 3000);
}

start().catch(console.error);
