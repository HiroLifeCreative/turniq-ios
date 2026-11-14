import SwiftUI

/// Formulario de turno (crear/editar). Convierte entre los strings
/// del modelo ("YYYY-MM-DD", "HH:mm") y los Date de los pickers.
/// Al editar deja corregir las horas REALES (las que mandan en el
/// dinero) por si se olvidó marcar.
struct ShiftFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var editing: Shift?
    var defaultFecha: String? = nil

    @State private var jobId: String = ""
    @State private var fecha: Date = Date()
    @State private var entrada: Date = Date()
    @State private var salida: Date = Date()
    @State private var sinSalida = false
    @State private var esLibre = false
    @State private var breakMin: Int = 0
    @State private var propinas: String = ""
    @State private var bono: String = ""
    @State private var notas: String = ""
    @State private var estacionesSel: Set<String> = []
    @State private var marcoEntrada = false
    @State private var marcoSalida = false
    @State private var entradaReal: Date = Date()
    @State private var salidaReal: Date = Date()
    @State private var mult: Double = 1
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Trabajo")) {
                    Picker(L("Trabajo"), selection: $jobId) {
                        ForEach(store.jobs) { j in
                            Text(j.nombre).tag(j.id)
                        }
                    }
                    Toggle(L("Día libre"), isOn: $esLibre)
                }
                Section(L("Fecha")) {
                    DatePicker(L("Fecha"), selection: $fecha, displayedComponents: [.date])
                }
                if !esLibre {
                    Section(L("Horario")) {
                        DatePicker(L("Entrada"), selection: $entrada, displayedComponents: [.hourAndMinute])
                        Toggle(L("Sin hora de salida"), isOn: $sinSalida)
                        if !sinSalida {
                            DatePicker(L("Salida"), selection: $salida, displayedComponents: [.hourAndMinute])
                            if Calc.isOvernight(entrada: Calc.hhmm(entrada), salida: Calc.hhmm(salida)) {
                                Text(L("Termina al día siguiente: \(Calc.shortDate(Calc.addDays(Calc.ymd(fecha), 1)))"))
                                    .font(.caption).foregroundStyle(T.amber)
                            }
                        }
                        Stepper(L("Descanso: \(breakMin) min"), value: $breakMin, in: 0...240, step: 5)
                        Picker(L("Pago de este turno"), selection: $mult) {
                            Text(L("Normal")).tag(1.0)
                            Text(L("Tiempo y medio (×1.5)")).tag(1.5)
                            Text(L("Feriado / doble (×2)")).tag(2.0)
                        }
                    }
                    if let job = store.job(id: jobId), !job.estaciones.isEmpty {
                        Section(L("Estaciones")) {
                            ForEach(job.estaciones) { st in
                                Toggle(st.nombre, isOn: Binding(
                                    get: { estacionesSel.contains(st.id) },
                                    set: { on in
                                        if on { estacionesSel.insert(st.id) } else { estacionesSel.remove(st.id) }
                                    }
                                ))
                            }
                        }
                    }
                    if editing != nil {
                        Section {
                            Toggle(L("Marqué entrada"), isOn: $marcoEntrada)
                            if marcoEntrada {
                                DatePicker(L("Entrada real"), selection: $entradaReal, displayedComponents: [.hourAndMinute])
                                Toggle(L("Marqué salida"), isOn: $marcoSalida)
                                if marcoSalida {
                                    DatePicker(L("Salida real"), selection: $salidaReal, displayedComponents: [.hourAndMinute])
                                }
                            }
                        } header: {
                            Text(L("Horas trabajadas (reales)"))
                        } footer: {
                            Text(L("Si marcaste, el dinero se calcula con estas horas y no con las programadas."))
                        }
                    }
                    Section("Extras") {
                        TextField(L("Propinas (\(Money.symbol))"), text: $propinas)
                            .keyboardType(.decimalPad)
                        TextField(L("Bono (\(Money.symbol))"), text: $bono)
                            .keyboardType(.decimalPad)
                        TextField(L("Notas"), text: $notas, axis: .vertical)
                    }
                }
                if editing != nil {
                    Section {
                        Button(L("Eliminar turno"), role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? L("Nuevo turno") : L("Editar turno"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Guardar")) { save() }.disabled(jobId.isEmpty)
                }
            }
            .confirmationDialog(L("¿Eliminar este turno?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L("Eliminar"), role: .destructive) {
                    if let e = editing { store.deleteShift(id: e.id) }
                    dismiss()
                }
                Button(L("Cancelar"), role: .cancel) {}
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let e = editing {
            jobId = e.jobId
            fecha = Calc.parseDay(e.fecha) ?? Date()
            entrada = Self.date(fromHHMM: e.horaEntrada)
            salida = Self.date(fromHHMM: e.horaSalida ?? e.horaEntrada)
            sinSalida = e.horaSalida == nil
            esLibre = e.esLibre
            breakMin = e.breakMin
            propinas = e.propinas > 0 ? Self.num(e.propinas) : ""
            bono = e.bono > 0 ? Self.num(e.bono) : ""
            notas = e.notas
            estacionesSel = Set(e.estacionIds)
            mult = [1.0, 1.5, 2.0].contains(Calc.multiplier(e)) ? Calc.multiplier(e) : 1
            marcoEntrada = e.horaEntradaReal != nil
            marcoSalida = e.horaSalidaReal != nil
            entradaReal = Self.date(fromHHMM: e.horaEntradaReal ?? e.horaEntrada)
            salidaReal = Self.date(fromHHMM: e.horaSalidaReal ?? e.horaSalida ?? e.horaEntrada)
        } else {
            jobId = store.jobs.first?.id ?? ""
            fecha = Calc.parseDay(defaultFecha ?? Calc.todayYmd()) ?? Date()
            entrada = Self.date(fromHHMM: "09:00")
            salida = Self.date(fromHHMM: "17:00")
        }
    }

    private func save() {
        let day = Calc.ymd(fecha)
        let inHm = Calc.hhmm(entrada)
        let outHm: String? = (sinSalida || esLibre) ? nil : Calc.hhmm(salida)
        // Fecha de salida explícita (como Android): el día siguiente
        // si la salida es menor o igual a la entrada.
        let outDay: String? = outHm == nil ? nil
            : (Calc.isOvernight(entrada: inHm, salida: outHm) ? Calc.addDays(day, 1) : day)

        var realIn: String? = nil
        var realOut: String? = nil
        var realOutDay: String? = nil
        if editing != nil && marcoEntrada && !esLibre {
            let rIn = Calc.hhmm(entradaReal)
            realIn = rIn
            if marcoSalida {
                let rOut = Calc.hhmm(salidaReal)
                realOut = rOut
                realOutDay = Calc.isOvernight(entrada: rIn, salida: rOut) ? Calc.addDays(day, 1) : day
            }
        }

        let shift = Shift(
            id: editing?.id ?? UUID().uuidString,
            jobId: jobId,
            esLibre: esLibre,
            estacionIds: Array(estacionesSel),
            fecha: day,
            fechaSalida: outDay,
            horaEntrada: inHm,
            horaSalida: outHm,
            horaEntradaReal: realIn,
            horaSalidaReal: realOut,
            fechaSalidaReal: realOutDay,
            breakMin: breakMin,
            propinas: Self.parse(propinas),
            bono: Self.parse(bono),
            notas: notas,
            gcalEventId: editing?.gcalEventId,
            multiplicador: (mult == 1 || esLibre) ? nil : mult
        )
        store.upsertShift(shift)
        dismiss()
    }

    static func parse(_ s: String) -> Double {
        max(0, Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    /// "12.5" / "12" — sin ceros de más.
    static func num(_ n: Double) -> String {
        n == n.rounded() ? String(Int(n)) : String(n)
    }

    static func date(fromHHMM hm: String) -> Date {
        let parts = hm.split(separator: ":")
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = parts.count > 0 ? Int(parts[0]) ?? 9 : 9
        comps.minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}
