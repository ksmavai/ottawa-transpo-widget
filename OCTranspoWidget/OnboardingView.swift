import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var currentScreen: OnboardingScreen = .welcome
    
    enum OnboardingScreen {
        case welcome
        case routes
        case location
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Group {
                switch currentScreen {
                case .welcome:
                    WelcomeScreen(onNext: {
                        withAnimation {
                            currentScreen = .routes
                        }
                    })
                case .routes:
                    RouteSelectionScreen(
                        onNext: { routes in
                            appState.selectedRoutes = routes
                            // Save to RouteManager for persistence
                            RouteManager.shared.setRoutes(routes)
                            withAnimation {
                                currentScreen = .location
                            }
                        }
                    )
                case .location:
                    LocationPermissionScreen(onNext: {
                        appState.hasCompletedOnboarding = true
                    })
                }
            }
            .transition(.opacity)
        }
    }
}

struct WelcomeScreen: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 1.0, green: 0.03, blue: 0.04))
                        .frame(width: 112, height: 112)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "bus.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }
                
                // Title - CENTERED
                Text("Ottawa Transpo Widget")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Description
                Text("We're the same, just a little less crappier, somewhat")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                HapticFeedback.medium()
                onNext()
            }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 1.0, green: 0.03, blue: 0.04))
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 80)
        }
    }
}

