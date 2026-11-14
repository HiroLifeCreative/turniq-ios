import SwiftUI

/// La cáscara visual de Turniq, igual que en Android:
/// banda superior OSCURA con el título de la pantalla y el engranaje
/// (que abre Más), el contenido sobre una HOJA redondeada (radio 28
/// arriba), y abajo el DOCK FLOTANTE de vidrio con íconos solos y la
/// pestaña activa como píldora azul sólida.
struct TurniqShell: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var showMas = false
    @State private var taps: [Int] = [0, 0, 0, 0]

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", L("Inicio")),
        ("calendar", L("Semana")),
        ("briefcase.fill", L("Trabajos")),
        ("chart.bar.fill", L("Ganancias")),
    ]

    private var title: String {
        if tab == 0 {
            let first = store.settings.nombreUsuario.split(separator: " ").first.map(String.init) ?? ""
            return first.isEmpty ? L("Hola") : L("Hola, \(first)")
        }
        return tabs[tab].label
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                sheet
            }
            dock
                .padding(.bottom, 12)
        }
        .background(T.band.ignoresSafeArea())
        .font(.turniq(15))
        .sensoryFeedback(.selection, trigger: tab)
        .sheet(isPresented: $showMas) {
            MasView()
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.turniq(21, .bold))
                .tracking(-0.4)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button { showMas = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(L("Más"))
        }
        .frame(height: 60)
        .padding(.horizontal, 16)
    }

    private var sheet: some View {
        Group {
            switch tab {
            case 0: HomeView(goTab: { tab = $0 })
            case 1: WeekView()
            case 2: JobsView()
            default: EarningsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
    }

    /// Dock de vidrio: inactivas de 48 pt, la activa es una píldora
    /// azul de 58 pt que crece con resorte. Cada ícono rebota al
    /// tocarlo, también si la pestaña ya estaba activa.
    private var dock: some View {
        HStack(spacing: 12) {
            ForEach(tabs.indices, id: \.self) { i in
                let active = tab == i
                Button {
                    taps[i] += 1
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { tab = i }
                } label: {
                    Image(systemName: tabs[i].icon)
                        .font(.system(size: 21, weight: .semibold))
                        .symbolEffect(.bounce, value: taps[i])
                        .foregroundStyle(active ? T.buttonText : T.text3)
                        .frame(width: active ? 58 : 48, height: 48)
                        .background {
                            if active {
                                Capsule()
                                    .fill(T.button)
                                    .shadow(color: T.button.opacity(0.38), radius: 8, y: 3)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tabs[i].label)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(T.card.opacity(0.78)))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
        }
        .overlay {
            Capsule().strokeBorder(T.line, lineWidth: 0.5)
        }
    }
}

/// Espacio al final de cada lista para que el dock no tape nada.
let dockClearance: CGFloat = 110
