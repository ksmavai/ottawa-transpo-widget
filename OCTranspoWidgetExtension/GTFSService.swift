import Foundation
import CoreLocation

// MARK: - Mock Data Toggle
let useMockData = false // Set to false when ready to use real API

// MARK: - API Configuration
// Get your free API key from: https://octranspo.com/en/plan-your-trip/travel-tools/developers
let OC_TRANSPO_API_KEY = "YOUR_OC_TRANSPO_API_KEY_HERE"
let OC_TRANSPO_API_URL = "https://nextrip-public-api.azure-api.net/octranspo/gtfs-rt-tp/beta/v1/TripUpdates"
// NextRide endpoint for stop-specific departures (includes scheduled trips)
let OC_TRANSPO_NEXTRIDE_URL = "https://nextrip-public-api.azure-api.net/octranspo/nextride/v1/Stop"

// MARK: - Route Mapper
// Manual mapping of route_id to display names
// If a route_id is not found, the raw ID will be displayed
struct RouteMapper {
    static let routeNames: [String: String] = [
        "7-288": "7 Carleton",
        "94-28": "Route 94",
        "88-1": "Route 88",
        // Add more mappings as you discover route IDs from the API
    ]
    
    static func getRouteName(for routeId: String) -> String {
        return routeNames[routeId] ?? routeId
    }
    
    // Route direction fallbacks: [routeNumber: [directionId: destinationName]]
    // Used ONLY when no headsign can be determined from GTFS-RT or static trips.
    static let routeDirections: [String: [Int: String]] = [
        // Derived from current static GTFS headsings (most common per direction)
        "6": [0: "Greenboro", 1: "Rockcliffe"],
        "7": [0: "Carleton", 1: "St. Laurent"],
        "12": [0: "Blair", 1: "Tunney's Pasture"],
        "14": [0: "Carlington", 1: "Riverview"],
        "16": [0: "Britannia", 1: "Greenboro"],
        "19": [0: "Parliament", 1: "Hurdman"],
        "61": [0: "Terry Fox", 1: "Innovation"],
        "75": [0: "Barrhaven Centre", 1: "Cambrian"],
        "85": [0: "Bayshore", 1: "Gatineau"],
        "88": [0: "Terry Fox", 1: "Hurdman"],
        "95": [0: "Barrhaven", 1: "Orleans"],
        "97": [0: "Bayshore", 1: "Airport"]
    ]
    
    static func getDestination(for routeNumber: String, directionId: Int?) -> String {
        guard let directionId = directionId,
              let routeDirs = routeDirections[routeNumber],
              let destination = routeDirs[directionId] else {
            // Fallback: use generic destination
            return "Destination"
        }
        return destination
    }
}

// MARK: - GTFS-RT Data Models
// Note: The Azure API returns PascalCase JSON (from Protobuf conversion)
struct GTFSResponse: Codable {
    let Header: FeedHeader?
    let Entity: [FeedEntity]?
    
    // Computed properties for easier access
    var header: FeedHeader? { Header }
    var entity: [FeedEntity]? { Entity }
}

struct FeedHeader: Codable {
    let GtfsRealtimeVersion: String?
    let Timestamp: UInt64?
    
    // Ignore Has* metadata fields
    enum CodingKeys: String, CodingKey {
        case GtfsRealtimeVersion
        case Timestamp
        // Ignore Has* fields
    }
    
    var gtfsRealtimeVersion: String { GtfsRealtimeVersion ?? "2.0" }
    var timestamp: UInt64 { Timestamp ?? 0 }
}

struct FeedEntity: Codable {
    let Id: String
    let TripUpdate: TripUpdate?
    let IsDeleted: Bool?
    
    // Ignore Has* metadata fields
    enum CodingKeys: String, CodingKey {
        case Id
        case TripUpdate
        case IsDeleted
    }
    
    var id: String { Id }
    var tripUpdate: TripUpdate? { IsDeleted == true ? nil : TripUpdate }
}

struct TripUpdate: Codable {
    let Trip: Trip
    let StopTimeUpdate: [StopTimeUpdate]?
    let Vehicle: Vehicle?
    
