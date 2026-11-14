import Foundation

// GENERADO por tools/legal.py — no editar a mano.
// Términos y condiciones + Política de privacidad (español e inglés).

struct LegalSection: Identifiable {
    let id: Int
    let title: String
    let body: [String]
}

enum Legal {
    static var updated: String { Lang.en ? "Last updated: November 14, 2026" : "Última actualización: 14 de noviembre de 2026" }
    static var terms: [LegalSection] { Lang.en ? termsEN : termsES }
    static var privacy: [LegalSection] { Lang.en ? privacyEN : privacyES }

    private static let termsES: [LegalSection] = [
        LegalSection(id: 0, title: "1. Aceptación de los términos", body: [
            "Al descargar, instalar o utilizar Turniq aceptas estos Términos y Condiciones en su totalidad. Si no estás de acuerdo con alguna parte, no utilices la aplicación.",
        ]),
        LegalSection(id: 1, title: "2. Tus datos se guardan en tu dispositivo", body: [
            "Turniq guarda tu información en tu dispositivo: trabajos, turnos, sueldos, estaciones, propinas, cheques anotados, ajustes y los respaldos que exportes. La aplicación no tiene servidores propios, no requiere cuenta ni registro, y no envía tu información al desarrollador ni a terceros.",
            "Esto significa que:",
            "• Si desinstalas la aplicación o borras sus datos, la información se pierde de forma permanente, salvo que tengas un respaldo.\n• Si cambias de teléfono, debes exportar tu respaldo desde Ajustes → Datos e importarlo en el nuevo dispositivo.\n• Turniq guarda una copia diaria en la carpeta de la app dentro de Archivos. Si tienes activada la copia de iCloud de tu iPhone, Apple la incluye en esa copia según sus propias condiciones.\n• Eres el único responsable de mantener tus propios respaldos.",
        ]),
        LegalSection(id: 2, title: "3. Privacidad", body: [
            "Turniq no recopila, no vende y no comparte datos personales. La aplicación no incluye analíticas, rastreadores ni publicidad de terceros. El detalle está en la Política de privacidad, que forma parte de estos términos.",
        ]),
        LegalSection(id: 3, title: "4. Uso de la aplicación", body: [
            "Turniq es una herramienta de registro personal de horarios y ganancias estimadas. Los cálculos de horas, ingresos, impuestos, horas extra, días de cobro, la comparación con tus cheques y el resumen anual son estimaciones basadas en los datos que tú introduces y no constituyen asesoría laboral, fiscal ni contable. Verifica siempre tus pagos reales con tu empleador.",
            "Te comprometes a utilizar la aplicación de forma lícita y a no intentar vulnerar su funcionamiento.",
        ]),
        LegalSection(id: 4, title: "5. «Invítame un café» (apoyos voluntarios)", body: [
            "La aplicación puede ofrecer apoyos voluntarios («Invítame un café») a través de compras dentro de la app de la App Store (iPhone) o de Google Play (Android). Son aportaciones únicas y voluntarias; no desbloquean funciones ni otorgan suscripción alguna. Los pagos los procesa Apple o Google y se rigen por sus políticas, incluidas las de reembolso.",
        ]),
        LegalSection(id: 5, title: "6. Disponibilidad y cambios", body: [
            "La aplicación se ofrece «tal cual» (as is), sin garantías de disponibilidad ininterrumpida ni de ausencia de errores. Podemos actualizar la aplicación y estos términos en cualquier momento; los cambios entrarán en vigor al publicar una nueva versión. El uso continuado de la aplicación después de un cambio implica la aceptación de los nuevos términos.",
        ]),
        LegalSection(id: 6, title: "7. Limitación de responsabilidad", body: [
            "En la máxima medida permitida por la ley, el desarrollador no será responsable por pérdidas de datos derivadas de la desinstalación, el borrado de datos del dispositivo, daños o fallos del equipo, ni por decisiones tomadas con base en las estimaciones que muestra la aplicación.",
        ]),
        LegalSection(id: 7, title: "8. Propiedad intelectual", body: [
            "Turniq, su nombre, diseño y código son propiedad de su desarrollador (HiroLifeCreative). Estos términos no te otorgan ningún derecho sobre la marca ni sobre el código fuente.",
        ]),
        LegalSection(id: 8, title: "9. Contacto", body: [
            "Si tienes preguntas sobre estos términos, puedes escribir a: nelsonherreraff@gmail.com",
        ]),
    ]

