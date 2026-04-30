
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const geohash = require("ngeohash");
const h3 = require("h3-js");

admin.initializeApp({
    databaseURL: "https://lemon-app-final-prod-1-default-rtdb.asia-southeast1.firebasedatabase.app"
});
const db = admin.database();

// Cost Configuration
const BASE_UNLOCK_FEE = 100.0; // Rs. 100
const RATE_PER_MINUTE = 20.0;  // Rs. 20

// Validation Helper
function getDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Radius of the earth in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = 
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const d = R * c; // Distance in km
    return d;
}

function validateScooterId(scooterId) {
    if (!scooterId || typeof scooterId !== 'string') {
        throw new functions.https.HttpsError("invalid-argument", "Scooter ID is required");
    }
    // Allow alphanumeric, dashes, underscores. No slashes or dots to prevent path traversal.
    if (!/^[a-zA-Z0-9_\-]+$/.test(scooterId)) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid Scooter ID format");
    }
}

/**
 * START: Geospatial Helper
 * Centralizes logic for updating Shards (Res 8) and Aggergates (Res 6/4).
 * Handles atomic increments/decrements.
 */
async function updateGeospatialIndex(scooterId, newLat, newLon, oldLat, oldLon, scooterData) {
    const updates = {};
    const RES_SHARD = 8;
    const RES_AGG_MID = 6;
    const RES_AGG_LOW = 4;

    const newH3 = h3.latLngToCell(newLat, newLon, RES_SHARD);
    const oldH3 = (oldLat && oldLon) ? h3.latLngToCell(oldLat, oldLon, RES_SHARD) : null;

    // 1. Update Res 8 Shard (Detailed Data)
    const shardData = {
        id: scooterId,
        lat: newLat,
        lng: newLon,
        bat: scooterData.battery_percentage || 0,
        s: (!scooterData.is_available) ? 'mn' : (!scooterData.is_locked ? 'in' : 'av')
    };

    // If cell changed, remove from old shard
    if (oldH3 && oldH3 !== newH3) {
        updates[`geo_shards/${oldH3}/${scooterId}`] = null;
    }
    updates[`geo_shards/${newH3}/${scooterId}`] = shardData;

    // 2. Update Aggregates (Res 6)
    const newAggMid = h3.cellToParent(newH3, RES_AGG_MID);
    const oldAggMid = oldH3 ? h3.cellToParent(oldH3, RES_AGG_MID) : null;

    if (newAggMid !== oldAggMid) {
        // Increment New
        updates[`geo_aggregates/${RES_AGG_MID}/${newAggMid}/count`] = admin.database.ServerValue.increment(1);
        updates[`geo_aggregates/${RES_AGG_MID}/${newAggMid}/lat`] = newLat; // Approximate center
        updates[`geo_aggregates/${RES_AGG_MID}/${newAggMid}/lng`] = newLon;
        
        // Decrement Old
        if (oldAggMid) {
            updates[`geo_aggregates/${RES_AGG_MID}/${oldAggMid}/count`] = admin.database.ServerValue.increment(-1);
        }
    } else {
        // Just update location reference for the aggregate center (optional, keeps heatmap fresh)
         updates[`geo_aggregates/${RES_AGG_MID}/${newAggMid}/lat`] = newLat;
         updates[`geo_aggregates/${RES_AGG_MID}/${newAggMid}/lng`] = newLon;
    }

    // 3. Update Aggregates (Res 4) - For city-level view
    const newAggLow = h3.cellToParent(newH3, RES_AGG_LOW);
    const oldAggLow = oldH3 ? h3.cellToParent(oldH3, RES_AGG_LOW) : null;

    if (newAggLow !== oldAggLow) {
        updates[`geo_aggregates/${RES_AGG_LOW}/${newAggLow}/count`] = admin.database.ServerValue.increment(1);
        if (oldAggLow) {
            updates[`geo_aggregates/${RES_AGG_LOW}/${oldAggLow}/count`] = admin.database.ServerValue.increment(-1);
        }
    }

    // 4. Update core scooter record reference
    updates[`scooters/${scooterId}/h3_index`] = newH3;
    updates[`scooters/${scooterId}/latitude`] = newLat;
    updates[`scooters/${scooterId}/longitude`] = newLon;
    
    // Execute atomic multi-path update
    await db.ref().update(updates);
    
    return newH3;
}
/** END: Geospatial Helper */


/**
 * Gets nearby scooters using H3 spatial indexing.
 * This is efficient and cheaper than querying all scooters.
 */
