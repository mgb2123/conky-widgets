# Notas de diseño

Notas técnicas sobre cómo están construidos estos cinco widgets: qué se hizo,
por qué, y qué tener en cuenta si se editan. Pensadas como referencia propia
mientras se iteraba sobre la configuración — se conservan aquí porque
documentan decisiones concretas (medición de geometría de ventana, benchmarks
de rendimiento, un bug de kernel/driver diagnosticado y arreglado) que no son
obvias solo mirando los ficheros de config.

## Inventario

| Widget | Contenido | `gap_y` (top_right) |
|---|---|---|
| Gotham | Reloj, fecha, HD/RAM/CPU resumido | `20` |
| Temperatura | Temp. CPU (package + 4 núcleos), frecuencia, placa base (ACPI), SSD NVMe | `227` |
| Sistema | Red (subida/bajada + señal WiFi), disco `/`, GPU integrada, actualizaciones apt pendientes | `467` |
| Process Panel | % CPU/RAM global + barras + top 5 procesos por CPU y por RAM | `728` |
| Portfolio | Cartera de inversión: total + variación semanal por activo | `alignment bottom_left`, `gap_x 20` `gap_y 20` |

Los cuatro primeros comparten `gap_x 20` (borde derecho alineado entre sí) y
`alignment top_right`. Portfolio va en una columna aparte, esquina inferior
izquierda (`bottom_left`) — no cabía como 5º widget del stack de la derecha
(ver sección propia más abajo).

**Fuente y anchura**: Temperatura, Sistema y Process Panel (los 3 widgets
"stat", que comparten estilo idéntico) usan `xftfont Droid Sans:size=11` /
`minimum_size 210 0` — pensado para que valores de longitud variable (p. ej.
la velocidad de red pasando de `XXXB` a `1.234KiB`) no se corten ni fuercen
un redimensionado visible. Gotham (el reloj, con su propia fuente `GE
Inspira`) usa otra tipografía. Se probó `size=12` primero pero no cabía en
pantalla: con los 4 widgets apilados y el margen de 20 px entre ellos, el
alto total necesario superaba el área de trabajo disponible
(`_NET_WORKAREA`), lo que hacía que X clampara el último widget contra el
borde inferior de la pantalla y lo solapara con el de encima. **Si en el
futuro se quiere subir la fuente aún más, hay que volver a comprobar que la
suma de alturas + márgenes no supere `_NET_WORKAREA`** (comprobar con
`xprop -root _NET_WORKAREA`) — si no cabe, reducir el margen entre widgets
antes que renunciar al tamaño de fuente.

## Estructura de distribución elegida

Con 3 widgets se usaba un anclaje "arriba + centro + abajo"
(`top_right`/`middle_right`/`bottom_right`) para no depender de medir
alturas. Al añadir un 4º widget ya no cabían cómodamente 4 anclas fijas sin
riesgo de solape, así que se pasó a un **layout apilado medido**, con los
cuatro en `alignment top_right` y `gap_y` calculado así:

1. Lanzar cada widget y medir su altura real renderizada con
   `xwininfo -root -tree | grep '"conky (m-PC)"'` (da geometría `WxH+X+Y` de
   cada ventana).
2. Alturas medidas (con fuente `size=11` en los 3 widgets "stat"): Gotham
   171 px, Temperatura 220 px, Sistema 241 px, Process Panel 346 px.
3. `gap_y` de cada widget = `gap_y` del anterior + su altura + margen fijo
   (20 px). Orden de arriba a abajo: Gotham → Temperatura → Sistema →
   Process Panel (el más alto se deja al final para no arrastrar overflow si
   algún día crece más). **Cuidado**: si la suma total no cabe en
   `_NET_WORKAREA`, X clampa el último widget contra el borde inferior de la
   pantalla en vez de respetar el `gap_y` configurado, y lo solapa con el
   widget de arriba.
