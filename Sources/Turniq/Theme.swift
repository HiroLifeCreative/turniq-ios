import SwiftUI

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
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
    }
}
