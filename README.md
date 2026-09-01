# Conky Widgets

Cinco widgets de escritorio [Conky](https://github.com/brndnmtthws/conky)
para Ubuntu/XFCE: reloj, temperatura, sistema, panel de procesos y una
cartera de inversión, apilados en la esquina superior derecha con zonas
clicables que abren la app correspondiente (gestor de tareas, monitor de
sensores, gestor de red...).

![threshold colors](https://img.shields.io/badge/thresholds-verde%20%E2%86%92%20naranja%20%E2%86%92%20rojo-8AFF8A)

## Por qué

Lo que hace interesantes estos widgets no es el tema visual — parte de una
base descargada, ver [créditos](#créditos) — sino la integración: sensores
leídos nativamente sin lanzar procesos externos en cada refresco, un
workaround propio para un bug de kernel/driver que generaba crashes
silenciosos, zonas clicables por coordenadas medidas empíricamente, y un
layout apilado calculado en píxeles reales de ventana. El detalle completo
está en [`NOTES.md`](NOTES.md).

## Widgets

| Widget | Contenido |
|---|---|
| **Gotham** | Reloj, fecha, resumen de disco/RAM/CPU |
| **Temperatura** | Temperatura CPU (package + 4 núcleos), frecuencia, placa base, SSD NVMe |
| **Sistema** | Red (subida/bajada + señal WiFi), disco, GPU integrada, actualizaciones pendientes |
| **Process Panel** | % CPU/RAM global con barras + top 5 procesos por CPU y por RAM |
| **Portfolio** | Valor total y variación semanal de una cartera de inversión, vía API pública de Yahoo Finance |

Todos comparten el mismo sistema de color por umbrales (verde → naranja →
rojo) y abren una aplicación distinta según en qué zona se hace clic — ver
la tabla completa en `NOTES.md`.

## Requisitos

- `conky-all` (no `conky-std` — necesita los bindings de Lua para las zonas
  clicables vía `lua_mouse_hook`)
- `psutil`-equivalentes nativos de Conky (nada de Python aquí, es C/Lua)
- `curl` y `jq` (widget Portfolio)
- `lspci` / opcionalmente `nvidia-smi` si hay GPU dedicada

## Instalación

1. Copia (o symlink) este repositorio a `~/.conky/`. Las rutas absolutas que
   usan `lua_load` y `execi` en cada `conkyrc`, y las que usa
   `scripts/autostart_widgets.sh`, llevan `/home/USUARIO/` como placeholder
   (Conky no expande `~` ni `$HOME` en esas directivas de forma fiable) —
   sustitúyelo por tu ruta real de home en cada `conkyrc` antes de lanzar
   los widgets. `autostart_widgets.sh` sí es un script bash normal y ya usa
   `$HOME` sin necesidad de tocarlo.
2. Instala las fuentes usadas (`GE Inspira` para Gotham, `Ubuntu` para el
   resumen de disco/RAM/CPU) — no se incluyen en el repo por licencia; ver
   [créditos](#créditos) para dónde venían originalmente. Sin ellas, Conky
   cae a una fuente por defecto y el layout de Gotham pierde su tamaño
   calculado.
3. Ajusta el nombre de tu interfaz de red en `sistema/conkyrc`
   (`${downspeed <iface>}` / `${upspeed <iface>}` — comprueba el tuyo con
   `ip -br addr`).
4. Sustituye la cartera de ejemplo en `scripts/portfolio_widget.sh`
   (arrays `TICKERS`/`NAMES`/`QTYS`) por la tuya, o elimina ese widget si no
   lo necesitas.
5. Lanza cada widget:
   ```bash
   conky -c ~/.conky/gotham/conkyrc &
   conky -c ~/.conky/temperatura/conkyrc &
   conky -c ~/.conky/sistema/conkyrc &
   conky -c "~/.conky/process-panel/conkyrc" &
   conky -c ~/.conky/portfolio/conkyrc &
   ```
   O usa `scripts/autostart_widgets.sh` (registrable como entrada
   `~/.config/autostart/*.desktop` para que arranquen solos al iniciar
   sesión).

## Estructura

```
gotham/conkyrc            reloj + resumen de sistema
temperatura/conkyrc       sensores de temperatura
sistema/conkyrc           red, disco, GPU, actualizaciones
process-panel/conkyrc     CPU/RAM + top procesos (base: Tony George/TeejeeTech)
portfolio/conkyrc         cartera de inversión
scripts/
  click_actions.lua       zonas clicables de los 5 widgets
  gpu_usage.sh             % de uso de la iGPU vía /proc/*/fdinfo (sin intel_gpu_top)
  apt_updates.sh           paquetes apt pendientes de actualizar
  portfolio_widget.sh      cotizaciones vía API pública de Yahoo Finance
  autostart_widgets.sh     lanza los 5 procesos al iniciar sesión
```

## Créditos

Gotham parte del tema [Gotham Conky config](http://psyjunta.deviantart.com/art/Gotham-Conky-config-205465419)
de psyjunta (deviantart), con la disposición de reloj y tipografía
`GE Inspira`. Process Panel parte de los
[temas de Tony George / TeejeeTech](http://www.teejeetech.in/2014/07/my-conky-themes-update-2.html)
(atribución conservada en la cabecera del propio fichero). Temperatura,
Sistema y Portfolio son configuraciones propias construidas desde cero
sobre el mismo estilo visual. Sobre esas bases: layout apilado medido con
`xwininfo`, sensores nativos, scripts de datos propios (GPU, apt,
cotizaciones), zonas clicables por widget y autoarranque sin depender de
Conky Manager — ver [`NOTES.md`](NOTES.md) para el detalle de cada decisión.

## Licencia

El código propio de este repositorio (scripts en `scripts/` y las
adaptaciones de las configuraciones) se distribuye bajo [MIT](LICENSE). Los
temas base de Gotham y Process Panel citados arriba son de sus autores
originales; consulta sus fuentes si vas a redistribuirlos.
