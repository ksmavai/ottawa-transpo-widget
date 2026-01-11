import SwiftUI
import WidgetKit
import CoreGraphics

// MARK: - Departure Grouping Helper
struct DepartureGroup: Identifiable {
    let id: String  // Stop name as ID
    let stopName: String
    let departures: [Departure]
}

func groupDeparturesByStop(_ departures: [Departure]) -> [DepartureGroup] {
    // Group departures by stopName, maintaining order of first appearance
    var groups: [DepartureGroup] = []
    var seenStops: [String: Int] = [:] // stopName -> index in groups
    
    for departure in departures {
        let stopName = departure.stopName ?? "Unknown Stop"
        
        if let index = seenStops[stopName] {
            // Add to existing group
            let existingGroup = groups[index]
            var newDepartures = existingGroup.departures
            newDepartures.append(departure)
            groups[index] = DepartureGroup(id: stopName, stopName: stopName, departures: newDepartures)
        } else {
            // Create new group
            seenStops[stopName] = groups.count
            groups.append(DepartureGroup(id: stopName, stopName: stopName, departures: [departure]))
        }
    }
    
    return groups
}

// MARK: - Font Helper
extension Font {
    static func dotMatrix(size: CGFloat) -> Font {
        // Try various possible PostScript names for the dot-matrix fonts
        // Fonts must be in Info.plist UIAppFonts and copied to bundle
        let fontNames = [
            "Doto-Bold",
            "Doto-Regular", 
            "DotMatrix-Bold",
            "DotMatrix",
            "dot-matrix-bold",
            "dot-matrix"
        ]
        
        for fontName in fontNames {
            if UIFont(name: fontName, size: size) != nil {
                return .custom(fontName, size: size)
            }
        }
        
        // Fallback to system monospace
        return .system(size: size, weight: .bold, design: .monospaced)
    }
}

struct DepartureBoardView: View {
    var entry: DepartureEntry
    
    @State private var isBlinking = false
    
    // Theme is now passed through the entry from the timeline provider
    // This ensures the widget updates when the theme changes
    private var selectedTheme: String {
        entry.theme
    }
    
    var body: some View {
        Group {
            switch selectedTheme {
            case "classic":
                ClassicWidgetView(entry: entry, isBlinking: isBlinking)
            case "night":
                NightWidgetView(entry: entry, isBlinking: isBlinking)
            case "oldwindows":
                OldWindowsWidgetView(entry: entry, isBlinking: isBlinking)
            case "minimal":
                MinimalWidgetView(entry: entry, isBlinking: isBlinking)
            case "crt":
                CRTWidgetView(entry: entry, isBlinking: isBlinking)
            case "skeuomorphic":
                SkeuomorphicWidgetView(entry: entry, isBlinking: isBlinking)
            default:
                ClassicWidgetView(entry: entry, isBlinking: isBlinking)
            }
        }
        .onAppear {
            // Start blinking animation for "NOW" text
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
    }
}

// MARK: - Theme Views for Widget
struct ClassicWidgetView: View {
    let entry: DepartureEntry
    let isBlinking: Bool

    var body: some View {
        let groups = groupDeparturesByStop(entry.departures)
        
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 4) {
                // First header with date
                if let firstGroup = groups.first {
                    HStack(alignment: .center) {
                        Text(firstGroup.stopName.uppercased())
                            .font(.dotMatrix(size: 14))
                            .foregroundColor(.amber)
                            .lineLimit(1)

                        Spacer()
                        
                        Text(formatDate(Date()))
                            .font(.dotMatrix(size: 14))
                            .foregroundColor(.amber)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Divider()
                        .background(Color.amber.opacity(0.3))
                        .padding(.horizontal, 12)

                    // Departures for first stop
                    ForEach(firstGroup.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .classic)
                            .padding(.horizontal, 12)
                    }
                }
                
                // Subsequent groups with stop header (no date)
                ForEach(groups.dropFirst()) { group in
                    Text(group.stopName.uppercased())
                        .font(.dotMatrix(size: 14)) // match top header
                        .foregroundColor(.amber)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    
                    Divider()
                        .background(Color.amber.opacity(0.3))
                        .padding(.horizontal, 12)
                    
                    ForEach(group.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .classic)
                            .padding(.horizontal, 12)
                    }
                }

                if entry.departures.isEmpty {
                    Text("NO ACTIVE TRIPS")
                        .font(.dotMatrix(size: 20))
                        .foregroundColor(.amber)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }

                Spacer()
            }
        }
    }
}