    var trip: Trip { Trip }
    var stopTimeUpdate: [StopTimeUpdate]? { StopTimeUpdate }
}

struct Trip: Codable {
    let TripId: String?
    let RouteId: String
    let DirectionId: Int?
    let StartTime: String?
    let StartDate: String?
    let TripHeadsign: String? // Dynamic destination from API
    
    var tripId: String? { TripId }
    var routeId: String { RouteId }
    var directionId: Int? { DirectionId }
    var startTime: String? { StartTime }
    var startDate: String? { StartDate }
    var tripHeadsign: String? { TripHeadsign }
}

struct Vehicle: Codable {
    let Id: String?
    let Label: String?
}

struct StopTimeUpdate: Codable {
    let StopSequence: Int?
    let StopId: String
    let Arrival: TimeUpdate?
    let Departure: TimeUpdate?
    
    var stopId: String { StopId }
    var stopSequence: Int? { StopSequence }
    var arrival: TimeUpdate? { Arrival }
    var departure: TimeUpdate? { Departure }
}

struct TimeUpdate: Codable {
    // The API returns Time as UInt64 (Unix timestamp)
    let Time: UInt64?
    let Delay: Int?
    
    // Ignore Has* metadata fields
    enum CodingKeys: String, CodingKey {
        case Time
        case Delay
    }
    
    var time: Double? {
        guard let timeValue = Time else { return nil }
        return Double(timeValue)
    }
}

// MARK: - Processed Departure Model
struct Departure: Identifiable, Codable {
    let id: String
    let routeNumber: String // e.g. "7", "6"
    let routeName: String
    let destination: String
    let minutesUntilArrival: Int
    let isArrivingNow: Bool
    let directionId: Int? // 0 = "to", 1 = "from" (typically)
    let stopId: String? // The stop this departure is from
    let stopName: String? // Human-readable stop name
}

// MARK: - Widget Data Cache (Shared via App Group)
class WidgetDataCache {
    static let shared = WidgetDataCache()
    private let suiteName = "group.com.myapp.octranspo"
    private let cacheKey = "CachedDepartures"
    private let timestampKey = "CachedDeparturesTimestamp"
    
    private init() {}
    
    /// Save departures for widget to read
    func saveDepartures(_ departures: [Departure]) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            print("❌ WidgetDataCache: Cannot access App Group")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(departures)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: timestampKey)
            print("✅ WidgetDataCache: Saved \(departures.count) departures for widget")
        } catch {
            print("❌ WidgetDataCache: Failed to encode departures: \(error)")
        }
    }
    
    /// Load cached departures (for widget)
    func loadDepartures() -> [Departure]? {
        print("🔍 WidgetDataCache: Attempting to load departures...")
        
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            print("❌ WidgetDataCache: Failed to access App Group UserDefaults (suiteName: \(suiteName))")
            return nil
        }
        
        print("✅ WidgetDataCache: Got App Group UserDefaults")
        
        guard let data = userDefaults.data(forKey: cacheKey) else {
            print("⚠️ WidgetDataCache: No cached data found for key '\(cacheKey)'")
            // Debug: List all keys
            let allKeys = userDefaults.dictionaryRepresentation().keys
            print("🔑 WidgetDataCache: Available keys: \(Array(allKeys).prefix(10))")
            return nil
        }
        
        print("📦 WidgetDataCache: Found cached data (\(data.count) bytes)")
        
        // Calculate age/elapsed minutes
        let timestamp = userDefaults.double(forKey: timestampKey)
        let now = Date().timeIntervalSince1970
        let ageSeconds = now - timestamp
        let elapsedMinutes = Int(ageSeconds / 60)
        
        if ageSeconds > 300 {
            print("⚠️ WidgetDataCache: Cache is stale (\(Int(ageSeconds))s old / \(elapsedMinutes) mins)")
        } else {
            print("✅ WidgetDataCache: Cache is fresh (\(Int(ageSeconds))s old)")
        }
        
        do {
            let originalDepartures = try JSONDecoder().decode([Departure].self, from: data)
            
            // Adjust minutes based on age
            let adjustedDepartures = originalDepartures.map { dep -> Departure in
                let newMinutes = dep.minutesUntilArrival - elapsedMinutes
                return Departure(
                    id: dep.id,
                    routeNumber: dep.routeNumber,
                    routeName: dep.routeName,
                    destination: dep.destination,
                    minutesUntilArrival: newMinutes,
                    isArrivingNow: newMinutes <= 0,
                    directionId: dep.directionId,
                    stopId: dep.stopId,
                    stopName: dep.stopName
                )
            }
            // Filter out departures that have already passed (allowing up to -2 mins for "Arriving Now" lingering)
            .filter { $0.minutesUntilArrival >= -2 }
            
            print("✅ WidgetDataCache: Loaded \(originalDepartures.count) departures, returning \(adjustedDepartures.count) after time adjustment (-\(elapsedMinutes) mins)")
            return adjustedDepartures
        } catch {
            print("❌ WidgetDataCache: Failed to decode departures: \(error)")
            return nil
        }
    }
}

