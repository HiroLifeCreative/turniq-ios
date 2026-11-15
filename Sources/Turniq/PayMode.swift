import Foundation

// MARK: - Forma de pago de un trabajo
// No en todos los países se cobra por hora. Cada trabajo tiene su
// forma de pago:
//   · hora  → horas trabajadas × sueldo por hora (EE. UU., Canadá…)
//   · dia   → días trabajados × salario diario, con séptimo día
//             opcional (México, jornales)
//   · fijo  → sueldo por semana, quincena o mes; cada día trabajado
//             vale su parte y las horas no cambian el pago
//   · turno → un monto por cada turno
// En los países donde la hora es el estándar (Country.hourlyOnly) solo
// existe «hora» y no se muestra el selector.

enum PayMode: String, CaseIterable, Identifiable {
    case hora, dia, fijo, turno

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hora: return L("Por hora")
        case .dia: return L("Por día")
        case .fijo: return L("Sueldo fijo")
        case .turno: return L("Por turno")
        }
    }
}

enum SalaryPeriod: String, CaseIterable, Identifiable {
    case semanal, quincenal, mensual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .semanal: return L("Por semana")
        case .quincenal: return L("Por quincena")
        case .mensual: return L("Por mes")
        }
    }

    /// Sufijo corto para "$1,200.00/mes"
    var unit: String {
        switch self {
        case .semanal: return L("sem")
        case .quincenal: return L("quincena")
        case .mensual: return L("mes")
        }
    }

    /// Equivalente mensual de un monto de este periodo.
    func monthly(_ amount: Double) -> Double {
        switch self {
        case .semanal: return amount * 52 / 12
        case .quincenal: return amount * 2
        case .mensual: return amount
        }
    }
}

extension Country {
    /// Países donde cobrar por hora es el estándar: no se ofrece otra
    /// forma de pago.
    var hourlyOnly: Bool { ["US", "PR", "CA", "GB", "AU"].contains(code) }

    /// Forma de pago que se propone al crear un trabajo.
    var defaultPayMode: PayMode {
        if hourlyOnly || code == "ZZ" { return .hora }
        return code == "MX" ? .dia : .fijo
    }
}

extension Job {
    var payMode: PayMode { PayMode(rawValue: pagoTipo ?? "") ?? .hora }
    var salaryPeriod: SalaryPeriod { SalaryPeriod(rawValue: pagoPeriodo ?? "") ?? .mensual }

    /// Monto de la forma de pago (por día, por turno o por periodo).
    var amount: Double { max(0, pagoMonto ?? 0) }

    /// Sueldo fijo llevado a un mes.
    var monthlyEquivalent: Double { salaryPeriod.monthly(amount) }

    /// Lo que vale un día trabajado en «dia» y «fijo».
    var dayValue: Double {
        switch payMode {
        case .dia: return amount
        case .fijo: return monthlyEquivalent * 12 / 52 / Double(max(1, diasSemana ?? 5))
        default: return 0
        }
    }

    /// Valor de una hora, para la hora extra y las estimaciones. En
    /// «turno» no hay base por hora.
    var hourlyValue: Double {
        switch payMode {
        case .hora: return sueldoHora
        case .dia: return amount / max(1, horasDia ?? 8)
        case .fijo: return monthlyEquivalent / max(1, horasMes ?? 173.33)
        case .turno: return 0
        }
    }

    /// "$17.00/h", "$300.00/día", "$1,200.00/mes", "$50.00/turno"
    var wageLabel: String {
        switch payMode {
        case .hora: return "\(Calc.money(sueldoHora))/h"
        case .dia: return "\(Calc.money(amount))/\(L("día"))"
        case .fijo: return "\(Calc.money(amount))/\(salaryPeriod.unit)"
        case .turno: return "\(Calc.money(amount))/\(L("turno"))"
        }
    }
}
