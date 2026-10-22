import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var showClockSheet = false

    private var fmt12: Bool { store.settings.formatoHora == "12h" }

    private var weekShifts: [Shift] {
        let mon = Calc.monday(of: Calc.todayYmd())
        return store.shifts.filter { Calc.monday(of: $0.fecha) == mon }
    }

    private var totals: Calc.WeekTotals {
        Calc.weekTotals(
            shifts: Calc.onlyWorked(weekShifts),
            jobsById: store.jobsById,
            umbralExtraHrs: store.settings.umbralExtraHrs,
            multExtra: store.settings.multExtra
        )
    }

    private var todayShifts: [Shift] {
        store.shifts
            .filter { $0.fecha == Calc.todayYmd() && !$0.esLibre }
            .sorted { $0.horaEntrada < $1.horaEntrada }
    }

    private var nextShift: Shift? {
        let now = Calc.todayYmd() + Calc.nowHHMM()
        return store.shifts
            .filter { !$0.esLibre && ($0.fecha + $0.horaEntrada) > now }
            .sorted { ($0.fecha + $0.horaEntrada) < ($1.fecha + $1.horaEntrada) }
            .first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                if let open = store.openShift {
                    workingCard(open)
                } else if !todayShifts.isEmpty {
                    PrimaryButton(title: "Marcar entrada ahora") { showClockSheet = true }
                }
                if let next = nextShift { nextCard(next) }
                todayList
            }
            .padding()
        }
        .sheet(isPresented: $showClockSheet) { clockSheet }
    }

    private var hero: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(text: "Neto trabajado · esta semana", color: .white.opacity(0.55))
                Text(Calc.money(totals.net))
                    .font(.turniq(40, .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 18) {
                    Label(Calc.fmtHours(totals.hours), systemImage: "clock")
                    Label(Calc.money(totals.gross) + " bruto", systemImage: "banknote")
                    if totals.overtimeHours > 0 {
                        Label("+\(Calc.fmtHours(totals.overtimeHours)) extra", systemImage: "bolt.fill")
                            .foregroundStyle(T.amber)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                if store.settings.mostrarMeta && store.settings.metaSemanal > 0 {
                    let pct = min(1, totals.net / store.settings.metaSemanal)
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: pct).tint(T.money)
                        Text("Meta semanal: \(Calc.money(totals.net)) de \(Calc.money(store.settings.metaSemanal))")
                            .font(.caption).foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func workingCard(_ s: Shift) -> some View {
        let job = store.job(id: s.jobId)
        return DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "Estás trabajando", color: T.money)
                Text(job?.nombre ?? "")
                    .font(.title3.bold()).foregroundStyle(.white)
                Text("Entrada: \(Calc.fmtTime(s.horaEntradaReal ?? s.horaEntrada, format12: fmt12))")
                    .foregroundStyle(.white.opacity(0.75)).font(.callout)
                PrimaryButton(title: "Marcar salida") { store.clockOut(shiftId: s.id) }
            }
        }
    }

    private func nextCard(_ s: Shift) -> some View {
        let job = store.job(id: s.jobId)
        return VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: "Próximo turno")
            HStack {
                Circle().fill(T.hex(job?.color ?? "#0064E0")).frame(width: 10, height: 10)
                Text(job?.nombre ?? "").font(.headline)
                Spacer()
                Text("\(s.fecha == Calc.todayYmd() ? "Hoy" : s.fecha)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("\(Calc.fmtTime(s.horaEntrada, format12: fmt12)) – \(s.horaSalida.map { Calc.fmtTime($0, format12: fmt12) } ?? "…")\(Calc.isOvernight(entrada: s.horaEntrada, salida: s.horaSalida) ? " +1 día" : "")")
                .font(.callout).foregroundStyle(.secondary)
            if let pin = job?.pinMarcaje, !pin.isEmpty {
                Label("PIN \(pin)", systemImage: "key.fill")
                    .font(.callout.bold()).foregroundStyle(T.primary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(text: "Turnos de hoy")
            if todayShifts.isEmpty {
                Text("Sin turnos hoy.").foregroundStyle(.secondary).font(.callout)
            }
            ForEach(todayShifts) { s in
                ShiftRow(shift: s)
            }
        }
    }

    private var clockSheet: some View {
        NavigationStack {
            List(todayShifts.filter { $0.horaEntradaReal == nil }) { s in
                let job = store.job(id: s.jobId)
                Button {
                    store.clockIn(shiftId: s.id)
                    showClockSheet = false
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job?.nombre ?? "").font(.headline).foregroundStyle(.primary)
                        Text("\(Calc.fmtTime(s.horaEntrada, format12: fmt12)) – \(s.horaSalida.map { Calc.fmtTime($0, format12: fmt12) } ?? "…")")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let pin = job?.pinMarcaje, !pin.isEmpty {
                            Label("PIN \(pin)", systemImage: "key.fill")
                                .font(.subheadline.bold()).foregroundStyle(T.primary)
                        }
                    }
                }
            }
            .navigationTitle("Marcar entrada")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

/// Fila de turno reutilizable (Semana e Inicio).
struct ShiftRow: View {
    @EnvironmentObject var store: Store
    var shift: Shift
    var body: some View {
        let job = store.job(id: shift.jobId)
        let fmt12 = store.settings.formatoHora == "12h"
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(T.hex(job?.color ?? "#0064E0"))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Calc.fmtTime(shift.horaEntrada, format12: fmt12)) – \(shift.horaSalida.map { Calc.fmtTime($0, format12: fmt12) } ?? "…")\(Calc.isOvernight(entrada: shift.horaEntrada, salida: shift.horaSalida) ? " +1 día" : "")")
                    .font(.headline)
                Text(job?.nombre ?? "")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Calc.fmtHours(Calc.shiftHours(shift)))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
