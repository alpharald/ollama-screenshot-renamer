#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.env}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE"
  echo "Copy config.env.example to config.env and edit it first."
  exit 1
fi

source "$CONFIG_FILE"

: "${SCREENSHOT_DIR:="$HOME/Documents/Screenshots"}"
: "${MODEL:="qwen2.5vl:7b"}"
: "${OLLAMA_API_URL:="http://localhost:11434/api/chat"}"
: "${LOGFILE:="$HOME/Library/Logs/rename-screenshots.log"}"
: "${DRY_RUN:="1"}"
: "${MAX_FILES:="200"}"
: "${MIN_WORDS:="3"}"
: "${MAX_WORDS:="6"}"
: "${SCREENSHOT_NAME_REGEX:='^(Screen[[:space:]]Shot|Screenshot|Screen_Shot|Screen-Shot)'}"
: "${ALREADY_RENAMED_REGEX:='^[a-z0-9-]+_screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?\.(png|jpg|jpeg)$'}"

mkdir -p "$(dirname "$LOGFILE")"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOGFILE"
}

is_probably_screenshot() {
  local name="$1"
  [[ "$name" =~ ${~SCREENSHOT_NAME_REGEX} ]]
}

is_already_renamed() {
  local name="$1"
  [[ "$name" =~ ${~ALREADY_RENAMED_REGEX} ]]
}

slugify() {
  local input="$1"
  input="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  input="$(printf '%s' "$input" | sed -E 's/[^a-z0-9[:space:]-]+/ /g')"
  input="$(printf '%s' "$input" | sed -E 's/\b(screenshot|image|photo|picture|desktop|macos|screen|window)\b//g')"
  input="$(printf '%s' "$input" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  input="$(printf '%s' "$input" | tr ' ' '\n' | sed '/^$/d' | head -n "$MAX_WORDS" | tr '\n' ' ')"
  input="$(printf '%s' "$input" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  input="$(printf '%s' "$input" | sed -E 's/ /-/g; s/-+/-/g; s/^-//; s/-$//')"
  printf '%s' "$input"
}

word_count_from_slug() {
  local slug="$1"
  if [[ -z "$slug" ]]; then
    echo 0
    return
  fi
  awk -F'-' '{print NF}' <<< "$slug"
}

describe_image() {
  local image_path="$1"

  python3 - "$image_path" "$MODEL" "$OLLAMA_API_URL" <<'PY'
import base64, json, pathlib, sys, urllib.request

image_path = pathlib.Path(sys.argv[1])
model = sys.argv[2]
api_url = sys.argv[3]

prompt = """Create a short filename phrase for this screenshot.

Rules:
- Return only one short phrase, no explanation.
- Use 3 to 6 simple concrete words.
- Lowercase words only.
- No punctuation.
- No file extensions.
- Do not include the words screenshot, image, photo, picture, macos, desktop, window.
- Focus on the main visible subject or topic.
- If it is mostly text, summarize the topic briefly.

Good examples:
cats on bed
github issue discussion
docker compose config
calendar app meeting
weather forecast dashboard
"""

img_b64 = base64.b64encode(image_path.read_bytes()).decode("utf-8")
payload = {
    "model": model,
    "messages": [
        {
            "role": "user",
            "content": prompt,
            "images": [img_b64]
        }
    ],
    "stream": False
}

req = urllib.request.Request(
    api_url,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)

with urllib.request.urlopen(req, timeout=180) as resp:
    data = json.loads(resp.read().decode("utf-8"))

text = data["message"]["content"].strip().splitlines()[0].strip()
print(text)
PY
}

get_file_date() {
  local file="$1"
  stat -f '%SB' -t '%Y-%m-%d' "$file"
}

propose_name() {
  local file="$1"
  local basename ext raw_desc slug wc file_date

  basename="$(basename "$file")"
  ext="${basename##*.}"
  ext="${ext:l}"

  raw_desc="$(describe_image "$file" 2>>"$LOGFILE" || true)"
  raw_desc="$(printf '%s' "$raw_desc" | sed -E 's/^["'\''`]+|["'\''`]+$//g')"
  slug="$(slugify "$raw_desc")"
  wc="$(word_count_from_slug "$slug")"
  file_date="$(get_file_date "$file")"

  if [[ -z "$slug" ]]; then
    log "SKIP empty model output: $basename"
    return 1
  fi

  if (( wc < MIN_WORDS || wc > MAX_WORDS )); then
    log "SKIP bad word count ($wc): $basename -> raw='$raw_desc' slug='$slug'"
    return 1
  fi

  printf '%s_screenshot_%s.%s\n' "$slug" "$file_date" "$ext"
}

process_file() {
  local file="$1"
  local basename target_name target_path counter base_no_ext ext

  basename="$(basename "$file")"

  if ! is_probably_screenshot "$basename"; then
    log "SKIP not screenshot-like: $basename"
    return 0
  fi

  if is_already_renamed "$basename"; then
    log "SKIP already renamed: $basename"
    return 0
  fi

  target_name="$(propose_name "$file")" || return 0
  target_path="$SCREENSHOT_DIR/$target_name"

  if [[ -e "$target_path" && "$file" != "$target_path" ]]; then
    ext="${target_name##*.}"
    base_no_ext="${target_name%.*}"
    counter=2
    while [[ -e "$SCREENSHOT_DIR/${base_no_ext}-${counter}.${ext}" ]]; do
      ((counter++))
    done
    target_name="${base_no_ext}-${counter}.${ext}"
    target_path="$SCREENSHOT_DIR/$target_name"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY RUN: $basename -> $target_name"
  else
    mv "$file" "$target_path"
    log "RENAMED: $basename -> $target_name"
  fi
}

main() {
  local count=0

  if [[ ! -d "$SCREENSHOT_DIR" ]]; then
    log "ERROR screenshot directory does not exist: $SCREENSHOT_DIR"
    exit 1
  fi

  log "=== screenshot rename run started (dry_run=$DRY_RUN) ==="

  find "$SCREENSHOT_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | \
  while IFS= read -r file; do
    ((count++)) || true
    if (( count > MAX_FILES )); then
      log "Reached MAX_FILES=$MAX_FILES, stopping"
      break
    fi
    process_file "$file"
  done

  log "=== screenshot rename run finished ==="
}

main