    private static let termsEN: [LegalSection] = [
        LegalSection(id: 0, title: "1. Acceptance of terms", body: [
            "By downloading, installing or using Turniq you accept these Terms and Conditions in full. If you do not agree with any part, please do not use the app.",
        ]),
        LegalSection(id: 1, title: "2. Your data is stored on your device", body: [
            "Turniq stores your information on your device: jobs, shifts, wages, stations, tips, recorded paychecks, settings and any backups you export. The app has no servers of its own, requires no account or sign-up, and does not send your information to the developer or to third parties.",
            "This means that:",
            "• If you uninstall the app or erase its data, your information is permanently lost unless you have a backup.\n• If you switch phones, you must export your backup from Settings → Data and import it on the new device.\n• Turniq saves a daily copy in the app's folder in Files. If iCloud Backup is turned on for your iPhone, Apple includes it in that backup under its own terms.\n• You are solely responsible for keeping your own backups.",
        ]),
        LegalSection(id: 2, title: "3. Privacy", body: [
            "Turniq does not collect, sell or share personal data. The app includes no analytics, trackers or third-party advertising. The details are in the Privacy Policy, which is part of these terms.",
        ]),
        LegalSection(id: 3, title: "4. Use of the app", body: [
            "Turniq is a personal tool for logging work schedules and estimated earnings. Calculations of hours, income, taxes, overtime, paydays, the comparison with your paychecks and the annual summary are estimates based on the data you enter and do not constitute employment, tax or accounting advice. Always verify your actual payments with your employer.",
            "You agree to use the app lawfully and not to attempt to compromise its operation.",
        ]),
        LegalSection(id: 4, title: "5. “Buy me a coffee” (voluntary tips)", body: [
            "The app may offer voluntary tips (“Buy me a coffee”) through in-app purchases on the App Store (iPhone) or Google Play (Android). They are one-time, voluntary contributions; they do not unlock features or grant any subscription. Payments are processed by Apple or Google and governed by their policies, including refund policies.",
        ]),
        LegalSection(id: 5, title: "6. Availability and changes", body: [
            "The app is provided “as is”, without guarantees of uninterrupted availability or absence of errors. We may update the app and these terms at any time; changes take effect when a new version is published. Continued use of the app after a change implies acceptance of the new terms.",
        ]),
        LegalSection(id: 6, title: "7. Limitation of liability", body: [
            "To the maximum extent permitted by law, the developer shall not be liable for data loss resulting from uninstalling the app, erasing device data, device damage or failure, nor for decisions made based on the estimates shown by the app.",
        ]),
        LegalSection(id: 7, title: "8. Intellectual property", body: [
            "Turniq, its name, design and code are the property of its developer (HiroLifeCreative). These terms grant you no rights over the brand or the source code.",
        ]),
        LegalSection(id: 8, title: "9. Contact", body: [
            "If you have questions about these terms, you can write to: nelsonherreraff@gmail.com",
        ]),
    ]

