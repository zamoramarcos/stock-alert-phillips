#!/usr/bin/env bash
# Chequea stock y manda mensaje por Telegram solo cuando CAMBIA el estado a "en stock".
set -u
declare -A URLS=(
  ["Philips OLED 77 Ambilight"]="https://philips.tvsound.com.ar/productos/smart-tv-oled-4k-philips-77-con-ambilight/"
  ["Philips OLED 65 Ambilight"]="https://philips.tvsound.com.ar/productos/smart-tv-oled-4k-philips-65-con-ambilight/"
)
STATE=state.txt; touch "$STATE"; NEW=$(mktemp)

for name in "${!URLS[@]}"; do
  url="${URLS[$name]}"
  html=$(curl -sL --max-time 30 -A "Mozilla/5.0" "$url") || { grep "^$name=" "$STATE" >> "$NEW"; echo "$name: error de red"; continue; }
  # availability de la oferta cuyo url es el de esta pagina (no los productos relacionados)
  status=$(printf '%s' "$html" | perl -0777 -ne 'BEGIN{$u=shift} if (/"url":\s*"\Q$u\E",\s*"priceCurrency":\s*"[^"]*",\s*"price":\s*"[^"]*",\s*"availability":\s*"https:\/\/schema.org\/(\w+)"/){print $1}' "$url")
  if [ -z "$status" ]; then grep "^$name=" "$STATE" >> "$NEW"; echo "$name: no pude leer el estado"; continue; fi
  echo "$name: $status"
  echo "$name=$status" >> "$NEW"
  prev=$(grep "^$name=" "$STATE" | cut -d= -f2)
  if [ "$status" = "InStock" ] && [ "$prev" != "InStock" ]; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=HAY STOCK: $name
$url" > /dev/null
  fi
done
sort "$NEW" > "$STATE"
