
const admin = require("firebase-admin");
const h3 = require("h3-js");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://lemon-app-final-prod-1-default-rtdb.firebaseio.com" // Update this!
});

const db = admin.database();

async function migrate() {
    console.log("Starting migration...");
    const scootersRef = db.ref("scooters");
    const snapshot = await scootersRef.once("value");
    
    if (!snapshot.exists()) {
        console.log("No scooters found.");
        return;
    }
    
    const scooters = snapshot.val();
    let count = 0;
    
    for (const [id, scooter] of Object.entries(scooters)) {
        if (scooter.latitude && scooter.longitude) {
            const h3Index = h3.latLngToCell(scooter.latitude, scooter.longitude, 8);
            
            // 1. Update Scooter with h3_index
            await scootersRef.child(id).update({ h3_index: h3Index });
            
            // 2. Add to Geolocation Index
            await db.ref(`geolocations/${h3Index}/${id}`).set(true);
            
            console.log(`Updated scooter ${id} -> ${h3Index}`);
            count++;
        }
    }
    
    console.log(`Migration complete. Updated ${count} scooters.`);
    process.exit();
}

migrate();
