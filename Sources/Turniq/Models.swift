import Foundation

// MARK: - Modelo de datos de Turniq (idéntico al de la app Android)
// Fechas "YYYY-MM-DD", horas "HH:mm" (24h). Dinero en dólares.
//
// La lectura es TOLERANTE: cualquier campo que falte en el JSON toma
// su valor por defecto. Así un respaldo de Android (que omite campos
// opcionales) o un archivo guardado por una versión anterior de la
// app nunca falla al cargarse ni borra los datos.

extension KeyedDecodingContainer {
    /// Lee un valor; si falta, es null o tiene otro tipo, usa `def`.
    func val<T: Decodable>(_ key: Key, _ def: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? def
    }

    /// Lee un valor opcional sin lanzar nunca.
    func opt<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

struct Station: Codable, Identifiable, Equatable {
    var id: String
    var nombre: String
    /// Sueldo por hora propio de esta estación. nil = el del trabajo.
    var sueldoHora: Double?
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

    // MARK: Cobro por trabajo
    /// Cada cuánto paga este trabajo: "semanal" o "quincenal" (cada
    /// 2 semanas). nil = semanal con el día de cobro de Ajustes.
    var pagoFrecuencia: String?
    /// Día de la semana en que paga: 0=lunes … 6=domingo.
    /// nil = el día de cobro general de Ajustes.
    var pagoDia: Int?
    /// Solo quincenal: una fecha "YYYY-MM-DD" en la que este trabajo
    /// pagó (o pagará). Los demás cobros caen cada 14 días desde ahí.
    var pagoAncla: String?
    /// Semanas de espera entre el final de la semana trabajada y el
    /// cobro: 1 = se cobra en la semana siguiente (trabajo 2–8 nov,
    /// cobro el viernes 13); 2 = pasan 2 semanas (trabajo 2–8 nov,
    /// cobro el viernes 20). nil = 1.
    var pagoRetraso: Int?

    // MARK: Aviso al llegar
    /// Ubicación del trabajo (grados). Con ella Turniq avisa al
    /// llegar para marcar la entrada. nil = sin aviso.
    var lat: Double?
    var lon: Double?

    // MARK: Tarifas especiales
    /// Extra por hora trabajada de noche (10 p. m. – 6 a. m.), en
    /// dólares. nil o 0 = sin extra nocturno.
    var nocturnoExtra: Double?

    // MARK: Forma de pago (ver PayMode.swift)
    /// "hora" | "dia" | "fijo" | "turno". nil = por hora.
    var pagoTipo: String?
    /// Monto por día, por turno o por periodo (según pagoTipo)
    var pagoMonto: Double?
    /// Sueldo fijo: "semanal" | "quincenal" | "mensual"
    var pagoPeriodo: String?
    /// Sueldo fijo: días que se trabajan por semana
    var diasSemana: Int?
    /// Por día: horas de una jornada (para el valor de la hora extra)
    var horasDia: Double?
    /// Sueldo fijo: horas de un mes (para el valor de la hora extra)
    var horasMes: Double?
    /// Por día: paga un día de descanso por cada seis trabajados
    var septimoDia: Bool?

    // Misma paleta que Android (JOB_COLORS).
    static let palette: [String] = [
        "#0064E0", "#7C3AED", "#0E7C3E", "#D97706",
        "#D13438", "#0E9BD8", "#DB2777", "#4B5563",
    ]
}

extension Job {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UUID().uuidString)
        nombre = c.val(.nombre, "")
        color = c.val(.color, Job.palette[0])
        sueldoHora = c.val(.sueldoHora, 0)
        taxPct = c.val(.taxPct, 0)
        estaciones = c.val(.estaciones, [])
        pinMarcaje = c.opt(.pinMarcaje)
        pagoFrecuencia = c.opt(.pagoFrecuencia)
        pagoDia = c.opt(.pagoDia)
        pagoAncla = c.opt(.pagoAncla)
        pagoRetraso = c.opt(.pagoRetraso)
        lat = c.opt(.lat)
        lon = c.opt(.lon)
        nocturnoExtra = c.opt(.nocturnoExtra)
        pagoTipo = c.opt(.pagoTipo)
        pagoMonto = c.opt(.pagoMonto)
        pagoPeriodo = c.opt(.pagoPeriodo)
        diasSemana = c.opt(.diasSemana)
        horasDia = c.opt(.horasDia)
        horasMes = c.opt(.horasMes)
        septimoDia = c.opt(.septimoDia)
    }
}

