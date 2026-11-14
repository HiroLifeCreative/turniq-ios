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
            save()
            scheduleSideEffects()
        }
    }

    private let fileURL: URL
    private let backupsURL: URL
    private var sideEffects: Task<Void, Never>?

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("turniq-v1.json")
        backupsURL = docs.appendingPathComponent("Respaldos", isDirectory: true)
        if let raw = try? Data(contentsOf: fileURL) {
            if let decoded = try? JSONDecoder().decode(TurniqData.self, from: raw) {
                data = decoded
            } else {
                // Archivo ilegible: se conserva una copia antes de
                // empezar de cero, para no perder nada sin remedio.
                let bak = docs.appendingPathComponent("turniq-v1.corrupto.json")
                try? raw.write(to: bak, options: [.atomic])
                data = TurniqData()
            }
        } else {
            data = TurniqData()
        }
        Lang.en = data.settings.idioma == "en"
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: fileURL, options: [.atomic])
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
        let file = backupsURL.appendingPathComponent("turniq-backup-\(Calc.todayYmd()).json")
        guard !fm.fileExists(atPath: file.path), let raw = exportJSON() else { return }
        try? raw.write(to: file, options: [.atomic])
        let names = ((try? fm.contentsOfDirectory(atPath: backupsURL.path)) ?? [])
            .filter { $0.hasPrefix("turniq-backup-") && $0.hasSuffix(".json") }
            .sorted()
        for old in names.dropLast(14) {
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

    func wipeAll() { data = TurniqData() }
}
