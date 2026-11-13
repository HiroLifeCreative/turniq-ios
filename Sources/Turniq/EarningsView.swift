import SwiftUI

/// Pestaña Ganancias — por semana (trabajado vs programado), meta,
/// próximos cobros, mes, año y desglose por trabajo.
struct EarningsView: View {
    @EnvironmentObject var store: Store
    @State private var weekOff = 0
    @State private var monthOff = 0
    @State private var yearOff = 0
    @State private var showYear = false

    private var hidden: Bool { store.settings.dineroOculto }

    private func totals(_ shifts: [Shift], overtime: Bool = true) -> Calc.WeekTotals {
        Calc.weekTotals(
            shifts: shifts, jobsById: store.jobsById,
            umbralExtraHrs: overtime ? store.settings.umbralExtraHrs : 1e9,
            multExtra: overtime ? store.settings.multExtra : 1)
    }

    /// "YYYY-MM" del mes actual + `offset` meses.
    private func monthKey(_ offset: Int) -> String {
        let cal = Calc.cal
        let base = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let d = cal.date(byAdding: .month, value: offset, to: base) ?? base
        return String(Calc.ymd(d).prefix(7))
    }

    var body: some View {
        let monday = Calc.addDays(Calc.monday(of: Calc.todayYmd()), weekOff * 7)
        let weekShifts = store.shifts.filter { Calc.monday(of: $0.fecha) == monday }
        let workedShifts = weekShifts.filter { Calc.workState($0) == .worked }
        let worked = totals(workedShifts)
        let scheduled = totals(weekShifts.filter { Calc.workState($0) == .scheduled })
        let lastMonday = Calc.addDays(monday, -7)
        let prev = totals(store.shifts.filter { Calc.monday(of: $0.fecha) == lastMonday })
        let weekLabel = "\(Calc.shortDate(monday)) – \(Calc.shortDate(Calc.addDays(monday, 6)))"

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionTitle(text: "Por semana")
                        Text(weekLabel).font(.turniq(12)).foregroundStyle(T.text2)
                    }
                    Spacer()
                    navArrows(prev: { weekOff -= 1 }, next: { weekOff += 1 })
                }

                weekCard(worked: worked, scheduled: scheduled)

                if store.settings.mostrarMeta && store.settings.metaSemanal > 0 {
                    goalCard(cur: worked, prev: prev)
                }

                PaydaysCard()

                monthSection

                yearSection

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        MonoLabel(text: "Por trabajo")
                        Text(weekLabel).font(.turniq(12)).foregroundStyle(T.text2)
                    }
                    Spacer()
                    navArrows(prev: { weekOff -= 1 }, next: { weekOff += 1 })
                }
                .padding(.top, 4)
                perJob(workedShifts)

                recordedCard
            }
            .padding(16)
            .padding(.bottom, dockClearance)
        }
    }

    private func navArrows(prev: @escaping () -> Void, next: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            CircleButton(icon: "chevron.left", action: prev)
            CircleButton(icon: "chevron.right", action: next)
        }
    }

    // MARK: Semana

    private func weekCard(worked: Calc.WeekTotals, scheduled: Calc.WeekTotals) -> some View {
        let total = worked.hours + scheduled.hours
        return TintedCard(accent: "#30A46C") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TRABAJADAS").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                        Text(Calc.fmtHours(worked.hours))
                            .font(.turniq(30, .bold)).foregroundStyle(T.money)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("BRUTO").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                        Text(T.cash(worked.gross, hidden: hidden))
                            .font(.turniq(17, .bold)).foregroundStyle(.white)
                        Text("NETO").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                            .padding(.top, 6)
                        Text(T.cash(worked.net, hidden: hidden))
                            .font(.turniq(20, .bold)).foregroundStyle(T.money)
                    }
                }
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        if total > 0 {
                            Rectangle().fill(T.money)
                                .frame(width: geo.size.width * worked.hours / total)
                            Rectangle().fill(T.sky)
                                .frame(width: geo.size.width * scheduled.hours / total)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.14))
                    .clipShape(Capsule())
                }
                .frame(height: 10)
                HStack(alignment: .top) {
                    DarkStat(label: "Programadas", value: Calc.fmtHours(scheduled.hours), color: T.sky)
                    Spacer()
                    DarkStat(label: "Total", value: Calc.fmtHours(total), alignment: .trailing)
                }
            }
        }
    }

    private func goalCard(cur: Calc.WeekTotals, prev: Calc.WeekTotals) -> some View {
        let meta = store.settings.metaSemanal
        let pct = min(100, cur.net / meta * 100)
        let filled = Int((pct / 100 * 12).rounded())
        let vs = prev.net > 0 ? (cur.net - prev.net) / prev.net * 100 : (cur.net > 0 ? 100 : 0)
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    MonoLabel(text: "Meta semanal")
                    Spacer()
                    Text("\(T.cash(cur.net, hidden: hidden)) de \(Calc.money(meta))")
                        .font(.turniq(12)).foregroundStyle(T.text2)
                }
                HStack(spacing: 3) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(i < filled ? T.button : T.surface)
                            .frame(height: 12)
                    }
                }
                Text("\(Int(pct.rounded()))% de la meta completada")
                    .font(.turniq(12)).foregroundStyle(T.text2)
                Text("vs semana anterior: \(vs >= 0 ? "+" : "")\(Int(vs.rounded()))%")
                    .font(.turniq(12)).foregroundStyle(T.text3)
            }
        }
    }

    // MARK: Mes

    @ViewBuilder
    private var monthSection: some View {
        let key = monthKey(monthOff)
        let monthShifts = Calc.onlyWorked(store.shifts.filter { $0.fecha.hasPrefix(key) })
        let month = totals(monthShifts, overtime: false)
        let monthIdx = (Int(key.suffix(2)) ?? 1) - 1
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                SectionTitle(text: "\(Calc.monthsLong[min(11, max(0, monthIdx))]) \(key.prefix(4))")
                if monthOff != 0 {
                    Button { monthOff = 0 } label: {
                        Text("HOY").font(.turniqMono).foregroundStyle(T.primary)
                    }
                }
            }
            Spacer()
            navArrows(prev: { monthOff -= 1 }, next: { monthOff += 1 })
        }
        .padding(.top, 4)

        TintedCard(accent: "#0064E0") {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTALES DEL MES").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                Text(T.cash(month.net, hidden: hidden))
                    .font(.turniq(34, .bold)).tracking(-1).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("Neto · con taxes").font(.turniq(12)).foregroundStyle(.white.opacity(0.55))
                Rectangle().fill(.white.opacity(0.14)).frame(height: 1).padding(.vertical, 8)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BRUTO").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                        Text(T.cash(month.gross, hidden: hidden))
                            .font(.turniq(20, .bold)).foregroundStyle(T.amber)
                        Text("sin taxes").font(.turniqMono).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("HORAS").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                        Text(Calc.fmtHours(month.hours))
                            .font(.turniq(20, .bold)).foregroundStyle(.white)
                        Text("\(monthShifts.filter { !$0.esLibre }.count) turnos")
                            .font(.turniqMono).foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }

    // MARK: Año

    @ViewBuilder
    private var yearSection: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { showYear.toggle() }
        } label: {
            HStack {
                SectionTitle(text: "Por año")
                Spacer()
                Image(systemName: showYear ? "chevron.down" : "chevron.right")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(T.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)

        if showYear {
            let year = Calc.cal.component(.year, from: Date()) + yearOff
            let worked = Calc.onlyWorked(store.shifts.filter { $0.fecha.hasPrefix("\(year)-") })
            let months: [Calc.WeekTotals] = (1...12).map { m in
                let key = String(format: "%04d-%02d", year, m)
                return totals(worked.filter { $0.fecha.hasPrefix(key) }, overtime: false)
            }
            let net = months.reduce(0) { $0 + $1.net }
            let hours = months.reduce(0) { $0 + $1.hours }
            let maxNet = max(1, months.map { $0.net }.max() ?? 1)
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(String(year)).font(.turniq(20, .bold)).foregroundStyle(T.text)
                        Spacer()
                        CircleButton(icon: "chevron.left", size: 36) { yearOff -= 1 }
                        CircleButton(icon: "chevron.right", size: 36) { yearOff += 1 }
                    }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            MonoLabel(text: "Neto")
                            Text(T.cash(net, hidden: hidden)).font(.turniq(24, .bold)).foregroundStyle(T.text)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            MonoLabel(text: "Horas")
                            Text(Calc.fmtHours(hours)).font(.turniq(24, .bold)).foregroundStyle(T.text)
                        }
                    }
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<12, id: \.self) { i in
                            VStack(spacing: 4) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(months[i].net > 0 ? T.primary : T.surface)
                                    .frame(height: max(3, months[i].net / maxNet * 100))
                                    .padding(.horizontal, 4)
                                Text(String(Calc.months[i].prefix(1)).uppercased())
                                    .font(.turniq(9)).foregroundStyle(T.text3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 124)
                }
            }
        }
    }

    // MARK: Por trabajo

    @ViewBuilder
    private func perJob(_ workedShifts: [Shift]) -> some View {
        let rows = jobRows(workedShifts)
        if rows.isEmpty {
            Text("Aún no hay turnos registrados")
                .font(.turniq(13)).foregroundStyle(T.text3)
        }
        ForEach(rows, id: \.job.id) { row in
            Card {
                HStack(spacing: 12) {
                    Circle().fill(T.hex(row.job.color)).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.job.nombre).font(.turniq(16, .bold)).foregroundStyle(T.text).lineLimit(1)
                        Text(Calc.fmtHours(row.t.hours)
                             + (row.t.overtimeHours > 0 ? " · \(Calc.fmtHours(row.t.overtimeHours)) hora extra" : ""))
                            .font(.turniq(12)).foregroundStyle(T.text2)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(T.cash(row.t.net, hidden: hidden))
                            .font(.turniq(18, .bold)).foregroundStyle(T.text)
                        Text("\(T.cash(row.t.gross, hidden: hidden)) bruto")
                            .font(.turniq(11)).foregroundStyle(T.text3)
                    }
                }
            }
        }
    }

    private func jobRows(_ workedShifts: [Shift]) -> [(job: Job, t: Calc.WeekTotals)] {
        var rows: [(job: Job, t: Calc.WeekTotals)] = []
        for job in store.jobs {
            let mine = workedShifts.filter { $0.jobId == job.id && !$0.esLibre }
            if !mine.isEmpty { rows.append((job: job, t: totals(mine))) }
        }
        return rows
    }

    /// Todo lo registrado hasta hoy (solo trabajado).
    private var recordedCard: some View {
        let all = Calc.onlyWorked(store.shifts).filter { !$0.esLibre }
        let t = totals(all, overtime: false)
        return Card {
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel(text: "Registrado actualmente")
                Text(T.cash(t.net, hidden: hidden))
                    .font(.turniq(34, .bold)).tracking(-1).foregroundStyle(T.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("\(all.count) turnos · \(Calc.fmtHours(t.hours))")
                    .font(.turniq(12)).foregroundStyle(T.text3)
            }
        }
    }
}
