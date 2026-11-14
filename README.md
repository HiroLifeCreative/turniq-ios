# Turniq para iOS (nativa, SwiftUI)

La versión iPhone de Turniq, escrita en Swift puro como paquete
SwiftPM — el formato que **xtool** compila, firma e instala sin Mac.
Mismo modelo de datos y mismas reglas que la app de Android:

- Totales SOLO de turnos ya trabajados (criterio global).
- **Horas extra POR TRABAJO**: el umbral semanal se aplica a cada
  empleo por separado, con su sueldo y su impuesto.
- PIN de reloj por trabajo (opcional): se muestra al marcar entrada
  y en el recordatorio del próximo turno.
- Turnos que cruzan medianoche (+1 día), plantillas en el modelo,
  respaldo JSON compatible con el de Android.

## Estado (v1.4.2, 14 nov 2026)

**Ícono de la app:** `Assets/AppIcon.png` (1024×1024, el mismo de
Android). xtool lo empaqueta con `iconPath` en `xtool.yml`.
`Info.plist` (fusionado con `infoPath`) trae el nombre, la versión y
los textos de permiso de Face ID y Calendario.

**Diseño igualado con Android** (mismos tokens de `src/theme/tokens.ts`):
banda oscura con el título de cada pantalla y el engranaje, hoja
redondeada (radio 28), dock flotante de vidrio con píldora azul y
rebote del ícono, tarjetas claras con degradado/borde/sombra y
tarjetas oscuras teñidas, modo claro y oscuro.

- **Inicio:** héroe de neto trabajado con ojito (ocultar dinero),
  píldora de estado, reloj en vivo con anillo y neto estimado, chips
  de horas/bruto/taxes, marcar entrada/salida, editar entrada, tarjeta
  de recordatorio con cuenta atrás y PIN, próximos cobros, próximos
  turnos.
- **Semana:** columna del día, tarjetas con barra de estado (en curso,
  no marcado, próximamente, pasado), aviso de traslape, hora extra por
  trabajo, total semanal, duplicar semana.
- **Trabajos:** tarjetas con Editar/Eliminar, estaciones, PIN del
  reloj y **Cobro** (cada semana o cada 2 semanas).
- **Ganancias:** trabajado vs programado, meta semanal, próximos
  cobros, totales del mes, por año, por trabajo.
- **Más:** Ajustes, Calendario del iPhone, Novedades.

**Funciones propias de iOS**

- **Cobro por trabajo** (`PaySchedule.swift`): cada trabajo paga
  `semanal` o `quincenal` (cada 14 días desde una fecha de cobro
  conocida) y tiene su espera `pagoRetraso`: 1 = se cobra en la
  semana siguiente (trabajo 2–8 nov → viernes 13), 2 = pasan 2
  semanas (2–8 nov → viernes 20). El periodo pagado siempre son
  semanas lun–dom completas. Campos nuevos y opcionales en `Job`:
  `pagoFrecuencia`, `pagoDia`, `pagoAncla`, `pagoRetraso` (un
  respaldo con ellos se importa en Android sin problema; Android
  todavía no los muestra).
- **Calendario del iPhone** (`CalendarSync.swift`, EventKit): turnos y
  días de cobro en un calendario propio «Turniq», de 7 días atrás a 60
  adelante; se actualiza solo con cada cambio.
- **Aviso del día de cobro** a las 9:00 a. m.

**Nuevo en 1.4.2**

- **Avisos de todas las cuentas** (`Settings.avisosTodasCuentas`,
  Ajustes → Avisos de turno, visible con más de una cuenta): apagado,
  solo avisa de la cuenta en uso; encendido, también de las demás, con
  la bandera del país en el título. Los montos del aviso de cobro solo
  se escriben para la cuenta en uso.
- **Respaldo de una cuenta o de todas**: al exportar con varias
  cuentas se pregunta. El de todas (`AccountsBackup`) se importa
  repartiendo cada cuenta en la suya o creándola si no existe.
- La copia automática diaria guarda todas las cuentas.

**Nuevo en 1.4.1**

