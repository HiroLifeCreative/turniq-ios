import SwiftUI

struct WeekView: View {
    @EnvironmentObject var store: Store
    @State private var weekOffset = 0
    @State private var editing: Shift? = nil
    @State private var creating: String? = nil   // fecha para el formulario nuevo
    @State private var confirmDup = false

    private var monday: String {
        let base = Calc.monday(of: Calc.todayYmd())
        return Calc.addDays(base, weekOffset * 7)
    }
    private var days: [String] { (0..<7).map { Calc.addDays(monday, $0) } }
    private var weekShifts: [Shift] {
        store.shifts.filter { Calc.monday(of: $0.fecha) == monday }
    }
    private var totals: Calc.WeekTotals {
        Calc.weekTotals(
            shifts: Calc.onlyWorked(weekShifts),
            jobsById: store.jobsById,
            umbralExtraHrs: store.settings.umbralExtraHrs,
            multExtra: store.settings.multExtra
        )
    }

    private static let dayNames = ["LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB", "DOM"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                weekNav
                if store.settings.mostrarHoraExtra { otCard }
                ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                    daySection(day: day, name: Self.dayNames[idx])
                }
                totalsCard
                PrimaryButton(title: "Duplicar semana a la siguiente") { confirmDup = true }
            }
            .padding()
        }
        .sheet(item: $editing) { s in
            ShiftFormView(editing: s)
        }
        .sheet(item: Binding(
            get: { creating.map { FechaRef(fecha: $0) } },
            set: { creating = $0?.fecha }
        )) { ref in
            ShiftFormView(editing: nil, defaultFecha: ref.fecha)
        }
        .confirmationDialog(
            "¿Duplicar los \(weekShifts.count) turnos de esta semana a la siguiente?",
            isPresented: $confirmDup
        ) {
            Button("Duplicar") { store.duplicateWeek(monday: monday) }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var weekNav: some View {
        HStack {
            Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
                .frame(width: 44, height: 44)
            Spacer()
            VStack(spacing: 2) {
                Text("\(days.first ?? "") – \(days.last ?? "")")
                    .font(.headline)
                if weekOffset != 0 {
                    Button("Hoy") { weekOffset = 0 }
                        .font(.caption).foregroundStyle(T.primary)
                }
            }
            Spacer()
            Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
                .frame(width: 44, height: 44)
        }
    }

    /// Hora extra POR TRABAJO: una barra por empleo.
    private var otCard: some View {
        let worked = Calc.onlyWorked(weekShifts)
        let rows = store.jobs
            .map { (job: $0, hours: Calc.hours(ofJob: $0.id, in: worked)) }
            .filter { $0.hours > 0 }
        return Group {
            if !rows.isEmpty {
                DarkCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            MonoLabel(text: "Hora extra · por trabajo", color: .white.opacity(0.55))
                            Spacer()
                            Text("×\(store.settings.multExtra.formatted())")
                                .font(.caption).foregroundStyle(.white.opacity(0.75))
                        }
                        ForEach(rows, id: \.job.id) { row in
                            let umbral = store.settings.umbralExtraHrs
                            let pct = umbral > 0 ? min(1, row.hours / umbral) : 0
                            let ot = max(0, row.hours - umbral)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Circle().fill(T.hex(row.job.color)).frame(width: 8, height: 8)
                                    Text(row.job.nombre).font(.subheadline.bold()).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Calc.fmtHours(row.hours)) / \(Calc.fmtHours(umbral))")
                                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                                    if ot > 0 {
                                        Text("+\(Calc.fmtHours(ot))")
                                            .font(.caption.bold()).foregroundStyle(T.amber)
                                    }
                                }
                                ProgressView(value: pct).tint(ot > 0 ? T.amber : T.button)
                            }
                        }
                    }
                }
            }
        }
    }

    private func daySection(day: String, name: String) -> some View {
        let ds = weekShifts
            .filter { $0.fecha == day }
            .sorted { $0.horaEntrada < $1.horaEntrada }
        let isToday = day == Calc.todayYmd()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(day.suffix(2)))
                    .font(.title2.bold())
                    .foregroundStyle(isToday ? T.primary : .secondary)
                Text(name).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { creating = day } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(T.primary)
                }
            }
            if ds.isEmpty {
                Text("Sin turnos").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(ds) { s in
                Button { editing = s } label: {
                    ShiftRow(shift: s)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Duplicar turno") { store.duplicateShift(id: s.id) }
                    Button("Eliminar", role: .destructive) { store.deleteShift(id: s.id) }
                }
            }
        }
    }

    private var totalsCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "Total semanal · trabajado", color: .white.opacity(0.55))
                HStack {
                    VStack(alignment: .leading) {
                        Text("Horas").font(.caption).foregroundStyle(.white.opacity(0.55))
                        Text(Calc.fmtHours(totals.hours)).font(.headline).foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Bruto").font(.caption).foregroundStyle(.white.opacity(0.55))
                        Text(Calc.money(totals.gross)).font(.headline).foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Neto").font(.caption).foregroundStyle(.white.opacity(0.55))
                        Text(Calc.money(totals.net)).font(.headline).foregroundStyle(T.money)
                    }
                }
                if totals.overtimeHours > 0 {
                    Text("+\(Calc.fmtHours(totals.overtimeHours)) extra ×\(store.settings.multExtra.formatted())")
                        .font(.caption).foregroundStyle(.white.opacity(0.65))
                }
            }
        }
    }
}

struct FechaRef: Identifiable {
    var fecha: String
    var id: String { fecha }
}
