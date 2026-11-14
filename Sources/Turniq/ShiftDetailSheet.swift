import SwiftUI

/// Color y texto del estado de un turno (los mismos de Semana).
func shiftStatusColor(_ st: Calc.Status) -> Color {
    switch st {
    case .now: return T.orange
    case .missed: return T.danger
    case .upcoming: return T.success
    case .past: return T.text3
    }
}

func shiftStatusLabel(_ st: Calc.Status) -> String {
    switch st {
    case .now: return L("En curso")
    case .missed: return L("No marcado")
    case .upcoming: return L("Próximamente")
    case .past: return L("Horario pasado")
    }
}

/// Detalle de un turno: se abre al mantener pulsada su tarjeta en
/// Semana. Lee el turno del almacén, así refleja los cambios al
/// instante.
struct ShiftDetailSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var shiftId: String
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    private var fmt12: Bool { store.settings.formatoHora == "12h" }
    private var hidden: Bool { store.settings.dineroOculto }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let s = store.shift(id: shiftId) {
                    content(s)
                        .padding(16)
                }
            }
            .background(T.bg)
            .navigationTitle(L("Detalle del turno"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Cerrar")) { dismiss() }
                }
            }
        }
        .font(.turniq(15))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func time(_ hm: String?) -> String {
        hm.map { Calc.fmtTime($0, format12: fmt12) } ?? "—"
    }

    @ViewBuilder
    private func content(_ s: Shift) -> some View {
        let job = store.job(id: s.jobId)
        let st = Calc.status(s)
        let stations = s.estacionIds.compactMap { id in
            job?.estaciones.first(where: { $0.id == id })?.nombre
        }
        let scheduled = Calc.scheduledHours(s)
        let worked = Calc.shiftHours(s)
        let pay = Calc.weekTotals(shifts: [s], jobsById: store.jobsById, umbralExtraHrs: 1e9, multExtra: 1)
        let payday = job.flatMap { Pay.payday(covering: s.fecha, job: $0, settings: store.settings) }
        let dayTitle = "\(Calc.daysLong[Calc.weekdayIndex(s.fecha)]) \(Calc.shortDate(s.fecha))"

        VStack(alignment: .leading, spacing: 12) {
            // Encabezado
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2).fill(shiftStatusColor(st)).frame(width: 4, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(T.hex(job?.color ?? "#0064E0")).frame(width: 10, height: 10)
                        Text(s.esLibre ? L("Día libre") : (job?.nombre ?? ""))
                            .font(.turniq(20, .bold)).foregroundStyle(T.text).lineLimit(1)
                    }
                    Text(dayTitle).font(.turniq(14)).foregroundStyle(T.text2)
                }
                Spacer(minLength: 8)
                Text(shiftStatusLabel(st))
                    .font(.turniq(12, .bold)).foregroundStyle(shiftStatusColor(st))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(shiftStatusColor(st).opacity(0.12), in: Capsule())
            }

            if !s.esLibre {
                // Horario
                Card {
                    VStack(spacing: 0) {
                        row(L("Programado"), Calc.rangeLabel(s, format12: fmt12), bold: true)
                        line
                        row(L("Entrada real"), s.horaEntradaReal == nil ? L("Sin marcar") : time(s.horaEntradaReal))
                        line
                        row(L("Salida real"), s.horaSalidaReal == nil ? L("Sin marcar") : time(s.horaSalidaReal))
                        line
                        row(L("Descanso"), "\(s.breakMin) min")
                        line
                        row(L("Horas programadas"), Calc.fmtHoursLong(scheduled))
                        if s.horaEntradaReal != nil {
                            line
                            row(L("Horas trabajadas"), Calc.fmtHoursLong(worked), bold: true)
                        }
                    }
                }

                // Dinero
                TintedCard(accent: "#30A46C") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            DarkStat(label: L("Bruto estimado"), value: T.cash(pay.gross, hidden: hidden))
                            Spacer()
                            DarkStat(label: L("Neto estimado"), value: T.cash(pay.net, hidden: hidden),
                                     color: T.money, alignment: .trailing)
                        }
                        HStack(alignment: .top) {
                            DarkStat(label: L("Sueldo"), value: hidden ? "••••" : "\(Calc.money(Calc.rate(s, job: job)))/h" + (Calc.multiplier(s) != 1 ? " ×\(ShiftFormView.num(Calc.multiplier(s)))" : ""))
                            Spacer()
                            DarkStat(label: "Taxes", value: T.cash(pay.taxes, hidden: hidden), alignment: .trailing)
                        }
                        if s.propinas > 0 || s.bono > 0 {
                            HStack(alignment: .top) {
                                DarkStat(label: L("Propinas"), value: T.cash(s.propinas, hidden: hidden))
                                Spacer()
                                DarkStat(label: L("Bono"), value: T.cash(s.bono, hidden: hidden), alignment: .trailing)
                            }
                        }
                    }
                }

                // Datos del trabajo
                Card {
                    VStack(spacing: 0) {
                        if let pin = job?.pinMarcaje, !pin.isEmpty {
                            row(L("PIN del reloj"), pin, bold: true)
                            line
                        }
                        if !stations.isEmpty {
                            row(L("Estaciones"), stations.joined(separator: ", "))
                            line
                        }
                        row(L("Se cobra"), payday.map { Calc.weekdayDate($0) } ?? "—")
                    }
                }

                if !s.notas.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            MonoLabel(text: L("Notas"))
                            Text(s.notas).font(.turniq(15)).foregroundStyle(T.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                GhostButton(title: L("Editar"), icon: "pencil") {
                    dismiss()
                    onEdit()
                }
                GhostButton(title: L("Duplicar"), icon: "plus.square.on.square") {
                    store.duplicateShift(id: s.id)
                    dismiss()
                }
            }
            Button {
                dismiss()
                onDelete()
            } label: {
                Text(L("Eliminar turno"))
                    .font(.turniq(15, .bold)).foregroundStyle(T.danger)
                    .frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(PressStyle())
        }
    }

    private var line: some View {
        Rectangle().fill(T.line).frame(height: 0.5)
    }

    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.turniq(14)).foregroundStyle(T.text2)
            Spacer(minLength: 12)
            Text(value)
                .font(.turniq(15, bold ? .bold : .medium))
                .foregroundStyle(T.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}
