import Foundation
import UserNotifications
import CoreLocation

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
        reschedule(all: [data])
    }

    /// Bandera que se antepone al título cuando se avisa de varias cuentas.
    private static var tag = ""

    /// Reprograma los avisos de una o varias cuentas. La primera es
    /// la que está en uso; las demás solo se pasan si el usuario
    /// activó «Avisos de todas las cuentas».
    static func reschedule(all: [TurniqData]) {
        let center = UNUserNotificationCenter.current()
        // El botón del aviso de llegada sigue el idioma de la app.
        NotificationDelegate.registerCategories()
        center.removeAllPendingNotificationRequests()
        // iOS admite 64 avisos pendientes: se reparten entre las cuentas.
        let limit = max(8, maxShiftNotices / max(1, all.count))
        for (i, data) in all.enumerated() {
            tag = all.count > 1 ? Countries.country(data.settings.pais).flag + " " : ""
            // Los montos solo se escriben para la cuenta en uso, que es
            // la que tiene cargada su moneda.
            schedule(data, center: center, limit: limit, amounts: i == 0)
        }
        tag = ""
    }

    private static func schedule(_ data: TurniqData, center: UNUserNotificationCenter,
                                 limit: Int, amounts: Bool) {
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
            var body = L("Tu turno empieza a las \(hora).")
            if let pin = job?.pinMarcaje, !pin.isEmpty { body += L(" PIN del reloj: \(pin).") }
            for aviso in settings.avisosMin {
                let fire = start.addingTimeInterval(TimeInterval(-aviso * 60))
                guard fire > now else { continue }
                pending.append((fire, "turniq-\(shift.id)-\(aviso)",
                                L("Turno en \(job?.nombre ?? "Turniq")"),
                                aviso == 0 ? L("Es hora de tu turno (\(hora)).") : body))
            }
        }
        pending.sort { $0.fire < $1.fire }
        for p in pending.prefix(limit) {
            add(center, id: p.id, title: p.title, body: p.body, fire: p.fire)
        }

        // 2. Aviso al llegar al trabajo: solo para trabajos con
        //    ubicación guardada y algún turno pendiente (hoy o después).
        if settings.avisoLlegada {
            let today = Calc.todayYmd()
            for job in data.jobs {
                guard let lat = job.lat, let lon = job.lon else { continue }
                let hasShift = data.shifts.contains {
                    $0.jobId == job.id && !$0.esLibre && $0.fecha >= today && $0.horaEntradaReal == nil
                }
                guard hasShift else { continue }
                let region = CLCircularRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    radius: 150, identifier: "turniq-llegada-\(job.id)")
                region.notifyOnEntry = true
                region.notifyOnExit = false
                let content = UNMutableNotificationContent()
                content.title = L("¿Llegaste a \(job.nombre)?")
                var body = L("Toca «Marcar entrada» para empezar tu turno.")
                if let pin = job.pinMarcaje, !pin.isEmpty { body += L(" PIN del reloj: \(pin).") }
                content.body = body
                content.sound = .default
                content.categoryIdentifier = NotificationDelegate.arriveCategory
                content.userInfo = ["jobId": job.id]
                let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
                center.add(UNNotificationRequest(identifier: "turniq-llegada-\(job.id)",
                                                 content: content, trigger: trigger))
            }
        }

        // 3. Aviso de hora extra: al empezar el turno con el que un
        //    trabajo llega a 4 h o menos del umbral semanal.
        if settings.avisoHoraExtra, settings.umbralExtraHrs > 0 {
            let umbral = settings.umbralExtraHrs
            let warnAt = max(0, umbral - 4)
            let thisWeek = Calc.monday(of: Calc.todayYmd())
            for monday in [thisWeek, Calc.addDays(thisWeek, 7)] {
                for job in data.jobs {
                    let week = data.shifts
                        .filter { $0.jobId == job.id && !$0.esLibre && Calc.monday(of: $0.fecha) == monday }
                        .sorted { ($0.fecha + $0.horaEntrada) < ($1.fecha + $1.horaEntrada) }
                    var total = 0.0
                    for s in week {
                        let before = total
                        total += Calc.projectedHours(s)
                        guard before < warnAt, total >= warnAt else { continue }
                        if let start = Calc.date(s.fecha, s.horaEntrada), start > now {
                            let body = total > umbral
                                ? L("Con este turno llegarás a \(Calc.fmtHoursLong(total)) esta semana: pasarás de las \(Calc.fmtHoursLong(umbral)) y entrarás en hora extra.")
                                : L("Con este turno llegarás a \(Calc.fmtHoursLong(total)) esta semana. La hora extra empieza a las \(Calc.fmtHoursLong(umbral)).")
                            add(center, id: "turniq-extra-\(job.id)-\(monday)",
                                title: L("Hora extra cerca · \(job.nombre)"), body: body, fire: start)
                        }
                        break
                    }
                }
            }
        }

        // 4. Aviso del día de cobro (9:00 a. m.), los 2 próximos de
        //    cada trabajo. El monto solo se dice si ya es definitivo.
        guard settings.avisoCobro else { return }
        for job in data.jobs {
            for pay in Pay.upcoming(job, shifts: data.shifts, settings: settings, count: 2) {
                guard let fire = Calc.date(pay.payday, "09:00"), fire > now else { continue }
                let body = amounts && pay.closed && pay.totals.net > 0 && !settings.dineroOculto
                    ? L("Hoy cobras aproximadamente \(Calc.money(pay.totals.net)) (neto) por \(Calc.shortDate(pay.periodStart)) – \(Calc.shortDate(pay.periodEnd)).")
                    : L("Hoy te pagan en \(job.nombre). Abre Turniq para ver cuánto.")
                add(center, id: "turniq-cobro-\(job.id)-\(pay.payday)",
                    title: L("Día de cobro · \(job.nombre)"), body: body, fire: fire)
            }
        }
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, title: String, body: String, fire: Date) {
        let content = UNMutableNotificationContent()
        content.title = tag + title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