exports.getNearbyScooters = functions.https.onCall(async (data, context) => {
    // console.log(`[getNearbyScooters] Request from UID: ${context.auth ? context.auth.uid : 'UNAUTHENTICATED'}`);
    
    if (!context.auth) {
         throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    }

    const { latitude, longitude, radiusKm } = data;
    
    if (!latitude || !longitude) {
        throw new functions.https.HttpsError("invalid-argument", "Latitude and Longitude required");
    }
    
    const targetResolution = data.resolution || 8;
    
    // Normalize: We ALWAYS query Resolution 8 shards for individual scooters.
    const indexingResolution = 8;
    const searchCenterH3 = h3.latLngToCell(latitude, longitude, indexingResolution);
    
    // 2. Get neighboring cells (gridDisk). 
    let k = 2;
    if (targetResolution > indexingResolution) k = 1;
    if (targetResolution < indexingResolution) k = 3; // Reduced from 4 to 3 for perf
    
    const neighborCells = h3.gridDisk(searchCenterH3, k);
    
    // console.log(`[getNearbyScooters] Querying ${neighborCells.length} shards (k=${k}) at Resolution ${indexingResolution}`);
    
    return { 
        cellIds: neighborCells // Return list of cells for client subscription
    };
});

/**
 * NEW: Fetches aggregated scooter counts for zoomed-out views.
 * Uses Res 6 or Res 4 based on requests.
 */
exports.getMapOverview = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    
    const { latitude, longitude, zoomLevel } = data;
    
    // Determine Aggregation Level
    // Zoom < 10 -> Res 4
    // Zoom 10-14 -> Res 6
    let res = 6;
    if (zoomLevel < 10) res = 4;
    
    const centerCell = h3.latLngToCell(latitude, longitude, res);
    
    // Get a wide area (k=3 at Res 6 covers a huge area, ~50km radius)
    // Res 6 edge is ~2km. k=3 is ~6km radius.
    // We might need k=6-10 for full city view at Res 6.
    const k = res === 6 ? 6 : 4; 
    
    const neighborCells = h3.gridDisk(centerCell, k);
    
    // Fetch all aggregates
    const promises = neighborCells.map(cell => 
        db.ref(`geo_aggregates/${res}/${cell}`).once('value')
    );
    
    const snapshots = await Promise.all(promises);
    const aggregates = [];
    
    snapshots.forEach((snap, index) => {
        if (snap.exists()) {
            const val = snap.val();
            if (val.count > 0) {
                aggregates.push({
                    h3: neighborCells[index],
                    count: val.count,
                    lat: val.lat || 0, // Approximate center of activity
                    lng: val.lng || 0
                });
            }
        }
    });
    
    return { aggregates };
});

/**
 * Unlocks a scooter.
 * Checks availability and authorization securely using transactions.
 */
exports.unlockScooter = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Auth required.");
  }
  
  if (context.app == undefined) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required.');
  }

  const userId = context.auth.uid;
  const scooterId = data.scooterId;
  validateScooterId(scooterId);

  const scooterRef = db.ref(`scooters/${scooterId}`);
  const snap = await scooterRef.once('value');
  const s = snap.val();

  if (!s) {
      throw new functions.https.HttpsError("not-found", "Scooter not found.");
  }

  if (s.is_locked === false || s.is_available === false) {
      throw new functions.https.HttpsError("failed-precondition", "Scooter is already unlocked or unavailable.");
  }

  const secureRef = db.ref(`scooter_secure_data/${scooterId}`);
  
  // Use transaction to atomically check and reserve
  let abortReason = null;
  const result = await secureRef.transaction((secureData) => {
      if (!secureData) secureData = {};
      
      if (secureData.reserved_by && secureData.reserved_by !== userId) {
          abortReason = "RESERVED";
          return;
      }
      
      if (secureData.current_ride_client_id && secureData.current_ride_client_id !== userId) {
          abortReason = "IN_USE";
          return;
      }
      
      secureData.current_ride_client_id = userId;
      secureData.current_ride_start = Date.now();
      secureData.start_lat = data.latitude;
      secureData.start_lon = data.longitude;
      secureData.reserved_by = null;
      return secureData;
  });

  if (!result.committed) {
      throw new functions.https.HttpsError("failed-precondition", abortReason || "Unlock failed");
  }

  // Update public state
  // We don't change location here, just status. 
  // Status change affects Shard "s" field, so we should update shard.
  // We can do a lightweight shard update.
  await scooterRef.update({
      is_locked: false,
      is_available: false,
      current_ride_client_id: userId,
      status: 'in',
      last_updated: admin.database.ServerValue.TIMESTAMP
  });
  
  // Update Shard Status
  if (s && s.h3_index) {
      await db.ref(`geo_shards/${s.h3_index}/${scooterId}/s`).set('in');
  } else {
      console.warn(`[Unlock] Scooter ${scooterId} missing H3 index, skipping shard update.`);
  }

  return { success: true };
});