// MARK: - GTFS Service
class GTFSService {
    static let shared = GTFSService()
    
    private init() {}
    
    // Optimized fetch: Downloads feed ONCE and filters for multiple stops
    func fetchAllDepartures(for stopIds: [String], routeFilter: [String]? = nil) async throws -> [String: [Departure]] {
        if useMockData {
            var results: [String: [Departure]] = [:]
            for stopId in stopIds {
                results[stopId] = getMockDepartures(for: stopId)
            }
            return results
        }
        
        // Use GTFS-RT TripUpdates directly
        guard let url = URL(string: "\(OC_TRANSPO_API_URL)?format=json") else {
            throw GTFSError.invalidURL
        }
        
        print("🌐 Fetching ALL GTFS-RT TripUpdates (Optimized Batch Request)")
        
        var request = URLRequest(url: url)
        request.setValue(OC_TRANSPO_API_KEY, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 30.0
        let session = URLSession(configuration: config)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as NSError {
            print("Network error: \(error.localizedDescription)")
            throw GTFSError.invalidResponse
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GTFSError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        do {
            let gtfsResponse = try decoder.decode(GTFSResponse.self, from: data)
            print("✅ Successfully decoded \(gtfsResponse.entity?.count ?? 0) entities. Processing for \(stopIds.count) stops...")
            
            var results: [String: [Departure]] = [:]
            
            // Process for EACH requested stop using the SAME data
            // This avoids re-downloading the massive file 5 times
            for stopId in stopIds {
                results[stopId] = processGTFSResponse(gtfsResponse, for: stopId, routeFilter: routeFilter)
            }
            
            return results
        } catch {
            print("Decoding error: \(error)")
            throw GTFSError.decodingError
        }
    }

    func fetchDepartures(for stopId: String, routeFilter: [String]? = nil) async throws -> [Departure] {
        // Fallback to fetchAll for single stop (reusing logic)
        let results = try await fetchAllDepartures(for: [stopId], routeFilter: routeFilter)
        return results[stopId] ?? []
    }
    
    // MARK: - NextRide API (Stop-specific departures)
    private func fetchFromNextRide(stopId: String) async throws -> [Departure] {
        // Try different NextRide endpoint variations
        let endpoints = [
            "\(OC_TRANSPO_NEXTRIDE_URL)/\(stopId)",
            "https://nextrip-public-api.azure-api.net/octranspo/nextride/v1/Stops/\(stopId)",
            "https://nextrip-public-api.azure-api.net/octranspo/nextride/v1/Stops/\(stopId)/Departures",
            "https://nextrip-public-api.azure-api.net/octranspo/nextride/v1/Stop/\(stopId)/Departures"
        ]
        
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
        
        var request = URLRequest(url: url)
        request.setValue(OC_TRANSPO_API_KEY, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 10.0
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GTFSError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("NextRide API Error (\(httpResponse.statusCode)): \(errorString.prefix(200))")
                }
                throw GTFSError.invalidResponse
            }
            
            // Print response to see structure
            if let jsonString = String(data: data, encoding: .utf8) {
                print("✅ NextRide Response from \(endpoint): \(jsonString.prefix(1000))")
            }
            
            // Try to decode NextRide response
            // Note: We'll need to see the actual structure first
            // For now, return empty and let GTFS-RT handle it
            return []
        } catch {
            // Try next endpoint
            continue
        }
        }
        