    private static let privacyES: [LegalSection] = [
        LegalSection(id: 0, title: "1. Resumen", body: [
            "Turniq no recopila datos personales. Todo lo que escribes se queda en tu dispositivo. No hay cuentas, analíticas, publicidad ni rastreadores, y el desarrollador no tiene acceso a tu información.",
        ]),
        LegalSection(id: 1, title: "2. Qué información guardas en la app", body: [
            "Tu nombre (opcional), tus trabajos con su sueldo, porcentaje de taxes, estaciones, PIN del reloj y ubicación (opcional); tus turnos con horas, propinas, bonos y notas; los cheques que anotes; y tus ajustes. Todo se guarda en el almacenamiento de la app en tu dispositivo.",
        ]),
        LegalSection(id: 2, title: "3. Permisos del dispositivo", body: [
            "Todos son opcionales y se pueden quitar en los Ajustes del iPhone:",
            "• Notificaciones: avisos de turno, de día de cobro y de hora extra. Se generan en tu dispositivo.\n• Calendario: si lo activas, Turniq crea un calendario propio llamado «Turniq» y copia ahí tus turnos y días de cobro. No lee los eventos de tus otros calendarios ni los modifica.\n• Ubicación: solo al tocar «Usar mi ubicación actual» para guardar dónde queda un trabajo. La coordenada se guarda en tu dispositivo y el aviso al llegar lo gestiona iOS. Turniq no rastrea tu ubicación ni la envía a nadie.\n• Face ID / Touch ID: lo gestiona iOS; Turniq solo recibe si el desbloqueo fue correcto, nunca tus datos biométricos.\n• Archivos y Compartir: solo cuando tú exportas un respaldo, un PDF o una imagen de tu semana.",
        ]),
        LegalSection(id: 3, title: "4. Servicios de terceros", body: [
            "Turniq no incluye componentes de terceros que recopilen datos. Algunas funciones usan servicios de Apple bajo la política de privacidad de Apple: la copia de iCloud de tu iPhone (si la tienes activada), la sincronización de tu Calendario (si tu cuenta lo sincroniza) y las compras de «Invítame un café» en la App Store. En Android, la conexión opcional con Google Calendar o Gmail se realiza directamente entre tu dispositivo y tu cuenta de Google.",
        ]),
        LegalSection(id: 4, title: "5. Conservación y borrado", body: [
            "Tus datos permanecen en tu dispositivo hasta que los borres. Puedes eliminarlos en Ajustes → Datos → Borrar todos los datos, o desinstalando la aplicación. El calendario «Turniq» se quita desde Más → Calendario del iPhone.",
        ]),
        LegalSection(id: 5, title: "6. Menores", body: [
            "Turniq no está dirigida a menores de 13 años y no recopila datos de ningún usuario.",
        ]),
        LegalSection(id: 6, title: "7. Cambios en esta política", body: [
            "Si esta política cambia, la nueva versión se publicará con una actualización de la aplicación y con una nueva fecha.",
        ]),
        LegalSection(id: 7, title: "8. Contacto", body: [
            "Para cualquier pregunta sobre privacidad, escribe a: nelsonherreraff@gmail.com",
        ]),
    ]

    private static let privacyEN: [LegalSection] = [
        LegalSection(id: 0, title: "1. Summary", body: [
            "Turniq does not collect personal data. Everything you enter stays on your device. There are no accounts, analytics, advertising or trackers, and the developer has no access to your information.",
        ]),
        LegalSection(id: 1, title: "2. What information you keep in the app", body: [
            "Your name (optional), your jobs with their wage, tax percentage, stations, time clock PIN and location (optional); your shifts with hours, tips, bonuses and notes; the paychecks you record; and your settings. All of it is stored in the app's storage on your device.",
        ]),
        LegalSection(id: 2, title: "3. Device permissions", body: [
            "All are optional and can be turned off in iPhone Settings:",
            "• Notifications: shift, payday and overtime reminders. They are generated on your device.\n• Calendar: if you turn it on, Turniq creates its own calendar called “Turniq” and copies your shifts and paydays there. It does not read the events in your other calendars or change them.\n• Location: only when you tap “Use my current location” to save where a job is. The coordinate is stored on your device and the arrival alert is handled by iOS. Turniq does not track your location or send it to anyone.\n• Face ID / Touch ID: handled by iOS; Turniq only learns whether the unlock succeeded, never your biometric data.\n• Files and Share: only when you export a backup, a PDF or an image of your week.",
        ]),
        LegalSection(id: 3, title: "4. Third-party services", body: [
            "Turniq includes no third-party components that collect data. Some features use Apple services under Apple's privacy policy: your iPhone's iCloud Backup (if turned on), Calendar sync (if your account syncs it) and “Buy me a coffee” purchases on the App Store. On Android, the optional connection to Google Calendar or Gmail happens directly between your device and your Google account.",
        ]),
        LegalSection(id: 4, title: "5. Retention and deletion", body: [
            "Your data stays on your device until you delete it. You can erase it in Settings → Data → Erase all data, or by uninstalling the app. The “Turniq” calendar is removed from More → iPhone Calendar.",
        ]),
        LegalSection(id: 5, title: "6. Children", body: [
            "Turniq is not directed at children under 13 and does not collect data from any user.",
        ]),
        LegalSection(id: 6, title: "7. Changes to this policy", body: [
            "If this policy changes, the new version will be published with an app update and a new date.",
        ]),
        LegalSection(id: 7, title: "8. Contact", body: [
            "For any privacy question, write to: nelsonherreraff@gmail.com",
        ]),
    ]
}
