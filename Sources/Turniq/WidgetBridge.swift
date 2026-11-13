import Foundation
import WidgetKit
import ActivityKit
import TurniqShared

/// Puente hacia la extensión de Widgets: escribe la foto de datos en
/// la carpeta compartida y pide a iOS que redibuje los widgets.
@MainActor
enum WidgetBridge {

    static func update(data: TurniqData) {
        let now = Date()
        let today = Calc.todayYmd()
        let monday = Calc.monday(of: today)
        guard let weekStart = Calc.parseDay(monday),
              let weekEnd = Calc.parseDay(Calc.addDays(monday, 7)) else { return }
        let settings = data.settings
        let jobs = Dictionary(data.jobs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        let week = Calc.onlyWorked(data.shifts.filter { Calc.monday(of: $0.fecha) == monday })
        let totals = Calc.weekTotals(shifts: week, jobsById: jobs,
                                     umbralExtraHrs: settings.umbralExtraHrs,
                                     multExtra: settings.multExtra)

        // Turnos que aún no terminan, del más cercano al más lejano.
        var items: [WidgetSnapshot.ShiftItem] = []
        let from = Calc.addDays(today, -1)
        for s in data.shifts where !s.esLibre && s.fecha >= from {
            guard let start = Calc.date(s.fecha, s.horaEntrada) else { continue }
            let end = s.horaSalida.flatMap { Calc.date(Calc.endDate(s), $0) }
            guard (end ?? start) > now else { continue }
            let job = jobs[s.jobId]
            items.append(WidgetSnapshot.ShiftItem(
                id: s.id, jobName: job?.nombre ?? "Turno",
                colorHex: job?.color ?? "#0064E0",
                start: start, end: end, pin: job?.pinMarcaje))
        }
        items.sort { $0.start < $1.start }

        var pays: [WidgetSnapshot.PayItem] = []
        for job in data.jobs {
            for p in Pay.upcoming(job, shifts: data.shifts, settings: settings, count: 2) {
                guard let day = Calc.parseDay(p.payday) else { continue }
                pays.append(WidgetSnapshot.PayItem(
                    id: p.id, jobName: job.nombre, colorHex: job.color,
                    payday: day, net: p.totals.net, closed: p.closed))
            }
        }
        pays.sort { $0.payday < $1.payday }

        let snapshot = WidgetSnapshot(
            generatedAt: now, weekStart: weekStart, weekEnd: weekEnd,
            weekNet: totals.net, weekHours: totals.hours,
            hideMoney: settings.dineroOculto,
            format12: settings.formatoHora == "12h",
            shifts: Array(items.prefix(12)), pays: Array(pays.prefix(6)))
        if snapshot.save() {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

/// Actividad en Vivo del turno en curso: se inicia al marcar entrada
/// y se cierra al marcar salida.
@MainActor
enum LiveShift {

    static func sync(data: TurniqData) {
        let running = Activity<ShiftActivityAttributes>.activities
        let open = data.shifts
            .filter { $0.horaEntradaReal != nil && $0.horaSalidaReal == nil && !$0.esLibre }
            .sorted { $0.fecha > $1.fecha }
            .first

        guard data.settings.actividadEnVivo,
              let s = open,
              let realIn = s.horaEntradaReal,
              let start = Calc.date(s.fecha, realIn) else {
            end(running)
            return
        }

        let job = data.jobs.first { $0.id == s.jobId }
        var scheduledEnd: Date? = nil
        if let out = s.horaSalida, let e = Calc.date(Calc.endDate(s), out), e > start {
            scheduledEnd = e
        }
        let rate = (job?.sueldoHora ?? 0) * (1 - (job?.taxPct ?? 0) / 100)
        let state = ShiftActivityAttributes.ContentState(
            start: start, scheduledEnd: scheduledEnd,
            netPerHour: rate, hideMoney: data.settings.dineroOculto)
        let content = ActivityContent(state: state, staleDate: nil)

        if let current = running.first(where: { $0.attributes.shiftId == s.id }) {
            end(running.filter { $0.id != current.id })
            Task { await current.update(content) }
            return
        }

        end(running)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ShiftActivityAttributes(
            shiftId: s.id, jobName: job?.nombre ?? "Turno",
            colorHex: job?.color ?? "#0064E0", pin: job?.pinMarcaje)
        _ = try? Activity<ShiftActivityAttributes>.request(
            attributes: attributes, content: content, pushType: nil)
    }

    private static func end(_ list: [Activity<ShiftActivityAttributes>]) {
        for a in list {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
