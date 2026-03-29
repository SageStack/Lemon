const admin = require("firebase-admin");
const geohash = require("ngeohash");
const h3 = require("h3-js");
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
  console.warn("⚠️ Service account key not found at ./service-account-key.json");
  console.warn("⚠️ Attempting Application Default Credentials (ADC)...");
  
  try {
      admin.initializeApp({
        databaseURL: "https://lemon-app-final-prod-1-default-rtdb.asia-southeast1.firebasedatabase.app"
      });
  } catch (err) {
      console.error("\n❌ FATAL: Could not authenticate with Firebase.");
      console.error("Please ensure you have EITHER:");
      console.error("1. A 'service-account-key.json' file in this directory.");
      console.error("2. Set up ADC via 'gcloud auth application-default login'.");
      process.exit(1);
  }
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

  for (const s of SCOOTERS_TO_SIMULATE) {
      // Offset slightly to provide variety around the user
      const startLat = 6.8644 + (Math.random() - 0.5) * 0.01;
      const startLng = 79.9211 + (Math.random() - 0.5) * 0.01;
      
      console.log(`Creating scooter (Force): ${s.name}`);
      const newScooterRef = scootersRef.push();
      const h3Idx = h3.latLngToCell(startLat, startLng, 8);
      
      const shardData = { id: newScooterRef.key, lat: startLat, lng: startLng, bat: 100, s: 'av' };

      const newScooter = {
        id: newScooterRef.key,
        name: s.name,
        latitude: startLat,
        longitude: startLng,
        battery_percentage: 100,
        is_locked: true,
        is_available: true,
        geohash: geohash.encode(startLat, startLng, 9),
        h3_index: h3Idx,
        last_updated: admin.database.ServerValue.TIMESTAMP
      };
      
      await newScooterRef.set(newScooter);
      await db.ref(`geolocations/${h3Idx}/${newScooter.id}`).set(true);
      await db.ref(`geo_shards/${h3Idx}/${newScooter.id}`).set(shardData);
      
      // Initialize Aggregates
      const aggMid = h3.cellToParent(h3Idx, 6);
      const aggLow = h3.cellToParent(h3Idx, 4);
       
      await db.ref(`geo_aggregates/6/${aggMid}/count`).transaction(c => (c || 0) + 1);
      await db.ref(`geo_aggregates/6/${aggMid}/lat`).set(startLat);
      await db.ref(`geo_aggregates/6/${aggMid}/lng`).set(startLng);
      await db.ref(`geo_aggregates/4/${aggLow}/count`).transaction(c => (c || 0) + 1);
      
      activeScooterIds.push(newScooterRef.key);
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
      geohash: geohash.encode(newPos.lat, newPos.lng, 9),
      h3_index: h3.latLngToCell(newPos.lat, newPos.lng, 8),
      last_updated: admin.database.ServerValue.TIMESTAMP
    });
    
    // Update H3 index
    const newH3 = h3.latLngToCell(newPos.lat, newPos.lng, 8);
    
    // --- GEO-SHARDING ---
    // Compact data for clients
    const shardData = {
        id: id,
        lat: newPos.lat,
        lng: newPos.lng,
        bat: newBattery,
        s: (scooter.is_available && scooter.is_locked) ? 'av' : 'in' // simplified status
    };

    if (scooter.h3_index && scooter.h3_index !== newH3) {
      await db.ref(`geolocations/${scooter.h3_index}/${id}`).remove();
      await db.ref(`geo_shards/${scooter.h3_index}/${id}`).remove();
      
      // Remove from old aggregates
      const oldAggMid = h3.cellToParent(scooter.h3_index, 6);
      const oldAggLow = h3.cellToParent(scooter.h3_index, 4);
      await db.ref(`geo_aggregates/6/${oldAggMid}/count`).transaction(c => (c || 0) - 1);
      await db.ref(`geo_aggregates/4/${oldAggLow}/count`).transaction(c => (c || 0) - 1);
    }
    
    // Add to new Aggregates if changed or new
    if (!scooter.h3_index || scooter.h3_index !== newH3) {
        const newAggMid = h3.cellToParent(newH3, 6);
        const newAggLow = h3.cellToParent(newH3, 4);
        
        await db.ref(`geo_aggregates/6/${newAggMid}/count`).transaction(c => (c || 0) + 1);
        await db.ref(`geo_aggregates/6/${newAggMid}/lat`).set(newPos.lat);
        await db.ref(`geo_aggregates/6/${newAggMid}/lng`).set(newPos.lng);
        
        await db.ref(`geo_aggregates/4/${newAggLow}/count`).transaction(c => (c || 0) + 1);
    }

    await db.ref(`geolocations/${newH3}/${id}`).set(true);
    await db.ref(`geo_shards/${newH3}/${id}`).set(shardData);
    
    console.log(`Updated ${scooter.name}: Lat ${newPos.lat.toFixed(5)}, Lng ${newPos.lng.toFixed(5)}, Battery ${newBattery}%`);
  }
}

async function start() {
  await initializeScooters();
  console.log("Starting simulation loop (every 3 seconds)...");
  setInterval(updateScooterStates, 3000);
}

start().catch(console.error);
