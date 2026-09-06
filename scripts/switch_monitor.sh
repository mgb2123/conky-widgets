#!/bin/bash
# Cicla el xinerama_head de un widget de Conky al siguiente monitor conectado
# y reinicia su proceso. Los mismos gap_x/gap_y del conkyrc producen "la misma
# posicion" en el monitor nuevo porque Conky los recalcula contra el workarea
# del head activo -- no hace falta mover la ventana a mano.
#
# Uso: switch_monitor.sh <ruta_conkyrc> <ruta_log>
set -euo pipefail

CONKYRC="$1"
LOG="$2"

mapfile -t MONITORES < <(xrandr --query | grep -E '^\S+ connected' | grep -E '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+')
N=${#MONITORES[@]}

# Guarda de seguridad: si el monitor externo se desconecto entre que se
# mostro el boton y el clic, no hacer nada.
if [ "$N" -le 1 ]; then
  exit 0
fi

ACTUAL=$(grep -oP '^xinerama_head\s+\K[0-9]+' "$CONKYRC" || echo 0)
SIGUIENTE=$(( (ACTUAL + 1) % N ))

sed -i -E "s/^xinerama_head[[:space:]]+[0-9]+/xinerama_head ${SIGUIENTE}/" "$CONKYRC"

PID=$(pgrep -f -- "conky -c ${CONKYRC}" || true)
if [ -n "$PID" ]; then
  kill "$PID"
  sleep 0.3
fi

setsid nohup conky -c "$CONKYRC" >"$LOG" 2>&1 </dev/null &
disown
