import SwiftUI
import UIKit

/// Menú "Más" (hoja modal): filas simples con ícono, sin contenedores
/// de color, y el pie con versión y créditos — igual que Android.
struct MasView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Dest: Hashable { case settings, calendar, shortcuts, changelog }

    private let items: [(dest: Dest, icon: String, label: String)] = [
        (.settings, "gearshape", "Ajustes"),
        (.calendar, "calendar", "Calendario del iPhone"),
        (.shortcuts, "bolt.circle", "Atajos, Siri y Widgets"),
        (.changelog, "sparkles", "Novedades"),
    ]

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.2.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                        NavigationLink(value: it.dest) {
                            HStack(spacing: 12) {
                                Image(systemName: it.icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(T.text2)
                                    .frame(width: 26)
                                Text(it.label)
                                    .font(.turniq(17)).foregroundStyle(T.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(T.text3)
                            }
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if idx < items.count - 1 {
                            Rectangle().fill(T.line).frame(height: 0.5)
                        }
                    }

                    VStack(spacing: 8) {
                        Text("Turniq iOS \(version)")
                        Link(destination: URL(string: "https://www.instagram.com/SoyNelsonHerrera")!) {
                            Image(systemName: "camera")
                                .font(.system(size: 16))
                                .padding(8)
                        }
                        .accessibilityLabel("Instagram")
                        Text("Desarrollado por Nelson Herrera")
                        Text("© 2026 HiroLifeStudio · Todos los derechos reservados")
                    }
                    .font(.turniq(12))
                    .foregroundStyle(T.text3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(T.bg)
            .navigationTitle("Más")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .navigationDestination(for: Dest.self) { d in
                switch d {
                case .settings: SettingsView()
                case .calendar: CalendarSyncView()
                case .shortcuts: ShortcutsHelpView()
                case .changelog: ChangelogView()
                }
            }
        }
        .font(.turniq(15))
    }
}

