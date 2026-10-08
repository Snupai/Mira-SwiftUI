#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
MODE="${1:-run}"
case "$MODE" in
  run|--verify|--debug|--logs|--telemetry) ;;
  *) echo "usage: $0 [--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
pkill -x Mira >/dev/null 2>&1 || true
./bundle.sh
case "$MODE" in
  --debug) lldb -- Mira.app/Contents/MacOS/Mira ;;
  --logs|--telemetry)
    /usr/bin/open -n Mira.app
    /usr/bin/log stream --info --style compact --predicate 'process == "Mira"'
    ;;
  --verify)
    /usr/bin/open -n Mira.app
    sleep 2
    pgrep -x Mira >/dev/null
    ;;
  run) /usr/bin/open -n Mira.app ;;
esac
