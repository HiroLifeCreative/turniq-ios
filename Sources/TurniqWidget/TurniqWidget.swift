import WidgetKit
import SwiftUI
import TurniqShared

// MARK: - Widgets de Turniq
// · Home (pequeño y mediano): próximo turno con su PIN, neto de la
//   semana y próximo cobro.
// · Pantalla de bloqueo (rectangular, circular, en línea).
// · Actividad en Vivo del turno en curso (ShiftLiveActivity.swift).

@main
struct TurniqWidgetBundle: WidgetBundle {
    var body: some Widget {
        TurniqWidget()
        ShiftLiveActivity()
    }
}

struct TurniqEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?

    /// Próximo turno respecto a la hora de esta entrada.
    var nextShift: WidgetSnapshot.ShiftItem? {
        snapshot?.shifts.first(where: { $0.start > date })
    }

    /// Turno que está ocurriendo ahora según su horario.
    var currentShift: WidgetSnapshot.ShiftItem? {
        snapshot?.shifts.first(where: { s in
            guard let end = s.end else { return false }
            return s.start <= date && end > date
        })
    }

    var nextPay: WidgetSnapshot.PayItem? {
        let today = Calendar.current.startOfDay(for: date)
        return snapshot?.pays.first(where: { $0.payday >= today })
    }

    /// Neto de la semana; 0 si ya empezó una semana nueva.
    var weekNet: Double {
        guard let s = snapshot, date < s.weekEnd else { return 0 }
        return s.weekNet
    }

    var hideMoney: Bool { snapshot?.hideMoney ?? false }
}

struct TurniqProvider: TimelineProvider {
    func placeholder(in context: Context) -> TurniqEntry {
        TurniqEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TurniqEntry) -> Void) {
        let snap = context.isPreview ? WidgetSnapshot.sample : (WidgetSnapshot.load() ?? .sample)
        completion(TurniqEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TurniqEntry>) -> Void) {
        let now = Date()
        let snap = WidgetSnapshot.load()
        // Una entrada ahora y otra al empezar y al terminar cada turno
        // cercano, para que "próximo turno" avance solo.
        var dates: [Date] = [now]
        for s in snap?.shifts ?? [] {
            if s.start > now { dates.append(s.start.addingTimeInterval(1)) }
            if let end = s.end, end > now { dates.append(end.addingTimeInterval(1)) }
        }
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400 + 5)
        dates.append(midnight)
        let entries = Array(Set(dates)).sorted().prefix(12).map { TurniqEntry(date: $0, snapshot: snap) }
        completion(Timeline(entries: Array(entries), policy: .after(midnight.addingTimeInterval(3600))))
    }
}

struct TurniqWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TurniqWidget", provider: TurniqProvider()) { entry in
            TurniqWidgetView(entry: entry)
                .containerBackground(for: .widget) { WColor.band }
                .widgetURL(URL(string: "turniq://abrir"))
        }
        .configurationDisplayName("Turniq")
        .description("Tu próximo turno con su PIN, el neto de la semana y tu próximo cobro.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Estilo y formato

enum WColor {
    static let band = Color(red: 0.078, green: 0.086, blue: 0.102)   // #14161A
    static let button = Color(red: 0.012, green: 0.573, blue: 1.0)   // #0392FF
    static let money = Color(red: 0.196, green: 0.769, blue: 0.427)  // #32C46D
    static let orange = Color(red: 0.91, green: 0.514, blue: 0.047)  // #E8830C

    static func hex(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt64(s, radix: 16) ?? 0x0064E0
        return Color(red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }
}

enum WFmt {
    private static let moneyFmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static var symbol = "$"

    /// Toma la moneda del perfil que viene en la foto de datos.
    static func configure(_ snap: WidgetSnapshot?) {
        guard let snap else { return }
        symbol = snap.currencySymbol ?? "$"
        let d = snap.currencyDecimals ?? 2
        moneyFmt.locale = Locale(identifier: snap.currencyLocale ?? "en_US")
        moneyFmt.minimumFractionDigits = d
        moneyFmt.maximumFractionDigits = d
    }

    static func money(_ n: Double, hidden: Bool) -> String {
        if hidden { return "••••" }
        let gap = (symbol.last.map { $0.isLetter || $0 == "/" || $0 == "." } ?? false) ? " " : ""
        return symbol + gap + (moneyFmt.string(from: NSNumber(value: n)) ?? String(format: "%.2f", n))
    }

    static func time(_ d: Date, format12: Bool, english: Bool = false) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let h = c.hour ?? 0, m = c.minute ?? 0
        if !format12 { return String(format: "%02d:%02d", h, m) }
        let h12 = h % 12 == 0 ? 12 : h % 12
        let suffix = english ? (h < 12 ? "AM" : "PM") : (h < 12 ? "a.m." : "p.m.")
        return String(format: "%d:%02d %@", h12, m, suffix)
    }

    private static let days = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    private static let months = ["ene", "feb", "mar", "abr", "may", "jun",
                                 "jul", "ago", "sep", "oct", "nov", "dic"]
    private static let daysEn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "Hoy" / "Mañana" / "vie 20 nov"
    static func day(_ d: Date, relativeTo now: Date, english: Bool = false) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
        if diff == 0 { return english ? "Today" : "Hoy" }
        if diff == 1 { return english ? "Tomorrow" : "Mañana" }
        let c = cal.dateComponents([.weekday, .day, .month], from: d)
        let wi = max(0, min(6, (c.weekday ?? 1) - 1))
        let mi = max(0, min(11, (c.month ?? 1) - 1))
        if english { return "\(daysEn[wi]), \(monthsEn[mi]) \(c.day ?? 1)" }
        return "\(days[wi]) \(c.day ?? 1) \(months[mi])"
    }

    static func range(_ s: WidgetSnapshot.ShiftItem, format12: Bool, english: Bool = false) -> String {
        let a = time(s.start, format12: format12, english: english)
        guard let end = s.end else { return a }
        return "\(a) – \(time(end, format12: format12, english: english))"
    }
}