/// Novedades de la versión de iOS.
struct ChangelogView: View {
    private let entries: [(version: String, fecha: String, notas: [String])] = [
        ("1.2.0", "2026-11-13", [
            "Widgets para la pantalla de inicio y la pantalla de bloqueo: próximo turno con su PIN, neto de la semana y próximo cobro.",
            "Actividad en Vivo: contador del turno en curso en la pantalla de bloqueo y en la Dynamic Island.",
            "Enlaces para Atajos, Siri y el Botón de Acción: marcar entrada y salida sin buscar la app.",
            "Aviso al llegar al trabajo, con botón para marcar la entrada.",
            "Respaldo automático diario en la app Archivos.",
        ]),
        ("1.1.0", "2026-11-13", [
            "Ícono de la app en la pantalla de inicio del iPhone.",
            "Cobro por trabajo: cada empleo se configura para pagar cada semana o cada 2 semanas, con su día de cobro y su espera (la semana siguiente o 2 semanas después de trabajar).",
            "Tarjeta Próximos cobros en Inicio y Ganancias: fecha de cada cobro, periodo que paga y monto neto.",
            "Aviso la mañana del día de cobro.",
            "Sincronización con el Calendario del iPhone: turnos y días de cobro en un calendario propio llamado Turniq.",
            "Diseño igualado con Android: encabezado por pantalla, héroe con control de privacidad y reloj en vivo, tarjetas de turno con estado por color, Ganancias por semana, mes y año.",
            "Las horas reales marcadas mandan en el cálculo del dinero y se pueden corregir al editar el turno.",
            "Cierre automático de turnos abiertos a la hora tope configurada.",
            "Los respaldos de Android se importan sin errores aunque les falten campos.",
        ]),
        ("1.0.0", "2026-10-22", [
            "Primera versión nativa para iPhone: Inicio, Semana, Trabajos, Ganancias y Ajustes.",
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entries, id: \.version) { e in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("v\(e.version)").font(.turniq(17, .bold)).foregroundStyle(T.text)
                                Spacer()
                                Text(Calc.shortDate(e.fecha) + " " + String(e.fecha.prefix(4)))
                                    .font(.turniq(12)).foregroundStyle(T.text3)
                            }
                            ForEach(e.notas, id: \.self) { n in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle().fill(T.button).frame(width: 5, height: 5)
                                        .padding(.top, 6)
                                    Text(n).font(.turniq(14)).foregroundStyle(T.text2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(T.bg)
        .navigationTitle("Novedades")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Cómo usar los enlaces turniq:// con Atajos, Siri y el Botón de
/// Acción, y cómo añadir los widgets.
struct ShortcutsHelpView: View {
    private let links: [(url: String, what: String)] = [
        ("turniq://marcar", "Marca entrada si no estás trabajando, o salida si ya tienes un turno en curso."),
        ("turniq://entrada", "Marca la entrada del turno de hoy más cercano a la hora actual."),
        ("turniq://salida", "Marca la salida del turno en curso."),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(links, id: \.url) { l in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.url)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(T.primary)
                            .textSelection(.enabled)
                        Text(l.what).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Enlaces de Turniq")
            } footer: {
                Text("Mantén pulsado un enlace para copiarlo.")
            }

            Section("Crear el atajo (una sola vez)") {
                step(1, "Abre la app Atajos y toca + para crear uno nuevo.")
                step(2, "Añade la acción «Abrir URL» y pega turniq://marcar.")
                step(3, "Ponle un nombre fácil de decir, por ejemplo «Marcar turno».")
            }

            Section("Usarlo") {
                step(1, "Siri: di «Oye Siri, Marcar turno».")
                step(2, "Botón de Acción: Ajustes → Botón de Acción → Atajo → elige tu atajo.")
                step(3, "Pantalla de inicio: en el atajo, Compartir → Añadir a pantalla de inicio.")
            }

            Section {
                step(1, "Mantén pulsada la pantalla de inicio y toca Editar → Añadir widget.")
                step(2, "Busca Turniq y elige el tamaño pequeño o mediano.")
                step(3, "Para la pantalla de bloqueo: mantenla pulsada → Personalizar → Añadir widgets → Turniq.")
            } header: {
                Text("Widgets")
            } footer: {
                Text("Los widgets muestran tu próximo turno con su PIN, el neto de la semana y tu próximo cobro. Se actualizan cada vez que abres Turniq o cambias un turno. La Actividad en Vivo aparece sola al marcar entrada.")
            }
        }
        .navigationTitle("Atajos, Siri y Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.footnote.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(T.button, in: Circle())
            Text(text).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

/// Calendario del iPhone: copia turnos y días de cobro a un
/// calendario propio «Turniq».
struct CalendarSyncView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openURL) private var openURL
    @State private var message: String? = nil
    @State private var denied = false
    @State private var confirmRemove = false

    var body: some View {
        Form {
            Section {
                Toggle("Sincronizar con Calendario", isOn: Binding(
                    get: { store.settings.calendarioSync },
                    set: { on in
                        if on { enable() } else { store.setSettings { $0.calendarioSync = false } }
                    }
                ))
            } footer: {
                Text("Turniq crea un calendario propio llamado «Turniq» y copia ahí tus turnos (con el PIN del reloj en las notas) y tus días de cobro. No toca tus otros calendarios. Se actualiza solo cada vez que cambias un turno, de 7 días atrás a 60 días adelante.")
            }

            if denied {
                Section {
                    Button("Abrir Ajustes del iPhone") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } footer: {
                    Text("Turniq no tiene permiso para usar el Calendario. Actívalo en Ajustes → Turniq → Calendarios → Acceso total.")
                }
            }

            if store.settings.calendarioSync {
                Section {
                    Button("Sincronizar ahora") { syncNow() }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Quitar el calendario Turniq", role: .destructive) { confirmRemove = true }
            } footer: {
                Text("Borra el calendario «Turniq» y sus eventos de la app Calendario. Tus turnos dentro de Turniq no se tocan.")
            }
        }
        .navigationTitle("Calendario del iPhone")
        .onAppear { denied = CalendarSync.denied }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Quitar el calendario «Turniq» del iPhone?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Quitar", role: .destructive) {
                store.setSettings { $0.calendarioSync = false }
                CalendarSync.removeCalendar()
                message = nil
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func enable() {
        Task {
            let ok = await CalendarSync.requestAccess()
            denied = !ok
            guard ok else { return }
            store.setSettings { $0.calendarioSync = true }
            syncNow()
        }
    }

    private func syncNow() {
        if let n = CalendarSync.sync(data: store.data) {
            message = "Listo: \(n) eventos en el calendario Turniq."
        } else {
            message = "No se pudo sincronizar. Revisa el permiso de Calendarios."
            denied = CalendarSync.denied
        }
    }
}