struct Shift: Codable, Identifiable, Equatable {
    var id: String
    var jobId: String
    /// Día libre (no cuenta horas ni dinero)
    var esLibre: Bool = false
    var estacionIds: [String] = []
    /// "YYYY-MM-DD" (día de la entrada)
    var fecha: String
    /// "YYYY-MM-DD" explícita de la salida programada. nil en datos
    /// viejos: ahí vale la regla "salida <= entrada = día siguiente".
    var fechaSalida: String? = nil
    /// "HH:mm"
    var horaEntrada: String
    /// "HH:mm"; nil = sin salida programada.
    var horaSalida: String?
    /// "HH:mm" reales de marcaje
    var horaEntradaReal: String?
    var horaSalidaReal: String?
    /// "YYYY-MM-DD" real de la salida marcada
    var fechaSalidaReal: String? = nil
    /// Descanso no pagado, minutos
    var breakMin: Int = 0
    var propinas: Double = 0
    var bono: Double = 0
    var notas: String = ""
    /// Evento de Google Calendar vinculado (Android)
    var gcalEventId: String?
    /// Pago especial del turno: 2 = feriado / pago doble, 1.5 = tiempo
    /// y medio. nil = pago normal.
    var multiplicador: Double? = nil
}

extension Shift {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UUID().uuidString)
        jobId = c.val(.jobId, "")
        esLibre = c.val(.esLibre, false)
        estacionIds = c.val(.estacionIds, [])
        fecha = c.val(.fecha, "1970-01-05")
        fechaSalida = c.opt(.fechaSalida)
        horaEntrada = c.val(.horaEntrada, "09:00")
        horaSalida = c.opt(.horaSalida)
        horaEntradaReal = c.opt(.horaEntradaReal)
        horaSalidaReal = c.opt(.horaSalidaReal)
        fechaSalidaReal = c.opt(.fechaSalidaReal)
        breakMin = c.val(.breakMin, 0)
        propinas = c.val(.propinas, 0)
        bono = c.val(.bono, 0)
        notas = c.val(.notas, "")
        gcalEventId = c.opt(.gcalEventId)
        multiplicador = c.opt(.multiplicador)
    }
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

extension ShiftTemplate {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UUID().uuidString)
        nombre = c.val(.nombre, "")
        jobId = c.val(.jobId, "")
        estacionIds = c.val(.estacionIds, [])
        horaEntrada = c.val(.horaEntrada, "09:00")
        horaSalida = c.opt(.horaSalida)
        breakMin = c.val(.breakMin, 0)
    }
}

struct Settings: Codable, Equatable {
    var idioma: String = "es"           // "es" | "en"
    var nombreUsuario: String = ""
    /// Día de cobro general: 0=lunes … 6=domingo (por defecto
    /// 4=viernes). Cada trabajo puede tener el suyo (Job.pagoDia).
    var diaCobro: Int = 4
    /// Avisos antes del turno, en minutos (1440 = 1 día)
    var avisosMin: [Int] = [30]
    /// Umbral semanal de horas extra — POR TRABAJO
    var umbralExtraHrs: Double = 40
    var multExtra: Double = 1.5
    var metaSemanal: Double = 600
    var mostrarMeta: Bool = true
    var mostrarHoraExtra: Bool = true
    var terminosAceptados: Bool = false
    /// Ojito del héroe: oculta el dinero con •••••
    var dineroOculto: Bool = false
    var dark: Bool = false
    /// PIN de acceso a la app (4 dígitos) — distinto al pinMarcaje
    var pin: String? = nil
    var biometrico: Bool = false
    var formatoHora: String = "12h"     // "12h" | "24h"
    var onboardingDone: Bool = false
    var sonidoAlarma: String = "clasica"
    var posponerMin: Int = 10
    /// "HH:mm" — hora tope del día siguiente para cerrar solo los
    /// turnos que quedaron abiertos.
    var cierreAuto: String = "04:00"

    // MARK: Solo iOS
    /// Copiar turnos y días de cobro al Calendario del iPhone
    var calendarioSync: Bool = false
    /// Aviso la mañana del día de cobro
    var avisoCobro: Bool = true
    /// Actividad en Vivo (pantalla de bloqueo / Dynamic Island)
    var actividadEnVivo: Bool = true
    /// Aviso al llegar a un trabajo con ubicación guardada
    var avisoLlegada: Bool = true
    /// Aviso cuando un trabajo se acerca a la hora extra de la semana
    var avisoHoraExtra: Bool = true
    /// Preguntar las propinas al marcar salida
    var preguntarPropinas: Bool = true

    /// Con varias cuentas: avisar también de los turnos y cobros de
    /// las cuentas que no están en uso.
    var avisosTodasCuentas: Bool = false

