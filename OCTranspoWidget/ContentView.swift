//
//  ContentView.swift
//  OCTranspoWidget
//
//  Created by kshitij savi mavai on 2025-12-24.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var stopManager = StopManager.shared
    @State private var selectedTab: TabSelection = .departures
    
    enum TabSelection {
        case departures
        case widget
        case settings
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main Content
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .departures:
                        DeparturesView()
                    case .widget:
                        WidgetView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(height: geometry.size.height - 25) // Reserve space for tab bar
                
                // Custom Bottom Navigation - Fixed height, positioned lower
                CustomTabBar(selectedTab: $selectedTab)
                    .frame(height: 25)
            }
        }
        .onAppear {
            stopManager.loadStops()
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.TabSelection
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "calendar",
                    label: "Departures",
                    isSelected: selectedTab == .departures,
                    action: { selectedTab = .departures }
                )
                
                TabBarButton(
                    icon: "square.grid.2x2",
                    label: "Widget",
                    isSelected: selectedTab == .widget,
                    action: { selectedTab = .widget }
                )
                
                TabBarButton(
                    icon: "gearshape.fill",
                    label: "Settings",
                    isSelected: selectedTab == .settings,
                    action: { selectedTab = .settings }
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 2)
            .padding(.bottom, 4) // Safe area padding
            .background(Color(.systemBackground))
        }
        .frame(height: 25) // Fixed height
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? Color(red: 1.0, green: 0.03, blue: 0.04) : Color.gray)
                
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? Color(red: 1.0, green: 0.03, blue: 0.04) : Color.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    ContentView()
}
