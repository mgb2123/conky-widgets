#!/bin/bash
# % de ocupacion de la iGPU Intel (el motor mas ocupado de todos).
#
# NO usa intel_gpu_top: la version 1.28 de intel-gpu-tools (Ubuntu 24.04) aborta
# con SIGABRT en get_num_gts() sobre este kernel, y cada abort dispara apport
# ("System program problem detected"). En su lugar lee /proc/*/fdinfo, que expone
# drm-engine-<motor> en nanosegundos acumulados por cliente DRM: dos muestras
# separadas por SAMPLE_MS dan el porcentaje ocupado. Sin root, sin perf, sin crash.
#
# Se mide cada motor por separado (render/3D, copy, video, video-enhance) y se
# imprime el MAS ocupado: asi un video acelerado por hardware (motor "video") o
# una copia de texturas se ven igual que una carga 3D. Si un motor tiene varias
# instancias (drm-engine-capacity-video: 2 = vcs0+vcs1), se divide por su
# capacidad para que el maximo siga siendo 100%.
#
# El widget Sistema invoca este script 3 veces por refresco (execi 2), asi que el
# resultado se cachea CACHE_TTL segundos en $XDG_RUNTIME_DIR.

SAMPLE_MS=400
CACHE_TTL=2
CACHE="${XDG_RUNTIME_DIR:-/tmp}/conky_gpu_usage"

if [ -f "$CACHE" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    cat "$CACHE"
    exit 0
  fi
fi

# Imprime "<motor> <ns_acumulados>" por motor, sumando todos los clientes DRM.
# Deduplica por drm-client-id: un mismo cliente aparece en varios descriptores.
sample() {
  grep -ls '^drm-driver' /proc/[0-9]*/fdinfo/* 2>/dev/null \
  | xargs -r awk '
      FNR == 1 { skip = 0 }
      /^drm-client-id:/ { if (seen[$2]++) skip = 1; next }
      skip { next }
      /^drm-engine-capacity-/ { sub(/^drm-engine-capacity-/, "", $1); sub(/:$/, "", $1); cap[$1] = $2 + 0; next }
      /^drm-engine-/ { sub(/^drm-engine-/, "", $1); sub(/:$/, "", $1); ns[$1] += $2 + 0 }
      END { for (e in ns) printf "%s %d %d\n", e, ns[e], (cap[e] > 1 ? cap[e] : 1) }
    ' 2>/dev/null
}

t0=$(sample)
sleep "0.$(printf '%03d' $SAMPLE_MS)"
t1=$(sample)

val=$(awk -v ms="$SAMPLE_MS" '
  NR == FNR { before[$1] = $2; next }
  {
    d = $2 - before[$1]
    if (d <= 0) next
    p = d / ($3 * ms * 1000000) * 100
    if (p > max) max = p
  }
  END { if (max > 100) max = 100; printf "%.0f", max + 0 }
' <(echo "$t0") <(echo "$t1") 2>/dev/null)

[ -z "$val" ] && val=0
echo "$val" | tee "$CACHE"
