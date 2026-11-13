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

## Estado (v1, 22 oct 2026)

Diseño igualado con Android: dock flotante de vidrio solo-íconos
con cápsula azul animada, banda superior oscura + hoja blanca
redondeada (radio 28), engranaje que abre Más, tipografía Roboto
bundleada (registro en tiempo de ejecución) y JetBrains Mono en
las etiquetas. Sintaxis verificada con swiftc 6.1.2 (parse).

Incluye: Inicio (héroe de neto trabajado, marcar entrada/salida,
próximo turno con su PIN), Semana (navegación, tarjeta de hora
extra por trabajo, duplicar semana), Trabajos (CRUD con estaciones
y PIN de reloj), Ganancias (trabajado vs programado, por trabajo,
totales del mes), Más/Ajustes (PIN de la app + Face ID, horas
extra, meta, exportar/importar respaldo), avisos por notificación
local.

Pendiente (fase 2): sincronización con Google Calendar/Gmail,
pantalla de Plantillas, reportes PDF/CSV, calendario mensual.

**Nota iOS:** Apple no permite alarmas a pantalla completa de
terceros; los avisos son notificaciones con sonido.

## Compilar con xtool

Para generar un IPA sin firma (xtool 1.24.0, con el SDK de iOS instalado):

```sh
xtool dev build --configuration release --ipa
```

El archivo se genera dentro de `xtool/`. Antes de instalarlo en un
iPhone hay que firmarlo con una cuenta de Apple mediante una herramienta
de instalación, como Sideloadly, o compilar con la opción `--sign` tras
configurar la cuenta en xtool.

```sh
xtool setup     # instala el SDK de Darwin (pide el Xcode.xip)
xtool auth      # TU Apple ID — solo el dueño firma
xtool dev       # compila, firma e instala en el iPhone conectado
```

Firma gratuita: la app vence a los 7 días (reinstalar). Con Apple
Developer Program ($99/año): firma de 1 año y TestFlight sin
cables, subiendo con la API key de App Store Connect.
