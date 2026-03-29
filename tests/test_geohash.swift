import Foundation

// Copying GeohashHelper for standalone testing
struct GeohashHelper {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    
    static func encode(latitude: Double, longitude: Double, precision: Int = 9) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var geohash = ""
        var isEven = true
        var bit = 0
        var ch = 0
        
        while geohash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude > mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude > mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            
            isEven = !isEven
            if bit < 4 {
                bit += 1
            } else {
                geohash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        return geohash
    }
}

// Test cases
func testGeohash() {
    print("Running Geohash Tests...")
    
    // London
    let london = GeohashHelper.encode(latitude: 51.5074, longitude: -0.1278, precision: 9)
    print("London (51.5074, -0.1278): \(london)")
    assert(london.startsWith("gcpvj"), "London geohash should start with gcpvj")
    
    // New York
    let ny = GeohashHelper.encode(latitude: 40.7128, longitude: -74.0060, precision: 9)
    print("New York (40.7128, -74.0060): \(ny)")
    assert(ny.startsWith("dr5r"), "NY geohash should start with dr5r")
    
    print("✅ Geohash Tests Passed!")
}

extension String {
    func startsWith(_ prefix: String) -> Bool {
        return self.hasPrefix(prefix)
    }
}

testGeohash()
