import SwiftUI
import CoreLocation
import WidgetKit

// MARK: - View Model Models
struct RouteStopItem: Identifiable {
    let id: String // Unique ID: e.g. "428-Route6-Dir0"
    let stopId: String
    let stopCode: String
    let stopName: String
    let routeNumber: String
    let destination: String
    let distance: Double
    let departures: [Departure]
    let directionId: Int
}

struct DeparturesView: View {
    @StateObject private var viewModel = DeparturesViewModel()
    @StateObject private var locationManager = AppLocationManager.shared
    
    // TWO Lists of ITEMS (Page 0 = Outbound/Dir 0, Page 1 = Inbound/Dir 1)
    @State private var outboundItems: [RouteStopItem] = [] // Dir 0
    @State private var inboundItems: [RouteStopItem] = []  // Dir 1
    
    @State private var currentDirectionPage: Int = 0 // 0 = outbound, 1 = inbound
    @State private var refreshTimer: Timer?
    @State private var isLoading = true // Start true to show loading on launch
    @State private var hasLoadedOnce = false // Track if we've ever loaded data
    
    var body: some View {
        ZStack {
            // Background - Respects system light/dark mode
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title Section (Fixed Header)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Departures")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(currentDirectionPage == 0 ? "Direction 0" : "Direction 1")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                            .animation(.none, value: currentDirectionPage)
                        
                        Text("• Swipe to change")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16) // Reduced from 60, let SafeArea handle the rest
                .padding(.bottom, 16)
                .background(Color(UIColor.systemBackground)) // Header Background - dynamic
                
                // Content area
                ZStack {
                    if RouteManager.shared.selectedRoutes.isEmpty {
                        // Empty State: No Routes - wrapped in ScrollView for pull-to-refresh
                        ScrollView {
                            EmptyStateView(
                                icon: "bus",
                                title: "No Routes Selected",
                                message: "Select routes in Settings to see departures."
                            )
                            .frame(maxWidth: .infinity, minHeight: 400)
                        }
                        .refreshable {
                            await loadDepartures()
                        }
                    } else if outboundItems.isEmpty && inboundItems.isEmpty && !isLoading && hasLoadedOnce {
                        // Empty State: No Stops/Permission - wrapped in ScrollView for pull-to-refresh
                        ScrollView {
                            if locationManager.authorizationStatus != .authorizedWhenInUse && locationManager.authorizationStatus != .authorizedAlways {
                                LocationPermissionWarning()
                                    .frame(maxWidth: .infinity, minHeight: 400)
                            } else {
                                // No Stops Found Error
                                NoStopsErrorView(
                                    debugStatus: StopDataLoader.shared.debugStatus,
                                    location: locationManager.currentLocation,
                                    routes: RouteManager.shared.selectedRoutes
                                )
                                .frame(maxWidth: .infinity, minHeight: 400)
                            }
                        }
                        .refreshable {
                            await loadDepartures()
                        }
                    } else {
                        // Main Content: 2-Page Swipe
                        TabView(selection: $currentDirectionPage) {
                            // Page 0: Direction 0
                            DirectionPageView(items: outboundItems, directionName: "Direction 0")
                                .tag(0)
                            
                            // Page 1: Direction 1
                            DirectionPageView(items: inboundItems, directionName: "Direction 1")
                                .tag(1)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        
                        // Page indicator dots
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(currentDirectionPage == 0 ? Color(red: 1.0, green: 0.03, blue: 0.04) : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Circle()
                                    .fill(currentDirectionPage == 1 ? Color(red: 1.0, green: 0.03, blue: 0.04) : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    
                    // Loading Overlay
                    if isLoading && outboundItems.isEmpty && inboundItems.isEmpty {
                        Color(UIColor.systemBackground).opacity(0.9)
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            }
            // Removed .ignoresSafeArea(.container, edges: .top) to let VStack sit below status bar
        }
        .onAppear {
            startAutoRefresh()
            Task { await loadDepartures() }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .refreshable {
            await loadDepartures()
        }
    }
    
    private func loadDepartures() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }
        
        guard let location = await locationManager.getCurrentLocation() else { return }
        let selectedRoutes = RouteManager.shared.selectedRoutes
        guard !selectedRoutes.isEmpty else { return }
        
        // 1) For each selected route, pick a small set of closest stops that serve it.
        // We do this per-route so BOTH directions have a chance to appear (often opposite sides of the street).
        let perRouteLimit = max(6, min(12, 60 / max(selectedRoutes.count, 1)))
        var routeCandidates: [String: [ParsedStopInfo]] = [:]
        var uniqueStopIds: Set<String> = []
        
        for route in selectedRoutes {
            let stops = StopDataLoader.shared.findClosestStopsForRoute(route, from: location, limit: perRouteLimit)
            routeCandidates[route] = stops
            for stop in stops {
                let internalId = StopDataLoader.shared.getGTFSId(for: stop.id) ?? stop.id
                uniqueStopIds.insert(internalId)
            }
        }
        
        // 2) Batch fetch departures for all unique candidate stops (filtered to selected routes for performance).
        var batchResults: [String: [Departure]] = [:]
        if !uniqueStopIds.isEmpty {
            do {
                batchResults = try await GTFSService.shared.fetchAllDepartures(
                    for: Array(uniqueStopIds),
                    routeFilter: selectedRoutes
                )
            } catch {
                print("Error loading batch departures: \(error)")
            }
        }
        
        // 3) For each route + direction, find the nearest stop that has at least one matching departure,
        // then keep the earliest departures at that stop.
        func buildItem(route: String, direction: Int) -> RouteStopItem? {
            guard let stops = routeCandidates[route], !stops.isEmpty else { return nil }
            
            for stop in stops {
                let internalId = StopDataLoader.shared.getGTFSId(for: stop.id) ?? stop.id
                let allDeps = batchResults[internalId] ?? []
                
                let matching = allDeps
                    .filter { $0.routeNumber == route && $0.directionId == direction }
                    .sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }
                
                guard let first = matching.first else { continue }
                
                let dist = location.distance(from: CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude))
                let topDepartures = Array(matching.prefix(3))
                
                return RouteStopItem(
                    id: "\(internalId)-\(route)-\(direction)",
                    stopId: internalId,
                    stopCode: stop.id,
                    stopName: stop.name,
                    routeNumber: route,
                    destination: first.destination,
                    distance: dist,
                    departures: topDepartures,
                    directionId: direction
                )
            }
            
            return nil
        }
        
        var newOutbound: [RouteStopItem] = []
        var newInbound: [RouteStopItem] = []
        
        for route in selectedRoutes {
            if let outbound = buildItem(route: route, direction: 0) {
                newOutbound.append(outbound)
            }
            if let inbound = buildItem(route: route, direction: 1) {
                newInbound.append(inbound)
            }
        }
        
        // Sort: Primary by Distance, Secondary by Route Number
        let sorter: (RouteStopItem, RouteStopItem) -> Bool = { a, b in
            if abs(a.distance - b.distance) > 10 { // If distance diff > 10m, use distance
                return a.distance < b.distance
            }
            return a.routeNumber.localizedStandardCompare(b.routeNumber) == .orderedAscending
        }
        
        newOutbound.sort(by: sorter)
        newInbound.sort(by: sorter)
        
        await MainActor.run {
            self.outboundItems = newOutbound
            self.inboundItems = newInbound
            
            // Save all departures to cache for widget to read
            // IMPORTANT: Copy the stopName from RouteStopItem to each Departure
            var allDepartures: [Departure] = []
            for item in newOutbound + newInbound {
                for dep in item.departures {
                    let depWithStopName = Departure(
                        id: dep.id,
                        routeNumber: dep.routeNumber,
                        routeName: dep.routeName,
                        destination: dep.destination,
                        minutesUntilArrival: dep.minutesUntilArrival,
                        isArrivingNow: dep.isArrivingNow,
                        directionId: dep.directionId,
                        stopId: item.stopId,
                        stopName: item.stopName
                    )
                    allDepartures.append(depWithStopName)
                }
            }
            WidgetDataCache.shared.saveDepartures(allDepartures)
            
            // Trigger widget to reload with new data
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { await loadDepartures() }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Direction Page Component
struct DirectionPageView: View {
    let items: [RouteStopItem]
    let directionName: String
    
    var body: some View {
        if items.isEmpty {
            VStack {
                Spacer()
                // Fallback to a reliable SF Symbol; double-decker is unavailable on some OS builds
                Image(systemName: "bus.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                Text("No \(directionName) Departures")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text("Check the other direction or adjust filters.")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 16) { // Spacing between distinct route cards
                    ForEach(items) { item in
                        RouteStopCard(item: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - New Route Card Component
struct RouteStopCard: View {
    let item: RouteStopItem
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 1. Top Section: Route Bubble + Destination
            HStack(spacing: 16) {
                // Red Route Bubble
                Text(item.routeNumber)
                    .font(.system(size: 32, weight: .bold)) // Large Route Number
                    .foregroundColor(.white)
                    .frame(minWidth: 80)
                    .frame(height: 50)
                    .background(Color(red: 1.0, green: 0.03, blue: 0.04))
                    .cornerRadius(12)
                
                // Destination
                Text(item.destination)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // 2. Middle Section: Stop Name + Code
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)
                .padding(.vertical, 16)
            
            HStack(alignment: .center) {
                Text(item.stopName.uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Stop Code Pill
                Text(item.stopCode)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // 3. Bottom Section: Timing Bubbles (fixed width for 1, 2, or 3 bubbles)
            HStack(spacing: 10) {
                // Show max 3 departures - always fill the same total width
                ForEach(item.departures.prefix(3)) { dep in
                    DepartureBubble(departure: dep)
                }
                
                // Add invisible spacer bubbles to maintain consistent total width
                ForEach(0..<(3 - min(item.departures.count, 3)), id: \.self) { _ in
                    Color.clear
                        .frame(minWidth: 70, maxWidth: .infinity)
                        .frame(height: 70)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct DepartureBubble: View {
    let departure: Departure
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(departure.minutesUntilArrival)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("min")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70, maxWidth: .infinity)
        .frame(height: 70)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Subviews & Components

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct LocationPermissionWarning: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Location Permission Required")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Please enable location access to find nearby stops.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding()
            .background(Color(red: 1.0, green: 0.03, blue: 0.04))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct NoStopsErrorView: View {
    let debugStatus: String
    let location: CLLocation?
    let routes: [String]

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Stops Found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Text("We couldn't find any nearby stops serving your selected routes.")
                 .multilineTextAlignment(.center)
                 .foregroundColor(.secondary)
                 .padding(.horizontal)

            // Debug Info
            VStack(spacing: 4) {
                Text("Debug: \(debugStatus)")
                if let loc = location {
                    Text("Loc: \(String(format: "%.4f", loc.coordinate.latitude)), \(String(format: "%.4f", loc.coordinate.longitude))")
                }
                Text("Routes: \(routes.joined(separator: ", "))")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.top)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

class DeparturesViewModel: ObservableObject {
    // Placeholder for future logic if needed
}
