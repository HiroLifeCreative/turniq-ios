import Foundation
import SwiftUI

/// Estado global de Turniq iOS. Persiste el MISMO documento JSON
/// que usa el respaldo de Android, así un respaldo exportado de una
/// plataforma se puede importar en la otra.
@MainActor
final class Store: ObservableObject {
    /// Instancia única: también la usan las notificaciones.
    static let shared = Store()

    @Published var data: TurniqData {
        didSet {
            Lang.en = data.settings.idioma == "en"
            Money.apply(data.settings)
            save()
            scheduleSideEffects()
        }
    }

    /// Cuentas (una por país) y la que está en uso.
    @Published private(set) var accounts: [Account]
    @Published private(set) var activeId: String

    private let docsURL: URL
    private let backupsURL: URL
    private var sideEffects: Task<Void, Never>?

    /// Id de la primera cuenta: conserva el archivo de siempre.
    static let mainAccountId = "principal"

    private static func dataURL(_ id: String, in docs: URL) -> URL {
        docs.appendingPathComponent(id == mainAccountId ? "turniq-v1.json" : "turniq-cuenta-\(id).json")
    }

    private var fileURL: URL { Self.dataURL(activeId, in: docsURL) }
    private var indexURL: URL { docsURL.appendingPathComponent("turniq-cuentas.json") }

    /// Lee el archivo de una cuenta. Si está ilegible guarda una copia
    /// antes de empezar de cero, para no perder nada sin remedio.
    private static func load(_ url: URL) -> TurniqData {
        guard let raw = try? Data(contentsOf: url) else { return TurniqData() }
        if let decoded = try? JSONDecoder().decode(TurniqData.self, from: raw) { return decoded }
        let bak = url.deletingPathExtension().appendingPathExtension("corrupto.json")
        try? raw.write(to: bak, options: [.atomic])
        return TurniqData()
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        docsURL = docs
        backupsURL = docs.appendingPathComponent("Respaldos", isDirectory: true)

        var index: AccountIndex? = nil
        if let raw = try? Data(contentsOf: docs.appendingPathComponent("turniq-cuentas.json")) {
            index = try? JSONDecoder().decode(AccountIndex.self, from: raw)
        }
        let active = index.flatMap { ix in ix.accounts.contains { $0.id == ix.activeId } ? ix.activeId : ix.accounts.first?.id }
            ?? Self.mainAccountId
        let loaded = Self.load(Self.dataURL(active, in: docs))
        activeId = active
        if let index, !index.accounts.isEmpty {
            accounts = index.accounts
        } else {
            // Primera vez con cuentas: lo que ya había pasa a ser la
            // cuenta principal, con su país y su moneda.
            accounts = [Account(id: Self.mainAccountId, nombre: nil,
                                pais: loaded.settings.pais, moneda: loaded.settings.moneda)]
        }
        data = loaded
        Lang.en = data.settings.idioma == "en"
        Money.apply(data.settings)
    }

    // MARK: Cuentas

    var activeAccount: Account? { accounts.first { $0.id == activeId } }

    /// La cuenta ya tiene trabajos o turnos: su país y su moneda
    /// quedan fijos (cambiarlos dejaría los montos sin sentido).
    var accountLocked: Bool { !data.jobs.isEmpty || !data.shifts.isEmpty }

    private func saveIndex() {
        let index = AccountIndex(activeId: activeId, accounts: accounts)
        if let raw = try? JSONEncoder().encode(index) {
            try? raw.write(to: indexURL, options: [.atomic])
        }
    }

    /// Ajustes de una cuenta con las preferencias de la app (nombre,
    /// idioma, PIN, avisos…) tomadas de `app`. Lo propio de la cuenta
    /// —país, moneda, impuestos, hora extra, meta y día de cobro— se
    /// conserva.
    private static func merged(account: Settings, app: Settings) -> Settings {
        var s = app
        s.pais = account.pais
        s.moneda = account.moneda
        s.taxDefault = account.taxDefault
        s.umbralExtraHrs = account.umbralExtraHrs
        s.multExtra = account.multExtra
        s.metaSemanal = account.metaSemanal
        s.diaCobro = account.diaCobro
        return s
    }

    /// Cambia a otra cuenta ya creada.
    func switchAccount(_ id: String) {
        guard id != activeId, accounts.contains(where: { $0.id == id }) else { return }
        save()
        var next = Self.load(Self.dataURL(id, in: docsURL))
        next.settings = Self.merged(account: next.settings, app: data.settings)
        activeId = id
        data = next
        saveIndex()
    }

