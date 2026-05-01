import SwiftUI
import Combine

// MARK: - Theme Presets
struct BrowserTheme: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var accentHex: String
    var tabBarHex: String
    var toolbarHex: String
    var textHex: String
    var isDark: Bool

    var accentColor: Color { Color(hex: accentHex) ?? .green }
    var tabBarColor: Color { Color(hex: tabBarHex) ?? Color(NSColor.windowBackgroundColor) }
    var toolbarColor: Color { Color(hex: toolbarHex) ?? Color(NSColor.windowBackgroundColor) }
    var textColor: Color { Color(hex: textHex) ?? .primary }

    static let snakeGreen = BrowserTheme(
        name: "Snake Green",
        accentHex: "#22c55e",
        tabBarHex: "#0f172a",
        toolbarHex: "#1e293b",
        textHex: "#e2e8f0",
        isDark: true
    )
    static let midnightBlue = BrowserTheme(
        name: "Midnight Blue",
        accentHex: "#3b82f6",
        tabBarHex: "#0a0f1e",
        toolbarHex: "#111827",
        textHex: "#dbeafe",
        isDark: true
    )
    static let crimsonDark = BrowserTheme(
        name: "Crimson",
        accentHex: "#ef4444",
        tabBarHex: "#1c0a0a",
        toolbarHex: "#2d1010",
        textHex: "#fecaca",
        isDark: true
    )
    static let purpleNight = BrowserTheme(
        name: "Purple Night",
        accentHex: "#a855f7",
        tabBarHex: "#13001f",
        toolbarHex: "#1f0a2e",
        textHex: "#e9d5ff",
        isDark: true
    )
    static let solarLight = BrowserTheme(
        name: "Solar Light",
        accentHex: "#f59e0b",
        tabBarHex: "#fef9f0",
        toolbarHex: "#fffbf0",
        textHex: "#1c1917",
        isDark: false
    )
    static let cleanWhite = BrowserTheme(
        name: "Clean White",
        accentHex: "#6366f1",
        tabBarHex: "#f1f5f9",
        toolbarHex: "#ffffff",
        textHex: "#0f172a",
        isDark: false
    )

    static let presets: [BrowserTheme] = [
        .snakeGreen, .midnightBlue, .crimsonDark, .purpleNight, .solarLight, .cleanWhite
    ]
}

// MARK: - ThemeManager
class ThemeManager: ObservableObject {
    @Published var current: BrowserTheme {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "snakenet.theme"),
           let theme = try? JSONDecoder().decode(BrowserTheme.self, from: data) {
            current = theme
        } else {
            current = .snakeGreen
        }
    }

    func apply(_ theme: BrowserTheme) {
        current = theme
    }

    private func save() {
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: "snakenet.theme")
        }
    }
}

// MARK: - Color Hex Extension
extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var toHex: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
