import Foundation
import CoreLocation

// MARK: - GeoJSON Structures (for stops.geojson)
struct WidgetStopFeatureCollection: Codable {
    let features: [WidgetStopFeature]
}

struct WidgetStopFeature: Codable {
    let properties: WidgetStopProperties
}

struct WidgetStopProperties: Codable {
    let stopId: String
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
struct WidgetParsedStopInfo: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    
    var clLocation: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

// MARK: - Widget Stop Data Loader
/// A self-contained stop data loader for the widget extension.
/// Loads stop data directly from bundled JSON files.
class WidgetStopDataLoader {
    static let shared = WidgetStopDataLoader()
    
    private var allStops: [WidgetParsedStopInfo] = []
    private var isLoaded = false
    
    // Route stops index: route_number -> [stop_ids]
    private var routeStops: [String: [String]] = [:]
    // Stop code to internal ID mapping
    private var stopMapping: [String: String] = [:]
    private var routeStopsLoaded = false
    
    private init() {}
    
    // MARK: - Stop Data Loading
    
    private func loadStopsIfNeeded() {
        guard !isLoaded else { return }
        
        guard let url = Bundle.main.url(forResource: "stops", withExtension: "geojson") else {
            print("❌ WidgetStopDataLoader: Could not find stops.geojson in Bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(WidgetStopFeatureCollection.self, from: data)
            
            self.allStops = decoded.features.map { feature in
                WidgetParsedStopInfo(
                    id: feature.properties.stopId,
                    name: feature.properties.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: feature.properties.latitude,
                        longitude: feature.properties.longitude
                    )
                )
            }
            self.isLoaded = true
            print("✅ WidgetStopDataLoader: Loaded \(self.allStops.count) stops from GeoJSON")
        } catch {
            print("❌ WidgetStopDataLoader: Failed to parse GeoJSON: \(error)")
        }
    }
    
    // MARK: - Route/Stop Index Loading
    
    private func loadRouteStops() {
        guard !routeStopsLoaded else { return }
        
        // Load Route Stops
        if let url = Bundle.main.url(forResource: "route_stops", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                routeStops = try JSONDecoder().decode([String: [String]].self, from: data)
                print("✅ WidgetStopDataLoader: Loaded route stops index (\(routeStops.keys.count) routes)")
            } catch {
                print("❌ WidgetStopDataLoader: Failed to parse route_stops.json: \(error)")
            }
        } else {
            print("⚠️ WidgetStopDataLoader: route_stops.json not found in bundle.")
        }
        
        // Load Stop Mapping
        if let url = Bundle.main.url(forResource: "stop_mapping", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                stopMapping = try JSONDecoder().decode([String: String].self, from: data)
                print("✅ WidgetStopDataLoader: Loaded stop mapping (\(stopMapping.keys.count) entries)")
            } catch {
                print("❌ WidgetStopDataLoader: Failed to parse stop_mapping.json: \(error)")
            }
        } else {
            print("⚠️ WidgetStopDataLoader: stop_mapping.json not found in bundle.")
        }
        
        routeStopsLoaded = true
    }
    
    // MARK: - Public Methods
    
    /// Get the set of stop IDs that serve a specific route
    func getStopsForRoute(_ route: String) -> Set<String> {
        loadRouteStops()
        guard routeStopsLoaded else { return [] }
        return Set(routeStops[route] ?? [])
    }
    
    /// Convert a stop code to its internal GTFS ID
    func getGTFSId(for stopCode: String) -> String? {
        loadRouteStops()
        return stopMapping[stopCode]
    }
    
    /// Find the closest stops that serve a specific route (sorted by distance).
    /// Only returns stops within 2km of the user's location.
    func findClosestStopsForRoute(_ route: String, from location: CLLocation, limit: Int = 6) -> [WidgetParsedStopInfo] {
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
        .filter { $0.distance <= maxDistance }
        .sorted { $0.distance < $1.distance }
        
        return sorted.prefix(limit).map { $0.stop }
    }
    
    /// Find nearest stop that serves a specific route
    func findNearestStopForRoute(_ route: String, from location: CLLocation) -> WidgetParsedStopInfo? {
        return findClosestStopsForRoute(route, from: location, limit: 1).first
    }
}
