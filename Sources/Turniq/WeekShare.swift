import SwiftUI
import UIKit

/// Imagen de la semana para compartir (sin montos: solo días, horas
/// y trabajos). Se dibuja siempre en claro.
struct WeekShareCard: View {
    var title: String
    var name: String
    /// (día "Lun", número, filas "7:00 a.m. – 2:30 p.m. · Trabajo" con color)
    var days: [(label: String, number: String, rows: [(color: String, text: String)])]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("Turniq").foregroundStyle(.white)
                    Text(".").foregroundStyle(T.button)
                }
                .font(.turniq(18, .bold))
                Text(title).font(.turniq(22, .bold)).foregroundStyle(.white)
                if !name.isEmpty {
                    Text(name).font(.turniq(13)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.hex("#14161A"))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { idx, d in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Text(d.number).font(.turniq(20, .bold)).foregroundStyle(T.hex("#0C0E13"))
                            Text(d.label.uppercased()).font(.turniq(10)).foregroundStyle(T.hex("#646B7A"))
                        }
                        .frame(width: 40)
                        VStack(alignment: .leading, spacing: 5) {
                            if d.rows.isEmpty {
                                Text("—").font(.turniq(14)).foregroundStyle(T.hex("#646B7A"))
                            }
                            ForEach(Array(d.rows.enumerated()), id: \.offset) { _, r in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Circle().fill(T.hex(r.color)).frame(width: 8, height: 8)
                                    Text(r.text).font(.turniq(14, .medium)).foregroundStyle(T.hex("#0C0E13"))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 3)
                    }
                    .padding(.vertical, 10)
                    if idx < days.count - 1 {
                        Rectangle().fill(T.hex("#E6E8EC")).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .frame(width: 380)
        .background(Color.white)
    }
}

@MainActor
enum WeekShare {

    /// Crea la imagen PNG de la semana y devuelve su archivo temporal.
    static func image(monday: String, store: Store) -> URL? {
        let fmt12 = store.settings.formatoHora == "12h"
        var days: [(label: String, number: String, rows: [(color: String, text: String)])] = []
        for i in 0..<7 {
            let day = Calc.addDays(monday, i)
            let list = store.shifts.filter { $0.fecha == day }.sorted { $0.horaEntrada < $1.horaEntrada }
            var rows: [(color: String, text: String)] = []
            for s in list {
                let job = store.job(id: s.jobId)
                if s.esLibre {
                    rows.append((color: "#8B8D98", text: L("Día libre")))
                } else {
                    rows.append((color: job?.color ?? "#0064E0",
                                 text: "\(Calc.rangeLabel(s, format12: fmt12)) · \(job?.nombre ?? "")"))
                }
            }
            days.append((label: Calc.daysShort[i], number: String(Int(day.suffix(2)) ?? 0), rows: rows))
        }
        let card = WeekShareCard(
            title: "\(Calc.shortDate(monday)) – \(Calc.shortDate(Calc.addDays(monday, 6)))",
            name: store.settings.nombreUsuario,
            days: days)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage, let png = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("turniq-semana-\(monday).png")
        do {
            try png.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }
}
