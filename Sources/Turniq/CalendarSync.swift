import Foundation
import EventKit
import UIKit

/// Sincronización con el Calendario del iPhone (EventKit).
/// Turniq mantiene un calendario PROPIO llamado «Turniq» y copia ahí
/// los turnos y los días de cobro. Nunca toca tus otros calendarios.
/// Como vive en la app Calendario, también aparece en iCloud, en el
/// Apple Watch, en CarPlay y en los widgets de Calendario.
@MainActor
enum CalendarSync {

    static let ek = EKEventStore()
    private static let calKey = "turniq.calendarId"
    static let calendarTitle = "Turniq"

    /// Ventana que se mantiene sincronizada.
    private static let daysBack = 7
    private static let daysAhead = 60

    static var authorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// El usuario negó el permiso: solo se cambia en Ajustes de iOS.
    static var denied: Bool {
        let st = EKEventStore.authorizationStatus(for: .event)
        return st == .denied || st == .restricted
    }

    static func requestAccess() async -> Bool {
        do {
            return try await ek.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    private static func calendar(create: Bool) -> EKCalendar? {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: calKey), let c = ek.calendar(withIdentifier: id) {
            return c
        }
        if let c = ek.calendars(for: .event).first(where: {
            $0.title == calendarTitle && $0.allowsContentModifications
        }) {
            defaults.set(c.calendarIdentifier, forKey: calKey)
            return c
        }
        guard create else { return nil }
        let source: EKSource? = ek.defaultCalendarForNewEvents?.source
            ?? ek.sources.first(where: { $0.sourceType == .local })
            ?? ek.sources.first
        guard let source else { return nil }
        let c = EKCalendar(for: .event, eventStore: ek)
        c.title = calendarTitle
        c.cgColor = UIColor(red: 0.012, green: 0.573, blue: 1.0, alpha: 1).cgColor
        c.source = source
        do {
            try ek.saveCalendar(c, commit: true)
        } catch {
            return nil
        }
        defaults.set(c.calendarIdentifier, forKey: calKey)
        return c
    }

    /// Sincroniza si el usuario lo tiene activado y hay permiso.
    static func syncIfEnabled(data: TurniqData) {
        guard data.settings.calendarioSync, authorized else { return }
        sync(data: data)
    }

    /// Reescribe la ventana (-7 … +60 días) del calendario «Turniq».
    /// Devuelve cuántos eventos dejó, o nil si no se pudo.
    @discardableResult
    static func sync(data: TurniqData) -> Int? {
        guard authorized, let cal = calendar(create: true) else { return nil }
        let today = Calc.todayYmd()
        let from = Calc.addDays(today, -daysBack)
        let to = Calc.addDays(today, daysAhead)
        guard let winStart = Calc.parseDay(from),
              let winEnd = Calc.parseDay(Calc.addDays(to, 1)) else { return nil }

        // 1. Limpia lo que había en la ventana (solo en NUESTRO calendario).
        let pred = ek.predicateForEvents(withStart: winStart, end: winEnd, calendars: [cal])
        for ev in ek.events(matching: pred) {
            try? ek.remove(ev, span: .thisEvent, commit: false)
        }

        let jobs = Dictionary(data.jobs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var count = 0

        // 2. Turnos.
        for s in data.shifts where s.fecha >= from && s.fecha <= to {
            let job = jobs[s.jobId]
            let ev = EKEvent(eventStore: ek)
            ev.calendar = cal
            if s.esLibre {
                guard let day = Calc.parseDay(s.fecha) else { continue }
                ev.title = "Día libre"
                ev.isAllDay = true
                ev.startDate = day
                ev.endDate = day
            } else {
                guard let start = Calc.date(s.fecha, s.horaEntrada) else { continue }
                var end = start.addingTimeInterval(3600)
                if let out = s.horaSalida, let e = Calc.date(Calc.endDate(s), out), e > start {
                    end = e
                }
                let stations = s.estacionIds.compactMap { id in
                    job?.estaciones.first(where: { $0.id == id })?.nombre
                }
                var title = job?.nombre ?? "Turno"
                if !stations.isEmpty { title += " · " + stations.joined(separator: ", ") }
                ev.title = title
                ev.startDate = start
                ev.endDate = end
                var notes: [String] = []
                if let pin = job?.pinMarcaje, !pin.isEmpty { notes.append("PIN del reloj: \(pin)") }
                if s.breakMin > 0 { notes.append("Descanso: \(s.breakMin) min") }
                if !s.notas.isEmpty { notes.append(s.notas) }
                notes.append("Creado por Turniq")
                ev.notes = notes.joined(separator: "\n")
            }
            if (try? ek.save(ev, span: .thisEvent, commit: false)) != nil { count += 1 }
        }

        // 3. Días de cobro (evento de todo el día, sin montos: el
        //    calendario puede estar compartido).
        for job in data.jobs {
            var day = Pay.nextPayday(job, settings: data.settings, from: today)
            while day <= to {
                if let d = Calc.parseDay(day) {
                    let ev = EKEvent(eventStore: ek)
                    ev.calendar = cal
                    ev.title = "Cobro · \(job.nombre)"
                    ev.isAllDay = true
                    ev.startDate = d
                    ev.endDate = d
                    let p = Pay.period(job, payday: day)
                    ev.notes = "Periodo: \(Calc.shortDate(p.start)) – \(Calc.shortDate(p.end))\nCreado por Turniq"
                    if (try? ek.save(ev, span: .thisEvent, commit: false)) != nil { count += 1 }
                }
                day = Calc.addDays(day, Pay.freq(job).days)
            }
        }

        do {
            try ek.commit()
        } catch {
            ek.reset()
            return nil
        }
        return count
    }

    /// Borra el calendario «Turniq» entero (al desactivar la función).
    static func removeCalendar() {
        guard authorized, let cal = calendar(create: false) else { return }
        try? ek.removeCalendar(cal, commit: true)
        UserDefaults.standard.removeObject(forKey: calKey)
    }
}
