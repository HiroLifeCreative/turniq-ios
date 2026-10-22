import SwiftUI

/// La cáscara visual de Turniq, igual que en Android:
/// banda superior OSCURA casi negra con el wordmark y el engranaje
/// (que abre Más), el contenido sobre una HOJA BLANCA redondeada
/// (radio 28 arriba), y abajo el DOCK FLOTANTE de vidrio con
/// íconos solos y la pestaña activa como cápsula azul sólida.
struct TurniqShell: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var showMas = false
    @Namespace private var dockNS

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Inicio"),
        ("calendar", "Semana"),
        ("briefcase.fill", "Trabajos"),
        ("chart.bar.fill", "Ganancias"),
    ]

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
        .sensoryFeedback(.impact(weight: .light), trigger: tab)
        .sheet(isPresented: $showMas) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 0) {
                Text("Turniq").foregroundStyle(.white)
                Text(".").foregroundStyle(T.button)
            }
            .font(.turniq(22, .bold))
            Spacer()
            Button { showMas = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("Más")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var sheet: some View {
        Group {
            switch tab {
            case 0: HomeView()
            case 1: WeekView()
            case 2: JobsView()
            default: EarningsView()
            }
        }
        .padding(.bottom, 84) // espacio para el dock flotante
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .ignoresSafeArea(edges: .bottom)
        }
        .clipped()
    }

    private var dock: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { tab = i }
                } label: {
                    Image(systemName: t.icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(tab == i ? T.buttonText : Color.secondary)
                        .frame(width: 52, height: 46)
                        .background {
                            if tab == i {
                                Capsule()
                                    .fill(T.button)
                                    .matchedGeometryEffect(id: "dockPill", in: dockNS)
                            }
                        }
                }
                .accessibilityLabel(t.label)
            }
        }
        .padding(5)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        }
    }
}
