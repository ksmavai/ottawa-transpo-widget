import Foundation
import SwiftUI
import WidgetKit

// MARK: - Stop Manager
class StopManager: ObservableObject {
    static let shared = StopManager()
    
    private let userDefaults: UserDefaults?
    private let favoriteStopsKey = "FavoriteStops"
    
    @Published var favoriteStops: [String] = []
    
    private init() {
        userDefaults = UserDefaults(suiteName: "group.com.myapp.octranspo")
        loadStops()
    }
    
    func loadStops() {
        guard let userDefaults = userDefaults else { return }
        
        if let stops = userDefaults.array(forKey: favoriteStopsKey) as? [String] {
            favoriteStops = stops
        } else {
            // Default stops
            favoriteStops = ["8922", "5813"]
            saveStops()
        }
    }
    
    func saveStops() {
        guard let userDefaults = userDefaults else { return }
        userDefaults.set(favoriteStops, forKey: favoriteStopsKey)
        // Reload widgets when stops are saved
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func addStop(_ stopId: String) {
        let trimmed = stopId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !favoriteStops.contains(trimmed) else { return }
        favoriteStops.append(trimmed)
        saveStops()
    }
    
    func removeStop(at index: Int) {
        guard index < favoriteStops.count else { return }
        favoriteStops.remove(at: index)
        saveStops()
    }
    
    func updateStop(at index: Int, with newStopId: String) {
        let trimmed = newStopId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, index < favoriteStops.count else { return }
        favoriteStops[index] = trimmed
        saveStops()
    }
    
    func moveStop(from source: IndexSet, to destination: Int) {
        favoriteStops.move(fromOffsets: source, toOffset: destination)
        saveStops()
    }
}

