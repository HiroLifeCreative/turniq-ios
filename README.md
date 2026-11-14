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

## Estado (v1.2.3, 14 nov 2026)

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
