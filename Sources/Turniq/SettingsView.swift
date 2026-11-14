import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Ajustes (se abre desde Más): perfil, apariencia, trabajo, cobro,
/// seguridad y datos (respaldo compatible con Android).
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var pinInput = ""
    @State private var shareFile: ShareFile? = nil
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

    private static var avisos: [(min: Int, label: String)] {
        [
            (1440, L("1 día antes")), (60, L("1 hora antes")), (30, L("30 min antes")),
            (15, L("15 min antes")), (0, L("Al momento")),
        ]
    }

    var body: some View {
        Form {
            Section(L("Apariencia")) {
                Picker(L("Idioma / Language"), selection: bind(\.idioma)) {
                    Text(verbatim: "Español").tag("es")
                    Text(verbatim: "English").tag("en")
                }
                Toggle(L("Modo oscuro"), isOn: bind(\.dark))
                Picker(L("Formato de hora"), selection: bind(\.formatoHora)) {
                    Text("12 h").tag("12h")
                    Text("24 h").tag("24h")
                }
                Toggle(L("Dinero oculto"), isOn: bind(\.dineroOculto))
            }

            Section {
                Picker(L("Día de cobro general"), selection: bind(\.diaCobro)) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(Calc.daysLong[i]).tag(i)
                    }
                }
                Toggle(L("Avisarme el día de cobro"), isOn: bind(\.avisoCobro))
            } header: {
                Text(L("Cobro"))
            } footer: {
                Text(L("Cada trabajo puede tener su propio ritmo (cada semana o cada 2 semanas) y su día: se cambia en Trabajos → Editar → Cobro. Este día se usa para los trabajos que no lo tengan."))
            }

            Section {
                LabeledContent(L("Hora extra después de (h/sem)")) {
                    TextField("40", value: bind(\.umbralExtraHrs), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                LabeledContent(L("Multiplicador")) {
                    TextField("1.5", value: bind(\.multExtra), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                Toggle(L("Mostrar hora extra"), isOn: bind(\.mostrarHoraExtra))
                LabeledContent(L("Meta semanal (\(Money.symbol))")) {
                    TextField("600", value: bind(\.metaSemanal), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                Toggle(L("Mostrar meta"), isOn: bind(\.mostrarMeta))
                DatePicker(L("Cierre automático"), selection: cierreAuto, displayedComponents: [.hourAndMinute])
            } header: {
                Text(L("Trabajo"))
            } footer: {
                Text(L("La hora extra se cuenta por cada trabajo por separado, nunca sumando todos tus trabajos. Si un turno queda abierto, se cierra solo a la hora de cierre automático del día siguiente."))
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
                Toggle(L("Avisar al llegar al trabajo"), isOn: bind(\.avisoLlegada))
                Toggle(L("Avisar si me acerco a la hora extra"), isOn: bind(\.avisoHoraExtra))
                Toggle(L("Preguntar propinas al marcar salida"), isOn: bind(\.preguntarPropinas))
                Toggle(L("Actividad en Vivo al marcar entrada"), isOn: bind(\.actividadEnVivo))
            } header: {
                Text(L("Avisos de turno"))
            } footer: {
                Text(L("En iPhone los avisos son notificaciones con sonido; Apple no permite alarmas a pantalla completa a otras apps."))
            }

            Section(L("Seguridad")) {
                if store.settings.pin == nil {
                    HStack {
                        SecureField(L("PIN de 4 dígitos"), text: $pinInput)
                            .keyboardType(.numberPad)
                        Button(L("Guardar")) {
                            if pinInput.count == 4, pinInput.allSatisfy({ $0.isNumber }) {
                                store.setSettings { $0.pin = pinInput }
                                pinInput = ""
                            }
                        }
                        .disabled(pinInput.count != 4)
                    }
                } else {
                    Toggle("Face ID / Touch ID", isOn: bind(\.biometrico))
                    Button(L("Quitar PIN"), role: .destructive) {
                        store.setSettings { $0.pin = nil; $0.biometrico = false }
                    }
                }
            }

            Section {
                Button(L("Exportar respaldo (JSON)")) { exportBackup() }
                Button(L("Importar respaldo")) { importing = true }
                if let importMessage {
                    Text(importMessage).font(.footnote).foregroundStyle(.secondary)
                }
                Button(L("Borrar los datos de esta cuenta"), role: .destructive) { confirmWipe = true }
            } header: {
                Text(L("Datos"))
            } footer: {
                Text(L("El respaldo es compatible con Turniq para Android: lo que exportas en una app se importa en la otra. Además Turniq guarda sola una copia diaria (las últimas 14) en la app Archivos → En mi iPhone → Turniq → Respaldos, que también entra en la copia de iCloud del iPhone.") + " " + L("El respaldo incluye solo la cuenta en uso: exporta cada cuenta por separado."))
            }
        }
        .navigationTitle(L("Ajustes"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("¿Borrar los trabajos, turnos y cheques de esta cuenta? Las otras cuentas no se tocan."), isPresented: $confirmWipe, titleVisibility: .visible) {
            Button(L("Borrar todo"), role: .destructive) { store.wipeAll() }
            Button(L("Cancelar"), role: .cancel) {}
        }
        // Exportar: hoja de Compartir de iOS con el archivo ya escrito
        // (Guardar en Archivos, AirDrop, WhatsApp, correo…).
        .sheet(item: $shareFile) { f in
            ActivityView(items: [f.url])
                .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let raw = try? Data(contentsOf: url), store.importMerge(raw) {
                importMessage = L("Respaldo importado.")
            } else {
                importMessage = L("No pude importar ese archivo.")
            }
        }
    }
}

extension SettingsView {
    /// Escribe el respaldo en un archivo temporal y abre Compartir.
    fileprivate func exportBackup() {
        guard let raw = store.exportJSON() else {
            importMessage = L("No pude crear el respaldo.")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("turniq-backup-\(Calc.todayYmd()).json")
        do {
            try raw.write(to: url, options: [.atomic])
            importMessage = nil
            shareFile = ShareFile(url: url)
        } catch {
            importMessage = L("No pude crear el respaldo.")
        }
    }
}

struct ShareFile: Identifiable {
    var url: URL
    var id: String { url.path }
}

/// Hoja de Compartir del sistema.
struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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
