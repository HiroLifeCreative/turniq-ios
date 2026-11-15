import SwiftUI
import UIKit

/// Totales de un año por trabajo (solo turnos ya trabajados; la hora
/// extra se aplica por trabajo y por semana).
struct YearRow: Identifiable {
    var job: Job
    var shifts: Int
    var totals: Calc.WeekTotals
    var tips: Double
    var id: String { job.id }
}

@MainActor
enum AnnualReport {

    static func rows(year: Int, store: Store) -> [YearRow] {
        let prefix = "\(year)-"
        let worked = Calc.onlyWorked(store.shifts.filter { $0.fecha.hasPrefix(prefix) && !$0.esLibre })
        var out: [YearRow] = []
        for job in store.jobs {
            let mine = worked.filter { $0.jobId == job.id }
            guard !mine.isEmpty else { continue }
            let t = Calc.rangeTotals(shifts: mine, jobsById: [job.id: job],
                                     umbralExtraHrs: store.settings.umbralExtraHrs,
                                     multExtra: store.settings.multExtra)
            out.append(YearRow(job: job, shifts: mine.count, totals: t,
                               tips: mine.reduce(0) { $0 + $1.propinas }))
        }
        return out
    }

    /// Totales por mes (1…12) de todos los trabajos.
    static func months(year: Int, store: Store) -> [Calc.WeekTotals] {
        let worked = Calc.onlyWorked(store.shifts.filter { $0.fecha.hasPrefix("\(year)-") && !$0.esLibre })
        return (1...12).map { m in
            let key = String(format: "%04d-%02d", year, m)
            return Calc.rangeTotals(shifts: worked.filter { $0.fecha.hasPrefix(key) },
                                    jobsById: store.jobsById,
                                    umbralExtraHrs: store.settings.umbralExtraHrs,
                                    multExtra: store.settings.multExtra)
        }
    }