        // All endpoints failed
        throw GTFSError.invalidResponse
    }
    
    // Dynamic Stop Name Loader
    class StopNameLoader {
        static let shared = StopNameLoader()
        private var stopNames: [String: String] = [:]
        private var isLoaded = false
        
        func getName(for stopId: String) -> String? {
            if !isLoaded { loadStops() }
            return stopNames[stopId]
        }
        
        private func loadStops() {
            // Try to find stops.geojson in the bundle
            guard let url = Bundle.main.url(forResource: "stops", withExtension: "geojson") else {
                print("⚠️ StopNameLoader: stops.geojson not found")
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                // Minimal decoding structure for speed
                struct StopCollection: Decodable {
                    let features: [Feature]
                    struct Feature: Decodable {
                        let properties: Properties
                        struct Properties: Decodable {
                            let stopId: Int
                            let name: String
                            enum CodingKeys: String, CodingKey {
                                case stopId = "F560"
                                case name = "Location"
                            }
                        }
                    }
                }
                
                let collection = try JSONDecoder().decode(StopCollection.self, from: data)
                for feature in collection.features {
                    let idStr = String(feature.properties.stopId)
                    stopNames[idStr] = feature.properties.name
                }
                isLoaded = true
                print("✅ StopNameLoader: Loaded \(stopNames.count) stop names")
            } catch {
                print("❌ StopNameLoader: Failed to decode stops.geojson: \(error)")
            }
        }
    }
    // MARK: - Static Trip Data Loader
    class TripDataLoader {
        static let shared = TripDataLoader()
        // Map: TripId -> { h: Headsign, d: DirectionId }
        private var tripMap: [String: StaticTripEntry] = [:]
        private var isLoaded = false
        
        struct StaticTripEntry: Decodable {
            let h: String? // Headsign
            let d: Int?    // DirectionId
        }
        
        func getStaticTrip(for tripId: String) -> StaticTripEntry? {
            if !isLoaded { loadTrips() }
            return tripMap[tripId]
        }
        
        private func loadTrips() {
            // Try to find trip_id_map.json in the bundle
            guard let url = Bundle.main.url(forResource: "trip_id_map", withExtension: "json") else {
                print("⚠️ TripDataLoader: trip_id_map.json not found")
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                tripMap = try JSONDecoder().decode([String: StaticTripEntry].self, from: data)
                isLoaded = true
                print("✅ TripDataLoader: Loaded \(tripMap.count) static trips")
            } catch {
                print("❌ TripDataLoader: Failed to decode trip_id_map.json: \(error)")
            }
        }
    }

    // MARK: - Service IDs by Date (precomputed from calendar*.txt)
    class ServiceByDateLoader {
        static let shared = ServiceByDateLoader()
        private var byDate: [String: [String]] = [:]
        private var isLoaded = false
        
        func serviceIds(for startDate: String?) -> [String] {
            guard let startDate, !startDate.isEmpty else { return [] }
            if !isLoaded { load() }
            return byDate[startDate] ?? []
        }
        
        private func load() {
            guard !isLoaded else { return }
            guard let url = Bundle.main.url(forResource: "services_by_date", withExtension: "json") else {
                print("⚠️ ServiceByDateLoader: services_by_date.json not found")
                return
            }
            do {
                let data = try Data(contentsOf: url)
                byDate = try JSONDecoder().decode([String: [String]].self, from: data)
                isLoaded = true
                print("✅ ServiceByDateLoader: Loaded \(byDate.count) days")
            } catch {
                print("❌ ServiceByDateLoader: Failed to decode services_by_date.json: \(error)")
            }
        }
    }
    
    // MARK: - Trip Start Index (precomputed from trips.txt + stop_times.txt)
    class TripStartIndexLoader {
        static let shared = TripStartIndexLoader()
        
        struct Candidate: Decodable {
            let t: String // trip_id
            let l: String // last stop_id
        }
        
        private var index: [String: [Candidate]] = [:]
        private var isLoaded = false
        
        func candidates(routeId: String, serviceId: String, startTime: String) -> [Candidate] {
            if !isLoaded { load() }
            return index["\(routeId)|\(serviceId)|\(startTime)"] ?? []
        }
        
        private func load() {
            guard !isLoaded else { return }
            guard let url = Bundle.main.url(forResource: "trip_start_index", withExtension: "json") else {
                print("⚠️ TripStartIndexLoader: trip_start_index.json not found")
                return
            }
            do {
                let data = try Data(contentsOf: url)
                index = try JSONDecoder().decode([String: [Candidate]].self, from: data)
                isLoaded = true
                print("✅ TripStartIndexLoader: Loaded \(index.count) keys")
            } catch {
                print("❌ TripStartIndexLoader: Failed to decode trip_start_index.json: \(error)")
            }
        }
    }
    
    // MARK: - Stop Headsign Overrides (precomputed stop_times.txt stop_headsign)
    class StopHeadsignOverrideLoader {
        static let shared = StopHeadsignOverrideLoader()
        private var overrides: [String: String] = [:]
        private var isLoaded = false
        
        func overrideHeadsign(tripId: String, stopId: String) -> String? {
            if !isLoaded { load() }
            return overrides["\(tripId)|\(stopId)"]
        }
        
        private func load() {
            guard !isLoaded else { return }
            guard let url = Bundle.main.url(forResource: "stop_headsign_overrides", withExtension: "json") else {
                print("⚠️ StopHeadsignOverrideLoader: stop_headsign_overrides.json not found")
                return
            }
            do {
                let data = try Data(contentsOf: url)
                overrides = try JSONDecoder().decode([String: String].self, from: data)
                isLoaded = true
                print("✅ StopHeadsignOverrideLoader: Loaded \(overrides.count) overrides")
            } catch {
                print("❌ StopHeadsignOverrideLoader: Failed to decode stop_headsign_overrides.json: \(error)")
            }
        }
    }

    private func processGTFSResponse(_ response: GTFSResponse, for stopId: String, stopName: String? = nil, routeFilter: [String]? = nil) -> [Departure] {
        let now = Date().timeIntervalSince1970
        var departures: [Departure] = []
        
        guard let entities = response.entity, !entities.isEmpty else {
            print("⚠️ No entities in GTFS response")
            return []
        }
        
        print("🔍 Processing \(entities.count) entities for stop \(stopId)")
        
        var matchCount = 0
        var processedCount = 0
        
        // Now process entities for our stop
        for entity in entities {
            processedCount += 1
            guard let tripUpdate = entity.tripUpdate,
                  let stopTimeUpdates = tripUpdate.stopTimeUpdate else {
                continue
            }
            
            // Filter for this specific stop - check ALL stop time updates in the trip
            // A trip can have multiple stops, and we want to find the one matching our stop
            let relevantUpdates = stopTimeUpdates.filter { update in
                // Exact string match (most reliable)
                if update.stopId == stopId {
                    return true
                }
                // Try numeric comparison (handles leading zeros like "08922" vs "8922")
                if let updateNum = Int(update.stopId), let searchNum = Int(stopId), updateNum == searchNum {
                    return true
                }
                // Check for variations like "8922-1" - must start with our ID followed by dash
                // This prevents "89" from matching "8922"
                if update.stopId.hasPrefix(stopId + "-") {
                    return true
                }
                // Check for leading zero variations - only strip LEADING zeros
                // This handles "08922" matching "8922" but prevents "89" matching "8922"
                let updateTrimmed = String(update.stopId.drop(while: { $0 == "0" }))
                let stopIdTrimmed = String(stopId.drop(while: { $0 == "0" }))
                if updateTrimmed == stopIdTrimmed && updateTrimmed == stopId {
                    return true
                }
                return false
            }
            
            // Use the first matching update (or the one with the earliest time)
            guard let relevantUpdate = relevantUpdates.first else {
                continue
            }
            
            matchCount += 1
            
            // Use arrival time if available and non-zero, otherwise departure
            var timestamp = relevantUpdate.arrival?.time
            if timestamp == nil || timestamp == 0 {
                timestamp = relevantUpdate.departure?.time
            }
            
            guard let validTimestamp = timestamp, validTimestamp > 0 else {
                print("⚠️ No valid timestamp for stop \(stopId) in entity \(entity.id)")
                continue
            }
            
            let minutesUntilArrival = Int((validTimestamp - now) / 60)
            
            // Include all future departures (GTFS-RT includes scheduled trips with updates)
            // Allow up to 2 hours in the future to catch scheduled trips
            if minutesUntilArrival >= -5 && minutesUntilArrival <= 120 {
                let routeId = tripUpdate.trip.routeId
                let routeIdForResolution = routeId
                let startDate = tripUpdate.trip.startDate
                let startTime = tripUpdate.trip.startTime
                
                // last stop id from GTFS-RT stop list (used to disambiguate start_time collisions)
                let lastStopIdRT = stopTimeUpdates
                    .max(by: { ($0.stopSequence ?? 0) < ($1.stopSequence ?? 0) })?
                    .stopId
                
                // Filter by route if routeFilter is provided
                if let routeFilter = routeFilter, !routeFilter.isEmpty {
                    let routeNumber = routeId.components(separatedBy: "-").first ?? routeId
                    let matchesFilter = routeFilter.contains { filterRoute in
                        routeId == filterRoute || routeId.hasPrefix(filterRoute + "-") || routeNumber == filterRoute
                    }
                    if !matchesFilter {
                        // Debug: Log first few mismatches
                        // if departures.count < 3 {
                        //    print("🚫 Filter skip: routeId='\(routeId)' routeNumber='\(routeNumber)' filter=\(routeFilter)")
                        // }
                        continue 
                    }
                }
                
                let routeNumber = routeId.components(separatedBy: "-").first ?? routeId
                let routeName = RouteMapper.getRouteName(for: routeId)
                
                var directionId = tripUpdate.trip.directionId
                var destination: String? = nil
                
                // PRIORITY 1: Use API-provided headsign (fastest, no JSON load)
                if let apiHeadsign = tripUpdate.trip.tripHeadsign,
                   !apiHeadsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    destination = apiHeadsign
                }
                
                // PRIORITY 2: Only do heavy resolution if API didn't provide headsign
                if destination == nil || destination?.isEmpty == true {
                    // Resolve to a static GTFS trip_id using GTFS-RT TripDescriptor fields (routeId + startTime + startDate).
                    var resolvedTripId: String? = nil
                    if let sd = startDate, let st = startTime, !sd.isEmpty, !st.isEmpty {
                        let serviceIds = ServiceByDateLoader.shared.serviceIds(for: sd)
                        for serviceId in serviceIds {
                            let candidates = TripStartIndexLoader.shared.candidates(routeId: routeIdForResolution, serviceId: serviceId, startTime: st)
                            guard !candidates.isEmpty else { continue }
                            if candidates.count == 1 {
                                resolvedTripId = candidates[0].t
                            } else if let last = lastStopIdRT,
                                      let match = candidates.first(where: { $0.l == last }) {
                                resolvedTripId = match.t
                            } else {
                                resolvedTripId = candidates[0].t
                            }
                            break
                        }
                    }
                    
                    // Use static trip data (trip_headsign + direction_id) from the resolved trip id.
                    if let resolvedTripId, let staticTrip = TripDataLoader.shared.getStaticTrip(for: resolvedTripId) {
                        if let staticDir = staticTrip.d {
                            directionId = staticDir
                        }
                        if let staticHead = staticTrip.h,
                           !staticHead.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            destination = staticHead
                        }
                        
                        // Stop-specific headsign override (when destination changes mid-trip)
                        if let override = StopHeadsignOverrideLoader.shared.overrideHeadsign(tripId: resolvedTripId, stopId: stopId),
                           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            destination = override
                        }
                    }
                }
                
                // Normalize bilingual headsigns like "Parliament ~ Parlement"
                if let dest = destination, dest.contains("~") {
                    let cleaned = dest.split(separator: "~", maxSplits: 1, omittingEmptySubsequences: true).first
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    if let cleaned, !cleaned.isEmpty {
                        destination = cleaned
                    }
                }
                
                // PRIORITY 3: Fallback to route map (least reliable / manual)
                if destination == nil || destination?.isEmpty == true {
                    destination = RouteMapper.getDestination(for: routeNumber, directionId: directionId)
                }
                
                // PRIORITY 4: Last resort cardinal naming
                if destination == nil || destination == "Destination" || destination?.isEmpty == true {
                    destination = (directionId == 0) ? "Eastbound" : "Westbound"
                }
                
                // FINAL SANITIZATION: Fix known bad headsigns (e.g., stop names used as destinations)
                if let dest = destination {
                    // Fix: "GARRY J ARMSTRONG" -> "St-Laurent" (Route 19)
                    if dest.uppercased().contains("GARRY J ARMSTRONG") {
                        if routeNumber == "19" {
                            destination = "St-Laurent"
                        } else {
                            destination = "St-Laurent" // Likely safe default for this area
                        }
                    }
                    // Fix: "Rideau Centre" -> "Rideau" (Cleaner UI)
                    else if dest.caseInsensitiveCompare("Rideau Centre") == .orderedSame {
                        destination = "Rideau"
                    }
                }
                
                let departure = Departure(
                    id: entity.id,
                    routeNumber: routeNumber,
                    routeName: routeName,
                    destination: destination ?? "Destination",
                    minutesUntilArrival: max(0, minutesUntilArrival),
                    isArrivingNow: minutesUntilArrival <= 0,
                    directionId: directionId,
                    stopId: stopId,
                    stopName: stopName
                )
                
                departures.append(departure)
                // print("✅ Found departure: \(routeName) to \(destination ?? "Unknown") in \(minutesUntilArrival) min")
            }
        }
        
        print("🔄 Processed \(processedCount) entities, found \(matchCount) matches, \(departures.count) departures")
        
        if departures.isEmpty {
             print("⚠️ No departures found for stop \(stopId).")
        }
        
        // Sort by arrival time and limit to top 5
        let sorted = departures.sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }.prefix(5).map { $0 }
        print("📊 Returning \(sorted.count) departures")
        return sorted
    }
    
    // MARK: - Mock Data
    private func getMockDepartures(for stopId: String) -> [Departure] {
        // Simulate some departures for testing the UI
        return [
            Departure(id: "1", routeNumber: "1", routeName: "Line 1", destination: "Blair", minutesUntilArrival: 2, isArrivingNow: false, directionId: 0, stopId: nil, stopName: nil),
            Departure(id: "2", routeNumber: "94", routeName: "Route 94", destination: "Hurdman", minutesUntilArrival: 5, isArrivingNow: false, directionId: 0, stopId: nil, stopName: nil),
            Departure(id: "3", routeNumber: "7", routeName: "7 Carleton", destination: "Carleton U", minutesUntilArrival: 0, isArrivingNow: true, directionId: 0, stopId: nil, stopName: nil),
            Departure(id: "4", routeNumber: "88", routeName: "Route 88", destination: "Unknown", minutesUntilArrival: 12, isArrivingNow: false, directionId: 1, stopId: nil, stopName: nil),
            Departure(id: "5", routeNumber: "1", routeName: "Line 1", destination: "Tunney's", minutesUntilArrival: 18, isArrivingNow: false, directionId: 1, stopId: nil, stopName: nil)
        ]
    }
}

enum GTFSError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case noDataForStop
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .decodingError:
            return "Failed to parse API data"
        case .noDataForStop:
            return "No departures found for this stop"
        }
    }
}
