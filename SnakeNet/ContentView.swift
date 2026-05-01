import SwiftUI
import WebKit
import Combine

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject var tabManager = TabManager()
    @State private var addressText: String = ""
    @State private var addressBarFocused: Bool = false
    @State private var showThemePanel: Bool = false
    @FocusState private var isAddressFocused: Bool

    var selectedTab: BrowserTab? { tabManager.selectedTab }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Tab Bar
            TabBarView(tabManager: tabManager)
                .background(themeManager.current.tabBarColor)

            // MARK: Toolbar
            ToolbarView(
                tab: selectedTab,
                addressText: $addressText,
                isAddressFocused: _isAddressFocused,
                showThemePanel: $showThemePanel,
                onLoad: { loadURL() },
                onBack: { selectedTab?.webView?.goBack() },
                onForward: { selectedTab?.webView?.goForward() },
                onReload: { reloadOrStop() },
                onHome: { goHome() },
                onNewTab: { tabManager.addTab() }
            )
            .background(themeManager.current.toolbarColor)

            Divider().opacity(0.3)

            // MARK: Progress Bar
            ProgressBarView(tab: selectedTab)

            // MARK: Web Views (stacked, only selected is visible)
            ZStack {
                ForEach(tabManager.tabs) { tab in
                    WebView(tab: tab)
                        .opacity(tab.id == tabManager.selectedTabID ? 1 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showThemePanel) {
            ThemePanel()
                .environmentObject(themeManager)
        }
        .onChange(of: tabManager.selectedTabID) { _ in
            updateAddressBar()
        }
        .onReceive(tabManager.$tabs) { _ in
            updateAddressBar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
            tabManager.addTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
            if let tab = selectedTab { tabManager.closeTab(tab) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadPage)) { _ in
            reloadOrStop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusAddressBar)) { _ in
            isAddressFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .goBack)) { _ in
            selectedTab?.webView?.goBack()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goForward)) { _ in
            selectedTab?.webView?.goForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTheme)) { _ in
            showThemePanel = true
        }
        .preferredColorScheme(themeManager.current.isDark ? .dark : .light)
    }

    // MARK: - Actions
    private func updateAddressBar() {
        if let tab = selectedTab {
            addressText = tab.url == "snakenet://home" ? "" : tab.url
        }
    }

    private func loadURL() {
        guard let tab = selectedTab else { return }
        var raw = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return }
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            if raw.contains(".") && !raw.contains(" ") {
                raw = "https://" + raw
            } else {
                let q = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
                raw = "https://www.google.com/search?q=\(q)"
            }
        }
        tab.url = raw
        addressText = raw
        if let url = URL(string: raw) {
            tab.webView?.load(URLRequest(url: url))
        }
        isAddressFocused = false
    }

    private func reloadOrStop() {
        guard let tab = selectedTab else { return }
        if tab.isLoading {
            tab.webView?.stopLoading()
        } else {
            tab.webView?.reload()
        }
    }

    private func goHome() {
        guard let tab = selectedTab else { return }
        tab.isHomePage = true
        tab.url = "snakenet://home"
        addressText = ""
        if let wv = tab.webView {
            WebView.loadHomePage(webView: wv)
        }
    }
}

// MARK: - Tab Bar View
struct TabBarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var tabManager: TabManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    TabChip(
                        tab: tab,
                        isSelected: tab.id == tabManager.selectedTabID,
                        onSelect: { tabManager.selectTab(tab) },
                        onClose: { tabManager.closeTab(tab) }
                    )
                }

                // New Tab button
                Button(action: { tabManager.addTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeManager.current.textColor.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
                .help("New Tab (⌘T)")

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 0)
        }
        .frame(height: 38)
    }
}

// MARK: - Tab Chip
struct TabChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var tab: BrowserTab
    var isSelected: Bool
    var onSelect: () -> Void
    var onClose: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            // Favicon or spinner
            Group {
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else if let img = tab.favicon {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.current.textColor.opacity(0.5))
                        .frame(width: 14, height: 14)
                }
            }

            // Tab title
            Text(tab.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(themeManager.current.textColor.opacity(isSelected ? 1 : 0.65))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            // Close button
            if isHovered || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(themeManager.current.textColor.opacity(0.7))
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(themeManager.current.textColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 180, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected
                      ? themeManager.current.toolbarColor
                      : themeManager.current.tabBarColor)
                .shadow(color: isSelected ? .black.opacity(0.15) : .clear, radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected
                        ? themeManager.current.accentColor.opacity(0.4)
                        : Color.clear,
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .padding(.trailing, 2)
    }
}

