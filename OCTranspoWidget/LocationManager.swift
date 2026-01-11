import Foundation
import CoreLocation
import Combine
import MapKit
import WidgetKit

// MARK: - App Group Location Keys
struct LocationCacheKeys {
    static let suiteName = "group.com.myapp.octranspo"
    static let latitude = "LastKnownLatitude"
    static let longitude = "LastKnownLongitude"
    static let timestamp = "LastKnownLocationTimestamp"
}

// MARK: - Location Manager for Main App
@MainActor
class AppLocationManager: NSObject, ObservableObject {
    static let shared = AppLocationManager()
    
    // ============================================
    // TEMPORARY TEST FLAG - SET TO false TO RESTORE NORMAL BEHAVIOR
    // ============================================
    private let USE_TEST_LOCATION = false  // <-- CHANGE TO false WHEN DONE TESTING
    private let TEST_LOCATION = CLLocation(
        latitude: 45.38200517165346,  // Carleton University
        longitude: -75.69883365496109
    )
    // ============================================
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        
        // If using test location, set it immediately
        if USE_TEST_LOCATION {
            currentLocation = TEST_LOCATION
            print("🧪 TEST MODE: Using fake location at Carleton University")
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Live Verification
    // The user wants "auto-updates nearest stops" as they move
    func startLiveUpdates() {
        if USE_TEST_LOCATION {
            print("🧪 TEST MODE: Skipping live updates (using fake location)")
            return
        }
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
            print("📍 AppLocationManager: Started live updates")
        } else {
             requestLocationPermission()
        }
    }
    
    func stopLiveUpdates() {
        if USE_TEST_LOCATION { return }
        locationManager.stopUpdatingLocation()
        print("📍 AppLocationManager: Stopped live updates")
    }
    
    func getCurrentLocation() async -> CLLocation? {
        // TEST MODE: Return fake location immediately
        if USE_TEST_LOCATION {
            print("🧪 TEST MODE: Returning Carleton University location")
            return TEST_LOCATION
        }
        
        // ORIGINAL LOGIC BELOW (unchanged)
        // If we already have a very recent location (from live updates), return it
        if let location = currentLocation,
           location.timestamp.timeIntervalSinceNow > -5 {
            return location
        }
        
        // Otherwise request one
        return await withCheckedContinuation { continuation in
            // Only set continuation if none is pending
            guard locationContinuation == nil else {
                continuation.resume(returning: currentLocation)
                return
            }
            
            locationContinuation = continuation
            
            // Set timeout - but don't resume directly, just nil out the continuation
            // The delegate methods will check for nil before resuming
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                // If continuation is still set (not yet handled), resume with nil
                if let cont = locationContinuation {
                    locationContinuation = nil
                    cont.resume(returning: nil)
                }
            }
            
            locationManager.requestLocation()
        }
    }
}

extension AppLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.first {
                currentLocation = location
                locationError = nil
                
                // Save location to App Group for widget access
                saveLocationToAppGroup(location)
            }
            
            if let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(returning: currentLocation)
            }
        }
    }
    
    // MARK: - App Group Location Caching
    private func saveLocationToAppGroup(_ location: CLLocation) {
        guard let userDefaults = UserDefaults(suiteName: LocationCacheKeys.suiteName) else {
            print("❌ LocationManager: Cannot access App Group")
            return
        }
        
        userDefaults.set(location.coordinate.latitude, forKey: LocationCacheKeys.latitude)
        userDefaults.set(location.coordinate.longitude, forKey: LocationCacheKeys.longitude)
        userDefaults.set(Date().timeIntervalSince1970, forKey: LocationCacheKeys.timestamp)
        userDefaults.synchronize() // Force write to disk
        print("📍 LocationManager: Saved location to App Group for widget")
        
        // Tell widgets to reload with new location
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = error.localizedDescription
            print("Location error: \(error.localizedDescription)")
            
            if let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(returning: nil)
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
}