// MARK: - Vistas

struct TurniqWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TurniqEntry

    private var fmt12: Bool { entry.snapshot?.format12 ?? true }
    private var en: Bool { entry.snapshot?.english ?? false }

    /// Texto en español o en inglés según el idioma de la app.
    private func tr(_ es: String, _ english: String) -> String { en ? english : es }

    var body: some View {
        let _ = WFmt.configure(entry.snapshot)
        switch family {
        case .systemMedium: medium
        case .accessoryRectangular: rectangular
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: small
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1)
    }

    /// Bloque "próximo turno" (o el turno en curso).
    @ViewBuilder
    private var shiftBlock: some View {
        if let s = entry.currentShift {
            label(tr("En turno", "On shift"))
            jobLine(s)
            Text(verbatim: tr("Hasta", "Until") + " " + (s.end.map { WFmt.time($0, format12: fmt12, english: en) } ?? ""))
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            pinLine(s)
        } else if let s = entry.nextShift {
            label(tr("Próximo turno", "Next shift"))
            jobLine(s)
            Text("\(WFmt.day(s.start, relativeTo: entry.date, english: en)) · \(WFmt.time(s.start, format12: fmt12, english: en))")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                .lineLimit(1).minimumScaleFactor(0.8)
            pinLine(s)
        } else {
            label(tr("Próximo turno", "Next shift"))
            Text(verbatim: entry.snapshot == nil ? tr("Abre Turniq", "Open Turniq") : tr("Sin turnos", "No shifts"))
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
        }
    }

    private func jobLine(_ s: WidgetSnapshot.ShiftItem) -> some View {
        HStack(spacing: 5) {
            Circle().fill(WColor.hex(s.colorHex)).frame(width: 8, height: 8)
            Text(s.jobName)
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private func pinLine(_ s: WidgetSnapshot.ShiftItem) -> some View {
        if let pin = s.pin, !pin.isEmpty {
            Label("PIN \(pin)", systemImage: "key.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WColor.button)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 3) {
            shiftBlock
            Spacer(minLength: 0)
            label(tr("Neto semana", "Net this week"))
            Text(WFmt.money(entry.weekNet, hidden: entry.hideMoney))
                .font(.system(size: 20, weight: .bold)).foregroundStyle(WColor.money)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                shiftBlock
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(.white.opacity(0.12)).frame(width: 1)

            VStack(alignment: .leading, spacing: 3) {
                label(tr("Neto semana", "Net this week"))
                Text(WFmt.money(entry.weekNet, hidden: entry.hideMoney))
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(WColor.money)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                label(tr("Próximo cobro", "Next payday"))
                if let p = entry.nextPay {
                    Text("\(WFmt.day(p.payday, relativeTo: entry.date, english: en)) · \(WFmt.money(p.net, hidden: entry.hideMoney))")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(p.jobName)
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                } else {
                    Text("—").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Pantalla de bloqueo

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let s = entry.currentShift ?? entry.nextShift {
                Text(s.jobName).font(.headline).lineLimit(1)
                Text("\(WFmt.day(s.start, relativeTo: entry.date, english: en)) · \(WFmt.range(s, format12: fmt12, english: en))")
                    .font(.caption).lineLimit(1).minimumScaleFactor(0.8)
                if let pin = s.pin, !pin.isEmpty {
                    Text("PIN \(pin)").font(.caption.bold())
                } else {
                    Text(verbatim: tr("Semana", "Week") + ": " + WFmt.money(entry.weekNet, hidden: entry.hideMoney)).font(.caption)
                }
            } else {
                Text("Turniq").font(.headline)
                Text(verbatim: tr("Sin turnos próximos", "No upcoming shifts")).font(.caption)
                Text(verbatim: tr("Semana", "Week") + ": " + WFmt.money(entry.weekNet, hidden: entry.hideMoney)).font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "clock").font(.system(size: 11, weight: .semibold))
                if let s = entry.nextShift {
                    Text(WFmt.time(s.start, format12: false))
                        .font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.7)
                } else {
                    Text("—").font(.system(size: 14, weight: .bold))
                }
            }
        }
    }

    private var inline: some View {
        Group {
            if let s = entry.nextShift {
                Text("\(WFmt.day(s.start, relativeTo: entry.date, english: en)) \(WFmt.time(s.start, format12: fmt12, english: en)) · \(s.jobName)")
            } else {
                Text(verbatim: tr("Turniq · sin turnos", "Turniq · no shifts"))
            }
        }
    }
}