struct RouteSelectionScreen: View {
    let onNext: (([String]) -> Void)
    @State private var selectedRoutes: [String] = []
    @State private var showDropdown = false
    
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
        ("13", "Gatineau / Tunney's Pasture"),
        ("14", "St-Laurent / Tunney's Pasture"),
        ("15", "Blair / Parliament"),
        ("17", "Wateridge / Parliament"),
        ("18", "St-Laurent / Billings Bridge"),
        ("19", "Hurdman / Parliament"),
        ("20", "St-Laurent / Rideau"),
        ("21", "Blair / Canotek"),
        ("23", "Blair / Rothwell Heights"),
        ("24", "St-Laurent / Chapel Hill"),
        ("25", "Wateridge / Blair"),
        ("26", "Blair / Pineview"),
        ("30", "Millennium / Blair"),
        ("31", "Place d'Orléans / Tenth Line"),
        ("32", "Chapel Hill / Blair"),
        ("33", "Portobello / Place d'Orléans"),
        ("34", "Chapel Hill / Blair"),
        ("35", "Avalon / Blair"),
        ("36", "Place d'Orléans / Innes"),
        ("38", "Trim / Blair"),
        ("39", "Millennium / Blair"),
        ("40", "Greenboro / St-Laurent"),
        ("41", "St-Laurent / Billings Bridge"),
        ("42", "Blair / Hurdman"),
        ("43", "Karsh / Greenboro"),
        ("44", "Billings Bridge / Hurdman"),
        ("45", "Hospital / Hurdman"),
        ("47", "Hawthorne / St-Laurent"),
        ("48", "Carleton / Hurdman"),
        ("49", "Hurdman / Elmvale"),
        ("51", "Tunney's Pasture / Britannia"),
        ("53", "Tunney's Pasture / Baseline"),
        ("56", "Civic / Tunney's Pasture"),
        ("57", "Carling Campus / Tunney's Pasture"),
        ("58", "Carling Campus / Tunney's Pasture"),
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
        ("110", "Innovation / Limebank"),
        ("111", "Carleton / Baseline"),
        ("112", "Billings Bridge / Baseline"),
        ("116", "Greenboro / Baseline"),
        ("117", "Greenboro / Baseline"),
        ("138", "Place d'Orléans / Hiawatha"),
        ("139", "Place d'Orléans / Petrie Island"),
        ("153", "Lincoln Fields / Carlingwood Mall"),
        ("158", "Bayshore / Haanel"),
        ("161", "Terry Fox / Bridlewood"),
        ("162", "Terry Fox / Canadian Tire Centre"),
        ("163", "Terry Fox / Kittawake"),
        ("165", "Innovation / Terry Fox"),
        ("168", "Terry Fox / Bridlewood"),
        ("173", "Barrhaven Centre / CitiGate"),
        ("187", "Baseline / Amberwood"),
        ("189", "Baseline / Colonnade"),
        ("197", "Uplands / Greenboro"),
        ("198", "Greenboro / Limebank")
    ]
    
    var hasSelectedRoutes: Bool {
        !selectedRoutes.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Select your routes")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Swipe left to remove a route")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 16)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Selected Routes - with swipe-to-delete
                    if !selectedRoutes.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("SELECTED ROUTES")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(selectedRoutes.enumerated()), id: \.element) { index, route in
                                    OnboardingSwipeRow(
                                        route: route,
                                        routeDescription: availableRoutes.first(where: { $0.0 == route })?.1,
                                        onDelete: {
                                            HapticFeedback.medium()
                                            withAnimation {
                                                selectedRoutes.removeAll { $0 == route }
                                            }
                                        }
                                    )
                                    
                                    if index < selectedRoutes.count - 1 {
                                        Divider()
                                            .background(Color.gray.opacity(0.3))
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(white: 0.15))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Add Route Dropdown
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ADD NEW ROUTE")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            // Add Route Button
                            Button(action: {
                                HapticFeedback.selection()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showDropdown.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Color(red: 1.0, green: 0.03, blue: 0.04))
                                    
                                    Text("Add Route")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: showDropdown ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                .padding(16)
                            }
                            
                            // Route Dropdown - scrollable
                            if showDropdown {
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(availableRoutes.filter { route in
                                            !selectedRoutes.contains(route.0)
                                        }, id: \.0) { route in
                                            Button(action: {
                                                HapticFeedback.medium()
                                                withAnimation {
                                                    selectedRoutes.append(route.0)
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Route \(route.0)")
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    
                                                    Text(route.1)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.gray)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(16)
                                            }
                                            
                                            if route.0 != availableRoutes.filter({ !selectedRoutes.contains($0.0) }).last?.0 {
                                                Divider()
                                                    .background(Color.gray.opacity(0.3))
                                                    .padding(.leading, 16)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
                            }
                        }
                        .background(Color(white: 0.11))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            
            // Continue Button
            Button(action: {
                HapticFeedback.medium()
                onNext(selectedRoutes)
            }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(hasSelectedRoutes ? Color(red: 1.0, green: 0.03, blue: 0.04) : Color.gray.opacity(0.3))
                    .cornerRadius(14)
            }
            .disabled(!hasSelectedRoutes)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.black)
    }
}

// MARK: - Onboarding Swipe to Delete Row (All Red Fill Animation)
struct OnboardingSwipeRow: View {
    let route: String
    let routeDescription: String?
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @State private var isDeleting = false
    
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
                            .foregroundColor(.white)
                        
                        if let description = routeDescription {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color(white: 0.15))
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
        withAnimation(.easeOut(duration: 0.2)) {
            offset = -geometry.size.width
            isDeleting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDelete()
        }
    }
}

struct LocationPermissionScreen: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Location Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 1.0, green: 0.03, blue: 0.04))
                        .frame(width: 112, height: 112)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }
                
                // Title
                Text("Enable Location")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                // Description
                // Description
                Text("We need your location to show you the nearest bus stops for your selected routes. Please click 'Allow While Using App' when prompted!")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Allow Button
            Button(action: {
                HapticFeedback.medium()
                AppLocationManager.shared.requestLocationPermission()
                // Small delay to let the prompt appear before transitioning? 
                // Actually, prompts are async. We can just transition.
                // Or wait for status change? For now, just request it.
                onNext()
            }) {
                Text("Allow Location Access")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 1.0, green: 0.03, blue: 0.04))
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 80)
        }
    }
}

