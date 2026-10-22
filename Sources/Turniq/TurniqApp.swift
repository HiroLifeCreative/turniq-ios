import SwiftUI

@main
struct TurniqApp: App {
    @StateObject private var store = Store()
    @State private var unlocked = false

    var body: some Scene {
        WindowGroup {
            Group {
                if needsLock && !unlocked {
                    PinLockView { unlocked = true }
                } else {
                    TabView {
                        HomeView()
                            .tabItem { Label("Inicio", systemImage: "house.fill") }
                        WeekView()
                            .tabItem { Label("Semana", systemImage: "calendar") }
                        JobsView()
                            .tabItem { Label("Trabajos", systemImage: "briefcase.fill") }
                        EarningsView()
                            .tabItem { Label("Ganancias", systemImage: "chart.bar.fill") }
                        SettingsView()
                            .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
                    }
                    .tint(T.button)
                }
            }
            .environmentObject(store)
            .preferredColorScheme(store.settings.dark ? .dark : .light)
            .onAppear {
                if store.settings.pin == nil { unlocked = true }
            }
        }
    }

    private var needsLock: Bool { store.settings.pin != nil }
}
