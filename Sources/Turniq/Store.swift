import Foundation
import SwiftUI

/// Estado global de Turniq iOS. Persiste el MISMO documento JSON
/// que la app de Android usa internamente (turniq-v1.json), así un
/// respaldo exportado de una plataforma se puede importar en la otra.
@MainActor
final class Store: ObservableObject {
    @Published var data: TurniqData {
        didSet { save() }
    }

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("turniq-v1.json")
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(TurniqData.self, from: raw) {
            data = decoded
        } else {
            data = TurniqData()
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: fileURL, options: [.atomic])
        }
    }

    // MARK: Accesos

    var jobs: [Job] { data.jobs }
    var shifts: [Shift] { data.shifts }
    var settings: Settings { data.settings }
    var jobsById: [String: Job] { Dictionary(uniqueKeysWithValues: data.jobs.map { ($0.id, $0) }) }

    func job(id: String) -> Job? { data.jobs.first { $0.id == id } }

    func setSettings(_ mutate: (inout Settings) -> Void) {
        var s = data.settings
        mutate(&s)
        data.settings = s
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
        data.jobs.removeAll { $0.id == id }
        data.shifts.removeAll { $0.jobId == id }
        data.templates.removeAll { $0.jobId == id }
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
        copy.gcalEventId = nil
        data.shifts.append(copy)
    }

    /// Duplica los turnos de la semana (lunes YYYY-MM-DD) a la
    /// semana siguiente. Devuelve cuántos creó.
    @discardableResult
    func duplicateWeek(monday: String) -> Int {
        let week = data.shifts.filter { Calc.monday(of: $0.fecha) == monday }
        var created = 0
        for s in week {
            var copy = s
            copy.id = UUID().uuidString
            copy.fecha = Calc.addDays(s.fecha, 7)
            copy.horaEntradaReal = nil
            copy.horaSalidaReal = nil
            copy.gcalEventId = nil
            data.shifts.append(copy)
            created += 1
        }
        return created
    }

    // MARK: Marcaje (clock in/out)

    /// Turno de hoy con entrada real y sin salida real (sesión abierta)
    var openShift: Shift? {
        let today = Calc.todayYmd()
        return data.shifts.first {
            $0.fecha == today && $0.horaEntradaReal != nil && $0.horaSalidaReal == nil && !$0.esLibre
        }
    }

    func clockIn(shiftId: String) {
        guard let i = data.shifts.firstIndex(where: { $0.id == shiftId }) else { return }
        data.shifts[i].horaEntradaReal = Calc.nowHHMM()
    }

    func clockOut(shiftId: String) {
        guard let i = data.shifts.firstIndex(where: { $0.id == shiftId }) else { return }
        data.shifts[i].horaSalidaReal = Calc.nowHHMM()
    }

    // MARK: Respaldos

    func exportJSON() -> Data? { try? JSONEncoder().encode(data) }

    /// Importa fusionando (no borra): trabajos por id, turnos por id.
    func importMerge(_ raw: Data) -> Bool {
        guard let other = try? JSONDecoder().decode(TurniqData.self, from: raw) else { return false }
        let jobIds = Set(data.jobs.map { $0.id })
        data.jobs.append(contentsOf: other.jobs.filter { !jobIds.contains($0.id) })
        let shiftIds = Set(data.shifts.map { $0.id })
        data.shifts.append(contentsOf: other.shifts.filter { !shiftIds.contains($0.id) })
        let tplIds = Set(data.templates.map { $0.id })
        data.templates.append(contentsOf: other.templates.filter { !tplIds.contains($0.id) })
        return true
    }

    func wipeAll() { data = TurniqData() }
}
