import SwiftUI
import LocalAuthentication

/// Bloqueo por PIN de la app (4 dígitos) + Face/Touch ID si el
/// usuario lo activó. El PIN vive en Ajustes; es distinto al PIN
/// de reloj de cada trabajo.
struct PinLockView: View {
    @EnvironmentObject var store: Store
    var onUnlock: () -> Void
    @State private var entered = ""
    @State private var error = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Turniq.")
                .font(.system(size: 38, weight: .bold))
            MonoLabel(text: "Escribe tu PIN")
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < entered.count ? T.button : Color.secondary.opacity(0.25))
                        .frame(width: 14, height: 14)
                }
            }
            if error {
                Text("PIN incorrecto").foregroundStyle(T.danger).font(.callout)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(76)), count: 3), spacing: 14) {
                ForEach(1..<10, id: \.self) { n in key("\(n)") }
                Spacer()
                key("0")
                Button { if !entered.isEmpty { entered.removeLast() } } label: {
                    Image(systemName: "delete.left").font(.title3)
                        .frame(width: 76, height: 64)
                }
            }
            if store.settings.biometrico {
                Button("Usar Face ID / Touch ID") { biometric() }
                    .foregroundStyle(T.primary)
            }
            Spacer()
        }
        .padding()
        .onAppear { if store.settings.biometrico { biometric() } }
    }

    private func key(_ d: String) -> some View {
        Button {
            guard entered.count < 4 else { return }
            entered += d
            if entered.count == 4 {
                if entered == store.settings.pin {
                    onUnlock()
                } else {
                    error = true
                    entered = ""
                }
            }
        } label: {
            Text(d).font(.title)
                .frame(width: 76, height: 64)
                .background(Color.secondary.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func biometric() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Desbloquear Turniq") { ok, _ in
            if ok { DispatchQueue.main.async { onUnlock() } }
        }
    }
}
