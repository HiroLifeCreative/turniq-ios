import SwiftUI
import UIKit
import TurniqShared

/// Menú "Más" (hoja modal): tarjeta de perfil arriba y las opciones
/// agrupadas en tarjetas, cada una con su ícono de color y una línea
/// que explica para qué sirve.
struct MasView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private enum Dest: Hashable {
        case profile, paychecks, annual, settings, calendar, shortcuts, terms, changelog
    }

    private struct Item: Identifiable {
        var dest: Dest
        var icon: String
        var tint: String
        var title: String
        var subtitle: String
        var id: String { title }
    }

    private var groups: [(title: String, items: [Item])] {
        [
            (L("Dinero"), [
                Item(dest: .paychecks, icon: "banknote.fill", tint: "#30A46C",
                     title: L("Comparar cheques"), subtitle: L("Lo que te pagaron frente a lo calculado")),
                Item(dest: .annual, icon: "doc.text.fill", tint: "#0064E0",
                     title: L("Resumen anual"), subtitle: L("Totales del año y PDF")),
            ]),
            (L("Herramientas"), [
                Item(dest: .calendar, icon: "calendar", tint: "#E5484D",
                     title: L("Calendario del iPhone"), subtitle: L("Turnos y cobros en tu calendario")),
                Item(dest: .shortcuts, icon: "bolt.fill", tint: "#E8830C",
                     title: L("Atajos, Siri y Widgets"), subtitle: L("Marcar sin abrir la app")),
            ]),
            ("Turniq", [
                Item(dest: .settings, icon: "gearshape.fill", tint: "#646B7A",
                     title: L("Ajustes"), subtitle: L("Avisos, seguridad y respaldo")),
                Item(dest: .terms, icon: "building.columns.fill", tint: "#7C3AED",
                     title: L("Términos y privacidad"), subtitle: L("Cómo se usan tus datos")),
                Item(dest: .changelog, icon: "sparkles", tint: "#D97706",
                     title: L("Novedades"), subtitle: L("Lo nuevo de esta versión")),
            ]),
        ]
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.4.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NavigationLink(value: Dest.profile) { profileCard }
                        .buttonStyle(PressStyle())

                    ForEach(groups, id: \.title) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            MonoLabel(text: g.title).padding(.leading, 4)
                            Card(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(Array(g.items.enumerated()), id: \.element.id) { idx, it in
                                        NavigationLink(value: it.dest) { row(it) }
                                            .buttonStyle(.plain)
                                        if idx < g.items.count - 1 {
                                            Rectangle().fill(T.line).frame(height: 0.5)
                                                .padding(.leading, 66)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            Text(verbatim: "Turniq").foregroundStyle(T.text)
                            Text(verbatim: ".").foregroundStyle(T.button)
                        }
                        .font(.turniq(20, .bold))
                        Text("Turniq iOS \(version)")
                        Link(destination: URL(string: "https://www.instagram.com/SoyNelsonHerrera")!) {
                            Image(systemName: "camera")
                                .font(.system(size: 16))
                                .padding(8)
                        }
                        .accessibilityLabel("Instagram")
                        Text(L("Desarrollado por Nelson Herrera"))
                        Text(L("© 2026 HiroLifeStudio · Todos los derechos reservados"))
                    }
                    .font(.turniq(12))
                    .foregroundStyle(T.text3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                }
                .padding(16)
            }
            .background(T.surface)
            .navigationTitle(L("Más"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Listo")) { dismiss() }
                }
            }
            .navigationDestination(for: Dest.self) { d in
                switch d {
                case .profile: ProfileView()
                case .paychecks: PaychecksView()
                case .annual: AnnualSummaryView()
                case .terms: TermsView()
                case .settings: SettingsView()
                case .calendar: CalendarSyncView()
                case .shortcuts: ShortcutsHelpView()
                case .changelog: ChangelogView()
                }
            }
        }
        .font(.turniq(15))
    }

    /// Tarjeta oscura con el perfil y un resumen de la cuenta.
    private var profileCard: some View {
        let s = store.settings
        let country = Countries.country(s.pais)
        let year = String(Calc.todayYmd().prefix(4))
        let worked = Calc.onlyWorked(store.shifts.filter { $0.fecha.hasPrefix(year) && !$0.esLibre })
        let net = Calc.rangeTotals(shifts: worked, jobsById: store.jobsById,
                                   umbralExtraHrs: s.umbralExtraHrs, multExtra: s.multExtra).net
        return DarkCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Avatar(name: s.nombreUsuario, size: 58)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.nombreUsuario.isEmpty ? L("Tu perfil") : s.nombreUsuario)
                            .font(.turniq(20, .bold)).foregroundStyle(.white).lineLimit(1)
                        Text(verbatim: "\(country.flag) \(country.name) · \(s.moneda)")
                            .font(.turniq(13)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(L("Editar"))
                        .font(.turniq(13, .bold)).foregroundStyle(T.buttonText)
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(T.button, in: Capsule())
                }
                HStack(spacing: 8) {
                    stat("\(store.jobs.count)", L("Trabajos"))
                    stat("\(worked.count)", L("Turnos \(year)"))
                    stat(T.cash(net, hidden: s.dineroOculto), L("Neto \(year)"))
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.turniq(15, .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.turniq(10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 6)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ it: Item) -> some View {
        HStack(spacing: 14) {
            Image(systemName: it.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(T.hex(it.tint))
                .frame(width: 38, height: 38)
                .background(T.hex(it.tint).opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(it.title).font(.turniq(16, .medium)).foregroundStyle(T.text)
                Text(it.subtitle).font(.turniq(12)).foregroundStyle(T.text3).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(T.text3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// Novedades de la versión de iOS.
struct ChangelogView: View {
    private let entries: [(version: String, fecha: String, notas: [String])] = [
        ("1.4.0", "2026-11-14", [
            L("Perfil con país y moneda: al elegir el país se ajustan la moneda y los valores sugeridos de hora extra."),
            L("Pantalla Más rediseñada, con tarjeta de perfil y opciones agrupadas."),
            L("Bienvenida por pasos de configuración: idioma, país, perfil y primer trabajo."),
        ]),
        ("1.3.1", "2026-11-14", [
            L("Calendario: la sincronización ya funciona con cuentas que no permiten crear calendarios y muestra el motivo si falla."),
        ]),
        ("1.3.0", "2026-11-14", [
            L("Comparar cheques: anota lo que te pagaron cada día de cobro y la app lo compara con lo calculado."),
            L("Tarifas especiales: sueldo propio por estación, extra nocturno y pago doble o tiempo y medio por turno."),
            L("Aviso de hora extra cuando un trabajo se acerca al límite semanal."),
            L("Resumen anual por trabajo, con exportación a PDF."),
            L("Propinas: se preguntan al marcar salida y Ganancias muestra qué días dejan más."),
            L("Compartir semana: una imagen del horario para enviar."),
            L("Bienvenida de la primera vez, con términos y condiciones y política de privacidad."),
        ]),
        ("1.2.3", "2026-11-14", [
            L("Exportar respaldo abre la hoja de Compartir con el archivo listo para guardar o enviar."),
            L("Un respaldo .json se puede importar con Abrir en Turniq desde Archivos u otras apps."),
        ]),
        ("1.2.2", "2026-11-14", [
            L("Detalle del turno: al mantener pulsado un turno en Semana se abre una hoja con horario, horas, dinero estimado, PIN del reloj y día de cobro."),
            L("La barra de navegación se lee bien al pasar sobre fondos oscuros."),
        ]),
        ("1.2.1", "2026-11-14", [
            L("Idioma: inglés o español, en Ajustes → Apariencia."),
            L("Corrección: los widgets ahora encuentran los datos de la app sin importar cómo se firmó."),
        ]),
        ("1.2.0", "2026-11-13", [
            L("Widgets para la pantalla de inicio y la pantalla de bloqueo: próximo turno con su PIN, neto de la semana y próximo cobro."),
            L("Actividad en Vivo: contador del turno en curso en la pantalla de bloqueo y en la Dynamic Island."),
            L("Enlaces para Atajos, Siri y el Botón de Acción: marcar entrada y salida sin buscar la app."),
            L("Aviso al llegar al trabajo, con botón para marcar la entrada."),
            L("Respaldo automático diario en la app Archivos."),
        ]),
        ("1.1.0", "2026-11-13", [
            L("Ícono de la app en la pantalla de inicio del iPhone."),
            L("Cobro por trabajo: cada empleo se configura para pagar cada semana o cada 2 semanas, con su día de cobro y su espera (la semana siguiente o 2 semanas después de trabajar)."),
            L("Tarjeta Próximos cobros en Inicio y Ganancias: fecha de cada cobro, periodo que paga y monto neto."),
            L("Aviso la mañana del día de cobro."),
            L("Sincronización con el Calendario del iPhone: turnos y días de cobro en un calendario propio llamado Turniq."),
            L("Diseño igualado con Android: encabezado por pantalla, héroe con control de privacidad y reloj en vivo, tarjetas de turno con estado por color, Ganancias por semana, mes y año."),
            L("Las horas reales marcadas mandan en el cálculo del dinero y se pueden corregir al editar el turno."),
            L("Cierre automático de turnos abiertos a la hora tope configurada."),
            L("Los respaldos de Android se importan sin errores aunque les falten campos."),
        ]),
        ("1.0.0", "2026-10-22", [
            L("Primera versión nativa para iPhone: Inicio, Semana, Trabajos, Ganancias y Ajustes."),
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
        .navigationTitle(L("Novedades"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Cómo usar los enlaces turniq:// con Atajos, Siri y el Botón de
/// Acción, y cómo añadir los widgets.
struct ShortcutsHelpView: View {
    private let links: [(url: String, what: String)] = [
        ("turniq://marcar", L("Marca entrada si no estás trabajando, o salida si ya tienes un turno en curso.")),
        ("turniq://entrada", L("Marca la entrada del turno de hoy más cercano a la hora actual.")),
        ("turniq://salida", L("Marca la salida del turno en curso.")),
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
                Text(L("Enlaces de Turniq"))
            } footer: {
                Text(L("Mantén pulsado un enlace para copiarlo."))
            }

            Section(L("Crear el atajo (una sola vez)")) {
                step(1, L("Abre la app Atajos y toca + para crear uno nuevo."))
                step(2, L("Añade la acción «Abrir URL» y pega turniq://marcar."))
                step(3, L("Ponle un nombre fácil de decir, por ejemplo «Marcar turno»."))
            }

            Section(L("Usarlo")) {
                step(1, L("Siri: di «Oye Siri, Marcar turno»."))
                step(2, L("Botón de Acción: Ajustes → Botón de Acción → Atajo → elige tu atajo."))
                step(3, L("Pantalla de inicio: en el atajo, Compartir → Añadir a pantalla de inicio."))
            }

            Section {
                step(1, L("Mantén pulsada la pantalla de inicio y toca Editar → Añadir widget."))
                step(2, L("Busca Turniq y elige el tamaño pequeño o mediano."))
                step(3, L("Para la pantalla de bloqueo: mantenla pulsada → Personalizar → Añadir widgets → Turniq."))
                widgetStatus
            } header: {
                Text("Widgets")
            } footer: {
                Text(L("Los widgets muestran tu próximo turno con su PIN, el neto de la semana y tu próximo cobro. Se actualizan cada vez que abres Turniq o cambias un turno. La Actividad en Vivo aparece sola al marcar entrada."))
            }
        }
        .navigationTitle(L("Atajos, Siri y Widgets"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// ¿La app y el widget comparten carpeta en esta instalación?
    @ViewBuilder
    private var widgetStatus: some View {
        let ok = AppGroup.containerURL != nil
        VStack(alignment: .leading, spacing: 4) {
            Label(L("Estado del widget"), systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(ok ? T.success : T.amber)
            Text(ok
                 ? L("Conectado: el widget puede leer tus datos.")
                 : L("Sin conexión: esta instalación se firmó sin el grupo de apps, así que el widget no puede leer tus datos. Vuelve a instalar con xtool para que el grupo quede incluido."))
                .font(.footnote).foregroundStyle(.secondary)
            Text(verbatim: AppGroup.diagnostics)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
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
                Toggle(L("Sincronizar con Calendario"), isOn: Binding(
                    get: { store.settings.calendarioSync },
                    set: { on in
                        if on { enable() } else { store.setSettings { $0.calendarioSync = false } }
                    }
                ))
            } footer: {
                Text(L("Turniq crea un calendario propio llamado «Turniq» y copia ahí tus turnos (con el PIN del reloj en las notas) y tus días de cobro. No toca tus otros calendarios. Se actualiza solo cada vez que cambias un turno, de 7 días atrás a 60 días adelante."))
            }

            if denied {
                Section {
                    Button(L("Abrir Ajustes del iPhone")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } footer: {
                    Text(L("Turniq no tiene permiso para usar el Calendario. Actívalo en Ajustes → Turniq → Calendarios → Acceso total."))
                }
            }

            if store.settings.calendarioSync {
                Section {
                    Button(L("Sincronizar ahora")) { syncNow() }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(L("Quitar el calendario Turniq"), role: .destructive) { confirmRemove = true }
            } footer: {
                Text(L("Borra el calendario «Turniq» y sus eventos de la app Calendario. Tus turnos dentro de Turniq no se tocan."))
            }
        }
        .navigationTitle(L("Calendario del iPhone"))
        .onAppear { denied = CalendarSync.denied }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("¿Quitar el calendario «Turniq» del iPhone?"), isPresented: $confirmRemove, titleVisibility: .visible) {
            Button(L("Quitar"), role: .destructive) {
                store.setSettings { $0.calendarioSync = false }
                CalendarSync.removeCalendar()
                message = nil
            }
            Button(L("Cancelar"), role: .cancel) {}
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
            var msg = L("Listo: \(n) eventos en el calendario Turniq.")
            if let name = CalendarSync.fallbackCalendarName {
                msg = L("Listo: \(n) eventos. Tu cuenta no deja crear calendarios, así que quedaron en tu calendario «\(name)».")
            }
            message = msg
        } else {
            var msg = L("No se pudo sincronizar. Revisa el permiso de Calendarios.")
            if let detail = CalendarSync.lastError { msg += "\n(" + detail + ")" }
            message = msg
            denied = CalendarSync.denied
        }
    }
}
