import Foundation

// MARK: - Cobro por trabajo
// Cada trabajo paga con su propio ritmo y su propia espera:
//   · frecuencia: semanal (un cobro por semana trabajada) o quincenal
//     (un cobro cada 14 días que paga 2 semanas lun–dom).
//   · espera (pagoRetraso): cuántas semanas pasan desde que termina
//     la semana trabajada hasta el cobro.
//       1 → trabajo 2–8 nov, cobro el viernes 13 (semana siguiente)
//       2 → trabajo 2–8 nov, cobro el viernes 20 (pasan 2 semanas)
// El periodo pagado siempre son semanas completas lunes–domingo.

enum PayFreq: String, CaseIterable, Identifiable {
    case semanal
    case quincenal

    var id: String { rawValue }
    var label: String { self == .semanal ? "Cada semana" : "Cada 2 semanas" }
    var days: Int { self == .semanal ? 7 : 14 }
    var weeks: Int { self == .semanal ? 1 : 2 }
}

/// Un cobro concreto de un trabajo.
struct PayInfo: Identifiable {
    var job: Job
    /// Día de cobro "YYYY-MM-DD"
    var payday: String
    /// Lunes en que empieza el periodo que se paga
    var periodStart: String
    /// Domingo en que termina
    var periodEnd: String
    /// Lo trabajado en ese periodo (solo turnos ya trabajados)
    var totals: Calc.WeekTotals
    /// El periodo ya terminó: el monto es definitivo
    var closed: Bool
    /// Días que faltan para cobrar (0 = hoy)
    var daysLeft: Int

    var id: String { job.id + payday }

    var whenLabel: String {
        switch daysLeft {
        case 0: return "Hoy"
        case 1: return "Mañana"
        default: return "En \(daysLeft) días"
        }
    }
}

enum Pay {

    static func freq(_ job: Job) -> PayFreq {
        PayFreq(rawValue: job.pagoFrecuencia ?? "") ?? .semanal
    }

    /// Día de la semana en que paga el trabajo (0=lunes … 6=domingo).
    static func weekday(_ job: Job, settings: Settings) -> Int {
        if freq(job) == .quincenal, let a = job.pagoAncla, Calc.parseDay(a) != nil {
            return Calc.weekdayIndex(a)
        }
        let d = job.pagoDia ?? settings.diaCobro
        return min(6, max(0, d))
    }

    /// Primer día de cobro del trabajo en o después de `from`.
    static func nextPayday(_ job: Job, settings: Settings, from: String) -> String {
        let wd = weekday(job, settings: settings)
        switch freq(job) {
        case .semanal:
            let delta = ((wd - Calc.weekdayIndex(from)) + 7) % 7
            return Calc.addDays(from, delta)
        case .quincenal:
            // Sin fecha de referencia se usa una fija, para que la
            // quincena no cambie de semana de un día para otro.
            var anchor = Calc.addDays("2024-01-01", wd)
            if let a = job.pagoAncla, Calc.parseDay(a) != nil { anchor = a }
            let diff = Calc.daysBetween(anchor, from)
            let rem = ((diff % 14) + 14) % 14
            return Calc.addDays(from, rem == 0 ? 0 : 14 - rem)
        }
    }

    /// Semanas de espera entre el fin del periodo y el cobro (1…4).
    static func lag(_ job: Job) -> Int {
        min(4, max(1, job.pagoRetraso ?? 1))
    }

    static func lagLabel(_ weeks: Int) -> String {
        weeks <= 1 ? "La semana siguiente" : "\(weeks) semanas después"
    }

    /// Periodo (lunes … domingo) que paga un día de cobro: termina el
    /// domingo de `lag` semanas antes de la semana del cobro.
    static func period(_ job: Job, payday: String) -> (start: String, end: String) {
        let payMonday = Calc.monday(of: payday)
        let end = Calc.addDays(payMonday, -1 - 7 * (lag(job) - 1))
        let start = Calc.addDays(end, -(7 * freq(job).weeks - 1))
        return (start, end)
    }

    /// Detalle de un cobro: periodo y monto trabajado.
    static func info(_ job: Job, payday: String, shifts: [Shift], settings: Settings, today: String) -> PayInfo {
        let p = period(job, payday: payday)
        let mine = Calc.onlyWorked(shifts.filter {
            $0.jobId == job.id && !$0.esLibre && $0.fecha >= p.start && $0.fecha <= p.end
        })
        let totals = Calc.rangeTotals(shifts: mine, jobsById: [job.id: job],
                                      umbralExtraHrs: settings.umbralExtraHrs,
                                      multExtra: settings.multExtra)
        return PayInfo(job: job, payday: payday, periodStart: p.start, periodEnd: p.end,
                       totals: totals, closed: p.end < today,
                       daysLeft: max(0, Calc.daysBetween(today, payday)))
    }

    /// Los próximos `count` cobros de un trabajo desde hoy.
    static func upcoming(_ job: Job, shifts: [Shift], settings: Settings, count: Int = 1) -> [PayInfo] {
        let today = Calc.todayYmd()
        var out: [PayInfo] = []
        var day = nextPayday(job, settings: settings, from: today)
        for _ in 0..<max(1, count) {
            out.append(info(job, payday: day, shifts: shifts, settings: settings, today: today))
            day = Calc.addDays(day, freq(job).days)
        }
        return out
    }

    /// El próximo cobro de cada trabajo, del más cercano al más lejano.
    static func nextForAll(jobs: [Job], shifts: [Shift], settings: Settings) -> [PayInfo] {
        jobs.compactMap { upcoming($0, shifts: shifts, settings: settings).first }
            .sorted { $0.payday < $1.payday }
    }

    /// "Cada semana · viernes" / "Cada semana · viernes · 2 sem. después"
    static func summary(_ job: Job, settings: Settings) -> String {
        var s = "\(freq(job).label) · \(Calc.daysLong[weekday(job, settings: settings)].lowercased())"
        if lag(job) > 1 { s += " · \(lag(job)) sem. después" }
        return s
    }
}
