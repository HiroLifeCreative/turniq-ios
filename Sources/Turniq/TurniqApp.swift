import SwiftUI

@main
struct TurniqApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false

    init() {
        FontReg.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.settings.pin != nil && !unlocked {
                    PinLockView { unlocked = true }
                } else {
                    TurniqShell()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(store.settings.dark ? .dark : .light)
            .tint(T.primary)
            .onAppear {
                Notifications.requestAuthorization()
                store.refreshOnForeground()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.refreshOnForeground() }
            }
        }
    }
}