    /// Dibuja el PDF (tamaño carta) y devuelve su archivo temporal.
    static func pdf(year: Int, store: Store) -> URL? {
        let jobRows = Self.rows(year: year, store: store)
        let monthRows = Self.months(year: year, store: store)
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 44
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("turniq-\(year).pdf")

        let dark = UIColor(red: 0.047, green: 0.055, blue: 0.075, alpha: 1)
        let gray = UIColor(red: 0.39, green: 0.42, blue: 0.48, alpha: 1)
        let blue = UIColor(red: 0, green: 0.39, blue: 0.88, alpha: 1)

        func draw(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                  size: CGFloat = 10, bold: Bool = false, color: UIColor = dark,
                  align: NSTextAlignment = .left) {
            let style = NSMutableParagraphStyle()
            style.alignment = align
            style.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular),
                .foregroundColor: color,
                .paragraphStyle: style,
            ]
            (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: size + 6),
                                    withAttributes: attrs)
        }

        func line(_ y: CGFloat, _ ctx: CGContext) {
            ctx.setStrokeColor(UIColor(white: 0.85, alpha: 1).cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: margin, y: y))
            ctx.addLine(to: CGPoint(x: page.width - margin, y: y))
            ctx.strokePath()
        }

        // Columnas: nombre + 5 números alineados a la derecha.
        let numW: CGFloat = 78
        let nameW = page.width - margin * 2 - numW * 5
        func cells(_ name: String, _ values: [String], y: CGFloat, bold: Bool = false, color: UIColor = dark) {
            draw(name, x: margin, y: y, width: nameW - 8, bold: bold, color: color)
            for (i, v) in values.enumerated() {
                draw(v, x: margin + nameW + CGFloat(i) * numW, y: y, width: numW,
                     bold: bold, color: color, align: .right)
            }
        }

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                let ctx = context.cgContext
                var y: CGFloat = margin

                draw("Turniq", x: margin, y: y, width: 200, size: 22, bold: true)
                draw(L("Resumen anual \(year)"), x: margin, y: y + 4, width: page.width - margin * 2,
                     size: 16, bold: true, color: blue, align: .right)
                y += 34
                let name = store.settings.nombreUsuario
                draw(name.isEmpty ? L("Horas y ganancias registradas") : name,
                     x: margin, y: y, width: 300, size: 11, color: gray)
                draw(L("Generado el \(Calc.shortDate(Calc.todayYmd())) \(String(Calc.todayYmd().prefix(4)))"),
                     x: margin, y: y, width: page.width - margin * 2, size: 11, color: gray, align: .right)
                y += 30

                // Por trabajo
                draw(L("Por trabajo").uppercased(), x: margin, y: y, width: 300, size: 9, bold: true, color: gray)
                y += 18
                cells(L("Trabajo"), [L("Turnos"), L("Horas"), L("Bruto"), "Taxes", L("Neto")],
                      y: y, bold: true, color: gray)
                y += 16
                line(y, ctx)
                y += 6
                var sum = Calc.WeekTotals()
                var sumShifts = 0
                var sumTips = 0.0
                for r in jobRows {
                    cells(r.job.nombre,
                          ["\(r.shifts)", Calc.fmtHours(r.totals.hours), Calc.money(r.totals.gross),
                           Calc.money(r.totals.taxes), Calc.money(r.totals.net)], y: y)
                    y += 18
                    sum = sum + r.totals
                    sumShifts += r.shifts
                    sumTips += r.tips
                }
                if jobRows.isEmpty {
                    draw(L("Aún no hay turnos registrados"), x: margin, y: y, width: 400, color: gray)
                    y += 18
                }
                line(y, ctx)
                y += 6
                cells(L("Total"), ["\(sumShifts)", Calc.fmtHours(sum.hours), Calc.money(sum.gross),
                                   Calc.money(sum.taxes), Calc.money(sum.net)], y: y, bold: true)
                y += 22
                draw(L("Propinas incluidas en el bruto: \(Calc.money(sumTips))"),
                     x: margin, y: y, width: 400, color: gray)
                y += 34

                // Por mes
                draw(L("Por mes").uppercased(), x: margin, y: y, width: 300, size: 9, bold: true, color: gray)
                y += 18
                cells(L("Mes"), ["", L("Horas"), L("Bruto"), "Taxes", L("Neto")], y: y, bold: true, color: gray)
                y += 16
                line(y, ctx)
                y += 6
                for (i, m) in monthRows.enumerated() {
                    cells(Calc.monthsLong[i],
                          ["", Calc.fmtHours(m.hours), Calc.money(m.gross), Calc.money(m.taxes), Calc.money(m.net)],
                          y: y, color: m.hours > 0 ? dark : gray)
                    y += 17
                }

                draw(L("Estimaciones basadas en los turnos, sueldos y taxes registrados en Turniq. No es un documento fiscal ni un comprobante de pago."),
                     x: margin, y: page.height - margin - 14, width: page.width - margin * 2,
                     size: 8, color: gray)
            }
            return url
        } catch {
            return nil
        }
    }
}

/// Resumen anual por trabajo, con exportación a PDF.
struct AnnualSummaryView: View {
    @EnvironmentObject var store: Store
    @State private var year = Calc.cal.component(.year, from: Date())
    @State private var shareFile: ShareFile? = nil
    @State private var failed = false

    private var hidden: Bool { store.settings.dineroOculto }

