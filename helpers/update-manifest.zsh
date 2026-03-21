#!/usr/bin/env zsh
set -euo pipefail

# Get format version parameter (required; this script only updates versioned folders like v2/)
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <formatVersion>"
  echo "Example: $0 2"
  exit 1
fi

FORMAT_VERSION="$1"

# Validate integer >= 2
if ! [[ "$FORMAT_VERSION" =~ ^[0-9]+$ ]]; then
  echo "formatVersion must be an integer (got: $FORMAT_VERSION)"
  exit 1
fi
if [[ "$FORMAT_VERSION" -lt 2 ]]; then
  echo "formatVersion must be >= 2 (got: $FORMAT_VERSION)"
  exit 1
fi

# Determine base path based on format version
BASE_PATH="v$FORMAT_VERSION"
BASE_URL_PATH="v$FORMAT_VERSION/"

MANIFEST="$BASE_PATH/manifest.json"
DATA_DIR="$BASE_PATH/data"
CONFIG_DIR="$BASE_PATH/config"

echo "Updating manifest for format version $FORMAT_VERSION"
echo "Working in: $BASE_PATH"

if [[ ! -f "$MANIFEST" ]]; then
  echo "manifest.json not found at $MANIFEST"
  exit 1
fi

if [[ ! -d "$DATA_DIR" ]]; then
  echo "data directory not found at $DATA_DIR"
  exit 1
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "config directory not found at $CONFIG_DIR"
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
   .csvData.baseUrl = \"https://nrpriore.github.io/tt2-raid-data/${BASE_URL_PATH}data/\" |
   .config |= (. // {}) |
   .config.files = { $json_cfg } |
   .config.baseUrl = \"https://nrpriore.github.io/tt2-raid-data/${BASE_URL_PATH}config/\" |
   .dataVersion = \"$ver\"" \
  "$MANIFEST" > "$MANIFEST.tmp"

mv "$MANIFEST.tmp" "$MANIFEST"

echo "manifest.json updated successfully"
echo "dataVersion set to $ver"
