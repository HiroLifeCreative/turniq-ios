import SwiftUI

/// "Próximos cobros": cuándo paga cada trabajo y cuánto va a caer.
/// Cada trabajo usa su propio ritmo (cada semana o cada 2 semanas).
struct PaydaysCard: View {
    @EnvironmentObject var store: Store

    private var infos: [PayInfo] {
        Pay.nextForAll(jobs: store.jobs, shifts: store.shifts, settings: store.settings)
    }

    var body: some View {
        let list = infos
        let hidden = store.settings.dineroOculto
        if !list.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(T.button)
                        MonoLabel(text: L("Próximos cobros"))
                    }
                    .padding(.bottom, 4)
                    ForEach(Array(list.enumerated()), id: \.element.id) { idx, p in
                        if idx > 0 { Rectangle().fill(T.line).frame(height: 0.5) }
                        row(p, hidden: hidden)
                    }
                }
            }
        }
    }

    private func row(_ p: PayInfo, hidden: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(T.hex(p.job.color)).frame(width: 10, height: 10).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.job.nombre)
                    .font(.turniq(15, .bold)).foregroundStyle(T.text).lineLimit(1)
                Text("\(Calc.weekdayDate(p.payday)) · \(Pay.freq(p.job).label.lowercased())")
                    .font(.turniq(12)).foregroundStyle(T.text2).lineLimit(1)
                Text(L("Paga \(Calc.shortDate(p.periodStart)) – \(Calc.shortDate(p.periodEnd)) · \(Calc.fmtHours(p.totals.hours))"))
                    .font(.turniq(12)).foregroundStyle(T.text3).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(T.cash(p.totals.net, hidden: hidden))
                    .font(.turniq(17, .bold))
                    .foregroundStyle(p.closed ? T.success : T.text)
                Text(p.whenLabel)
                    .font(.turniq(12, .bold))
                    .foregroundStyle(p.daysLeft == 0 ? T.success : T.text2)
                if !p.closed {
                    Text(L("acumulando")).font(.turniq(11)).foregroundStyle(T.text3)
                }
            }
        }
        .padding(.vertical, 10)
    }
}
