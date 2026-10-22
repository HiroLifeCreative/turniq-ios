import SwiftUI

/// Trabajos en TARJETAS (radio 20, como el resto de la app) —
/// nada de listas del sistema.
struct JobsView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Job? = nil
    @State private var creating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.jobs) { job in
                    Button { editing = job } label: {
                        HStack(spacing: 12) {
                            Circle().fill(T.hex(job.color)).frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(job.nombre).font(.headline).foregroundStyle(.primary)
                                Text("\(Calc.money(job.sueldoHora))/h · \(job.taxPct.formatted())% taxes\(job.pinMarcaje.map { " · PIN \($0)" } ?? "")")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                if !job.estaciones.isEmpty {
                                    Text(job.estaciones.map { $0.nombre }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Eliminar", role: .destructive) { store.deleteJob(id: job.id) }
                    }
                }
                if store.jobs.isEmpty {
                    Text("Todavía no tienes trabajos. Crea el primero con el botón de abajo.")
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                PrimaryButton(title: "Nuevo trabajo") { creating = true }
            }
            .padding()
        }
        .sheet(item: $editing) { j in JobFormView(editing: j) }
        .sheet(isPresented: $creating) { JobFormView(editing: nil) }
    }
}

struct JobFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: Job?

    @State private var nombre = ""
    @State private var color = Job.palette[0]
    @State private var sueldo = ""
    @State private var tax = ""
    @State private var pinReloj = ""
    @State private var estaciones: [Station] = []
    @State private var nuevaEstacion = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Trabajo") {
                    TextField("Nombre", text: $nombre)
                    HStack {
                        Text("Color")
                        Spacer()
                        ForEach(Job.palette, id: \.self) { c in
                            Circle()
                                .fill(T.hex(c))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(Color.primary, lineWidth: color == c ? 2 : 0))
                                .onTapGesture { color = c }
                        }
                    }
                    TextField("Sueldo por hora ($)", text: $sueldo)
                        .keyboardType(.decimalPad)
                    TextField("% de taxes", text: $tax)
                        .keyboardType(.decimalPad)
                }
                Section {
                    TextField("Ej. 2001", text: $pinReloj)
                        .keyboardType(.numberPad)
                } header: {
                    Text("PIN del reloj (opcional)")
                } footer: {
                    Text("El PIN que marcas en el reloj de este trabajo. Turniq te lo muestra al marcar entrada, para que no se te olvide.")
                }
                Section("Estaciones") {
                    ForEach(estaciones) { st in
                        Text(st.nombre)
                    }
                    .onDelete { estaciones.remove(atOffsets: $0) }
                    HStack {
                        TextField("Nueva estación", text: $nuevaEstacion)
                        Button("Añadir") {
                            let n = nuevaEstacion.trimmingCharacters(in: .whitespaces)
                            if !n.isEmpty {
                                estaciones.append(Station(id: UUID().uuidString, nombre: n))
                                nuevaEstacion = ""
                            }
                        }
                        .disabled(nuevaEstacion.isEmpty)
                    }
                }
                if editing != nil {
                    Section {
                        Button("Eliminar trabajo", role: .destructive) {
                            if let e = editing { store.deleteJob(id: e.id) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Nuevo trabajo" : "Editar trabajo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(nombre.isEmpty)
                }
            }
            .onAppear {
                if let e = editing {
                    nombre = e.nombre
                    color = e.color
                    sueldo = "\(e.sueldoHora)"
                    tax = "\(e.taxPct)"
                    pinReloj = e.pinMarcaje ?? ""
                    estaciones = e.estaciones
                }
            }
        }
    }

    private func save() {
        let pin = pinReloj.trimmingCharacters(in: .whitespaces)
        store.upsertJob(Job(
            id: editing?.id ?? UUID().uuidString,
            nombre: nombre,
            color: color,
            sueldoHora: Double(sueldo.replacingOccurrences(of: ",", with: ".")) ?? 0,
            taxPct: Double(tax.replacingOccurrences(of: ",", with: ".")) ?? 0,
            estaciones: estaciones,
            pinMarcaje: pin.isEmpty ? nil : pin
        ))
        dismiss()
    }
}
