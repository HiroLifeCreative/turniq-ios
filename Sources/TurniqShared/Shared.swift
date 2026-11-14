import Foundation
import ActivityKit

// MARK: - Código compartido entre la app y la extensión de Widgets
// La app escribe una "foto" pequeña de los datos (próximos turnos,
// neto de la semana, próximos cobros) en el contenedor del grupo de
// apps; el widget solo la lee y la dibuja. Así la extensión no
// necesita el motor de cálculo ni el archivo completo de datos.

public enum AppGroup {
    /// Identificador declarado en Turniq.entitlements.
    public static let declaredID = "group.com.hirolifecreative.turniq"

    /// Identificador del paquete de la APP (también desde la extensión,
    /// que vive en Turniq.app/PlugIns/TurniqWidget.appex).
    public static var hostBundleID: String? {
        var url = Bundle.main.bundleURL
        if url.pathExtension == "appex" {
            url = url.deletingLastPathComponent().deletingLastPathComponent()
            if let id = Bundle(url: url)?.bundleIdentifier { return id }
            // Sin acceso al paquete de la app: el id de la extensión es
            // el de la app + ".TurniqWidget".
            if let own = Bundle.main.bundleIdentifier, let dot = own.lastIndex(of: ".") {
                return String(own[..<dot])
            }
        }
        return Bundle.main.bundleIdentifier
    }

    /// Grupos de apps que el perfil de firma le concede a este binario
    /// (se leen de embedded.mobileprovision). Cada herramienta de firma
    /// renombra el grupo a su manera; el perfil dice el nombre real.
    public static var provisionedGroups: [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url),
              let start = raw.range(of: Data("<?xml".utf8)),
              let end = raw.range(of: Data("</plist>".utf8), in: start.lowerBound..<raw.endIndex) else { return [] }
        let xml = raw.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any],
              let ents = plist["Entitlements"] as? [String: Any],
              let groups = ents["com.apple.security.application-groups"] as? [String] else { return [] }
        return groups
    }

    /// Candidatos, del más probable al menos. El mismo orden en la app
    /// y en la extensión, para que las dos elijan la misma carpeta.
    public static var candidates: [String] {
        var list: [String] = []
        let prov = provisionedGroups.sorted()
        list += prov.filter { $0.lowercased().contains("turniq") }
        if let host = hostBundleID { list.append("group." + host) }
        list.append(declaredID)
        list += prov
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    private static var cached: (id: String, url: URL)?

    private static func resolve() -> (id: String, url: URL)? {
        if let cached { return cached }
        for id in candidates {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                cached = (id, url)
                return cached
            }
        }
        return nil
    }

    /// Grupo que realmente funciona en esta instalación; nil si la
    /// app se firmó sin grupo de apps.
    public static var groupID: String? { resolve()?.id }

    /// Carpeta compartida; nil si la app se firmó sin el grupo.
    public static var containerURL: URL? { resolve()?.url }

    /// Texto de diagnóstico para la pantalla de ayuda.
    public static var diagnostics: String {
        let prov = provisionedGroups
        return "id: \(hostBundleID ?? "?")\nperfil: \(prov.isEmpty ? "sin grupos" : prov.joined(separator: ", "))\nen uso: \(groupID ?? "ninguno")"
    }
}

/// Foto de los datos para los widgets.
public struct WidgetSnapshot: Codable, Sendable {

    public struct ShiftItem: Codable, Sendable, Identifiable {
        public var id: String
        public var jobName: String
        public var colorHex: String
        public var start: Date
        public var end: Date?
        public var pin: String?

        public init(id: String, jobName: String, colorHex: String, start: Date, end: Date?, pin: String?) {
            self.id = id
            self.jobName = jobName
            self.colorHex = colorHex
            self.start = start
            self.end = end
            self.pin = pin
        }
    }

    public struct PayItem: Codable, Sendable, Identifiable {
        public var id: String
        public var jobName: String
        public var colorHex: String
        /// Medianoche del día de cobro
        public var payday: Date
        public var net: Double
        /// El periodo ya terminó: el monto es definitivo
        public var closed: Bool

        public init(id: String, jobName: String, colorHex: String, payday: Date, net: Double, closed: Bool) {
            self.id = id
            self.jobName = jobName
            self.colorHex = colorHex
            self.payday = payday
            self.net = net
            self.closed = closed
        }
    }

    public var generatedAt: Date
    /// Lunes 00:00 de la semana del neto, y lunes siguiente
    public var weekStart: Date
    public var weekEnd: Date
    public var weekNet: Double
    public var weekHours: Double
    public var hideMoney: Bool
    public var format12: Bool
    public var shifts: [ShiftItem]
    public var pays: [PayItem]
    /// true = textos en inglés
    public var english: Bool?

    public init(generatedAt: Date, weekStart: Date, weekEnd: Date, weekNet: Double, weekHours: Double,
                hideMoney: Bool, format12: Bool, shifts: [ShiftItem], pays: [PayItem],
                english: Bool = false) {
        self.english = english
        self.generatedAt = generatedAt
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.weekNet = weekNet
        self.weekHours = weekHours
        self.hideMoney = hideMoney
        self.format12 = format12
        self.shifts = shifts
        self.pays = pays
    }

    private static let fileName = "widget-snapshot.json"

    /// Guarda la foto. false si no hay carpeta compartida.
    @discardableResult
    public func save() -> Bool {
        guard let dir = AppGroup.containerURL,
              let raw = try? JSONEncoder().encode(self) else { return false }
        do {
            try raw.write(to: dir.appendingPathComponent(Self.fileName), options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    public static func load() -> WidgetSnapshot? {
        guard let dir = AppGroup.containerURL,
              let raw = try? Data(contentsOf: dir.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: raw)
    }

    /// Datos de muestra para la galería de widgets.
    public static var sample: WidgetSnapshot {
        let now = Date()
        return WidgetSnapshot(
            generatedAt: now,
            weekStart: now.addingTimeInterval(-3 * 86400),
            weekEnd: now.addingTimeInterval(4 * 86400),
            weekNet: 486.50, weekHours: 31.5,
            hideMoney: false, format12: true,
            shifts: [ShiftItem(id: "demo", jobName: "Mi trabajo", colorHex: "#0064E0",
                               start: now.addingTimeInterval(3 * 3600),
                               end: now.addingTimeInterval(11 * 3600), pin: "2001")],
            pays: [PayItem(id: "demo", jobName: "Mi trabajo", colorHex: "#0064E0",
                           payday: now.addingTimeInterval(2 * 86400), net: 412.30, closed: true)]
        )
    }
}

/// Actividad en Vivo del turno en curso (pantalla de bloqueo y
/// Dynamic Island).
public struct ShiftActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable, Sendable {
        /// Entrada real
        public var start: Date
        /// Salida programada (para la barra de progreso)
        public var scheduledEnd: Date?
        /// Neto por hora de este trabajo (sueldo menos taxes)
        public var netPerHour: Double
        public var hideMoney: Bool
        public var english: Bool?

        public init(start: Date, scheduledEnd: Date?, netPerHour: Double, hideMoney: Bool, english: Bool = false) {
            self.english = english
            self.start = start
            self.scheduledEnd = scheduledEnd
            self.netPerHour = netPerHour
            self.hideMoney = hideMoney
        }
    }

    public var shiftId: String
    public var jobName: String
    public var colorHex: String
    public var pin: String?

    public init(shiftId: String, jobName: String, colorHex: String, pin: String?) {
        self.shiftId = shiftId
        self.jobName = jobName
        self.colorHex = colorHex
        self.pin = pin
    }
}