4. **Aviso importante**: el `gap_y` configurado no se traduce 1:1 en píxeles
   de pantalla — hay un offset de ventana/gestor de ventanas que varía
   (~±10 px) entre widgets. Los valores de la tabla de arriba ya están
   ajustados empíricamente (medidos con `xwininfo` tras cada cambio) para
   que el margen visual real sea ~20 px consistente entre los cuatro. **Si
   se edita el contenido de cualquiera de ellos (se añaden/quitan líneas)
   hay que volver a medir con `xwininfo` y reajustar el `gap_y` de los
   widgets que van *debajo*** — si no, se solapan o queda un hueco raro.
5. Verificación visual: captura de pantalla completa con
   `import -window root /tmp/check.png`.

## Decisiones de rendimiento (por qué no ralentiza el equipo)

Medido con `pidstat` sobre los 4 procesos del stack (12 muestras de 1 s):
**~1.0% de un núcleo en total** (Gotham 0.25%, Process Panel 0.50%, Sistema
0.08%, Temperatura 0.17%) y **~52 MB RAM** (RSS sumado), sobre un sistema de
8 núcleos / 15 GiB. Traducido a carga total del sistema: ~0.12% de la
capacidad de CPU y ~0.34% de la RAM — sigue siendo despreciable. Claves para
mantenerlo así en futuras ediciones:

1. **`update_interval` ≥ 1.0 s siempre.** Bajar de 1.0 s dispara el uso de
   CPU de Conky (reportado en foros de Arch/GitHub). Process Panel,
   Temperatura y Sistema están en `2.0`, Gotham en `1`.
2. **Evitar `${exec}` / `${execi}` cuando exista alternativa nativa.** El
   widget de Temperatura lee sensores vía `${hwmon <módulo> temp <n>}`
   directamente de `/sys/class/hwmon`, y el widget Sistema usa
   `${downspeed}`/`${upspeed}`/`${wireless_link_qual_perc}`/`${fs_*}` —
   todas nativas, **sin** lanzar procesos externos en cada refresco. Solo se
   recurre a `execi` con script propio cuando no existe variable nativa (ver
   sección de scripts): uso de GPU y actualizaciones pendientes de apt. Si
   se añade un dato nuevo, comprobar primero si Conky ya expone una
   variable nativa antes de recurrir a `exec`.
3. **`execi` con intervalo de cacheo generoso para lo que no es nativo.** El
   script de GPU se cachea cada `2` s (igual que el resto del widget) y su
   ejecución real dura ~0,45 s (dos lecturas de `/proc/*/fdinfo` separadas
   por 400 ms); además el propio script guarda su resultado 2 s en
   `$XDG_RUNTIME_DIR/conky_gpu_usage`, así que las 3 invocaciones que hace
   el widget por refresco (condición naranja, condición roja, valor
   mostrado) solo muestrean una vez. El de actualizaciones de apt se cachea
   cada `3600` s (1 h) porque `apt list --upgradable` es más pesado y no
   aporta nada consultarlo más a menudo. Conky cachea `execi` por
   combinación (intervalo, comando exacto) — repetir la misma llamada en la
   condición de color y en el valor mostrado no duplica la ejecución real
   del script.
4. **Transparencia "falsa", no compositor real.** `own_window_transparent
   yes` + `own_window_argb_visual no` capturan el fondo una vez, en vez de
   usar transparencia real vía Cairo/ARGB (que puede disparar el uso idle de
   ~3% a ~23% según reportes). Si en el futuro se quiere transparencia real,
   hay que asumir ese coste mayor a cambio.

## Mapeo de sensores usado (por si se reinicia o cambia hardware)

Descubierto vía `sensors` + `/sys/class/hwmon/*/name` y `temp*_label`. Los
nombres de módulo (`coretemp`, `nvme`, `acpitz`) son estables entre
reinicios; los números `hwmonN` **no** lo son necesariamente, por eso en la
config se usa el nombre del módulo y no el índice numérico:

