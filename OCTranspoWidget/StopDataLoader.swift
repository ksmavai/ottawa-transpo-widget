import Foundation
import CoreLocation

// MARK: - GeoJSON Structures
struct StopFeatureCollection: Codable {
    let features: [StopFeature]
}

struct StopFeature: Codable {
    let properties: StopProperties
}

struct StopProperties: Codable {
    let stopId: String // Can be numeric (8922) or alphanumeric (CG990 for O-Train)
    let name: String
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case stopId = "F560"
        case name = "Location"
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
    
    // Custom decoder to handle both Int and String for F560
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode as String first, then as Int
        if let stringValue = try? container.decode(String.self, forKey: .stopId) {
            stopId = stringValue
        } else if let intValue = try? container.decode(Int.self, forKey: .stopId) {
            stopId = String(intValue)
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "F560 must be either String or Int"
            ))
        }
        
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
    }
}

// MARK: - Stop Info Model
struct ParsedStopInfo: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    
    var clLocation: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

// MARK: - Stop Data Loader
class StopDataLoader {
    static let shared = StopDataLoader()
    
    private var allStops: [ParsedStopInfo] = []
    private var isLoaded = false
    
    // Load data only when needed
    init() {
        // Lazy load is better, but simple calls might need it ready.
        // We'll load on first access to 'allStops' logic.
    }
    
    private func loadStopsIfNeeded() {
        guard !isLoaded else { return }
        
        // Debug: Print the bundle path we are searching in
        print("📂 StopDataLoader: Searching for stops.geojson in bundle: \(Bundle.main.bundlePath)")
        
        guard let url = Bundle.main.url(forResource: "stops", withExtension: "geojson") else {
            print("❌ StopDataLoader: Could not find stops.geojson in Bundle.")
            // Debug: List all files in bundle to see if it's there
            if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                 print("   Files found: \(files.filter { $0.contains("stops") })")
            }
            return
        }
        
        print("✅ StopDataLoader: Found file at \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(StopFeatureCollection.self, from: data)
            
            self.allStops = decoded.features.map { feature in
                ParsedStopInfo(
                    id: feature.properties.stopId,
                    name: feature.properties.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: feature.properties.latitude,
                        longitude: feature.properties.longitude
                    )
                )
            }
            self.isLoaded = true
            print("✅ StopDataLoader: Loaded \(self.allStops.count) stops from GeoJSON")
        } catch {
            print("❌ StopDataLoader: Failed to parse GeoJSON: \(error)")
        }
    }
    
    func findClosestStops(to location: CLLocation, limit: Int = 20) -> [ParsedStopInfo] {
        loadStopsIfNeeded()
        
        // Brute force distance optimization
        // Filtering simple bounding box first could optimize, but for 5000 items, sort is usually fine (~20ms)
        let sorted = allStops.map { stop in
            (stop: stop, distance: location.distance(from: stop.clLocation))
        }.sorted { $0.distance < $1.distance }
        
        return sorted.prefix(limit).map { $0.stop }
    }
    // MARK: - Route Stops Index
    private var routeStops: [String: [String]] = [:]
    private var stopMapping: [String: String] = [:] // stop_code -> stop_id
    private var routeStopsLoaded = false
    
    private func loadRouteStops() {
        guard !routeStopsLoaded else { return }
        
        // Load Route Stops
        if let url = Bundle.main.url(forResource: "route_stops", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                routeStops = try JSONDecoder().decode([String: [String]].self, from: data)
                print("✅ StopDataLoader: Loaded route stops index (\(routeStops.keys.count) routes)")
            } catch {
                print("❌ StopDataLoader: Failed to parse route_stops.json: \(error)")
            }
        } else {
            print("⚠️ StopDataLoader: route_stops.json not found in bundle.")
        }
        
        // Load Stop Mapping
        if let url = Bundle.main.url(forResource: "stop_mapping", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                stopMapping = try JSONDecoder().decode([String: String].self, from: data)
                print("✅ StopDataLoader: Loaded stop mapping (\(stopMapping.keys.count) entries). 8922 -> \(stopMapping["8922"] ?? "nil")")
            } catch {
                print("❌ StopDataLoader: Failed to parse stop_mapping.json: \(error)")
            }
        } else {
             print("⚠️ StopDataLoader: stop_mapping.json not found in bundle.")
        }
        
        routeStopsLoaded = true
    }
    
    var debugStatus: String {
        // Force load to give accurate status
        if !isLoaded { loadStopsIfNeeded() }
        if !routeStopsLoaded { loadRouteStops() }
        
        let stopsStatus = isLoaded ? "Stops: \(allStops.count)" : "Stops: Failed"
        let indexStatus = routeStopsLoaded ? "Index: \(routeStops.keys.count)" : "Index: Failed"
        return "\(stopsStatus) | \(indexStatus)"
    }

    func getStopsForRoute(_ route: String) -> Set<String> {
        loadRouteStops()
        guard routeStopsLoaded else { return [] }
        return Set(routeStops[route] ?? [])
    }
    
    func getGTFSId(for stopCode: String) -> String? {
        loadRouteStops()
        return stopMapping[stopCode]
    }
    
    /// Find the nearest stop that serves a specific route
    func findNearestStopForRoute(_ route: String, from location: CLLocation) -> ParsedStopInfo? {
        loadStopsIfNeeded()
        loadRouteStops()
        
        let routeStopIds = getStopsForRoute(route)
        guard !routeStopIds.isEmpty else {
            print("⚠️ No stops found for route \(route)")
            return nil
        }
        
        // Filter stops to only those serving this route
        let stopsForRoute = allStops.filter { stop in
            // Check if this stop serves the route
            // The route_stops uses GTFS IDs, but our allStops uses stop codes
            // We need to check both ways
            if routeStopIds.contains(stop.id) {
                return true
            }
            // Also try the mapped GTFS ID
            if let gtfsId = stopMapping[stop.id], routeStopIds.contains(gtfsId) {
                return true
            }
            return false
        }
        
        guard !stopsForRoute.isEmpty else {
            print("⚠️ No matching stops found for route \(route) in loaded stops")
            return nil
        }
        
        // Find the closest one
        let sorted = stopsForRoute.map { stop in
            (stop: stop, distance: location.distance(from: stop.clLocation))
        }.sorted { $0.distance < $1.distance }
        
        if let nearest = sorted.first {
            print("📍 Nearest stop for route \(route): \(nearest.stop.name) (\(Int(nearest.distance))m)")
            return nearest.stop
        }
        
        return nil
    }
    
    /// Find the closest stops that serve a specific route (sorted by distance).
    /// Only returns stops within 2km of the user's location.
    func findClosestStopsForRoute(_ route: String, from location: CLLocation, limit: Int = 10) -> [ParsedStopInfo] {
        loadStopsIfNeeded()
        loadRouteStops()
        
        let maxDistance: Double = 2000.0 // 2km radius filter
        
        let routeStopIds = getStopsForRoute(route)
        guard !routeStopIds.isEmpty else { return [] }
        
        let stopsForRoute = allStops.filter { stop in
            if routeStopIds.contains(stop.id) { return true }
            if let gtfsId = stopMapping[stop.id], routeStopIds.contains(gtfsId) { return true }
            return false
        }
        
        guard !stopsForRoute.isEmpty else { return [] }
        
        let sorted = stopsForRoute.map { stop in
            (stop: stop, distance: location.distance(from: stop.clLocation))
        }
        .filter { $0.distance <= maxDistance } // Only include stops within 2km
        .sorted { $0.distance < $1.distance }
        
        return sorted.prefix(limit).map { $0.stop }
    }
}
