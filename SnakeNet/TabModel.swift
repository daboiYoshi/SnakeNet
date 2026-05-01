import SwiftUI
import WebKit
import Combine

// MARK: - Tab Model
class BrowserTab: ObservableObject, Identifiable {
    let id: UUID = UUID()

    @Published var title: String = "New Tab"
    @Published var url: String = "snakenet://home"
    @Published var favicon: NSImage? = nil
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    var webView: WKWebView?
    var isHomePage: Bool

    init(home: Bool = true) {
        self.isHomePage = home
    }
}

// MARK: - TabManager
class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabID: UUID?

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    init() {
        addTab()
    }

    @discardableResult
    func addTab() -> BrowserTab {
        let tab = BrowserTab(home: true)
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    func closeTab(_ tab: BrowserTab) {
        guard tabs.count > 1 else { return }
        if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
            let wasSelected = selectedTabID == tab.id
            tabs.remove(at: idx)
            if wasSelected {
                let newIdx = min(idx, tabs.count - 1)
                selectedTabID = tabs[newIdx].id
            }
        }
    }

    func selectTab(_ tab: BrowserTab) {
        selectedTabID = tab.id
    }
}