enum WidgetThemeType {
    case classic
    case night
    case oldwindows
    case minimal
    case crt
    case skeuomorphic
}

struct DepartureRow: View {
    let departure: Departure
    let isBlinking: Bool
    let theme: WidgetThemeType
    
    var body: some View {
        HStack(spacing: 12) {
            // Route - theme-specific sizes matching previews
            let routeSize: CGFloat = {
                switch theme {
                case .minimal: return 16
                case .crt: return 19
                default: return 20
                }
            }()
            
            Text(departure.routeName)
                .font(themeFont(size: routeSize))
                .foregroundColor(themeTextColor)
                .frame(width: 70, alignment: .leading)
                .modifier(ThemeShadowModifier(theme: theme))
            
            // Destination - theme-specific sizes matching previews
            let destSize: CGFloat = {
                switch theme {
                case .minimal: return 14
                case .crt: return 17
                default: return 18
                }
            }()
            
            Text(departure.destination.uppercased())
                .font(themeFont(size: destSize))
                .foregroundColor(themeTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
                .modifier(ThemeShadowModifier(theme: theme))
            
            // Time - theme-specific sizes matching previews
            let timeSize: CGFloat = {
                switch theme {
                case .minimal: return 16
                case .crt: return 19
                default: return 20
                }
            }()
            
            if departure.isArrivingNow {
                Text("NOW")
                    .font(themeFont(size: timeSize))
                    .foregroundColor(themeTextColor)
                    .opacity(isBlinking ? 1.0 : 0.3)
                    .frame(width: 60, alignment: .trailing)
                    .modifier(ThemeShadowModifier(theme: theme))
            } else {
                Text("\(departure.minutesUntilArrival)MIN")
                    .font(themeFont(size: timeSize))
                    .foregroundColor(themeTextColor)
                    .frame(width: 60, alignment: .trailing)
                    .modifier(ThemeShadowModifier(theme: theme))
            }
        }
    }
    
    private func themeFont(size: CGFloat) -> Font {
        switch theme {
        case .classic, .night:
            return .dotMatrix(size: size)
        case .oldwindows:
            // Try Fixedsys, fallback to system
            if UIFont(name: "FixedsysExcelsiorIIIb", size: size) != nil {
                return .custom("FixedsysExcelsiorIIIb", size: size)
            }
            return .system(size: size, weight: .regular, design: .monospaced)
        case .minimal:
            return .system(size: size, weight: .regular)
        case .crt:
            return .system(size: size, weight: .regular, design: .monospaced)
        case .skeuomorphic:
            return .system(size: size, weight: .bold, design: .default)
        }
    }
    
    private var themeTextColor: Color {
        switch theme {
        case .classic:
            return .amber
        case .night:
            return Color(red: 0.8, green: 0.0, blue: 0.0)
        case .oldwindows:
            return .white
        case .minimal:
            return .black
        case .crt:
            return Color(red: 0.0, green: 1.0, blue: 0.0)
        case .skeuomorphic:
            return Color(red: 0.15, green: 0.15, blue: 0.2)
        }
    }
}

// MARK: - Other Theme Views
struct NightWidgetView: View {
    let entry: DepartureEntry
    let isBlinking: Bool
    let nightRed = Color(red: 0.8, green: 0.0, blue: 0.0)
    
    var body: some View {
        let groups = groupDeparturesByStop(entry.departures)
        
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 4) {
                // First header with date
                if let firstGroup = groups.first {
                    HStack(alignment: .center) {
                        Text(firstGroup.stopName.uppercased())
                            .font(.dotMatrix(size: 14))
                            .foregroundColor(nightRed)
                            .shadow(color: nightRed.opacity(0.8), radius: 8, x: 0, y: 0)
                            .shadow(color: nightRed.opacity(0.6), radius: 12, x: 0, y: 0)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(formatDate(Date()))
                            .font(.dotMatrix(size: 14))
                            .foregroundColor(nightRed)
                            .shadow(color: nightRed.opacity(0.8), radius: 8, x: 0, y: 0)
                            .shadow(color: nightRed.opacity(0.6), radius: 12, x: 0, y: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    Divider()
                        .background(nightRed.opacity(0.3))
                        .padding(.horizontal, 12)
                    
                    // Departures for first stop
                    ForEach(firstGroup.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .night)
                            .padding(.horizontal, 12)
                    }
                }
                
                // Subsequent groups with stop header (no date)
                ForEach(groups.dropFirst()) { group in
                    // Stop header
                    Text(group.stopName.uppercased())
                        .font(.dotMatrix(size: 14)) // match top header
                        .foregroundColor(nightRed)
                        .shadow(color: nightRed.opacity(0.8), radius: 6, x: 0, y: 0)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    
                    Divider()
                        .background(nightRed.opacity(0.3))
                        .padding(.horizontal, 12)
                    
                    // Departures for this stop
                    ForEach(group.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .night)
                            .padding(.horizontal, 12)
                    }
                }
                
                if entry.departures.isEmpty {
                    Text("NO ACTIVE TRIPS")
                        .font(.dotMatrix(size: 20))
                        .foregroundColor(nightRed)
                        .shadow(color: nightRed.opacity(0.8), radius: 6, x: 0, y: 0)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }
                
                Spacer()
            }
        }
    }
}

