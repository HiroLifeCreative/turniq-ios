import SwiftUI

/// Formulario de turno (crear/editar). Convierte entre los strings
/// del modelo ("YYYY-MM-DD", "HH:mm") y los Date de los pickers.
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Trabajo") {
                    Picker("Trabajo", selection: $jobId) {
                        ForEach(store.jobs) { j in
                            Text(j.nombre).tag(j.id)
                        }
                    }
                    Toggle("Día libre", isOn: $esLibre)
                }
                if !esLibre {
                    Section("Horario") {
                        DatePicker("Fecha", selection: $fecha, displayedComponents: [.date])
                        DatePicker("Entrada", selection: $entrada, displayedComponents: [.hourAndMinute])
                        Toggle("Sin hora de salida", isOn: $sinSalida)
                        if !sinSalida {
                            DatePicker("Salida", selection: $salida, displayedComponents: [.hourAndMinute])
                            if Calc.isOvernight(entrada: Self.hhmm(entrada), salida: Self.hhmm(salida)) {
                                Text("Termina al día siguiente (+1 día)")
                                    .font(.caption).foregroundStyle(T.amber)
                            }
                        }
                        Stepper("Descanso: \(breakMin) min", value: $breakMin, in: 0...240, step: 5)
                    }
                    if let job = store.job(id: jobId), !job.estaciones.isEmpty {
                        Section("Estaciones") {
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
                    Section("Extras") {
                        TextField("Propinas ($)", text: $propinas)
                            .keyboardType(.decimalPad)
                        TextField("Bono ($)", text: $bono)
                            .keyboardType(.decimalPad)
                        TextField("Notas", text: $notas)
                    }
                }
                if editing != nil {
                    Section {
                        Button("Eliminar turno", role: .destructive) {
                            if let e = editing { store.deleteShift(id: e.id) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Nuevo turno" : "Editar turno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(jobId.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let e = editing {
            jobId = e.jobId
            fecha = Calc.parseDay(e.fecha) ?? Date()
            entrada = Self.date(fromHHMM: e.horaEntrada)
            salida = Self.date(fromHHMM: e.horaSalida ?? e.horaEntrada)
            sinSalida = e.horaSalida == nil
            esLibre = e.esLibre
            breakMin = e.breakMin
            propinas = e.propinas > 0 ? "\(e.propinas)" : ""
            bono = e.bono > 0 ? "\(e.bono)" : ""
            notas = e.notas
            estacionesSel = Set(e.estacionIds)
        } else {
            jobId = store.jobs.first?.id ?? ""
            fecha = Calc.parseDay(defaultFecha ?? Calc.todayYmd()) ?? Date()
            entrada = Self.date(fromHHMM: "09:00")
            salida = Self.date(fromHHMM: "17:00")
        }
    }

    private func save() {
        let shift = Shift(
            id: editing?.id ?? UUID().uuidString,
            jobId: jobId,
            esLibre: esLibre,
            estacionIds: Array(estacionesSel),
            fecha: Calc.ymd(fecha),
            horaEntrada: Self.hhmm(entrada),
            horaSalida: sinSalida ? nil : Self.hhmm(salida),
            horaEntradaReal: editing?.horaEntradaReal,
            horaSalidaReal: editing?.horaSalidaReal,
            breakMin: breakMin,
            propinas: Double(propinas.replacingOccurrences(of: ",", with: ".")) ?? 0,
            bono: Double(bono.replacingOccurrences(of: ",", with: ".")) ?? 0,
            notas: notas,
            gcalEventId: editing?.gcalEventId
        )
        store.upsertShift(shift)
        Notifications.reschedule(store: store)
        dismiss()
    }

    static func hhmm(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    static func date(fromHHMM hm: String) -> Date {
        let parts = hm.split(separator: ":")
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = parts.count > 0 ? Int(parts[0]) ?? 9 : 9
        comps.minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}
