const h3 = require('h3-js');

const userLat = 6.8641; 
const userLon = 79.919; // Kumbukgaha Pokuna Road approx

const scooterLat = 6.864181024831225;
const scooterLon = 79.92114901542665;

const userH8 = h3.latLngToCell(userLat, userLon, 8);
const scooterH8 = h3.latLngToCell(scooterLat, scooterLon, 8);

console.log(`User H8: ${userH8}`);
console.log(`Scooter H8: ${scooterH8}`);

const neighbors = h3.gridDisk(userH8, 1);
console.log(`Neighbors of User cell: ${neighbors}`);
console.log(`Is scooter cell in neighbors? ${neighbors.includes(scooterH8)}`);
