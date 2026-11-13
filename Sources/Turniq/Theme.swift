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
            return .custom("Roboto-Bold", fixedSize: size)
        case .medium:
            return .custom("Roboto-Medium", fixedSize: size)
        default:
            return .custom("Roboto-Regular", fixedSize: size)
        }
    }

    /// Etiquetas pequeñas (11 pt). En Android las etiquetas "mono"
    /// son Roboto, así que aquí también.
    static var turniqMono: Font { .turniq(11) }
}

/// Identidad visual de Turniq — los MISMOS tokens que Android
/// (src/theme/tokens.ts): todo redondeado, botones principales
/// AZULES sólidos #0392FF, tarjetas oscuras para los datos clave,
/// dinero en verde. Los colores de superficie y texto cambian solos
/// entre modo claro y oscuro.
enum T {
    // Marca
    static let primary = hex("#0064E0")
    static let button = hex("#0392FF")
    static let buttonText = hex("#C4E9FF")
    static let money = hex("#32C46D")
    static let amber = hex("#F5A623")
    static let orange = hex("#E8830C")
    static let sky = hex("#5EA9FF")
    static let heroTop = hex("#1E2128")
    static let heroBottom = hex("#16181D")

    // Paleta clara / oscura
    static let bg = dyn("#FFFFFF", "#0B0B0C")
    static let surface = dyn("#F5F6F8", "#141416")
    static let card = dyn("#FFFFFF", "#17171A")
    static let cardTop = dyn("#FFFFFF", "#1E1E22")
    static let cardBottom = dyn("#F8F9FB", "#17171A")
    static let cardBorder = dyn("#EDEFF2", "#2E2E33")
    static let text = dyn("#0C0E13", "#F4F4F5")
    static let text2 = dyn("#4A5160", "#A6A6B0")
    static let text3 = dyn("#646B7A", "#8A8A95")
    static let danger = dyn("#D13438", "#F04438")
    static let success = dyn("#0E7C3E", "#32C46D")
    static let band = dyn("#14161A", "#17171A")
    static let line = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(red: 12 / 255, green: 14 / 255, blue: 19 / 255, alpha: 0.09)
    })
    static let shadow = Color(red: 0.42, green: 0.48, blue: 0.60)   // #6B7A99

    static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0x0064E0
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    static func hex(_ hex: String) -> Color {
        let c = rgb(hex)
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    private static func ui(_ hex: String) -> UIColor {
        let c = rgb(hex)
        return UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    /// Color que cambia según el modo claro / oscuro.
    static func dyn(_ light: String, _ dark: String) -> Color {
        let l = ui(light), d = ui(dark)
        return Color(UIColor { tc in tc.userInterfaceStyle == .dark ? d : l })
    }

    /// Mezcla `hex` hacia `target` (amt 0…1).
    static func mix(_ hex: String, _ target: String, _ amt: Double) -> Color {
        let a = rgb(hex), b = rgb(target)
        return Color(red: a.r + (b.r - a.r) * amt,
                     green: a.g + (b.g - a.g) * amt,
                     blue: a.b + (b.b - a.b) * amt)
    }

    /// Dinero, o puntos si el ojito lo tiene oculto.
    static func cash(_ n: Double, hidden: Bool) -> String {
        hidden ? "••••" : Calc.money(n)
    }
}

/// Botón principal: píldora azul #0392FF con texto #C4E9FF.
struct PrimaryButton: View {
    var title: String
    var color: Color = T.button
    var textColor: Color = T.buttonText
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.turniq(17, .bold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(color, in: Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

/// Botón secundario con borde fino (ghost).
struct GhostButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.turniq(15, .bold))
            }
            .foregroundStyle(T.text)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(T.card, in: Capsule())
            .overlay(Capsule().strokeBorder(T.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// Botón redondo de 44 pt (flechas de semana, etc.).
struct CircleButton: View {
    var icon: String
    var size: CGFloat = 44
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(T.primary)
                .frame(width: size, height: size)
                .background(T.surface, in: Circle())
                .overlay(Circle().strokeBorder(T.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// Respuesta al toque: se hunde un poco, como en Android.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tarjeta clara estándar: degradado muy suave, borde fino, radio 20
/// y sombra azulada (igual que `Card` de Android).
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [T.cardTop, T.cardBottom], startPoint: .top, endPoint: .bottom))
                    .shadow(color: T.shadow.opacity(0.20), radius: 12, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(T.cardBorder, lineWidth: 0.5)
            }
    }
}

/// Tarjeta oscura teñida con un color de acento (`TintedCard`).
struct TintedCard<Content: View>: View {
    var accent: String
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [T.mix(accent, "#101216", 0.8), T.hex("#14161A")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.09), lineWidth: 0.5)
            }
    }
}

/// Tarjeta oscura del héroe (radio 28).
struct DarkCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [T.heroTop, T.heroBottom],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: T.shadow.opacity(0.25), radius: 16, y: 8)
            }
    }
}

/// Etiqueta pequeña en mayúsculas.
struct MonoLabel: View {
    var text: String
    var color: Color = T.text3
    var body: some View {
        Text(text.uppercased())
            .font(.turniqMono)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

/// Título de sección (18 pt, negrita).
struct SectionTitle: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.turniq(18, .bold))
            .foregroundStyle(T.text)
    }
}

/// Etiqueta + valor sobre tarjeta oscura.
struct DarkStat: View {
    var label: String
    var value: String
    var color: Color = .white
    var alignment: HorizontalAlignment = .leading
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label.uppercased()).font(.turniqMono).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.turniq(17, .bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
