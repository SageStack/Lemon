const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || "https://vheohhpaoqinyjedxemz.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Error: SUPABASE_SERVICE_ROLE_KEY is required in .env file");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const SCOOTERS_TO_SIMULATE = [
  { name: "Lemon S1 #1024", lat: 6.9270, lng: 79.8440 },
  { name: "Lemon S1 #4402", lat: 6.8960, lng: 79.8550 },
  { name: "Lemon S2 Lite #99", lat: 6.9050, lng: 79.8700 },
  { name: "Lemon S1 Pro #501", lat: 6.9150, lng: 79.8600 }
];

let activeScooters = [];

async function initializeScooters() {
  console.log("Initializing scooters in database...");
  
  for (const s of SCOOTERS_TO_SIMULATE) {
    // Check if scooter exists by name
    let { data: existing } = await supabase
      .from('scooters')
      .select('*')
      .eq('name', s.name)
      .single();
      
    if (!existing) {
      console.log(`Creating scooter: ${s.name}`);
      const { data: created, error } = await supabase
        .from('scooters')
        .insert({
          name: s.name,
          latitude: s.lat,
          longitude: s.lng,
          battery_percentage: 100,
          is_locked: true,
          is_available: true,
          status: 'idle'
        })
        .select()
        .single();
        
      if (error) console.error("Error creating scooter:", error);
      else activeScooters.push(created);
    } else {
      console.log(`Scooter exists: ${s.name} (${existing.id})`);
      activeScooters.push(existing);
    }
  }
}

function moveRandomly(lat, lng) {
  // Move by a tiny amount (~5-10 meters)
  const deltaLat = (Math.random() - 0.5) * 0.0002;
  const deltaLng = (Math.random() - 0.5) * 0.0002;
  return { lat: lat + deltaLat, lng: lng + deltaLng };
}

async function updateScooterStates() {
  for (let i = 0; i < activeScooters.length; i++) {
    const scooter = activeScooters[i];
    
    // Simulate some movement and battery drain if "unlocked"
    // For simulation purposes, let's just move them slightly even if locked to show live updates
    const newPos = moveRandomly(scooter.latitude, scooter.longitude);
    const newBattery = Math.max(0, scooter.battery_percentage - (Math.random() > 0.8 ? 1 : 0));
    
    const { data: updated, error } = await supabase
      .from('scooters')
      .update({
        latitude: newPos.lat,
        longitude: newPos.lng,
        battery_percentage: newBattery,
        last_updated: new Date().toISOString()
      })
      .eq('id', scooter.id)
      .select()
      .single();
      
    if (error) {
      console.error(`Error updating scooter ${scooter.name}:`, error.message);
    } else {
      activeScooters[i] = updated;
      console.log(`Updated ${scooter.name}: Lat ${updated.latitude.toFixed(5)}, Lng ${updated.longitude.toFixed(5)}, Battery ${updated.battery_percentage}%`);
    }
  }
}

async function start() {
  await initializeScooters();
  
  console.log("Starting simulation loop (every 3 seconds)...");
  setInterval(updateScooterStates, 3000);
}

start().catch(console.error);
