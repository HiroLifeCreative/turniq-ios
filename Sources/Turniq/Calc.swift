import Foundation

// MARK: - Motor de cálculos de Turniq (mismas reglas que Android)
// 1. Los totales de dinero cuentan SOLO turnos ya trabajados.
// 2. Las horas extra son POR TRABAJO y POR SEMANA: el umbral semanal
//    se aplica a las horas de cada empleo por separado, con SU sueldo
//    y SU impuesto. Nunca a la suma de todos los trabajos.
// 3. Si el turno tiene horas reales marcadas, mandan las reales.

enum Calc {

    // MARK: Fechas "YYYY-MM-DD" (sin zona: días civiles)

    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone.current
        return c
    }()

    static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let hmFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "HH:mm"
        return f
    }()

    static func parseDay(_ ymd: String) -> Date? { dayFmt.date(from: ymd) }
    static func ymd(_ d: Date) -> String { dayFmt.string(from: d) }

    static func addDays(_ ymdStr: String, _ n: Int) -> String {
        guard let d = parseDay(ymdStr) else { return ymdStr }
        return ymd(cal.date(byAdding: .day, value: n, to: d) ?? d)
    }

    /// Días civiles de `a` a `b` (b - a). 0 si alguna no se puede leer.
    static func daysBetween(_ a: String, _ b: String) -> Int {
        guard let da = parseDay(a), let db = parseDay(b) else { return 0 }
        return cal.dateComponents([.day], from: da, to: db).day ?? 0
    }

    /// Día de la semana de una fecha: 0=lunes … 6=domingo.
    static func weekdayIndex(_ ymdStr: String) -> Int {
        guard let d = parseDay(ymdStr) else { return 0 }
        // Calendar: 1=domingo … 7=sábado
        return (cal.component(.weekday, from: d) + 5) % 7
    }

    /// Lunes (YYYY-MM-DD) de la semana de una fecha.
    static func monday(of ymdStr: String) -> String {
        addDays(ymdStr, -weekdayIndex(ymdStr))
    }

    static func todayYmd() -> String { ymd(Date()) }
    static func nowHHMM() -> String { hmFmt.string(from: Date()) }
    static func hhmm(_ d: Date) -> String { hmFmt.string(from: d) }

    /// "HH:mm" → minutos del día (nil si el formato no vale)
    static func hmToMin(_ hm: String) -> Int? {
        let p = hm.split(separator: ":")
        guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]) else { return nil }
        return h * 60 + m
    }

    static func minToHm(_ min: Int) -> String {
        let m = ((min % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    /// Instante exacto de un día + hora "HH:mm".
    static func date(_ ymdStr: String, _ hm: String) -> Date? {
        guard let d = parseDay(ymdStr), let m = hmToMin(hm) else { return nil }
        return cal.date(byAdding: .minute, value: m, to: d)
    }

    // MARK: Horas de un turno

    /// ¿La salida es al día siguiente? (salida <= entrada)
    static func isOvernight(entrada: String, salida: String?) -> Bool {
        guard let s = salida, let e = hmToMin(entrada), let x = hmToMin(s) else { return false }
        return x <= e
    }

    /// Fecha en la que termina el turno programado.
    static func endDate(_ s: Shift) -> String {
        if let f = s.fechaSalida { return f }
        return isOvernight(entrada: s.horaEntrada, salida: s.horaSalida) ? addDays(s.fecha, 1) : s.fecha
    }

    /// Horas de un rango con fechas explícitas (descuenta el break).
    /// Sin salida = 0. Sin fecha de salida (datos viejos) vale la
    /// regla anterior: salida <= entrada cuenta como día siguiente.
    static func rangeHours(
        startDate: String, start: String,
        endDate: String?, end: String?,
        breakMin: Int
    ) -> Double {
        guard let end, let e = hmToMin(start), let x = hmToMin(end) else { return 0 }
        let days: Int
        if let endDate {
            days = daysBetween(startDate, endDate)
        } else {
            days = x <= e ? 1 : 0
        }
        let mins = days * 1440 + x - e
        return Double(max(0, mins - breakMin)) / 60.0
    }

    /// Horas programadas del turno.
    static func scheduledHours(_ s: Shift) -> Double {
        rangeHours(startDate: s.fecha, start: s.horaEntrada,
                   endDate: s.fechaSalida, end: s.horaSalida, breakMin: s.breakMin)
    }

    /// Horas del turno: si marcó entrada real mandan las horas reales
    /// (turno aún abierto = 0); si no, las programadas.
    static func shiftHours(_ s: Shift) -> Double {
        if let realIn = s.horaEntradaReal {
            return rangeHours(startDate: s.fecha, start: realIn,
                              endDate: s.fechaSalidaReal ?? s.fechaSalida,
                              end: s.horaSalidaReal, breakMin: s.breakMin)
        }
        return scheduledHours(s)
    }

    // MARK: ¿Ya se trabajó? (criterio global de la app)

    enum WorkState { case worked, scheduled }

    static func workState(_ s: Shift) -> WorkState {
        let today = todayYmd()
        if s.fecha < today { return .worked }
        if s.fecha > today { return .scheduled }
        // Hoy: trabajado si marcó entrada real, o si ya pasó la hora
        // de salida programada (si termina otro día, esa hora no vale).
        if s.horaEntradaReal != nil { return .worked }
        if endDate(s) > s.fecha { return .scheduled }
        guard let sal = s.horaSalida, let endMin = hmToMin(sal),
              let nowMin = hmToMin(nowHHMM()) else { return .scheduled }
        return nowMin >= endMin ? .worked : .scheduled
    }

    static func onlyWorked(_ shifts: [Shift]) -> [Shift] {
        shifts.filter { workState($0) == .worked }
    }

    // MARK: Estado visual del turno (pantalla Semana)

    enum Status { case past, upcoming, now, missed }

    static func status(_ s: Shift) -> Status {
        let today = todayYmd()
        if s.horaSalida == nil && s.fecha < today { return .missed }
        if s.fecha < today { return .past }
        if s.fecha > today { return .upcoming }
        // Hoy: las horas reales mandan.
        if let outReal = s.horaSalidaReal, s.horaEntradaReal != nil {
            let endDay = s.fechaSalidaReal ?? s.fechaSalida ?? s.fecha
            if let end = date(endDay, outReal), end <= Date() { return .past }
        }
        if s.horaEntradaReal != nil { return .now }
        guard let nowMin = hmToMin(nowHHMM()), let start = hmToMin(s.horaEntrada) else { return .upcoming }
        guard let sal = s.horaSalida, let end = hmToMin(sal) else {
            return nowMin < start ? .upcoming : .now
        }
        if nowMin < start { return .upcoming }
        if nowMin >= (end < start ? end + 1440 : end) { return .past }
        return .now
    }

    // MARK: Totales con horas extra POR TRABAJO

    struct WeekTotals {
        var hours: Double = 0
        var regularHours: Double = 0
        var overtimeHours: Double = 0
        var gross: Double = 0
        var net: Double = 0

        var taxes: Double { gross - net }

        static func + (a: WeekTotals, b: WeekTotals) -> WeekTotals {
            WeekTotals(hours: a.hours + b.hours,
                       regularHours: a.regularHours + b.regularHours,
                       overtimeHours: a.overtimeHours + b.overtimeHours,
                       gross: a.gross + b.gross,
                       net: a.net + b.net)
        }
    }

    /// Totales de UNA semana (el umbral se aplica por trabajo).
    static func weekTotals(
        shifts: [Shift],
        jobsById: [String: Job],
        umbralExtraHrs: Double,
        multExtra: Double
    ) -> WeekTotals {
        var byJob: [String: (hours: Double, tipsBonus: Double)] = [:]
        for s in shifts where !s.esLibre {
            var acc = byJob[s.jobId] ?? (hours: 0, tipsBonus: 0)
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

    /// Totales de un rango de VARIAS semanas: la hora extra se aplica
    /// por trabajo y por semana (cada grupo trabajo×semana con su
    /// propio umbral). Usar en todo total que abarque más de 1 semana.
    static func rangeTotals(
        shifts: [Shift],
        jobsById: [String: Job],
        umbralExtraHrs: Double,
        multExtra: Double
    ) -> WeekTotals {
        var groups: [String: [Shift]] = [:]
        for s in shifts where !s.esLibre {
            groups[monday(of: s.fecha), default: []].append(s)
        }
        var total = WeekTotals()
        for (_, list) in groups {
            total = total + weekTotals(shifts: list, jobsById: jobsById,
                                       umbralExtraHrs: umbralExtraHrs, multExtra: multExtra)
        }
        return total
    }

    /// Horas trabajadas de UN trabajo en el conjunto (para la barra
    /// de hora extra por trabajo de la pantalla Semana).
    static func hours(ofJob jobId: String, in shifts: [Shift]) -> Double {
        shifts.filter { $0.jobId == jobId && !$0.esLibre }
            .reduce(0) { $0 + shiftHours($1) }
    }

    // MARK: Formato

    static var months: [String] {
        Lang.en
            ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            : ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    }
    static var monthsLong: [String] {
        Lang.en
            ? ["January", "February", "March", "April", "May", "June", "July",
               "August", "September", "October", "November", "December"]
            : ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
               "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    }
    static var daysShort: [String] {
        Lang.en
            ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            : ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
    }
    static var daysLong: [String] {
        Lang.en
            ? ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            : ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    }

    private static let moneyFmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// "$1,234.56" (igual que Android)
    static func money(_ n: Double) -> String {
        let body = moneyFmt.string(from: NSNumber(value: abs(n))) ?? String(format: "%.2f", abs(n))
        return (n < 0 ? "-$" : "$") + body
    }

    /// "8h 30m" / "8h" (formato corto de Android)
    static func fmtHours(_ h: Double) -> String {
        var whole = Int(h)
        var mins = Int(((h - Double(whole)) * 60).rounded())
        if mins == 60 { whole += 1; mins = 0 }
        return mins == 0 ? "\(whole)h" : "\(whole)h \(mins)m"
    }

    /// "6 h 30 min" / "6 h" / "45 min"
    static func fmtHoursLong(_ h: Double) -> String {
        var whole = Int(h + 1e-9)
        var mins = Int(((h - Double(whole)) * 60).rounded())
        if mins == 60 { whole += 1; mins = 0 }
        if whole == 0 { return "\(mins) min" }
        return mins == 0 ? "\(whole) h" : "\(whole) h \(mins) min"
    }

    /// "5:00 p.m." (12h) o "17:00" (24h según ajuste)
    static func fmtTime(_ hm: String, format12: Bool) -> String {
        guard let mins = hmToMin(hm) else { return hm }
        let h = mins / 60, m = mins % 60
        if !format12 { return String(format: "%02d:%02d", h, m) }
        let suffix = Lang.en ? (h < 12 ? "AM" : "PM") : (h < 12 ? "a.m." : "p.m.")
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", h12, m, suffix)
    }

    /// "18 oct"
    static func shortDate(_ ymdStr: String) -> String {
        let p = ymdStr.split(separator: "-")
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]), (1...12).contains(m) else { return ymdStr }
        return "\(d) \(months[m - 1])"
    }

    /// "vie 18 oct"
    static func weekdayDate(_ ymdStr: String) -> String {
        "\(daysShort[weekdayIndex(ymdStr)].lowercased()) \(shortDate(ymdStr))"
    }

    /// "10:00 p.m. – 2:00 a.m. · 25 oct" (la fecha solo si la salida
    /// cae otro día).
    static func rangeLabel(_ s: Shift, format12: Bool) -> String {
        let out = s.horaSalida.map { fmtTime($0, format12: format12) } ?? "…"
        let base = "\(fmtTime(s.horaEntrada, format12: format12)) – \(out)"
        let fOut = endDate(s)
        return fOut != s.fecha ? "\(base) · \(shortDate(fOut))" : base
    }
}
