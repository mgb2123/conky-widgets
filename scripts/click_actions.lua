-- Zonas clicables de los widgets de Conky.
-- Cada widget referencia una de estas funciones via lua_mouse_hook.
-- Las coordenadas x,y son relativas a la ventana de ESE widget (no de la pantalla).
-- event.button llega como numero (1=izquierdo, 2=medio, 3=derecho), no como texto.

local function launch(cmd)
  os.execute(cmd .. " >/dev/null 2>&1 &")
end

-- Gotham (reloj/fecha + resumen HD/RAM/CPU), ventana 677x171
function conky_click_gotham(event)
  if event.type == "button_down" and event.button == 1 then
    if event.y >= 145 then
      -- linea HD/RAM/CPU (parte inferior)
      launch("xfce4-taskmanager")
      return true
    end
    -- zona del reloj/fecha: sin accion (no hay app de calendario instalada)
  end
  return false
end

-- Temperatura, ventana 181x200 -> zona unica
function conky_click_temperatura(event)
  if event.type == "button_down" and event.button == 1 then
    launch("psensor")
    return true
  end
  return false
end

-- Sistema (Red / Disco / GPU / Actualizaciones), ventana 227x241
function conky_click_sistema(event)
  if event.type == "button_down" and event.button == 1 then
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

-- Process Panel (CPU/RAM), ventana 181x314 -> zona unica
function conky_click_process_panel(event)
  if event.type == "button_down" and event.button == 1 then
    launch("xfce4-taskmanager")
    return true
  end
  return false
end

-- Portfolio (cartera de inversion), ventana 221x157 -> zona unica
function conky_click_portfolio(event)
  if event.type == "button_down" and event.button == 1 then
    launch("flatpak run info.portfolio_performance.PortfolioPerformance")
    return true
  end
  return false
end
