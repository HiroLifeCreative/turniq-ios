import SwiftUI

/// Círculo con las iniciales del usuario.
struct Avatar: View {
    var name: String
    var size: CGFloat = 56

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return s.isEmpty ? "T" : s
    }

    var body: some View {
        Text(initials)
            .font(.turniq(size * 0.38, .bold))
            .foregroundStyle(T.buttonText)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [T.button, T.primary], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle())
    }
}

/// Lista de países con buscador. Al elegir uno se aplican su moneda y
/// sus valores sugeridos.
struct CountryPicker: View {
    @Environment(\.dismiss) private var dismiss
    var selected: String
    var onPick: (Country) -> Void
    @State private var query = ""

    private var results: [Country] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Countries.all }
        return Countries.all.filter {
            $0.es.lowercased().contains(q) || $0.en.lowercased().contains(q)
                || $0.currency.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { c in
                Button {
                    onPick(c)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(verbatim: c.flag).font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: c.name).font(.turniq(16, .medium)).foregroundStyle(T.text)
                            Text(verbatim: "\(Countries.currency(c.currency).name) · \(c.currency)")
                                .font(.turniq(12)).foregroundStyle(T.text3)
                        }
                        Spacer()
                        if c.code == selected {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(T.button)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: Text(L("Buscar país o moneda")))
            .navigationTitle(L("País"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancelar")) { dismiss() }
                }
            }
        }
    }
}

/// Resumen de lo que el país propone, para mostrar bajo el selector.
func countrySuggestion(_ c: Country) -> String {
    let cur = Countries.currency(c.currency)
    var s = L("Moneda: \(cur.name) (\(cur.symbol)).")
    if let h = c.otHours, let m = c.otMult {
        s += " " + L("Hora extra sugerida: después de \(ShiftFormView.num(h)) h por semana, a ×\(ShiftFormView.num(m)).")
    } else {
        s += " " + L("Sin sugerencia de hora extra para este país: ajústala a tu contrato.")
    }
    return s
}

/// Perfil: nombre, país, moneda e impuestos por defecto.
struct ProfileView: View {
    @EnvironmentObject var store: Store
    @State private var pickingCountry = false

    private var country: Country { Countries.country(store.settings.pais) }

    private func bind<V>(_ kp: WritableKeyPath<Settings, V>) -> Binding<V> {
        Binding(
            get: { store.settings[keyPath: kp] },
            set: { v in store.setSettings { $0[keyPath: kp] = v } }
        )
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Avatar(name: store.settings.nombreUsuario, size: 60)
                    TextField(L("Tu nombre"), text: bind(\.nombreUsuario))
                        .font(.turniq(18, .medium))
                        .textInputAutocapitalization(.words)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button { pickingCountry = true } label: {
                    HStack(spacing: 12) {
                        Text(verbatim: country.flag).font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("País")).font(.caption).foregroundStyle(.secondary)
                            Text(verbatim: country.name).font(.turniq(16, .medium)).foregroundStyle(T.text)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(T.text3)
                    }
                }
                Picker(L("Moneda"), selection: bind(\.moneda)) {
                    ForEach(Countries.currencies) { c in
                        Text(verbatim: "\(c.code) · \(c.symbol) · \(c.name)").tag(c.code)
                    }
                }
                LabeledContent(L("Ejemplo")) {
                    Text(verbatim: Calc.money(1234.5)).foregroundStyle(.secondary)
                }
            } header: {
                Text(L("País y moneda"))
            } footer: {
                Text(L("Cambiar la moneda solo cambia el símbolo y el formato: no convierte los montos que ya escribiste."))
            }

            Section {
                LabeledContent(L("Impuestos por defecto (%)")) {
                    TextField("0", value: bind(\.taxDefault), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
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
            } header: {
                Text(L("Impuestos y hora extra"))
            } footer: {
                Text(L("El porcentaje de impuestos se propone al crear un trabajo nuevo; cada trabajo puede tener el suyo. Los valores de hora extra del país son sugerencias generales: la ley y tu contrato pueden ser distintos, revísalos.") + "\n" + countrySuggestion(country))
            }

            Section(L("Preferencias")) {
                Picker(L("Idioma / Language"), selection: bind(\.idioma)) {
                    Text(verbatim: "Español").tag("es")
                    Text(verbatim: "English").tag("en")
                }
                Picker(L("Formato de hora"), selection: bind(\.formatoHora)) {
                    Text("12 h").tag("12h")
                    Text("24 h").tag("24h")
                }
            }
        }
        .navigationTitle(L("Perfil"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $pickingCountry) {
            CountryPicker(selected: store.settings.pais) { c in
                store.setCountry(c.code)
            }
        }
    }
}
