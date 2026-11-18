#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$app_dir"

export RETINAZO_SIGNING_PROPERTIES="${RETINAZO_SIGNING_PROPERTIES:-$HOME/.local/share/retinazo/signing/release-signing.properties}"
config_file="${RETINAZO_CONFIG_FILE:-config/supabase.local.json}"

if [[ ! -f "$RETINAZO_SIGNING_PROPERTIES" ]]; then
  printf '%s\n' 'Falta la configuración privada de firma. Consulta docs/ANDROID_RELEASES.md.' >&2
  exit 1
fi
if [[ ! -f "$config_file" ]]; then
  printf '%s\n' 'Falta la configuración pública de servicios. Copia config/supabase.example.json al archivo local.' >&2
  exit 1
fi

"${FLUTTER_BIN:-flutter}" build apk --release --dart-define-from-file="$config_file"
