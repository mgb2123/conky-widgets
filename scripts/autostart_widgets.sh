#!/bin/bash
# Lanza los 5 widgets de Conky al iniciar sesión (autostart XDG).
# No depende de conky-manager2 -- lanza los procesos conky directamente,
# mismo patrón que el reinicio manual documentado en widgets-conky.md.

sleep 5

LOGDIR="/tmp"

setsid conky -c "$HOME/.conky/Green Apple Desktop/Gotham" >"$LOGDIR/conky-gotham.log" 2>&1 < /dev/null &
disown

setsid conky -c "$HOME/.conky/Temperatura/Temperatura" >"$LOGDIR/conky-temperatura.log" 2>&1 < /dev/null &
disown

setsid conky -c "$HOME/.conky/Sistema/Sistema" >"$LOGDIR/conky-sistema.log" 2>&1 < /dev/null &
disown

setsid conky -c "$HOME/.conky/TeejeeTech/Process Panel" >"$LOGDIR/conky-processpanel.log" 2>&1 < /dev/null &
disown

setsid conky -c "$HOME/.conky/Portfolio/Portfolio" >"$LOGDIR/conky-portfolio.log" 2>&1 < /dev/null &
disown
