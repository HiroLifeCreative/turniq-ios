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

## Estado (v1.1.0, 13 nov 2026)

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
  conocida). Un cobro paga las semanas lun–dom completas que
  terminaron antes de la semana del día de cobro. Campos nuevos y
  opcionales en `Job`: `pagoFrecuencia`, `pagoDia`, `pagoAncla` (un
  respaldo con ellos se importa en Android sin problema; Android
  todavía no los muestra).
- **Calendario del iPhone** (`CalendarSync.swift`, EventKit): turnos y
  días de cobro en un calendario propio «Turniq», de 7 días atrás a 60
  adelante; se actualiza solo con cada cambio.
- **Aviso del día de cobro** a las 9:00 a. m.

**Datos:** lectura tolerante (campos que falten toman su valor por
defecto), horas reales y fechas de salida explícitas como Android,
cierre automático de turnos abiertos, respaldo JSON en el formato de
Android (`version`, `exportedAt`).

**Verificación:** sintaxis comprobada con un parser de Swift en los
18 archivos. Falta la primera compilación real con `xtool dev`.

Pendiente: Widgets y Actividad en Vivo (requieren una extensión en
`xtool.yml` y un App Group), Plantillas, reportes PDF/CSV, calendario
mensual, Estadísticas, inglés.

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
