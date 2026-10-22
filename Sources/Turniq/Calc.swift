import Foundation

// MARK: - Motor de cálculos de Turniq (mismas reglas que Android)
// 1. Los totales de dinero cuentan SOLO turnos ya trabajados.
// 2. Las horas extra son POR TRABAJO: el umbral semanal se aplica a
//    las horas de cada empleo por separado, con SU sueldo y SU
//    impuesto. Nunca a la suma de todos los trabajos.

enum Calc {

    // MARK: Fechas "YYYY-MM-DD" (sin zona: días civiles)

    static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parseDay(_ ymd: String) -> Date? { dayFmt.date(from: ymd) }
    static func ymd(_ d: Date) -> String { dayFmt.string(from: d) }

    static func addDays(_ ymdStr: String, _ n: Int) -> String {
        guard let d = parseDay(ymdStr) else { return ymdStr }
        let c = Calendar(identifier: .gregorian)
        return ymd(c.date(byAdding: .day, value: n, to: d) ?? d)
    }

    /// Lunes (YYYY-MM-DD) de la semana de una fecha.
    static func monday(of ymdStr: String) -> String {
        guard let d = parseDay(ymdStr) else { return ymdStr }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        let mon = cal.date(from: comps) ?? d
        return ymd(mon)
    }

    static func todayYmd() -> String { ymd(Date()) }
    static func nowHHMM() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    /// "HH:mm" → minutos del día (nil si el formato no vale)
    static func hmToMin(_ hm: String) -> Int? {
        let p = hm.split(separator: ":")
        guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]) else { return nil }
        return h * 60 + m
    }

    // MARK: Horas de un turno

    /// ¿La salida es al día siguiente? (salida <= entrada)
    static func isOvernight(entrada: String, salida: String?) -> Bool {
        guard let s = salida, let e = hmToMin(entrada), let x = hmToMin(s) else { return false }
        return x <= e
    }

    /// Horas netas del turno (descuenta el break). Overnight suma 24h.
    static func shiftHours(_ s: Shift) -> Double {
        guard let e = hmToMin(s.horaEntrada) else { return 0 }
        var end: Int
        if let sal = s.horaSalida, let x = hmToMin(sal) {
            end = x <= e ? x + 1440 : x
        } else {
            end = e // sin salida: 0 h netas tras restar
            return 0
        }
        let net = Double(end - e - s.breakMin) / 60.0
        return max(0, net)
    }

    // MARK: ¿Ya se trabajó? (criterio global de la app)

    enum WorkState { case worked, scheduled }

    static func workState(_ s: Shift) -> WorkState {
        let today = todayYmd()
        if s.fecha < today { return .worked }
        if s.fecha > today { return .scheduled }
        // Hoy: trabajado si marcó entrada real, o si ya pasó la hora
        // de salida programada (con overnight la salida es mañana).
        if s.horaEntradaReal != nil { return .worked }
        if isOvernight(entrada: s.horaEntrada, salida: s.horaSalida) { return .scheduled }
        guard let sal = s.horaSalida, let endMin = hmToMin(sal),
              let nowMin = hmToMin(nowHHMM()) else { return .scheduled }
        return nowMin >= endMin ? .worked : .scheduled
    }

    static func onlyWorked(_ shifts: [Shift]) -> [Shift] {
        shifts.filter { workState($0) == .worked }
    }

    // MARK: Totales con horas extra POR TRABAJO

    struct WeekTotals {
        var hours: Double = 0
        var regularHours: Double = 0
        var overtimeHours: Double = 0
        var gross: Double = 0
        var net: Double = 0
    }

    static func weekTotals(
        shifts: [Shift],
        jobsById: [String: Job],
        umbralExtraHrs: Double,
        multExtra: Double
    ) -> WeekTotals {
        var byJob: [String: (hours: Double, tipsBonus: Double)] = [:]
        for s in shifts where !s.esLibre {
            var acc = byJob[s.jobId] ?? (0, 0)
            acc.hours += shiftHours(s)
            acc.tipsBonus += s.propinas + s.bono
            byJob[s.jobId] = acc
        }
        var t = WeekTotals()
        for (jobId, acc) in byJob {
            let job = jobsById[jobId]
            let rate = job?.sueldoHora ?? 0
            let taxRate = (job?.taxPct ?? 0) / 100.0
            let reg = min(acc.hours, umbralExtraHrs)
            let ot = max(0, acc.hours - umbralExtraHrs)
            let g = reg * rate + ot * rate * multExtra + acc.tipsBonus
            t.hours += acc.hours
            t.regularHours += reg
            t.overtimeHours += ot
            t.gross += g
            t.net += g * (1 - taxRate)
        }
        return t
    }

    /// Horas trabajadas de UN trabajo en el conjunto (para la barra
    /// de hora extra por trabajo de la pantalla Semana).
    static func hours(ofJob jobId: String, in shifts: [Shift]) -> Double {
        shifts.filter { $0.jobId == jobId && !$0.esLibre }
            .reduce(0) { $0 + shiftHours($1) }
    }

    // MARK: Formato

    static func money(_ n: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: n)) ?? String(format: "$%.2f", n)
    }

    /// "8 h 30 min" / "8 h"
    static func fmtHours(_ h: Double) -> String {
        let whole = Int(h)
        let mins = Int(((h - Double(whole)) * 60).rounded())
        if mins == 60 { return "\(whole + 1) h" }
        return mins == 0 ? "\(whole) h" : "\(whole) h \(mins) min"
    }

    /// "9:00 a. m." (12h) o "09:00" (24h según ajuste)
    static func fmtTime(_ hm: String, format12: Bool) -> String {
        guard let mins = hmToMin(hm) else { return hm }
        let h = mins / 60, m = mins % 60
        if !format12 { return String(format: "%02d:%02d", h, m) }
        let suffix = h < 12 ? "a. m." : "p. m."
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", h12, m, suffix)
    }
}
