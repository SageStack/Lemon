const admin = require("firebase-admin");
require('dotenv').config();

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT || "./service-account-key.json";

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://lemon-app-final-prod-1-default-rtdb.asia-southeast1.firebasedatabase.app"
  });
} catch (e) {
  console.error("Failed to load service account. Ensure service-account-key.json exists.");
  process.exit(1);
}

const db = admin.database();

async function purgeAllRides() {
  console.log("🧹 Purging all active ride data...");
  
  try {
    // 1. Clear secure data
    await db.ref("scooter_secure_data").remove();
    console.log("✅ Cleared scooter_secure_data");
    
    // 2. Clear current ride from public scooters
    const scootersSnap = await db.ref("scooters").once("value");
    const scooters = scootersSnap.val();
    
    if (scooters) {
      const updates = {};
      Object.keys(scooters).forEach(id => {
        updates[`scooters/${id}/current_ride_client_id`] = null;
        updates[`scooters/${id}/is_available`] = true;
        updates[`scooters/${id}/is_locked`] = true;
      });
      await db.ref().update(updates);
      console.log(`✅ Reset state for ${Object.keys(scooters).length} scooters`);
    }

    console.log("✨ All rides purged successfully!");
    process.exit(0);
  } catch (err) {
    console.error("❌ Purge failed:", err);
    process.exit(1);
  }
}

purgeAllRides();
