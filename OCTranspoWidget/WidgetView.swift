import SwiftUI
import CoreGraphics
import CoreText
import WidgetKit

// MARK: - Font Registration Helper
class FontLoader {
    static let shared = FontLoader()
    private var fontsRegistered = false
    
    func registerFontsIfNeeded() {
        guard !fontsRegistered else { return }
        
        // Register dot-matrix fonts - try both main bundle and widget extension bundle
        let dotMatrixFonts = ["dot-matrix", "dot-matrix-bold"]
        for fontName in dotMatrixFonts {
            var fontURL: URL? = nil
            
            // Try main bundle first
            if let url = Bundle.main.url(forResource: fontName, withExtension: "TTF") {
                fontURL = url
            } else if let url = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
                fontURL = url
            }
            
            // If not found in main bundle, try widget extension bundle
            if fontURL == nil {
                // Try to find widget extension bundle
                let possibleBundleIds = [
                    "com.myapp.octranspo.OCTranspoWidgetExtensionExtension",
                    "com.myapp.octranspo.OCTranspoWidgetExtension"
                ]
                
                for bundleId in possibleBundleIds {
                    if let widgetBundle = Bundle(identifier: bundleId) {
                        if let url = widgetBundle.url(forResource: fontName, withExtension: "TTF") {
                            fontURL = url
                            break
                        } else if let url = widgetBundle.url(forResource: fontName, withExtension: "ttf") {
                            fontURL = url
                            break
                        }
                    }
                }
            }
            
            if let url = fontURL {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    print("✅ Registered \(fontName) font")
                } else {
                    if let cfError = error?.takeUnretainedValue() {
                        let errorDescription = CFErrorCopyDescription(cfError) as String? ?? "unknown error"
                        print("❌ Failed to register \(fontName) font: \(errorDescription)")
                    } else {
                        print("❌ Failed to register \(fontName) font: unknown error")
                    }
                }
            } else {
                print("⚠️ \(fontName).TTF not found in any bundle")
            }
        }
        
        // Register Fixedsys font - try both TTF and ttf extensions
        if let fontURL = Bundle.main.url(forResource: "fixedsys", withExtension: "TTF") {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                print("✅ Registered fixedsys font (TTF)")
            } else {
                if let cfError = error?.takeUnretainedValue() {
                    let errorDescription = CFErrorCopyDescription(cfError) as String? ?? "unknown error"
                    print("❌ Failed to register fixedsys font (TTF): \(errorDescription)")
                } else {
                    print("❌ Failed to register fixedsys font (TTF): unknown error")
                }
            }
        } else if let fontURL = Bundle.main.url(forResource: "fixedsys", withExtension: "ttf") {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                print("✅ Registered fixedsys font (ttf)")
            } else {
                if let cfError = error?.takeUnretainedValue() {
                    let errorDescription = CFErrorCopyDescription(cfError) as String? ?? "unknown error"
                    print("❌ Failed to register fixedsys font (ttf): \(errorDescription)")
                } else {
                    print("❌ Failed to register fixedsys font (ttf): unknown error")
                }
            }
        } else {
            print("⚠️ fixedsys.TTF/ttf not found in bundle")
            // Debug: List all font files in bundle
            if let resourcePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                    let fontFiles = files.filter { $0.lowercased().hasSuffix(".ttf") || $0.lowercased().hasSuffix(".otf") }
                    print("📋 Font files in bundle: \(fontFiles)")
                }
            }
        }
        
        fontsRegistered = true
    }
}

