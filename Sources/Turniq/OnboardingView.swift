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

/// Bienvenida de la primera vez: idioma, aceptar términos, nombre y
/// primer trabajo. Igual que en Android, en menos pasos.
struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var step = 0
    @State private var accepted = false
    @State private var showTerms = false
    @State private var name = ""
    @State private var jobName = ""
    @State private var wage = "15"
    @State private var tax = "0"
    @State private var color = Job.palette[0]

    private var lastStep: Int { 3 }

    var body: some View {
        VStack(spacing: 0) {
            // Progreso
            HStack(spacing: 6) {
                ForEach(0...lastStep, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? T.button : Color.white.opacity(0.18))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case 0: welcome
                    case 1: nameStep
                    case 2: jobStep
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
                if step == 1 || step == 2 {
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
        .onAppear {
            name = store.settings.nombreUsuario
            accepted = store.settings.terminosAceptados
        }
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

    // MARK: Pasos

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 0) {
                Text("Turniq").foregroundStyle(.white)
                Text(".").foregroundStyle(T.button)
            }
            .font(.turniq(44, .bold))
            .padding(.top, 24)

            title(L("Bienvenido a Turniq"),
                  L("Tu asistente para registrar turnos, horas y ganancias. Vamos a configurarlo en menos de un minuto."))

            // Idioma
            HStack(spacing: 8) {
                langChip("Español", "es")
                langChip("English", "en")
            }

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

    private func langChip(_ label: String, _ code: String) -> some View {
        let active = store.settings.idioma == code
        return Button {
            store.setSettings { $0.idioma = code }
        } label: {
            Text(verbatim: label)
                .font(.turniq(14, .bold))
                .foregroundStyle(active ? T.buttonText : .white.opacity(0.8))
                .padding(.horizontal, 16).frame(height: 38)
                .background(active ? T.button : Color.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(PressStyle())
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title(L("¿Cómo te llamas?"), L("Así te saludará la app cada vez que la abras."))
            field(L("Tu nombre"), text: $name)
                .textInputAutocapitalization(.words)
        }
    }

    private var jobStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title(L("Registra tu trabajo"),
                  L("¿Dónde trabajas? Agrega tu sueldo por hora y el % de taxes."))
            field(L("Nombre del trabajo"), text: $jobName)
            HStack(spacing: 12) {
                field(L("Sueldo por hora ($)"), text: $wage, keyboard: .decimalPad)
                field("Taxes (%)", text: $tax, keyboard: .decimalPad)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("COLOR").font(.turniqMono).foregroundStyle(.white.opacity(0.55))
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
                .font(.system(size: 64))
                .foregroundStyle(T.money)
                .padding(.top, 24)
            title(L("¡Todo listo!"),
                  L("Ya puedes empezar a registrar tus turnos. Ve a Semana y toca + en el día que trabajes."))
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
            let n = name.trimmingCharacters(in: .whitespaces)
            store.setSettings { $0.nombreUsuario = n }
        case 2:
            let n = jobName.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty {
                store.upsertJob(Job(
                    id: UUID().uuidString, nombre: n, color: color,
                    sueldoHora: ShiftFormView.parse(wage),
                    taxPct: min(100, ShiftFormView.parse(tax)),
                    estaciones: [], pinMarcaje: nil))
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
            if n == 2 && !store.jobs.isEmpty { n = 3 }
            step = min(lastStep, n)
        }
    }
}
