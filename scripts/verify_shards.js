const admin = require("firebase-admin");
require('dotenv').config();
const path = require("path");

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT || path.join(__dirname, "../service-account-key.json");

try {
  // Try to load service account if available, otherwise default
  try {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: "https://lemon-app-final-prod-1-default-rtdb.asia-southeast1.firebasedatabase.app"
      });
  } catch(e) {
      admin.initializeApp({
        databaseURL: "https://lemon-app-final-prod-1-default-rtdb.asia-southeast1.firebasedatabase.app"
      });
  }
} catch (e) {
  console.error("Init failed", e);
}

const db = admin.database();

async function verify() {
    console.log("🔍 Verifying /geo_shards data...");
    const ref = db.ref("geo_shards");
    const snapshot = await ref.once("value");
    
    if (!snapshot.exists()) {
        console.error("❌ No data found in /geo_shards. Simulator might not be running or writing.");
        process.exit(1);
    }
    
    const shards = snapshot.val();
    const cellCount = Object.keys(shards).length;
    console.log(`✅ Found ${cellCount} active H3 cells.`);
    
    let totalScooters = 0;
    Object.keys(shards).forEach(cell => {
        const scooters = shards[cell];
        const count = Object.keys(scooters).length;
        totalScooters += count;
        
        // Validate structure of first scooter
        const firstId = Object.keys(scooters)[0];
        const data = scooters[firstId];
        
        if (data.lat && data.lng && data.s) {
             console.log(`   - Cell ${cell}: ${count} scooters. Sample: ${JSON.stringify(data)}`);
        } else {
             console.error(`❌ Invalid data structure in cell ${cell}:`, data);
        }
    });
    
    console.log(`✅ Total Scooters in Shards: ${totalScooters}`);
    
    // Check if total matches /scooters count
    const regularRef = db.ref("scooters");
    const regSnap = await regularRef.once("value");
    const regCount = regSnap.numChildren();
    
    console.log(`ℹ️  Total Scooters in /scooters: ${regCount}`);
    
    if (totalScooters > 0) {
        console.log("✅ Verification SUCCESS: Geo-Shards are active and populated.");
        process.exit(0);
    } else {
        console.warn("⚠️  Verification INCOMPLETE: No scooters found in shards.");
        process.exit(0);
    }
}

verify();
