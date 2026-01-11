import Foundation
import CoreLocation
import MapKit

// MARK: - Route Stop Finder
// Finds stops for a specific route based on user location
struct RouteStopFinder {
    
    // MARK: - New Stop-Centric Finder
    // Finds nearby stops and prepares them for API querying (handling ID mapping)
    static func findCandidateStops(
        near location: CLLocation,
        limit: Int = 5
    ) -> [StopInfo] {
        // 1. Get raw candidates from GeoJSON
        let rawCandidates = StopDataLoader.shared.findClosestStops(to: location, limit: limit)
        
        // 2. Map them to StopInfo with correct ID translation
        return rawCandidates.map { candidate in
            // candidate.id is the Visible Code (e.g. 8922) from GeoJSON
            // We map it to the Internal ID (e.g. 428) for the API
            let mappedId = StopDataLoader.shared.getGTFSId(for: candidate.id) ?? candidate.id
            
            return StopInfo(
                id: mappedId,          // Internal ID (e.g. 428) used for API
                code: candidate.id,    // Visible Code (e.g. 8922) used for UI
                name: candidate.name,
                coordinate: candidate.coordinate
            )
        }
    }
}

// MARK: - Stop Info (shared with widget extension)
struct StopInfo {
    let id: String   // Internal API ID (e.g. 428)
    let code: String // Visible Stop Code (e.g. 8922)
    let name: String // Stop Name
    let coordinate: CLLocationCoordinate2D
}
