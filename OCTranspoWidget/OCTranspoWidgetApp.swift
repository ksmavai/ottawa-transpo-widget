//
//  OCTranspoWidgetApp.swift
//  OCTranspoWidget
//
//  Created by kshitij savi mavai on 2025-12-24.
//

import SwiftUI

import BackgroundTasks
import WidgetKit


@main
struct OCTranspoWidgetApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Register the background task handler
        BackgroundUpdateManager.shared.register()
    }
    
    var body: some Scene {
        WindowGroup {
            if appState.hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(appState: appState)
            }
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .background {
                BackgroundUpdateManager.shared.scheduleAppRefresh()
            }
        }
    }
}

// Separate manager class to handle background tasks (avoids "mutating self" error in struct)
class BackgroundUpdateManager {
    static let shared = BackgroundUpdateManager()
    let backgroundTaskIdentifier = "com.myapp.octranspo.refresh"
    
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 mins
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🕒 Application: Scheduled background refresh for 15+ mins from now")
        } catch {
            print("❌ Application: Could not schedule app refresh: \(error)")
        }
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleAppRefresh()
        
        // Create an operation queue for the fetch
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        task.expirationHandler = {
            print("⚠️ Application: Background task expired")
            queue.cancelAllOperations()
        }
        
        let operation = BlockOperation {
            let semaphore = DispatchSemaphore(value: 0)
            
            Task {
                print("🔄 Application: Background Refresh task started...")
                
                let suiteName = "group.com.myapp.octranspo"
                guard let userDefaults = UserDefaults(suiteName: suiteName) else {
                    print("❌ Application: Failed to access App Group")
                    semaphore.signal()
                    return
                }
                
                // Load favorites directly
                guard let stopIds = userDefaults.array(forKey: "FavoriteStops") as? [String], !stopIds.isEmpty else {
                    print("⚠️ Application: No favorite stops to refresh")
                    task.setTaskCompleted(success: true)
                    semaphore.signal()
                    return
                }
                
                print("📋 Application: Background refresh for stops: \(stopIds)")
                
                do {
                    let selectedRoutes = userDefaults.array(forKey: "SelectedRoutes") as? [String] ?? []
                    
                    let results = try await GTFSService.shared.fetchAllDepartures(
                        for: stopIds,
                        routeFilter: selectedRoutes.isEmpty ? nil : selectedRoutes
                    )
                    
                    var allDepartures: [Departure] = []
                    for (_, departures) in results {
                        allDepartures.append(contentsOf: departures)
                    }
                    
                    if !allDepartures.isEmpty {
                        WidgetDataCache.shared.saveDepartures(allDepartures)
                        WidgetCenter.shared.reloadAllTimelines()
                        print("✅ Application: Background refresh success! Found \(allDepartures.count) departures.")
                        task.setTaskCompleted(success: true)
                    } else {
                        print("⚠️ Application: No departures found")
                        task.setTaskCompleted(success: true)
                    }
                } catch {
                    print("❌ Application: Background fetch failed: \(error)")
                    task.setTaskCompleted(success: false)
                }
                
                semaphore.signal()
            }
            
            semaphore.wait()
        }
        
        queue.addOperation(operation)
    }
}

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    @Published var selectedRoutes: [String] = []

    
    init() {
        // Load onboarding state from UserDefaults - persists across app restarts
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}
