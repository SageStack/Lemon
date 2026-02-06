const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json"); // User must provide this

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const uid = process.argv[2];

if (!uid) {
  console.log("Usage: node setup_scooter_role.js <UID>");
  process.exit(1);
}

admin.auth().setCustomUserClaims(uid, { role: "scooter" })
  .then(() => {
    console.log(`Successfully assigned 'scooter' role to user: ${uid}`);
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error assigned role:", error);
    process.exit(1);
  });
