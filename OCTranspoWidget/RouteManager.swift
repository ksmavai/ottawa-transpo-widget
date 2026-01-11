import Foundation
import WidgetKit

// MARK: - Route Manager
class RouteManager: ObservableObject {
    static let shared = RouteManager()
    
    private let userDefaults: UserDefaults?
    private let selectedRoutesKey = "SelectedRoutes"

    
    @Published var selectedRoutes: [String] = []
    
    private init() {
        userDefaults = UserDefaults(suiteName: "group.com.myapp.octranspo")
        loadRoutes()
    }
    
    func loadRoutes() {
        guard let userDefaults = userDefaults else { return }
        
        if let routes = userDefaults.array(forKey: selectedRoutesKey) as? [String] {
            selectedRoutes = routes
        }
    }
    
    func saveRoutes() {
        guard let userDefaults = userDefaults else { return }
        userDefaults.set(selectedRoutes, forKey: selectedRoutesKey)
        // Reload widgets when routes are saved
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func setRoutes(_ routes: [String]) {
        selectedRoutes = routes
        saveRoutes()
    }
    
    func addRoute(_ route: String) {
        guard !selectedRoutes.contains(route) else { return }
        selectedRoutes.append(route)
        saveRoutes()
    }
    
    func removeRoute(_ route: String) {
        selectedRoutes.removeAll { $0 == route }
        saveRoutes()
    }
}

