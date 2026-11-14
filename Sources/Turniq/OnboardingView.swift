import SwiftUI

/// Términos y condiciones + Política de privacidad, en secciones
/// plegables. Se abre desde Más y desde la bienvenida.
struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(Legal.updated)
                    .font(.turniq(12)).foregroundStyle(T.text3)
                group(L("Términos y condiciones"), Legal.terms)
                group(L("Política de privacidad"), Legal.privacy)
            }
            .padding(16)
        }
        .background(T.bg)
        .navigationTitle(L("Términos y privacidad"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, _ sections: [LegalSection]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: title).padding(.top, 6)
            ForEach(sections) { s in
                Card(padding: 14) {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(s.body.enumerated()), id: \.offset) { _, p in
                                Text(p)
                                    .font(.turniq(14)).foregroundStyle(T.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    } label: {
                        Text(s.title)
                            .font(.turniq(15, .bold)).foregroundStyle(T.text)
                            .multilineTextAlignment(.leading)
                    }
                    .tint(T.primary)
                }
            }
        }
    }
}

/// Configuración inicial en pasos: bienvenida y términos, país y
/// moneda, perfil, primer trabajo y resumen. Cada paso guarda lo suyo
/// al avanzar, así que se puede retomar donde quedó.
struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var step = 0
    @State private var accepted = false
    @State private var showTerms = false
    @State private var pickingCountry = false
    @State private var name = ""
    @State private var taxDefault = ""
    @State private var jobName = ""
    @State private var wage = "15"
    @State private var tax = "0"
    @State private var color = Job.palette[0]
    @State private var freq: PayFreq = .semanal

    private var steps: [(icon: String, label: String)] {
        [
            ("hand.wave.fill", L("Inicio")),
            ("globe.americas.fill", L("País")),
            ("person.fill", L("Perfil")),
            ("briefcase.fill", L("Trabajo")),
            ("checkmark", L("Listo")),
        ]
    }
    private var lastStep: Int { 4 }
    private var country: Country { Countries.country(store.settings.pais) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case 0: welcome
                    case 1: countryStep
                    case 2: profileStep
                    case 3: jobStep
                    default: doneStep
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                PrimaryButton(title: primaryTitle) { next() }
                    .disabled(step == 0 && !accepted)
                    .opacity(step == 0 && !accepted ? 0.45 : 1)
                if step == 2 || step == 3 {
                    Button { advance() } label: {
                        Text(L("Omitir"))
                            .font(.turniq(15, .bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity).frame(height: 40)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.hex("#14161A").ignoresSafeArea())
        .font(.turniq(15))
        .sheet(isPresented: $showTerms) {
            NavigationStack {
                TermsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L("Listo")) { showTerms = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $pickingCountry) {
            CountryPicker(selected: store.settings.pais) { c in
                store.setCountry(c.code)
            }
        }
        .onAppear {
            name = store.settings.nombreUsuario
            accepted = store.settings.terminosAceptados
            taxDefault = store.settings.taxDefault > 0 ? ShiftFormView.num(store.settings.taxDefault) : ""
        }
    }

    // MARK: Encabezado con los pasos

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { step = max(0, step - 1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(PressStyle())
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("CONFIGURACIÓN")).font(.turniqMono).tracking(0.6)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(L("Paso \(step + 1) de \(lastStep + 1)"))
                        .font(.turniq(15, .bold)).foregroundStyle(.white)
                }
                Spacer()
            }

            // Círculos numerados unidos por una línea
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, st in
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(i < step ? T.money : (i == step ? T.button : Color.white.opacity(0.10)))
                                .frame(width: 34, height: 34)
                            if i < step {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            } else {
                                Image(systemName: st.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(i == step ? T.buttonText : .white.opacity(0.45))
                            }
                        }
                        Text(st.label)
                            .font(.turniq(10, i == step ? .bold : .regular))
                            .foregroundStyle(i <= step ? .white : .white.opacity(0.45))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(width: 52)
                    if i < steps.count - 1 {
                        Rectangle()
                            .fill(i < step ? T.money : Color.white.opacity(0.14))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 18)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var primaryTitle: String {
        switch step {
        case 0: return L("Empezar")
        case lastStep: return L("Terminar")
        default: return L("Siguiente")
        }
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t).font(.turniq(28, .bold)).tracking(-0.5).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(sub).font(.turniq(16)).foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.turniqMono).foregroundStyle(.white.opacity(0.55))
            TextField("", text: text)
                .keyboardType(keyboard)
                .font(.turniq(17, .medium))
                .foregroundStyle(.white)
                .tint(T.button)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
    }

    /// Panel translúcido para agrupar opciones de un paso.
    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(.turniq(14, .bold))
                .foregroundStyle(active ? T.buttonText : .white.opacity(0.8))
                .padding(.horizontal, 16).frame(height: 38)
                .background(active ? T.button : Color.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(PressStyle())
    }

    // MARK: Pasos

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 0) {
                Text(verbatim: "Turniq").foregroundStyle(.white)
                Text(verbatim: ".").foregroundStyle(T.button)
            }
            .font(.turniq(40, .bold))

            title(L("Bienvenido a Turniq"),
                  L("Tu asistente para registrar turnos, horas y ganancias. Vamos a configurarlo en menos de un minuto."))

            panel {
                Text(L("IDIOMA")).font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 8) {
                    chip("Español", active: store.settings.idioma == "es") {
                        store.setSettings { $0.idioma = "es" }
                    }
                    chip("English", active: store.settings.idioma == "en") {
                        store.setSettings { $0.idioma = "en" }
                    }
                }
            }

            panel {
                Label(L("Tus datos se guardan solo en este dispositivo. Sin cuentas, sin nube."), systemImage: "lock.shield")
                    .font(.turniq(14)).foregroundStyle(.white.opacity(0.7))

                Button { accepted.toggle() } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: accepted ? "checkmark.square.fill" : "square")
                            .font(.system(size: 24))
                            .foregroundStyle(accepted ? T.button : .white.opacity(0.6))
                        Text(L("Acepto los términos y condiciones y la política de privacidad."))
                            .font(.turniq(15, .medium)).foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)

                Button { showTerms = true } label: {
                    Text(L("Leer los términos y la política de privacidad"))
                        .font(.turniq(14, .bold)).foregroundStyle(T.button)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var countryStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title(L("¿Dónde trabajas?"),
                  L("Con tu país Turniq pone la moneda correcta y propone los valores de hora extra habituales."))

            Button { if !store.accountLocked { pickingCountry = true } } label: {
                HStack(spacing: 14) {
                    Text(verbatim: country.flag).font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("PAÍS")).font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                        Text(verbatim: country.name).font(.turniq(20, .bold)).foregroundStyle(.white)
                    }
                    Spacer()
                    if store.accountLocked {
                        Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text(L("Cambiar"))
                            .font(.turniq(13, .bold)).foregroundStyle(T.buttonText)
                            .padding(.horizontal, 14).frame(height: 32)
                            .background(T.button, in: Capsule())
                    }
                }
                .padding(16)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(PressStyle())

            panel {
                setupRow("banknote.fill", L("Moneda"),
                         "\(Countries.currency(store.settings.moneda).name) · \(Calc.money(1234.5))")
                setupRow("bolt.fill", L("Hora extra"),
                         L("Después de \(ShiftFormView.num(store.settings.umbralExtraHrs)) h por semana, a ×\(ShiftFormView.num(store.settings.multExtra))"))
                setupRow("clock.fill", L("Formato de hora"),
                         store.settings.formatoHora == "12h" ? "12 h (a.m. / p.m.)" : "24 h")
                HStack(spacing: 8) {
                    chip("12 h", active: store.settings.formatoHora == "12h") {
                        store.setSettings { $0.formatoHora = "12h" }
                    }
                    chip("24 h", active: store.settings.formatoHora == "24h") {
                        store.setSettings { $0.formatoHora = "24h" }
                    }
                }
            }

            Text(store.accountLocked
                 ? L("Esta cuenta ya tiene trabajos o turnos, así que su país y su moneda quedan fijos. Para trabajar en otro país crea otra cuenta en Más → Cuentas: cada una guarda sus propios datos.")
                 : L("Son sugerencias generales del país: la ley y tu contrato pueden ser distintos. Si después trabajas en otro país, crea otra cuenta en Más → Cuentas."))
                .font(.turniq(13)).foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(T.button)
                .frame(width: 32, height: 32)
                .background(T.button.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased()).font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                Text(value).font(.turniq(15, .medium)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title(L("Tu perfil"), L("Así te saludará la app cada vez que la abras."))
            HStack(spacing: 14) {
                Avatar(name: name, size: 60)
                field(L("Tu nombre"), text: $name)
                    .textInputAutocapitalization(.words)
            }
            field(L("Impuestos por defecto (%)"), text: $taxDefault, keyboard: .decimalPad)
            Text(L("Es el porcentaje que te descuentan del sueldo. Se propone en cada trabajo nuevo y lo puedes cambiar en cada uno."))
                .font(.turniq(13)).foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var jobStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title(L("Registra tu trabajo"),
                  L("¿Dónde trabajas? Agrega tu sueldo por hora y el % de taxes."))
            field(L("Nombre del trabajo"), text: $jobName)
            HStack(spacing: 12) {
                field(L("Sueldo por hora (\(Money.symbol))"), text: $wage, keyboard: .decimalPad)
                field("Taxes (%)", text: $tax, keyboard: .decimalPad)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L("ME PAGAN")).font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 8) {
                    ForEach(PayFreq.allCases) { f in
                        chip(f.label, active: freq == f) { freq = f }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "COLOR").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 10) {
                    ForEach(Job.palette, id: \.self) { c in
                        Circle()
                            .fill(T.hex(c))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(.white, lineWidth: color == c ? 3 : 0))
                            .onTapGesture { color = c }
                    }
                }
            }
            Text(L("Después puedes añadir más trabajos, estaciones, el día de cobro y el PIN del reloj en la pestaña Trabajos."))
                .font(.turniq(13)).foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(T.money)
            title(L("¡Todo listo!"),
                  L("Ya puedes empezar a registrar tus turnos. Ve a Semana y toca + en el día que trabajes."))
            panel {
                setupRow("globe.americas.fill", L("País"), "\(country.flag) \(country.name) · \(store.settings.moneda)")
                setupRow("person.fill", L("Perfil"),
                         store.settings.nombreUsuario.isEmpty ? "—" : store.settings.nombreUsuario)
                setupRow("briefcase.fill", L("Trabajos"),
                         store.jobs.isEmpty ? L("Ninguno todavía") : store.jobs.map { $0.nombre }.joined(separator: ", "))
            }
            VStack(alignment: .leading, spacing: 12) {
                tip("calendar", L("Semana: programa tus turnos y duplica la semana."))
                tip("clock", L("Inicio: marca entrada y salida; el dinero se calcula solo."))
                tip("wallet.pass", L("Cobros: mira cuándo te paga cada trabajo y compáralo con tu cheque."))
            }
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(T.button)
                .frame(width: 36, height: 36)
                .background(T.button.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(text).font(.turniq(15)).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Flujo

    /// Botón principal: guarda lo del paso y avanza.
    private func next() {
        switch step {
        case 0:
            store.setSettings { $0.terminosAceptados = true }
        case 1:
            // El país ya se guardó al elegirlo; el % del perfil se
            // propone también en el primer trabajo.
            break
        case 2:
            let n = name.trimmingCharacters(in: .whitespaces)
            let t = min(100, ShiftFormView.parse(taxDefault))
            store.setSettings { $0.nombreUsuario = n; $0.taxDefault = t }
            if t > 0 { tax = ShiftFormView.num(t) }
        case 3:
            let n = jobName.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty {
                store.upsertJob(Job(
                    id: UUID().uuidString, nombre: n, color: color,
                    sueldoHora: ShiftFormView.parse(wage),
                    taxPct: min(100, ShiftFormView.parse(tax)),
                    estaciones: [], pinMarcaje: nil,
                    pagoFrecuencia: freq.rawValue))
            }
        default:
            store.setSettings { $0.onboardingDone = true }
            return
        }
        advance()
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            var n = step + 1
            // Quien ya tiene trabajos no necesita el paso de crear uno.
            if n == 3 && !store.jobs.isEmpty { n = 4 }
            step = min(lastStep, n)
        }
    }
}