// MARK: - Font Helper (shared with widget extension)
extension Font {
    static func dotMatrix(size: CGFloat) -> Font {
        // Register fonts first (runtime registration as backup)
        FontLoader.shared.registerFontsIfNeeded()
        
        // First, try to load the font file directly to get exact PostScript name
        var fontPath: String? = nil
        
        // Try main bundle first
        if let path = Bundle.main.path(forResource: "dot-matrix", ofType: "TTF") {
            fontPath = path
        } else if let path = Bundle.main.path(forResource: "dot-matrix", ofType: "ttf") {
            fontPath = path
        }
        
        // If not found, try widget extension bundle
        if fontPath == nil {
            let possibleBundleIds = [
                "com.myapp.octranspo.OCTranspoWidgetExtensionExtension",
                "com.myapp.octranspo.OCTranspoWidgetExtension"
            ]
            
            for bundleId in possibleBundleIds {
                if let widgetBundle = Bundle(identifier: bundleId) {
                    if let path = widgetBundle.path(forResource: "dot-matrix", ofType: "TTF") {
                        fontPath = path
                        break
                    } else if let path = widgetBundle.path(forResource: "dot-matrix", ofType: "ttf") {
                        fontPath = path
                        break
                    }
                }
            }
        }
        
        // Load font file and get PostScript name
        if let path = fontPath {
            if let fontData = NSData(contentsOfFile: path) as Data?,
               let dataProvider = CGDataProvider(data: fontData as CFData),
               let font = CGFont(dataProvider) {
                if let postScriptName = font.postScriptName as String? {
                    if UIFont(name: postScriptName, size: size) != nil {
                        return .custom(postScriptName, size: size)
                    }
                }
            }
        }
        
        // Try multiple possible font names (including PostScript names from Info.plist)
        let fontNames = ["DotMatrix", "dot-matrix", "Dot Matrix", "Doto-Bold", "DotMatrix-Regular", "DotMatrix-Bold"]
        for fontName in fontNames {
            if UIFont(name: fontName, size: size) != nil {
                return .custom(fontName, size: size)
            }
        }
        
        // Fallback to system font if custom font not found
        return .system(size: size, weight: .bold, design: .monospaced)
    }
}

// MARK: - Color Extension
extension Color {
    static let amber = Color(red: 1.0, green: 0.67, blue: 0.0) // #FFAA00
}

struct WidgetView: View {
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragStartIndex: Int = 0
    
    // Use @AppStorage to automatically sync with UserDefaults - this triggers updates
    @AppStorage("SelectedWidgetTheme", store: UserDefaults(suiteName: "group.com.myapp.octranspo"))
    private var selectedThemeId: String = "classic"
    
    private let selectedThemeKey = "SelectedWidgetTheme"
    
    let widgetThemes: [WidgetTheme] = [
        WidgetTheme(id: "classic", name: "Classic Dot Matrix", description: "Traditional orange LED display"),
        WidgetTheme(id: "night", name: "Night Mode", description: "Dimmed red LEDs with soft glow"),
        WidgetTheme(id: "oldwindows", name: "Old Windows", description: "Windows 3.x/95 BSOD style"),
        WidgetTheme(id: "minimal", name: "Minimal Text", description: "Clean SF Pro font"),
        WidgetTheme(id: "crt", name: "Retro CRT", description: "Green phosphor with scanlines"),
        WidgetTheme(id: "skeuomorphic", name: "iOS 6", description: "2010 Apple vibes")
    ]
    
    private var selectedThemeIndex: Int {
        widgetThemes.firstIndex(where: { $0.id == selectedThemeId }) ?? 0
    }
    
