import Foundation

// MARK: - Modelo de datos de Turniq (idéntico al de la app Android)
// Fechas "YYYY-MM-DD", horas "HH:mm" (24h). Dinero en dólares.

struct Station: Codable, Identifiable, Equatable {
    var id: String
    var nombre: String
}

struct Job: Codable, Identifiable, Equatable {
    var id: String
    var nombre: String
    /// Color hex "#RRGGBB"
    var color: String
    /// Sueldo por hora en dólares
    var sueldoHora: Double
    /// % de descuento (taxes) 0-100
    var taxPct: Double
    var estaciones: [Station]
    /// PIN que el empleado marca en el reloj de ESE trabajo
    /// (ej. 2001, 255). Opcional. NO es el PIN de la app.
    var pinMarcaje: String?

    static let palette: [String] = [
        "#0064E0", "#D97706", "#0E9F6E", "#9333EA",
        "#DB2777", "#0891B2", "#65A30D", "#DC2626",
    ]
}

struct Shift: Codable, Identifiable, Equatable {
    var id: String
    var jobId: String
    /// Día libre (no cuenta horas ni dinero)
    var esLibre: Bool = false
    var estacionIds: [String] = []
    /// "YYYY-MM-DD"
    var fecha: String
    /// "HH:mm"
    var horaEntrada: String
    /// "HH:mm"; nil = sin salida programada. Si es <= entrada, el
    /// turno cruza medianoche y termina al día siguiente.
    var horaSalida: String?
    /// "HH:mm" reales de marcaje
    var horaEntradaReal: String?
    var horaSalidaReal: String?
    /// Descanso no pagado, minutos
    var breakMin: Int = 0
    var propinas: Double = 0
    var bono: Double = 0
    var notas: String = ""
    /// Evento de Google Calendar vinculado (sync, fase 2)
    var gcalEventId: String?
}

struct ShiftTemplate: Codable, Identifiable, Equatable {
    var id: String
    var nombre: String
    var jobId: String
    var estacionIds: [String] = []
    var horaEntrada: String
    var horaSalida: String?
    var breakMin: Int = 0
}

struct Settings: Codable, Equatable {
    var idioma: String = "es"           // "es" | "en"
    var nombreUsuario: String = ""
    /// Día de cobro: 0=lunes … 4=viernes (semana lun–dom, cobro el
    /// viernes de la semana siguiente por defecto)
    var diaCobro: Int = 4
    /// Avisos antes del turno, en minutos (1440 = 1 día)
    var avisosMin: [Int] = [30]
    /// Umbral semanal de horas extra — POR TRABAJO
    var umbralExtraHrs: Double = 40
    var multExtra: Double = 1.5
    var metaSemanal: Double = 600
    var mostrarMeta: Bool = true
    var mostrarHoraExtra: Bool = true
    var dark: Bool = false
    /// PIN de acceso a la app (4 dígitos) — distinto al pinMarcaje
    var pin: String? = nil
    var biometrico: Bool = false
    var formatoHora: String = "12h"     // "12h" | "24h"
    var onboardingDone: Bool = false
}

/// Documento raíz persistido (JSON en Documents/turniq-v1.json).
struct TurniqData: Codable {
    var jobs: [Job] = []
    var shifts: [Shift] = []
    var templates: [ShiftTemplate] = []
    var settings: Settings = Settings()
}
