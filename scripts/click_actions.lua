-- Zonas clicables de los widgets de Conky.
-- Cada widget referencia una de estas funciones via lua_mouse_hook.
-- Las coordenadas x,y son relativas a la ventana de ESE widget (no de la pantalla).
-- event.button llega como numero (1=izquierdo, 2=medio, 3=derecho), no como texto.
-- event.type tambien puede ser "mouse_enter"/"mouse_leave"/"mouse_move" ademas de
-- "button_down"/"button_up" (no documentado en la wiki de Conky, pero confirmado
-- leyendo src/mouse-events.cc y probado en vivo -- ver widgets-conky.md).

require 'cairo'

local function launch(cmd)
  os.execute(cmd .. " >/dev/null 2>&1 &")
end

local HOME = os.getenv("HOME")
local SCRIPT_DIR = HOME .. "/.conky/scripts"

-- Ruta real del conkyrc de cada widget, para poder reiniciarlo al cambiar de pantalla.
local CONKYRC = {
  gotham         = HOME .. "/.conky/Green Apple Desktop/Gotham",
  temperatura    = HOME .. "/.conky/Temperatura/Temperatura",
  sistema        = HOME .. "/.conky/Sistema/Sistema",
  process_panel  = HOME .. "/.conky/TeejeeTech/Process Panel",
  portfolio      = HOME .. "/.conky/Portfolio/Portfolio",
}

-- Lado del boton de cambio de pantalla: el lado que da "hacia dentro" del
-- escritorio, no el borde de pantalla al que esta anclado el widget.
local BOTON_LADO = {
  gotham         = "izquierda",
  temperatura    = "izquierda",
  sistema        = "izquierda",
  process_panel  = "izquierda",
  portfolio      = "derecha",
}

local BOTON_RADIO = 11
local BOTON_MARGEN = 15 -- distancia del centro del boton al borde lateral

-- Estado de hover por widget, actualizado por mouse_enter/mouse_leave.
local hover = {}

-- Cuenta monitores conectados con geometria activa (no basta "connected" a
-- secas: una salida puede estar conectada sin modo activo). Solo se llama
-- mientras hay hover, nunca en reposo, para no gastar un fork por ciclo.
local function contar_monitores()
  local f = io.popen("xrandr --query 2>/dev/null")
  if not f then return 1 end
  local n = 0
  for line in f:lines() do
    if line:match("^%S+ connected") and line:match("%d+x%d+%+%d+%+%d+") then
      n = n + 1
    end
  end
  f:close()
  return n
end

local function boton_centro(widget)
  local w = (conky_window and conky_window.width) or 0
  local h = (conky_window and conky_window.height) or 0
  local cx = (BOTON_LADO[widget] == "derecha") and (w - BOTON_MARGEN) or BOTON_MARGEN
  return cx, h / 2
end

local function dentro_del_boton(widget, x, y)
  local cx, cy = boton_centro(widget)
  local dx, dy = x - cx, y - cy
  return (dx * dx + dy * dy) <= (BOTON_RADIO * BOTON_RADIO)
end

local function dibujar_boton(widget)
  if not conky_window or conky_window.width == 0 or conky_window.height == 0 then return end

  local cx, cy = boton_centro(widget)
  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
    conky_window.visual, conky_window.width, conky_window.height)
  local cr = cairo_create(cs)

  cairo_set_source_rgba(cr, 0.1, 0.1, 0.1, 0.55)
  cairo_arc(cr, cx, cy, BOTON_RADIO, 0, 2 * math.pi)
  cairo_fill(cr)

  -- flecha simple apuntando hacia el lado contrario al anclaje del widget
  cairo_set_source_rgba(cr, 1, 1, 1, 0.9)
  cairo_set_line_width(cr, 2)
  local dir = (BOTON_LADO[widget] == "derecha") and 1 or -1
  cairo_move_to(cr, cx - dir * 4, cy - 5)
  cairo_line_to(cr, cx + dir * 4, cy)
  cairo_line_to(cr, cx - dir * 4, cy + 5)
  cairo_stroke(cr)

  cairo_destroy(cr)
  cairo_surface_destroy(cs)
end

