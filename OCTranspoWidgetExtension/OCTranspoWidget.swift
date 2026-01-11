import WidgetKit
import SwiftUI
import CoreText

// MARK: - Font Registration Helper for Widget Extension
class WidgetFontLoader {
    static let shared = WidgetFontLoader()
    private var fontsRegistered = false
    
    func registerFontsIfNeeded() {
        guard !fontsRegistered else { return }
        
        // Register DotMatrix fonts
        let dotMatrixFonts = ["dot-matrix", "dot-matrix-bold"]
        for fontName in dotMatrixFonts {
            if let fontURL = Bundle.main.url(forResource: fontName, withExtension: "TTF") {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                    print("✅ Registered \(fontName) font (TTF) in widget")
                } else {
                    if let cfError = error?.takeUnretainedValue() {
                        let errorDescription = CFErrorCopyDescription(cfError) as String? ?? "unknown error"
                        print("❌ Failed to register \(fontName) font (TTF) in widget: \(errorDescription)")
                    }
                }
            } else if let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                    print("✅ Registered \(fontName) font (ttf) in widget")
                } else {
                    if let cfError = error?.takeUnretainedValue() {
                        let errorDescription = CFErrorCopyDescription(cfError) as String? ?? "unknown error"
                        print("❌ Failed to register \(fontName) font (ttf) in widget: \(errorDescription)")
                    }
                }
            }
        }
        
        // Register Fixedsys font - try both TTF and ttf extensions
        if let fontURL = Bundle.main.url(forResource: "fixedsys", withExtension: "TTF") {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                print("✅ Registered fixedsys font (TTF) in widget")
            } else {
                if let cfError = error?.takeUnretainedValue() {
                    let errorDescription = CFErrorCopyDescription(cfError) as String? ?? "unknown error"
                    print("❌ Failed to register fixedsys font (TTF) in widget: \(errorDescription)")
                }
            }
        } else if let fontURL = Bundle.main.url(forResource: "fixedsys", withExtension: "ttf") {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                print("✅ Registered fixedsys font (ttf) in widget")
            } else {
                if let cfError = error?.takeUnretainedValue() {
                    let errorDescription = CFErrorCopyDescription(cfError) as String? ?? "unknown error"
                    print("❌ Failed to register fixedsys font (ttf) in widget: \(errorDescription)")
                }
            }
        }
        
        fontsRegistered = true
    }
}

@main
struct OCTranspoWidgetBundle: WidgetBundle {
    var body: some Widget {
        OCTranspoWidget()
        InboundDeparturesWidget()
    }
}

struct OCTranspoWidget: Widget {
    let kind: String = "OCTranspoWidget"
    
    init() {
        // Register fonts once at startup
        WidgetFontLoader.shared.registerFontsIfNeeded()
    }
    
    // Get background color based on theme
    private func getBackgroundColor(for theme: String) -> Color {
        switch theme {
        case "classic", "night":
            return .black
        case "oldwindows":
            return Color(red: 0.0, green: 0.0, blue: 1.0) // Windows blue
        case "crt":
            return .black
        case "minimal":
            return .white
        case "skeuomorphic":
            return Color(red: 0.90, green: 0.88, blue: 0.85) // Linen background
        default:
            return .black
        }
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DepartureTimelineProvider()) { entry in
            DepartureBoardView(entry: entry)
                .id(entry.theme) // Force view refresh when theme changes
                .containerBackground(getBackgroundColor(for: entry.theme), for: .widget)
        }
        .configurationDisplayName("Ottawa Transpo Departures")
        .description("Retro LED-style bus departure board")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled() // Allow full bleed for CRT effects
    }
}

