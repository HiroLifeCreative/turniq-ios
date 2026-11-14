import SwiftUI
import UserNotifications

@main
struct TurniqApp: App {
    @StateObject private var store = Store.shared
    @State private var linkMessage: String? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false

    init() {
        FontReg.register()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationDelegate.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.settings.pin != nil && !unlocked {
                    PinLockView { unlocked = true }
                } else if !store.settings.onboardingDone {
                    OnboardingView()
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
            // Enlaces turniq:// desde Atajos, Siri, el Botón de Acción
            // o los widgets.
            .onOpenURL { url in
                if let msg = store.handleURL(url) { linkMessage = msg }
            }
            .alert("Turniq", isPresented: Binding(
                get: { linkMessage != nil },
                set: { if !$0 { linkMessage = nil } }
            )) {
                Button("OK", role: .cancel) { linkMessage = nil }
            } message: {
                Text(linkMessage ?? "")
            }
        }
    }
}