exports.reserveScooter = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
    if (context.app == undefined) throw new functions.https.HttpsError('failed-precondition', 'App Check required.');

    const userId = context.auth.uid;
    const scooterId = data.scooterId;
    validateScooterId(scooterId);
    
    const secureRef = db.ref(`scooter_secure_data/${scooterId}`);
    
    const result = await secureRef.transaction((secureData) => {
        if (!secureData) secureData = {};
        if (secureData.current_ride_client_id) return; 
        if (secureData.reserved_by && secureData.reserved_by !== userId) return;
        
        secureData.reserved_by = userId;
        secureData.reserved_at = admin.database.ServerValue.TIMESTAMP;
        return secureData;
    });

    if (!result.committed) throw new functions.https.HttpsError("failed-precondition", "Scooter unavailable");
        
    await db.ref(`scooters/${scooterId}`).update({
        is_available: false,
        last_updated: admin.database.ServerValue.TIMESTAMP
    });
    
    // Update Shard Status to 'rs' (Reserved) - treated as 'mn' (Maintenance/Unavailable) for public map
    // or we can add 'rs' support to client.
    // For now, let's look up H3 to update shard.
    const sSnap = await db.ref(`scooters/${scooterId}/h3_index`).once('value');
    const h3Idx = sSnap.val();
    if (h3Idx) {
        await db.ref(`geo_shards/${h3Idx}/${scooterId}/s`).set('rs');
    }
    
    return { success: true };
});

exports.cancelReservation = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
    const { scooterId } = data;
    const userId = context.auth.uid;
    validateScooterId(scooterId);

    const secureRef = db.ref(`scooter_secure_data/${scooterId}`);
    
    await secureRef.transaction((secureData) => {
        if (!secureData) return null;
        if (secureData.reserved_by === userId) {
            secureData.reserved_by = null;
            secureData.reserved_at = null;
        }
        return secureData;
    });
    
    await db.ref(`scooters/${scooterId}`).update({
        is_available: true,
        last_updated: admin.database.ServerValue.TIMESTAMP
    });
    
    const sSnap = await db.ref(`scooters/${scooterId}/h3_index`).once('value');
    const h3Idx = sSnap.val();
    if (h3Idx) {
        await db.ref(`geo_shards/${h3Idx}/${scooterId}/s`).set('av');
    }
    
    return { success: true };
});


/**
 * Ends a ride for multiple scooters.
 */