| Variable Conky | Sensor real | Nota |
|---|---|---|
| `${hwmon coretemp temp 1}` | Package id 0 (CPU completo) | |
| `${hwmon coretemp temp 2..5}` | Core 0 / Core 1 / Core 2 / Core 3 | 4 núcleos físicos |
| `${hwmon nvme temp 1}` | Composite (SSD NVMe) | |
| `${hwmon acpitz temp 1}` | Zona térmica ACPI | Proxy de temperatura interna general del chasis/placa |

Sensores disponibles pero **no usados** (por si interesan más adelante):
- `iwlwifi` (temperatura del adaptador WiFi) — descartado por baja relevancia.
- RPM de ventilador — no expuesto por ACPI/hwmon en todo el hardware, no
  viable sin herramientas adicionales (p. ej. `asusctl`/`ec_probe`).
- Batería (`BAT0`, vía `upower`/`${battery_percent}`) — descartada
  explícitamente para el widget Sistema.

### Fuentes de datos del widget Sistema

| Variable/script | Qué muestra | Tipo |
|---|---|---|
| `${downspeed <iface>}` / `${upspeed <iface>}` | Velocidad de red bajada/subida | Nativa |
| `${wireless_link_qual_perc <iface>}` | % de calidad de señal WiFi | Nativa (lee la API wireless del kernel, no invoca `nmcli`) |
| `${fs_used_perc /}`, `${fs_bar 6,150 /}`, `${fs_used /}`, `${fs_size /}` | % usado, barra y GB usados/total del disco `/` | Nativa |
| `scripts/gpu_usage.sh` | % de uso del motor Render/3D de la iGPU Intel | Script propio, vía `execi 2` (no hay variable nativa de Conky para GPU) |
| `scripts/apt_updates.sh` | Nº de paquetes `apt` pendientes de actualizar | Script propio, vía `execi 3600` |

**Nota sobre el nombre de interfaz**: la config usa el nombre real de la
interfaz WiFi del equipo (obtenido con `ip -br addr`). Si cambia el
adaptador de red o se reinstala el sistema, este nombre puede cambiar (los
nombres `wlXXX`/`enXXX` de systemd-networkd/udev dependen del hardware/bus)
— hay que comprobarlo con `ip -br addr` y actualizarlo en `sistema/conkyrc`.

## Cambios de sistema fuera de la config de Conky

Para el bloque de GPU del widget Sistema se hicieron en su día dos cambios
de sistema, no solo de configuración de Conky. Ambos quedaron obsoletos
cuando el script dejó de usar `intel_gpu_top` (ver sección siguiente); se
documentan porque en su momento formaron parte del proceso:

1. **`intel-gpu-tools`** — instala el binario `intel_gpu_top`, que expone en
   JSON (`-J`) el % de ocupación de los motores de la iGPU. Ya no lo usa
   ningún widget.
2. **`kernel.perf_event_paranoid` bajado de `4` a `2`**, vía
   `/etc/sysctl.d/60-perfmon-gpu-widget.conf`, porque `intel_gpu_top` lee
   contadores de rendimiento del kernel vía `perf_event_open()`. El método
   actual (`fdinfo`) **no usa `perf` en absoluto**, así que este
   relajamiento ya no le hace falta al widget.

### GPU (iGPU): del bug de `intel_gpu_top` a leer `/proc/*/fdinfo`

