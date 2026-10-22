import SwiftUI

@main
struct TurniqApp: App {
    @StateObject private var store = Store()
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
            .onAppear {
                Notifications.requestAuthorization()
            }
        }
    }
}