- **Cuentas por país** (`Account`, `Store.switchAccount`,
  `createAccount`, `deleteAccount`): cada cuenta es un país con su
  moneda y su propio archivo de datos (`turniq-v1.json` para la
  principal, `turniq-cuenta-<id>.json` para las demás; el índice está
  en `turniq-cuentas.json`). Al cambiar de cuenta se cargan sus
  trabajos, turnos, plantillas y cheques; el nombre, idioma, PIN y
  avisos son comunes. Lo propio de la cuenta: país, moneda, impuestos
  por defecto, hora extra, meta semanal y día de cobro.
- El país y la moneda de una cuenta quedan fijos cuando tiene trabajos
  o turnos (`Store.accountLocked`); para otro país se crea otra cuenta.
- El calendario, el widget y la Actividad en Vivo trabajan con la
  cuenta en uso.

**Nuevo en 1.4.0**

- **Perfil con país y moneda** (`Country.swift`, `ProfileView.swift`):
  33 países con su moneda (símbolo, decimales y separadores) y, donde
  hay un valor habitual, horas semanales y recargo de hora extra
  sugeridos. `Money` guarda la moneda en uso y `Calc.money` la aplica
  en toda la app, el PDF, el widget y la Actividad en Vivo. Cambiar la
  moneda no convierte montos. Campos nuevos en `Settings`: `pais`,
  `moneda`, `taxDefault` (% que se propone en trabajos nuevos).
  Los valores de hora extra por país son orientativos y conviene
  verificarlos antes de publicar.
- **Más** rediseñada: tarjeta de perfil con resumen del año y opciones
  agrupadas (Dinero, Herramientas, Turniq) con ícono de color y
  descripción.
- **Bienvenida por pasos** (`OnboardingView.swift`): Inicio (idioma y
  términos), País, Perfil, Trabajo y Listo, con indicador de pasos y
  botón de volver.

**Nuevo en 1.3.0**

- **Comparar cheques** (`PaychecksView.swift`, Más → Comparar
  cheques): se anota el neto recibido en cada día de cobro y se
  compara con lo calculado. Se guarda en `cheques` del documento.
- **Tarifas especiales** (`Calc.rate`, `Calc.multiplier`,
  `Calc.nightHours`): sueldo propio por estación
  (`Station.sueldoHora`), extra nocturno por hora entre 10 p. m. y
  6 a. m. (`Job.nocturnoExtra`) y pago ×1.5 / ×2 por turno
  (`Shift.multiplicador`). El recargo de hora extra usa la tarifa
  promedio de la semana en ese trabajo; con una sola tarifa el
  resultado es el mismo de antes. Android todavía no lee estos campos.
- **Aviso de hora extra**: tarjeta en Inicio y notificación al empezar
  el turno con el que un trabajo llega a 4 h o menos del umbral.
- **Resumen anual** (`AnnualSummary.swift`): por trabajo y por mes,
  con exportación a PDF.
- **Propinas**: se preguntan al marcar salida; Ganancias muestra el
  promedio por día de la semana.
- **Compartir semana** (`WeekShare.swift`): imagen del horario, sin
  montos.
- **Bienvenida** (`OnboardingView.swift`): idioma, aceptación de
  términos, nombre y primer trabajo. Se muestra una vez, también a
  quien ya tenía datos.
- **Términos y privacidad**: `tools/legal.py` es la fuente única y
  genera `Sources/Turniq/LegalContent.swift` (pantalla en Más) y las
  páginas `docs/terms.html` y `docs/privacy.html` para publicarlas en
  una URL (App Store Connect pide la de privacidad).

**Herramientas** (`tools/`, requieren `pip install tree-sitter
tree-sitter-swift`): `i18n_table.py` + `i18n_wrap.py` (traducciones y
`Lang.swift`), `legal.py` (textos legales) y `syntax_check.py`.

**Nuevo en 1.2.3**

- **Exportar respaldo** usa la hoja de Compartir de iOS con el archivo
  ya escrito (antes un selector de documentos que podía salir en
  blanco). **Importar** también funciona con «Abrir en Turniq» sobre
  un `.json` desde Archivos u otra app.

**Nuevo en 1.2.2**

- **Detalle del turno** (`ShiftDetailSheet.swift`): mantener pulsada
  una tarjeta de turno en Semana (o ⋮ → Ver detalles) abre una hoja
  con horario programado y real, horas, dinero estimado, PIN del
  reloj, estaciones, notas y el día en que se cobra ese turno.
