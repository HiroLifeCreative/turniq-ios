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
            HStack(spacing: 0) {
                Text("Turniq").foregroundStyle(.white)
                Text(".").foregroundStyle(T.button)
            }
            .font(.turniq(38, .bold))
            MonoLabel(text: L("Escribe tu PIN"), color: .white.opacity(0.55))
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < entered.count ? T.button : Color.white.opacity(0.22))
                        .frame(width: 14, height: 14)
                }
            }
            if error {
                Text(L("PIN incorrecto")).foregroundStyle(T.danger).font(.callout)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(76)), count: 3), spacing: 14) {
                ForEach(1..<10, id: \.self) { n in key("\(n)") }
                Spacer()
                key("0")
                Button { if !entered.isEmpty { entered.removeLast() } } label: {
                    Image(systemName: "delete.left").font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 64)
                }
            }
            if store.settings.biometrico {
                Button(L("Usar Face ID / Touch ID")) { biometric() }
                    .foregroundStyle(T.button)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.band.ignoresSafeArea())
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
            Text(d).font(.turniq(28, .medium))
                .foregroundStyle(.white)
                .frame(width: 76, height: 64)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func biometric() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: L("Desbloquear Turniq")) { ok, _ in
            if ok { DispatchQueue.main.async { onUnlock() } }
        }
    }
}
