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

    // MARK: Tarifas de un turno

    /// Sueldo por hora que aplica al turno: el de la primera estación
    /// marcada que tenga tarifa propia; si ninguna, el del trabajo.
    static func rate(_ s: Shift, job: Job?) -> Double {
        guard let job else { return 0 }
        // Fuera del pago por hora, la "tarifa" es el valor de la hora
        // que se deriva del salario diario o del sueldo fijo.
        guard job.payMode == .hora else { return job.hourlyValue }
        for id in s.estacionIds {
            if let st = job.estaciones.first(where: { $0.id == id }),
               let r = st.sueldoHora, r > 0 {
                return r
            }
        }
        return job.sueldoHora
    }

    /// Multiplicador del turno (feriado / pago doble). 1 = normal.
    static func multiplier(_ s: Shift) -> Double {
        guard let m = s.multiplicador, m > 0 else { return 1 }
        return m
    }

    /// Horas del turno que caen de noche (10 p. m. – 6 a. m.), con el
    /// descanso descontado en proporción.
    static func nightHours(_ s: Shift) -> Double {
        let inHm = s.horaEntradaReal ?? s.horaEntrada
        let outHm = s.horaEntradaReal != nil ? s.horaSalidaReal : s.horaSalida
        let outDay = s.horaEntradaReal != nil ? (s.fechaSalidaReal ?? s.fechaSalida) : s.fechaSalida
        guard let outHm, let a = hmToMin(inHm), let x = hmToMin(outHm) else { return 0 }
        let days = outDay.map { daysBetween(s.fecha, $0) } ?? (x <= a ? 1 : 0)
        let b = x + max(0, days) * 1440
        guard b > a else { return 0 }
        // Ventanas nocturnas en minutos desde la medianoche del día
        // de entrada: [-120, 360), [1320, 1800), [2760, 3240)…
        var night = 0
        var w = -120
        while w < b {
            let lo = max(a, w), hi = min(b, w + 480)
            if hi > lo { night += hi - lo }
            w += 1440
        }
        return Double(night) / Double(b - a) * shiftHours(s)
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
        // Por trabajo: horas, pago base (con la tarifa y el
        // multiplicador de cada turno), pago a tarifa simple (para el
        // promedio de la hora extra), extra nocturno y propinas+bono.
        // `days` guarda, para «por día» y «sueldo fijo», cada fecha
        // trabajada con su mayor multiplicador (un feriado vale doble).
        struct Acc {
            var hours = 0.0, base = 0.0, plain = 0.0, night = 0.0, tipsBonus = 0.0
            var days: [String: Double] = [:]
            var dayHours: [String: Double] = [:]
        }
        var byJob: [String: Acc] = [:]
        for s in shifts where !s.esLibre {
            let job = jobsById[s.jobId]
            let mode = job?.payMode ?? .hora
            let h = shiftHours(s)
            var acc = byJob[s.jobId] ?? Acc()
            acc.hours += h
            switch mode {
            case .hora:
                let r = rate(s, job: job)
                acc.base += h * r * multiplier(s)
                acc.plain += h * r
                if let extra = job?.nocturnoExtra, extra > 0 {
                    acc.night += nightHours(s) * extra
                }
            case .turno:
                acc.base += (job?.amount ?? 0) * multiplier(s)
            case .dia, .fijo:
                acc.days[s.fecha] = max(acc.days[s.fecha] ?? 0, multiplier(s))
                acc.dayHours[s.fecha, default: 0] += h
            }
            acc.tipsBonus += s.propinas + s.bono
            byJob[s.jobId] = acc
        }
        var t = WeekTotals()
        for (jobId, acc) in byJob {
            let job = jobsById[jobId]
            let mode = job?.payMode ?? .hora
            let taxRate = (job?.taxPct ?? 0) / 100.0
            let reg = min(acc.hours, umbralExtraHrs)
            let ot = max(0, acc.hours - umbralExtraHrs)
            var g = acc.tipsBonus
            switch mode {
            case .hora:
                // El recargo de hora extra usa la tarifa promedio de la
                // semana en ese trabajo. Con una sola tarifa da lo mismo
                // que: normales × sueldo + extra × sueldo × recargo.
                let avgRate = acc.hours > 0 ? acc.plain / acc.hours : 0
                g += acc.base + ot * avgRate * (multExtra - 1) + acc.night
            case .turno:
                g += acc.base
            case .dia, .fijo:
                // Cada día trabajado vale lo mismo, sin importar sus
                // horas. De las horas extra, las que pasan de la jornada
                // de su día se pagan enteras al valor de la hora
                // derivado; las que ya cubre el pago del día, solo el
                // recargo (como en «por hora»).
                let dayValue = job?.dayValue ?? 0
                g += acc.days.values.reduce(0) { $0 + dayValue * $1 }
                if mode == .dia, job?.septimoDia == true {
                    // Séptimo día: por cada semana, un sexto de día
                    // pagado por cada día trabajado (hasta seis).
                    var perWeek: [String: Int] = [:]
                    for day in acc.days.keys { perWeek[monday(of: day), default: 0] += 1 }
                    for n in perWeek.values { g += Double(min(n, 6)) / 6 * dayValue }
                }
                let hv = job?.hourlyValue ?? 0
                let jornada = job.map { $0.payMode == .dia
                    ? max(1, $0.horasDia ?? 8)
                    : max(1, $0.horasMes ?? 173.33) * 12 / 52 / Double(max(1, $0.diasSemana ?? 5)) } ?? 8
                let uncovered = acc.dayHours.values.reduce(0) { $0 + max(0, $1 - jornada) }
                let otFull = min(ot, uncovered)
                g += otFull * hv * multExtra + (ot - otFull) * hv * (multExtra - 1)
            }
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

    /// Neto estimado de un turno en curso. Por hora crece con el
    /// tiempo; en las demás formas de pago es el valor fijo del día
    /// o del turno.
    static func liveNet(_ s: Shift, job: Job?, seconds: Int) -> Double {
        guard let job else { return 0 }
        let tax = job.taxPct / 100
        if job.payMode == .hora {
            return rate(s, job: job) * multiplier(s) * Double(seconds) / 3600 * (1 - tax)
        }
        let value = job.payMode == .turno ? job.amount : job.dayValue
        return value * multiplier(s) * (1 - tax)
    }

    // MARK: Aviso de hora extra

    struct OvertimeWarning: Identifiable {
        var job: Job
        /// Horas ya trabajadas esta semana
        var worked: Double
        /// Trabajadas + lo que falta por trabajar según el horario
        var projected: Double
        var id: String { job.id }
    }

    /// Horas con las que un turno cuenta para la proyección semanal:
    /// las reales si ya se cerró, las programadas si no.
    static func projectedHours(_ s: Shift) -> Double {
        (s.horaEntradaReal != nil && s.horaSalidaReal != nil) ? shiftHours(s) : scheduledHours(s)
    }

    /// Trabajos que esta semana llegan a 4 h o menos de la hora extra.
    static func overtimeWarnings(jobs: [Job], shifts: [Shift], umbral: Double) -> [OvertimeWarning] {
        guard umbral > 0 else { return [] }
        let thisWeek = Calc.monday(of: todayYmd())
        var out: [OvertimeWarning] = []
        for job in jobs {
            let week = shifts.filter { $0.jobId == job.id && !$0.esLibre && Calc.monday(of: $0.fecha) == thisWeek }
            let projected = week.reduce(0.0) { $0 + projectedHours($1) }
            guard projected >= umbral - 4 else { continue }
            let worked = hours(ofJob: job.id, in: onlyWorked(week))
            out.append(OvertimeWarning(job: job, worked: worked, projected: projected))
        }
        return out
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

    /// Dinero con la moneda del perfil: "$1,234.56", "S/ 1,234.50"…
    static func money(_ n: Double) -> String {
        Money.format(n)
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