// MARK: - Toolbar View
struct ToolbarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    var tab: BrowserTab?
    @Binding var addressText: String
    @FocusState var isAddressFocused: Bool
    @Binding var showThemePanel: Bool
    var onLoad: () -> Void
    var onBack: () -> Void
    var onForward: () -> Void
    var onReload: () -> Void
    var onHome: () -> Void
    var onNewTab: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Back
            NavButton(icon: "chevron.left", action: onBack,
                      enabled: tab?.canGoBack ?? false, theme: themeManager.current)
            // Forward
            NavButton(icon: "chevron.right", action: onForward,
                      enabled: tab?.canGoForward ?? false, theme: themeManager.current)
            // Reload/Stop
            NavButton(
                icon: (tab?.isLoading ?? false) ? "xmark" : "arrow.clockwise",
                action: onReload, enabled: true, theme: themeManager.current
            )
            // Home
            NavButton(icon: "house", action: onHome, enabled: true, theme: themeManager.current)

            // Address Bar
            HStack(spacing: 6) {
                // Lock/Globe icon
                Image(systemName: addressText.hasPrefix("https") ? "lock.fill" : "globe")
                    .font(.system(size: 11))
                    .foregroundColor(
                        addressText.hasPrefix("https")
                        ? themeManager.current.accentColor
                        : themeManager.current.textColor.opacity(0.4)
                    )
                    .frame(width: 16)

                TextField("Search or enter URL", text: $addressText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.current.textColor)
                    .focused($isAddressFocused)
                    .onSubmit { onLoad() }
                    .onTapGesture { isAddressFocused = true }

                if !addressText.isEmpty && isAddressFocused {
                    Button(action: { addressText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.current.textColor.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(themeManager.current.tabBarColor.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isAddressFocused
                        ? themeManager.current.accentColor
                        : themeManager.current.textColor.opacity(0.15),
                        lineWidth: isAddressFocused ? 1.5 : 0.75
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isAddressFocused)

            // Theme button
            Button(action: { showThemePanel = true }) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(themeManager.current.accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(themeManager.current.accentColor.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .help("Customize Theme (⌘,)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Nav Button
struct NavButton: View {
    let icon: String
    let action: () -> Void
    let enabled: Bool
    let theme: BrowserTheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(
                    enabled
                    ? (isHovered ? theme.accentColor : theme.textColor.opacity(0.75))
                    : theme.textColor.opacity(0.25)
                )
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovered && enabled
                              ? theme.accentColor.opacity(0.12)
                              : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Progress Bar
struct ProgressBarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var tab: BrowserTab

    // dummy fallback if nil
    init(tab: BrowserTab?) {
        _tab = ObservedObject(wrappedValue: tab ?? BrowserTab())
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if tab.isLoading {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.current.accentColor,
                                    themeManager.current.accentColor.opacity(0.5)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * tab.loadingProgress)
                        .animation(.linear(duration: 0.25), value: tab.loadingProgress)
                }
            }
        }
        .frame(height: tab.isLoading ? 3 : 0)
        .animation(.easeInOut(duration: 0.2), value: tab.isLoading)
    }
}

// MARK: - Theme Panel
struct ThemePanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var customAccent: Color = .green
    @State private var customTabBar: Color = Color(NSColor.windowBackgroundColor)
    @State private var customToolbar: Color = Color(NSColor.windowBackgroundColor)
    @State private var customText: Color = .primary
    @State private var customIsDark: Bool = true
    @State private var customName: String = "My Theme"
    @State private var selectedPreset: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "snake")
                    .font(.title2)
                    .foregroundColor(themeManager.current.accentColor)
                Text("SnakeNet Theme Studio")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeManager.current.textColor)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.current.textColor.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(themeManager.current.tabBarColor)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Preset Themes
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Presets", systemImage: "swatchpalette")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.current.textColor.opacity(0.6))

                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 10) {
                            ForEach(BrowserTheme.presets) { preset in
                                PresetCard(
                                    theme: preset,
                                    isSelected: themeManager.current.name == preset.name
                                ) {
                                    themeManager.apply(preset)
                                    syncCustomFields(from: preset)
                                    selectedPreset = preset.id
                                }
                            }
                        }
                    }

                    Divider().opacity(0.3)

                    // Custom Builder
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Custom Theme", systemImage: "pencil.and.ruler")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.current.textColor.opacity(0.6))

                        TextField("Theme name", text: $customName)
                            .textFieldStyle(.roundedBorder)

                        Group {
                            ColorRow(label: "Accent Color", color: $customAccent)
                            ColorRow(label: "Tab Bar", color: $customTabBar)
                            ColorRow(label: "Toolbar", color: $customToolbar)
                            ColorRow(label: "Text Color", color: $customText)
                        }

                        Toggle("Dark Mode", isOn: $customIsDark)
                            .foregroundColor(themeManager.current.textColor)

                        Button(action: applyCustom) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Apply Custom Theme")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.current.accentColor)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 440, height: 600)
        .background(themeManager.current.toolbarColor)
        .onAppear {
            syncCustomFields(from: themeManager.current)
        }
    }

    private func syncCustomFields(from theme: BrowserTheme) {
        customAccent = theme.accentColor
        customTabBar = theme.tabBarColor
        customToolbar = theme.toolbarColor
        customText = theme.textColor
        customIsDark = theme.isDark
        customName = theme.name
    }

    private func applyCustom() {
        let theme = BrowserTheme(
            name: customName,
            accentHex: customAccent.toHex,
            tabBarHex: customTabBar.toHex,
            toolbarHex: customToolbar.toHex,
            textHex: customText.toHex,
            isDark: customIsDark
        )
        themeManager.apply(theme)
    }
}

// MARK: - Preset Card
struct PresetCard: View {
    let theme: BrowserTheme
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach([theme.accentColor, theme.tabBarColor, theme.toolbarColor], id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(c)
                            .frame(height: 18)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))

                Text(theme.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.tabBarColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(hovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.2), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Color Row
struct ColorRow: View {
    let label: String
    @Binding var color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 110, alignment: .leading)
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
            Spacer()
        }
    }
}