struct OldWindowsWidgetView: View {
    let entry: DepartureEntry
    let isBlinking: Bool
    let windowsBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    
    var bitmapFont: Font {
        // Try Fixedsys font
        if UIFont(name: "FixedsysExcelsiorIIIb", size: 20) != nil {
            return .custom("FixedsysExcelsiorIIIb", size: 20)
        }
        return .system(size: 20, weight: .regular, design: .monospaced)
    }
    
    var body: some View {
        let groups = groupDeparturesByStop(entry.departures)
        
        ZStack {
            windowsBlue
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 4) {
                // First header with date
                if let firstGroup = groups.first {
                    HStack(alignment: .center) {
                        Text(firstGroup.stopName.uppercased())
                            .font(bitmapFont)
                            .foregroundColor(.white)
                            .tracking(-1.0)
                        
                        Spacer()
                        
                        Text(formatDate(Date()))
                            .font(bitmapFont)
                            .foregroundColor(.white)
                            .tracking(-1.0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    Divider()
                        .background(Color.white.opacity(0.5))
                        .padding(.horizontal, 12)
                    
                    // Departures for first stop
                    ForEach(firstGroup.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .oldwindows)
                            .padding(.horizontal, 12)
                    }
                }
                
                // Subsequent groups
                ForEach(groups.dropFirst()) { group in
                    Text(group.stopName.uppercased())
                        .font(bitmapFont)
                        .foregroundColor(.white)
                        .tracking(-1.0)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    
                    Divider()
                        .background(Color.white.opacity(0.5))
                        .padding(.horizontal, 12)
                    
                    ForEach(group.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .oldwindows)
                            .padding(.horizontal, 12)
                    }
                }
                
                if entry.departures.isEmpty {
                    Text("NO ACTIVE TRIPS")
                        .font(bitmapFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }
                
                Spacer()
            }
        }
    }
}

struct MinimalWidgetView: View {
    let entry: DepartureEntry
    let isBlinking: Bool

    var body: some View {
        let groups = groupDeparturesByStop(entry.departures)
        
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 4) {
                // First header with date
                if let firstGroup = groups.first {
                    HStack(alignment: .center) {
                        Text(firstGroup.stopName.uppercased())
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(1)

                        Spacer()

                        Text(formatDate(Date()))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.horizontal, 12)

                    ForEach(firstGroup.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .minimal)
                            .padding(.horizontal, 12)
                    }
                }
                
                // Subsequent groups
                ForEach(groups.dropFirst()) { group in
                    Text(group.stopName.uppercased())
                        .font(.system(size: 13, weight: .medium)) // match top header
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.horizontal, 12)
                    
                    ForEach(group.departures) { departure in
                        DepartureRow(departure: departure, isBlinking: isBlinking, theme: .minimal)
                            .padding(.horizontal, 12)
                    }
                }

                if entry.departures.isEmpty {
                    Text("No Active Trips")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }

                Spacer()
            }
        }
    }
}

struct CRTWidgetView: View {
    let entry: DepartureEntry
    let isBlinking: Bool
    let crtGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    
    // Courier New monospace font - SMALLER sizes to fit more content
    var courierFont: Font {
        if UIFont(name: "Courier New", size: 15) != nil {
            return .custom("Courier New", size: 15)
        }
        return .system(size: 15, weight: .regular, design: .monospaced)
    }
    var courierFontSmall: Font {
        if UIFont(name: "Courier New", size: 13) != nil {
            return .custom("Courier New", size: 13)
        }
        return .system(size: 13, weight: .regular, design: .monospaced)
    }
    var courierFontHeader: Font {
        if UIFont(name: "Courier New", size: 11) != nil {
            return .custom("Courier New", size: 11)
        }
        return .system(size: 11, weight: .regular, design: .monospaced)
    }
    var courierFontEmpty: Font {
        if UIFont(name: "Courier New", size: 15) != nil {
            return .custom("Courier New", size: 15)
        }
        return .system(size: 15, weight: .regular, design: .monospaced)
    }
    
