const h3 = require('h3-js');

const userLat = -36.85361;
const userLon = 174.766481; // AUT City Campus

const scooterLat = -36.85312;
const scooterLon = 174.76703;

const userH8 = h3.latLngToCell(userLat, userLon, 8);
const scooterH8 = h3.latLngToCell(scooterLat, scooterLon, 8);

console.log(`User H8: ${userH8}`);
console.log(`Scooter H8: ${scooterH8}`);

const neighbors = h3.gridDisk(userH8, 1);
console.log(`Neighbors of User cell: ${neighbors}`);
console.log(`Is scooter cell in neighbors? ${neighbors.includes(scooterH8)}`);
