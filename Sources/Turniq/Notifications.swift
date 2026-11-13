import Foundation
import UserNotifications

/// Avisos locales (iOS): recordatorio antes de cada turno y aviso la
/// mañana del día de cobro de cada trabajo. En iOS NO existe la
/// alarma a pantalla completa de Android — Apple reserva eso a su
/// app Reloj; aquí el aviso es una notificación con sonido.
@MainActor
enum Notifications {

    /// iOS guarda como máximo 64 avisos pendientes por app.
    private static let maxShiftNotices = 48

    nonisolated static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Reprograma todos los avisos. Se llama sola cada vez que cambian
    /// los datos (turnos, trabajos o ajustes).
    static func reschedule(store: Store) {
        reschedule(data: store.data)
    }

    static func reschedule(data: TurniqData) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let settings = data.settings
        let fmt12 = settings.formatoHora == "12h"
        let jobs = Dictionary(data.jobs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let now = Date()

        // 1. Avisos de turno — los más cercanos primero.
        var pending: [(fire: Date, id: String, title: String, body: String)] = []
        for shift in data.shifts where !shift.esLibre {
            guard let start = Calc.date(shift.fecha, shift.horaEntrada) else { continue }
            let job = jobs[shift.jobId]
            let hora = Calc.fmtTime(shift.horaEntrada, format12: fmt12)
            var body = "Tu turno empieza a las \(hora)."
            if let pin = job?.pinMarcaje, !pin.isEmpty { body += " PIN del reloj: \(pin)." }
            for aviso in settings.avisosMin {
                let fire = start.addingTimeInterval(TimeInterval(-aviso * 60))
                guard fire > now else { continue }
                pending.append((fire, "turniq-\(shift.id)-\(aviso)",
                                "Turno en \(job?.nombre ?? "Turniq")",
                                aviso == 0 ? "Es hora de tu turno (\(hora))." : body))
            }
        }
        pending.sort { $0.fire < $1.fire }
        for p in pending.prefix(maxShiftNotices) {
            add(center, id: p.id, title: p.title, body: p.body, fire: p.fire)
        }

        // 2. Aviso del día de cobro (9:00 a. m.), los 2 próximos de
        //    cada trabajo. El monto solo se dice si ya es definitivo.
        guard settings.avisoCobro else { return }
        for job in data.jobs {
            for pay in Pay.upcoming(job, shifts: data.shifts, settings: settings, count: 2) {
                guard let fire = Calc.date(pay.payday, "09:00"), fire > now else { continue }
                let body = pay.closed && pay.totals.net > 0 && !settings.dineroOculto
                    ? "Hoy cobras aproximadamente \(Calc.money(pay.totals.net)) (neto) por \(Calc.shortDate(pay.periodStart)) – \(Calc.shortDate(pay.periodEnd))."
                    : "Hoy te pagan en \(job.nombre). Abre Turniq para ver cuánto."
                add(center, id: "turniq-cobro-\(job.id)-\(pay.payday)",
                    title: "Día de cobro · \(job.nombre)", body: body, fire: fire)
            }
        }
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, title: String, body: String, fire: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