    var body: some View {
        let groups = groupDeparturesByStop(entry.departures)
        
        GeometryReader { geometry in
            ZStack {
                // Black background - fills ENTIRE widget with rounded corners
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Scanlines effect - fills ENTIRE widget with rounded corners
                VStack(spacing: 0) {
                    ForEach(0..<Int(geometry.size.height / 2), id: \.self) { _ in
                        Rectangle()
                            .fill(crtGreen.opacity(0.15)) // More visible opacity
                            .frame(height: 1)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                
                // Additional scanline overlay for more visibility - fills ENTIRE widget with rounded corners
                VStack(spacing: 0) {
                    ForEach(0..<Int(geometry.size.height / 3), id: \.self) { _ in
                        Rectangle()
                            .fill(crtGreen.opacity(0.08))
                            .frame(height: 1)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                
                // Radial gradient overlay for CRT effect - fills ENTIRE widget with rounded corners
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.3)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            
                VStack(alignment: .leading, spacing: 2) {
                    // First header with date
                    if let firstGroup = groups.first {
                        HStack(alignment: .center) {
                            Text(firstGroup.stopName.uppercased())
                                .font(courierFontHeader)
                                .foregroundColor(crtGreen)
                                .shadow(color: crtGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                                .shadow(color: crtGreen.opacity(0.4), radius: 16, x: 0, y: 0)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatDate(Date()))
                                .font(courierFontHeader)
                                .foregroundColor(crtGreen)
                                .shadow(color: crtGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        
                        Divider()
                            .background(crtGreen.opacity(0.4))
                            .padding(.horizontal, 10)
                        
                        ForEach(firstGroup.departures) { departure in
                            DepartureRow(departure: departure, isBlinking: isBlinking, theme: .crt)
                                .padding(.horizontal, 10)
                        }
                    }
                    
                    // Subsequent groups
                    ForEach(groups.dropFirst()) { group in
                        Text(group.stopName.uppercased())
                            .font(courierFontHeader)
                            .foregroundColor(crtGreen)
                            .padding(.horizontal, 10)
                            .padding(.top, 1)
                        
                        Divider()
                            .background(crtGreen.opacity(0.4))
                            .padding(.horizontal, 10)
                        
                        ForEach(group.departures) { departure in
                            DepartureRow(departure: departure, isBlinking: isBlinking, theme: .crt)
                                .padding(.horizontal, 10)
                        }
                    }
                    
                    if entry.departures.isEmpty {
                        Text("NO ACTIVE TRIPS")
                            .font(courierFontEmpty)
                            .foregroundColor(crtGreen)
                            .shadow(color: crtGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }
                    
                    Spacer() // Push content to top
                }
                .frame(maxHeight: .infinity, alignment: .top) // Align to top, not center
            }
        }
    }
}

// MARK: - Skeuomorphic Theme (iOS 6 / 2010 Apple Vibes)
struct SkeuomorphicWidgetView: View {
    let entry: DepartureEntry
    let isBlinking: Bool
    
    // Classic iOS 6 colors
    let headerGradientTop = Color(red: 0.55, green: 0.57, blue: 0.60)
    let headerGradientBottom = Color(red: 0.35, green: 0.37, blue: 0.40)
    let linenBackground = Color(red: 0.90, green: 0.88, blue: 0.85)
    let textColor = Color(red: 0.15, green: 0.15, blue: 0.2)
    let insetShadow = Color.black.opacity(0.3)
    
    var body: some View {
        let groups = groupDeparturesByStop(entry.departures)
        
        GeometryReader { geometry in
            ZStack {
                // Linen-like textured background
                linenBackground
                
                // Subtle noise texture overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear,
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(spacing: 0) {
                    // Glossy header bar - classic iOS 6 style
                    ZStack {
                        // Base gradient
                        LinearGradient(
                            colors: [headerGradientTop, headerGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Glossy shine overlay
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)
                            
                            Spacer()
                        }
                        
                        // Header content
                        HStack {
                            Text(groups.first?.stopName.uppercased() ?? entry.stopName.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: -1)
                            
                            Spacer()
                            
                            Text(formatDate(Date()))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: -1)
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 28)
                    .overlay(
                        // Bottom edge shadow
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    
                    // Content area with inset effect
                    ZStack(alignment: .top) {
                        // Inset shadow effect
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.white)
                            .shadow(color: insetShadow, radius: 1.0, x: 0, y: 1.0)
                            // Increase padding to make the white card visibly smaller
                            .padding(.horizontal, 8) 
                            .padding(.vertical, 8)
                        
                        // Content
                        VStack(alignment: .leading, spacing: 2) {
                            if entry.departures.isEmpty {
                                Spacer()
                                Text("No Active Trips")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(textColor.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Spacer()
                            } else {
                                // First group with date shown in header already
                                if let firstGroup = groups.first {
                                    ForEach(firstGroup.departures) { departure in
                                        SkeuomorphicDepartureRow(departure: departure, isBlinking: isBlinking)
                                    }
                                }
                                
                                // Subsequent groups with stop headers
                                ForEach(groups.dropFirst()) { group in
                                    Text(group.stopName.uppercased())
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(textColor.opacity(0.8))
                                        .padding(.top, 2)
                                        .padding(.leading, 5) // align with badges
                                    
                                    ForEach(group.departures) { departure in
                                        SkeuomorphicDepartureRow(departure: departure, isBlinking: isBlinking)
                                    }
                                }
                                
                                Spacer(minLength: 0) // Explicitly push content to top
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 12) // Slightly more top padding for content
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Force top alignment
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
}

struct SkeuomorphicDepartureRow: View {
    let departure: Departure
    let isBlinking: Bool
    
    let textColor = Color(red: 0.15, green: 0.15, blue: 0.2)
    let accentBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    
    var body: some View {
        HStack(spacing: 4) {
            // Route badge with glossy effect
            ZStack {
                // Badge background with gradient
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentBlue.opacity(0.9),
                                accentBlue
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 35, height: 19)
                    .shadow(color: .black.opacity(0.2), radius: 0.8, x: 0, y: 1)
                
                // Glossy overlay
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: 35, height: 19)
                
                Text(departure.routeNumber)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: -0.5)
            }
            
            // Destination
            Text(departure.destination)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Time with embossed effect
            if departure.isArrivingNow {
                Text("NOW")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(Color(red: 0.8, green: 0.2, blue: 0.1))
                    .opacity(isBlinking ? 1.0 : 0.4)
                    .shadow(color: .white.opacity(0.8), radius: 0, x: 0, y: 1)
            } else {
                Text("\(departure.minutesUntilArrival) min")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(textColor)
                    .shadow(color: .white.opacity(0.8), radius: 0, x: 0, y: 1)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4) // was 1.5
    }
}

// MARK: - Theme Shadow Modifier
struct ThemeShadowModifier: ViewModifier {
    let theme: WidgetThemeType
    
    func body(content: Content) -> some View {
        Group {
            switch theme {
            case .night:
                let nightRed = Color(red: 0.8, green: 0.0, blue: 0.0)
                content
                    .shadow(color: nightRed.opacity(0.8), radius: 6, x: 0, y: 0)
                    .shadow(color: nightRed.opacity(0.6), radius: 10, x: 0, y: 0)
            case .crt:
                let crtGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
                // Route and Time get stronger shadows, destination gets lighter
                content
                    .shadow(color: crtGreen.opacity(0.9), radius: 10, x: 0, y: 0)
                    .shadow(color: crtGreen.opacity(0.5), radius: 20, x: 0, y: 0)
            default:
                content
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    static let amber = Color(red: 1.0, green: 0.67, blue: 0.0) // #FFAA00
}

// MARK: - Date Formatter
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: date).uppercased()
}

// MARK: - Preview
struct DepartureBoardView_Previews: PreviewProvider {
    static var previews: some View {
        DepartureBoardView(entry: DepartureEntry(
            date: Date(),
            departures: [
                Departure(id: "1", routeNumber: "1", routeName: "Line 1", destination: "Blair", minutesUntilArrival: 2, isArrivingNow: false, directionId: 0, stopId: nil, stopName: nil),
                Departure(id: "2", routeNumber: "94", routeName: "Route 94", destination: "Hurdman", minutesUntilArrival: 5, isArrivingNow: false, directionId: 0, stopId: nil, stopName: nil),
                Departure(id: "3", routeNumber: "7", routeName: "7 Carleton", destination: "Carleton U", minutesUntilArrival: 0, isArrivingNow: true, directionId: 0, stopId: nil, stopName: nil),
                Departure(id: "4", routeNumber: "88", routeName: "88-1", destination: "Unknown", minutesUntilArrival: 12, isArrivingNow: false, directionId: 1, stopId: nil, stopName: nil)
            ],
            stopName: "Home",
            theme: "classic"
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

