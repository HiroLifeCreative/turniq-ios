import Foundation

// MARK: - País y moneda
// El país del perfil decide la moneda (símbolo, decimales y forma de
// escribir los números) y propone valores de hora extra habituales en
// ese país. Son sugerencias: cada contrato puede ser distinto y todo
// se puede cambiar después en Ajustes.

struct Country: Identifiable, Equatable {
    /// Código ISO de 2 letras ("US"); "ZZ" = otro país
    var code: String
    var flag: String
    var es: String
    var en: String
    /// Código ISO de la moneda ("USD")
    var currency: String
    /// Idioma/región para separar miles y decimales
    var locale: String
    /// Horas semanales después de las cuales suele empezar la hora
    /// extra, y su recargo. nil = sin sugerencia (varía demasiado).
    var otHours: Double? = nil
    var otMult: Double? = nil

    var id: String { code }
    var name: String { Lang.en ? en : es }
}

struct Currency: Identifiable, Equatable {
    var code: String
    var symbol: String
    var decimals: Int
    var es: String
    var en: String

    var id: String { code }
    var name: String { Lang.en ? en : es }
}

enum Countries {

    static let currencies: [Currency] = [
        Currency(code: "USD", symbol: "$", decimals: 2, es: "Dólar estadounidense", en: "US dollar"),
        Currency(code: "EUR", symbol: "€", decimals: 2, es: "Euro", en: "Euro"),
        Currency(code: "MXN", symbol: "$", decimals: 2, es: "Peso mexicano", en: "Mexican peso"),
        Currency(code: "CAD", symbol: "$", decimals: 2, es: "Dólar canadiense", en: "Canadian dollar"),
        Currency(code: "COP", symbol: "$", decimals: 0, es: "Peso colombiano", en: "Colombian peso"),
        Currency(code: "ARS", symbol: "$", decimals: 2, es: "Peso argentino", en: "Argentine peso"),
        Currency(code: "CLP", symbol: "$", decimals: 0, es: "Peso chileno", en: "Chilean peso"),
        Currency(code: "PEN", symbol: "S/", decimals: 2, es: "Sol peruano", en: "Peruvian sol"),
        Currency(code: "DOP", symbol: "RD$", decimals: 2, es: "Peso dominicano", en: "Dominican peso"),
        Currency(code: "VES", symbol: "Bs.", decimals: 2, es: "Bolívar venezolano", en: "Venezuelan bolívar"),
        Currency(code: "GTQ", symbol: "Q", decimals: 2, es: "Quetzal guatemalteco", en: "Guatemalan quetzal"),
        Currency(code: "HNL", symbol: "L", decimals: 2, es: "Lempira hondureño", en: "Honduran lempira"),
        Currency(code: "NIO", symbol: "C$", decimals: 2, es: "Córdoba nicaragüense", en: "Nicaraguan córdoba"),
        Currency(code: "CRC", symbol: "₡", decimals: 0, es: "Colón costarricense", en: "Costa Rican colón"),
        Currency(code: "BOB", symbol: "Bs", decimals: 2, es: "Boliviano", en: "Bolivian boliviano"),
        Currency(code: "PYG", symbol: "₲", decimals: 0, es: "Guaraní paraguayo", en: "Paraguayan guaraní"),
        Currency(code: "UYU", symbol: "$", decimals: 2, es: "Peso uruguayo", en: "Uruguayan peso"),
        Currency(code: "BRL", symbol: "R$", decimals: 2, es: "Real brasileño", en: "Brazilian real"),
        Currency(code: "GBP", symbol: "£", decimals: 2, es: "Libra esterlina", en: "Pound sterling"),
        Currency(code: "AUD", symbol: "$", decimals: 2, es: "Dólar australiano", en: "Australian dollar"),
        Currency(code: "JPY", symbol: "¥", decimals: 0, es: "Yen japonés", en: "Japanese yen"),
        Currency(code: "KRW", symbol: "₩", decimals: 0, es: "Won surcoreano", en: "South Korean won"),
        Currency(code: "INR", symbol: "₹", decimals: 2, es: "Rupia india", en: "Indian rupee"),
        Currency(code: "PHP", symbol: "₱", decimals: 2, es: "Peso filipino", en: "Philippine peso"),
    ]

