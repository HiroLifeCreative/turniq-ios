import SwiftUI
import CoreText

/// Registro de fuentes en tiempo de ejecución (Roboto + JetBrains
/// Mono vienen bundleadas en Resources/Fonts). Así la app usa la
/// misma tipografía que Android sin depender de claves de
/// Info.plist que xtool tendría que generar.
enum FontReg {
    static private(set) var roboto = false
    static private(set) var mono = false

    static func register() {
        roboto = load(["Roboto-Regular", "Roboto-Medium", "Roboto-Bold"])
        mono = load(["JetBrainsMono_400Regular"])
    }

    private static func load(_ names: [String]) -> Bool {
        var ok = false
        for name in names {
            let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Resources/Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf")
            guard let url else { continue }
            var err: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err) { ok = true }
        }
        return ok
    }
}

extension Font {
    /// Roboto (Regular/Medium/Bold) si el registro funcionó; si no,
    /// la fuente del sistema — nunca se cae la app por la fuente.
    static func turniq(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard FontReg.roboto else { return .system(size: size, weight: weight) }
        switch weight {
        case .bold, .heavy, .black, .semibold:
            return .custom("Roboto-Bold", size: size)
        case .medium:
            return .custom("Roboto-Medium", size: size)
        default:
            return .custom("Roboto", size: size)
        }
    }

    static var turniqMono: Font {
        FontReg.mono ? .custom("JetBrainsMono-Regular", size: 11) : .system(size: 11, weight: .medium, design: .monospaced)
    }
}

/// Identidad visual de Turniq (la misma línea de Android):
/// todo redondeado, botones principales AZULES sólidos #0392FF,
/// tarjetas oscuras para los datos clave, dinero en verde.
enum T {
    static let primary = Color(red: 0.0, green: 0.39, blue: 0.89)       // #0064E0
    static let button = Color(red: 0.012, green: 0.573, blue: 1.0)      // #0392FF
    static let buttonText = Color(red: 0.769, green: 0.914, blue: 1.0)  // #C4E9FF
    static let money = Color(red: 0.196, green: 0.769, blue: 0.427)     // #32C46D
    static let amber = Color(red: 0.961, green: 0.651, blue: 0.137)     // #F5A623
    static let danger = Color(red: 0.898, green: 0.282, blue: 0.302)    // #E5484D
    static let heroTop = Color(red: 0.118, green: 0.129, blue: 0.157)   // #1E2128
    static let heroBottom = Color(red: 0.086, green: 0.094, blue: 0.114)// #16181D
    static let band = Color(red: 0.078, green: 0.086, blue: 0.102)      // #14161A

    static func hex(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0x0064E0
        return Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}

/// Botón principal sólido estilo Turniq.
struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(T.buttonText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(T.button, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: T.button.opacity(0.38), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// Tarjeta oscura destacada (héroe / totales).
struct DarkCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [T.heroTop, T.heroBottom], startPoint: .top, endPoint: .bottom))
            }
    }
}

/// Etiqueta mono pequeña en mayúsculas.
struct MonoLabel: View {
    var text: String
    var color: Color = .secondary
    var body: some View {
        Text(text.uppercased())
            .font(.turniqMono)
            .foregroundStyle(color)
    }
}
