import SwiftUI
import UniformTypeIdentifiers

/// Ajustes (se abre desde Más): perfil, apariencia, trabajo, cobro,
/// seguridad y datos (respaldo compatible con Android).
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var pinInput = ""
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmWipe = false
    @State private var importMessage: String? = nil

    /// Enlace a un campo de Ajustes.
    private func bind<V>(_ kp: WritableKeyPath<Settings, V>) -> Binding<V> {
        Binding(
            get: { store.settings[keyPath: kp] },
            set: { v in store.setSettings { $0[keyPath: kp] = v } }
        )
    }

    private var cierreAuto: Binding<Date> {
        Binding(
            get: { ShiftFormView.date(fromHHMM: store.settings.cierreAuto) },
            set: { d in store.setSettings { $0.cierreAuto = Calc.hhmm(d) } }
        )
    }

    private static let avisos: [(min: Int, label: String)] = [
        (1440, "1 día antes"), (60, "1 hora antes"), (30, "30 min antes"),
        (15, "15 min antes"), (0, "Al momento"),
    ]

    var body: some View {
        Form {
            Section("Perfil") {
                TextField("Tu nombre", text: bind(\.nombreUsuario))
            }

            Section("Apariencia") {
                Toggle("Modo oscuro", isOn: bind(\.dark))
                Picker("Formato de hora", selection: bind(\.formatoHora)) {
                    Text("12 h").tag("12h")
                    Text("24 h").tag("24h")
                }
                Toggle("Dinero oculto", isOn: bind(\.dineroOculto))
            }

            Section {
                Picker("Día de cobro general", selection: bind(\.diaCobro)) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(Calc.daysLong[i]).tag(i)
                    }
                }
                Toggle("Avisarme el día de cobro", isOn: bind(\.avisoCobro))
            } header: {
                Text("Cobro")
            } footer: {
                Text("Cada trabajo puede tener su propio ritmo (cada semana o cada 2 semanas) y su día: se cambia en Trabajos → Editar → Cobro. Este día se usa para los trabajos que no lo tengan.")
            }

            Section {
                LabeledContent("Hora extra después de (h/sem)") {
                    TextField("40", value: bind(\.umbralExtraHrs), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                LabeledContent("Multiplicador") {
                    TextField("1.5", value: bind(\.multExtra), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                Toggle("Mostrar hora extra", isOn: bind(\.mostrarHoraExtra))
                LabeledContent("Meta semanal ($)") {
                    TextField("600", value: bind(\.metaSemanal), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                Toggle("Mostrar meta", isOn: bind(\.mostrarMeta))
                DatePicker("Cierre automático", selection: cierreAuto, displayedComponents: [.hourAndMinute])
            } header: {
                Text("Trabajo")
            } footer: {
                Text("La hora extra se cuenta por cada trabajo por separado, nunca sumando todos tus trabajos. Si un turno queda abierto, se cierra solo a la hora de cierre automático del día siguiente.")
            }

            Section {
                ForEach(Self.avisos, id: \.min) { a in
                    Toggle(a.label, isOn: Binding(
                        get: { store.settings.avisosMin.contains(a.min) },
                        set: { on in
                            store.setSettings { s in
                                s.avisosMin.removeAll { $0 == a.min }
                                if on { s.avisosMin.append(a.min) }
                            }
                        }
                    ))
                }
                Toggle("Avisar al llegar al trabajo", isOn: bind(\.avisoLlegada))
                Toggle("Actividad en Vivo al marcar entrada", isOn: bind(\.actividadEnVivo))
            } header: {
                Text("Avisos de turno")
            } footer: {
                Text("En iPhone los avisos son notificaciones con sonido; Apple no permite alarmas a pantalla completa a otras apps.")
            }

            Section("Seguridad") {
                if store.settings.pin == nil {
                    HStack {
                        SecureField("PIN de 4 dígitos", text: $pinInput)
                            .keyboardType(.numberPad)
                        Button("Guardar") {
                            if pinInput.count == 4, pinInput.allSatisfy({ $0.isNumber }) {
                                store.setSettings { $0.pin = pinInput }
                                pinInput = ""
                            }
                        }
                        .disabled(pinInput.count != 4)
                    }
                } else {
                    Toggle("Face ID / Touch ID", isOn: bind(\.biometrico))
                    Button("Quitar PIN", role: .destructive) {
                        store.setSettings { $0.pin = nil; $0.biometrico = false }
                    }
                }
            }

            Section {
                Button("Exportar respaldo (JSON)") { exporting = true }
                Button("Importar respaldo") { importing = true }
                if let importMessage {
                    Text(importMessage).font(.footnote).foregroundStyle(.secondary)
                }
                Button("Borrar todos los datos", role: .destructive) { confirmWipe = true }
            } header: {
                Text("Datos")
            } footer: {
                Text("El respaldo es compatible con Turniq para Android: lo que exportas en una app se importa en la otra. Además Turniq guarda sola una copia diaria (las últimas 14) en la app Archivos → En mi iPhone → Turniq → Respaldos, que también entra en la copia de iCloud del iPhone.")
            }
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Borrar TODOS los datos de Turniq?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) { store.wipeAll() }
            Button("Cancelar", role: .cancel) {}
        }
        .fileExporter(
            isPresented: $exporting,
            document: JSONDocument(data: store.exportJSON() ?? Data()),
            contentType: .json,
            defaultFilename: "turniq-backup-\(Calc.todayYmd())"
        ) { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let raw = try? Data(contentsOf: url), store.importMerge(raw) {
                importMessage = "Respaldo importado."
            } else {
                importMessage = "No pude importar ese archivo."
            }
        }
    }
}

struct JSONDocument: FileDocument {
    var data: Data
    static var readableContentTypes: [UTType] { [.json] }
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