- **Dock**: velo del color de la tarjeta sobre el vidrio para que los
  íconos se lean también al pasar sobre tarjetas oscuras.
- **Widget y firma**: el widget necesita que la app se instale con el
  grupo de apps. `xtool dev` / `xtool install` lo registran; otras
  herramientas de firma pueden quitarlo, y entonces Más → Atajos, Siri
  y Widgets muestra «Sin conexión» con `perfil: sin grupos`.

**Nuevo en 1.2.1**

- **Inglés y español** (`Lang.swift`): los textos están en español en
  el código y `L("…")` devuelve su traducción cuando el idioma es
  inglés (Ajustes → Apariencia → Idioma). La tabla `enStrings` va de
  español a inglés; si falta una clave se muestra el español. Las
  interpolaciones se conservan (`L("Hola, \(nombre)")` busca
  `"Hola, %@"`). El widget y la Actividad en Vivo reciben el idioma
  en sus datos.
- **Widget sin datos («Abre Turniq»)**: el grupo de apps ya no se
  adivina con una sola regla. `AppGroup` prueba, en orden, los grupos
  que concede el perfil de firma (`embedded.mobileprovision`),
  `group.` + id de la app y el id declarado, y usa el primero que
  exista. Más → Atajos, Siri y Widgets muestra el estado y los
  identificadores para diagnosticar.

**Nuevo en 1.2.0**

- **Widgets** (`Sources/TurniqWidget`, extensión declarada en
  `xtool.yml`): Home pequeño/mediano y pantalla de bloqueo, con el
  próximo turno y su PIN, el neto de la semana y el próximo cobro.
  La app escribe una foto de datos (`WidgetSnapshot`, en
  `Sources/TurniqShared`) en la carpeta del grupo de apps
  (`Turniq.entitlements`); el id del grupo se calcula al vuelo como
  `group.` + id de la app porque xtool le antepone su prefijo al
  firmar. Si la app se firma sin el grupo, todo sigue funcionando y
  el widget muestra «Abre Turniq».
- **Actividad en Vivo / Dynamic Island** (`ShiftLiveActivity.swift`,
  `LiveShift`): contador del turno en curso, barra hacia la salida
  programada, neto por hora y PIN. Se inicia al marcar entrada.
- **Atajos, Siri y Botón de Acción** con enlaces: `turniq://marcar`,
  `turniq://entrada`, `turniq://salida` (acción «Abrir URL» en la app
  Atajos; instrucciones en Más → Atajos, Siri y Widgets). No usa App
  Intents porque xtool no genera sus metadatos.
- **Aviso al llegar al trabajo** (`Arrival.swift`): cada trabajo puede
  guardar su ubicación; con turno pendiente, una notificación por
  zona ofrece «Marcar entrada».
- **Respaldo automático** diario en Documentos/Respaldos (visible en
  Archivos; últimas 14 copias).

No disponible con xtool o con firma gratuita: app de Apple Watch
(xtool solo empaqueta iOS) y sincronización por iCloud (requiere el
Apple Developer Program).

**Datos:** lectura tolerante (campos que falten toman su valor por
defecto), horas reales y fechas de salida explícitas como Android,
cierre automático de turnos abiertos, respaldo JSON en el formato de
Android (`version`, `exportedAt`).

**Verificación:** sintaxis comprobada con un parser de Swift en los
todos los archivos. Falta la primera compilación real con `xtool dev`.

Pendiente: Plantillas, reportes PDF/CSV, calendario
mensual, Estadísticas.

**Nota iOS:** Apple no permite alarmas a pantalla completa de
terceros; los avisos son notificaciones con sonido.

## Compilar con xtool

```sh
xtool setup     # instala el SDK de Darwin (pide el Xcode.xip)
xtool auth      # TU Apple ID — solo el dueño firma
xtool dev       # compila, firma e instala en el iPhone conectado
```

Firma gratuita: la app vence a los 7 días (reinstalar). Con Apple
Developer Program ($99/año): firma de 1 año y TestFlight sin
cables, subiendo con la API key de App Store Connect.
