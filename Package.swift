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
        .executable(
            name: "Turniq",
            targets: ["Turniq"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Turniq",
            path: "Sources/Turniq",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
