// swift-tools-version: 5.9
import PackageDescription

// Turniq para iOS — versión NATIVA en SwiftUI, gemela de la app de
// Android (React Native). Proyecto SwiftPM listo para compilar con
// xtool (Linux/Windows/macOS, sin Xcode) o con Xcode en una Mac.
// Mismo modelo de datos que la app de Android (fecha "YYYY-MM-DD",
// horas "HH:mm"), mismas reglas: totales SOLO de turnos trabajados
// y horas extra POR TRABAJO (umbral semanal por empleo, nunca la
// suma de todos).
let package = Package(
    name: "Turniq",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // xtool empaqueta la app a partir de un producto de tipo
        // LIBRERÍA (no ejecutable); el @main vive en TurniqApp.swift.
        .library(
            name: "Turniq",
            targets: ["Turniq"]
        ),
        // Extensión de Widgets + Actividad en Vivo (ver xtool.yml).
        .library(
            name: "TurniqWidget",
            targets: ["TurniqWidget"]
        ),
    ],
    targets: [
        // Tipos que comparten la app y la extensión.
        .target(
            name: "TurniqShared",
            path: "Sources/TurniqShared"
        ),
        .target(
            name: "TurniqWidget",
            dependencies: ["TurniqShared"],
            path: "Sources/TurniqWidget",
            // xtool arranca la extensión por _NSExtensionMain; sin esto el
            // enlazador descarta el @main del widget (y con él todo su
            // código) y el empaquetado falla con "Signing failed".
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-u", "-Xlinker", "_main"])
            ]
        ),
        .target(
            name: "Turniq",
            dependencies: ["TurniqShared"],
            path: "Sources/Turniq",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
