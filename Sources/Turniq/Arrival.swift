import Foundation
import Combine
import CoreLocation
import UserNotifications

/// Pide la ubicación actual UNA vez (para guardar dónde queda un
/// trabajo). Solo usa el permiso "al usar la app".
final class LocationOnce: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: String? = nil
    @Published var busy = false

    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request(_ completion: @escaping (CLLocationCoordinate2D) -> Void) {
        self.completion = completion
        busy = true
        status = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            fail("Turniq no tiene permiso de ubicación. Actívalo en Ajustes → Turniq → Ubicación.")
        default:
            manager.requestLocation()
        }
    }

    private func fail(_ message: String) {
        busy = false
        completion = nil
        status = message
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard completion != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            fail("Turniq no tiene permiso de ubicación. Actívalo en Ajustes → Turniq → Ubicación.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate, let done = completion else { return }
        busy = false
        completion = nil
        status = "Ubicación guardada."
        done(coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fail("No pude obtener tu ubicación. Inténtalo de nuevo.")
    }
}

/// Recibe los toques en las notificaciones: el botón "Marcar entrada"
/// del aviso de llegada marca la entrada del turno de ese trabajo.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    static let arriveCategory = "TURNIQ_ARRIVE"
    static let clockInAction = "TURNIQ_CLOCK_IN"

    /// Registra el botón del aviso de llegada.
    static func registerCategories() {
        let action = UNNotificationAction(identifier: clockInAction,
                                          title: "Marcar entrada",
                                          options: [.foreground])
        let category = UNNotificationCategory(identifier: arriveCategory,
                                              actions: [action],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let jobId = response.notification.request.content.userInfo["jobId"] as? String
        Task { @MainActor in
            if action == NotificationDelegate.clockInAction, let jobId {
                Store.shared.clockInArrival(jobId: jobId)
            }
            completionHandler()
        }
    }
}
