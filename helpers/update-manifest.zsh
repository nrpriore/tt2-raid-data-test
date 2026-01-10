#!/usr/bin/env zsh
set -euo pipefail

MANIFEST="manifest.json"
DATA_DIR="data"
CONFIG_DIR="config"

if [[ ! -f "$MANIFEST" ]]; then
  echo "manifest.json not found"
  exit 1
fi

if [[ ! -d "$DATA_DIR" ]]; then
  echo "data directory not found"
  exit 1
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "config directory not found"
  exit 1
fi

typeset -A CSV_HASHES
typeset -A CONFIG_HASHES

# Hash data/*.txt -> csvData.files
for f in "$DATA_DIR"/*.txt; do
  [[ -f "$f" ]] || continue
  name="${f:t}"
  hash=$(shasum -a 256 "$f" | awk '{print $1}')
  CSV_HASHES[$name]="sha256:$hash"
  echo "Hashed data/$name"
done

# Hash config/*.json -> config.files
for f in "$CONFIG_DIR"/*.json; do
  [[ -f "$f" ]] || continue
  name="${f:t}"
  hash=$(shasum -a 256 "$f" | awk '{print $1}')
  CONFIG_HASHES[$name]="sha256:$hash"
  echo "Hashed config/$name"
done

# Build JSON objects
json_csv=$(for k v in ${(kv)CSV_HASHES}; do
  printf '"%s":"%s"\n' "$k" "$v"
done | paste -sd, -)

json_cfg=$(for k v in ${(kv)CONFIG_HASHES}; do
  printf '"%s":"%s"\n' "$k" "$v"
done | paste -sd, -)

# UTC timestamp minute precision
ver="$(date -u +%Y.%m.%d-%H.%M)"

# Update manifest using jq
jq \
  ".csvData |= (. // {}) |
   .csvData.files = { $json_csv } |
   .config |= (. // {}) |
   .config.files = { $json_cfg } |
   .dataVersion = \"$ver\"" \
  "$MANIFEST" > "$MANIFEST.tmp"

mv "$MANIFEST.tmp" "$MANIFEST"

echo "manifest.json updated successfully"
echo "dataVersion set to $ver"
