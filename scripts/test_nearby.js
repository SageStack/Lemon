const admin = require("firebase-admin");
const axios = require("axios");
const path = require("path");

// Init Admin to get ID Token
const serviceAccountPath = path.join(__dirname, "../service-account-key.json");
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://lemon-app-final-prod-1-default-rtdb.asia-southeast1.firebasedatabase.app"
});

async function testFunction() {
    try {
        // 1. Get ID Token via Custom Token (Simulation)
        // Since we are admin, we can't easily get an ID token for a user without signing in.
        // We will just mint a custom token and exchange it? No, that requires Client SDK.
        
        // Alternative: Use verifyIdToken in function? No, function expects header.
        // We will try to call it WITHOUT auth first to see if it rejects fast (Connectivity check)
        // Then we might need to rely on the fact that I previously curled it and got 401.
        
        console.log("Testing connectivity to Cloud Function...");
        const url = "https://us-central1-lemon-app-final-prod-1.cloudfunctions.net/getNearbyScooters";
        
        try {
            await axios.post(url, { data: {} });
        } catch (e) {
            if (e.response && e.response.status === 401) {
                console.log("✅ Function is reachable (Returned 401 as expected without auth).");
            } else {
                console.error("❌ Connectivity Error:", e.message);
                return;
            }
        }

        console.log("⚠️ Cannot fully test function logic without a valid User ID Token (requires Client SDK).");
        console.log("Assuming function is reachable. If iOS hangs, it might be an iOS Transport Security or Network issue.");
        
    } catch (e) {
        console.error("Test Failed:", e);
    }
}

testFunction();