    private func selectTheme(_ themeId: String) {
        HapticFeedback.medium()
        
        // Simply set the @AppStorage property - this automatically writes to UserDefaults
        // and triggers updates in any views using the same @AppStorage
        selectedThemeId = themeId
        
        // Sync currentIndex
        if let newIndex = widgetThemes.firstIndex(where: { $0.id == themeId }) {
            withAnimation {
                currentIndex = newIndex
            }
        }
        
        // Reload widgets to pick up the new theme
        // @AppStorage handles the UserDefaults write automatically
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func loadSelectedTheme() {
        // @AppStorage automatically loads from UserDefaults, so we just need to sync currentIndex
        if let selectedIndex = widgetThemes.firstIndex(where: { $0.id == selectedThemeId }) {
            currentIndex = selectedIndex
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Section - Matching Departures header exactly
            VStack(alignment: .leading, spacing: 4) {
                Text("Widget Themes")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Choose your style")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, -10)
            .padding(.bottom, 24)
            .ignoresSafeArea(.container, edges: .top)
            
            // Widget Preview Carousel
            TabView(selection: $currentIndex) {
                ForEach(Array(widgetThemes.enumerated()), id: \.element.id) { index, theme in
                    VStack(spacing: 20) {
                        WidgetPreviewCard(theme: theme)
                        
                        // Select Button
                        Button(action: {
                            selectTheme(theme.id)
                        }) {
                            Text(selectedThemeId == theme.id ? "Selected" : "Select")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedThemeId == theme.id ? Color(red: 1.0, green: 0.03, blue: 0.04) : Color.gray.opacity(0.6))
                                )
                        }
                        .padding(.horizontal, 24)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 500)
            .padding(.top, 20)
            
            // Page Indicators - Draggable
            HStack(spacing: 8) {
                ForEach(0..<widgetThemes.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentIndex ? Color(red: 1.0, green: 0.03, blue: 0.04) : Color.gray.opacity(0.3))
                        .frame(width: index == currentIndex ? 32 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentIndex)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartIndex = currentIndex
                            HapticFeedback.selection()
                        }
                        dragOffset = value.translation.width
                        
                        // Calculate target index based on drag distance from start
                        // Dragging right (positive) = next item (increase index)
                        // Dragging left (negative) = previous item (decrease index)
                        let dragDistance = value.translation.width
                        let itemWidth: CGFloat = 40 // Approximate width per indicator (8pt dot + 8pt spacing)
                        let dragIndex = Int(dragDistance / itemWidth) // Positive drag = positive index change
                        let targetIndex = max(0, min(widgetThemes.count - 1, dragStartIndex + dragIndex))
                        
                        // Smoothly update index as user drags
                        if targetIndex != currentIndex {
                            HapticFeedback.light() // Haptic feedback when crossing to a new dot
                            withAnimation(.interactiveSpring()) {
                                currentIndex = targetIndex
                            }
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        // Final calculation based on total drag distance from start
                        let dragDistance = value.translation.width
                        let itemWidth: CGFloat = 40
                        let dragIndex = Int(dragDistance / itemWidth)
                        let targetIndex = max(0, min(widgetThemes.count - 1, dragStartIndex + dragIndex))
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentIndex = targetIndex
                        }
                        HapticFeedback.selection()
                        dragOffset = 0
                    }
            )
            .onAppear {
                loadSelectedTheme()
                // Sync currentIndex with selected theme
                if let selectedIndex = widgetThemes.firstIndex(where: { $0.id == selectedThemeId }) {
                    currentIndex = selectedIndex
                }
            }
            .onChange(of: selectedThemeId) { _, newValue in
                // Update currentIndex when theme changes (only when button is clicked)
                if let newIndex = widgetThemes.firstIndex(where: { $0.id == newValue }) {
                    currentIndex = newIndex
                }
            }
        }
    }
}

struct WidgetTheme {
    let id: String
    let name: String
    let description: String
}

struct WidgetPreviewCard: View {
    let theme: WidgetTheme
    