    static let all: [Country] = [
        Country(code: "US", flag: "🇺🇸", es: "Estados Unidos", en: "United States", currency: "USD", locale: "en_US", otHours: 40, otMult: 1.5),
        Country(code: "PR", flag: "🇵🇷", es: "Puerto Rico", en: "Puerto Rico", currency: "USD", locale: "en_US", otHours: 40, otMult: 1.5),
        Country(code: "MX", flag: "🇲🇽", es: "México", en: "Mexico", currency: "MXN", locale: "es_MX", otHours: 48, otMult: 2),
        Country(code: "CA", flag: "🇨🇦", es: "Canadá", en: "Canada", currency: "CAD", locale: "en_CA", otHours: 40, otMult: 1.5),
        Country(code: "ES", flag: "🇪🇸", es: "España", en: "Spain", currency: "EUR", locale: "es_ES"),
        Country(code: "CO", flag: "🇨🇴", es: "Colombia", en: "Colombia", currency: "COP", locale: "es_CO", otHours: 42, otMult: 1.25),
        Country(code: "AR", flag: "🇦🇷", es: "Argentina", en: "Argentina", currency: "ARS", locale: "es_AR", otHours: 48, otMult: 1.5),
        Country(code: "CL", flag: "🇨🇱", es: "Chile", en: "Chile", currency: "CLP", locale: "es_CL", otHours: 42, otMult: 1.5),
        Country(code: "PE", flag: "🇵🇪", es: "Perú", en: "Peru", currency: "PEN", locale: "es_PE", otHours: 48, otMult: 1.25),
        Country(code: "DO", flag: "🇩🇴", es: "República Dominicana", en: "Dominican Republic", currency: "DOP", locale: "es_DO", otHours: 44, otMult: 1.35),
        Country(code: "VE", flag: "🇻🇪", es: "Venezuela", en: "Venezuela", currency: "VES", locale: "es_VE", otHours: 40, otMult: 1.5),
        Country(code: "EC", flag: "🇪🇨", es: "Ecuador", en: "Ecuador", currency: "USD", locale: "es_EC", otHours: 40, otMult: 1.5),
        Country(code: "GT", flag: "🇬🇹", es: "Guatemala", en: "Guatemala", currency: "GTQ", locale: "es_GT", otHours: 44, otMult: 1.5),
        Country(code: "HN", flag: "🇭🇳", es: "Honduras", en: "Honduras", currency: "HNL", locale: "es_HN", otHours: 44, otMult: 1.25),
        Country(code: "SV", flag: "🇸🇻", es: "El Salvador", en: "El Salvador", currency: "USD", locale: "es_SV", otHours: 44, otMult: 2),
        Country(code: "NI", flag: "🇳🇮", es: "Nicaragua", en: "Nicaragua", currency: "NIO", locale: "es_NI", otHours: 48, otMult: 2),
        Country(code: "CR", flag: "🇨🇷", es: "Costa Rica", en: "Costa Rica", currency: "CRC", locale: "es_CR", otHours: 48, otMult: 1.5),
        Country(code: "PA", flag: "🇵🇦", es: "Panamá", en: "Panama", currency: "USD", locale: "es_PA", otHours: 48, otMult: 1.25),
        Country(code: "BO", flag: "🇧🇴", es: "Bolivia", en: "Bolivia", currency: "BOB", locale: "es_BO", otHours: 48, otMult: 2),
        Country(code: "PY", flag: "🇵🇾", es: "Paraguay", en: "Paraguay", currency: "PYG", locale: "es_PY", otHours: 48, otMult: 1.5),
        Country(code: "UY", flag: "🇺🇾", es: "Uruguay", en: "Uruguay", currency: "UYU", locale: "es_UY", otHours: 44, otMult: 2),
        Country(code: "BR", flag: "🇧🇷", es: "Brasil", en: "Brazil", currency: "BRL", locale: "pt_BR", otHours: 44, otMult: 1.5),
        Country(code: "GB", flag: "🇬🇧", es: "Reino Unido", en: "United Kingdom", currency: "GBP", locale: "en_GB"),
        Country(code: "FR", flag: "🇫🇷", es: "Francia", en: "France", currency: "EUR", locale: "fr_FR", otHours: 35, otMult: 1.25),
        Country(code: "DE", flag: "🇩🇪", es: "Alemania", en: "Germany", currency: "EUR", locale: "de_DE"),
        Country(code: "IT", flag: "🇮🇹", es: "Italia", en: "Italy", currency: "EUR", locale: "it_IT"),
        Country(code: "PT", flag: "🇵🇹", es: "Portugal", en: "Portugal", currency: "EUR", locale: "pt_PT"),
        Country(code: "AU", flag: "🇦🇺", es: "Australia", en: "Australia", currency: "AUD", locale: "en_AU", otHours: 38, otMult: 1.5),
        Country(code: "JP", flag: "🇯🇵", es: "Japón", en: "Japan", currency: "JPY", locale: "ja_JP", otHours: 40, otMult: 1.25),
        Country(code: "KR", flag: "🇰🇷", es: "Corea del Sur", en: "South Korea", currency: "KRW", locale: "ko_KR", otHours: 40, otMult: 1.5),
        Country(code: "IN", flag: "🇮🇳", es: "India", en: "India", currency: "INR", locale: "en_IN"),
        Country(code: "PH", flag: "🇵🇭", es: "Filipinas", en: "Philippines", currency: "PHP", locale: "en_PH"),
        Country(code: "ZZ", flag: "🌍", es: "Otro país", en: "Other country", currency: "USD", locale: "en_US"),
    ]

    static func country(_ code: String) -> Country {
        all.first { $0.code == code } ?? all[0]
    }

    static func currency(_ code: String) -> Currency {
        currencies.first { $0.code == code } ?? currencies[0]
    }
}

/// Moneda en uso. La actualiza Store cada vez que cambian los ajustes,
/// igual que el idioma.
enum Money {
    static private(set) var symbol = "$"
    static private(set) var decimals = 2
    static private(set) var code = "USD"
    static private(set) var localeID = "en_US"
    private static var formatter = makeFormatter()

    private static func makeFormatter() -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: localeID)
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f
    }

    static func apply(_ settings: Settings) {
        let c = Countries.currency(settings.moneda)
        let country = Countries.country(settings.pais)
        guard c.symbol != symbol || c.decimals != decimals || c.code != code
                || country.locale != localeID else { return }
        symbol = c.symbol
        decimals = c.decimals
        code = c.code
        localeID = country.locale
        formatter = makeFormatter()
    }

    /// Solo el número, con los separadores del país: "1,234.56"
    static func number(_ n: Double) -> String {
        formatter.string(from: NSNumber(value: abs(n))) ?? String(format: "%.\(decimals)f", abs(n))
    }

    /// Símbolo + número: "$1,234.56", "S/ 1,234.50", "€1.234,56"
    static func format(_ n: Double) -> String {
        let gap = (symbol.last.map { $0.isLetter || $0 == "/" || $0 == "." } ?? false) ? " " : ""
        return (n < 0 ? "-" : "") + symbol + gap + number(n)
    }
}