**El problema.** Con ambos cambios de sistema aplicados, `intel_gpu_top -J
-c 1` **seguía fallando**, y no por permisos — abortaba con:
```
intel_gpu_top: ../tools/intel_gpu_top.c:557: get_num_gts: Assertion `!errno || errno == ENOENT' failed.
Aborted (core dumped)
```
Es un **bug confirmado del paquete `intel-gpu-tools 1.28-1ubuntu2` de
Ubuntu 24.04**, reportado y sin resolver en Launchpad:
[Bug #2129174 "get_num_gts: assertion failed"](https://bugs.launchpad.net/ubuntu/+source/intel-gpu-tools/+bug/2129174).
`intel_gpu_top -L` (solo listar el dispositivo) **funciona** y detecta la
GPU; `-J -c 1` (muestreo JSON) y `-o - -c 1` (muestreo texto) crashean
igual. Es decir, el binario detecta la GPU pero se rompe al *muestrear* su
actividad.

**Efecto secundario que no se había previsto.** La decisión inicial fue
dejar el fallback a `0` y esperar a que Ubuntu publicase un paquete
corregido. Eso hacía que el widget mostrase `GPU (iGPU) 0%` fijo, pero
además **cada abort generaba un core dump que apport recogía**, disparando
el diálogo **"System program problem detected"** en cada inicio de sesión.
Como el widget llama al script con `execi 2` y tres veces por refresco (dos
condiciones de color + el valor), eran decenas de aborts por minuto.

Cómo se diagnosticó, por si vuelve a pasar con otro programa: `ls -la
/var/crash` (había un `.crash` para `intel_gpu_top`), `grep -a
'^ProcCmdline:' /var/crash/*.crash` (dio la línea exacta invocada por el
script), y `ps aux | grep apport` cazó en vivo la cadena completa
`conky → gpu_usage.sh → timeout → intel_gpu_top → apport`.

**Solución aplicada: leer `/proc/*/fdinfo` en vez de `intel_gpu_top`.** El
driver i915 expone, por cada cliente DRM y en el `fdinfo` de su descriptor,
un contador acumulado de nanosegundos ocupados por motor:
```
drm-driver:            i915
drm-client-id:         15
drm-engine-render:     182728 ns
drm-engine-copy:       0 ns
drm-engine-video:      0 ns
```
`gpu_usage.sh` toma dos muestras separadas por 400 ms, suma los nanosegundos
de **cada motor** (`render`, `copy`, `video`, `video-enhance`) sobre todos
los clientes, calcula `Δns / (400 ms) × 100` por motor y muestra **el motor
más ocupado**. Es el mismo mecanismo que usa `nvtop`. Detalles que importan
si se toca el script:

- **Deduplicar por `drm-client-id`**: un proceso puede tener el mismo
  cliente DRM abierto en varios descriptores (se vio con 3 fds apuntando al
  mismo `drm-client-id`), y contarlos todos multiplicaría el porcentaje. El
  script lleva una lista de ids ya vistos por muestra.
- **Sin `perf`, sin root, sin `jq`**: solo lectura de `/proc`, `sed` y
  `awk`. No puede crashear ni disparar apport.
- **Solo ve procesos del propio usuario** — `/proc/<pid>/fdinfo` de otros
  usuarios no es legible. En un equipo de un solo usuario es irrelevante.
- **Se mide el máximo de los motores, no solo Render/3D**: la primera
  versión solo miraba `drm-engine-render`, con lo que un vídeo decodificado
  por hardware —que corre en el motor `video`— habría seguido marcando
  `0%`. El máximo entre motores es lo que se percibe como "la GPU está
  ocupada"; **sumarlos sería incorrecto** porque pueden trabajar en paralelo
  y el total pasaría de 100%.
- **Motores con varias instancias**: si el `fdinfo` trae
  `drm-engine-capacity-<motor>: N`, el porcentaje de ese motor se divide
  entre `N`; si no, el máximo teórico sería `N × 100%`.
- **Si un cliente DRM termina entre las dos muestras**, el acumulado total
  baja y `t1 < t0`; el script detecta ese caso e imprime `0` en vez de un
  número negativo.
- La versión antigua basada en `intel_gpu_top` se conserva como referencia
  en el historial de commits.

**`0%` en reposo es el valor correcto, no un fallo.** En un entorno sin
compositor y sin apps aceleradas abiertas, la iGPU está genuinamente
ociosa. Para comprobar de un vistazo quién tiene la GPU abierta y cuánto
lleva acumulado:
```bash
for f in $(grep -ls '^drm-driver' /proc/[0-9]*/fdinfo/* 2>/dev/null); do
  pid=$(echo "$f" | cut -d/ -f3)
  echo "$(cat /proc/$pid/comm) $(sed -n 's/^drm-engine-render:[[:space:]]*//p' $f)"
done | sort -u
```

## Scripts propios (`scripts/`)

Carpeta con scripts auxiliares usados vía `execi` cuando no hay variable
nativa de Conky disponible. Deben imprimir **solo un número** (sin `%`, sin
texto, sin saltos de línea extra) para que los `${if_match}` del widget no
rompan la comparación:

- **`apt_updates.sh`**: `apt list --upgradable 2>/dev/null | tail -n +2 | wc -l`.
- **`gpu_usage.sh`**: toma dos muestras de los contadores `drm-engine-*`
  (ns) en `/proc/*/fdinfo` separadas 400 ms y calcula el % del motor más
  ocupado; devuelve `0` si no hay datos.

Convención para próximos scripts: mismo criterio — un único número por
salida, con `timeout` si el comando externo puede colgarse, y fallback
numérico (nunca texto vacío) si algo falla.

## Widget Portfolio (cartera de inversión)

Muestra datos generales de una cartera de inversión: valor total actual +
**variación de la última semana** (% y €), y debajo una línea de variación
semanal por cada activo.

**La composición está hardcodeada** en `scripts/portfolio_widget.sh`
(arrays `TICKERS`/`NAMES`/`QTYS`) — no lee ningún fichero de gestión de
cartera externo. Si compras/vendes algo, hay que editar esos arrays a mano.
En este repositorio los valores son de ejemplo; sustitúyelos por tu propia
cartera.

**Referencia temporal: variación semanal, no P&L desde compra.** El título
del widget dice `PORTFOLIO (7d)` precisamente para dejar claro qué periodo
mide — compara el precio actual contra el cierre de hace 7 días naturales,
no la rentabilidad total desde la compra.

### Fuente de datos: API pública de Yahoo Finance

`portfolio_widget.sh` hace una petición HTTP por ticker a
`https://query1.finance.yahoo.com/v8/finance/chart/<ticker>` (endpoint no
oficial, sin autenticación).

- Llamado vía `${execpi 300 ...}` (**no** `${execi}`): `execpi` es "exec
  parseado" — interpreta `${color ...}` dentro de la salida del script,
  necesario porque los colores verde/rojo de ganancia/pérdida se calculan
  dentro del script según el signo de la variación de cada activo, no con
  `${if_match}` en el `TEXT` del widget como en los demás.
- Intervalo de caché `300` s (5 min): una API de cotizaciones bursátiles no
  necesita refresco por segundo, y evita golpear un endpoint no oficial con
  demasiada frecuencia.
- El script tarda unos segundos en ejecutarse (una petición HTTP por
  ticker + `sleep` entre ellas para evitar rate-limit) — aceptable porque
  solo se ejecuta una vez cada 5 min gracias al caché de `execpi`.
- **Rate-limit del endpoint**: pedir varios tickers en ráfaga rápida (sin
  pausa) hace que Yahoo empiece a devolver respuestas vacías para los
  últimos tickers de la ráfaga. Mitigado con `sleep 0.6` entre tickers y
  hasta 3 reintentos con `sleep 1.5` por ticker si la respuesta viene
  vacía.
- **Una posición solo se suma al total cuando ambos precios** (actual y de
  hace 7 días) se obtuvieron con éxito — si no, distorsionaría el % total
  como si esa posición hubiera perdido/ganado un salto irreal.

### Cómo se calcula la variación semanal (sin guardar estado propio)

El endpoint `v8/finance/chart/<ticker>` acepta parámetros `range`/`interval`;
con `?range=10d&interval=1d` devuelve, además del precio actual
(`meta.regularMarketPrice`), un array `timestamp` +
`indicators.quote[0].close` con el cierre diario de los últimos ~10 días. El
script calcula `target_ts = now - 7*86400` (7 días naturales atrás) y con
`jq` busca, entre los cierres no nulos (los `null` son fines de semana/
festivos sin sesión), el de `timestamp` más cercano a `target_ts` — así no
hace falta guardar ningún estado propio entre ejecuciones: cada ejecución
recalcula el punto de comparación desde cero contra el histórico que ya
trae la propia respuesta de Yahoo.

### Por qué está en `bottom_left`, no apilado con los otros 4

Al medir con `xwininfo`, el widget Portfolio ocupa 157 px de alto. Sumado a
los otros 4 (Gotham 171 + Temperatura 220 + Sistema 241 + Process Panel
346 + 4 márgenes de 20 px = 1135 px) el total necesario supera con margen
el `_NET_WORKAREA` disponible — no cabía como 5º widget en la misma columna
sin comprimir los demás. Se optó por darle su propia columna en la esquina
inferior izquierda (`alignment bottom_left`, `gap_x 20`, `gap_y 20`), lejos
del stack de la derecha. Ancho `minimum_size 210 0` igual que los otros
widgets "stat" — el formato de las líneas se diseñó compacto
(`+X,X% (+XXX€)` en vez de mostrar valor absoluto y P&L completos)
precisamente para caber en esa anchura sin que la ventana se expandiera de
más.

### Zona clicable: abre el gestor de cartera

`conky_click_portfolio` en `click_actions.lua`, mismo patrón que los otros
4 (zona única, toda la ventana): lanza la app de gestión de cartera
configurada. Como con cualquier cambio a `click_actions.lua`, hace falta
**matar y relanzar el proceso** correspondiente (no basta con que el `TEXT`
se autorecargue) para que recoja tanto el `lua_load`/`lua_mouse_hook` nuevos
en la config como la función nueva del `.lua`.

## Sistema de color usado (umbrales)

Mismo criterio en los cuatro widgets del stack: **verde `8AFF8A` → naranja
`FFA300` → rojo `FF3333`**, aplicado tanto al texto como a las barras
(`cpubar`/`membar`/`fs_bar`) vía `${if_match}` anidados antes de la
variable a colorear.

| Métrica | Naranja (aviso) | Rojo (crítico) |
|---|---|---|
| CPU global / núcleo individual | > 50% uso / > 60 °C | > 80% uso / > 80 °C |
| RAM global | > 50% | > 80% |
| Proceso individual (CPU) | > 20% | > 50% |
| Proceso individual (RAM, `top_mem mem N`, % no formateado) | > 5% | > 15% |
| Placa base (ACPI) | > 55 °C | > 70 °C |
| SSD NVMe | > 50 °C | > 70 °C |
| Señal WiFi (invertido: rojo = señal *baja*) | < 60% | < 30% |
| Disco `/` usado | > 75% | > 90% |
| GPU (iGPU) uso | > 60% | > 85% |
| Actualizaciones apt pendientes | > 50 | > 150 |

Todos los umbrales son orientativos — si en el día a día resultan demasiado
o poco sensibles, es solo cuestión de tocar el número en el `${if_match ...
> N}` correspondiente.

## Widgets clicables (zonas activas por sección)

Cada widget abre una app distinta según en qué sección se hace clic, vía el
mecanismo `lua_mouse_hook` de Conky (requiere `conky-all`, no `conky-std`).

### Requisito de paquete: `conky-std` → `conky-all`

El Conky `conky-std` **no tiene Lua compilado** (`conky --version` no lista
"Lua bindings"), y `lua_mouse_hook`/`lua_load` son funcionalidad Lua. Hace
falta `conky-all` (mismo binario `/usr/bin/conky`, solo añade bindings de
Lua/Cairo/Imlib2). Tras el cambio de paquete, **hay que matar y relanzar
los procesos** — el binario en memoria sigue siendo el antiguo hasta que se
relanza el proceso.

### Mapa de zonas y acciones

| Widget | Zona | Acción |
|---|---|---|
| Gotham | Línea inferior (HD/RAM/CPU), `y >= 145` | Gestor de tareas |
| Gotham | Reloj/fecha (resto de la ventana) | Sin acción |
| Temperatura | Toda la ventana | Monitor de sensores |
| Sistema | `y < 99` (Red/WiFi) | Editor de conexiones de red |
| Sistema | `99 ≤ y < 176` (Disco) | Gestor de ficheros |
| Sistema | `176 ≤ y < 215` (GPU) | Sin acción (zona libre) |
| Sistema | `y ≥ 215` (Actualizaciones) | Gestor de actualizaciones |
| Process Panel | Toda la ventana | Gestor de tareas |

Implementación: `scripts/click_actions.lua`, con una función
`conky_click_<widget>` por widget. Cada fichero de config referencia su
función vía:
```
lua_load <ruta>/scripts/click_actions.lua
lua_mouse_hook conky_click_<widget>
```
Las coordenadas `event.x`/`event.y` que recibe la función son relativas a
la ventana de **ese** widget, no a la pantalla — por eso las zonas de
Sistema se calcularon por proporción de líneas respecto a su altura total.
**Si se vuelve a cambiar el tamaño de fuente de Sistema, hay que reescalar
estos umbrales proporcionalmente** y relanzar el proceso para que recoja el
`.lua` actualizado — el script Lua se carga una sola vez al arrancar el
proceso, no se recarga solo como el `TEXT` de la config.

### Dos bugs no documentados que costó encontrar

Si esto deja de funcionar en el futuro (p. ej. tras actualizar Conky),
revisar primero estos dos puntos — ninguno de los dos aparece en el `man
conky`:

1. **El nombre de función en `lua_mouse_hook` va con el prefijo `conky_`
   completo, escrito a mano.** El manual dice que Conky añade `conky_`
   automáticamente si no lo pones tú — en la práctica (Conky 1.19.6) **no
   lo añade**: busca el nombre literal que escribas. Si se pone
   `lua_mouse_hook click_temperatura` pero la función se llama
   `conky_click_temperatura`, falla en silencio (nada se ve en pantalla, ni
   error visible para el usuario) y solo aparece en el log del proceso:
   `llua_mouse_hook: function click_temperatura execution failed: attempt
   to call a nil value`. Hay que escribir el nombre completo con `conky_`
   en el `lua_mouse_hook`.
2. **`event.button` es un número, no texto.** La wiki de GitHub de Conky
   documenta `event.button == "left"`, pero en esta versión llega como
   `event.button == 1` (botón izquierdo), `2` (medio), `3` (derecho) —
   comparar contra la cadena `"left"` nunca es verdadero y el clic no hace
   nada, sin ningún error en el log (la función se ejecuta bien, simplemente
   la condición nunca se cumple).

**Cómo se diagnosticó** (por si hace falta repetir el proceso): se añadió
un logger temporal a `click_actions.lua` que escribía cada evento recibido
(tipo, botón, x, y) a un fichero temporal. Eso reveló que los eventos sí
llegaban (`type=button_down button=1 ...`) pero la condición de texto nunca
coincidía. Antes de eso, se probó también una ventana de prueba mínima sin
transparencia/hints para descartar que fuera un problema de
`own_window_hints`, y se probó la sintaxis nueva de Conky
(`conky.config = {...}`) para descartar que la auto-conversión de sintaxis
antigua estuviera descartando las directivas `lua_load`/`lua_mouse_hook` —
ninguna de las dos cosas era la causa real.

## Autoarranque al iniciar sesión

**Por qué no vale un script en `.bashrc`/`.profile`**: esos ficheros son
para shells interactivas de terminal, no para el arranque de la sesión
gráfica — no hay garantía de que se ejecuten, ni de que lo hagan con el
`DISPLAY` ya disponible, en un login gráfico.

**Primer intento (fallido): apoyarse en Conky Manager.** Se probó una
entrada de autoarranque que relanzaba `conky-manager2` asumiendo que
recordaría los widgets activos entre sesiones. **No funcionó**: la app se
abría con la lista vacía. Investigando el binario, se confirmó que su
fichero de config **no guarda qué widgets estaban activos** entre
sesiones — solo ajustes de la interfaz. El propio programa, al arrancar sin
nada marcado, imprime `# No widgets enabled!` y no lanza nada.

**Solución aplicada**: un **script propio** (`scripts/autostart_widgets.sh`)
que lanza los `conky -c <ruta>` directamente, sin pasar por Conky Manager en
absoluto:
- Espera 5 s (a que el escritorio esté listo) y lanza los procesos con
  `setsid ... & disown`, cada uno con su log propio.
- Una entrada XDG autostart (`~/.config/autostart/conky-widgets.desktop`)
  ejecuta ese script en vez de abrir Conky Manager.

Este enfoque es más robusto porque no depende de un estado interno no
documentado de una app de terceros — si se añade/quita un widget del
layout en el futuro, basta con editar la lista de rutas en
`autostart_widgets.sh`.

## Notas operativas para editar los widgets

- **Conky recarga solo al detectar cambios en el fichero** (`conky:
  '<path>' modified, reloading...`). No hace falta matar el proceso y
  relanzarlo — de hecho, hacerlo justo cuando el propio conky está
  recargando puede dejarlo muerto por condición de carrera. Solo editar y
  esperar 1-2 s.
- Si un proceso conky muere y hay que relanzarlo a mano, usar `setsid
  nohup conky -c "<ruta>" >/tmp/log 2>&1 < /dev/null &` seguido de
  `disown` — lanzarlo con `&` a secas dentro de un subshell de herramienta
  puede quedar ligado a la sesión y morir con ella.
- El aviso `Syntax error (...:2: unexpected symbol near '#')` seguido de
  `Assuming it's in old syntax and attempting conversion` es **benigno**:
  ocurre porque el bloque de comentarios con `#` al principio del fichero
  usa formato antiguo de Conky 1.x y se autoconvierte. No indica que algo
  esté roto.

## Ideas para próximas iteraciones

- **GPU**: el dato ya no depende de `intel-gpu-tools`. Si algún día se
  quiere el desglose por motor (vídeo, copy, video-enhance además de
  render) o el consumo en vatios, `intel_gpu_top` corregido sigue siendo la
  vía más cómoda — pero para el % de render que muestra el widget, `fdinfo`
  ya basta y no necesita `perf`.
- Añadir temperatura de WiFi (`${hwmon iwlwifi_1 temp 1}`) si interesa un
  panel más completo de red.
- Si se añade una fuente de datos que requiera sí o sí `exec`/`execi`, usar
  `execi <segundos>` con un intervalo de cacheo generoso (no menor al
  `update_interval` del widget) para no lanzar el subproceso en cada
  refresco, y hacer que el script imprima solo un número con fallback
  (mismo patrón que `gpu_usage.sh`/`apt_updates.sh`).
- Si se añade o edita contenido de cualquier widget del layout apilado,
  recordar remedir con `xwininfo` y reajustar el `gap_y` de los widgets que
  quedan por debajo.
- **Portfolio**: si en el día a día el rate-limit de Yahoo Finance da
  problemas frecuentes de "sin datos", considerar subir el intervalo de
  `execpi` (actualmente `300` s) o añadir un pequeño caché en disco
  compartido entre ejecuciones.
