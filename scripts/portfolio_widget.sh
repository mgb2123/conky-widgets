#!/bin/bash
# Datos generales de una cartera de inversion: variacion de esta ultima
# semana (precio actual vs. precio de hace 7 dias), via API publica de
# Yahoo Finance (query1.finance.yahoo.com/v8/finance/chart/<ticker>).
# Pensado para usarse con ${execpi <segundos> ...} (exec "parseado": permite
# que el ${color ...} de la salida se interprete, a diferencia de ${execi}).
#
# EJEMPLO: sustituye estos tres arrays por tu propia cartera (ticker de
# Yahoo Finance, nombre a mostrar, numero de acciones/participaciones).
TICKERS=(AAPL MSFT GOOGL)
NAMES=("Apple" "Microsoft" "Alphabet")
QTYS=(10 5 8)

GREEN="8AFF8A"
RED="FF3333"
GREY="grey"

target_ts=$(( $(date +%s) - 7*86400 ))

# Formatea un numero con coma decimal y separador de miles (estilo es-ES).
fmt_eur() {
  awk -v n="$1" 'BEGIN {
    neg = (n < 0); if (neg) n = -n
    s = sprintf("%.2f", n)
    split(s, parts, ".")
    ent = parts[1]; dec = parts[2]
    out = ""
    len = length(ent)
    for (i = 1; i <= len; i++) {
      out = substr(ent, len - i + 1, 1) out
      if (i % 3 == 0 && i != len) out = "." out
    }
    printf "%s%s,%s", (neg ? "-" : ""), out, dec
  }'
}

total_now=0
total_weekago=0
lines=""

for i in "${!TICKERS[@]}"; do
  ticker="${TICKERS[$i]}"
  name="${NAMES[$i]}"
  qty="${QTYS[$i]}"

  raw=""
  for attempt in 1 2 3; do
    raw=$(timeout 5 curl -s -A "Mozilla/5.0" \
      "https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?range=10d&interval=1d" 2>/dev/null \
      | jq -r --argjson target "$target_ts" '
          .chart.result[0] as $r
          | ($r.meta.regularMarketPrice) as $now
          | ($r.timestamp // []) as $ts
          | ($r.indicators.quote[0].close // []) as $close
          | ([range(0; ($ts|length)) | select($close[.] != null) | {close: $close[.], diff: (($ts[.] - $target) | fabs)}]
             | sort_by(.diff) | .[0].close) as $weekago
          | if ($now != null and $weekago != null) then "\($now)\t\($weekago)" else empty end
        ' 2>/dev/null)
    [ -n "$raw" ] && break
    sleep 1.5
  done

  if [ -z "$raw" ]; then
    lines="${lines}\${color ${GREY}}${name}: sin datos\${color}"$'\n'
    continue
  fi
  sleep 0.6

  price_now=$(cut -f1 <<< "$raw")
  price_weekago=$(cut -f2 <<< "$raw")

  # Solo se suma al total una posicion con datos completos: si no, "sin
  # datos" restaria valor de un lado sin el otro y distorsionaria el % total.
  value_now=$(awk -v p="$price_now" -v q="$qty" 'BEGIN{printf "%.4f", p*q}')
  value_weekago=$(awk -v p="$price_weekago" -v q="$qty" 'BEGIN{printf "%.4f", p*q}')
  total_now=$(awk -v a="$total_now" -v b="$value_now" 'BEGIN{printf "%.4f", a+b}')
  total_weekago=$(awk -v a="$total_weekago" -v b="$value_weekago" 'BEGIN{printf "%.4f", a+b}')

  pl=$(awk -v v="$value_now" -v w="$value_weekago" 'BEGIN{printf "%.4f", v-w}')
  plpct=$(awk -v pl="$pl" -v w="$value_weekago" 'BEGIN{printf "%.2f", (w>0)?(pl/w*100):0}')

  color=$GREEN
  sign="+"
  if awk -v pl="$pl" 'BEGIN{exit !(pl<0)}'; then
    color=$RED
    sign=""
  fi

  pl_int=$(awk -v pl="$pl" 'BEGIN{printf "%.0f", (pl<0)?-pl:pl}')
  lines="${lines}\${color EAEAEA}${name}\${alignr}\${color ${color}}${sign}${plpct}% (${sign}${pl_int}€)\${color}"$'\n'
done

if awk -v w="$total_weekago" 'BEGIN{exit !(w>0)}'; then
  total_pl=$(awk -v v="$total_now" -v w="$total_weekago" 'BEGIN{printf "%.4f", v-w}')
  total_plpct=$(awk -v pl="$total_pl" -v w="$total_weekago" 'BEGIN{printf "%.2f", pl/w*100}')
  total_color=$GREEN
  total_sign="+"
  if awk -v pl="$total_pl" 'BEGIN{exit !(pl<0)}'; then
    total_color=$RED
    total_sign=""
  fi
  printf "\${color FFA300}Total: %s€\${alignr}\${color ${total_color}}%s%s%%\${color}\n" \
    "$(fmt_eur "$total_now")" "$total_sign" "$total_plpct"
fi

printf '%s' "${lines}"