    /// Crea una cuenta vacía para un país (con su moneda y sus valores
    /// sugeridos) y cambia a ella.
    func createAccount(country code: String) {
        let c = Countries.country(code)
        var s = Settings()
        s.pais = c.code
        s.moneda = c.currency
        if let h = c.otHours { s.umbralExtraHrs = h }
        if let m = c.otMult { s.multExtra = m }
        var fresh = TurniqData()
        fresh.settings = Self.merged(account: s, app: data.settings)

        // Si ya hay una cuenta de ese país, la nueva lleva número.
        let same = accounts.filter { $0.pais == c.code }.count
        let name: String? = same == 0 ? nil : "\(c.name) \(same + 1)"
        let account = Account(id: String(UUID().uuidString.prefix(8)).lowercased(),
                              nombre: name, pais: c.code, moneda: c.currency)
        save()
        accounts.append(account)
        activeId = account.id
        data = fresh
        saveIndex()
    }

    /// Borra una cuenta que NO está en uso, con todos sus datos.
    func deleteAccount(_ id: String) {
        guard id != activeId, accounts.count > 1, accounts.contains(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: Self.dataURL(id, in: docsURL))
        accounts.removeAll { $0.id == id }
        saveIndex()
    }

    /// País de la cuenta en uso. Solo se puede cambiar mientras la
    /// cuenta está vacía; después hay que crear otra cuenta.
    func setCountry(_ code: String) {
        guard !accountLocked else { return }
        let c = Countries.country(code)
        setSettings { s in
            s.pais = c.code
            s.moneda = c.currency
            if let h = c.otHours { s.umbralExtraHrs = h }
            if let m = c.otMult { s.multExtra = m }
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: fileURL, options: [.atomic])
        }
        // La lista de cuentas refleja el país y la moneda de la activa.
        if let i = accounts.firstIndex(where: { $0.id == activeId }),
           accounts[i].pais != data.settings.pais || accounts[i].moneda != data.settings.moneda {
            accounts[i].pais = data.settings.pais
            accounts[i].moneda = data.settings.moneda
            saveIndex()
        }
    }

    /// Avisos y calendario se rehacen solos tras cada cambio, con una
    /// pequeña espera para no repetirlo en cada tecla.
    private func scheduleSideEffects() {
        sideEffects?.cancel()
        sideEffects = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, !Task.isCancelled else { return }
            Notifications.reschedule(data: self.data)
            CalendarSync.syncIfEnabled(data: self.data)
            WidgetBridge.update(data: self.data)
            LiveShift.sync(data: self.data)
        }
    }

    /// Al abrir la app o volver a ella.
    func refreshOnForeground() {
        autoCerrarTurnos()
        autoBackup()
        scheduleSideEffects()
    }

    /// Respaldo automático: una copia por día en Documentos/Respaldos
    /// (visible en la app Archivos y dentro de la copia de iCloud del
    /// iPhone). Se guardan las últimas 14.
    private func autoBackup() {
        guard !(data.jobs.isEmpty && data.shifts.isEmpty) else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        // Una copia por día y por cuenta.
        let tag = activeId == Self.mainAccountId ? "" : "-\(activeId)"
        let file = backupsURL.appendingPathComponent("turniq-backup-\(Calc.todayYmd())\(tag).json")
        guard !fm.fileExists(atPath: file.path), let raw = exportJSON() else { return }
        try? raw.write(to: file, options: [.atomic])
        let names = ((try? fm.contentsOfDirectory(atPath: backupsURL.path)) ?? [])
            .filter { $0.hasPrefix("turniq-backup-") && $0.hasSuffix(".json") }
            .sorted()
        for old in names.dropLast(14 * max(1, accounts.count)) {
            try? fm.removeItem(at: backupsURL.appendingPathComponent(old))
        }
    }

    // MARK: Accesos

    var jobs: [Job] { data.jobs }
    var shifts: [Shift] { data.shifts }
    var settings: Settings { data.settings }
    var jobsById: [String: Job] {
        Dictionary(data.jobs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func job(id: String) -> Job? { data.jobs.first { $0.id == id } }
    func shift(id: String) -> Shift? { data.shifts.first { $0.id == id } }

    func setSettings(_ mutate: (inout Settings) -> Void) {
        var s = data.settings
        mutate(&s)
        if s != data.settings { data.settings = s }
    }

    // MARK: Trabajos

    func upsertJob(_ job: Job) {
        if let i = data.jobs.firstIndex(where: { $0.id == job.id }) {
            data.jobs[i] = job
        } else {
            data.jobs.append(job)
        }
    }

    func deleteJob(id: String) {
        var d = data
        d.jobs.removeAll { $0.id == id }
        d.shifts.removeAll { $0.jobId == id }
        d.templates.removeAll { $0.jobId == id }
        d.cheques.removeAll { $0.jobId == id }
        data = d
    }

    // MARK: Turnos

    func upsertShift(_ shift: Shift) {
        if let i = data.shifts.firstIndex(where: { $0.id == shift.id }) {
            data.shifts[i] = shift
        } else {
            data.shifts.append(shift)
        }
    }

    func deleteShift(id: String) { data.shifts.removeAll { $0.id == id } }

    func duplicateShift(id: String) {
        guard let s = data.shifts.first(where: { $0.id == id }) else { return }
        var copy = s
        copy.id = UUID().uuidString
        copy.horaEntradaReal = nil
        copy.horaSalidaReal = nil
        copy.fechaSalidaReal = nil
        copy.gcalEventId = nil
        data.shifts.append(copy)
    }

    /// Duplica los turnos de la semana (lunes YYYY-MM-DD) a la
    /// semana siguiente. Devuelve cuántos creó.
    @discardableResult
    func duplicateWeek(monday: String) -> Int {
        let week = data.shifts.filter { Calc.monday(of: $0.fecha) == monday }
        var copies: [Shift] = []
        for s in week {
            var copy = s
            copy.id = UUID().uuidString
            copy.fecha = Calc.addDays(s.fecha, 7)
            copy.fechaSalida = s.fechaSalida.map { Calc.addDays($0, 7) }
            copy.horaEntradaReal = nil
            copy.horaSalidaReal = nil
            copy.fechaSalidaReal = nil
            copy.gcalEventId = nil
            copies.append(copy)
        }
        if !copies.isEmpty { data.shifts.append(contentsOf: copies) }
        return copies.count
    }

    // MARK: Marcaje (clock in/out)

    /// Turno con entrada real y sin salida real (sesión abierta).
    /// Puede ser de ayer si el turno cruza la medianoche.
    var openShift: Shift? {
        data.shifts
            .filter { $0.horaEntradaReal != nil && $0.horaSalidaReal == nil && !$0.esLibre }
            .sorted { $0.fecha > $1.fecha }
            .first
    }

    func clockIn(shiftId: String) {
        guard let i = data.shifts.firstIndex(where: { $0.id == shiftId }) else { return }
        data.shifts[i].horaEntradaReal = Calc.nowHHMM()
    }

    func clockOut(shiftId: String) {
        guard let i = data.shifts.firstIndex(where: { $0.id == shiftId }) else { return }
        var s = data.shifts[i]
        s.horaSalidaReal = Calc.nowHHMM()
        s.fechaSalidaReal = Calc.todayYmd()
        data.shifts[i] = s
    }

    /// Turno de hoy sin marcar más cercano a la hora actual
    /// (opcionalmente de un trabajo concreto).
    private func pendingShiftNow(jobId: String? = nil) -> Shift? {
        let today = Calc.todayYmd()
        let now = Calc.hmToMin(Calc.nowHHMM()) ?? 0
        return data.shifts
            .filter {
                $0.fecha == today && !$0.esLibre && $0.horaEntradaReal == nil
                    && (jobId == nil || $0.jobId == jobId)
            }
            .min { a, b in
                abs((Calc.hmToMin(a.horaEntrada) ?? 0) - now) < abs((Calc.hmToMin(b.horaEntrada) ?? 0) - now)
            }
    }

    /// Botón "Marcar entrada" del aviso de llegada al trabajo.
    func clockInArrival(jobId: String) {
        guard openShift == nil, let s = pendingShiftNow(jobId: jobId) else { return }
        clockIn(shiftId: s.id)
    }

    /// Enlaces turniq:// (Atajos, Siri, Botón de Acción, widgets):
    ///   turniq://entrada · turniq://salida · turniq://marcar
    /// "marcar" alterna: entrada si no hay turno abierto, salida si lo
    /// hay. Devuelve el mensaje a mostrar, o nil si solo abre la app.
    func handleURL(_ url: URL) -> String? {
        // Un respaldo .json abierto con «Abrir en Turniq» desde
        // Archivos, WhatsApp, correo o AirDrop.
        if url.isFileURL {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let raw = try? Data(contentsOf: url), importMerge(raw) else {
                return L("No pude importar ese archivo.")
            }
            return L("Respaldo importado.")
        }
        guard url.scheme?.lowercased() == "turniq" else { return nil }
        let raw = url.host ?? url.path.replacingOccurrences(of: "/", with: "")
        var action = raw.lowercased()
        if action == "marcar" { action = openShift == nil ? "entrada" : "salida" }
        let fmt12 = settings.formatoHora == "12h"
        let hora = Calc.fmtTime(Calc.nowHHMM(), format12: fmt12)
        switch action {
        case "entrada":
            if let open = openShift {
                return L("Ya tienes un turno en curso en \(job(id: open.jobId)?.nombre ?? L("tu trabajo")).")
            }
            guard let s = pendingShiftNow() else { return L("No tienes turnos pendientes para hoy.") }
            clockIn(shiftId: s.id)
            let j = job(id: s.jobId)
            var msg = L("Entrada marcada en \(j?.nombre ?? L("tu trabajo")) a las \(hora).")
            if let pin = j?.pinMarcaje, !pin.isEmpty { msg += L(" PIN del reloj: \(pin).") }
            return msg
        case "salida":
            guard let open = openShift else { return L("No hay ningún turno en curso.") }
            clockOut(shiftId: open.id)
            return L("Salida marcada en \(job(id: open.jobId)?.nombre ?? L("tu trabajo")) a las \(hora).")
        default:
            return nil
        }
    }

    /// Suma propinas a un turno (se pregunta al marcar salida).
    func addTips(shiftId: String, amount: Double) {
        guard amount > 0, let i = data.shifts.firstIndex(where: { $0.id == shiftId }) else { return }
        data.shifts[i].propinas += amount
    }

    // MARK: Cheques (comparar lo pagado con lo calculado)

    func paycheck(jobId: String, payday: String) -> Paycheck? {
        data.cheques.first { $0.jobId == jobId && $0.payday == payday }
    }

    /// Guarda lo recibido en un día de cobro; nil lo borra.
    func setPaycheck(jobId: String, payday: String, recibido: Double?) {
        var list = data.cheques
        list.removeAll { $0.jobId == jobId && $0.payday == payday }
        if let recibido, recibido >= 0 {
            list.append(Paycheck(id: UUID().uuidString, jobId: jobId, payday: payday, recibido: recibido))
        }
        data.cheques = list
    }

    /// Corrige la hora real de entrada del turno en curso.
    func setRealEntry(shiftId: String, hm: String) {
        guard let i = data.shifts.firstIndex(where: { $0.id == shiftId }) else { return }
        data.shifts[i].horaEntradaReal = hm
    }

    /// Cierre automático: todo turno con entrada real y sin salida
    /// real, de un día anterior, se cierra solo al llegar la hora
    /// tope del día siguiente (4:00 a. m. por defecto). Devuelve
    /// cuántos cerró.
    @discardableResult
    func autoCerrarTurnos() -> Int {
        let tope = Calc.hmToMin(settings.cierreAuto) == nil ? "04:00" : settings.cierreAuto
        let now = Date()
        var d = data
        var closed = 0
        for i in d.shifts.indices {
            let s = d.shifts[i]
            guard s.horaEntradaReal != nil, s.horaSalidaReal == nil else { continue }
            let nextDay = Calc.addDays(s.fecha, 1)
            guard let corte = Calc.date(nextDay, tope), now >= corte else { continue }
            d.shifts[i].horaSalidaReal = tope
            d.shifts[i].fechaSalidaReal = nextDay
            closed += 1
        }
        if closed > 0 { data = d }
        return closed
    }

    // MARK: Respaldos

    func exportJSON() -> Data? {
        var d = data
        d.version = 1
        d.exportedAt = ISO8601DateFormatter().string(from: Date())
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(d)
    }

    /// Importa fusionando (no borra): trabajos, turnos y plantillas
    /// por id. Vale para respaldos de iOS y de Android.
    func importMerge(_ raw: Data) -> Bool {
        guard let other = try? JSONDecoder().decode(TurniqData.self, from: raw),
              !(other.jobs.isEmpty && other.shifts.isEmpty && other.templates.isEmpty) else { return false }
        var d = data
        let jobIds = Set(d.jobs.map { $0.id })
        d.jobs.append(contentsOf: other.jobs.filter { !jobIds.contains($0.id) })
        let shiftIds = Set(d.shifts.map { $0.id })
        d.shifts.append(contentsOf: other.shifts.filter { !shiftIds.contains($0.id) })
        let tplIds = Set(d.templates.map { $0.id })
        d.templates.append(contentsOf: other.templates.filter { !tplIds.contains($0.id) })
        data = d
        return true
    }

    /// Borra los trabajos, turnos, plantillas y cheques de la cuenta
    /// en uso. Las otras cuentas y las preferencias no se tocan.
    func wipeAll() {
        var d = TurniqData()
        d.settings = data.settings
        data = d
    }
}
