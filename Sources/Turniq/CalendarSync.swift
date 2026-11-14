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

    /// Motivo del último fallo, para mostrarlo en pantalla.
    static private(set) var lastError: String? = nil

    /// Marca de los eventos creados por Turniq (para no tocar otros).
    private static let marker = URL(string: "turniq://abrir")

    /// ¿El calendario es el propio «Turniq»? Si no se pudo crear uno
    /// (hay cuentas que no lo permiten) se usa el calendario por
    /// defecto del usuario y solo se tocan los eventos marcados.
    private static func isOwn(_ cal: EKCalendar) -> Bool {
        cal.title == calendarTitle
    }

    /// Nombre del calendario donde quedaron los eventos, si NO es el
    /// propio «Turniq».
    static var fallbackCalendarName: String? {
        guard authorized, let cal = calendar(create: false), !isOwn(cal) else { return nil }
        return cal.title
    }

    private static func calendar(create: Bool) -> EKCalendar? {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: calKey), let c = ek.calendar(withIdentifier: id),
           c.allowsContentModifications {
            return c
        }
        if let c = ek.calendars(for: .event).first(where: {
            $0.title == calendarTitle && $0.allowsContentModifications
        }) {
            defaults.set(c.calendarIdentifier, forKey: calKey)
            return c
        }
        guard create else { return nil }

        // No todas las cuentas dejan crear calendarios (Google y
        // Exchange suelen negarlo), así que se prueba una por una:
        // iCloud, local, la cuenta por defecto y el resto.
        var sources: [EKSource] = []
        let all = ek.sources
        sources += all.filter { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }
        sources += all.filter { $0.sourceType == .local }
        if let def = ek.defaultCalendarForNewEvents?.source { sources.append(def) }
        sources += all.filter { $0.sourceType == .calDAV || $0.sourceType == .exchange }
        var seen = Set<String>()
        sources = sources.filter { seen.insert($0.sourceIdentifier).inserted }

        var failure = "sin cuentas de calendario"
        for source in sources {
            let c = EKCalendar(for: .event, eventStore: ek)
            c.title = calendarTitle
            c.cgColor = UIColor(red: 0.012, green: 0.573, blue: 1.0, alpha: 1).cgColor
            c.source = source
            do {
                try ek.saveCalendar(c, commit: true)
                defaults.set(c.calendarIdentifier, forKey: calKey)
                return c
            } catch {
                failure = "\(source.title): \(error.localizedDescription)"
                ek.reset()
            }
        }

        // Último recurso: el calendario por defecto del usuario.
        if let def = ek.defaultCalendarForNewEvents, def.allowsContentModifications {
            defaults.set(def.calendarIdentifier, forKey: calKey)
            return def
        }
        lastError = failure
        return nil
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
        lastError = nil
        guard authorized else {
            lastError = "sin permiso de acceso total al Calendario"
            return nil
        }
        guard let cal = calendar(create: true) else { return nil }
        let own = isOwn(cal)
        let today = Calc.todayYmd()
        let from = Calc.addDays(today, -daysBack)
        let to = Calc.addDays(today, daysAhead)
        guard let winStart = Calc.parseDay(from),
              let winEnd = Calc.parseDay(Calc.addDays(to, 1)) else { return nil }

        // 1. Limpia lo que había en la ventana (solo en NUESTRO calendario).
        let pred = ek.predicateForEvents(withStart: winStart, end: winEnd, calendars: [cal])
        for ev in ek.events(matching: pred) where own || ev.url?.scheme == "turniq" {
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
                ev.title = L("Día libre")
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
                var title = job?.nombre ?? L("Turno")
                if !stations.isEmpty { title += " · " + stations.joined(separator: ", ") }
                ev.title = title
                ev.startDate = start
                ev.endDate = end
                var notes: [String] = []
                if let pin = job?.pinMarcaje, !pin.isEmpty { notes.append(L("PIN del reloj: \(pin)")) }
                if s.breakMin > 0 { notes.append(L("Descanso: \(s.breakMin) min")) }
                if !s.notas.isEmpty { notes.append(s.notas) }
                notes.append(L("Creado por Turniq"))
                ev.notes = notes.joined(separator: "\n")
            }
            ev.url = marker
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
                    ev.title = L("Cobro · \(job.nombre)")
                    ev.isAllDay = true
                    ev.startDate = d
                    ev.endDate = d
                    let p = Pay.period(job, payday: day)
                    ev.notes = L("Periodo: \(Calc.shortDate(p.start)) – \(Calc.shortDate(p.end))\nCreado por Turniq")
                    ev.url = marker
            if (try? ek.save(ev, span: .thisEvent, commit: false)) != nil { count += 1 }
                }
                day = Calc.addDays(day, Pay.freq(job).days)
            }
        }

        do {
            try ek.commit()
        } catch {
            lastError = error.localizedDescription
            ek.reset()
            return nil
        }
        return count
    }

    /// Borra el calendario «Turniq» entero (al desactivar la función).
    static func removeCalendar() {
        guard authorized, let cal = calendar(create: false) else { return }
        if isOwn(cal) {
            try? ek.removeCalendar(cal, commit: true)
        } else {
            // Calendario del usuario: solo se quitan los eventos de Turniq.
            let now = Date()
            let pred = ek.predicateForEvents(withStart: now.addingTimeInterval(-370 * 86400),
                                             end: now.addingTimeInterval(370 * 86400), calendars: [cal])
            for ev in ek.events(matching: pred) where ev.url?.scheme == "turniq" {
                try? ek.remove(ev, span: .thisEvent, commit: false)
            }
            try? ek.commit()
        }
        UserDefaults.standard.removeObject(forKey: calKey)
    }
}
