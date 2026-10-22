import SwiftUI
import UniformTypeIdentifiers

/// Ajustes + (por ahora) el resto del menú Más en iOS: datos
/// (exportar/importar respaldo compatible con Android) y peligro.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var pinInput = ""
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmWipe = false
    @State private var importError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Perfil") {
                    TextField("Tu nombre", text: Binding(
                        get: { store.settings.nombreUsuario },
                        set: { v in store.setSettings { $0.nombreUsuario = v } }
                    ))
                }

                Section("Apariencia") {
                    Toggle("Modo oscuro", isOn: Binding(
                        get: { store.settings.dark },
                        set: { v in store.setSettings { $0.dark = v } }
                    ))
                    Picker("Formato de hora", selection: Binding(
                        get: { store.settings.formatoHora },
                        set: { v in store.setSettings { $0.formatoHora = v } }
                    )) {
                        Text("12 h").tag("12h")
                        Text("24 h").tag("24h")
                    }
                }

                Section {
                    HStack {
                        Text("Después de (h/sem, por trabajo)")
                        Spacer()
                        TextField("40", value: Binding(
                            get: { store.settings.umbralExtraHrs },
                            set: { v in store.setSettings { $0.umbralExtraHrs = v ?? 40 } }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    }
                    HStack {
                        Text("Multiplicador")
                        Spacer()
                        TextField("1.5", value: Binding(
                            get: { store.settings.multExtra },
                            set: { v in store.setSettings { $0.multExtra = v ?? 1.5 } }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    }
                    Toggle("Mostrar hora extra", isOn: Binding(
                        get: { store.settings.mostrarHoraExtra },
                        set: { v in store.setSettings { $0.mostrarHoraExtra = v } }
                    ))
                    HStack {
                        Text("Meta semanal ($)")
                        Spacer()
                        TextField("600", value: Binding(
                            get: { store.settings.metaSemanal },
                            set: { v in store.setSettings { $0.metaSemanal = v ?? 0 } }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                    }
                    Toggle("Mostrar meta", isOn: Binding(
                        get: { store.settings.mostrarMeta },
                        set: { v in store.setSettings { $0.mostrarMeta = v } }
                    ))
                } header: {
                    Text("Horas extra y meta")
                } footer: {
                    Text("La hora extra se cuenta por cada trabajo por separado, nunca sumando todos tus trabajos.")
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
                        Button("Quitar PIN", role: .destructive) {
                            store.setSettings { $0.pin = nil; $0.biometrico = false }
                        }
                        Toggle("Face ID / Touch ID", isOn: Binding(
                            get: { store.settings.biometrico },
                            set: { v in store.setSettings { $0.biometrico = v } }
                        ))
                    }
                }

                Section("Datos") {
                    Button("Exportar respaldo (JSON)") { exporting = true }
                    Button("Importar respaldo") { importing = true }
                    Button("Borrar todos los datos", role: .destructive) { confirmWipe = true }
                }

                Section {
                    Text("Turniq para iOS — versión nativa (SwiftUI). Mismos datos y reglas que tu app de Android.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Más")
            .confirmationDialog("¿Borrar TODOS los datos de Turniq?", isPresented: $confirmWipe) {
                Button("Borrar todo", role: .destructive) { store.wipeAll() }
                Button("Cancelar", role: .cancel) {}
            }
            .alert("No pude importar ese archivo", isPresented: $importError) {
                Button("OK", role: .cancel) {}
            }
            .fileExporter(
                isPresented: $exporting,
                document: JSONDocument(data: store.exportJSON() ?? Data()),
                contentType: .json,
                defaultFilename: "turniq-respaldo.json"
            ) { _ in }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result,
                   url.startAccessingSecurityScopedResource(),
                   let raw = try? Data(contentsOf: url) {
                    url.stopAccessingSecurityScopedResource()
                    if !store.importMerge(raw) { importError = true }
                }
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
