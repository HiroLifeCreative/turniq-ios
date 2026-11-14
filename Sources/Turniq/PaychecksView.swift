import SwiftUI

/// Comparar con el cheque: anotas lo que realmente te pagaron cada
/// día de cobro y Turniq lo compara con lo que calculó.
struct PaychecksView: View {
    @EnvironmentObject var store: Store
    @State private var editing: PayInfo? = nil
    @State private var amount = ""

    private var hidden: Bool { store.settings.dineroOculto }

    /// Diferencia total (recibido − calculado) de los cheques anotados.
    private var totalDiff: (count: Int, diff: Double) {
        var count = 0
        var diff = 0.0
        for job in store.jobs {
            for p in Pay.recent(job, shifts: store.shifts, settings: store.settings, count: 8) {
                if let c = store.paycheck(jobId: job.id, payday: p.payday) {
                    count += 1
                    diff += c.recibido - p.totals.net
                }
            }
        }
        return (count, diff)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("Toca un día de cobro y escribe el neto que recibiste. Si falta dinero, Turniq te lo marca."))
                    .font(.turniq(13)).foregroundStyle(T.text2)

                let total = totalDiff
                if total.count > 0 {
                    TintedCard(accent: total.diff < -1 ? "#D13438" : "#30A46C") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("DIFERENCIA EN \(total.count) CHEQUES"))
                                .font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                            Text(hidden ? "••••" : signed(total.diff))
                                .font(.turniq(30, .bold))
                                .foregroundStyle(total.diff < -1 ? T.hex("#FF8A80") : T.money)
                            Text(total.diff < -1
                                 ? L("Te han pagado menos de lo que calculó Turniq.")
                                 : L("Tus cheques coinciden con lo calculado o lo superan."))
                                .font(.turniq(12)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                if store.jobs.isEmpty {
                    Text(L("Aún no hay turnos registrados"))
                        .font(.turniq(13)).foregroundStyle(T.text3)
                }

                ForEach(store.jobs) { job in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle().fill(T.hex(job.color)).frame(width: 10, height: 10)
                            SectionTitle(text: job.nombre)
                        }
                        .padding(.top, 6)
                        ForEach(Pay.recent(job, shifts: store.shifts, settings: store.settings, count: 6)) { p in
                            Button {
                                let saved = store.paycheck(jobId: job.id, payday: p.payday)
                                amount = saved.map { ShiftFormView.num($0.recibido) } ?? ""
                                editing = p
                            } label: {
                                row(p)
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }

                Text(L("El cálculo es una estimación con tus horas, sueldo y taxes. Una diferencia pequeña es normal; una grande conviene revisarla con tu empleador."))
                    .font(.turniq(12)).foregroundStyle(T.text3)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(T.bg)
        .navigationTitle(L("Comparar cheques"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("Neto recibido"), isPresented: Binding(
            get: { editing != nil },
            set: { if !$0 { editing = nil } }
        )) {
            TextField("0.00", text: $amount)
                .keyboardType(.decimalPad)
            Button(L("Guardar")) {
                if let p = editing {
                    let trimmed = amount.trimmingCharacters(in: .whitespaces)
                    store.setPaycheck(jobId: p.job.id, payday: p.payday,
                                      recibido: trimmed.isEmpty ? nil : ShiftFormView.parse(trimmed))
                }
                editing = nil
            }
            Button(L("Cancelar"), role: .cancel) { editing = nil }
        } message: {
            Text(editing.map { L("Cobro del \(Calc.weekdayDate($0.payday)). Turniq calculó \(Calc.money($0.totals.net)). Deja el campo vacío para borrar lo anotado.") } ?? "")
        }
    }

    private func signed(_ n: Double) -> String {
        (n >= 0 ? "+" : "−") + Calc.money(abs(n))
    }

    private func row(_ p: PayInfo) -> some View {
        let saved = store.paycheck(jobId: p.job.id, payday: p.payday)
        let diff = saved.map { $0.recibido - p.totals.net }
        return Card {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Calc.weekdayDate(p.payday))
                        .font(.turniq(15, .bold)).foregroundStyle(T.text)
                    Text(L("Paga \(Calc.shortDate(p.periodStart)) – \(Calc.shortDate(p.periodEnd)) · \(Calc.fmtHours(p.totals.hours))"))
                        .font(.turniq(12)).foregroundStyle(T.text3).lineLimit(1)
                    Text(L("Calculado: \(T.cash(p.totals.net, hidden: hidden))"))
                        .font(.turniq(12)).foregroundStyle(T.text2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    if let saved, let diff {
                        Text(T.cash(saved.recibido, hidden: hidden))
                            .font(.turniq(17, .bold)).foregroundStyle(T.text)
                        if abs(diff) < 1 {
                            Text(L("Coincide ✓")).font(.turniq(12, .bold)).foregroundStyle(T.success)
                        } else if diff < 0 {
                            Text(L("Faltan \(hidden ? "••••" : Calc.money(-diff))"))
                                .font(.turniq(12, .bold)).foregroundStyle(T.danger)
                        } else {
                            Text(L("\(hidden ? "••••" : Calc.money(diff)) de más"))
                                .font(.turniq(12, .bold)).foregroundStyle(T.success)
                        }
                    } else {
                        Text(L("Anotar"))
                            .font(.turniq(14, .bold)).foregroundStyle(T.primary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(T.primary.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
    }
}
