import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var settingsView: SettingsSubView = .main
    @State private var dragOffset: CGFloat = 0
    
    enum SettingsSubView {
        case main
        case theme
        case routes
        case about
    }
    
    var body: some View {
        ZStack {
            // Main settings (always present as background)
            MainSettingsView(onNavigate: { view in
                withAnimation(.easeOut(duration: 0.25)) {
                    settingsView = view
                }
            })
            .zIndex(0)
            
            // Sub-views slide in from right
            if settingsView == .theme {
                ThemeView(onBack: { goBack() })
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
                    .offset(x: dragOffset)
                    .gesture(swipeBackGesture)
            }
            
            if settingsView == .routes {
                RoutesEditorView(onBack: { goBack() })
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
                    .offset(x: dragOffset)
                    .gesture(swipeBackGesture)
            }
            
            if settingsView == .about {
                AboutView(onBack: { goBack() })
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
                    .offset(x: dragOffset)
                    .gesture(swipeBackGesture)
            }
        }
    }
    
    private var swipeBackGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow swiping from left edge (first 50 points) and to the right
                if value.startLocation.x < 50 && value.translation.width > 0 {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                // If swiped more than 100 points or with enough velocity, go back
                if dragOffset > 100 || value.velocity.width > 500 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = UIScreen.main.bounds.width
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        dragOffset = 0
                        settingsView = .main
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = 0
                    }
                }
            }
    }
    
    private func goBack() {
        withAnimation(.easeOut(duration: 0.25)) {
            settingsView = .main
        }
    }
}

struct MainSettingsView: View {
    let onNavigate: (SettingsView.SettingsSubView) -> Void
    @ObservedObject private var routeManager = RouteManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Title - Matching Widget Themes exactly
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Add invisible subtitle to match Widget Themes spacing
                    Text("")
                        .font(.system(size: 18))
                        .foregroundColor(.clear)
                        .opacity(0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 25)
                .padding(.bottom, 24)
                .ignoresSafeArea(.container, edges: .top)
                
