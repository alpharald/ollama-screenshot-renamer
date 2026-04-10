#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.env}"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/launchd/com.example.rename-screenshots.plist}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE"
  echo "Copy config.env.example to config.env and edit it first."
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Missing plist template: $TEMPLATE_FILE"
  exit 1
fi

source "$CONFIG_FILE"

: "${LABEL:="com.${USER}.rename-screenshots"}"
: "${SCRIPT_PATH:="$SCRIPT_DIR/rename-screenshots-daily.sh"}"
: "${PLIST_OUT:="$HOME/Library/LaunchAgents/${LABEL}.plist"}"
: "${STDOUT_LOG:="$HOME/Library/Logs/rename-screenshots.stdout.log"}"
: "${STDERR_LOG:="$HOME/Library/Logs/rename-screenshots.stderr.log"}"
: "${DRY_RUN:="1"}"
: "${SCHEDULE_HOUR:="21"}"
: "${SCHEDULE_MINUTE:="0"}"
: "${LOAD_AGENT:="1"}"

mkdir -p "$(dirname "$PLIST_OUT")"
mkdir -p "$(dirname "$STDOUT_LOG")"
mkdir -p "$(dirname "$STDERR_LOG")"

export LABEL CONFIG_FILE SCRIPT_PATH PLIST_OUT STDOUT_LOG STDERR_LOG DRY_RUN SCHEDULE_HOUR SCHEDULE_MINUTE

python3 - "$TEMPLATE_FILE" "$PLIST_OUT" <<'PY'
from pathlib import Path
import os
import sys

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

content = template_path.read_text()

mapping = {
    "__LABEL__": os.environ["LABEL"],
    "__CONFIG_FILE__": os.environ["CONFIG_FILE"],
    "__SCRIPT_PATH__": os.environ["SCRIPT_PATH"],
    "__DRY_RUN__": os.environ["DRY_RUN"],
    "__SCHEDULE_HOUR__": os.environ["SCHEDULE_HOUR"],
    "__SCHEDULE_MINUTE__": os.environ["SCHEDULE_MINUTE"],
    "__STDOUT_LOG__": os.environ["STDOUT_LOG"],
    "__STDERR_LOG__": os.environ["STDERR_LOG"],
}

for key, value in mapping.items():
    content = content.replace(key, value)

output_path.write_text(content)
print(output_path)
PY

echo "Generated LaunchAgent: $PLIST_OUT"

if [[ "$LOAD_AGENT" == "1" ]]; then
  launchctl bootout "gui/$(id -u)" "$PLIST_OUT" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST_OUT"
  launchctl enable "gui/$(id -u)/$LABEL"
  launchctl kickstart -k "gui/$(id -u)/$LABEL"
  echo "Loaded LaunchAgent: $LABEL"
  echo "Current DRY_RUN=$DRY_RUN"
else
  echo "Skipped loading LaunchAgent because LOAD_AGENT=0"
fi
