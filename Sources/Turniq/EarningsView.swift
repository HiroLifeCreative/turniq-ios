import SwiftUI

struct EarningsView: View {
    @EnvironmentObject var store: Store

    private var monday: String { Calc.monday(of: Calc.todayYmd()) }
    private var weekShifts: [Shift] { store.shifts.filter { Calc.monday(of: $0.fecha) == monday } }
    private var worked: Calc.WeekTotals {
        Calc.weekTotals(shifts: Calc.onlyWorked(weekShifts), jobsById: store.jobsById,
                        umbralExtraHrs: store.settings.umbralExtraHrs, multExtra: store.settings.multExtra)
    }
    private var scheduled: Calc.WeekTotals {
        // Programadas: la foto de planificación (sin filtrar por trabajado,
        // sin horas extra — igual que la tarjeta de la app Android).
        Calc.weekTotals(shifts: weekShifts, jobsById: store.jobsById,
                        umbralExtraHrs: 1e9, multExtra: 1)
    }
    private var monthShifts: [Shift] {
        let prefix = String(Calc.todayYmd().prefix(7))
        return store.shifts.filter { $0.fecha.hasPrefix(prefix) }
    }
    private var monthWorked: Calc.WeekTotals {
        Calc.weekTotals(shifts: Calc.onlyWorked(monthShifts), jobsById: store.jobsById,
                        umbralExtraHrs: 1e9, multExtra: 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DarkCard {
                        VStack(alignment: .leading, spacing: 6) {
                            MonoLabel(text: "Neto trabajado · esta semana", color: .white.opacity(0.55))
                            Text(Calc.money(worked.net))
                                .font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                            HStack(spacing: 16) {
                                Label(Calc.fmtHours(worked.hours), systemImage: "clock")
                                Label("\(Calc.money(worked.gross)) bruto", systemImage: "banknote")
                                if worked.overtimeHours > 0 {
                                    Label("+\(Calc.fmtHours(worked.overtimeHours)) extra", systemImage: "bolt.fill")
                                        .foregroundStyle(T.amber)
                                }
                            }
                            .font(.footnote).foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    compareCard
                    perJobCard

                    DarkCard {
                        VStack(alignment: .leading, spacing: 6) {
                            MonoLabel(text: "Totales del mes · trabajado", color: .white.opacity(0.55))
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Horas").font(.caption).foregroundStyle(.white.opacity(0.55))
                                    Text(Calc.fmtHours(monthWorked.hours)).font(.headline).foregroundStyle(.white)
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("Bruto").font(.caption).foregroundStyle(.white.opacity(0.55))
                                    Text(Calc.money(monthWorked.gross)).font(.headline).foregroundStyle(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Neto").font(.caption).foregroundStyle(.white.opacity(0.55))
                                    Text(Calc.money(monthWorked.net)).font(.headline).foregroundStyle(T.money)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Ganancias")
        }
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(text: "Trabajado vs programado")
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Trabajado").font(.caption).foregroundStyle(.secondary)
                    Text(Calc.money(worked.net)).font(.title3.bold())
                    Text(Calc.fmtHours(worked.hours)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Programado").font(.caption).foregroundStyle(.secondary)
                    Text(Calc.money(scheduled.net)).font(.title3.bold()).foregroundStyle(.secondary)
                    Text(Calc.fmtHours(scheduled.hours)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var perJobCard: some View {
        let workedShifts = Calc.onlyWorked(weekShifts)
        return VStack(alignment: .leading, spacing: 10) {
            MonoLabel(text: "Por trabajo · esta semana")
            ForEach(store.jobs) { job in
                let mine = workedShifts.filter { $0.jobId == job.id }
                if !mine.isEmpty {
                    let t = Calc.weekTotals(shifts: mine, jobsById: store.jobsById,
                                             umbralExtraHrs: store.settings.umbralExtraHrs,
                                             multExtra: store.settings.multExtra)
                    HStack {
                        Circle().fill(T.hex(job.color)).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.nombre).font(.headline)
                            Text("\(Calc.fmtHours(t.hours))\(t.overtimeHours > 0 ? " · +\(Calc.fmtHours(t.overtimeHours)) extra" : "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Calc.money(t.net)).font(.headline).foregroundStyle(T.money)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