exports.endRide = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  if (context.app == undefined) throw new functions.https.HttpsError('failed-precondition', 'App Check required.');

  const scooterIds = data.scooterIds || [];
  const distanceData = data.distances || {}; 
  const totalDistanceInput = data.totalDistance || 0;
  
  const userId = context.auth.uid;

  if (scooterIds.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "No scooter IDs provided");
  }

  let totalCost = 0;
  let totalDuration = 0;
  let totalDistanceCalc = 0;
  const now = Date.now();

  for (const id of scooterIds) {
    validateScooterId(id);

    const secureRef = db.ref(`scooter_secure_data/${id}`);
    const publicRef = db.ref(`scooters/${id}`);
    
    const publicSnap = await publicRef.once('value');
    const publicData = publicSnap.val();
    
    const endLat = data.latitude;
    const endLon = data.longitude;
    
    if (typeof endLat !== 'number' || typeof endLon !== 'number' || endLat === 0 || endLon === 0) {
        throw new functions.https.HttpsError("invalid-argument", "Valid end location required.");
    }

    if (publicData && publicData.latitude && publicData.longitude) {
        const drift = getDistance(publicData.latitude, publicData.longitude, endLat, endLon);
        if (drift > 0.5) { 
             console.error(`SECURITY: Location Spoofing ${id}. Drift: ${drift}km`);
             throw new functions.https.HttpsError("failed-precondition", "Location too far from scooter.");
        }
    }

    const result = await secureRef.transaction((secureData) => {
        if (!secureData) return secureData; 
        if (secureData.current_ride_client_id !== userId) return; 

        secureData.prev_ride_start = secureData.current_ride_start;
        secureData.current_ride_client_id = null;
        secureData.current_ride_start = null;
        secureData.reserved_by = null;
        return secureData;
    });

    if (!result.committed) continue; 

    const secureData = result.snapshot.val();
    const startTime = secureData.prev_ride_start || now; 
    const durationSeconds = Math.max(0, (now - startTime) / 1000);
    const durationMinutes = Math.ceil(durationSeconds / 60);

    const cost = BASE_UNLOCK_FEE + (durationMinutes * RATE_PER_MINUTE);
    totalCost += cost;
    totalDuration += durationSeconds;
    
    // Update Geolocation & Aggregates
    await updateGeospatialIndex(id, endLat, endLon, publicData.latitude, publicData.longitude, { 
        is_locked: true, 
        is_available: true,
        battery_percentage: publicData.battery_percentage 
    });
    
    // Explicitly set public state properties that updateGeospatialIndex doesn't handle fully
    await publicRef.update({
      is_locked: true,
      last_updated: admin.database.ServerValue.TIMESTAMP
    });
  }

  if (totalDuration === 0 && totalCost === 0 && scooterIds.length > 0) {
      throw new functions.https.HttpsError("failed-precondition", "Ride end failed.");
  }

  const rideId = db.ref("ride_history").push().key;
  const rideRecord = {
    id: rideId,
    userId: userId,
    date: admin.database.ServerValue.TIMESTAMP,
    distanceKm: parseFloat(totalDistanceCalc.toFixed(2)), 
    cost: totalCost,
    durationSeconds: totalDuration,
    scooterCount: scooterIds.length
  };

  await db.ref(`ride_history/${userId}/${rideId}`).set(rideRecord);

  return {
    success: true,
    message: "Ride ended successfully",
    summary: rideRecord
  };
});

/**
 * Updates scooter location and automatically calculates geohash AND H3 index.
 */
exports.updateScooterLocation = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required.");

    const { scooterId, latitude, longitude, battery } = data;
    validateScooterId(scooterId);

    const isOwner = context.auth.uid === scooterId;
    const isScooterRole = context.auth.token.role === 'scooter';
    const isAdmin = context.auth.token.role === 'admin';

    if (!isOwner && !isScooterRole && !isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Unauthorized.");
    }

    // Get previous state for speed check & differential H3 update
    const scooterRef = db.ref(`scooters/${scooterId}`);
    const snap = await scooterRef.once('value');
    const prev = snap.val();

    if (prev && prev.latitude && prev.longitude && prev.last_updated) {
        const dist = getDistance(prev.latitude, prev.longitude, latitude, longitude);
        const timeDiffHours = (Date.now() - prev.last_updated) / (1000 * 60 * 60);
        
        if (timeDiffHours > 0) {
            const speed = dist / timeDiffHours;
            if (speed > 40) { 
                 throw new functions.https.HttpsError("failed-precondition", "Invalid movement speed.");
            }
        }
    }

    // Update geospatial indices (Shards + Aggregates)
    const newH3 = await updateGeospatialIndex(
        scooterId, 
        latitude, 
        longitude, 
        prev ? prev.latitude : null, 
        prev ? prev.longitude : null, 
        { ...prev, battery_percentage: battery ?? prev?.battery_percentage }
    );
    
    // Update battery if provided
    if (battery !== undefined) {
        await scooterRef.update({ battery_percentage: battery });
    }

    return { success: true, h3Index: newH3 };
});

exports.toggleAlarm = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
    if (context.app == undefined) throw new functions.https.HttpsError('failed-precondition', 'App Check required.');

    const { scooterId, active } = data;
    const userId = context.auth.uid;
    validateScooterId(scooterId);

    const secureRef = db.ref(`scooter_secure_data/${scooterId}`);
    const secureSnap = await secureRef.once('value');
    const secureData = secureSnap.val();

    if (!secureData || (secureData.current_ride_client_id !== userId && secureData.reserved_by !== userId)) {
        throw new functions.https.HttpsError("permission-denied", "Unauthorized");
    }

    await db.ref(`scooters/${scooterId}`).update({
        alarm_active: active,
        last_updated: admin.database.ServerValue.TIMESTAMP
    });

    return { success: true };
});

exports.requestScooterRole = functions.https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
    const uid = context.auth.uid;
    await admin.auth().setCustomUserClaims(uid, { role: "scooter" });
    return { success: true, message: "Role assigned." };
});
