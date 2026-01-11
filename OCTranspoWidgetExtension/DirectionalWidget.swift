import WidgetKit
import SwiftUI
import CoreLocation

// MARK: - Direction 1 Timeline Provider (Inbound)
// This matches DepartureTimelineProvider EXACTLY, but filters for direction 1 instead of 0
struct Direction1TimelineProvider: TimelineProvider {
    typealias Entry = DepartureEntry
    
    // Helper to get current theme from UserDefaults
    private func getCurrentTheme() -> String {
        guard let userDefaults = UserDefaults(suiteName: UserDefaultsKeys.suiteName) else {
            return "classic"
        }
        userDefaults.synchronize()
        return userDefaults.string(forKey: UserDefaultsKeys.selectedWidgetTheme) ?? "classic"
    }
    
    func placeholder(in context: Context) -> DepartureEntry {
        // Mock departures for preview
        let mockDepartures = [
            Departure(id: "1", routeNumber: "6", routeName: "Rockcliffe", destination: "Rockcliffe", minutesUntilArrival: 5, isArrivingNow: false, directionId: 1, stopId: "123", stopName: "Rideau"),
            Departure(id: "2", routeNumber: "7", routeName: "St-Laurent", destination: "St-Laurent", minutesUntilArrival: 12, isArrivingNow: false, directionId: 1, stopId: "123", stopName: "Rideau"),
            Departure(id: "3", routeNumber: "12", routeName: "Blair", destination: "Blair", minutesUntilArrival: 18, isArrivingNow: false, directionId: 1, stopId: "123", stopName: "Rideau")
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
            Departure(id: "1", routeNumber: "6", routeName: "Rockcliffe", destination: "Rockcliffe", minutesUntilArrival: 5, isArrivingNow: false, directionId: 1, stopId: "123", stopName: "Rideau"),
            Departure(id: "2", routeNumber: "7", routeName: "St-Laurent", destination: "St-Laurent", minutesUntilArrival: 12, isArrivingNow: false, directionId: 1, stopId: "123", stopName: "Rideau"),
            Departure(id: "3", routeNumber: "12", routeName: "Blair", destination: "Blair", minutesUntilArrival: 18, isArrivingNow: false, directionId: 1, stopId: "123", stopName: "Rideau")
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
            print("⏳ Direction1 Widget: Starting getTimeline Task...")
            let baseEntry = await fetchDepartureEntry()
            
            print("📋 Direction1 Widget Timeline: Entry has \(baseEntry.departures.count) departures, stopName: \(baseEntry.stopName)")
            
            // Create multiple entries with pre-calculated countdown times
            // This allows the widget to update the display every minute without fetching new data
            var entries: [DepartureEntry] = []
            let now = Date()
            
            // Create entries for the next 20 minutes (one per minute)
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
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            print("✅ Direction1 Widget: Created predictive timeline with \(entries.count) entries, next refresh at \(refreshDate)")
            
            completion(timeline)
        }
    }
    
    private func fetchDepartureEntry() async -> DepartureEntry {
        print("🚀 Direction1 Widget: fetchDepartureEntry started")
        
        let theme = getCurrentTheme()
        
        // Get stored selected routes
        guard let userDefaults = UserDefaults(suiteName: UserDefaultsKeys.suiteName) else {
            print("❌ Direction1 Widget: Failed to access App Group UserDefaults")
            return DepartureEntry(date: Date(), departures: [], stopName: "Error: App Group", theme: theme)
        }
        
        let selectedRoutes = userDefaults.array(forKey: "SelectedRoutes") as? [String] ?? []
        print("📋 Direction1 Widget: Selected routes = \(selectedRoutes)")
        
        // Try to load cached departures first to get the stop IDs
        guard let cachedDepartures = WidgetDataCache.shared.loadDepartures(), !cachedDepartures.isEmpty else {
            print("⚠️ Direction1 Widget: No cached departures - open main app to load data")
            return DepartureEntry(
                date: Date(),
                departures: [],
                stopName: "OPEN APP TO LOAD",
                theme: theme
            )
        }
        
        print("✅ Direction1 Widget: Have \(cachedDepartures.count) cached departures")
        
        // API fetch removed - using cache only to prevent timeouts
        print("ℹ️ Direction1 Widget: Using cached data only (API fetch disabled)")
        
        // Use cached data directly
        let departuresToUse = cachedDepartures
        
        // Filter for DIRECTION 1 ONLY (inbound)
        var filteredDepartures = departuresToUse.filter { $0.directionId == 1 }
        print("📋 Direction1 Widget: Filtered to \(filteredDepartures.count) direction 1 departures")
        
        // Filter by selected routes if any
        if !selectedRoutes.isEmpty {
            filteredDepartures = filteredDepartures.filter { selectedRoutes.contains($0.routeNumber) }
            print("📋 Direction1 Widget: Filtered to \(filteredDepartures.count) for routes: \(selectedRoutes)")
        }
        
        // Keep only one per route (the soonest)
        let onePerRoute = getOnePerRoute(filteredDepartures)
        
        if onePerRoute.isEmpty {
            return DepartureEntry(
                date: Date(),
                departures: [],
                stopName: "NO DEPARTURES",
                theme: theme
            )
        }
        
        // Use "Nearby Stops" as the header since we have multiple stops
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
        
        if latitude == 0 && longitude == 0 {
            return (nil, "OPEN APP FOR LOCATION")
        }
        
        let age = Date().timeIntervalSince1970 - timestamp
        let maxAge: TimeInterval = 6 * 60 * 60 // 6 hours
        
        if age > maxAge {
            let hours = Int(age / 3600)
            print("⚠️ Direction1 Widget: Cached location is \(hours) hours old (max: 6 hours)")
            return (nil, "LOCATION EXPIRED")
        }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return (location, nil)
    }
    
    // Helper to keep only one departure per route (sorted by arrival time)
    private func getOnePerRoute(_ departures: [Departure]) -> [Departure] {
        var seenRoutes: Set<String> = []
        var result: [Departure] = []
        
        let sorted = departures.sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }
        
        for dep in sorted {
            if !seenRoutes.contains(dep.routeNumber) {
                seenRoutes.insert(dep.routeNumber)
                result.append(dep)
            }
        }
        
        return result
    }
}


// MARK: - Inbound Departures Widget (Direction 1)
// This is an EXACT clone of OCTranspoWidget, just using Direction1TimelineProvider
struct InboundDeparturesWidget: Widget {
    let kind: String = "InboundDeparturesWidget"
    
    init() {
        // Register fonts once at startup
        WidgetFontLoader.shared.registerFontsIfNeeded()
    }
    
    // Get background color based on theme - SAME as OCTranspoWidget
    private func getBackgroundColor(for theme: String) -> Color {
        switch theme {
        case "classic", "night":
            return .black
        case "oldwindows":
            return Color(red: 0.0, green: 0.0, blue: 1.0) // Windows blue
        case "crt":
            return .black
        case "minimal":
            return .white
        case "skeuomorphic":
            return Color(red: 0.90, green: 0.88, blue: 0.85) // Linen background
        default:
            return .black
        }
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Direction1TimelineProvider()) { entry in
            DepartureBoardView(entry: entry)
                .id(entry.theme) // Force view refresh when theme changes
                .containerBackground(getBackgroundColor(for: entry.theme), for: .widget)
        }
        .configurationDisplayName("Ottawa Inbound Departures")
        .description("Direction 1 - Retro LED-style bus departure board")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled() // Allow full bleed for CRT effects
    }
}