    // MARK: Perfil
    /// País (código ISO de 2 letras) y moneda (código ISO)
    var pais: String = "US"
    var moneda: String = "USD"
    /// % de impuestos que se propone al crear un trabajo nuevo
    var taxDefault: Double = 0
}

extension Settings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        idioma = c.val(.idioma, d.idioma)
        nombreUsuario = c.val(.nombreUsuario, d.nombreUsuario)
        diaCobro = c.val(.diaCobro, d.diaCobro)
        avisosMin = c.val(.avisosMin, d.avisosMin)
        umbralExtraHrs = c.val(.umbralExtraHrs, d.umbralExtraHrs)
        multExtra = c.val(.multExtra, d.multExtra)
        metaSemanal = c.val(.metaSemanal, d.metaSemanal)
        mostrarMeta = c.val(.mostrarMeta, d.mostrarMeta)
        mostrarHoraExtra = c.val(.mostrarHoraExtra, d.mostrarHoraExtra)
        terminosAceptados = c.val(.terminosAceptados, d.terminosAceptados)
        dineroOculto = c.val(.dineroOculto, d.dineroOculto)
        dark = c.val(.dark, d.dark)
        pin = c.opt(.pin)
        biometrico = c.val(.biometrico, d.biometrico)
        formatoHora = c.val(.formatoHora, d.formatoHora)
        onboardingDone = c.val(.onboardingDone, d.onboardingDone)
        sonidoAlarma = c.val(.sonidoAlarma, d.sonidoAlarma)
        posponerMin = c.val(.posponerMin, d.posponerMin)
        cierreAuto = c.val(.cierreAuto, d.cierreAuto)
        calendarioSync = c.val(.calendarioSync, d.calendarioSync)
        avisoCobro = c.val(.avisoCobro, d.avisoCobro)
        actividadEnVivo = c.val(.actividadEnVivo, d.actividadEnVivo)
        avisoLlegada = c.val(.avisoLlegada, d.avisoLlegada)
        avisoHoraExtra = c.val(.avisoHoraExtra, d.avisoHoraExtra)
        preguntarPropinas = c.val(.preguntarPropinas, d.preguntarPropinas)
        avisosTodasCuentas = c.val(.avisosTodasCuentas, d.avisosTodasCuentas)
        pais = c.val(.pais, d.pais)
        moneda = c.val(.moneda, d.moneda)
        taxDefault = c.val(.taxDefault, d.taxDefault)
    }
}

/// Lo que realmente pagó un trabajo en un día de cobro, para
/// compararlo con lo que calculó Turniq.
struct Paycheck: Codable, Identifiable, Equatable {
    var id: String
    var jobId: String
    /// Día de cobro "YYYY-MM-DD"
    var payday: String
    /// Neto recibido en el cheque
    var recibido: Double
}

extension Paycheck {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UUID().uuidString)
        jobId = c.val(.jobId, "")
        payday = c.val(.payday, "")
        recibido = c.val(.recibido, 0)
    }
}

/// Una cuenta: un país con su moneda y SUS propios trabajos, turnos y
/// cheques. Cada cuenta se guarda en su propio archivo, así los datos
/// de un país nunca se mezclan con los de otro.
struct Account: Codable, Identifiable, Equatable {
    var id: String
    /// Nombre propio; nil = el nombre del país
    var nombre: String?
    var pais: String
    var moneda: String

    var displayName: String { nombre ?? Countries.country(pais).name }
}

struct AccountIndex: Codable {
    var activeId: String
    var accounts: [Account]
}

/// Respaldo de TODAS las cuentas en un solo archivo.
struct AccountsBackup: Codable {
    struct Entry: Codable {
        var cuenta: Account
        var datos: TurniqData
    }
    var turniqCuentas: Int
    var exportedAt: String
    var activeId: String
    var cuentas: [Entry]
}

/// Documento raíz persistido (JSON en Documents/turniq-v1.json).
/// Mismo formato que el respaldo de Android (version/exportedAt se
/// escriben para que Android lo reconozca al importarlo).
struct TurniqData: Codable {
    var version: Int = 1
    var exportedAt: String = ""
    var jobs: [Job] = []
    var shifts: [Shift] = []
    var templates: [ShiftTemplate] = []
    var settings: Settings = Settings()
    /// Cheques anotados (solo iOS por ahora)
    var cheques: [Paycheck] = []
}

extension TurniqData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.val(.version, 1)
        exportedAt = c.val(.exportedAt, "")
        jobs = c.val(.jobs, [])
        shifts = c.val(.shifts, [])
        templates = c.val(.templates, [])
        settings = c.val(.settings, Settings())
        cheques = c.val(.cheques, [])
    }
}