    var body: some View {
        let rows = AnnualReport.rows(year: year, store: store)
        let total = rows.reduce(Calc.WeekTotals()) { $0 + $1.totals }
        let tips = rows.reduce(0.0) { $0 + $1.tips }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: String(year))
                    Spacer()
                    CircleButton(icon: "chevron.left") { year -= 1 }
                    CircleButton(icon: "chevron.right") { year += 1 }
                }

                TintedCard(accent: "#0064E0") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("NETO DEL AÑO")).font(.turniqMono).foregroundStyle(.white.opacity(0.55))
                        Text(T.cash(total.net, hidden: hidden))
                            .font(.turniq(34, .bold)).tracking(-1).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        HStack(alignment: .top) {
                            DarkStat(label: L("Bruto"), value: T.cash(total.gross, hidden: hidden), color: T.amber)
                            Spacer()
                            DarkStat(label: "Taxes", value: T.cash(total.taxes, hidden: hidden))
                            Spacer()
                            DarkStat(label: L("Horas"), value: Calc.fmtHours(total.hours), alignment: .trailing)
                        }
                        if tips > 0 {
                            Text(L("Propinas incluidas en el bruto: \(T.cash(tips, hidden: hidden))"))
                                .font(.turniq(12)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }

                if rows.isEmpty {
                    Text(L("Aún no hay turnos registrados"))
                        .font(.turniq(13)).foregroundStyle(T.text3)
                }
                ForEach(rows) { r in
                    Card(tint: T.hex(r.job.color)) {
                        HStack(spacing: 12) {
                            Circle().fill(T.hex(r.job.color)).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.job.nombre).font(.turniq(16, .bold)).foregroundStyle(T.text).lineLimit(1)
                                Text(L("\(r.shifts) turnos · \(Calc.fmtHours(r.totals.hours))"))
                                    .font(.turniq(12)).foregroundStyle(T.text2)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(T.cash(r.totals.net, hidden: hidden))
                                    .font(.turniq(18, .bold)).foregroundStyle(T.text)
                                Text(L("\(T.cash(r.totals.gross, hidden: hidden)) bruto"))
                                    .font(.turniq(11)).foregroundStyle(T.text3)
                            }
                        }
                    }
                }

                PrimaryButton(title: L("Exportar PDF")) {
                    if let url = AnnualReport.pdf(year: year, store: store) {
                        shareFile = ShareFile(url: url)
                    } else {
                        failed = true
                    }
                }
                .padding(.top, 4)
                .disabled(rows.isEmpty)
                .opacity(rows.isEmpty ? 0.5 : 1)

                if failed {
                    Text(L("No pude crear el PDF.")).font(.turniq(12)).foregroundStyle(T.danger)
                }
                Text(L("Estimaciones basadas en los turnos, sueldos y taxes registrados en Turniq. No es un documento fiscal ni un comprobante de pago."))
                    .font(.turniq(12)).foregroundStyle(T.text3)
            }
            .padding(16)
        }
        .background(T.bg)
        .navigationTitle(L("Resumen anual"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareFile) { f in
            ActivityView(items: [f.url]).presentationDetents([.medium, .large]).turniqSheet()
        }
    }
}

/// Propinas por día de la semana: qué días dejan más por turno.
struct TipsByDayCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let hidden = store.settings.dineroOculto
        let tipped = Calc.onlyWorked(store.shifts).filter { !$0.esLibre && $0.propinas > 0 }
        if !tipped.isEmpty {
            // Promedio por turno con propina, para cada día (0=lunes).
            let avg: [Double] = (0..<7).map { d in
                let day = tipped.filter { Calc.weekdayIndex($0.fecha) == d }
                return day.isEmpty ? 0 : day.reduce(0) { $0 + $1.propinas } / Double(day.count)
            }
            let best = avg.indices.max(by: { avg[$0] < avg[$1] }) ?? 0
            let top = max(1, avg.max() ?? 1)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        MonoLabel(text: L("Propinas por día"))
                        Spacer()
                        Text(L("\(tipped.count) turnos con propina"))
                            .font(.turniq(12)).foregroundStyle(T.text2)
                    }
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(0..<7, id: \.self) { d in
                            VStack(spacing: 4) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(d == best ? T.money : (avg[d] > 0 ? T.primary : T.surface))
                                    .frame(height: max(4, avg[d] / top * 70))
                                Text(Calc.daysShort[d].uppercased())
                                    .font(.turniq(9)).foregroundStyle(d == best ? T.text : T.text3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 92)
                    Text(L("Tu mejor día: \(Calc.daysLong[best].lowercased()), con \(T.cash(avg[best], hidden: hidden)) por turno en promedio."))
                        .font(.turniq(12)).foregroundStyle(T.text2)
                }
            }
        }
    }
}
