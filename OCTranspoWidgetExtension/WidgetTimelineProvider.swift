import WidgetKit
import CoreLocation
import Combine
import MapKit
import Foundation

// MARK: - UserDefaults Keys
struct UserDefaultsKeys {
    static let suiteName = "group.com.myapp.octranspo"
    static let favoriteStops = "FavoriteStops" // Array of stop IDs like ["8922", "5813"]
    static let selectedWidgetTheme = "SelectedWidgetTheme" // Selected theme ID like "classic", "night", etc.
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Check ACTUAL authorization status on init
        authorizationStatus = locationManager.authorizationStatus
        print("📍 LocationManager init: status = \(authorizationStatus.rawValue)")
    }
    
    func requestLocation() {
        // Always check the actual status from CLLocationManager
        let actualStatus = locationManager.authorizationStatus
        print("📍 LocationManager requestLocation: actual status = \(actualStatus.rawValue)")
        
        switch actualStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 LocationManager: Requesting location...")
            locationManager.requestLocation()
        case .notDetermined:
            print("⚠️ LocationManager: Authorization not determined - app needs to request first")
        case .denied, .restricted:
            print("❌ LocationManager: Authorization denied/restricted")
        @unknown default:
            print("❌ LocationManager: Unknown authorization status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first
        if let loc = currentLocation {
            print("✅ LocationManager: Got location \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 LocationManager: Authorization changed to \(authorizationStatus.rawValue)")
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}

// MARK: - Stop Info (with coordinates) - Widget Extension version
// Note: This is separate from RouteStopFinder.StopInfo to avoid conflicts
struct WidgetStopInfo {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Stop Location Helper
struct StopLocationHelper {
    // Cache for stop info to avoid repeated API calls
    private static var stopCache: [String: WidgetStopInfo] = [:]
    
    static func getNearestStop(
        from stopIds: [String],
        to location: CLLocation
    ) async -> WidgetStopInfo? {
        var nearestStop: WidgetStopInfo?
        var nearestDistance: CLLocationDistance = Double.infinity
        
        for stopId in stopIds {
            guard let stopInfo = await getStopInfo(stopId: stopId, userLocation: location) else {
                continue
            }
            
            let stopLocation = CLLocation(
                latitude: stopInfo.coordinate.latitude,
                longitude: stopInfo.coordinate.longitude
            )
            
            let distance = location.distance(from: stopLocation)
            
            if distance < nearestDistance {
                nearestDistance = distance
                nearestStop = stopInfo
            }
        }
        
        return nearestStop
    }
    
    private static func getStopInfo(stopId: String, userLocation: CLLocation) async -> WidgetStopInfo? {
        // Check cache first
        if let cached = stopCache[stopId] {
            return cached
        }
        
        // Try to fetch using MapKit's transit search
        if let stopInfo = await searchTransitStop(stopId: stopId, near: userLocation) {
            stopCache[stopId] = stopInfo
            return stopInfo
        }
        
        // Fallback: Try OC Transpo API
        if let stopInfo = await fetchFromOCTranspoAPI(stopId: stopId) {
            stopCache[stopId] = stopInfo
            return stopInfo
        }
        
        return nil
    }
    
    private static func searchTransitStop(stopId: String, near location: CLLocation) async -> WidgetStopInfo? {
        // Use MapKit to search for transit stops near the user
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "OC Transpo stop \(stopId)"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000, // 5km radius
            longitudinalMeters: 5000
        )
        request.resultTypes = [.pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            // Find the closest result
            var closestResult: MKMapItem?
            var closestDistance: CLLocationDistance = Double.infinity
            
            for item in response.mapItems {
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = location.distance(from: itemLocation)
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestResult = item
                }
            }
            
            if let result = closestResult {
                let coordinate = result.placemark.coordinate
                let name = result.name ?? "Stop \(stopId)"
                
                return WidgetStopInfo(
                    id: stopId,
                    name: name,
                    coordinate: coordinate
                )
            }
        } catch {
            print("MapKit search failed: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Find the nearest OC Transpo stop to user's location (any stop, not just favorites)
    static func findNearestOCTranspoStop(to location: CLLocation) async -> WidgetStopInfo? {
        // Use MapKit to search for OC Transpo transit stops
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "OC Transpo bus stop"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 1000, // 1km radius - look for nearby stops
            longitudinalMeters: 1000
        )
        request.resultTypes = [.pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            
            // Find the closest OC Transpo stop
            var closestStop: WidgetStopInfo?
            var closestDistance: CLLocationDistance = Double.infinity
            
            for item in response.mapItems {
                // Filter for OC Transpo stops
                guard let name = item.name,
                      name.localizedCaseInsensitiveContains("OC Transpo") ||
                      name.localizedCaseInsensitiveContains("bus stop") ||
                      item.placemark.name?.localizedCaseInsensitiveContains("stop") == true else {
                    continue
                }
                
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = location.distance(from: itemLocation)
                
                if distance < closestDistance {
                    closestDistance = distance
                    // Try to extract stop ID from name (e.g., "Stop 5813" or "OC Transpo Stop 8922")
                    let stopId = extractStopId(from: name) ?? "Unknown"
                    closestStop = WidgetStopInfo(
                        id: stopId,
                        name: name,
                        coordinate: item.placemark.coordinate
                    )
                }
            }
            
            if let stop = closestStop {
                print("📍 Found nearest OC Transpo stop: \(stop.id) (\(stop.name)) - \(Int(closestDistance))m away")
                return stop
            }
        } catch {
            print("MapKit search for nearest stop failed: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Extract stop ID from stop name (e.g., "Stop 5813" -> "5813")
    private static func extractStopId(from name: String) -> String? {
        // Look for patterns like "Stop 5813", "5813", "Stop #5813", etc.
        let patterns = [
            "Stop\\s*(?:#)?\\s*(\\d+)",
            "(?:OC Transpo\\s+)?Stop\\s*(\\d+)",
            "\\b(\\d{4,})\\b" // 4+ digit number
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                if let match = regex.firstMatch(in: name, options: [], range: range) {
                    if let stopIdRange = Range(match.range(at: 1), in: name) {
                        return String(name[stopIdRange])
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func fetchFromOCTranspoAPI(stopId: String) async -> WidgetStopInfo? {
        // Try OC Transpo NextRide API - this might return stop info
        // First, let's try to get stops near a location using the Azure API
        // If OC Transpo has a "stops near location" endpoint, use that
        
        // Alternative: Use the GTFS-RT feed to extract stop info
        // But GTFS-RT doesn't have coordinates, so we need another approach
        
        // For now, return nil and let the MapKit search handle it
        // For now, return nil and let the MapKit search handle it
        return nil
    }
    
    // Fallback: Hardcoded stops for common locations if MapKit fails
    // This is a safety net
    static func getHardcodedFallbackStop(for location: CLLocation) -> WidgetStopInfo? {
        // Carleton University
        let carleton = CLLocation(latitude: 45.385, longitude: -75.698)
        if location.distance(from: carleton) < 1000 {
            return WidgetStopInfo(id: "6612", name: "Carleton U", coordinate: CLLocationCoordinate2D(latitude: 45.385, longitude: -75.698))
        }
        
        // Rideau Centre
        let rideau = CLLocation(latitude: 45.424, longitude: -75.692)
        if location.distance(from: rideau) < 1000 {
            return WidgetStopInfo(id: "3000", name: "Rideau Centre", coordinate: CLLocationCoordinate2D(latitude: 45.424, longitude: -75.692))
        }
        
        return nil
    }
}

// MARK: - Timeline Provider
struct DepartureTimelineProvider: TimelineProvider {
    typealias Entry = DepartureEntry
    
    private let locationManager = LocationManager()
    
    init() {
        print("🚀 DepartureTimelineProvider: INIT CALLED")
    }
    
    // Helper to get current theme from UserDefaults
    private func getCurrentTheme() -> String {
        guard let userDefaults = UserDefaults(suiteName: UserDefaultsKeys.suiteName) else {
            print("❌ Widget Theme: Failed to access App Group UserDefaults")
            return "classic"
        }
        
        // Force synchronize to ensure we have latest values
        userDefaults.synchronize()
        
        let theme = userDefaults.string(forKey: UserDefaultsKeys.selectedWidgetTheme) ?? "classic"
        print("🎨 Widget Theme: Reading theme from UserDefaults: '\(theme)'")
        
        // Debug: List all keys in the App Group
        let allKeys = userDefaults.dictionaryRepresentation().keys
        print("🔑 Widget Theme: Available keys in App Group: \(Array(allKeys).prefix(10))")
        
        return theme
    }
    
    func placeholder(in context: Context) -> DepartureEntry {
        print("📋 DepartureTimelineProvider: placeholder() called")
        // Mock departures for preview
        let mockDepartures = [
            Departure(id: "1", routeNumber: "6", routeName: "Rockcliffe", destination: "Rockcliffe", minutesUntilArrival: 5, isArrivingNow: false, directionId: 0, stopId: "123", stopName: "Rideau"),
            Departure(id: "2", routeNumber: "7", routeName: "St-Laurent", destination: "St-Laurent", minutesUntilArrival: 12, isArrivingNow: false, directionId: 0, stopId: "123", stopName: "Rideau"),
            Departure(id: "3", routeNumber: "12", routeName: "Blair", destination: "Blair", minutesUntilArrival: 18, isArrivingNow: false, directionId: 0, stopId: "123", stopName: "Rideau")
        ]
        
        return DepartureEntry(
            date: Date(),
            departures: mockDepartures,
            stopName: "Rideau",
            theme: getCurrentTheme()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> Void) {
        // Mock departures for gallery preview
        let mockDepartures = [
            Departure(id: "1", routeNumber: "6", routeName: "Rockcliffe", destination: "Rockcliffe", minutesUntilArrival: 5, isArrivingNow: false, directionId: 0, stopId: "123", stopName: "Rideau"),
            Departure(id: "2", routeNumber: "7", routeName: "St-Laurent", destination: "St-Laurent", minutesUntilArrival: 12, isArrivingNow: false, directionId: 0, stopId: "123", stopName: "Rideau"),
            Departure(id: "3", routeNumber: "12", routeName: "Blair", destination: "Blair", minutesUntilArrival: 18, isArrivingNow: false, directionId: 0, stopId: "123", stopName: "Rideau")
        ]
        
        let entry = DepartureEntry(
            date: Date(),
            departures: mockDepartures,
            stopName: "Rideau",
            theme: getCurrentTheme()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureEntry>) -> Void) {
        Task {
            print("⏳ Widget: Starting getTimeline Task...")
            let baseEntry = await fetchDepartureEntry()
            
            print("📋 Widget Timeline: Entry has \(baseEntry.departures.count) departures, stopName: \(baseEntry.stopName)")
            
            // Create multiple entries with pre-calculated countdown times
            // This allows the widget to update the display every minute without fetching new data
            var entries: [DepartureEntry] = []
            let now = Date()
            
            // Create entries for the next 20 minutes (one per minute)
            // This ensures the widget counts down even if background refresh is delayed
            for minuteOffset in 0..<20 {
                let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) ?? now
                
                // Adjust departure times for this entry
                let adjustedDepartures = baseEntry.departures.compactMap { departure -> Departure? in
                    let adjustedMinutes = departure.minutesUntilArrival - minuteOffset
                    if adjustedMinutes < -1 { return nil } // Bus has passed
                    
                    return Departure(
                        id: departure.id,
                        routeNumber: departure.routeNumber,
                        routeName: departure.routeName,
                        destination: departure.destination,
                        minutesUntilArrival: max(0, adjustedMinutes),
                        isArrivingNow: adjustedMinutes <= 0,
                        directionId: departure.directionId,
                        stopId: departure.stopId,
                        stopName: departure.stopName
                    )
                }
                
                let entry = DepartureEntry(
                    date: entryDate,
                    departures: adjustedDepartures,
                    stopName: baseEntry.stopName,
                    theme: baseEntry.theme
                )
                entries.append(entry)
            }
            
            // Request a refresh in 5 minutes to keep data fresh
            // The widget will attempt to fetch new data from the API at that time
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            print("✅ Widget: Created predictive timeline with \(entries.count) entries, next refresh at \(refreshDate)")
            
            completion(timeline)
        }
    }
    
    private func fetchDepartureEntry() async -> DepartureEntry {
        print("🚀 Widget: fetchDepartureEntry started")
        
        // Get current theme
        let theme = getCurrentTheme()
        
        // Get stored selected routes
        guard let userDefaults = UserDefaults(suiteName: UserDefaultsKeys.suiteName) else {
            print("❌ Widget: Failed to access App Group UserDefaults")
            return DepartureEntry(date: Date(), departures: [], stopName: "Error: App Group", theme: theme)
        }
        
        let selectedRoutes = userDefaults.array(forKey: "SelectedRoutes") as? [String] ?? []
        print("📋 Widget: Selected routes = \(selectedRoutes)")
        
        // Load cached departures (saved by main app's background refresh)
        guard let cachedDepartures = WidgetDataCache.shared.loadDepartures(), !cachedDepartures.isEmpty else {
            print("⚠️ Widget: No cached departures - open main app to load data")
            return DepartureEntry(
                date: Date(),
                departures: [],
                stopName: "OPEN APP TO LOAD",
                theme: theme
            )
        }
        
        print("✅ Widget: Loaded \(cachedDepartures.count) cached departures")
        
        // Filter for DIRECTION 0 ONLY (outbound)
        var filteredDepartures = cachedDepartures.filter { $0.directionId == 0 }
        print("📋 Widget: Filtered to \(filteredDepartures.count) direction 0 departures")
        
        // Filter by selected routes if any
        if !selectedRoutes.isEmpty {
            filteredDepartures = filteredDepartures.filter { selectedRoutes.contains($0.routeNumber) }
            print("📋 Widget: Filtered to \(filteredDepartures.count) for routes: \(selectedRoutes)")
        }
        
        // Keep only one per route (the soonest)
        let onePerRoute = getOnePerRoute(filteredDepartures, stopName: "Departures")
        
        if onePerRoute.isEmpty {
            return DepartureEntry(
                date: Date(),
                departures: [],
                stopName: "NO DEPARTURES",
                theme: theme
            )
        }
        
        // Use "Nearby Stops" as the header
        return DepartureEntry(
            date: Date(),
            departures: onePerRoute,
            stopName: "Nearby Stops",
            theme: theme
        )
    }
    
    // MARK: - Location Cache Helper
    private func getCachedLocation(from userDefaults: UserDefaults) -> (location: CLLocation?, errorMessage: String?) {
        let latitude = userDefaults.double(forKey: "LastKnownLatitude")
        let longitude = userDefaults.double(forKey: "LastKnownLongitude")
        let timestamp = userDefaults.double(forKey: "LastKnownLocationTimestamp")
        
        // Check if location was ever saved
        if latitude == 0 && longitude == 0 {
            return (nil, "OPEN APP FOR LOCATION")
        }
        
        // Check if location is stale (older than 6 hours)
        let age = Date().timeIntervalSince1970 - timestamp
        let maxAge: TimeInterval = 6 * 60 * 60 // 6 hours in seconds
        
        if age > maxAge {
            let hours = Int(age / 3600)
            print("⚠️ Widget: Cached location is \(hours) hours old (max: 6 hours)")
            return (nil, "LOCATION EXPIRED")
        }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return (location, nil)
    }
    
    // Helper to keep only one departure per route (sorted by arrival time)
    private func getOnePerRoute(_ departures: [Departure], stopName: String) -> [Departure] {
        var seenRoutes: Set<String> = []
        var result: [Departure] = []
        
        // Sort by arrival time first
        let sorted = departures.sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }
        
        for dep in sorted {
            if !seenRoutes.contains(dep.routeNumber) {
                seenRoutes.insert(dep.routeNumber)
                result.append(dep)
            }
        }
        
        return result
    }
    
    private func extractStopId(from name: String) -> String? {
        let patterns = [
            "Stop\\s*(?:#)?\\s*(\\d+)",
            "(?:OC Transpo\\s+)?Stop\\s*(\\d+)",
            "\\b(\\d{4,})\\b"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                if let match = regex.firstMatch(in: name, options: [], range: range) {
                    if let stopIdRange = Range(match.range(at: 1), in: name) {
                        return String(name[stopIdRange])
                    }
                }
            }
        }
        
        return nil
    }
    
    private func fetchDeparturesForStop(stopId: String, stopName: String) async -> DepartureEntry {
        do {
            let departures = try await GTFSService.shared.fetchDepartures(for: stopId)
            return DepartureEntry(
                date: Date(),
                departures: departures,
                stopName: stopName
            )
        } catch let error as GTFSError {
            let errorMsg: String
            switch error {
            case .invalidURL:
                errorMsg = "Invalid URL"
            case .invalidResponse:
                errorMsg = "API Error"
            case .decodingError:
                errorMsg = "Data Error"
            case .noDataForStop:
                errorMsg = "No Data"
            }
            return DepartureEntry(
                date: Date(),
                departures: [],
                stopName: errorMsg
            )
        } catch {
            // Truncate long error messages
            let errorDesc = error.localizedDescription
            let shortError = errorDesc.count > 20 ? String(errorDesc.prefix(20)) + "..." : errorDesc
            return DepartureEntry(
                date: Date(),
                departures: [],
                stopName: "Error: \(shortError)"
            )
        }
    }
}

// MARK: - Timeline Entry
struct DepartureEntry: TimelineEntry {
    let date: Date
    let departures: [Departure]
    let stopName: String
    let theme: String  // Theme is now part of the entry
    
    init(date: Date, departures: [Departure], stopName: String, theme: String = "classic") {
        self.date = date
        self.departures = departures
        self.stopName = stopName
        self.theme = theme
    }
}