-- Cicla el widget al siguiente monitor y reinicia su proceso conky.
-- Nota: os.execute() usa /bin/sh (dash), que no soporta "disown" -- por eso
-- no se usa aqui aunque si se use en el patron de reinicio manual con bash.
local function cambiar_pantalla(widget)
  local conkyrc = CONKYRC[widget]
  if not conkyrc then return end
  local log = "/tmp/switch-" .. widget .. ".log"
  local cmd = string.format(
    "setsid nohup bash '%s/switch_monitor.sh' '%s' '%s' >'%s' 2>&1 </dev/null &",
    SCRIPT_DIR, conkyrc, log, log)
  os.execute(cmd)
end

-- Gotham (reloj/fecha + resumen HD/RAM/CPU)
function conky_click_gotham(event)
  if event.type == "mouse_enter" then hover.gotham = true; return false end
  if event.type == "mouse_leave" then hover.gotham = false; return false end
  if event.type == "button_down" and event.button == 1 then
    if hover.gotham and dentro_del_boton("gotham", event.x, event.y) and contar_monitores() > 1 then
      cambiar_pantalla("gotham")
      return true
    end
    if event.y >= 145 then
      -- linea HD/RAM/CPU (parte inferior)
      launch("xfce4-taskmanager")
      return true
    end
    -- zona del reloj/fecha: sin accion (no hay app de calendario instalada)
  end
  return false
end

function conky_draw_gotham()
  if hover.gotham and contar_monitores() > 1 then
    dibujar_boton("gotham")
  end
end

-- Temperatura -> zona unica
function conky_click_temperatura(event)
  if event.type == "mouse_enter" then hover.temperatura = true; return false end
  if event.type == "mouse_leave" then hover.temperatura = false; return false end
  if event.type == "button_down" and event.button == 1 then
    if hover.temperatura and dentro_del_boton("temperatura", event.x, event.y) and contar_monitores() > 1 then
      cambiar_pantalla("temperatura")
      return true
    end
    launch("psensor")
    return true
  end
  return false
end

function conky_draw_temperatura()
  if hover.temperatura and contar_monitores() > 1 then
    dibujar_boton("temperatura")
  end
end

-- Sistema (Red / Disco / GPU / Actualizaciones)
function conky_click_sistema(event)
  if event.type == "mouse_enter" then hover.sistema = true; return false end
  if event.type == "mouse_leave" then hover.sistema = false; return false end
  if event.type == "button_down" and event.button == 1 then
    if hover.sistema and dentro_del_boton("sistema", event.x, event.y) and contar_monitores() > 1 then
      cambiar_pantalla("sistema")
      return true
    end
    local y = event.y
    if y < 99 then
      launch("nm-connection-editor")           -- Red / Senal WiFi
    elseif y < 176 then
      launch("thunar /")                        -- Disco
    elseif y < 215 then
      -- GPU: sin app util de momento (dato roto por bug de Ubuntu, ver widgets-conky.md)
    else
      launch("software-properties-gtk")         -- Actualizaciones
    end
    return true
  end
  return false
end

function conky_draw_sistema()
  if hover.sistema and contar_monitores() > 1 then
    dibujar_boton("sistema")
  end
end

-- Process Panel (CPU/RAM) -> zona unica
function conky_click_process_panel(event)
  if event.type == "mouse_enter" then hover.process_panel = true; return false end
  if event.type == "mouse_leave" then hover.process_panel = false; return false end
  if event.type == "button_down" and event.button == 1 then
    if hover.process_panel and dentro_del_boton("process_panel", event.x, event.y) and contar_monitores() > 1 then
      cambiar_pantalla("process_panel")
      return true
    end
    launch("xfce4-taskmanager")
    return true
  end
  return false
end

function conky_draw_process_panel()
  if hover.process_panel and contar_monitores() > 1 then
    dibujar_boton("process_panel")
  end
end

-- Portfolio (cartera de inversion) -> zona unica
function conky_click_portfolio(event)
  if event.type == "mouse_enter" then hover.portfolio = true; return false end
  if event.type == "mouse_leave" then hover.portfolio = false; return false end
  if event.type == "button_down" and event.button == 1 then
    if hover.portfolio and dentro_del_boton("portfolio", event.x, event.y) and contar_monitores() > 1 then
      cambiar_pantalla("portfolio")
      return true
    end
    launch("flatpak run info.portfolio_performance.PortfolioPerformance")
    return true
  end
  return false
end

function conky_draw_portfolio()
  if hover.portfolio and contar_monitores() > 1 then
    dibujar_boton("portfolio")
  end
end