    var body: some View {
        VStack(spacing: 24) {
            // Widget Preview - Using actual widget size (System Medium: 329x155 points)
            // Add padding around the entire card to match widget appearance
            WidgetPreview(themeId: theme.id)
                .frame(width: 329, height: 155)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                .padding(12) // Add padding around border to match widget appearance
            
            // Theme Info
            VStack(spacing: 8) {
                Text(theme.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(theme.description)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
}

struct WidgetPreview: View {
    let themeId: String
    let currentDate = formatDate(Date())
    
    var body: some View {
        Group {
            switch themeId {
            case "classic":
                ClassicWidgetPreview()
            case "night":
                NightWidgetPreview()
            case "oldwindows":
                OldWindowsWidgetPreview()
            case "minimal":
                MinimalWidgetPreview()
            case "crt":
                CRTWidgetPreview()
            case "skeuomorphic":
                SkeuomorphicWidgetPreview()
            default:
                ClassicWidgetPreview()
            }
        }
    }
}

// MARK: - Widget Theme Previews

struct ClassicWidgetPreview: View {
    let currentDate = formatDate(Date())
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                // Header with stop name and date - matching actual widget
                HStack(alignment: .center) {
                    Text("RIDEAU CENTRE")
                        .font(.dotMatrix(size: 16))
                        .foregroundColor(.amber)
                    
                    Spacer()
                    
                    Text(currentDate)
                        .font(.dotMatrix(size: 16))
                        .foregroundColor(.amber)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                Divider()
                    .background(Color.amber.opacity(0.3))
                    .padding(.horizontal, 12)
                
                // Departure row - matching actual widget layout
                HStack(spacing: 12) {
                    // Route
                    Text("7")
                        .font(.dotMatrix(size: 20))
                        .foregroundColor(.amber)
                        .frame(width: 70, alignment: .leading)
                    
                    // Destination
                    Text("CARLETON")
                        .font(.dotMatrix(size: 18))
                        .foregroundColor(.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Time
                    Text("4MIN")
                        .font(.dotMatrix(size: 20))
                        .foregroundColor(.amber)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Spacer()
            }
        }
    }
}

struct NightWidgetPreview: View {
    let currentDate = formatDate(Date())
    let nightRed = Color(red: 0.8, green: 0.0, blue: 0.0)
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("RIDEAU CENTRE")
                        .font(.dotMatrix(size: 16))
                        .foregroundColor(nightRed)
                        .shadow(color: nightRed.opacity(0.8), radius: 8, x: 0, y: 0)
                        .shadow(color: nightRed.opacity(0.6), radius: 12, x: 0, y: 0)
                    
                    Spacer()
                    
                    Text(currentDate)
                        .font(.dotMatrix(size: 16))
                        .foregroundColor(nightRed)
                        .shadow(color: nightRed.opacity(0.8), radius: 8, x: 0, y: 0)
                        .shadow(color: nightRed.opacity(0.6), radius: 12, x: 0, y: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                Divider()
                    .background(nightRed.opacity(0.3))
                    .padding(.horizontal, 12)
                
                HStack(spacing: 12) {
                    Text("7")
                        .font(.dotMatrix(size: 20))
                        .foregroundColor(nightRed)
                        .frame(width: 70, alignment: .leading)
                        .shadow(color: nightRed.opacity(0.8), radius: 6, x: 0, y: 0)
                        .shadow(color: nightRed.opacity(0.6), radius: 10, x: 0, y: 0)
                    
                    Text("CARLETON")
                        .font(.dotMatrix(size: 18))
                        .foregroundColor(nightRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .shadow(color: nightRed.opacity(0.8), radius: 6, x: 0, y: 0)
                        .shadow(color: nightRed.opacity(0.6), radius: 10, x: 0, y: 0)
                    
                    Text("4MIN")
                        .font(.dotMatrix(size: 20))
                        .foregroundColor(nightRed)
                        .frame(width: 60, alignment: .trailing)
                        .shadow(color: nightRed.opacity(0.8), radius: 6, x: 0, y: 0)
                        .shadow(color: nightRed.opacity(0.6), radius: 10, x: 0, y: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Spacer()
            }
        }
    }
}

struct OldWindowsWidgetPreview: View {
    let currentDate = formatDate(Date())
    // Windows 3.x/95 BSOD blue background
    let windowsBlue = Color(red: 0.0, green: 0.0, blue: 1.0) // #0000FF
    // Fixedsys font - classic Windows bitmap font
    var bitmapFont: Font {
        // Register fonts first
        FontLoader.shared.registerFontsIfNeeded()
        
        // First, try to load the font file directly and get PostScript name - try both extensions
        var fontPath: String? = nil
        if let path = Bundle.main.path(forResource: "fixedsys", ofType: "ttf") {
            fontPath = path
        } else if let path = Bundle.main.path(forResource: "fixedsys", ofType: "TTF") {
            fontPath = path
        }
        
        if let path = fontPath {
            if let fontData = NSData(contentsOfFile: path) as Data?,
               let dataProvider = CGDataProvider(data: fontData as CFData),
               let font = CGFont(dataProvider) {
                if let postScriptName = font.postScriptName as String? {
                    print("✅ Found Fixedsys PostScript name from file: \(postScriptName)")
                    if UIFont(name: postScriptName, size: 20) != nil {
                        return .custom(postScriptName, size: 20)
                    } else {
                        print("⚠️ Font registered but UIFont(name:) returned nil for: \(postScriptName)")
                    }
                }
            } else {
                print("⚠️ Failed to create CGFont from fixedsys file")
            }
        } else {
            print("⚠️ fixedsys.ttf/TTF file not found in bundle")
        }
        
        // Use the exact PostScript name
        let fontName = "FixedsysExcelsiorIIIb"
        if UIFont(name: fontName, size: 20) != nil {
            print("✅ Using Fixedsys font: \(fontName)")
            return .custom(fontName, size: 20)
        }
        
        // Try alternative names as fallback
        let fallbackNames = ["Fixedsys", "fixedsys", "FIXEDSYS", "Fixedsys Excelsior"]
        for fallbackName in fallbackNames {
            if UIFont(name: fallbackName, size: 17.5) != nil {
                print("✅ Using Fixedsys font (fallback): \(fallbackName)")
                return .custom(fallbackName, size: 17.5)
            }
        }
        
        // Debug: Print all available fonts
        #if DEBUG
        let allFonts = UIFont.familyNames.flatMap { UIFont.fontNames(forFamilyName: $0) }
        print("📋 Available fonts containing 'fixedsys' or 'fixedsys':")
        allFonts.filter { $0.lowercased().contains("fixedsys") }.forEach { print("  - \($0)") }
        #endif
        
        // Fallback to system font if Fixedsys not available
        print("⚠️ Fixedsys font not found, using system font")
        return .system(size: 17.5, weight: .regular, design: .default)
    }
    
    var body: some View {
        ZStack {
            // Classic Windows BSOD blue background
            windowsBlue
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("RIDEAU CENTRE")
                        .font(bitmapFont)
                        .foregroundColor(.white)
                        .tracking(-1.0) // Tight spacing for bitmap look
                    
                    Spacer()
                    
                    Text(currentDate)
                        .font(bitmapFont)
                        .foregroundColor(.white)
                        .tracking(-1.0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                Divider()
                    .background(Color.white.opacity(0.5))
                    .padding(.horizontal, 12)
                
                HStack(spacing: 12) {
                    Text("7")
                        .font(bitmapFont)
                        .foregroundColor(.white)
                        .frame(width: 70, alignment: .leading)
                        .tracking(-1.0)
                    
                    Text("CARLETON")
                        .font(bitmapFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .tracking(-1.0)
                    
                    Text("4MIN")
                        .font(bitmapFont)
                        .foregroundColor(.white)
                        .frame(width: 60, alignment: .trailing)
                        .tracking(-1.0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Spacer()
            }
        }
    }
}

struct MinimalWidgetPreview: View {
    let currentDate = formatDate(Date())
    // SF Pro font family
    let sfFont = Font.system(size: 14, weight: .regular, design: .default)
    let sfFontSmall = Font.system(size: 14, weight: .regular, design: .default)
    let sfFontHeader = Font.system(size: 14, weight: .medium, design: .default)
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("RIDEAU CENTRE")
                        .font(sfFontHeader)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text(currentDate)
                        .font(sfFontHeader)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 12)
                
                HStack(spacing: 12) {
                    Text("7")
                        .font(sfFont)
                        .foregroundColor(.black)
                        .frame(width: 70, alignment: .leading)
                    
                    Text("CARLETON")
                        .font(sfFontSmall)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text("4MIN")
                        .font(sfFont)
                        .foregroundColor(.black)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Spacer()
            }
        }
    }
}

struct CRTWidgetPreview: View {
    let currentDate = formatDate(Date())
    // CRT green phosphor color
    let crtGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    // Courier New monospace font - fallback to system monospaced if not available
    var courierFont: Font {
        if UIFont(name: "Courier New", size: 19) != nil {
            return .custom("Courier New", size: 19)
        }
        return .system(size: 19, weight: .regular, design: .monospaced)
    }
    var courierFontSmall: Font {
        if UIFont(name: "Courier New", size: 17) != nil {
            return .custom("Courier New", size: 17)
        }
        return .system(size: 17, weight: .regular, design: .monospaced)
    }
    var courierFontHeader: Font {
        if UIFont(name: "Courier New", size: 16) != nil {
            return .custom("Courier New", size: 16)
        }
        return .system(size: 16, weight: .regular, design: .monospaced)
    }
    
    var body: some View {
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
            
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text("RIDEAU CENTRE")
                            .font(courierFontHeader)
                            .foregroundColor(crtGreen)
                            .shadow(color: crtGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                            .shadow(color: crtGreen.opacity(0.4), radius: 16, x: 0, y: 0)
                        
                        Spacer()
                        
                        Text(currentDate)
                            .font(courierFontHeader)
                            .foregroundColor(crtGreen)
                            .shadow(color: crtGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    
                    Divider()
                        .background(crtGreen.opacity(0.4))
                        .padding(.horizontal, 12)
                    
                    HStack(spacing: 12) {
                        Text("7")
                            .font(courierFont)
                            .foregroundColor(crtGreen)
                            .frame(width: 70, alignment: .leading)
                            .shadow(color: crtGreen.opacity(0.9), radius: 10, x: 0, y: 0)
                            .shadow(color: crtGreen.opacity(0.5), radius: 20, x: 0, y: 0)
                        
                        Text("CARLETON")
                            .font(courierFontSmall)
                            .foregroundColor(crtGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .shadow(color: crtGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                        
                        Text("4MIN")
                            .font(courierFont)
                            .foregroundColor(crtGreen)
                            .frame(width: 60, alignment: .trailing)
                            .shadow(color: crtGreen.opacity(0.9), radius: 10, x: 0, y: 0)
                            .shadow(color: crtGreen.opacity(0.5), radius: 20, x: 0, y: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    
                    Spacer()
                }
            }
        }
    }
}

struct SkeuomorphicWidgetPreview: View {
    let currentDate = formatDate(Date())
    
    // Classic iOS 6 colors
    let headerGradientTop = Color(red: 0.55, green: 0.57, blue: 0.60)
    let headerGradientBottom = Color(red: 0.35, green: 0.37, blue: 0.40)
    let linenBackground = Color(red: 0.90, green: 0.88, blue: 0.85)
    let textColor = Color(red: 0.15, green: 0.15, blue: 0.2)
    let accentBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Linen-like textured background
                linenBackground
                
                // Subtle gradient overlay
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
                            Text("RIDEAU CENTRE")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: -1)
                            
                            Spacer()
                            
                            Text(currentDate)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: -1)
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 40)
                    .overlay(
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    
                    // Content area with inset effect
                    ZStack(alignment: .top) {
                        // Inset shadow effect
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 2)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        
                        // Sample departure row
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 10) {
                                // Route badge with glossy effect
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [accentBlue.opacity(0.9), accentBlue],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 44, height: 26)
                                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.0)],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                        )
                                        .frame(width: 44, height: 26)
                                    
                                    Text("7")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: -0.5)
                                }
                                
                                Text("Carleton")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(textColor)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("4 min")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(textColor)
                                    .shadow(color: .white.opacity(0.8), radius: 0, x: 0, y: 1)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
}

// Helper function for date formatting
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: date).uppercased()
}