                VStack(spacing: 24) {
                    // Routes Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROUTES")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        
                        Button(action: {
                            HapticFeedback.medium()
                            onNavigate(.routes)
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.orange)
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: "bus.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Edit Routes")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(routeManager.selectedRoutes.count)")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            .padding(.leading, 20)
                            .padding(.trailing, 20)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APPEARANCE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        
                        Button(action: {
                            HapticFeedback.medium()
                            onNavigate(.theme)
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color(red: 1.0, green: 0.03, blue: 0.04))
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: "paintpalette.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Theme")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            .padding(.leading, 20)
                            .padding(.trailing, 20)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABOUT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            Button(action: {
                                HapticFeedback.medium()
                                onNavigate(.about)
                            }) {
                                HStack(alignment: .center, spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(Color(.systemGray))
                                            .frame(width: 28, height: 28)
                                        
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("About")
                                        .font(.system(size: 18))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 20)
                                .padding(.leading, 20)
                                .padding(.trailing, 20)
                                .background(Color(.secondarySystemGroupedBackground))
                            }
                            
                            Divider()
                                .padding(.leading, 20)
                            
                            HStack(alignment: .center, spacing: 12) {
                                Text("Version")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("1.0.0")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            .padding(.leading, 20)
                            .padding(.trailing, 20)
                            .background(Color(.secondarySystemGroupedBackground))
                        }
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 120) // Space for bottom tab bar
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct ThemeView: View {
    let onBack: () -> Void
    // App Theme (Local)
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Settings")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    
                    Text("Theme")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                VStack(spacing: 32) {
                    // App Appearance Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("APP APPEARANCE")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            // Dark Theme
                            Button(action: {
                                HapticFeedback.medium()
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                    windowScene.windows.first?.overrideUserInterfaceStyle = .dark
                                }
                                isDarkMode = true
                            }) {
                                HStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.black)
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: "moon.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Dark Mode")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if isDarkMode {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                                    }
                                }
                                .padding(16)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                            }
                            
                            // Light Theme
                            Button(action: {
                                HapticFeedback.medium()
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                    windowScene.windows.first?.overrideUserInterfaceStyle = .light
                                }
                                isDarkMode = false
                            }) {
                                HStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.white)
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        
                                        Image(systemName: "sun.max.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.black)
                                    }
                                    
                                    Text("Light Mode")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if !isDarkMode {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                                    }
                                }
                                .padding(16)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 50)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct AboutView: View {
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header - Matching Departures header exactly
                VStack(alignment: .leading, spacing: 4) {
                    // Back button positioned to align with title
                    Button(action: {
                        HapticFeedback.light()
                        onBack()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Settings")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    
                    Text("About")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Add invisible subtitle to match Departures spacing
                    Text("")
                        .font(.system(size: 18))
                        .foregroundColor(.clear)
                        .opacity(0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                VStack(spacing: 16) {
                    // App Icon and Name
                    VStack(spacing: 12) {
                        Image("AppLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 96, height: 96)
                                .cornerRadius(22)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        VStack(spacing: 4) {
                            Text("Ottawa Transpo Widget")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Version 1.0.0")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("We're the same, just a little less crappier, somewhat. Track your favorite OCTranspo routes with real-time departures and beautiful departure board widgets.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    
                    // Info Cards
                    VStack(spacing: 12) {
                        InfoCard(title: "Data Source", value: "OC Transpo API")
                        
                        // Made With - clickable link
                        Button(action: {
                            if let url = URL(string: "https://ksmavai.github.io") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Made With")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Text("❤️ by")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("kshitij")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Routes Editor View
struct RoutesEditorView: View {
    let onBack: () -> Void
    @ObservedObject private var routeManager = RouteManager.shared
    @State private var expandedDropdown = false
    
    let availableRoutes = [
        ("E1", "Downtown / Blair (Express)"),
        ("5", "Elmvale / Rideau"),
        ("6", "Greenboro / Rockcliffe"),
        ("7", "Carleton / St-Laurent"),
        ("8", "Gatineau / Dow's Lake"),
        ("9", "Hurdman / Rideau"),
        ("10", "Hurdman / Main"),
        ("11", "Lincoln Fields / Parliament"),
        ("12", "Tunney's Pasture / Blair"),
        ("14", "St-Laurent / Tunney's Pasture"),
        ("15", "Blair / Parliament"),
        ("17", "Wateridge / Parliament"),
        ("18", "St-Laurent / Billings Bridge"),
        ("19", "Hurdman / Parliament"),
        ("20", "St-Laurent / Rideau"),
        ("21", "Blair / Canotek"),
        ("24", "St-Laurent / Chapel Hill"),
        ("25", "Wateridge / Blair"),
        ("30", "Millennium / Blair"),
        ("31", "Place d'Orléans / Tenth Line"),
        ("32", "Chapel Hill / Blair"),
        ("34", "Chapel Hill / Blair"),
        ("35", "Avalon / Blair"),
        ("38", "Trim / Blair"),
        ("39", "Millennium / Blair"),
        ("40", "Greenboro / St-Laurent"),
        ("41", "St-Laurent / Billings Bridge"),
        ("44", "Billings Bridge / Hurdman"),
        ("45", "Hospital / Hurdman"),
        ("48", "Carleton / Hurdman"),
        ("49", "Hurdman / Elmvale"),
        ("51", "Tunney's Pasture / Britannia"),
        ("53", "Tunney's Pasture / Baseline"),
        ("56", "Civic / Tunney's Pasture"),
        ("57", "Carling Campus / Tunney's Pasture"),
        ("60", "Cope / Terry Fox"),
        ("61", "Stittsville / Terry Fox"),
        ("62", "Stittsville / Terry Fox"),
        ("63", "Briarbrook / Tunney's Pasture"),
        ("66", "Innovation / Tunney's Pasture"),
        ("67", "Cope / Terry Fox"),
        ("68", "Terry Fox / Baseline"),
        ("70", "Fallowfield / Limebank"),
        ("73", "Fallowfield / Limebank"),
        ("74", "Limebank / Tunney's Pasture"),
        ("75", "Cambrian / Tunney's Pasture"),
        ("80", "Tunney's Pasture / Barrhaven Centre"),
        ("81", "Tunney's Pasture / Bayshore"),
        ("82", "Lincoln Fields / Baseline"),
        ("84", "Baseline / Centrepointe"),
        ("85", "Bayshore / Lees"),
        ("86", "Tunney's Pasture / Antares"),
        ("87", "Tunney's Pasture / Baseline"),
        ("88", "Bayshore / Hurdman"),
        ("90", "Greenboro / Hurdman"),
        ("92", "Greenboro / Walkley"),
        ("93", "Leitrim / Rotary"),
        ("94", "Leitrim / Dun Skipper"),
        ("98", "Hawthorne / Hurdman"),
        ("99", "Barrhaven Centre / Limebank"),
        ("105", "Airport / St-Laurent"),
        ("111", "Carleton / Baseline"),
        ("112", "Billings Bridge / Baseline")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Button(action: {
                    HapticFeedback.light()
                    onBack()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Settings")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                }
                .padding(.top, 24)
                .padding(.bottom, 12)
                
                Text("Edit Routes")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Swipe left to delete a route")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Selected Routes - with swipe-to-delete
                    if !routeManager.selectedRoutes.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("SELECTED ROUTES")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(routeManager.selectedRoutes.enumerated()), id: \.element) { index, route in
                                    SwipeToDeleteRow(
                                        route: route,
                                        routeDescription: availableRoutes.first(where: { $0.0 == route })?.1,
                                        onDelete: {
                                            HapticFeedback.medium()
                                            withAnimation {
                                                routeManager.removeRoute(route)
                                            }
                                        }
                                    )
                                    
                                    if index < routeManager.selectedRoutes.count - 1 {
                                        Divider()
                                            .padding(.leading, 16)
                                            .background(Color(.secondarySystemGroupedBackground))
                                    }
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Empty state
                    if routeManager.selectedRoutes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bus")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No routes selected")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                    // Add Route Dropdown
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ADD NEW ROUTE")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            // Add Route Button
                            Button(action: {
                                HapticFeedback.selection()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedDropdown.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                                    
                                    Text("Add Route")
                                        .font(.system(size: 18))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: expandedDropdown ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                            }
                            
                            // Route Dropdown - scrollable
                            if expandedDropdown {
                                Divider()
                                
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(availableRoutes.filter { route in
                                            !routeManager.selectedRoutes.contains(route.0)
                                        }, id: \.0) { route in
                                            Button(action: {
                                                HapticFeedback.medium()
                                                withAnimation {
                                                    routeManager.addRoute(route.0)
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Route \(route.0)")
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                    
                                                    Text(route.1)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(16)
                                            }
                                            
                                            if route.0 != availableRoutes.filter({ !routeManager.selectedRoutes.contains($0.0) }).last?.0 {
                                                Divider()
                                                    .padding(.leading, 16)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Swipe to Delete Row (All Red Fill Animation)
struct SwipeToDeleteRow: View {
    let route: String
    let routeDescription: String?
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @State private var isDeleting = false
    @State private var rowHeight: CGFloat = 70
    
    private let deleteButtonWidth: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Red background (fills entire row when deleting)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: isDeleting ? geometry.size.width : (offset < 0 ? -offset : 0))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Delete button (only visible when swiping, not when just added)
                if offset < 0 && !isDeleting {
                    HStack {
                        Spacer()
                        Button(action: {
                            triggerDelete(geometry: geometry)
                        }) {
                            Text("Delete")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: deleteButtonWidth, height: geometry.size.height)
                        }
                    }
                }
                
                // Main content
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Route \(route)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let description = routeDescription {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color(.secondarySystemGroupedBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDeleting {
                                if value.translation.width < 0 {
                                    offset = max(value.translation.width, -deleteButtonWidth)
                                } else if isSwiping {
                                    offset = min(0, -deleteButtonWidth + value.translation.width)
                                }
                            }
                        }
                        .onEnded { value in
                            if !isDeleting {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    if offset < -deleteButtonWidth / 2 {
                                        offset = -deleteButtonWidth
                                        isSwiping = true
                                    } else {
                                        offset = 0
                                        isSwiping = false
                                    }
                                }
                            }
                        }
                )
                .onTapGesture {
                    if isSwiping && !isDeleting {
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                            isSwiping = false
                        }
                    }
                }
            }
        }
        .frame(height: isDeleting ? 0 : 70)
        .clipped()
        .animation(.easeOut(duration: 0.3), value: isDeleting)
    }
    
    private func triggerDelete(geometry: GeometryProxy) {
        // First, fill red and slide content off
        withAnimation(.easeOut(duration: 0.2)) {
            offset = -geometry.size.width
            isDeleting = true
        }
        // Then collapse and delete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDelete()
        }
    }
}

/* BACKUP: Simple Delete Button Version (say "bring delete backup" to restore)
// MARK: - Swipe to Delete Row (Simple Version)
struct SwipeToDeleteRow: View {
    let route: String
    let routeDescription: String?
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    private let deleteButtonWidth: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Delete button (only visible when swiping)
                if offset < 0 {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = -geometry.size.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDelete()
                            }
                        }) {
                            Text("Delete")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: deleteButtonWidth, height: geometry.size.height)
                        }
                        .background(Color.red)
                    }
                }
                
                // Main content
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Route \(route)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let description = routeDescription {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color(.secondarySystemGroupedBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -deleteButtonWidth)
                            } else if isSwiping {
                                offset = min(0, -deleteButtonWidth + value.translation.width)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                if offset < -deleteButtonWidth / 2 {
                                    offset = -deleteButtonWidth
                                    isSwiping = true
                                } else {
                                    offset = 0
                                    isSwiping = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if isSwiping {
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                            isSwiping = false
                        }
                    }
                }
            }
        }
        .frame(height: 70)
    }
}
*/

struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
