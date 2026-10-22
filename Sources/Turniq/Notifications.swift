import Foundation
import UserNotifications

/// Avisos locales de turno (iOS): notificaciones programadas según
/// los minutos de aviso de Ajustes. En iOS NO existe la alarma a
/// pantalla completa de Android — Apple reserva eso a su app Reloj;
/// aquí el aviso es una notificación con sonido.
enum Notifications {

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Reprograma los avisos de los turnos futuros (se llama al
    /// guardar/borrar turnos y al cambiar los minutos de aviso).
    static func reschedule(store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let settings = store.settings
        let now = Date()
        for shift in store.shifts where !shift.esLibre {
            guard let day = Calc.parseDay(shift.fecha),
                  let startMin = Calc.hmToMin(shift.horaEntrada) else { continue }
            let start = day.addingTimeInterval(TimeInterval(startMin * 60))
            for aviso in settings.avisosMin {
                let fire = start.addingTimeInterval(TimeInterval(-aviso * 60))
                guard fire > now else { continue }
                let content = UNMutableNotificationContent()
                let jobName = store.job(id: shift.jobId)?.nombre ?? "Turniq"
                content.title = "Turno en \(jobName)"
                content.body = aviso == 0
                    ? "Es hora de tu turno (\(shift.horaEntrada))."
                    : "Tu turno empieza a las \(shift.horaEntrada)."
                content.sound = .default
                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let req = UNNotificationRequest(
                    identifier: "turniq-\(shift.id)-\(aviso)",
                    content: content, trigger: trigger)
                center.add(req)
            }
        }
    }
}
